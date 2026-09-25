import SwiftUI

// The guided passport flow's own screens: the task guide, the explainer
// before each step, the confirmation after it, and the 3-part stepper they
// share with the camera and chip screens. ScanPassportView decides which one
// shows; nothing here reads or changes the passport or registration state.

// MARK: - Flow position

/// The three parts of verifying, as the user sees them.
enum PassportVerifyStage: Int, CaseIterable {
    case photoPage = 0
    case chip = 1
    case proof = 2

    var stepperLabel: LocalizedStringKey {
        switch self {
        case .photoPage: "1. Photo page"
        case .chip: "2. Chip"
        case .proof: "3. Proof"
        }
    }

    var guideTitle: LocalizedStringKey {
        switch self {
        case .photoPage: "Scan the photo page"
        case .chip: "Read the chip"
        case .proof: "Build your proof"
        }
    }

    var guideDetail: LocalizedStringKey {
        switch self {
        case .photoPage: "Your camera reads the two lines of letters at the bottom."
        case .chip: "Hold your phone on the passport. It reads the chip inside."
        case .proof: "Your phone turns that into a private proof. Nothing about you is uploaded."
        }
    }
}

/// Colours only these illustrations use.
private enum PassportIllustrationColor {
    /// Photo silhouette and page grey (#dbe4ee).
    static let page = Color(.sRGB, red: 0xDB / 255.0, green: 0xE4 / 255.0, blue: 0xEE / 255.0, opacity: 1)
    /// Passport cover (#0f766e).
    static let cover = Color(.sRGB, red: 0x0F / 255.0, green: 0x76 / 255.0, blue: 0x6E / 255.0, opacity: 1)
}

// MARK: - Stepper

/// Three segments (Photo page / Chip / Proof): done parts dark green, the
/// current one bright green, the rest grey.
struct PassportVerifyStepper: View {
    let current: PassportVerifyStage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(PassportVerifyStage.allCases, id: \.rawValue) { stage in
                segment(stage)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func segment(_ stage: PassportVerifyStage) -> some View {
        let isDone = stage.rawValue < current.rawValue
        let isCurrent = stage == current

        let barColor: Color = isDone ? FoundationTheme.accent : (isCurrent ? FoundationTheme.brandFill : FoundationTheme.border)
        let labelColor: Color = isDone ? FoundationTheme.accent : (isCurrent ? FoundationTheme.text : FoundationTheme.muted)
        let labelWeight: Font.Weight = isDone ? .semibold : (isCurrent ? .bold : .medium)

        return VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(barColor)
                .frame(height: 5)
            Text(stage.stepperLabel)
                .font(.system(size: 12, weight: labelWeight))
                .foregroundColor(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared screen frame

/// Back header ("Verify"), scrolling content and buttons pinned at the
/// bottom, on Foundation's light background.
private struct PassportVerifyScreen<Content: View, Buttons: View>: View {
    let onBack: () -> Void
    let content: Content
    let buttons: Buttons

    init(
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) {
        self.onBack = onBack
        self.content = content()
        self.buttons = buttons()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoundationBackHeader("Verify", onBack: onBack)
                .padding(.horizontal, FoundationTheme.horizontalPadding)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FoundationTheme.horizontalPadding)
                .padding(.top, 22)
                .padding(.bottom, 16)
            }
            VStack(spacing: 4) {
                buttons
            }
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .background(FoundationTheme.bg.ignoresSafeArea())
    }
}

/// Screen title plus its muted lead paragraph.
private struct PassportVerifyHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(FoundationTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundColor(FoundationTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Lock icon plus a short privacy line.
private struct PassportPrivacyLine: View {
    let text: LocalizedStringKey
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: iconSize, weight: .medium))
            Text(text)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(FoundationTheme.muted)
    }
}

/// Big soft-green circle with a check, on the confirmation screens.
private struct PassportSuccessMark: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 40, weight: .semibold))
            .foregroundColor(FoundationTheme.accent)
            .frame(width: 96, height: 96)
            .background(FoundationTheme.accentTint, in: Circle())
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// Small filled green circle with a white check.
private struct PassportCheckDot: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(FoundationTheme.onAccent)
            .frame(width: 24, height: 24)
            .background(FoundationTheme.accent, in: Circle())
    }
}

// MARK: - Task guide

/// "Verify with your passport": the three steps with Done / Next states.
/// Shown before the photo page (stage .photoPage), after it (.chip) and
/// after the chip (.proof); `stage` is the step that is next.
struct PassportVerifyGuideView: View {
    let stage: PassportVerifyStage
    let onBack: () -> Void
    let onContinue: () -> Void

    private var title: LocalizedStringKey {
        switch stage {
        case .photoPage: "Verify with your passport"
        case .chip: "Photo page done"
        case .proof: "Chip read"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch stage {
        case .photoPage: "Three short steps. You need your passport and a few minutes."
        case .chip: "Next, your phone reads the chip in your passport."
        case .proof: "Last step. It runs on your phone and takes about a minute. Keep the app open."
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch stage {
        case .photoPage: "Start"
        case .chip: "Continue"
        case .proof: "Build my proof"
        }
    }

    var body: some View {
        PassportVerifyScreen(onBack: onBack) {
            PassportVerifyHeading(title: title, subtitle: subtitle)
            VStack(alignment: .leading, spacing: 22) {
                ForEach(PassportVerifyStage.allCases, id: \.rawValue) { step in
                    row(step)
                }
            }
            .foundationCard()
            PassportPrivacyLine(text: "Your passport details stay on this phone.", iconSize: 17)
        } buttons: {
            Button(buttonTitle, action: onContinue)
                .buttonStyle(FoundationPrimaryButtonStyle())
        }
    }

    private func row(_ step: PassportVerifyStage) -> some View {
        let isDone = step.rawValue < stage.rawValue
        let isNext = step == stage
        let isLast = step == PassportVerifyStage.allCases.last

        return HStack(alignment: .top, spacing: 14) {
            marker(step, isDone: isDone, isNext: isNext)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(step.guideTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDone || isNext ? FoundationTheme.text : FoundationTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if isDone {
                        badge("Done", foreground: FoundationTheme.accent, background: FoundationTheme.accentTint)
                    } else if isNext {
                        badge("Next", foreground: FoundationTheme.text, background: FoundationTheme.border)
                    }
                }
                Text(step.guideDetail)
                    .font(.system(size: 14))
                    .foregroundColor(FoundationTheme.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The line down to the next step's circle: green once this step is done.
        .overlay(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(isDone ? FoundationTheme.accent : FoundationTheme.border)
                    .frame(width: 2)
                    .padding(.top, 40)
                    .padding(.bottom, -14)
                    .padding(.leading, 15)
            }
        }
    }

    @ViewBuilder
    private func marker(_ step: PassportVerifyStage, isDone: Bool, isNext: Bool) -> some View {
        if isDone {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(FoundationTheme.onAccent)
                .frame(width: 32, height: 32)
                .background(FoundationTheme.accent, in: Circle())
        } else if isNext {
            Text(verbatim: "\(step.rawValue + 1)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(FoundationTheme.onAccent)
                .frame(width: 32, height: 32)
                .background(FoundationTheme.text, in: Circle())
        } else {
            Text(verbatim: "\(step.rawValue + 1)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(FoundationTheme.muted)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(FoundationTheme.border, lineWidth: 2))
        }
    }

    private func badge(_ text: LocalizedStringKey, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }
}

// MARK: - Explainers

/// One tip on an explainer: icon in a soft-green circle, title, detail.
private struct PassportTip: Identifiable {
    let id: Int
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
}

/// Stepper, illustration, heading, tips card and one primary button.
private struct PassportExplainerScreen<Illustration: View>: View {
    let stage: PassportVerifyStage
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let tips: [PassportTip]
    let buttonTitle: LocalizedStringKey
    let buttonImage: String
    let onBack: () -> Void
    let onContinue: () -> Void
    let illustration: Illustration

    init(
        stage: PassportVerifyStage,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        tips: [PassportTip],
        buttonTitle: LocalizedStringKey,
        buttonImage: String,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.stage = stage
        self.title = title
        self.subtitle = subtitle
        self.tips = tips
        self.buttonTitle = buttonTitle
        self.buttonImage = buttonImage
        self.onBack = onBack
        self.onContinue = onContinue
        self.illustration = illustration()
    }

    var body: some View {
        PassportVerifyScreen(onBack: onBack) {
            PassportVerifyStepper(current: stage)
            illustration
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(FoundationTheme.meshBase)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            PassportVerifyHeading(title: title, subtitle: subtitle)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: tip.systemImage)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(FoundationTheme.accent)
                            .frame(width: 40, height: 40)
                            .background(FoundationTheme.accentTint, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(FoundationTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(tip.detail)
                                .font(.system(size: 14))
                                .foregroundColor(FoundationTheme.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .foundationCard(padding: 18)
        } buttons: {
            Button(action: onContinue) {
                Label(buttonTitle, systemImage: buttonImage)
            }
            .buttonStyle(FoundationPrimaryButtonStyle())
        }
    }
}

/// "First, the photo page": shown before the camera opens.
struct PassportPhotoExplainerView: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        PassportExplainerScreen(
            stage: .photoPage,
            title: "First, the photo page",
            subtitle: "Your camera reads the two lines of letters and <<< at the bottom. That unlocks the chip.",
            tips: [
                PassportTip(id: 0, systemImage: "book", title: "Open to the photo page", detail: "The page with your photo."),
                PassportTip(id: 1, systemImage: "sun.max", title: "Lay it flat in good light", detail: "No glare or shadow over the bottom lines."),
                PassportTip(id: 2, systemImage: "arrow.left.and.right", title: "Hold your phone about 30 cm away", detail: "It scans by itself, or tap Capture."),
            ],
            buttonTitle: "Open the camera",
            buttonImage: "camera.viewfinder",
            onBack: onBack,
            onContinue: onContinue
        ) {
            PhotoPageIllustration()
        }
    }
}

/// "Now, the chip": shown before the NFC scan starts.
struct PassportChipExplainerView: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        PassportExplainerScreen(
            stage: .chip,
            title: "Now, the chip",
            subtitle: "Your phone reads the chip inside your passport. It proves the passport is genuine.",
            tips: [
                PassportTip(id: 0, systemImage: "iphone", title: "Take off a thick phone case", detail: "Metal or thick cases block the signal."),
                PassportTip(id: 1, systemImage: "cpu", title: "Find the chip", detail: "Look for the chip symbol on the cover. The chip is in the cover or the photo page."),
                PassportTip(id: 2, systemImage: "wave.3.right", title: "Hold the top of your phone on it", detail: "Keep still until it buzzes, a few seconds."),
            ],
            buttonTitle: "Start chip scan",
            buttonImage: "wave.3.right",
            onBack: onBack,
            onContinue: onContinue
        ) {
            ChipIllustration()
        }
    }
}

/// A passport photo page: photo, text lines and the framed MRZ lines.
private struct PhotoPageIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PassportIllustrationColor.page)
                    .frame(width: 58, height: 72)
                VStack(alignment: .leading, spacing: 9) {
                    line(width: 136)
                    line(width: 95)
                    line(width: 116)
                }
                .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 3) {
                mrzLine("P<XXX<<<<<<<<<<<<<<<<<<<<<")
                mrzLine("0000000<0XXX<<<<<<<<<<")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(FoundationTheme.accent, lineWidth: 2)
            )
        }
        .padding(16)
        .frame(width: 240, height: 160, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FoundationTheme.surface)
                .shadow(color: FoundationTheme.text.opacity(0.08), radius: 9, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(FoundationTheme.border, lineWidth: 1)
        )
    }

    private func mrzLine(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .tracking(1)
            .foregroundColor(FoundationTheme.text)
            .lineLimit(1)
    }

    private func line(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(FoundationTheme.border)
            .frame(width: width, height: 7)
    }
}

/// A passport with its chip, a phone laid on it and the NFC rings.
private struct ChipIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PassportIllustrationColor.cover)
                .frame(width: 170, height: 120)
                .shadow(color: FoundationTheme.text.opacity(0.12), radius: 9, x: 0, y: 6)
                .offset(x: 10, y: 36)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(FoundationTheme.accentTint, lineWidth: 2)
                .frame(width: 42, height: 34)
                .offset(x: 70, y: 76)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FoundationTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(FoundationTheme.text, lineWidth: 3)
                )
                .frame(width: 84, height: 160)
                .offset(x: 110, y: 4)
            Circle()
                .strokeBorder(FoundationTheme.market.opacity(0.35), lineWidth: 2)
                .frame(width: 96, height: 96)
                .offset(x: 150, y: 10)
            Circle()
                .strokeBorder(FoundationTheme.market.opacity(0.6), lineWidth: 2)
                .frame(width: 64, height: 64)
                .offset(x: 166, y: 26)
        }
        .frame(width: 250, height: 170, alignment: .topLeading)
    }
}

// MARK: - Confirmations

/// What the photo page gave us, for the user to check: the document number
/// masked to its last 4 characters and the two dates.
///
/// Parsed from the MRZ key (PassportUtils.getMRZKey): document number (9,
/// padded with <), check digit, date of birth (YYMMDD), check digit, expiry
/// (YYMMDD), check digit.
struct PassportMRZSummary: Equatable {
    let maskedDocumentNumber: String
    let dateOfBirth: String
    let dateOfExpiry: String

    init?(mrzKey: String?) {
        guard let mrzKey else { return nil }
        let chars = Array(mrzKey)
        guard chars.count >= 23 else { return nil }

        let documentNumber = String(chars[0..<9]).replacingOccurrences(of: "<", with: "")
        guard !documentNumber.isEmpty else { return nil }

        maskedDocumentNumber = "•••••" + String(documentNumber.suffix(4))
        dateOfBirth = Self.format(String(chars[10..<16]), isBirthDate: true) ?? "—"
        dateOfExpiry = Self.format(String(chars[17..<23]), isBirthDate: false) ?? "—"
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PassportMRZSummary.calendar
        formatter.timeZone = PassportMRZSummary.calendar.timeZone
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    /// YYMMDD to "14 Mar 1980". A birth year can't be in the future, so a
    /// two-digit year above this year's is 19xx; an expiry is 20xx unless it
    /// is implausibly far ahead (more than 20 years).
    private static func format(_ yymmdd: String, isBirthDate: Bool) -> String? {
        guard yymmdd.count == 6, yymmdd.allSatisfy(\.isNumber),
              let yy = Int(yymmdd.prefix(2)),
              let month = Int(yymmdd.dropFirst(2).prefix(2)),
              let day = Int(yymmdd.suffix(2)),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        let currentYY = PassportMRZSummary.calendar.component(.year, from: Date()) % 100
        let century: Int
        if isBirthDate {
            century = yy > currentYY ? 1900 : 2000
        } else {
            century = yy > currentYY + 20 ? 1900 : 2000
        }

        let components = DateComponents(year: century + yy, month: month, day: day)
        guard let date = PassportMRZSummary.calendar.date(from: components),
              PassportMRZSummary.calendar.component(.day, from: date) == day
        else { return nil }
        return PassportMRZSummary.displayFormatter.string(from: date)
    }
}

/// "Photo page read": shown after the camera (or manual entry) gives an MRZ.
struct PassportPhotoConfirmView: View {
    let mrzKey: String?
    let onBack: () -> Void
    let onContinue: () -> Void
    let onScanAgain: () -> Void

    private var summary: PassportMRZSummary? {
        PassportMRZSummary(mrzKey: mrzKey)
    }

    var body: some View {
        PassportVerifyScreen(onBack: onBack) {
            PassportVerifyStepper(current: .chip)
            PassportSuccessMark()
            PassportVerifyHeading(
                title: "Photo page read",
                subtitle: "Check these match your passport. The chip only opens with the right details.",
                centered: true
            )
            VStack(spacing: 0) {
                detailRow("Document number", value: summary?.maskedDocumentNumber ?? "—", showsDivider: true)
                detailRow("Date of birth", value: summary?.dateOfBirth ?? "—", showsDivider: true)
                detailRow("Expires", value: summary?.dateOfExpiry ?? "—", showsDivider: false)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: FoundationTheme.cornerRadius, style: .continuous)
                    .fill(FoundationTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FoundationTheme.cornerRadius, style: .continuous)
                    .stroke(FoundationTheme.border, lineWidth: 1)
            )
            PassportPrivacyLine(text: "Kept on this phone only.")
                .frame(maxWidth: .infinity)
        } buttons: {
            Button("Yes, continue", action: onContinue)
                .buttonStyle(FoundationPrimaryButtonStyle())
            Button("Scan again", action: onScanAgain)
                .buttonStyle(FoundationTextButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func detailRow(_ label: LocalizedStringKey, value: String, showsDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(FoundationTheme.muted)
                Spacer(minLength: 8)
                Text(verbatim: value)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(FoundationTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            if showsDivider {
                Rectangle()
                    .fill(FoundationTheme.border)
                    .frame(height: 1)
            }
        }
    }
}

/// "Chip read": shown after the NFC scan succeeds.
struct PassportChipConfirmView: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        PassportVerifyScreen(onBack: onBack) {
            PassportVerifyStepper(current: .proof)
            PassportSuccessMark()
            PassportVerifyHeading(
                title: "Chip read",
                subtitle: "Your passport checks out.",
                centered: true
            )
            VStack(alignment: .leading, spacing: 14) {
                checkRow("Signed by your passport office")
                checkRow("The chip is genuine, not a copy")
                checkRow("Matches the photo page")
            }
            .foundationCard(padding: 18)
        } buttons: {
            Button("Continue", action: onContinue)
                .buttonStyle(FoundationPrimaryButtonStyle())
        }
    }

    private func checkRow(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            PassportCheckDot()
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(FoundationTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Guide") {
    PassportVerifyGuideView(stage: .chip, onBack: {}, onContinue: {})
}

#Preview("Photo explainer") {
    PassportPhotoExplainerView(onBack: {}, onContinue: {})
}

#Preview("Chip explainer") {
    PassportChipExplainerView(onBack: {}, onContinue: {})
}

#Preview("Photo confirm") {
    PassportPhotoConfirmView(
        mrzKey: "L898902C<369080619406236",
        onBack: {},
        onContinue: {},
        onScanAgain: {}
    )
}

#Preview("Chip confirm") {
    PassportChipConfirmView(onBack: {}, onContinue: {})
}
