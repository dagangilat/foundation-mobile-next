import SwiftUI

// Phase 3a — host view for the passport-scan funnel. Drives the user
// through three coordinator states with state-specific copy + action:
//
//   .readyForPassport   → "Scan passport MRZ" CTA opens MRZScanView sheet
//   .scanningPassport   → "Reading chip…" (passive — iOS NFC modal is up)
//   .passportReady      → "Verify" CTA seals the commitment
//   .failed (post-pose) → "Try again" CTA re-opens the MRZ sheet
//
// The actual system NFC prompt modal is drawn by CoreNFC itself when
// NFCTagReaderSession.begin() fires inside PassportReader, which runs
// after MRZ parsing hands the key to coordinator.scanPassport(mrzKey:).

struct NFCScanView: View {
    @ObservedObject var coordinator: CaptureCoordinator
    // CaptureView owns the MRZ sheet's presentation state; this closure
    // flips it open. Same closure is used by the retry path so a failed
    // scan goes straight back into MRZ entry without an extra tap.
    let onScanTap: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            stepIndicator

            hero

            copy

            Spacer(minLength: 0)

            statusBlock

            actionButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: — step indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "2.circle.fill")
                .foregroundStyle(Theme.brandGreen)
            Text("Step 2 of 3 — passport scan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.pillBg)
        .clipShape(Capsule())
        .accessibilityLabel("Step 2 of 3, passport scan")
    }

    // MARK: — hero (large illustrative icon)

    @ViewBuilder
    private var hero: some View {
        switch coordinator.state {
        case .scanningPassport:
            VStack(spacing: 16) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Theme.brandGreen)
                Image(systemName: "iphone")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
            }
        case .passportReady:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGreen)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.orange)
        default:
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGreen)
        }
    }

    // MARK: — state-specific body copy

    @ViewBuilder
    private var copy: some View {
        switch coordinator.state {
        case .readyForPassport:
            VStack(spacing: 8) {
                Text("Scan your passport")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Two steps: first, point your camera at the passport photo page to read the MRZ. Then hold the passport against the top-back of your iPhone for the chip read.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        case .scanningPassport:
            VStack(spacing: 8) {
                Text("Hold your passport")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text("near the top of your iPhone, under the camera bump. Keep still until the chip read completes.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        case .passportReady(_, let result):
            VStack(spacing: 8) {
                Text("Passport scanned")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(prettyCountry(result.issuingCountryCode)) passport \(result.passportNumberMasked). Tap verify to sign and seal the commitment.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        case .failed:
            VStack(spacing: 8) {
                Text("Scan failed")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Tap retry to re-scan the MRZ and try the chip read again. If it keeps failing, make sure the passport photo page is well lit and the chip is against the very top of your iPhone.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        default:
            EmptyView()
        }
    }

    // MARK: — status (small caption under copy)

    @ViewBuilder
    private var statusBlock: some View {
        switch coordinator.state {
        case .scanningPassport:
            HStack(spacing: 12) {
                ProgressView().progressViewStyle(.circular).tint(Theme.brandGreen)
                Text("Reading passport chip…")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
            }
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }

    // MARK: — primary action

    @ViewBuilder
    private var actionButton: some View {
        switch coordinator.state {
        case .readyForPassport:
            bigGreenButton(title: "Scan passport MRZ", action: onScanTap)
        case .scanningPassport:
            bigGreenButton(title: "Reading chip…", enabled: false) {}
        case .passportReady:
            bigGreenButton(title: "Verify humanity") { coordinator.verify() }
        case .failed where coordinator.isAfterPoseCapture:
            bigGreenButton(title: "Retry") {
                coordinator.retryPassportFromFailure()
                onScanTap()
            }
        default:
            EmptyView()
        }
    }

    private func bigGreenButton(title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandGreen)
                .cornerRadius(12)
                .opacity(enabled ? 1.0 : 0.5)
        }
        .disabled(!enabled)
    }

    // MARK: — helpers

    private func prettyCountry(_ code: String) -> String {
        switch code.uppercased() {
        case "ISR": return "Israeli"
        case "PRT": return "Portuguese"
        case "GBR": return "British"
        case "USA": return "US"
        case "FRA": return "French"
        case "DEU": return "German"
        case "ESP": return "Spanish"
        case "ITA": return "Italian"
        case "NLD": return "Dutch"
        case "BEL": return "Belgian"
        case "CHE": return "Swiss"
        default: return code
        }
    }
}
