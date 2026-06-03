import XCTest
@testable import QuickwheelCore

final class RadialOverlayLayoutTests: XCTestCase {
    func testOverlayCanvasLeavesEdgeMarginAtSupportedSizes() {
        for wheelSize in [144.0, 184.0, 260.0] {
            XCTAssertGreaterThanOrEqual(
                RadialOverlayLayout.edgeMargin(wheelSize: wheelSize, labelsVisible: false),
                RadialOverlayLayout.minimumSafeMargin,
                "Wheel size \(wheelSize) should not clip icon-only slots."
            )
            XCTAssertGreaterThanOrEqual(
                RadialOverlayLayout.edgeMargin(wheelSize: wheelSize, labelsVisible: true),
                RadialOverlayLayout.minimumSafeMargin,
                "Wheel size \(wheelSize) should not clip selected labels."
            )
        }
    }

    func testOverlayCanvasIsLargerThanConfiguredWheelSize() {
        XCTAssertEqual(
            RadialOverlayLayout.canvasSize(for: 184),
            184 + RadialOverlayLayout.edgePadding * 2
        )
    }
}
