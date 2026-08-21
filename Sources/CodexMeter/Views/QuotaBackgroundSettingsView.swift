import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct QuotaBackgroundSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var backgrounds: QuotaBackgroundStore

    @State private var cropRequest: QuotaCropRequest?
    @State private var isAddingProfile = false
    @State private var newProfileName = ""
    @State private var previewSlot: QuotaBackgroundSlot = .sufficient

    var body: some View {
        HStack(spacing: 0) {
            profileList
                .frame(width: 165)

            Divider()
                .overlay(Color.meterBorder)

            profileEditor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.meterCard,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.meterBorder, lineWidth: 1)
        }
        .shadow(color: Color.meterShadow, radius: 10, y: 2)
        .alert(
            QuotaBackgroundL10n.text(.addBackground, language: settings.language),
            isPresented: $isAddingProfile
        ) {
            TextField(
                QuotaBackgroundL10n.text(.newBackground, language: settings.language),
                text: $newProfileName
            )
            Button(QuotaBackgroundL10n.text(.addBackground, language: settings.language)) {
                let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = trimmed.isEmpty ? defaultProfileName : trimmed
                backgrounds.addProfile(named: name)
                newProfileName = ""
            }
            Button(
                QuotaBackgroundL10n.text(.cancel, language: settings.language),
                role: .cancel
            ) {
                newProfileName = ""
            }
        }
        .sheet(item: $cropRequest) { request in
            QuotaBackgroundCropView(request: request) { result in
                try backgrounds.saveImage(
                    original: request.image,
                    cropped: result.cardImage,
                    cropConfiguration: result.cardConfiguration,
                    panelIcon: result.panelIcon,
                    panelIconCropConfiguration: result.panelIconConfiguration,
                    usesDefaultPanelIcon: result.usesDefaultPanelIcon,
                    for: request.slot,
                    profileID: request.profileID
                )
            }
        }
    }

    private var profileList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(QuotaBackgroundL10n.text(.profiles, language: settings.language))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))

            VStack(spacing: 6) {
                ForEach(backgrounds.profiles) { profile in
                    profileButton(profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Button {
                newProfileName = ""
                isAddingProfile = true
            } label: {
                Label(
                    QuotaBackgroundL10n.text(.addBackground, language: settings.language),
                    systemImage: "plus"
                )
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            }
            .buttonStyle(.plain)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.meterBorder, lineWidth: 1)
            }
        }
        .padding(12)
    }

    private func profileButton(_ profile: QuotaBackgroundProfile) -> some View {
        let isSelected = profile.id == backgrounds.selectedProfileID
        return HStack(spacing: 8) {
            Group {
                if let thumbnail = profileThumbnail(profile) {
                    RightAlignedThumbnail(image: thumbnail)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.meterTertiary)
                        .padding(3)
                }
            }
            .frame(width: 30, height: 30)
            .background(Color.meterControl, in: Circle())
            .clipShape(Circle())

            Text(profile.name)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 2)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.meterAccent)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .contentShape(Rectangle())
        .background(
            isSelected ? Color.meterAccent.opacity(0.11) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .onTapGesture {
            backgrounds.selectedProfileID = profile.id
        }
        .contextMenu {
            Button(role: .destructive) {
                backgrounds.removeProfile(id: profile.id)
            } label: {
                Label(
                    QuotaBackgroundL10n.text(.deleteBackground, language: settings.language),
                    systemImage: "trash"
                )
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            backgrounds.selectedProfileID = profile.id
        }
    }

    @ViewBuilder
    private var profileEditor: some View {
        if let profile = backgrounds.selectedProfile {
            VStack(alignment: .leading, spacing: 6) {
                QuotaProfileNameEditor(
                    profile: profile,
                    language: settings.language
                ) { profileID, name in
                    backgrounds.renameProfile(id: profileID, name: name)
                }

                HStack {
                    Text(QuotaBackgroundL10n.text(.enableBackground, language: settings.language))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    Spacer()
                    QuotaInlineSwitch(isOn: $backgrounds.isEnabled)
                }
                .frame(height: 24)

                Divider().overlay(Color.meterBorder)

                HStack {
                    Text(QuotaBackgroundL10n.text(.quotaStatusImages, language: settings.language))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(profile.configuredSlotCount)/\(QuotaBackgroundSlot.allCases.count)")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                        .monospacedDigit()
                }

                GeometryReader { geometry in
                    let slotWidth = max(
                        72,
                        (geometry.size.width - 16) / CGFloat(QuotaBackgroundSlot.allCases.count)
                    )
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(QuotaBackgroundSlot.allCases) { slot in
                            imageSlot(slot, profile: profile)
                                .frame(width: slotWidth)
                                .clipped()
                        }
                    }
                }
                .frame(height: 120)

                if let activePreviewSlot = resolvedPreviewSlot(for: profile),
                   let previewImage = backgrounds.image(
                       for: activePreviewSlot,
                       profileID: profile.id
                   ) {
                    HStack(spacing: 8) {
                        Text(QuotaBackgroundL10n.text(.cardPreview, language: settings.language))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(QuotaBackgroundL10n.rangeTitle(activePreviewSlot))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.meterSecondary)
                    }

                    GeometryReader { geometry in
                        let cardWidth = min(
                            geometry.size.width - 48,
                            132 * QuotaBackgroundImageProcessor.cardAspectRatio
                        )
                        let controlsWidth = cardWidth + 48
                        ZStack {
                            QuotaBackgroundCardPreview(
                                image: previewImage,
                                slot: activePreviewSlot
                            )
                            .frame(
                                width: cardWidth,
                                height: cardWidth
                                    / QuotaBackgroundImageProcessor.cardAspectRatio
                            )

                            HStack {
                                previewNavigationButton(
                                    systemImage: "chevron.left",
                                    direction: -1,
                                    profile: profile,
                                    activeSlot: activePreviewSlot
                                )
                                Spacer()
                                previewNavigationButton(
                                    systemImage: "chevron.right",
                                    direction: 1,
                                    profile: profile,
                                    activeSlot: activePreviewSlot
                                )
                            }
                            .frame(width: controlsWidth)
                        }
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height,
                            alignment: .center
                        )
                    }
                    .frame(height: 132)

                    HStack(spacing: 8) {
                        Text(QuotaBackgroundL10n.text(.automaticSwitchHint, language: settings.language))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.meterSecondary)
                        Spacer(minLength: 4)
                        autoSavedLabel
                    }
                } else {
                    Text(QuotaBackgroundL10n.text(.supportedFormats, language: settings.language))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                        .padding(.top, 2)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        autoSavedLabel
                    }
                }
            }
            .padding(14)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.meterTertiary)
                Text(QuotaBackgroundL10n.text(.emptyProfiles, language: settings.language))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
                    .multilineTextAlignment(.center)
                Button(QuotaBackgroundL10n.text(.addBackground, language: settings.language)) {
                    isAddingProfile = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Color.meterAccent, in: RoundedRectangle(cornerRadius: 7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }

    private var autoSavedLabel: some View {
        Label(
            QuotaBackgroundL10n.text(.autoSaved, language: settings.language),
            systemImage: "checkmark.circle.fill"
        )
        .font(.system(size: 9.5, weight: .medium, design: .rounded))
        .foregroundStyle(Color.meterAccent)
        .fixedSize()
    }

    private func imageSlot(
        _ slot: QuotaBackgroundSlot,
        profile: QuotaBackgroundProfile
    ) -> some View {
        VStack(spacing: 5) {
            Text(QuotaBackgroundL10n.rangeTitle(slot))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.meterSecondary)

            if let image = backgrounds.image(for: slot, profileID: profile.id) {
                GeometryReader { geometry in
                    RightAlignedThumbnail(image: image)
                        .frame(width: geometry.size.width, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(height: 76)

                HStack(spacing: 5) {
                    Button(QuotaBackgroundL10n.text(.recrop, language: settings.language)) {
                        recrop(slot, profileID: profile.id)
                    }
                    Divider().frame(height: 11)
                    Button(QuotaBackgroundL10n.text(.replace, language: settings.language)) {
                        chooseImage(slot, profileID: profile.id)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.meterAccent)
                .font(.system(size: 9, weight: .medium, design: .rounded))
            } else {
                Button {
                    chooseImage(slot, profileID: profile.id)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color.meterSecondary)
                        Text(QuotaBackgroundL10n.text(.uploadImage, language: settings.language))
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.meterAccent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            Color.meterSecondary.opacity(0.40),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var defaultProfileName: String {
        "\(QuotaBackgroundL10n.text(.newBackground, language: settings.language)) \(backgrounds.profiles.count + 1)"
    }

    private func profileThumbnail(_ profile: QuotaBackgroundProfile) -> NSImage? {
        for slot in QuotaBackgroundSlot.allCases {
            if let image = backgrounds.image(for: slot, profileID: profile.id) {
                return image
            }
        }
        return nil
    }

    private func previewSlots(for profile: QuotaBackgroundProfile) -> [QuotaBackgroundSlot] {
        QuotaBackgroundSlot.allCases.filter { slot in
            backgrounds.image(for: slot, profileID: profile.id) != nil
        }
    }

    private func resolvedPreviewSlot(for profile: QuotaBackgroundProfile) -> QuotaBackgroundSlot? {
        let slots = previewSlots(for: profile)
        return slots.contains(previewSlot) ? previewSlot : slots.first
    }

    private func previewNavigationButton(
        systemImage: String,
        direction: Int,
        profile: QuotaBackgroundProfile,
        activeSlot: QuotaBackgroundSlot
    ) -> some View {
        let slots = previewSlots(for: profile)
        return Button {
            guard slots.count > 1,
                  let currentIndex = slots.firstIndex(of: activeSlot)
            else { return }
            let nextIndex = (currentIndex + direction + slots.count) % slots.count
            previewSlot = slots[nextIndex]
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.meterAccent)
                .frame(width: 20, height: 20)
                .background(Color.meterControl, in: Circle())
                .overlay {
                    Circle().stroke(Color.meterBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(slots.count <= 1)
        .opacity(slots.count <= 1 ? 0.45 : 1)
        .accessibilityLabel(
            QuotaBackgroundL10n.text(
                direction < 0 ? .previousQuotaStyle : .nextQuotaStyle,
                language: settings.language
            )
        )
    }

    private func chooseImage(_ slot: QuotaBackgroundSlot, profileID: UUID) {
        let panel = NSOpenPanel()
        panel.title = QuotaBackgroundL10n.text(.uploadImage, language: settings.language)
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url)
        else { return }

        cropRequest = QuotaCropRequest(
            profileID: profileID,
            slot: slot,
            image: image,
            cropConfiguration: .default,
            panelIconCropConfiguration: .default,
            usesDefaultPanelIcon: false
        )
    }

    private func recrop(_ slot: QuotaBackgroundSlot, profileID: UUID) {
        guard let image = backgrounds.image(for: slot, profileID: profileID, original: true) else {
            chooseImage(slot, profileID: profileID)
            return
        }
        cropRequest = QuotaCropRequest(
            profileID: profileID,
            slot: slot,
            image: image,
            cropConfiguration: backgrounds.cropConfiguration(
                for: slot,
                profileID: profileID
            ),
            panelIconCropConfiguration: backgrounds.panelIconCropConfiguration(
                for: slot,
                profileID: profileID
            ),
            usesDefaultPanelIcon: backgrounds.usesDefaultPanelIcon(
                for: slot,
                profileID: profileID
            )
        )
    }
}

private struct QuotaProfileNameEditor: View {
    let profile: QuotaBackgroundProfile
    let language: AppLanguage
    let rename: (UUID, String) -> Void

    @State private var draftName: String
    @State private var editingProfileID: UUID?
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    init(
        profile: QuotaBackgroundProfile,
        language: AppLanguage,
        rename: @escaping (UUID, String) -> Void
    ) {
        self.profile = profile
        self.language = language
        self.rename = rename
        _draftName = State(initialValue: profile.name)
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isEditing {
                    TextField(
                        QuotaBackgroundL10n.text(.renameBackground, language: language),
                        text: $draftName
                    )
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        finishEditing()
                    }
                } else {
                    Text(profile.name)
                }
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                if isEditing {
                    finishEditing()
                } else {
                    beginEditing()
                }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isEditing ? Color.meterAccent : Color.meterTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                QuotaBackgroundL10n.text(.renameBackground, language: language)
            )
            .help(QuotaBackgroundL10n.text(.renameBackground, language: language))
        }
        .frame(height: 26)
        .onChange(of: profile.id) { _, _ in
            finishEditing()
            draftName = profile.name
        }
        .onChange(of: profile.name) { _, newName in
            if !isEditing {
                draftName = newName
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused && isEditing {
                finishEditing()
            }
        }
    }

    private func beginEditing() {
        draftName = profile.name
        editingProfileID = profile.id
        isEditing = true
        Task { @MainActor in
            isFocused = true
        }
    }

    private func finishEditing() {
        guard isEditing else { return }
        let profileID = editingProfileID ?? profile.id
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draftName = profile.name
        } else {
            draftName = trimmed
            rename(profileID, trimmed)
        }
        editingProfileID = nil
        isEditing = false
        isFocused = false
    }
}

private struct RightAlignedThumbnail: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            let sourceSize = image.size
            let scale = max(
                geometry.size.width / max(sourceSize.width, 1),
                geometry.size.height / max(sourceSize.height, 1)
            )
            let renderedSize = CGSize(
                width: sourceSize.width * scale,
                height: sourceSize.height * scale
            )

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: renderedSize.width, height: renderedSize.height)
                .position(
                    x: geometry.size.width - renderedSize.width / 2,
                    y: geometry.size.height / 2
                )
        }
        .clipped()
    }
}

private struct QuotaCropRequest: Identifiable {
    let id = UUID()
    let profileID: UUID
    let slot: QuotaBackgroundSlot
    let image: NSImage
    let cropConfiguration: QuotaBackgroundCropConfiguration
    let panelIconCropConfiguration: QuotaBackgroundCropConfiguration
    let usesDefaultPanelIcon: Bool
}

private struct QuotaBackgroundCropResult {
    let cardImage: NSImage
    let cardConfiguration: QuotaBackgroundCropConfiguration
    let panelIcon: NSImage?
    let panelIconConfiguration: QuotaBackgroundCropConfiguration
    let usesDefaultPanelIcon: Bool
}

private struct QuotaInlineSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.meterAccent : Color.meterTrack)
                Circle()
                    .fill(.white)
                    .padding(2)
                    .shadow(color: .black.opacity(0.13), radius: 1, y: 1)
            }
            .frame(width: 34, height: 20)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "1" : "0")
    }
}

private struct QuotaBackgroundCropView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let request: QuotaCropRequest
    let save: (QuotaBackgroundCropResult) throws -> Void

    @State private var zoom: CGFloat
    @State private var offset: CGSize
    @State private var quarterTurns: Int
    @State private var panelIconZoom: CGFloat
    @State private var panelIconOffset: CGSize
    @State private var panelIconQuarterTurns: Int
    @State private var usesDefaultPanelIcon: Bool
    @State private var errorMessage: String?

    // Crop offsets are persisted in this stable logical coordinate space so a
    // larger editor never changes an existing crop.
    private let cropReferenceSize = CGSize(width: 300, height: 120)
    private let editorDisplaySize = CGSize(width: 520, height: 208)
    private let panelIconReferenceSize = CGSize(width: 120, height: 120)
    private let panelIconDisplaySize = CGSize(width: 128, height: 128)

    init(
        request: QuotaCropRequest,
        save: @escaping (QuotaBackgroundCropResult) throws -> Void
    ) {
        self.request = request
        self.save = save
        let configuration = request.cropConfiguration
        let panelIconConfiguration = request.panelIconCropConfiguration
        _zoom = State(initialValue: CGFloat(min(max(configuration.zoom, 1), 3)))
        _offset = State(initialValue: CGSize(
            width: CGFloat(configuration.offsetX),
            height: CGFloat(configuration.offsetY)
        ))
        _quarterTurns = State(initialValue: configuration.quarterTurns)
        _panelIconZoom = State(
            initialValue: CGFloat(min(max(panelIconConfiguration.zoom, 1), 3))
        )
        _panelIconOffset = State(initialValue: CGSize(
            width: CGFloat(panelIconConfiguration.offsetX),
            height: CGFloat(panelIconConfiguration.offsetY)
        ))
        _panelIconQuarterTurns = State(
            initialValue: panelIconConfiguration.quarterTurns
        )
        _usesDefaultPanelIcon = State(initialValue: request.usesDefaultPanelIcon)
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(QuotaBackgroundL10n.text(.cropImage, language: settings.language))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(QuotaBackgroundL10n.text(.cropHint, language: settings.language))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
            }

            HStack(spacing: 20) {
                ZStack {
                    BackgroundQuotaUsageCard(
                        window: BackgroundQuotaUsageCard.previewWindow(),
                        backgroundImage: livePreviewImage
                    )

                    CropInteractionOverlay(
                        onMove: { translation in
                            let scale = editorDisplaySize.width / cropReferenceSize.width
                            offset = CGSize(
                                width: offset.width + translation.width / scale,
                                height: offset.height + translation.height / scale
                            )
                        },
                        onMagnify: { magnification in
                            zoom = min(max(zoom * (1 + magnification), 1), 3)
                        }
                    )
                }
                .frame(width: editorDisplaySize.width, height: editorDisplaySize.height)
                .contentShape(Rectangle())

                Divider().overlay(Color.meterBorder)

                VStack(spacing: 10) {
                    Text(QuotaBackgroundL10n.text(.panelIcon, language: settings.language))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))

                    Picker("", selection: $usesDefaultPanelIcon) {
                        Text(QuotaBackgroundL10n.text(.defaultIcon, language: settings.language))
                            .tag(true)
                        Text(QuotaBackgroundL10n.text(.customIcon, language: settings.language))
                            .tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 140)

                    ZStack {
                        if usesDefaultPanelIcon {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color.meterControl)
                            CodexIconView(size: 72)
                        } else {
                            Image(nsImage: livePanelIcon)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()

                            CropInteractionOverlay(
                                onMove: { translation in
                                    let scale = panelIconDisplaySize.width
                                        / panelIconReferenceSize.width
                                    panelIconOffset = CGSize(
                                        width: panelIconOffset.width + translation.width / scale,
                                        height: panelIconOffset.height + translation.height / scale
                                    )
                                },
                                onMagnify: { magnification in
                                    panelIconZoom = min(
                                        max(panelIconZoom * (1 + magnification), 1),
                                        3
                                    )
                                }
                            )
                        }
                    }
                    .frame(
                        width: panelIconDisplaySize.width,
                        height: panelIconDisplaySize.height
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.meterBorder, lineWidth: 1)
                    }

                    HStack(spacing: 7) {
                        if usesDefaultPanelIcon {
                            CodexIconView(size: 30)
                        } else {
                            Image(nsImage: livePanelIcon)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        Text("Codex Meter")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
            }

            Text(QuotaBackgroundL10n.text(.dragToPosition, language: settings.language))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.meterSecondary)

            HStack(spacing: 8) {
                Text("5:2")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 7))

                Text(QuotaBackgroundL10n.text(.zoom, language: settings.language))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                Slider(value: $zoom, in: 1...3)
                    .frame(width: 104)

                Button(QuotaBackgroundL10n.text(.rotateLeft, language: settings.language)) {
                    quarterTurns -= 1
                    offset = .zero
                }
                .buttonStyle(.link)

                Divider().frame(height: 18)

                Text(QuotaBackgroundL10n.text(.panelIcon, language: settings.language))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                Slider(value: $panelIconZoom, in: 1...3)
                    .frame(width: 90)
                    .disabled(usesDefaultPanelIcon)

                Button(QuotaBackgroundL10n.text(.rotateLeft, language: settings.language)) {
                    panelIconQuarterTurns -= 1
                    panelIconOffset = .zero
                }
                .buttonStyle(.link)
                .disabled(usesDefaultPanelIcon)

                Button(QuotaBackgroundL10n.text(.reset, language: settings.language)) {
                    zoom = 1
                    offset = .zero
                    quarterTurns = 0
                    panelIconZoom = 1
                    panelIconOffset = .zero
                    panelIconQuarterTurns = 0
                }
                .buttonStyle(.link)

                Spacer()

                Button(QuotaBackgroundL10n.text(.cancel, language: settings.language)) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(QuotaBackgroundL10n.text(.finishCrop, language: settings.language)) {
                    finishCrop()
                }
                .buttonStyle(.borderedProminent)
                .tint(.meterAccent)
            }
            .controlSize(.small)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 820, height: 420)
        .foregroundStyle(Color.meterPrimary)
        .background(Color.meterPanel)
    }

    private func finishCrop() {
        let cropped = QuotaBackgroundImageProcessor.crop(
            request.image,
            zoom: zoom,
            offset: offset,
            quarterTurns: quarterTurns,
            previewSize: cropReferenceSize
        )
        let panelIcon: NSImage? = usesDefaultPanelIcon
            ? nil
            : QuotaBackgroundImageProcessor.crop(
                request.image,
                zoom: panelIconZoom,
                offset: panelIconOffset,
                quarterTurns: panelIconQuarterTurns,
                previewSize: panelIconReferenceSize,
                renderSize: QuotaBackgroundImageProcessor.panelIconOutputSize
            )
        do {
            try save(QuotaBackgroundCropResult(
                cardImage: cropped,
                cardConfiguration: QuotaBackgroundCropConfiguration(
                    zoom: Double(zoom),
                    offsetX: Double(offset.width),
                    offsetY: Double(offset.height),
                    quarterTurns: quarterTurns
                ),
                panelIcon: panelIcon,
                panelIconConfiguration: QuotaBackgroundCropConfiguration(
                    zoom: Double(panelIconZoom),
                    offsetX: Double(panelIconOffset.width),
                    offsetY: Double(panelIconOffset.height),
                    quarterTurns: panelIconQuarterTurns
                ),
                usesDefaultPanelIcon: usesDefaultPanelIcon
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var livePreviewImage: NSImage {
        QuotaBackgroundImageProcessor.crop(
            request.image,
            zoom: zoom,
            offset: offset,
            quarterTurns: quarterTurns,
            previewSize: cropReferenceSize,
            renderSize: editorDisplaySize
        )
    }

    private var livePanelIcon: NSImage {
        QuotaBackgroundImageProcessor.crop(
            request.image,
            zoom: panelIconZoom,
            offset: panelIconOffset,
            quarterTurns: panelIconQuarterTurns,
            previewSize: panelIconReferenceSize,
            renderSize: panelIconDisplaySize
        )
    }
}

private struct CropInteractionOverlay: NSViewRepresentable {
    let onMove: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void

    func makeNSView(context: Context) -> CropInteractionNSView {
        let view = CropInteractionNSView()
        view.onMove = onMove
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ nsView: CropInteractionNSView, context: Context) {
        nsView.onMove = onMove
        nsView.onMagnify = onMagnify
    }
}

private final class CropInteractionNSView: NSView {
    var onMove: ((CGSize) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?

    private var lastDragLocation: CGPoint?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastDragLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let lastDragLocation else {
            self.lastDragLocation = location
            return
        }
        onMove?(CGSize(
            width: location.x - lastDragLocation.x,
            height: location.y - lastDragLocation.y
        ))
        self.lastDragLocation = location
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    override func scrollWheel(with event: NSEvent) {
        onMove?(CGSize(
            width: event.scrollingDeltaX,
            height: event.scrollingDeltaY
        ))
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(event.magnification)
    }
}

private struct QuotaBackgroundCardPreview: View {
    let image: NSImage
    let slot: QuotaBackgroundSlot

    var body: some View {
        BackgroundQuotaUsageCard(
            window: BackgroundQuotaUsageCard.previewWindow(
                remainingPercent: previewRemainingPercent
            ),
            backgroundImage: image
        )
    }

    private var previewRemainingPercent: Double {
        switch slot {
        case .sufficient: 85
        case .attention: 50
        case .critical: 15
        }
    }
}
