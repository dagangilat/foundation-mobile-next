import SwiftUI

// Phase 3a — the host view for the NFC chip-read step. The actual iOS
// NFC prompt modal is drawn by CoreNFC itself when
// NFCTagReaderSession.begin() fires inside PassportReader. Our job is
// pre-scan instructional copy + post-scan state display. The hold-here
// drawing is a simple SF Symbol over gradient; iPhone 13's NFC antenna
// sits under the top-back camera bump so "top of phone, near the
// camera" is the right literal instruction.

struct NFCScanView: View {
    @ObservedObject var coordinator: CaptureCoordinator

    var body: some View {
        VStack(spacing: 24) {
            hero

            instruction

            Spacer(minLength: 0)

            statusBlock

            retryButtonIfFailed
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    private var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGreen)
            Image(systemName: "iphone")
                .font(.system(size: 42))
                .foregroundStyle(.white)
        }
        .padding(.top, 20)
    }

    private var instruction: some View {
        VStack(spacing: 8) {
            Text("Hold your passport")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("near the top of your iPhone, under the camera bump. Keep still until the chip read completes.")
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
    }

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
        case .passportReady(_, let result):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.brandGreen)
                Text("\(prettyCountry(result.issuingCountryCode)) passport \(result.passportNumberMasked)")
                    .font(.callout)
                    .foregroundStyle(.white)
            }
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Scan failed")
                        .font(.callout).foregroundStyle(.orange)
                }
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var retryButtonIfFailed: some View {
        if case .failed = coordinator.state {
            Button {
                coordinator.retryPassportFromFailure()
            } label: {
                Text("Retry")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGreen)
                    .cornerRadius(12)
            }
        }
    }

    // Pretty-print the 3-letter issuing country where we can. Falls back
    // to the raw code. Kept in-file; adding more countries is cheap.
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
