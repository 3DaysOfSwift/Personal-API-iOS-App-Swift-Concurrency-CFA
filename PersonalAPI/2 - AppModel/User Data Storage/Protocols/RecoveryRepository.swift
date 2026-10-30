import Foundation

protocol RecoveryRepository: Sendable {
  func changes() async -> AsyncStream<Void>
  func recoverySnapshot(at date: Date, themeID: String?) async throws -> RecoverySnapshot
  func restore(
    _ snapshot: RecoverySnapshot, safetyFolder: URL, at date: Date, previousThemeID: String?)
    async throws
}

protocol RecoveryFiles: Sendable {
  func prepare(_ snapshot: RecoverySnapshot, force: Bool) async throws -> RecoverySnapshot?
  func localCopies() async throws -> [RecoveryCopy]
  func upload() async throws -> Bool?
  func preview(_ url: URL) async throws -> RecoverySnapshot
  var safetyFolder: URL { get }
}
