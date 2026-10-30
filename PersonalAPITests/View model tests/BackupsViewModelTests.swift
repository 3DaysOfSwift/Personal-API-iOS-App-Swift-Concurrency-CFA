import XCTest

@testable import PersonalAPI

@MainActor final class BackupsViewModelTests: XCTestCase {
  func testCommandsAndStatusUseFeature() async {
    let feature = BackupStub()
    let viewModel = BackupsViewModel(backup: feature)
    await viewModel.backupNow()
    XCTAssertEqual(feature.requests, [true])
    let url = URL(fileURLWithPath: "/test.json")
    await viewModel.inspect(url)
    XCTAssertEqual(feature.inspected, url)
    await viewModel.restore()
    XCTAssertTrue(feature.restored)
    XCTAssertEqual(viewModel.status, feature.status)
    feature.error = "failure"
    XCTAssertEqual(viewModel.error, "failure")
    feature.isWorking = true
    XCTAssertTrue(viewModel.isWorking)
  }
  func testImportFailureIsVisible() {
    let vm = BackupsViewModel(backup: BackupStub())
    vm.importFinished(.failure(TestFailure.unavailable))
    XCTAssertNotNil(vm.error)
  }
}

extension BackupsViewModelTests {
  func testSyncCheckAndIssueAreExposedFromFeature() async {
    let feature = BackupStub()
    feature.syncIssue = CloudSyncIssue(kind: .configuration, details: "Missing container")
    let vm = BackupsViewModel(backup: feature)
    await vm.checkSync()
    XCTAssertEqual(feature.checks, 1)
    XCTAssertEqual(vm.syncIssue, feature.syncIssue)
    feature.isCheckingAccount = true
    XCTAssertTrue(vm.isCheckingAccount)
  }
}

extension BackupsViewModelTests {
  func testErrorContextDistinguishesLocalBackupFromCloudCopy() {
    let feature = BackupStub()
    feature.error = "Underlying failure"
    let vm = BackupsViewModel(backup: feature)
    feature.errorContext = .createBackup
    XCTAssertEqual(vm.errorTitle, "Recovery backup could not be created")
    XCTAssertTrue(vm.errorGuidance.contains("No new recovery backup"))
    feature.errorContext = .uploadBackup
    XCTAssertTrue(vm.errorTitle.contains("saved locally"))
    XCTAssertTrue(vm.errorGuidance.contains("still saved on this device"))
    XCTAssertEqual(vm.error, "Underlying failure")
  }

  func testPostRestoreRefreshFailureDoesNotSuggestRestoringAgain() {
    let feature = BackupStub()
    feature.errorContext = .refreshAfterRestore
    feature.error = "Refresh failed"
    let vm = BackupsViewModel(backup: feature)
    XCTAssertTrue(vm.errorTitle.contains("Data restored"))
    XCTAssertTrue(vm.errorGuidance.contains("do not need to restore again"))
  }

  func testFilePickerFailureHasFileContext() {
    let vm = BackupsViewModel(backup: BackupStub())
    vm.importFinished(.failure(TestFailure.unavailable))
    XCTAssertEqual(vm.errorTitle, "Recovery file could not be opened")
    XCTAssertTrue(vm.errorGuidance.contains("Nothing has been restored"))
  }
}

extension BackupsViewModelTests {
  func testFastAccountCheckStillPresentsResultAndKeepsSyncFailure() async {
    let feature = BackupStub()
    feature.syncIssue = CloudSyncIssue(kind: .unknown, details: "Sync failed")
    let vm = BackupsViewModel(backup: feature)
    await vm.checkAccountWithFeedback()
    XCTAssertTrue(vm.showingAccountCheckResult)
    XCTAssertTrue(vm.accountCheckResult.contains("sync issue is still reported"))
    XCTAssertEqual(vm.syncIssue, feature.syncIssue)
    vm.showingAccountCheckResult = false
    await vm.checkAccountWithFeedback()
    XCTAssertTrue(vm.showingAccountCheckResult)
    XCTAssertEqual(feature.checks, 2)
  }
}
