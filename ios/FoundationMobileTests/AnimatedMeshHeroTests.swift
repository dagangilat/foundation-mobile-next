import SwiftUI
import XCTest
@testable import FoundationMobile

final class AnimatedMeshHeroTests: XCTestCase {
    func testMeshPointsKeepCornersPinnedAtAnyTime() {
        for t: TimeInterval in [0.0, 5.0, 12.3, 100.0] {
            let points = AnimatedMeshHero<EmptyView>.meshPoints(at: t)
            XCTAssertEqual(points.count, 9)
            XCTAssertEqual(points[0], SIMD2<Float>(0, 0), "top-left corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[2], SIMD2<Float>(1, 0), "top-right corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[6], SIMD2<Float>(0, 1), "bottom-left corner must stay pinned at t=\(t)")
            XCTAssertEqual(points[8], SIMD2<Float>(1, 1), "bottom-right corner must stay pinned at t=\(t)")
        }
    }

    func testMeshColorsPlacesBlobsAtTheFourEdgeMidpoints() {
        let base = Color.white
        let blobs = [Color.red, Color.green, Color.blue, Color.yellow]
        let colors = AnimatedMeshHero<EmptyView>.meshColors(base: base, blobs: blobs)
        XCTAssertEqual(colors.count, 9)
        XCTAssertEqual(colors[1], .red)    // top-mid
        XCTAssertEqual(colors[3], .green)  // mid-left
        XCTAssertEqual(colors[5], .blue)   // mid-right
        XCTAssertEqual(colors[7], .yellow) // bottom-mid
        XCTAssertEqual(colors[0], base)
        XCTAssertEqual(colors[4], base)
        XCTAssertEqual(colors[8], base)
    }

    func testAngledCutShapeStaysWithinItsRect() {
        let shape = AngledCutShape()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let path = shape.path(in: rect)
        XCTAssertEqual(path.boundingRect.minX, 0, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.maxX, 300, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.minY, 0, accuracy: 0.01)
        XCTAssertEqual(path.boundingRect.maxY, 200, accuracy: 0.01)
    }
}
