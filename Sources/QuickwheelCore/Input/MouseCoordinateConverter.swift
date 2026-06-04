import AppKit
import CoreGraphics

enum MouseCoordinateConverter {
    static func appKitLocation(from event: CGEvent) -> CGPoint {
        appKitPoint(
            fromQuartzPoint: event.location,
            screenFrames: NSScreen.screens.map(\.frame)
        )
    }

    static func appKitPoint(fromQuartzPoint quartzPoint: CGPoint, screenFrames: [CGRect]) -> CGPoint {
        // Quartz global coordinates originate at the top-left of the primary
        // screen; AppKit at its bottom-left. Flip against the primary screen
        // frame (origin at (0, 0)), never the union of all screens - a taller
        // secondary display would otherwise shift every converted point.
        let primaryFrame = screenFrames.first { $0.origin == .zero } ?? screenFrames.first

        guard let primaryFrame else {
            return quartzPoint
        }

        return CGPoint(
            x: quartzPoint.x,
            y: primaryFrame.maxY - quartzPoint.y
        )
    }
}
