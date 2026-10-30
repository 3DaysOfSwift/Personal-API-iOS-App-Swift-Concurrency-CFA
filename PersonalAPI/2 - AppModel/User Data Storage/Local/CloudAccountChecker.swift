import CloudKit

actor CloudAccountChecker: CloudAccountChecking {
  func check() async throws -> CloudAccountState {
    let container = CKContainer(identifier: "iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI.SwiftData")
    switch try await container.accountStatus() {
    case .available: return .available
    case .noAccount: return .signedOut
    case .restricted: return .restricted
    case .couldNotDetermine, .temporarilyUnavailable: return .unavailable
    @unknown default: return .unavailable
    }
  }
}
