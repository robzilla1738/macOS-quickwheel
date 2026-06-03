import CoreGraphics
import Foundation

struct DirectionResolver {
    let deadZoneRadius: CGFloat

    func direction(from center: CGPoint, to pointer: CGPoint) -> WheelDirection? {
        let dx = pointer.x - center.x
        let dy = pointer.y - center.y
        let distance = hypot(dx, dy)

        guard distance >= deadZoneRadius else {
            return nil
        }

        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        }

        return dy < 0 ? .down : .up
    }
}
