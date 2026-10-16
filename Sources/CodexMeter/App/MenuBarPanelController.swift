import AppKit
import Combine
import SwiftUI

/// Owns both ways of opening the same panel: the status item and Settings.
@MainActor
final class MenuBarPanelController: NSObject {
    static let shared = MenuBarPanelController()

    private let store = UsageStore.shared
    private let settings = AppSettings.shared
    private var statusItem: NSStatusItem?
    private var labelView: StatusItemLabelView?
    private var panel: MenuBarPanel?
    private var subscriptions = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var deactivationObserver: NSObjectProtocol?
    private let presentation = PanelPresentationState(isPresented: false)
    private var animationTimer: Timer?
    private var restingFrame: NSRect?

    private override init() { super.init() }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "CodexMeter.StatusItem"
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.setAccessibilityLabel("Codex Meter")
        let label = StatusItemLabelView(rootView: makeLabel())
        label.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        labelView = label
        appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.updateLabel() }
        }
        updateLabel()
        Publishers.Merge(store.objectWillChange, settings.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }
            .store(in: &subscriptions)
        store.startIfNeeded()
    }

    func showPanel() {
        start()
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let popup = panel ?? makePanel()
        panel = popup
        if presentation.isPresented, popup.isVisible {
            NSApplication.shared.activate(ignoringOtherApps: true)
            popup.makeKeyAndOrderFront(nil)
            return
        }
        stopWindowAnimation()
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let frame = screen.map { MenuBarPanelPosition.frame(anchor: anchor, screen: $0.frame) } ?? popup.frame
        restingFrame = frame
        presentation.anchorX = min(1, max(0, (anchor.midX - frame.minX) / frame.width))
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !popup.isVisible {
            presentation.isPresented = false
            popup.setFrame(frame.offsetBy(dx: 0, dy: reduceMotion ? 0 : 6), display: false)
            popup.alphaValue = 0
        } else if reduceMotion {
            // Finish any previous movement immediately if the preference changed.
            popup.setFrameOrigin(frame.origin)
        }
        if popup.contentView == nil {
            popup.contentView = NSHostingView(rootView: MeterPanelView(presentation: presentation)
                .environmentObject(store).environmentObject(settings))
        }
        popup.ignoresMouseEvents = false
        NSApplication.shared.activate(ignoringOtherApps: true)
        popup.makeKeyAndOrderFront(nil)
        popup.contentView?.layoutSubtreeIfNeeded()
        let generation = presentation.beginTransition(isPresented: true)
        button.highlight(true)
        installDismissalObservers()
        animateWindow(popup, restingOrigin: frame.origin, reduceMotion: reduceMotion,
                      generation: generation, isPresented: true)
    }

    func closePanel() {
        statusItem?.button?.highlight(false)
        removeDismissalObservers()
        guard presentation.isPresented, let popup = panel else { return }
        stopWindowAnimation()
        let generation = presentation.beginTransition(isPresented: false)
        // A closing window must not intercept the click that opens another app.
        popup.ignoresMouseEvents = true
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        animateWindow(popup, restingOrigin: (restingFrame ?? popup.frame).origin, reduceMotion: reduceMotion,
                      generation: generation, isPresented: false)
    }

    @objc private func togglePanel() {
        if presentation.isPresented { closePanel() }
        else { showPanel() }
    }

    private func animateWindow(
        _ popup: MenuBarPanel, restingOrigin: NSPoint, reduceMotion: Bool,
        generation: UInt64, isPresented: Bool
    ) {
        let motion = PanelWindowMotion.visibility(
            isPresented,
            from: .init(origin: popup.frame.origin, opacity: popup.alphaValue),
            restingOrigin: restingOrigin, reduceMotion: reduceMotion,
            startedAt: ProcessInfo.processInfo.systemUptime
        )
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self, weak popup] timer in
            MainActor.assumeIsolated {
                guard let self, let popup,
                      self.presentation.isCurrent(generation, isPresented: isPresented)
                else { timer.invalidate(); return }
                let now = ProcessInfo.processInfo.systemUptime
                let sample = motion.sample(at: now)
                popup.setFrameOrigin(sample.origin)
                popup.alphaValue = sample.opacity
                guard motion.isComplete(at: now) else { return }
                self.stopWindowAnimation()
                if !isPresented {
                    popup.orderOut(nil)
                    // Only this completed closing generation may release the view.
                    // A quick reopening reuses it and cancels the old transition.
                    popup.contentView = nil
                }
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopWindowAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func makeLabel() -> AnyView {
        AnyView(MenuBarLabelView().environmentObject(store).environmentObject(settings).accessibilityHidden(true))
    }

    private func updateLabel() {
        guard let labelView, let button = statusItem?.button else { return }
        labelView.appearance = button.effectiveAppearance
        labelView.rootView = makeLabel()
        labelView.layoutSubtreeIfNeeded()
        statusItem?.length = ceil(labelView.fittingSize.width)
        button.toolTip = store.refreshErrorMessage ?? L10n.text(.menuBarHelp, language: settings.language)
        button.setAccessibilityValue(store.menuBarRemainingPercent.map {
            L10n.remaining(Int($0.rounded()), language: settings.language)
        } ?? L10n.text(.notAvailable, language: settings.language))
    }

    private func makePanel() -> MenuBarPanel {
        let popup = MenuBarPanel(contentRect: NSRect(origin: .zero, size: MenuBarPanelPosition.size),
                                 styleMask: [.borderless], backing: .buffered, defer: false)
        popup.title = "Codex Meter"
        popup.contentView = nil
        popup.isReleasedWhenClosed = false
        popup.isFloatingPanel = true
        popup.level = .popUpMenu
        popup.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        popup.backgroundColor = .clear
        popup.isOpaque = false
        popup.hasShadow = true
        popup.animationBehavior = .none
        popup.dismiss = { [weak self] in self?.closePanel() }
        return popup
    }

    private func installDismissalObservers() {
        guard localEventMonitor == nil else { return }
        let generation = presentation.generation
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.presentation.isCurrent(generation, isPresented: true) else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.closePanel(); return nil }
                return event
            }
            let point = NSEvent.mouseLocation
            if self.panel?.frame.contains(point) == true || self.statusButtonContains(point) { return event }
            self.closePanel()
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.presentation.isCurrent(generation, isPresented: true) else { return }
            self.closePanel()
        }
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApplication.shared, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.presentation.isCurrent(generation, isPresented: true) else { return }
                self.closePanel()
            }
        }
    }

    private func statusButtonContains(_ point: NSPoint) -> Bool {
        guard let button = statusItem?.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point)
    }

    private func removeDismissalObservers() {
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
        if let deactivationObserver { NotificationCenter.default.removeObserver(deactivationObserver) }
        localEventMonitor = nil
        globalEventMonitor = nil
        deactivationObserver = nil
    }
}

enum MenuBarPanelPosition {
    static let size = NSSize(width: 420, height: 700)

    static func frame(anchor: NSRect, screen: NSRect) -> NSRect {
        NSRect(x: min(max(anchor.midX - size.width / 2, screen.minX), screen.maxX - size.width),
               y: max(screen.minY, min(anchor.minY, screen.maxY) - size.height),
               width: size.width, height: size.height)
    }
}

private final class StatusItemLabelView: NSHostingView<AnyView> {
    // The actual status-bar button receives all clicks, including over the label.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class MenuBarPanel: NSPanel {
    var dismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
    override func performClose(_ sender: Any?) { dismiss?() }
}
