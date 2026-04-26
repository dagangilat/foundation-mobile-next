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
            Button {
                isShowingQRScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .foregroundStyle(Theme.brandGreen)
            }
            .accessibilityLabel("Pair desktop")
            Button {
                isShowingSupport = true
            } label: {
                Image(systemName: "lifepreserver")
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityLabel("Support")
            Button {
                try? AuthService.shared.signOut()
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

        // Document-start marker: AccessGate.tsx reads this to stay on its
        // Loading… state while the iOS bridge is in-flight, instead of
        // falling through to Landing the instant Firebase's first
        // onAuthStateChanged fires with null. Without this the bridge
        // races the React initial render and the user sees the public
        // Landing page even when the bridge eventually succeeds. The
        // marker is cleared by window.__foundationSignInWithCustomToken
        // (in evoting-frontend/src/lib/auth.ts) once it's done — so
        // success and failure both unblock AccessGate.
        let bridgeMarker = WKUserScript(
            source: "window.__foundationMobileBridgePending = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bridgeMarker)

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
                    print("[WebHome] inject error: \(error.localizedDescription)")
                    self?.injectedTokenFingerprint = nil
                    return
                }
                guard let dict = result as? [String: Any] else { return }
                let ok = dict["ok"] as? Bool ?? false
                if ok {
                    print("[WebHome] sign-in bridge ok uid=\(dict["uid"] ?? "nil")")
                    return
                }
                let err = dict["error"] as? String ?? "unknown"
                print("[WebHome] sign-in bridge failed: \(err)")
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
