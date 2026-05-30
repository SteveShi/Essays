import Foundation
#if os(macOS)
import Sparkle
#endif
import Observation

#if os(macOS)
@MainActor
@Observable
final class UpdaterViewModel {
    static let shared = UpdaterViewModel()

    private let controller: SPUStandardUpdaterController
    
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            controller.updater.automaticallyChecksForUpdates
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SUEnableAutomaticChecks")
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }
    
    init() {
        // SPUStandardUpdaterController handles identifying the app and checking for updates.
        // It uses the SUFeedURL from Info.plist (which is set in project.yml).
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        controller.updater.checkForUpdatesInBackground()
    }
}
#else
@MainActor
@Observable
final class UpdaterViewModel {
    static let shared = UpdaterViewModel()

    var canCheckForUpdates: Bool { false }
    var automaticallyChecksForUpdates: Bool {
        get { false }
        set { }
    }

    func checkForUpdates() { }
    func checkForUpdatesInBackground() { }
}
#endif
