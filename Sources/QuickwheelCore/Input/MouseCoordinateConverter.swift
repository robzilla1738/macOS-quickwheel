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
        let desktopFrame = screenFrames.reduce(CGRect.null) { partialResult, frame in
            partialResult.union(frame)
        }

        guard !desktopFrame.isNull else {
            return quartzPoint
        }

        return CGPoint(
            x: quartzPoint.x,
            y: desktopFrame.maxY - quartzPoint.y
        )
    }
}
