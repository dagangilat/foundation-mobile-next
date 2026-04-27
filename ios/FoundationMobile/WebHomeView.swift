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
        bridgeStatus = .minting
        do {
            let result = try await FunctionsService.shared.mintWebSessionToken()
            customToken = result.customToken
            bridgeStatus = .ready
        } catch {
            // The user can still sign in via the WebView's own email link
            // flow as a fallback — surface a banner so they know what
            // happened without blocking the surface entirely.
            bridgeStatus = .failed(Self.friendlyMintError(error))
        }
    }

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
                    Text("Found").foregroundStyle(.white)
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
            Button {
                isShowingSupport = true
            } label: {
                Image(systemName: "lifepreserver")
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("Support")
            Button {
                Task { try? await AuthService.shared.signOut() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(Theme.brandGreen)
            }
            .accessibilityLabel("Sign out")
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

        private func inject() {
            guard pageLoaded, let token = pendingToken, let view = webView else { return }
            // First 12 chars used as an idempotency key — re-injecting
            // the same token would just replay the same sign-in. If the
            // token changes (re-mint), we inject again.
            let fingerprint = String(token.prefix(12))
            if injectedTokenFingerprint == fingerprint { return }
            injectedTokenFingerprint = fingerprint

            // Escape backslashes first, then single quotes, so the JS
            // literal can't be broken out of. Custom tokens are
            // base64url + dots so neither character should appear, but
            // belt-and-suspenders.
            let escaped = token
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            // Poll for the bridge function inside the JS itself: didFinish
            // fires when the document finishes loading, but the React
            // module that defines window.__foundationSignInWithCustomToken
            // is loaded as a deferred <script type="module"> and may still
            // be evaluating. A single-shot check would race and fall
            // through to the Landing page; polling holds AccessGate on
            // its Loading… state until the bridge can sign the user in
            // directly into the authenticated app. 15s deadline covers
            // cold cache + Edge-throttled networks; on timeout we clear
            // the fingerprint so the next updateUIView retries.
            let js = """
            (async () => {
              const deadline = Date.now() + 15000;
              while (typeof window.__foundationSignInWithCustomToken !== 'function') {
                if (Date.now() > deadline) {
                  return { ok: false, error: 'bridge_timeout' };
                }
                await new Promise(r => setTimeout(r, 75));
              }
              try {
                const r = await window.__foundationSignInWithCustomToken('\(escaped)');
                return { ok: true, uid: r?.uid || null };
              } catch (e) {
                return { ok: false, error: e?.message || String(e) };
              }
            })()
            """
            view.evaluateJavaScript(js) { [weak self] result, error in
                if let error {
                    #if DEBUG
                    print("[WebHome] inject error: \(error.localizedDescription)")
                    #endif
                    self?.injectedTokenFingerprint = nil
                    return
                }
                guard let dict = result as? [String: Any] else { return }
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
