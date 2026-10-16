import SwiftUI

/// Panel layout is independent from the application's light/dark appearance.
enum PanelTheme: String, CaseIterable, Identifiable, Sendable {
    case quiet
    case instrument

    var id: String { rawValue }
    var isInstrument: Bool { self == .instrument }
    var accent: Color { isInstrument ? .meterInstrumentAccent : .meterAccent }
    var accentSoft: Color { isInstrument ? .meterInstrumentAccentSoft : .meterAccentSoft }
    var cardPadding: CGFloat { 15 }
}
