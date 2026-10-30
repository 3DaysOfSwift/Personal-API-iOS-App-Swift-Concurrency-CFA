import Foundation

protocol ConversationRepository: Sendable {
  func load() async throws -> [Conversation]
  func save(_ conversations: [Conversation]) async throws
  func save(_ conversations: [Conversation], replacing original: [Conversation]) async throws
  func export(_ conversations: [Conversation]) async throws -> Data
}

// File-only/test repositories have no concurrent cloud writer.
extension ConversationRepository {
  func save(_ conversations: [Conversation], replacing original: [Conversation]) async throws {
    try await save(conversations)
  }
}
