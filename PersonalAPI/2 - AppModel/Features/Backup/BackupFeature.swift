import Foundation

@MainActor protocol BackupFeature: AnyObject {
  var isRestoring: Bool { get }
  var localCopies: [RecoveryCopy] { get }
  var isWorking: Bool { get }
  var lastBackup: Date? { get }
  var status: String { get }
  var syncIssue: CloudSyncIssue? { get }
  var accountStatus: String? { get }
  var isCheckingAccount: Bool { get }
  func checkSyncAvailability() async
  var syncStatus: String { get }
  var errorContext: RecoveryFailureContext? { get }
  var error: String? { get }
  var preview: RecoverySnapshot? { get }
  func observeChanges()
  func backup(force: Bool) async
  func loadLocalCopies() async
  func inspect(_ url: URL) async
  func restorePreview() async
  func discardPreview()
}

struct RecoveryCopy: Identifiable, Sendable {
  let url: URL
  let name: String
  var id: URL { url }
}

/// Identifies the failed stage, including whether restoration already committed.
enum RecoveryFailureContext: Sendable {
  case createBackup, uploadBackup, listBackups, readFile
  case restore, restoreBusy, refreshAfterRestore, refreshAfterSync
}
