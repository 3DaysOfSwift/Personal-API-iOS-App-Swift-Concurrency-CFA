import Foundation
import Observation

@MainActor @Observable final class BackupsViewModel {
  private let backup: any BackupFeature
  private var accountCheck: Task<Void, Never>?
  private var command: Task<Void, Never>?
  var showingAccountCheckResult = false
  private(set) var accountCheckResult = ""
  var importing = false
  var confirmingRestore = false
  private(set) var importError: String?
  init(backup: any BackupFeature = AppModel.shared.backupFeature) { self.backup = backup }
  var localCopies: [RecoveryCopy] { backup.localCopies }
  func load() async {
    await backup.loadLocalCopies()
    await checkSync()
  }
  var syncIssue: CloudSyncIssue? { backup.syncIssue }
  var accountStatus: String? { backup.accountStatus }
  var isCheckingAccount: Bool { backup.isCheckingAccount }
  func checkSync() async { await backup.checkSyncAvailability() }
  func checkAccountWithFeedback() async {
    await checkSync()
    accountCheckResult = backup.accountStatus ?? "The account check could not confirm availability."
    if backup.syncIssue != nil {
      accountCheckResult += "\n\nA sync issue is still reported. Expand Error details to see the underlying failure."
    }
    showingAccountCheckResult = true
  }
  func requestSyncCheck() {
    guard accountCheck == nil else { return }
    accountCheck = Task {
      await checkAccountWithFeedback()
      accountCheck = nil
    }
  }
  func requestInspect(_ url: URL) { importFinished(.success(url)) }
  var isWorking: Bool { backup.isWorking }
  var status: String { backup.status }
  var syncStatus: String { backup.syncStatus }
  var error: String? { importError ?? backup.error }
  private var errorContext: RecoveryFailureContext {
    importError != nil ? .readFile : backup.errorContext ?? .createBackup
  }
  var errorTitle: String {
    switch errorContext {
    case .createBackup: return "Recovery backup could not be created"
    case .uploadBackup: return "Backup saved locally, but cloud copying failed"
    case .listBackups: return "Local recovery copies could not be listed"
    case .readFile: return "Recovery file could not be opened"
    case .restore: return "Recovery file could not be restored"
    case .restoreBusy: return "Restore is waiting for the current operation"
    case .refreshAfterRestore: return "Data restored, but the screen could not refresh"
    case .refreshAfterSync: return "iCloud changes arrived, but the screen could not refresh"
    }
  }
  var errorGuidance: String {
    switch errorContext {
    case .createBackup:
      return
        "No new recovery backup was completed. Your journal data has not been deleted. Check available device storage, then tap Back up now to try again."
    case .uploadBackup:
      return
        "The recovery copy is still saved on this device. Check your connection and iCloud Drive settings, then tap Back up now to retry."
    case .listBackups:
      return
        "The app could not read the list of local recovery files. Reopen this screen to try again. This has not deleted your journal data."
    case .readFile:
      return
        "Nothing has been restored. Make sure the file has downloaded and is a Personal API recovery file, then choose it again."
    case .restore:
      return
        "Your current data has not been replaced. Check the file and available device storage, then try restoring again."
    case .restoreBusy:
      return "Wait for the current chat operation to finish, then tap Restore this snapshot again."
    case .refreshAfterRestore:
      return
        "The restore completed and a safety copy of your previous data was saved. Reopen the app to refresh the screen; you do not need to restore again."
    case .refreshAfterSync:
      return
        "Reopen the app to reload the latest data. This message concerns refreshing the screen, not uploading a recovery backup."
    }
  }
  var preview: RecoverySnapshot? { backup.preview }
  var lastBackup: Date? { backup.lastBackup }

  func backupNow() async { await backup.backup(force: true) }
  func requestBackup() {
    guard command == nil else { return }
    command = Task {
      await backupNow()
      command = nil
    }
  }
  func inspect(_ url: URL) async { await backup.inspect(url) }
  func importFinished(_ result: Result<URL, Error>) {
    guard command == nil else { return }
    switch result {
    case .success(let url):
      importError = nil
      command = Task {
        await inspect(url)
        command = nil
      }
    case .failure(let error): importError = error.localizedDescription
    }
  }
  func restore() async { await backup.restorePreview() }
  func requestRestore() {
    guard command == nil else { return }
    command = Task {
      await restore()
      command = nil
    }
  }
  func discardPreview() { backup.discardPreview() }
}
