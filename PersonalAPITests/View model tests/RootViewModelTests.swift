import XCTest

@testable import PersonalAPI

@MainActor final class RootViewModelTests: XCTestCase {
  func testBackgroundRequiresUnlockAgain() async {
    let graph = TestAppModelFactory()
    let vm = RootViewModel(
      settings: graph.app.settingsFeature, authentication: graph.app.authenticationFeature,
      backup: BackupStub())
    await graph.app.authenticationFeature.setEnabled(true)
    XCTAssertFalse(vm.requiresUnlock)
    vm.enteredBackground()
    XCTAssertTrue(vm.requiresUnlock)
  }
}

extension RootViewModelTests {
  func testOnboardingVisibilityTracksCompletion() {
    let graph = TestAppModelFactory()
    let vm = RootViewModel(
      settings: graph.app.settingsFeature, authentication: graph.app.authenticationFeature,
      backup: BackupStub())
    XCTAssertTrue(vm.needsOnboarding)
    XCTAssertFalse(vm.requiresUnlock)
    graph.app.settingsFeature.completeOnboarding()
    XCTAssertFalse(vm.needsOnboarding)
  }
}
