import AppKit
import SwiftUI

struct MonthlyRangePopover: View {
    @Environment(\.meterFontSizes) private var fontSizes
    let selection: Int
    let language: AppLanguage
    var period: UsagePeriod = .month
    let onSelect: (Int) -> Void
    @State private var hoveredRange: Int?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(period.ranges, id: \.self) { count in
                let isSelected = selection == count
                Button {
                    onSelect(count)
                } label: {
                    HStack(spacing: 8) {
                        Text(UsageStatisticsL10n.range(count, period: period, language: language))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "checkmark")
                            .frame(width: 12)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .meterText(.detail)
                    .foregroundStyle(isSelected ? Color.meterAccent : Color.meterPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 33)
                    .background(
                        isSelected ? Color.meterAccent.opacity(0.10)
                            : hoveredRange == count ? Color.meterControl : .clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hoveredRange = $0 ? count : nil }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(5)
        .frame(width: popoverWidth)
        .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.meterBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.13), radius: 13, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text(.monthlyUsageRange, language: language))
    }

    private var popoverWidth: CGFloat {
        let longestLabel = period.ranges.map {
            (UsageStatisticsL10n.range($0, period: period, language: language) as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: CGFloat(fontSizes.detail))]
            ).width
        }.max() ?? 0
        return max(146, ceil(longestLabel) + 50)
    }
}

/// Installed only while the in-card popover is visible. Outside clicks still reach
/// their normal target; clicks on the trigger are left to the trigger's toggle.
struct MonthlyRangeDismissObserver: NSViewRepresentable {
    let triggerSize: CGSize
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(triggerSize: triggerSize, onDismiss: onDismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDismiss = onDismiss
        context.coordinator.triggerSize = triggerSize
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        weak var view: NSView?
        var triggerSize: CGSize
        var onDismiss: () -> Void
        private var eventMonitor: Any?
        private var keyWindowObserver: NSObjectProtocol?

        init(triggerSize: CGSize, onDismiss: @escaping () -> Void) {
            self.triggerSize = triggerSize
            self.onDismiss = onDismiss
        }

        func start() {
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
            ) { [weak self] event in
                guard let self, let view = self.view, let window = view.window else { return event }
                if event.type == .keyDown {
                    guard event.keyCode == 53 else { return event }
                    self.onDismiss()
                    return nil
                }
                if event.type == .scrollWheel {
                    self.onDismiss()
                    return event
                }
                let point = view.convert(event.locationInWindow, from: nil)
                let insidePopup = event.window === window && view.bounds.contains(point)
                // The trigger shares the popover's trailing edge and sits seven
                // points above it. Use its measured SwiftUI size: transparent
                // NSView anchors can have zero-sized bounds after a state update.
                let triggerRect = CGRect(
                    x: view.bounds.maxX - self.triggerSize.width,
                    y: view.isFlipped
                        ? view.bounds.minY - 7 - self.triggerSize.height
                        : view.bounds.maxY + 7,
                    width: self.triggerSize.width,
                    height: self.triggerSize.height
                )
                let insideTrigger = event.window === window && triggerRect.contains(point)
                if !insidePopup && !insideTrigger { self.onDismiss() }
                return event
            }
            keyWindowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
            ) { [weak self] notification in
                guard let self, let window = self.view?.window,
                      notification.object as? NSWindow === window else { return }
                self.onDismiss()
            }
        }

        func stop() {
            if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
            if let keyWindowObserver { NotificationCenter.default.removeObserver(keyWindowObserver) }
            eventMonitor = nil
            keyWindowObserver = nil
        }

        deinit { stop() }
    }
}
