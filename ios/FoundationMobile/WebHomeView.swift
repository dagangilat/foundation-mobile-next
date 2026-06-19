import SwiftUI
import WebKit

// Post-verification surface. Once the user has anchored a humanity
// commitment (and, eventually, while their passport is not expired),
// HomeView swaps the "Verify humanity" CTA + technical readouts for
// this WKWebView pointed at the foundation-global web app. Keeps the
// mobile shell thin: native top toolbar (Pair desktop / Sign out /
// Support), web app for everything else.
//
// Auth handoff is deferred — the WebView starts unauthenticated and
// the user signs in via the same email link if the session cookie
// hasn't been minted yet. Custom-token bridging through a Cloud
// Function is the follow-up.

struct WebHomeView: View {
    let claims: Claims
    @ObservedObject var pairing: PairingCoordinator
    @State private var isShowingQRScanner = false
    @State private var isShowingSupport = false
    @State private var attestation = AttestationCoordinator.shared
    @State private var capture = CaptureCoordinator.shared
    @State private var proofSmoke: SmokeProofResult = .skipped
    @State private var customToken: String? = nil
    @State private var bridgeStatus: BridgeStatus = .minting

    enum BridgeStatus: Equatable {
        case minting
        case ready
        case failed(String)
    }

    // Foundation web app URL — same hosting target the docs-site +
    // evoting-frontend deploy to (foundation-global). Hard-coded for
    // now; could move to AppConfig if a profile ever wants a different
    // surface (e.g. lowsec-attest pointing at a Sybil-resistance demo
    // surface instead of the full governance UI).
    private static let webURL = URL(string: "https://foundation-global.com/")!

    var body: some View {
        VStack(spacing: 0) {
            chrome
            if case .failed(let msg) = bridgeStatus {
                bridgeBanner(msg)
            }
            WebContainer(url: Self.webURL, customToken: customToken)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $isShowingQRScanner) {
            QRScannerView(
                onScanned: { code in
                    isShowingQRScanner = false
                    pairing.claim(scannedPayload: code)
                },
                onCancel: { isShowingQRScanner = false }
            )
        }
        .sheet(isPresented: $isShowingSupport) {
            SupportSheet(
                attestation: attestation,
                capture: capture,
                proofSmoke: proofSmoke
            )
        }
        .task {
            proofSmoke = await MoproSmokeBridge.runMultiplier2Smoke()
        }
        .task {
            await mintToken()
        }
    }

    private func mintToken() async {
        #if DEBUG
        let t0 = Date()
        print("[WebHome.timing] mintToken start at \(Self.fmt(t0))")
        #endif
        bridgeStatus = .minting
        do {
            let result = try await FunctionsService.shared.mintWebSessionToken()
            customToken = result.customToken
            bridgeStatus = .ready
            #if DEBUG
            let elapsed = Date().timeIntervalSince(t0) * 1000
            print("[WebHome.timing] mintToken success in \(Int(elapsed)) ms")
            #endif
        } catch {
            #if DEBUG
            let elapsed = Date().timeIntervalSince(t0) * 1000
            print("[WebHome.timing] mintToken FAILED in \(Int(elapsed)) ms: \(error.localizedDescription)")
            #endif
            // The user can still sign in via the WebView's own email link
            // flow as a fallback — surface a banner so they know what
            // happened without blocking the surface entirely.
            bridgeStatus = .failed(Self.friendlyMintError(error))
        }
    }

    #if DEBUG
    private static func fmt(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: d)
    }
    #endif

    // Maps the raw NSError into copy a user can act on. Server returns
    // ("failed-precondition", "stale_auth: …") when auth_time is past
    // PAIRING_AUTH_FRESHNESS_SECONDS — sign-out + sign-in cures it.
    // ("unauthenticated") usually means an App Check carve-out missing
    // on the callable; nothing the user can fix, so frame it as "we'll
    // catch this on our side, retry shortly". Anything else falls back
    // to the raw message so the support sheet still has the detail.
    private static func friendlyMintError(_ error: Error) -> String {
        let ns = error as NSError
        let desc = ns.localizedDescription
        if desc.contains("stale_auth") {
            return "Session is stale — sign out and sign in again to refresh, then tap Retry."
        }
        if ns.domain == "com.firebase.functions" && ns.code == 16 /* unauthenticated */ {
            return "Server didn't accept the device session. Tap Retry; if it keeps failing, sign out and sign in again."
        }
        return desc
    }

    private func bridgeBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't auto sign-in to web")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry") { Task { await mintToken() } }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle().fill(Color.orange.opacity(0.4)).frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var chrome: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                HStack(spacing: 0) {
                    Text("Found").foregroundStyle(Theme.text)
                    Text("ation").foregroundStyle(Theme.brandGreen)
                }
                .font(.system(size: 16, weight: .bold))
            }
            Spacer()
            // Pair-desktop button gated by AppConfig.shared.pairing.enabled.
            // Sheet + QRScannerView code stays compiled.
            if AppConfig.shared.pairing.enabled {
                Button {
                    isShowingQRScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundStyle(Theme.brandGreen)
                }
                .accessibilityLabel("Pair desktop")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(
            Rectangle().fill(Theme.border).frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// Thin UIViewRepresentable wrapper. Mobile mints a Firebase custom
// token via mintWebSessionToken, then injects it after the WebView
// finishes loading by calling window.__foundationSignInWithCustomToken
// (defined in evoting-frontend lib/auth.ts). The token never appears
// in the URL — it travels only via JS injection inside the WebView's
// process boundary.
struct WebContainer: UIViewRepresentable {
    let url: URL
    let customToken: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()

        // Document-start markers for AccessGate.tsx:
        //
        //   - __foundationMobileBridgePending: in-flight bridge sign-in.
        //     Cleared by window.__foundationSignInWithCustomToken when
        //     the call resolves (success or failure). Holds AccessGate
        //     on Loading… so it doesn't flash Landing in the race
        //     between Firebase's first null callback and the bridge.
        //
        //   - __foundationMobileWebView: persistent flag that this
        //     surface IS the iOS Foundation Mobile shell, not a real
        //     desktop browser. AccessGate's pair gate (which forces
        //     desktops to pair before granting access) is skipped when
        //     this is set — pairing the mobile to itself would be a
        //     useless self-loop. NOT cleared by the bridge function;
        //     persists for the lifetime of the WebView.
        let documentStartMarkers = WKUserScript(
            source: """
                window.__foundationMobileBridgePending = true;
                window.__foundationMobileWebView = true;
                // Sign-out bridge: when the web app's Logout fires, it
                // calls this fn to delegate back to the iOS shell. The
                // shell's AuthService.signOut() owns the pair release
                // CF + clears iOS Firebase Auth + tears down this
                // WebView. Without delegation, the web's Auth.signOut
                // alone leaves the iOS pair lingering until the lease
                // expires (~30s). evoting-frontend/src/lib/auth.ts
                // clearAuth() awaits this hook before its own signOut.
                window.__foundationMobileSignOut = function() {
                    return new Promise(function(resolve) {
                        try {
                            window.webkit.messageHandlers.foundationMobileSignOut.postMessage({});
                        } catch (e) {
                            // Handler not registered — fall through
                        }
                        // Resolve quickly; iOS will tear down the
                        // WebView shortly after, making the resolve
                        // moot. 200ms gives the postMessage time to
                        // dispatch before the WebView dies.
                        setTimeout(resolve, 200);
                    });
                };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(documentStartMarkers)

        // Register the sign-out message handler. The handler is held
        // by the Coordinator so its lifetime matches the WKWebView's;
        // when WebHomeView dismisses, the handler is released along
        // with the rest of the WebView graph.
        config.userContentController.add(
            context.coordinator.signOutMessageHandler,
            name: "foundationMobileSignOut"
        )

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.bounces = true
        view.isOpaque = false
        view.backgroundColor = UIColor(Theme.bg)
        view.scrollView.backgroundColor = UIColor(Theme.bg)
        context.coordinator.webView = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.handle(token: customToken)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var pendingToken: String?
        private var pageLoaded = false
        private var injectedTokenFingerprint: String?
        // Owned by the Coordinator so lifetime matches the WKWebView.
        // When WebHomeView dismisses, this is released with the rest
        // of the WebView graph and the message handler unregisters.
        let signOutMessageHandler = SignOutMessageHandler()

        func handle(token: String?) {
            if let token { pendingToken = token }
            inject()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            inject()
        }

        // 2026-04-26 security review M-H-5: lock the WKWebView to the
        // Foundation domain. Without a navigation policy, a link or
        // auto-redirect on the loaded page could navigate to an
        // attacker-controlled origin while the at-document-start user
        // script (which sets __foundationMobileWebView and the custom-
        // token bridge target) re-runs on every navigation. With this
        // policy, in-app navigation is allowlist-bounded and external
        // links open in Safari instead.
        private static let allowedHosts: Set<String> = [
            "foundation-global.com",
            "www.foundation-global.com",
        ]

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let host = navigationAction.request.url?.host?.lowercased() else {
                decisionHandler(.cancel)
                return
            }
            if Self.allowedHosts.contains(host) {
                decisionHandler(.allow)
                return
            }
            // Out-of-app link tap: open in Safari rather than inline.
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                Task { @MainActor in
                    UIApplication.shared.open(url)
                }
            }
            decisionHandler(.cancel)
        }

        // 2026-04-26 security review M-H-5: defense-in-depth shape check
        // on the custom token before injecting into JS. Firebase custom
        // tokens are JWTs (three base64url segments separated by dots);
        // this regex rejects anything else, so a malformed value from
        // mintWebSessionToken (debug echo, error string, server bug)
        // can't reach evaluateJavaScript and break out of the literal.
        private static let jwtShape = try! NSRegularExpression(
            pattern: "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"
        )

        private func inject() {
            guard pageLoaded, let token = pendingToken, let view = webView else { return }

            let range = NSRange(token.startIndex..<token.endIndex, in: token)
            guard Self.jwtShape.firstMatch(in: token, range: range) != nil,
                  token.count <= 4096 else {
                #if DEBUG
                print("[WebHome] refusing to inject malformed custom token (len=\(token.count))")
                #endif
                return
            }

            // First 12 chars used as an idempotency key — re-injecting
            // the same token would just replay the same sign-in. If the
            // token changes (re-mint), we inject again.
            let fingerprint = String(token.prefix(12))
            if injectedTokenFingerprint == fingerprint { return }
            injectedTokenFingerprint = fingerprint

            // Token is passed through `arguments:` rather than baked into
            // the JS literal — callAsyncJavaScript marshals arguments
            // through JSON, so there's no string-escape break-out risk
            // even on a future token format that includes quotes or
            // backslashes. The shape regex above already rejected anything
            // that isn't a clean JWT.
            //
            // Bridge handoff is fire-and-forget. We've measured
            // signInWithCustomToken inside WKWebView taking 20-40 s due
            // to WebContent process / IndexedDB contention during the
            // cold-start window, during which AWAITING the promise
            // blocks the iOS side and wastes time we don't have. Once
            // we've INVOKED window.__foundationSignInWithCustomToken,
            // Firebase Web Auth will eventually update auth.currentUser
            // — and AccessGate's 100 ms polling fallback (see web
            // AccessGate.tsx) catches that the moment it lands,
            // regardless of how long the promise itself takes to
            // resolve. The bridge body returns to iOS in <100 ms after
            // the function-defined poll succeeds; iOS logs "bridge
            // fired" and stops waiting.
            //
            // We still poll for window.__foundationSignInWithCustomToken
            // up to 15 s because the React bundle's lib/auth.ts module
            // has to evaluate before the function is defined.
            //
            // callAsyncJavaScript wraps `body` in an async function and
            // awaits the returned Promise before invoking the completion
            // handler — required because evaluateJavaScript(_:completionHandler:)
            // does NOT await Promises and would error with
            // "JavaScript execution returned a result of an unsupported type".
            let body = """
            const deadline = Date.now() + 15000;
            while (typeof window.__foundationSignInWithCustomToken !== 'function') {
              if (Date.now() > deadline) {
                return { ok: false, error: 'bridge_timeout' };
              }
              await new Promise(r => setTimeout(r, 75));
            }
            // Fire-and-forget. The .catch is just there to keep the
            // unhandled-rejection logger quiet if Firebase Auth ever
            // throws (network down, malformed token, etc.) — the
            // user-visible failure mode is "WebView stays on Loading
            // until AccessGate's 60 s bridge timeout", which is the
            // right behavior for a genuinely broken sign-in.
            window.__foundationSignInWithCustomToken(token).catch(() => {});
            return { ok: true, fired: true };
            """
            #if DEBUG
            let injectStart = Date()
            print("[WebHome.timing] inject start")
            #endif
            view.callAsyncJavaScript(
                body,
                arguments: ["token": token],
                in: nil,
                in: .page
            ) { [weak self] result in
                #if DEBUG
                let elapsed = Date().timeIntervalSince(injectStart) * 1000
                #endif
                switch result {
                case .failure(let error):
                    #if DEBUG
                    print("[WebHome.timing] inject error after \(Int(elapsed)) ms: \(error.localizedDescription)")
                    #endif
                    self?.injectedTokenFingerprint = nil
                    return
                case .success(let value):
                    #if DEBUG
                    print("[WebHome.timing] inject completed in \(Int(elapsed)) ms")
                    #endif
                    guard let dict = value as? [String: Any] else { return }
                    let ok = dict["ok"] as? Bool ?? false
                    if ok {
                        // 2026-04-26 security review M-H-6: do not log uid in
                        // release builds. uid ties this device session to the
                        // backend across all surfaces; readable via Console.app
                        // with USB access.
                        #if DEBUG
                        print("[WebHome] sign-in bridge ok uid=\(dict["uid"] ?? "nil")")
                        #endif
                        return
                    }
                    let err = dict["error"] as? String ?? "unknown"
                    #if DEBUG
                    print("[WebHome] sign-in bridge failed: \(err)")
                    #endif
                    // bridge_timeout means the React bundle hadn't evaluated by
                    // the deadline. Clearing the fingerprint lets the next
                    // updateUIView (e.g. on customToken re-emission, or any
                    // SwiftUI state tick) retry the injection. Other errors
                    // (exception inside __foundationSignInWithCustomToken) are
                    // not retryable from here — surfaced via the console for
                    // diagnostics; user must reload the WebView.
                    if err == "bridge_timeout" {
                        self?.injectedTokenFingerprint = nil
                    }
                }
            }
        }
    }
}

// Receives `window.webkit.messageHandlers.foundationMobileSignOut.postMessage(...)`
// from the WebView's JS context. Triggers the iOS shell's full
// sign-out path — which fires the pair-release CF (with retry), then
// clears iOS Firebase Auth, which causes RootView to swap to
// SignInView, tearing down the WebView. Without this hook, the web
// app's sign-out only signed out the WebView's Firebase Auth instance
// and left the iOS shell paired indefinitely (until lease expiry).
final class SignOutMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "foundationMobileSignOut" else { return }
        Task { @MainActor in
            try? await AuthService.shared.signOut()
        }
    }
}
