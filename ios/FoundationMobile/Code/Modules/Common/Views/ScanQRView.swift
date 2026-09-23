import CodeScanner
import SwiftUI

struct ScanQRView: View {
    var onBack: () -> Void
    var onScan: (String) -> Void

    private let frameSize: CGFloat = 250

    var body: some View {
        ZStack {
            FoundationTheme.scanBackground
                .ignoresSafeArea()
            CameraPermissionView(onCancel: onBack) {
                CodeScannerView(codeTypes: [.qr]) { response in
                    switch response {
                    case .success(let result):
                        onScan(result.string)
                    case .failure(let error):
                        LoggerUtil.common.error("Failed to scan QR code: \(error, privacy: .public)")
                        onScan("")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
            ZStack {
                FoundationTheme.scanBackground
                    .opacity(0.75)
                    .mask(MaskShape(size: Double(frameSize)).fill(style: FillStyle(eoFill: true)))
                ScanFrameCorners()
                    .stroke(FoundationTheme.brandFill, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: frameSize, height: frameSize)
            }
            .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("Close"))
                    .padding(.trailing, -12)
                }
                Text("Scan a QR code")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Point your camera at the code on the partner's site.")
                    .font(.system(size: 16))
                    .foregroundColor(FoundationTheme.scanMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, FoundationTheme.horizontalPadding)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Four rounded green corner brackets marking the scan area.
private struct ScanFrameCorners: Shape {
    var length: CGFloat = 40
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

private struct MaskShape: Shape {
    let size: Double

    func path(in rect: CGRect) -> Path {
        let cgSize = CGSize(width: size, height: size)

        var path = Rectangle().path(in: rect)
        path.addPath(
            RoundedRectangle(cornerRadius: 10)
                .path(in: CGRect(
                    x: rect.midX - cgSize.width / 2,
                    y: rect.midY - cgSize.height / 2,
                    width: size,
                    height: size
                ))
        )

        return path
    }
}

#Preview {
    ScanQRView(onBack: {}, onScan: { _ in })
}
