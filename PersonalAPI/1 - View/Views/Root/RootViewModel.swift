import Foundation
import Observation

@MainActor @Observable final class RootViewModel {
  private let backup: any BackupFeature
  private let settings: any SettingsFeature
  private let authentication: any AuthenticationFeature
  init(
    settings: any SettingsFeature = AppModel.shared.settingsFeature,
    authentication: any AuthenticationFeature = AppModel.shared.authenticationFeature,
    backup: any BackupFeature = AppModel.shared.backupFeature
  ) {
    self.backup = backup
    self.settings = settings
    self.authentication = authentication
  }
  var isRestoring: Bool { backup.isRestoring }
  var requiresUnlock: Bool { authentication.requiresUnlock }
  var needsOnboarding: Bool { !settings.onboarded }
  func becameActive() async { await backup.backup(force: false) }
  func enteredBackground() { authentication.lockForBackground() }
}
