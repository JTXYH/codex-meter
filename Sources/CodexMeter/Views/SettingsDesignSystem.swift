import AppKit
import SwiftUI

/// Neutral and semantic settings colors stay consistent across panel themes.
enum SettingsPalette {
    static let danger = adaptive(0xC45447, 0xE79B90)
    static let success = adaptive(0x368B73, 0x80C6B0)
    static func primaryButtonText(for theme: PanelTheme) -> Color {
        adaptive(0xFFFFFF, theme.isInstrument ? 0x173A33 : 0x242136)
    }

    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct SettingsCard<Content: View>: View {
    var radius: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(1)
            .frame(maxWidth: .infinity)
            .background(Color.meterPanel, in: RoundedRectangle(cornerRadius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.meterBorder, lineWidth: 1))
    }
}

struct SettingsDivider: View {
    var body: some View { Rectangle().fill(Color.meterBorder).frame(height: 1) }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).frame(minHeight: 19.5)
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 11))
                        .foregroundStyle(Color.meterSecondary)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true).frame(minHeight: 18)
                }
            }
            Spacer(minLength: 0)
            control
        }
        .padding(18)
        .frame(minHeight: 82)
    }
}

struct SettingsButtonStyle: ButtonStyle {
    @Environment(\.meterTheme) private var theme
    enum Kind { case normal, primary, danger, link }
    var kind: Kind = .normal
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .link ? 0 : 14)
            .padding(.vertical, kind == .link ? 0 : 7)
            .frame(minHeight: kind == .link ? 0 : 32.5)
            .background(background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(border, lineWidth: 1))
            .opacity(isEnabled ? configuration.isPressed ? 0.75 : 1 : 0.4)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .normal: .meterPrimary
        case .primary: SettingsPalette.primaryButtonText(for: theme)
        case .danger: SettingsPalette.danger
        case .link: theme.accent
        }
    }
    private var background: Color {
        switch kind {
        case .normal: .meterCard
        case .primary: theme.accent
        case .danger: SettingsPalette.danger.opacity(0.07)
        case .link: .clear
        }
    }
    private var border: Color {
        switch kind {
        case .normal: .meterBorder
        case .primary: theme.accent
        case .danger: SettingsPalette.danger.opacity(0.2)
        case .link: .clear
        }
    }
}

struct SettingsSelect<Value: Hashable>: View {
    @Environment(\.meterTheme) private var theme
    let title: String
    @Binding var selection: Value
    let options: [Value]
    var width: CGFloat? = 175
    var size: CGFloat = 11
    var optionTitle: (Value) -> String
    @State private var isPresented = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 4) {
                Text(optionTitle(selection)).lineLimit(1).layoutPriority(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 9)).fixedSize()
            }
            .font(.system(size: size)).foregroundStyle(Color.meterPrimary)
            .padding(.horizontal, 9)
            .frame(width: width, height: size == 10 ? 29 : 32)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(optionTitle(selection))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 3) {
                ForEach(options, id: \.self) { item in
                    Button { selection = item; isPresented = false } label: {
                        HStack(spacing: 10) {
                            Text(optionTitle(item)).font(.system(size: 11))
                            Spacer(minLength: 4)
                            Image(systemName: "checkmark").font(.system(size: 10))
                                .foregroundStyle(theme.accent).opacity(item == selection ? 1 : 0)
                        }
                        .padding(.horizontal, 10).frame(minHeight: 30).contentShape(Rectangle())
                        .background(item == selection ? theme.accentSoft : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)
                }
            }.padding(7).frame(minWidth: max(160, width ?? 175)).background(Color.meterCard)
        }
    }
}

struct SettingsSlider: View {
    @Environment(\.meterTheme) private var theme
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    let label: String
    @Environment(\.isEnabled) private var isEnabled

    private var fraction: Double { min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound))) }
    private func adjust(_ delta: Double) { value = min(range.upperBound, max(range.lowerBound, value + delta)) }

    var body: some View {
        GeometryReader { proxy in
            let span = max(1, proxy.size.width - 14)
            ZStack(alignment: .leading) {
                Capsule().fill(SettingsPalette.adaptive(0xF5F5F5, 0x39393F))
                    .overlay(Capsule().strokeBorder(SettingsPalette.adaptive(0xC6C6C6, 0x6B6B76), lineWidth: 1))
                    .frame(height: 8)
                Capsule().fill(theme.accent).frame(width: 7 + span * fraction, height: 8)
                Circle().fill(theme.accent).frame(width: 14, height: 14).offset(x: span * fraction)
            }
            .frame(height: 18).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                guard isEnabled else { return }
                let ratio = min(1, max(0, (event.location.x - 7) / span))
                let proposed = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                value = min(range.upperBound, max(range.lowerBound, (proposed / step).rounded() * step))
            })
        }
        .frame(height: 18)
        .offset(x: 2)
        .focusable(isEnabled)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .left, .down: adjust(-step)
            case .right, .up: adjust(step)
            default: break
            }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(value.formatted(.number.precision(.fractionLength(0...1))))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(step)
            case .decrement: adjust(-step)
            @unknown default: break
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct SettingsSwitchStyle: ToggleStyle {
    @Environment(\.meterTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(configuration.isOn ? theme.accent : Color.meterBorder)
                .frame(width: 31, height: 19)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 1).padding(2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: Binding(get: { configuration.isOn }, set: { configuration.isOn = $0 })) {
                configuration.label
            }
            .toggleStyle(.switch)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isOn)
    }
}

struct SettingsNote: View {
    @Environment(\.meterTheme) private var theme
    let text: String
    var symbol = "arrow.up.right"
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(theme.accent)
            Text(text).font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(2)
    }
}

struct SettingsNumberField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 78

    var body: some View {
        TextField(title, value: $value, format: .number.grouping(.never))
            .textFieldStyle(.plain)
            .font(.system(size: 11)).monospacedDigit().multilineTextAlignment(.trailing)
            .padding(.horizontal, 9).frame(width: width, height: 32)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
            .onSubmit { value = min(range.upperBound, max(range.lowerBound, value)) }
            .onChange(of: value) { _, newValue in
                value = min(range.upperBound, max(range.lowerBound, newValue))
            }
    }
}

struct SettingsCleanupRequest {
    let detail: String
    let perform: () -> Void
}

struct SettingsCleanupDialog: View {
    @EnvironmentObject private var settings: AppSettings
    let request: SettingsCleanupRequest
    let dismiss: () -> Void
    private func text(_ key: String) -> String { SettingsCopy.text(key, language: settings.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("−").font(.system(size: 24)).foregroundStyle(SettingsPalette.danger)
                .frame(width: 34, height: 34).background(SettingsPalette.danger.opacity(0.1), in: Circle())
                .padding(.bottom, 17)
            Text(text("cleanupConfirmTitle")).font(.system(size: 17, weight: .semibold)).tracking(-0.3).frame(minHeight: 25.5)
            Text(request.detail).font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                .lineSpacing(3).frame(minHeight: 18.15).padding(.top, 8).padding(.bottom, 17)
            Text(text("cleanupPreserveShort"))
                .font(.system(size: 11)).foregroundStyle(Color.meterSecondary).lineSpacing(3)
                .frame(minHeight: 18.7).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 11).padding(.horizontal, 13).padding(1)
                .background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
            HStack(spacing: 8) {
                Spacer()
                Button(StorageL10n.text(.cancel, language: settings.language), action: dismiss)
                    .buttonStyle(SettingsButtonStyle()).keyboardShortcut(.cancelAction)
                Button(text("cleanupConfirm")) { dismiss(); request.perform() }
                    .buttonStyle(SettingsButtonStyle(kind: .danger))
            }.padding(.top, 24)
        }
        .padding(24).padding(1).frame(width: 360)
        .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.meterBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 15)
    }
}
