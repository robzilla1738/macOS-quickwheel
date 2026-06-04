import XCTest
@testable import QuickwheelCore

final class DirectionResolverTests: XCTestCase {
    func testReturnsNilInsideDeadZone() {
        let resolver = DirectionResolver(deadZoneRadius: 36)

        XCTAssertNil(resolver.direction(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 120, y: 100)))
    }

    func testResolvesCardinalDirections() {
        let resolver = DirectionResolver(deadZoneRadius: 36)
        let center = CGPoint(x: 100, y: 100)

        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 100, y: 160)), .up)
        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 100, y: 40)), .down)
        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 40, y: 100)), .left)
        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 160, y: 100)), .right)
    }

    func testDominantAxisWins() {
        let resolver = DirectionResolver(deadZoneRadius: 10)
        let center = CGPoint(x: 0, y: 0)

        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 40, y: 20)), .right)
        XCTAssertEqual(resolver.direction(from: center, to: CGPoint(x: 20, y: 40)), .up)
    }

    func testConvertsQuartzMouseLocationToAppKitCoordinates() {
        let convertedPoint = MouseCoordinateConverter.appKitPoint(
            fromQuartzPoint: CGPoint(x: 88.95703125, y: 425.06640625),
            screenFrames: [CGRect(x: 0, y: 0, width: 1728, height: 1117)]
        )

        XCTAssertEqual(convertedPoint.x, 88.95703125, accuracy: 0.001)
        XCTAssertEqual(convertedPoint.y, 691.93359375, accuracy: 0.001)
    }

    func testConversionFlipsAgainstPrimaryScreenNotDesktopUnion() {
        // A taller secondary display extending above the primary must not
        // shift the converted point (regression: overlay opened above clicks).
        let primaryFrame = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let tallerSecondaryFrame = CGRect(x: 1728, y: -100, width: 3440, height: 1440)

        let convertedPoint = MouseCoordinateConverter.appKitPoint(
            fromQuartzPoint: CGPoint(x: 400, y: 500),
            screenFrames: [primaryFrame, tallerSecondaryFrame]
        )

        XCTAssertEqual(convertedPoint.y, 1117 - 500, accuracy: 0.001)

        // Same result regardless of screen ordering.
        let reorderedPoint = MouseCoordinateConverter.appKitPoint(
            fromQuartzPoint: CGPoint(x: 400, y: 500),
            screenFrames: [tallerSecondaryFrame, primaryFrame]
        )

        XCTAssertEqual(reorderedPoint.y, 1117 - 500, accuracy: 0.001)
    }
}
