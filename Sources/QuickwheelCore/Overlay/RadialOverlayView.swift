import AppKit
import SwiftUI

final class RadialOverlayModel: ObservableObject {
    @Published var selectedDirection: WheelDirection?
    @Published var dragVector = CGVector(dx: 0, dy: 0)
    @Published var settings = QuickwheelSettings.defaults
    @Published var activeLayerIndex = 0
    @Published var cycleIndices: [WheelDirection: Int] = [:]

    var overlaySize: NSSize {
        let canvasSize = RadialOverlayLayout.canvasSize(for: settings.overlaySize)
        return NSSize(width: canvasSize, height: canvasSize)
    }

    func slot(for direction: WheelDirection) -> QuickwheelSlot {
        settings.slot(layerIndex: settings.clampedLayerIndex(activeLayerIndex), direction: direction)
    }

    /// The step that will fire next for this direction, honoring the slot's cycle position.
    func previewAction(for direction: WheelDirection) -> QuickwheelAction {
        let slot = slot(for: direction)
        return slot.step(at: cycleIndices[direction] ?? 0)
    }

    func stepBadge(for direction: WheelDirection) -> String? {
        let slot = slot(for: direction)
        guard slot.steps.count > 1 else { return nil }
        return "\((cycleIndices[direction] ?? 0) + 1)/\(slot.steps.count)"
    }
}

enum RadialOverlayLayout {
    static let edgePadding: CGFloat = 56
    static let selectedScale: CGFloat = 1.05
    static let selectedSlotDelta: CGFloat = 4
    static let slotFrameWidth: CGFloat = 82
    static let selectedLabelFrameHeight: CGFloat = 76
    static let maxShadowRadius: CGFloat = 14
    static let minimumSafeMargin: CGFloat = 12

    static func canvasSize(for wheelSize: CGFloat) -> CGFloat {
        wheelSize + edgePadding * 2
    }

    static func slotDiameter(for wheelSize: CGFloat) -> CGFloat {
        min(max(wheelSize * 0.25, 42), 54)
    }

    static func joystickDiameter(for wheelSize: CGFloat) -> CGFloat {
        min(max(wheelSize * 0.26, 42), 54)
    }

    static func slotOffset(
        wheelSize: CGFloat,
        selectedSlotDiameter: CGFloat,
        joystickDiameter: CGFloat
    ) -> CGFloat {
        let proportionalOffset = wheelSize * 0.32
        let gap = min(max(wheelSize * 0.07, 11), 18)
        let nonOverlappingOffset = joystickDiameter / 2 + selectedSlotDiameter / 2 + gap
        return max(proportionalOffset, nonOverlappingOffset)
    }

    static func joystickTravelRadius(
        wheelSize: CGFloat,
        slotOffset: CGFloat,
        selectedSlotDiameter: CGFloat,
        joystickDiameter: CGFloat
    ) -> CGFloat {
        let proportionalTravel = wheelSize * 0.18
        let collisionLimitedTravel = slotOffset - selectedSlotDiameter / 2 - joystickDiameter / 2 - 6
        return max(min(proportionalTravel, collisionLimitedTravel), wheelSize * 0.1)
    }

    static func edgeMargin(wheelSize: CGFloat, labelsVisible: Bool) -> CGFloat {
        let slotDiameter = slotDiameter(for: wheelSize)
        let selectedSlotDiameter = slotDiameter + selectedSlotDelta
        let joystickDiameter = joystickDiameter(for: wheelSize)
        let slotOffset = slotOffset(
            wheelSize: wheelSize,
            selectedSlotDiameter: selectedSlotDiameter,
            joystickDiameter: joystickDiameter
        )
        let frameHeight = labelsVisible ? selectedLabelFrameHeight : selectedSlotDiameter
        let frameHalfExtent = max(slotFrameWidth, frameHeight) * selectedScale / 2
        let visualExtent = slotOffset + frameHalfExtent + maxShadowRadius
        return canvasSize(for: wheelSize) / 2 - visualExtent
    }
}

struct RadialOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: RadialOverlayModel

    var body: some View {
        ZStack {
            joystickStem

            directionSlot(.up)
                .offset(y: -slotOffset)
            directionSlot(.down)
                .offset(y: slotOffset)
            directionSlot(.left)
                .offset(x: -slotOffset)
            directionSlot(.right)
                .offset(x: slotOffset)

            joystickPuck
        }
        .frame(width: model.overlaySize.width, height: model.overlaySize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var wheelSize: CGFloat {
        model.settings.overlaySize
    }

    private var slotOffset: CGFloat {
        RadialOverlayLayout.slotOffset(
            wheelSize: wheelSize,
            selectedSlotDiameter: selectedSlotDiameter,
            joystickDiameter: joystickDiameter
        )
    }

    private var slotDiameter: CGFloat {
        RadialOverlayLayout.slotDiameter(for: wheelSize)
    }

    private var selectedSlotDiameter: CGFloat {
        slotDiameter + RadialOverlayLayout.selectedSlotDelta
    }

    private var joystickDiameter: CGFloat {
        RadialOverlayLayout.joystickDiameter(for: wheelSize)
    }

    private var joystickIconSize: CGFloat {
        min(max(wheelSize * 0.11, 17), 22)
    }

    private var showsLayerIndicator: Bool {
        model.activeLayerIndex > 0 || model.settings.usesMultipleLayers
    }

    private var joystickTravelRadius: CGFloat {
        RadialOverlayLayout.joystickTravelRadius(
            wheelSize: wheelSize,
            slotOffset: slotOffset,
            selectedSlotDiameter: selectedSlotDiameter,
            joystickDiameter: joystickDiameter
        )
    }

    @ViewBuilder
    private var joystickStem: some View {
        if dragLength > 1 {
            let selected = model.selectedDirection != nil

            Path { path in
                path.move(to: centerPoint)
                path.addLine(to: joystickPoint)
            }
            .stroke(
                selected ? Color.accentColor.opacity(0.65) : Color.white.opacity(0.36),
                style: StrokeStyle(lineWidth: selected ? 3 : 2, lineCap: .round)
            )
            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: model.dragVector.dx)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: model.dragVector.dy)
        }
    }

    private var joystickPuck: some View {
        let selected = model.selectedDirection != nil

        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(selected ? Color.accentColor.opacity(0.58) : Color.black.opacity(0.18))

            Circle()
                .strokeBorder(
                    selected ? Color.white.opacity(0.62) : Color.white.opacity(0.18),
                    lineWidth: 1
                )

            Image(systemName: QuickwheelSymbol.validatedName(model.settings.centerSymbolName, fallback: "command"))
                .font(.system(size: joystickIconSize, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 0.96 : 0.78))

            if showsLayerIndicator {
                VStack {
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(model.settings.layers.indices, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == model.activeLayerIndex
                                        ? Color.white.opacity(0.95)
                                        : Color.white.opacity(0.32)
                                )
                                .frame(width: 3.5, height: 3.5)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(width: joystickDiameter, height: joystickDiameter)
        .shadow(color: .black.opacity(0.26), radius: 14, y: 8)
        .offset(x: joystickOffset.dx, y: joystickOffset.dy)
        .scaleEffect(selected ? 1.04 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: model.dragVector.dx)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: model.dragVector.dy)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: selected)
    }

    private var centerPoint: CGPoint {
        CGPoint(x: model.overlaySize.width / 2, y: model.overlaySize.height / 2)
    }

    private var dragLength: CGFloat {
        hypot(model.dragVector.dx, model.dragVector.dy)
    }

    private var joystickOffset: CGVector {
        let dx = model.dragVector.dx
        let dy = -model.dragVector.dy
        let length = max(hypot(dx, dy), 1)
        let radius = min(length, joystickTravelRadius)

        return CGVector(
            dx: dx / length * radius,
            dy: dy / length * radius
        )
    }

    private var joystickPoint: CGPoint {
        CGPoint(
            x: centerPoint.x + joystickOffset.dx,
            y: centerPoint.y + joystickOffset.dy
        )
    }

    private func directionSlot(_ direction: WheelDirection) -> some View {
        let selected = model.selectedDirection == direction
        let action = model.previewAction(for: direction)
        let stepBadge = model.stepBadge(for: direction)
        let diameter = selected ? selectedSlotDiameter : slotDiameter

        return VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.72) : Color.black.opacity(0.14))

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        selected ? Color.white.opacity(0.58) : Color.white.opacity(0.14),
                        lineWidth: 1
                    )

                QuickwheelActionIconView(
                    action: action,
                    direction: direction,
                    isSelected: selected,
                    size: diameter * 0.52
                )
            }
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .bottomTrailing) {
                if let stepBadge {
                    Text(stepBadge)
                        .font(.system(size: 8, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .offset(x: 4, y: 4)
                }
            }
            .shadow(
                color: selected ? Color.accentColor.opacity(0.34) : Color.black.opacity(0.18),
                radius: selected ? 12 : 8,
                y: selected ? 5 : 4
            )

            if model.settings.showOverlayLabels, selected {
                Text(action.resolvedTitle(fallback: direction))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 72)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.32), radius: 3, y: 1)
            }
        }
        .frame(
            width: RadialOverlayLayout.slotFrameWidth,
            height: model.settings.showOverlayLabels ? RadialOverlayLayout.selectedLabelFrameHeight : selectedSlotDiameter
        )
        .scaleEffect(selected ? RadialOverlayLayout.selectedScale : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: selected)
    }

    private var accessibilityLabel: String {
        if let selectedDirection = model.selectedDirection {
            return "Quickwheel, \(selectedDirection.displayName) selected"
        }

        return "Quickwheel, no direction selected"
    }
}

private struct QuickwheelActionIconView: View {
    let action: QuickwheelAction
    let direction: WheelDirection
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if let image = QuickwheelActionIconResolver.image(for: action) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: max(size * 0.18, 4), style: .continuous))
            } else {
                Image(systemName: QuickwheelActionIconResolver.symbolName(for: action, fallback: direction))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.86))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.04 : 1)
    }
}
