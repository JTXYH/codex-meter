import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct QuotaBackgroundTests {
    @Test
    func mapsRemainingQuotaToTheExpectedBackgroundSlot() {
        #expect(QuotaBackgroundSlot.slot(for: 100) == .sufficient)
        #expect(QuotaBackgroundSlot.slot(for: 70) == .sufficient)
        #expect(QuotaBackgroundSlot.slot(for: 69.99) == .attention)
        #expect(QuotaBackgroundSlot.slot(for: 30) == .attention)
        #expect(QuotaBackgroundSlot.slot(for: 29.99) == .critical)
        #expect(QuotaBackgroundSlot.slot(for: -10) == .critical)
    }

    @Test @MainActor
    func persistsProfilesSelectionAndEnabledState() throws {
        let suiteName = "CodexMeterTests.QuotaBackgrounds.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMeterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        let first = store.addProfile(named: "First")
        let second = store.addProfile(named: "Second")
        store.selectedProfileID = first
        store.isEnabled = false

        let restored = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        #expect(restored.profiles.map(\.name) == ["First", "Second"])
        #expect(restored.selectedProfileID == first)
        #expect(restored.selectedProfileID != second)
        #expect(restored.isEnabled == false)
    }

    @Test @MainActor
    func renamesProfileWithTrimmedNonemptyNameAndPersistsIt() throws {
        let suiteName = "CodexMeterTests.RenameQuotaBackground.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMeterRenameTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        let profileID = store.addProfile(named: "Original")

        store.renameProfile(id: profileID, name: "  Updated  ")
        #expect(store.selectedProfile?.name == "Updated")

        store.renameProfile(id: profileID, name: "   ")
        #expect(store.selectedProfile?.name == "Updated")

        let restored = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        #expect(restored.selectedProfile?.name == "Updated")
    }

    @Test @MainActor
    func savesAndReloadsCroppedImagesForTheSelectedQuotaSlot() throws {
        let suiteName = "CodexMeterTests.QuotaBackgroundImages.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMeterImageTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        let profileID = store.addProfile(named: "Demo")
        let original = solidImage(size: CGSize(width: 640, height: 480), color: .systemPink)
        let cropped = QuotaBackgroundImageProcessor.crop(
            original,
            zoom: 1.25,
            offset: CGSize(width: 8, height: -4),
            quarterTurns: 0,
            previewSize: CGSize(width: 300, height: 120)
        )
        let cropConfiguration = QuotaBackgroundCropConfiguration(
            zoom: 1.25,
            offsetX: 8,
            offsetY: -4,
            quarterTurns: -1
        )
        let panelIcon = QuotaBackgroundImageProcessor.crop(
            original,
            zoom: 1.5,
            offset: CGSize(width: -12, height: 6),
            quarterTurns: 0,
            previewSize: CGSize(width: 120, height: 120),
            renderSize: QuotaBackgroundImageProcessor.panelIconOutputSize
        )
        let panelIconCropConfiguration = QuotaBackgroundCropConfiguration(
            zoom: 1.5,
            offsetX: -12,
            offsetY: 6,
            quarterTurns: 0
        )

        try store.saveImage(
            original: original,
            cropped: cropped,
            cropConfiguration: cropConfiguration,
            panelIcon: panelIcon,
            panelIconCropConfiguration: panelIconCropConfiguration,
            for: .attention,
            profileID: profileID
        )

        #expect(store.selectedImage(for: 50) != nil)
        #expect(store.selectedPanelIcon(for: 50) != nil)
        #expect(store.selectedImage(for: 90) == nil)
        #expect(store.selectedPanelIcon(for: 90) != nil)
        #expect(store.profiles.first?.configuredSlotCount == 1)

        let restored = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        let restoredImage = try #require(restored.image(for: .attention, profileID: profileID))
        #expect(restoredImage.size == QuotaBackgroundImageProcessor.outputSize)
        #expect(
            restored.cropConfiguration(for: .attention, profileID: profileID)
                == cropConfiguration
        )
        let restoredPanelIcon = try #require(
            restored.panelIcon(for: .attention, profileID: profileID)
        )
        #expect(restoredPanelIcon.size == QuotaBackgroundImageProcessor.panelIconOutputSize)
        #expect(
            restored.panelIconCropConfiguration(for: .attention, profileID: profileID)
                == panelIconCropConfiguration
        )

        restored.isEnabled = false
        #expect(restored.selectedImage(for: 50) == nil)
        #expect(restored.selectedPanelIcon(for: 50) == nil)
    }

    @Test
    func migratesSavedImagesThatPredateCropConfigurationPersistence() throws {
        let legacyJSON = Data(
            #"{"originalFilename":"original.jpg","croppedFilename":"cropped.jpg"}"#.utf8
        )
        let asset = try JSONDecoder().decode(QuotaBackgroundAsset.self, from: legacyJSON)

        #expect(asset.cropConfiguration == .default)
        #expect(asset.panelIconFilename == nil)
        #expect(asset.panelIconCropConfiguration == .default)
        #expect(asset.usesDefaultPanelIcon)
        #expect(
            QuotaBackgroundImageProcessor.outputSize.width
                / QuotaBackgroundImageProcessor.outputSize.height
                == QuotaBackgroundImageProcessor.cardAspectRatio
        )
    }

    @Test @MainActor
    func persistsExplicitDefaultPanelIconWithoutFallingBack() throws {
        let suiteName = "CodexMeterTests.DefaultPanelIcon.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMeterDefaultIconTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        let profileID = store.addProfile(named: "Demo")
        let image = solidImage(size: CGSize(width: 640, height: 480), color: .systemBlue)
        let cropped = QuotaBackgroundImageProcessor.crop(
            image,
            zoom: 1,
            offset: .zero,
            quarterTurns: 0,
            previewSize: CGSize(width: 300, height: 120)
        )
        let customIcon = QuotaBackgroundImageProcessor.crop(
            image,
            zoom: 1,
            offset: .zero,
            quarterTurns: 0,
            previewSize: CGSize(width: 120, height: 120),
            renderSize: QuotaBackgroundImageProcessor.panelIconOutputSize
        )

        try store.saveImage(
            original: image,
            cropped: cropped,
            panelIcon: customIcon,
            for: .sufficient,
            profileID: profileID
        )
        try store.saveImage(
            original: image,
            cropped: cropped,
            usesDefaultPanelIcon: true,
            for: .attention,
            profileID: profileID
        )

        #expect(store.selectedPanelIcon(for: 90) != nil)
        #expect(store.selectedPanelIcon(for: 50) == nil)
        #expect(store.usesDefaultPanelIcon(for: .attention, profileID: profileID))

        let restored = QuotaBackgroundStore(defaults: defaults, storageDirectory: directory)
        #expect(restored.selectedPanelIcon(for: 50) == nil)
        #expect(restored.usesDefaultPanelIcon(for: .attention, profileID: profileID))
    }

    @Test
    func migratesLegacyMenuBarIconMetadataToPanelIcon() throws {
        let legacyJSON = Data(
            #"{"originalFilename":"original.jpg","croppedFilename":"cropped.jpg","menuBarIconFilename":"attention-menu-bar-icon.jpg","menuBarIconCropConfiguration":{"zoom":1.5,"offsetX":-12,"offsetY":6,"quarterTurns":1},"usesDefaultMenuBarIcon":false}"#.utf8
        )

        let asset = try JSONDecoder().decode(QuotaBackgroundAsset.self, from: legacyJSON)

        #expect(asset.panelIconFilename == "attention-menu-bar-icon.jpg")
        #expect(asset.panelIconCropConfiguration.zoom == 1.5)
        #expect(asset.panelIconCropConfiguration.offsetX == -12)
        #expect(asset.panelIconCropConfiguration.offsetY == 6)
        #expect(asset.panelIconCropConfiguration.quarterTurns == 1)
        #expect(asset.usesDefaultPanelIcon == false)
    }

    @Test @MainActor
    func previewAndSavedCropUseTheSameFiveToTwoComposition() throws {
        let source = quadrantImage(size: CGSize(width: 640, height: 480))
        let configuration = (
            zoom: CGFloat(1.35),
            offset: CGSize(width: 17, height: -9),
            quarterTurns: 0
        )
        let referenceSize = CGSize(width: 300, height: 120)
        let previewSize = CGSize(width: 400, height: 160)

        let saved = QuotaBackgroundImageProcessor.crop(
            source,
            zoom: configuration.zoom,
            offset: configuration.offset,
            quarterTurns: configuration.quarterTurns,
            previewSize: referenceSize
        )
        let preview = QuotaBackgroundImageProcessor.crop(
            source,
            zoom: configuration.zoom,
            offset: configuration.offset,
            quarterTurns: configuration.quarterTurns,
            previewSize: referenceSize,
            renderSize: previewSize
        )

        #expect(saved.size == QuotaBackgroundImageProcessor.outputSize)
        #expect(preview.size == previewSize)

        for point in [
            CGPoint(x: 0.12, y: 0.20),
            CGPoint(x: 0.42, y: 0.72),
            CGPoint(x: 0.78, y: 0.30),
            CGPoint(x: 0.90, y: 0.80),
        ] {
            let savedColor = try normalizedColor(in: saved, at: point)
            let previewColor = try normalizedColor(in: preview, at: point)
            #expect(abs(savedColor.red - previewColor.red) < 0.03)
            #expect(abs(savedColor.green - previewColor.green) < 0.03)
            #expect(abs(savedColor.blue - previewColor.blue) < 0.03)
        }
    }

    @MainActor
    private func solidImage(size: CGSize, color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    @MainActor
    private func quadrantImage(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        for (color, rect) in [
            (NSColor.systemRed, CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight)),
            (NSColor.systemGreen, CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)),
            (NSColor.systemBlue, CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)),
            (NSColor.systemYellow, CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)),
        ] {
            color.setFill()
            NSBezierPath(rect: rect).fill()
        }
        image.unlockFocus()
        return image
    }

    private func normalizedColor(
        in image: NSImage,
        at point: CGPoint
    ) throws -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let x = min(max(Int(CGFloat(bitmap.pixelsWide - 1) * point.x), 0), bitmap.pixelsWide - 1)
        let y = min(max(Int(CGFloat(bitmap.pixelsHigh - 1) * point.y), 0), bitmap.pixelsHigh - 1)
        let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }
}
