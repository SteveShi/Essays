import Foundation
import Sparkle
import Observation

@MainActor
@Observable
final class UpdaterViewModel {
    private let controller: SPUStandardUpdaterController
    
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
    
    init() {
        // SPUStandardUpdaterController handles identifying the app and checking for updates.
        // It uses the SUFeedURL from Info.plist (which is set in project.yml).
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
