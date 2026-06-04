import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class InputController {
    private let overlayController: OverlayWindowController
    private let settingsStore: SettingsStore
    private let actionRunner: ActionRunner

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var heldModifierKeyCodes = Set<Int64>()
    private var heldDigitKeyCode: Int64?
    private var activeLayerIndex = 0
    private var menuCenter: CGPoint?
    private var currentDirection: WheelDirection?

    private static let layerDigitKeyCodes: [Int64: Int] = [
        Int64(kVK_ANSI_1): 1,
        Int64(kVK_ANSI_2): 2,
        Int64(kVK_ANSI_3): 3
    ]

    static func layerIndex(forHeldDigit digit: Int?, layerCount: Int) -> Int {
        guard let digit, layerCount > 0 else { return 0 }
        return min(max(digit - 1, 0), layerCount - 1)
    }

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    init(
        overlayController: OverlayWindowController,
        settingsStore: SettingsStore,
        actionRunner: ActionRunner
    ) {
        self.overlayController = overlayController
        self.settingsStore = settingsStore
        self.actionRunner = actionRunner
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return isRunning
        }

        let eventMask =
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.mouseMoved.rawValue) |
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        heldModifierKeyCodes.removeAll()
        heldDigitKeyCode = nil
        resetGestureState()
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> CGEvent? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            // Key-up events may have been dropped while the tap was disabled.
            heldModifierKeyCodes.removeAll()
            heldDigitKeyCode = nil
            return event

        case .flagsChanged:
            updateModifierState(with: event)
            return event

        case .leftMouseDown:
            guard settingsStore.settings.isEnabled, triggerModifierIsDown else { return event }
            beginGesture(at: MouseCoordinateConverter.appKitLocation(from: event))
            return nil

        case .leftMouseDragged, .mouseMoved:
            guard menuCenter != nil else { return event }
            updateGesture(at: MouseCoordinateConverter.appKitLocation(from: event))
            return nil

        case .leftMouseUp:
            guard menuCenter != nil else { return event }
            completeGesture(at: MouseCoordinateConverter.appKitLocation(from: event))
            return nil

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            guard menuCenter != nil else {
                // Record (never swallow) layer digits held alongside the
                // trigger modifier so the next click opens that layer.
                if Self.layerDigitKeyCodes[keyCode] != nil, triggerModifierIsDown {
                    heldDigitKeyCode = keyCode
                }
                return event
            }

            if keyCode == kVK_Escape {
                cancelGesture()
            }
            return nil

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == heldDigitKeyCode {
                heldDigitKeyCode = nil
            }
            return event

        default:
            return event
        }
    }

    private var triggerModifierIsDown: Bool {
        let matchingKeyCodes = settingsStore.settings.triggerModifier.matchingKeyCodes

        if matchingKeyCodes.contains(where: { keyCode in
            CGEventSource.keyState(.hidSystemState, key: CGKeyCode(clamping: keyCode))
        }) {
            return true
        }

        return !heldModifierKeyCodes.isDisjoint(with: matchingKeyCodes)
    }

    private func updateModifierState(with event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard TriggerModifier.allKeyCodes.contains(keyCode) else {
            return
        }

        guard modifierFamilyIsActive(keyCode: keyCode, flags: event.flags) else {
            heldModifierKeyCodes.remove(keyCode)
            return
        }

        if CGEventSource.keyState(.hidSystemState, key: CGKeyCode(clamping: keyCode)) {
            heldModifierKeyCodes.insert(keyCode)
        } else {
            heldModifierKeyCodes.remove(keyCode)
        }

        if !triggerModifierIsDown {
            heldDigitKeyCode = nil
        }
    }

    private func modifierFamilyIsActive(keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand:
            flags.contains(.maskCommand)
        case kVK_Option, kVK_RightOption:
            flags.contains(.maskAlternate)
        case kVK_Control, kVK_RightControl:
            flags.contains(.maskControl)
        case kVK_Shift, kVK_RightShift:
            flags.contains(.maskShift)
        default:
            false
        }
    }

    private func beginGesture(at location: CGPoint) {
        menuCenter = location
        currentDirection = nil
        let heldDigit = heldDigitKeyCode.flatMap { Self.layerDigitKeyCodes[$0] }
        activeLayerIndex = Self.layerIndex(
            forHeldDigit: heldDigit,
            layerCount: settingsStore.settings.layers.count
        )
        overlayController.show(centeredAt: location, layerIndex: activeLayerIndex)
        overlayController.updateGesture(
            selection: nil,
            dragVector: CGVector(dx: 0, dy: 0)
        )
    }

    private func updateGesture(at location: CGPoint) {
        guard let center = menuCenter else { return }
        let resolver = DirectionResolver(deadZoneRadius: CGFloat(settingsStore.settings.deadZoneRadius))
        let direction = resolver.direction(from: center, to: location)
        let dragVector = CGVector(
            dx: location.x - center.x,
            dy: location.y - center.y
        )

        currentDirection = direction
        overlayController.updateGesture(selection: direction, dragVector: dragVector)
    }

    private func completeGesture(at location: CGPoint) {
        updateGesture(at: location)

        let directionToRun = currentDirection
        let layerIndex = activeLayerIndex
        resetGestureState()

        guard let direction = directionToRun else { return }
        let slot = settingsStore.settings.slot(layerIndex: layerIndex, direction: direction)
        let stepIndex = settingsStore.advanceCycle(forSlotID: slot.id, stepCount: slot.steps.count)
        actionRunner.run(slot.step(at: stepIndex))
    }

    private func cancelGesture() {
        resetGestureState()
    }

    private func resetGestureState() {
        menuCenter = nil
        currentDirection = nil
        overlayController.hide()
    }
}

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<InputController>.fromOpaque(userInfo).takeUnretainedValue()
    guard let returnedEvent = controller.handle(proxy: proxy, type: type, event: event) else {
        return nil
    }

    return Unmanaged.passUnretained(returnedEvent)
}
