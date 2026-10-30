import Foundation
import Observation

@MainActor @Observable final class ConversationsManager: ConversationsFeature {
  private(set) var conversations: [Conversation] = []
  private(set) var isBusy = false
  private(set) var activeTurnID: UUID?
  private var loaded = false
  private let repository: any ConversationRepository
  private let query: any QueryFeature
  private let now: @Sendable () -> Date
  init(
    repository: any ConversationRepository, query: any QueryFeature,
    now: @escaping @Sendable () -> Date
  ) {
    self.repository = repository
    self.query = query
    self.now = now
  }
  func canSend(_ question: String) -> Bool {
    !isBusy && query.canSearch(question) && question.count <= 500
  }
  func load() async throws {
    guard !loaded else { return }
    guard !isBusy else { throw ConversationError.busy }
    isBusy = true
    defer { isBusy = false }
    conversations = try await repository.load()
    loaded = true
  }
  func refresh() async throws {
    loaded = false
    guard !isBusy else { return }
    try await load()
  }
  private func commit(_ updated: [Conversation]) async throws {
    do {
      try await repository.save(updated, replacing: conversations)
      conversations = updated.sorted { $0.updatedAt > $1.updatedAt }
    } catch {
      // A conflict must reload before retrying; the old baseline is no longer valid.
      loaded = false
      throw error
    }
  }
  func send(_ question: String, in conversationID: UUID) async throws {
    try await load()
    guard canSend(question) else { throw QueryFailure.invalidQuestion }
    isBusy = true
    defer {
      isBusy = false
      activeTurnID = nil
    }
    try Task.checkCancellation()
    var updated = conversations
    if !updated.contains(where: { $0.id == conversationID }) {
      updated.append(
        Conversation(id: conversationID, createdAt: now(), updatedAt: now(), turns: []))
    }
    let index = updated.firstIndex { $0.id == conversationID }!
    let turn = ChatTurn(id: UUID(), question: question, createdAt: now())
    updated[index].turns.append(turn)
    updated[index].updatedAt = now()
    // Save the question before inference, so interruption never loses it.
    try await commit(updated)
    activeTurnID = turn.id
    try await generate(in: conversationID)
  }
  func answerAgain(in conversationID: UUID) async throws {
    try await load()
    guard !isBusy else { throw ConversationError.busy }
    guard let turn = conversations.first(where: { $0.id == conversationID })?.turns.last else {
      throw ConversationError.missing
    }
    isBusy = true
    activeTurnID = turn.id
    defer {
      isBusy = false
      activeTurnID = nil
    }
    try await generate(in: conversationID)
  }
  private func generate(in id: UUID) async throws {
    guard let conversation = conversations.first(where: { $0.id == id }),
      let turn = conversation.turns.last
    else { throw ConversationError.missing }
    var result: QueryResult?
    var failure: String?
    do {
      result = try await query.search(
        turn.question, previousQuestions: conversation.turns.dropLast().map(\.question))
      try Task.checkCancellation()
      failure = nil
    } catch is CancellationError { throw CancellationError() } catch {
      result = nil
      failure = error.localizedDescription
    }
    try Task.checkCancellation()
    var updated = conversations
    guard let index = updated.firstIndex(where: { $0.id == id }),
      let last = updated[index].turns.indices.last
    else { throw ConversationError.missing }
    updated[index].turns[last].result = result
    updated[index].turns[last].failure = failure
    updated[index].turns[last].feedback = nil
    updated[index].updatedAt = now()
    try await commit(updated)
  }
  func delete(_ id: UUID) async throws {
    try await load()
    guard !isBusy else { throw ConversationError.busy }
    isBusy = true
    defer { isBusy = false }
    try await commit(conversations.filter { $0.id != id })
  }
  func recordFeedback(
    _ rating: AnswerFeedback.Rating, explanation: String, turnID: UUID, conversationID: UUID
  ) async throws {
    try await load()
    guard !isBusy else { throw ConversationError.busy }
    isBusy = true
    defer { isBusy = false }
    var updated = conversations
    guard let chat = updated.firstIndex(where: { $0.id == conversationID }),
      let turn = updated[chat].turns.firstIndex(where: { $0.id == turnID })
    else { throw ConversationError.missing }
    updated[chat].turns[turn].feedback = AnswerFeedback(
      rating: rating, explanation: String(explanation.prefix(2000)), recordedAt: now())
    try await commit(updated)
  }
  func export() async throws -> Data {
    try await load()
    return try await repository.export(conversations)
  }
}
