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

    // Foundation web app URL — same hosting target the docs-site +
    // evoting-frontend deploy to (foundation-global). Hard-coded for
    // now; could move to AppConfig if a profile ever wants a different
    // surface (e.g. lowsec-attest pointing at a Sybil-resistance demo
    // surface instead of the full governance UI).
    private static let webURL = URL(string: "https://foundation-global.com/")!

    var body: some View {
        VStack(spacing: 0) {
            chrome
            WebContainer(url: Self.webURL)
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

// Thin UIViewRepresentable wrapper. The WebView keeps its own auth
// state — Foundation web reads Firebase Auth via the JS SDK, so the
// user signs in once on mobile (email link) and once in the WebView
// (same email link, separate session). A custom-token bridge would
// collapse those into one — TODO.
struct WebContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.bounces = true
        view.isOpaque = false
        view.backgroundColor = UIColor(Theme.bg)
        view.scrollView.backgroundColor = UIColor(Theme.bg)
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
