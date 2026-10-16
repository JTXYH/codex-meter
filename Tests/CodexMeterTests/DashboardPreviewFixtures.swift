import SwiftUI
@testable import CodexMeter

struct DashboardCardStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettings
    let snapshot: CodexUsageSnapshot
    var isPresented = true

    private var visibleSections: [DashboardSection] {
        settings.dashboardSectionOrder.filter(settings.isDashboardSectionVisible)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleSections.enumerated()), id: \.element) { index, section in
                DashboardCard(section: section, snapshot: snapshot)
                    .environment(\.meterCardHasBottomBorder, section != visibleSections.last)
                    .id(section)
                    .modifier(PanelModuleEntrance(isPresented: isPresented, index: index))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: settings.dashboardSectionOrder)
    }
}

/// Used by typography regression checks to render the actual dashboard components.
struct FontCardPreview: View {
    @EnvironmentObject private var settings: AppSettings
    let section: DashboardSection?
    let snapshot: CodexUsageSnapshot
    var body: some View {
        VStack(spacing: 12) {
            ForEach(section.map { [$0] } ?? settings.dashboardSectionOrder.filter { $0 != .quota }) { section in
                DashboardCard(section: section, snapshot: snapshot).accessibilityIdentifier("font-preview-\(section.rawValue)")
            }
        }
    }
}
