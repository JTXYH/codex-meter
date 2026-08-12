import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case failed
    }

    @Published private(set) var state: State = .idle

    let currentVersion: String

    private var hasStarted = false
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    override init() {
        currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
        super.init()
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        updaterController.startUpdater()
    }

    func checkManually() {
        startIfNeeded()
        state = .checking
        NSApplication.shared.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        state = .available(item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        state = .upToDate
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard state == .checking else { return }
        state = error == nil ? .idle : .failed
    }
}
