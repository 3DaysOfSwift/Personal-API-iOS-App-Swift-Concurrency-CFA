protocol CloudAccountChecking: Sendable {
  func check() async throws -> CloudAccountState
}
