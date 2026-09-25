import SwiftUI

/// Foundation's light design tokens, ported from the original Foundation
/// shell's `ThemePalette.foundation` (deleted in bfeab73). Light only: the app
/// forces the light color scheme (AppView + UIUserInterfaceStyle), so these
/// are plain colors rather than appearance-aware asset colors.
enum FoundationTheme {
    static let bg = rgb(0xF6F9FC)
    static let surface = rgb(0xFFFFFF)
    static let border = rgb(0xE6EBF1)
    static let muted = rgb(0x596171)
    static let text = rgb(0x0A0E27)
    /// Primary accent (brand green): CTAs, links, active states.
    static let accent = rgb(0x047857)
    /// Bright brand green. Decorative fills only, never text.
    static let brandFill = rgb(0x34D399)
    static let brandCyan = rgb(0x22D3EE)
    static let onAccent = rgb(0xFFFFFF)
    /// Soft green behind the "Verified" pill and success hints.
    static let accentTint = rgb(0xD1FAE5)
    /// Destructive rows (Sign out, Delete account) and inline error text.
    static let danger = rgb(0xB42318)
    /// Unread dots (bell, error entries) and the error icon's tint behind it.
    static let alertDot = rgb(0xDC2626)
    static let dangerIcon = rgb(0xB91C1C)
    static let dangerTint = rgb(0xFEE2E2)

    static let voice = rgb(0x6366F1)
    static let share = rgb(0x0D9488)
    static let market = rgb(0x0891B2)

    static let meshBase = rgb(0xE8FBF4)
    static let meshBlobs: [Color] = [rgb(0x34D399), rgb(0x22D3EE), rgb(0x60A5FA), rgb(0xA78BFA)]

    /// Dark surface used behind camera screens (QR scan).
    static let scanBackground = rgb(0x0F172A)
    static let scanMuted = rgb(0xCBD5E1)

    static let cornerRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 8
    static let buttonHeight: CGFloat = 52
    static let horizontalPadding: CGFloat = 24

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Buttons

/// Full-width filled green button (radius 8, 0.7 opacity when disabled).
struct FoundationPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(FoundationTheme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: FoundationTheme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: FoundationTheme.buttonRadius, style: .continuous)
                    .fill(FoundationTheme.accent)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1.0) : 0.7)
            .contentShape(Rectangle())
    }
}

/// Full-width outlined button: surface fill, 1pt border, green label.
struct FoundationSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(FoundationTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: FoundationTheme.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: FoundationTheme.buttonRadius, style: .continuous)
                    .fill(configuration.isPressed ? FoundationTheme.bg : FoundationTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FoundationTheme.buttonRadius, style: .continuous)
                    .stroke(FoundationTheme.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.7)
            .contentShape(Rectangle())
    }
}

/// Borderless green text button ("Restore from backup", "Resend").
struct FoundationTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(FoundationTheme.accent)
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1.0) : 0.5)
            .contentShape(Rectangle())
    }
}

// MARK: - Cards and small pieces

private struct FoundationCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FoundationTheme.cornerRadius, style: .continuous)
                    .fill(FoundationTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FoundationTheme.cornerRadius, style: .continuous)
                    .stroke(FoundationTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    /// Status-card look: white surface, 12 radius, 1pt #e6ebf1 border.
    func foundationCard(padding: CGFloat = 20) -> some View {
        modifier(FoundationCardModifier(padding: padding))
    }
}

/// Small uppercase caption ("STATUS", "SIGNED IN AS").
struct FoundationSectionLabel: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(FoundationTheme.muted)
    }
}

/// A red error line shown on the screen it belongs to (sign-in, first run,
/// Backup and recovery), for errors that must be seen where they happened
/// rather than behind Home's bell.
struct FoundationInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .semibold))
            Text(verbatim: message)
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(FoundationTheme.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Back chevron plus a short screen title, used by pushed screens
/// (Profile, the passport scan steps).
struct FoundationBackHeader: View {
    let title: LocalizedStringKey?
    let onBack: () -> Void

    init(_ title: LocalizedStringKey? = nil, onBack: @escaping () -> Void) {
        self.title = title
        self.onBack = onBack
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(FoundationTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Back"))
            if let title {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FoundationTheme.text)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 44)
        .padding(.leading, -12)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        FoundationBackHeader("Verify", onBack: {})
        VStack(alignment: .leading, spacing: 12) {
            FoundationSectionLabel("Status")
            Text(String("Not verified yet"))
                .font(.system(size: 22, weight: .bold))
            Button(String("Scan passport")) {}
                .buttonStyle(FoundationPrimaryButtonStyle())
        }
        .foundationCard()
        Button(String("Scan QR code")) {}
            .buttonStyle(FoundationSecondaryButtonStyle())
        Button(String("Restore from backup")) {}
            .buttonStyle(FoundationTextButtonStyle())
    }
    .padding(24)
    .background(FoundationTheme.bg)
}
