import SwiftUI
import WebKit

private let kFoundationWebURL = URL(string: "https://app.foundation-global.com")!

// MARK: – WKWebView shell (injects mobile-context flag for AccessGate)
private struct FoundationWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addUserScript(WKUserScript(
            source: "window.__foundationMobileWebView = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.load(URLRequest(url: kFoundationWebURL))
        return wv
    }
    func updateUIView(_ wv: WKWebView, context: Context) {}
}

// MARK: – Tech-report sheet
private struct TechReportView: View {
    let claims: Claims
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    row("Version", appVersion)
                    row("Build", buildNumber)
                }
                Section("Account") {
                    row("UID", claims.uid)
                    if let email = claims.email { row("Email", email) }
                    if let ring = claims.ring { row("Ring", "\(ring)") }
                }
                Section("Environment") {
                    row("Web app", kFoundationWebURL.absoluteString)
                }
            }
            .navigationTitle("Technical Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: – Main view
struct HomeView: View {
    let claims: Claims

    @StateObject private var firestore = FirestoreService.shared
    @State private var showSignOutConfirm = false
    @State private var webViewActive = false
    @State private var showTechReport = false

    private var ringText: String? {
        let ring = firestore.userDoc?.ring ?? claims.ring
        guard let ring else { return nil }
        return Theme.ringLabels[ring] ?? "Ring \(ring)"
    }

    var body: some View {
        if webViewActive {
            // ── Connected state: logo bar + full-height web view ──────────
            VStack(spacing: 0) {
                connectedHeader
                FoundationWebView()
            }
            .ignoresSafeArea(edges: .bottom)
        } else {
            // ── Native state: full home screen ────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    solanaPill
                    hero
                    ringCard
                    launchCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .onAppear { firestore.observeUser(uid: claims.uid) }
            .confirmationDialog(
                "Sign out of Foundation?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    try? AuthService.shared.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showTechReport) {
                TechReportView(claims: claims)
            }
        }
    }

    // ── Native header (logo + lifebuoy + logout) ──────────────────────
    private var header: some View {
        HStack {
            logo
            Spacer()
            HStack(spacing: 8) {
                Button {
                    showTechReport = true
                } label: {
                    Image(systemName: "lifepreserver")
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("Technical report")

                Button {
                    showSignOutConfirm = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("Sign out")
            }
        }
    }

    // ── Connected header (logo only — web app provides its own nav) ───
    private var connectedHeader: some View {
        HStack {
            logo
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(
            Divider().background(Theme.border),
            alignment: .bottom
        )
    }

    private var logo: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.brandGreen)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                Text("Found").foregroundStyle(.white)
                Text("ation").foregroundStyle(Theme.brandGreen)
            }
            .font(.system(size: 22, weight: .bold))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Foundation")
        }
    }

    private var solanaPill: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.brandGreen).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("Powered by Solana Blockchain")
                .font(.callout)
                .foregroundStyle(Theme.brandGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.pillBg)
        .cornerRadius(999)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            pillar(icon: "waveform", label: "Voice.", color: Theme.voice)
            pillar(icon: "square.and.arrow.up", label: "Share.", color: Theme.share)
            pillar(icon: "chart.line.uptrend.xyaxis", label: "Market.", color: Theme.market)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Voice, Share, and Market")
    }

    private func pillar(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(color)
                .accessibilityHidden(true)
            Text(label).font(.system(size: 48, weight: .bold)).foregroundStyle(color)
        }
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Signed in")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(claims.email ?? claims.uid)
                .font(.callout)
                .foregroundStyle(.white)
            if let ringText {
                Text(ringText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brandGreen)
                    .padding(.top, 4)
            } else {
                Text("Ring pending — awaiting first-sign-in claim")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .cornerRadius(12)
    }

    // ── "Connect to Foundation" launch card ───────────────────────────
    private var launchCard: some View {
        Button {
            webViewActive = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.brandGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Foundation App")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Your Voice · Share · Market")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.brandGreen.opacity(0.3)))
            .cornerRadius(12)
        }
    }
}
