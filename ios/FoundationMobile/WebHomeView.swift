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
            bridgeStatus = .failed(error.localizedDescription)
        }
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
            let js = """
            (async () => {
              if (typeof window.__foundationSignInWithCustomToken !== 'function') {
                return { ok: false, error: 'bridge_not_ready' };
              }
              try {
                const r = await window.__foundationSignInWithCustomToken('\(escaped)');
                return { ok: true, uid: r?.uid || null };
              } catch (e) {
                return { ok: false, error: e?.message || String(e) };
              }
            })()
            """
            view.evaluateJavaScript(js) { result, error in
                if let error {
                    print("[WebHome] inject error: \(error.localizedDescription)")
                    return
                }
                if let dict = result as? [String: Any] {
                    let ok = dict["ok"] as? Bool ?? false
                    if !ok {
                        let err = dict["error"] as? String ?? "unknown"
                        print("[WebHome] sign-in bridge failed: \(err)")
                    } else {
                        print("[WebHome] sign-in bridge ok uid=\(dict["uid"] ?? "nil")")
                    }
                }
            }
        }
    }
}
