import AppKit
import Combine
import SwiftUI

final class OverlayWindowController {
    private let model = RadialOverlayModel()
    private let settingsStore: SettingsStore
    private var settingsCancellable: AnyCancellable?
    private lazy var panel: NSPanel = makePanel()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        model.settings = settingsStore.settings
        settingsCancellable = settingsStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.model.settings = settings
            }
    }

    func show(centeredAt point: NSPoint, layerIndex: Int = 0) {
        model.activeLayerIndex = model.settings.clampedLayerIndex(layerIndex)
        refreshCycleIndices()

        let overlaySize = model.overlaySize
        let origin = NSPoint(
            x: point.x - overlaySize.width / 2,
            y: point.y - overlaySize.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: overlaySize), display: true)
        panel.orderFrontRegardless()
    }

    func setActiveLayer(_ layerIndex: Int) {
        model.activeLayerIndex = model.settings.clampedLayerIndex(layerIndex)
        refreshCycleIndices()
    }

    private func refreshCycleIndices() {
        var cycleIndices: [WheelDirection: Int] = [:]
        for direction in WheelDirection.allCases {
            let slot = model.settings.slot(layerIndex: model.activeLayerIndex, direction: direction)
            cycleIndices[direction] = settingsStore.cycleIndex(forSlotID: slot.id, stepCount: slot.steps.count)
        }
        model.cycleIndices = cycleIndices
    }

    func updateSelection(_ direction: WheelDirection?) {
        model.selectedDirection = direction
    }

    func updateGesture(selection direction: WheelDirection?, dragVector: CGVector) {
        model.selectedDirection = direction
        model.dragVector = dragVector
    }

    func hide() {
        panel.orderOut(nil)
        model.selectedDirection = nil
        model.dragVector = CGVector(dx: 0, dy: 0)
    }

    private func makePanel() -> NSPanel {
        let overlaySize = model.overlaySize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        panel.contentView = NSHostingView(rootView: RadialOverlayView(model: model))
        return panel
    }
}
