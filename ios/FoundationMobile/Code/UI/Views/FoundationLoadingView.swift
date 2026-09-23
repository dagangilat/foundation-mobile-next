import SwiftUI

/// Launch / loading screen: the Foundation lockup, the pillars hero in the
/// mesh, and a quiet "Loading Foundation…" footer over a slim green progress
/// line. Same hero as Home, so launch and Home read as one opening sequence.
/// Ported from the original Foundation shell's LoadingView.
struct FoundationLoadingView: View {
    var message: LocalizedStringKey = "Loading Foundation…"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            BrandLockup()
                .frame(height: 44)
            PillarsHero()
                .padding(.top, 16)
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, FoundationTheme.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FoundationTheme.bg.ignoresSafeArea())
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(FoundationTheme.accent)
                    .controlSize(.small)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.muted)
            }
            FoundationIndeterminateBar()
                .frame(width: 200, height: 2)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Indeterminate progress: a 2pt green capsule sweeping across a 200pt track.
/// Holds still (a static segment) when Reduce Motion is on.
struct FoundationIndeterminateBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweepOffset: CGFloat = -0.4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FoundationTheme.border)
                Capsule()
                    .fill(FoundationTheme.accent)
                    .frame(width: geometry.size.width * 0.4)
                    .offset(x: (reduceMotion ? 0.3 : sweepOffset) * geometry.size.width)
            }
            .clipShape(Capsule())
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    sweepOffset = 1.0
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    FoundationLoadingView()
}
