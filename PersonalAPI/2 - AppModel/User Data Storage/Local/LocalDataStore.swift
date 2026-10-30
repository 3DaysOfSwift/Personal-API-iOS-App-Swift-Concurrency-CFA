import Foundation
import SwiftData

/// All database work runs on this actor, using fresh contexts per transaction.
actor LocalDataStore: PersonalDataRepository, ConversationRepository, RecoveryRepository {
  private let storeURL: URL?
  private var container: ModelContainer?
  private let cloudEnabled: Bool
  private var changeContinuations: [AsyncStream<Void>.Continuation] = []

  init(storeURL: URL? = nil, cloudEnabled: Bool = false) {
    self.storeURL = storeURL
    self.cloudEnabled = cloudEnabled
  }

  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    changeContinuations.append(continuation)
    return stream
  }

  private func save(_ context: ModelContext) throws {
    try context.save()
    changeContinuations.removeAll { continuation in
      if case .terminated = continuation.yield(()) { return true }
      return false
    }
  }

  private func makeContext() throws -> ModelContext {
    if container == nil {
      let schema = Schema([Moment.self, PersonalFact.self, StoredConversation.self])
      let configuration: ModelConfiguration
      if let storeURL {
        configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
      } else {
        configuration = ModelConfiguration(
          schema: schema,
          cloudKitDatabase: cloudEnabled
            ? .private("iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI.SwiftData") : .none)
      }
      container = try ModelContainer(
        for: schema, configurations: [configuration])
    }
    guard let container else { throw MomentError.missingMoment }
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return context
  }
  private func snapshot(_ value: Moment) -> MomentSnapshot {
    MomentSnapshot(
      id: value.id, text: value.text, createdAt: value.createdAt,
      happenedAt: value.happenedAt, source: value.source,
      analysisData: value.analysisData, processingState: value.processingState)
  }
  func loadMoments() throws -> [MomentSnapshot] {
    try makeContext().fetch(FetchDescriptor<Moment>()).sorted { $0.createdAt > $1.createdAt }.map(
      snapshot)
  }
  func saveMoment(_ value: MomentSnapshot) throws {
    let context = try makeContext()
    let record = Moment(text: value.text, happenedAt: value.happenedAt)
    record.id = value.id
    record.createdAt = value.createdAt
    record.source = value.source
    context.insert(record)
    try save(context)
  }
  private func removeDerivedFacts(for id: UUID, in context: ModelContext) throws {
    for fact in try context.fetch(FetchDescriptor<PersonalFact>()) {
      if let data = fact.derivationData,
        try JSONDecoder().decode(FactDerivation.self, from: data).momentID == id
      {
        context.delete(fact)
      }
    }
  }
  func updateMoment(_ original: MomentSnapshot, text: String) throws -> MomentSnapshot {
    let context = try makeContext()
    guard
      let record = try context.fetch(FetchDescriptor<Moment>()).first(where: {
        $0.id == original.id
      })
    else { throw MomentError.missingMoment }
    guard record.text == original.text else { throw MomentError.changedMoment }
    record.replaceTextFromUserEdit(text)
    record.analysisData = nil
    record.processingState = "pending"
    try removeDerivedFacts(for: original.id, in: context)
    try save(context)
    return snapshot(record)
  }
  func deleteMoment(_ original: MomentSnapshot) throws {
    let context = try makeContext()
    guard
      let record = try context.fetch(FetchDescriptor<Moment>()).first(where: {
        $0.id == original.id
      })
    else { throw MomentError.missingMoment }
    guard record.text == original.text else { throw MomentError.changedMoment }
    try removeDerivedFacts(for: original.id, in: context)
    context.delete(record)
    try save(context)
  }
  func saveAnalysis(_ analysis: MomentAnalysis, momentID: UUID) throws -> MomentSnapshot {
    let context = try makeContext()
    guard
      let record = try context.fetch(FetchDescriptor<Moment>()).first(where: { $0.id == momentID })
    else { throw MomentError.missingMoment }
    record.analysisData = try JSONEncoder().encode(analysis)
    record.processingState = "complete"
    try save(context)
    return snapshot(record)
  }
  func saveAnalysis(_ analysis: MomentAnalysis, source: MomentSnapshot) async throws
    -> MomentSnapshot
  {
    guard let current = try loadMoments().first(where: { $0.id == source.id }),
      current.text == source.text
    else { throw MomentError.changedMoment }
    return try saveAnalysis(analysis, momentID: source.id)
  }
  func markAnalysesPending() throws -> [MomentSnapshot] {
    let context = try makeContext()
    let records = try context.fetch(FetchDescriptor<Moment>()).sorted {
      $0.createdAt > $1.createdAt
    }
    for record in records { record.processingState = "pending" }
    try save(context)
    return records.map(snapshot)
  }
  func loadFacts() throws -> [PersonalFactSnapshot] {
    try makeContext().fetch(FetchDescriptor<PersonalFact>()).sorted { $0.createdAt > $1.createdAt }
      .map {
        PersonalFactSnapshot(
          id: $0.id, label: $0.label, value: $0.value, createdAt: $0.createdAt,
          derivation: try $0.derivationData.map {
            try JSONDecoder().decode(FactDerivation.self, from: $0)
          })
      }
  }
  func saveFact(_ value: PersonalFactSnapshot) throws {
    let context = try makeContext()
    let record = PersonalFact(label: value.label, value: value.value)
    record.id = value.id
    record.createdAt = value.createdAt
    record.derivationData = try value.derivation.map { try JSONEncoder().encode($0) }
    context.insert(record)
    try save(context)
  }
  func replaceDerivedFacts(_ facts: [PersonalFactSnapshot], source: MomentSnapshot) throws {
    let context = try makeContext()
    guard
      let current = try context.fetch(FetchDescriptor<Moment>()).first(where: { $0.id == source.id }
      ),
      current.text == source.text, facts.allSatisfy({ $0.isSupported(by: source) })
    else {
      throw MomentError.missingMoment
    }
    let records = try context.fetch(FetchDescriptor<PersonalFact>())
    let existing = try records.filter { record in
      guard let data = record.derivationData else { return false }
      return try JSONDecoder().decode(FactDerivation.self, from: data).momentID == source.id
    }
    if existing.count == facts.count
      && existing.allSatisfy({ record in
        facts.contains { fact in
          record.label == fact.label && record.value == fact.value
            && (record.derivationData.flatMap {
              try? JSONDecoder().decode(FactDerivation.self, from: $0)
            }) == fact.derivation
        }
      })
    {
      return
    }
    for record in existing {
      if let data = record.derivationData,
        try JSONDecoder().decode(FactDerivation.self, from: data).momentID == source.id
      {
        context.delete(record)
      }
    }
    for fact in facts {
      let record = PersonalFact(label: fact.label, value: fact.value)
      record.id = fact.id
      record.createdAt = fact.createdAt
      record.derivationData = try fact.derivation.map { try JSONEncoder().encode($0) }
      context.insert(record)
    }
    // One transaction: readers never see a partially replaced extraction.
    try save(context)
  }
  func exportArchive() throws -> Data {
    // No suspension between these reads; actor-owned writes cannot interleave.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(
      PersonalArchive(
        exportedAt: Date(), moments: loadMoments().map(PersonalArchive.MomentRecord.init),
        facts: loadFacts()))
  }
}

extension LocalDataStore {
  func load() throws -> [Conversation] {
    try makeContext().fetch(FetchDescriptor<StoredConversation>())
      .map { try JSONDecoder().decode(Conversation.self, from: $0.payload) }
      .sorted {
        $0.updatedAt == $1.updatedAt
          ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt
      }
  }

  func save(_ conversations: [Conversation]) throws {
    try saveChanges(conversations, replacing: load())
  }

  /// Apply only this caller's changes. Unseen cloud chats must never be deleted.
  func save(_ updated: [Conversation], replacing original: [Conversation]) async throws {
    try saveChanges(updated, replacing: original)
  }

  private func saveChanges(_ updated: [Conversation], replacing original: [Conversation]) throws {
    let context = try makeContext()
    let records = try context.fetch(FetchDescriptor<StoredConversation>())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for old in original {
      let next = updated.first { $0.id == old.id }
      if let next, try encoder.encode(next) == encoder.encode(old) { continue }
      guard let record = records.first(where: { $0.id == old.id }),
        try encoder.encode(JSONDecoder().decode(Conversation.self, from: record.payload))
          == encoder.encode(old)
      else { throw BackupError.changedConversation }
      if let next { record.payload = try encoder.encode(next) } else { context.delete(record) }
    }
    for chat in updated where !original.contains(where: { $0.id == chat.id }) {
      guard !records.contains(where: { $0.id == chat.id }) else {
        throw BackupError.changedConversation
      }
      context.insert(StoredConversation(id: chat.id, payload: try encoder.encode(chat)))
    }
    try save(context)
  }

  func export(_ conversations: [Conversation]) throws -> Data {
    struct Archive: Encodable {
      let version = 1
      let conversations: [Conversation]
    }
    return try JSONEncoder().encode(Archive(conversations: conversations))
  }

  func recoverySnapshot(at date: Date, themeID: String?) throws -> RecoverySnapshot {
    // No suspension: all three collections are read on the database actor.
    try RecoverySnapshot(
      createdAt: date,
      moments: loadMoments().sorted { $0.id.uuidString < $1.id.uuidString },
      facts: loadFacts().sorted { $0.id.uuidString < $1.id.uuidString },
      conversations: load().sorted { $0.id.uuidString < $1.id.uuidString }, colourThemeID: themeID)
  }

  func restore(
    _ snapshot: RecoverySnapshot, safetyFolder: URL, at date: Date, previousThemeID: String? = nil
  ) throws {
    try snapshot.validate()
    let context = try makeContext()
    let previous = try recoverySnapshot(at: date, themeID: previousThemeID)
    try FileManager.default.createDirectory(at: safetyFolder, withIntermediateDirectories: true)
    let safetyURL = safetyFolder.appendingPathComponent("Before-restore-\(UUID().uuidString).json")
    try previous.encoded().write(to: safetyURL, options: .atomic)
    // Safety copy and replacement contain no suspension points. One database transaction.
    for record in try context.fetch(FetchDescriptor<Moment>()) { context.delete(record) }
    for record in try context.fetch(FetchDescriptor<PersonalFact>()) { context.delete(record) }
    for record in try context.fetch(FetchDescriptor<StoredConversation>()) {
      context.delete(record)
    }
    for value in snapshot.moments {
      let record = Moment(text: value.text, happenedAt: value.happenedAt)
      record.id = value.id
      record.createdAt = value.createdAt
      record.source = value.source
      record.analysisData = value.analysisData
      record.processingState = value.processingState
      context.insert(record)
    }
    for value in snapshot.facts {
      let record = PersonalFact(label: value.label, value: value.value)
      record.id = value.id
      record.createdAt = value.createdAt
      record.derivationData = try value.derivation.map { try JSONEncoder().encode($0) }
      context.insert(record)
    }
    for value in snapshot.conversations {
      context.insert(StoredConversation(id: value.id, payload: try JSONEncoder().encode(value)))
    }
    try save(context)
  }
}
