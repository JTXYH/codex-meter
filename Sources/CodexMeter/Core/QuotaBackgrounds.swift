import AppKit
import Foundation

enum QuotaBackgroundSlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case sufficient
    case attention
    case critical

    var id: String { rawValue }

    static func slot(for remainingPercent: Double) -> QuotaBackgroundSlot {
        let clamped = min(max(remainingPercent, 0), 100)
        if clamped >= 70 { return .sufficient }
        if clamped >= 30 { return .attention }
        return .critical
    }

    var percentageRange: ClosedRange<Int> {
        switch self {
        case .sufficient: 70...100
        case .attention: 30...69
        case .critical: 0...29
        }
    }
}

struct QuotaBackgroundCropConfiguration: Codable, Equatable, Sendable {
    static let `default` = QuotaBackgroundCropConfiguration()

    let zoom: Double
    let offsetX: Double
    let offsetY: Double
    let quarterTurns: Int

    init(
        zoom: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        quarterTurns: Int = 0
    ) {
        self.zoom = zoom
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.quarterTurns = quarterTurns
    }
}

struct QuotaBackgroundAsset: Codable, Equatable, Sendable {
    let originalFilename: String
    let croppedFilename: String
    let cropConfiguration: QuotaBackgroundCropConfiguration
    let panelIconFilename: String?
    let panelIconCropConfiguration: QuotaBackgroundCropConfiguration
    let usesDefaultPanelIcon: Bool

    init(
        originalFilename: String,
        croppedFilename: String,
        cropConfiguration: QuotaBackgroundCropConfiguration = .default,
        panelIconFilename: String? = nil,
        panelIconCropConfiguration: QuotaBackgroundCropConfiguration = .default,
        usesDefaultPanelIcon: Bool = false
    ) {
        self.originalFilename = originalFilename
        self.croppedFilename = croppedFilename
        self.cropConfiguration = cropConfiguration
        self.panelIconFilename = panelIconFilename
        self.panelIconCropConfiguration = panelIconCropConfiguration
        self.usesDefaultPanelIcon = usesDefaultPanelIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        originalFilename = try container.decode(String.self, forKey: .originalFilename)
        croppedFilename = try container.decode(String.self, forKey: .croppedFilename)
        cropConfiguration = try container.decodeIfPresent(
            QuotaBackgroundCropConfiguration.self,
            forKey: .cropConfiguration
        ) ?? .default
        panelIconFilename = try container.decodeIfPresent(
            String.self,
            forKey: .panelIconFilename
        ) ?? container.decodeIfPresent(String.self, forKey: .menuBarIconFilename)
        panelIconCropConfiguration = try container.decodeIfPresent(
            QuotaBackgroundCropConfiguration.self,
            forKey: .panelIconCropConfiguration
        ) ?? container.decodeIfPresent(
            QuotaBackgroundCropConfiguration.self,
            forKey: .menuBarIconCropConfiguration
        ) ?? .default
        usesDefaultPanelIcon = try container.decodeIfPresent(
            Bool.self,
            forKey: .usesDefaultPanelIcon
        ) ?? container.decodeIfPresent(
            Bool.self,
            forKey: .usesDefaultMenuBarIcon
        ) ?? (panelIconFilename == nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originalFilename, forKey: .originalFilename)
        try container.encode(croppedFilename, forKey: .croppedFilename)
        try container.encode(cropConfiguration, forKey: .cropConfiguration)
        try container.encodeIfPresent(panelIconFilename, forKey: .panelIconFilename)
        try container.encode(panelIconCropConfiguration, forKey: .panelIconCropConfiguration)
        try container.encode(usesDefaultPanelIcon, forKey: .usesDefaultPanelIcon)
    }

    private enum CodingKeys: String, CodingKey {
        case originalFilename
        case croppedFilename
        case cropConfiguration
        case panelIconFilename
        case panelIconCropConfiguration
        case usesDefaultPanelIcon
        // Read-only compatibility with versions that used this image in the menu bar.
        case menuBarIconFilename
        case menuBarIconCropConfiguration
        case usesDefaultMenuBarIcon
    }
}

struct QuotaBackgroundProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var assets: [QuotaBackgroundSlot: QuotaBackgroundAsset]

    init(
        id: UUID = UUID(),
        name: String,
        assets: [QuotaBackgroundSlot: QuotaBackgroundAsset] = [:]
    ) {
        self.id = id
        self.name = name
        self.assets = assets
    }

    var configuredSlotCount: Int { assets.count }
}

@MainActor
final class QuotaBackgroundStore: ObservableObject {
    static let shared = QuotaBackgroundStore()

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published private(set) var profiles: [QuotaBackgroundProfile]

    @Published var selectedProfileID: UUID? {
        didSet {
            defaults.set(selectedProfileID?.uuidString, forKey: Keys.selectedProfileID)
        }
    }

    let storageDirectory: URL

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private var imageCache: [URL: NSImage] = [:]

    init(
        defaults: UserDefaults = .standard,
        storageDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.storageDirectory = storageDirectory ?? Self.defaultStorageDirectory(fileManager: fileManager)
        isEnabled = (defaults.object(forKey: Keys.isEnabled) as? NSNumber)?.boolValue ?? true

        if let data = defaults.data(forKey: Keys.profiles),
           let decoded = try? JSONDecoder().decode([QuotaBackgroundProfile].self, from: data) {
            profiles = decoded
        } else {
            profiles = []
        }

        let storedSelection = defaults.string(forKey: Keys.selectedProfileID).flatMap(UUID.init(uuidString:))
        if let storedSelection, profiles.contains(where: { $0.id == storedSelection }) {
            selectedProfileID = storedSelection
        } else {
            selectedProfileID = profiles.first?.id
        }
    }

    var selectedProfile: QuotaBackgroundProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    @discardableResult
    func addProfile(named name: String) -> UUID {
        let profile = QuotaBackgroundProfile(name: name)
        profiles.append(profile)
        selectedProfileID = profile.id
        persistProfiles()
        return profile.id
    }

    func renameProfile(id: UUID, name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard profiles[index].name != trimmed else { return }
        profiles[index].name = trimmed
        persistProfiles()
    }

    func removeProfile(id: UUID) {
        profiles.removeAll(where: { $0.id == id })
        let directory = profileDirectory(for: id)
        imageCache = imageCache.filter { !$0.key.path.hasPrefix(directory.path) }
        try? fileManager.removeItem(at: directory)

        if selectedProfileID == id {
            selectedProfileID = profiles.first?.id
        }
        persistProfiles()
    }

    func selectNextProfile() {
        guard profiles.count > 1 else { return }
        guard let selectedProfileID,
              let index = profiles.firstIndex(where: { $0.id == selectedProfileID })
        else {
            self.selectedProfileID = profiles.first?.id
            return
        }
        self.selectedProfileID = profiles[(index + 1) % profiles.count].id
    }

    func saveImage(
        original: NSImage,
        cropped: NSImage,
        cropConfiguration: QuotaBackgroundCropConfiguration = .default,
        panelIcon: NSImage? = nil,
        panelIconCropConfiguration: QuotaBackgroundCropConfiguration = .default,
        usesDefaultPanelIcon: Bool = false,
        for slot: QuotaBackgroundSlot,
        profileID: UUID
    ) throws {
        guard let profileIndex = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw QuotaBackgroundError.profileNotFound
        }

        let directory = profileDirectory(for: profileID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let originalFilename = "\(slot.rawValue)-original.jpg"
        let croppedFilename = "\(slot.rawValue)-cropped.jpg"
        let panelIconFilename = "\(slot.rawValue)-panel-icon.jpg"
        let originalURL = directory.appendingPathComponent(originalFilename)
        let croppedURL = directory.appendingPathComponent(croppedFilename)
        let panelIconURL = directory.appendingPathComponent(panelIconFilename)

        guard let originalData = original.jpegData(compressionFactor: 0.94),
              let croppedData = cropped.jpegData(compressionFactor: 0.90)
        else {
            throw QuotaBackgroundError.couldNotEncodeImage
        }

        try originalData.write(to: originalURL, options: .atomic)
        try croppedData.write(to: croppedURL, options: .atomic)
        imageCache[originalURL] = original
        imageCache[croppedURL] = cropped

        if let previousIconFilename = profiles[profileIndex].assets[slot]?.panelIconFilename,
           previousIconFilename != panelIconFilename {
            let previousIconURL = directory.appendingPathComponent(previousIconFilename)
            try? fileManager.removeItem(at: previousIconURL)
            imageCache.removeValue(forKey: previousIconURL)
        }

        var savedPanelIconFilename: String?
        if usesDefaultPanelIcon {
            try? fileManager.removeItem(at: panelIconURL)
            imageCache.removeValue(forKey: panelIconURL)
        } else if let panelIcon {
            guard let panelIconData = panelIcon.jpegData(compressionFactor: 0.94) else {
                throw QuotaBackgroundError.couldNotEncodeImage
            }
            try panelIconData.write(to: panelIconURL, options: .atomic)
            imageCache[panelIconURL] = panelIcon
            savedPanelIconFilename = panelIconFilename
        }

        profiles[profileIndex].assets[slot] = QuotaBackgroundAsset(
            originalFilename: originalFilename,
            croppedFilename: croppedFilename,
            cropConfiguration: cropConfiguration,
            panelIconFilename: savedPanelIconFilename,
            panelIconCropConfiguration: panelIconCropConfiguration,
            usesDefaultPanelIcon: usesDefaultPanelIcon
        )
        persistProfiles()
    }

    func cropConfiguration(
        for slot: QuotaBackgroundSlot,
        profileID: UUID? = nil
    ) -> QuotaBackgroundCropConfiguration {
        let resolvedProfileID = profileID ?? selectedProfileID
        guard let resolvedProfileID,
              let profile = profiles.first(where: { $0.id == resolvedProfileID }),
              let asset = profile.assets[slot]
        else { return .default }
        return asset.cropConfiguration
    }

    func panelIconCropConfiguration(
        for slot: QuotaBackgroundSlot,
        profileID: UUID? = nil
    ) -> QuotaBackgroundCropConfiguration {
        let resolvedProfileID = profileID ?? selectedProfileID
        guard let resolvedProfileID,
              let profile = profiles.first(where: { $0.id == resolvedProfileID }),
              let asset = profile.assets[slot]
        else { return .default }
        return asset.panelIconCropConfiguration
    }

    func usesDefaultPanelIcon(
        for slot: QuotaBackgroundSlot,
        profileID: UUID? = nil
    ) -> Bool {
        let resolvedProfileID = profileID ?? selectedProfileID
        guard let resolvedProfileID,
              let profile = profiles.first(where: { $0.id == resolvedProfileID }),
              let asset = profile.assets[slot]
        else { return false }
        return asset.usesDefaultPanelIcon
    }

    func image(
        for slot: QuotaBackgroundSlot,
        profileID: UUID? = nil,
        original: Bool = false
    ) -> NSImage? {
        let resolvedProfileID = profileID ?? selectedProfileID
        guard let resolvedProfileID,
              let profile = profiles.first(where: { $0.id == resolvedProfileID }),
              let asset = profile.assets[slot]
        else { return nil }

        let filename = original ? asset.originalFilename : asset.croppedFilename
        let url = profileDirectory(for: resolvedProfileID).appendingPathComponent(filename)
        if let cached = imageCache[url] { return cached }
        guard let loaded = NSImage(contentsOf: url) else { return nil }
        imageCache[url] = loaded
        return loaded
    }

    func selectedImage(for remainingPercent: Double) -> NSImage? {
        guard isEnabled else { return nil }
        return image(for: .slot(for: remainingPercent))
    }

    func panelIcon(
        for slot: QuotaBackgroundSlot,
        profileID: UUID? = nil
    ) -> NSImage? {
        let resolvedProfileID = profileID ?? selectedProfileID
        guard let resolvedProfileID,
              let profile = profiles.first(where: { $0.id == resolvedProfileID }),
              let asset = profile.assets[slot],
              let filename = asset.panelIconFilename
        else { return nil }

        let url = profileDirectory(for: resolvedProfileID).appendingPathComponent(filename)
        if let cached = imageCache[url] { return cached }
        guard let loaded = NSImage(contentsOf: url) else { return nil }
        imageCache[url] = loaded
        return loaded
    }

    func selectedPanelIcon(for remainingPercent: Double) -> NSImage? {
        guard isEnabled else { return nil }
        let preferredSlot = QuotaBackgroundSlot.slot(for: remainingPercent)
        if usesDefaultPanelIcon(for: preferredSlot) {
            return nil
        }
        if let preferredIcon = panelIcon(for: preferredSlot) {
            return preferredIcon
        }

        for fallbackSlot in QuotaBackgroundSlot.allCases where fallbackSlot != preferredSlot {
            if let fallbackIcon = panelIcon(for: fallbackSlot) {
                return fallbackIcon
            }
        }
        return nil
    }

    private func profileDirectory(for id: UUID) -> URL {
        storageDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func persistProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            defaults.set(encoded, forKey: Keys.profiles)
        }
    }

    private static func defaultStorageDirectory(fileManager: FileManager) -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return root
            .appendingPathComponent("CodexMeter", isDirectory: true)
            .appendingPathComponent("QuotaBackgrounds", isDirectory: true)
    }

    private enum Keys {
        static let isEnabled = "quotaBackgroundsEnabled"
        static let profiles = "quotaBackgroundProfiles"
        static let selectedProfileID = "selectedQuotaBackgroundProfileID"
    }
}

enum QuotaBackgroundError: LocalizedError {
    case profileNotFound
    case couldNotEncodeImage

    var errorDescription: String? {
        switch self {
        case .profileNotFound: "The selected background profile no longer exists."
        case .couldNotEncodeImage: "The selected image could not be saved."
        }
    }
}

enum QuotaBackgroundImageProcessor {
    static let cardAspectRatio: CGFloat = 5 / 2
    static let outputSize = CGSize(width: 1_500, height: 600)
    static let panelIconOutputSize = CGSize(width: 128, height: 128)

    static func crop(
        _ image: NSImage,
        zoom: CGFloat,
        offset: CGSize,
        quarterTurns: Int,
        previewSize: CGSize,
        renderSize: CGSize? = nil
    ) -> NSImage {
        let rotated = rotatedImage(image, quarterTurns: quarterTurns)
        let sourceSize = rotated.size
        let targetSize = renderSize ?? outputSize
        let safeZoom = min(max(zoom, 1), 3)
        let scale = max(targetSize.width / max(sourceSize.width, 1),
                        targetSize.height / max(sourceSize.height, 1)) * safeZoom
        let drawnSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let previewScale = targetSize.width / max(previewSize.width, 1)
        let drawnRect = CGRect(
            x: (targetSize.width - drawnSize.width) / 2 + offset.width * previewScale,
            y: (targetSize.height - drawnSize.height) / 2 - offset.height * previewScale,
            width: drawnSize.width,
            height: drawnSize.height
        )

        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
        NSBezierPath(rect: CGRect(origin: .zero, size: targetSize)).addClip()
        NSGraphicsContext.current?.imageInterpolation = .high
        rotated.draw(in: drawnRect, from: .zero, operation: .sourceOver, fraction: 1)
        result.unlockFocus()
        return result
    }

    static func rotatedImage(_ image: NSImage, quarterTurns: Int) -> NSImage {
        let normalizedTurns = ((quarterTurns % 4) + 4) % 4
        guard normalizedTurns != 0 else { return image }

        let swapsDimensions = normalizedTurns.isMultiple(of: 2) == false
        let resultSize = swapsDimensions
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size
        let result = NSImage(size: resultSize)
        result.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: resultSize.width / 2, yBy: resultSize.height / 2)
        transform.rotate(byDegrees: CGFloat(normalizedTurns) * 90)
        transform.translateX(by: -image.size.width / 2, yBy: -image.size.height / 2)
        transform.concat()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
        result.unlockFocus()
        return result
    }
}

private extension NSImage {
    func jpegData(compressionFactor: Double) -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionFactor]
        )
    }
}
