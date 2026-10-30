import Foundation

@testable import PersonalAPI

enum TestFailure: Error { case unavailable }
actor MemoryRepository: PersonalDataRepository {
  var moments: [MomentSnapshot] = []
  var facts: [PersonalFactSnapshot] = []
  var fails = false
  var momentLoads = 0
  func setFailure(_ value: Bool) { fails = value }
  func loadMoments() throws -> [MomentSnapshot] {
    momentLoads += 1
    if fails { throw TestFailure.unavailable }
    return moments
  }
  func saveMoment(_ moment: MomentSnapshot) throws {
    if fails { throw TestFailure.unavailable }
    moments.insert(moment, at: 0)
  }
  func updateMoment(_ original: MomentSnapshot, text: String) throws -> MomentSnapshot {
    if fails { throw TestFailure.unavailable }
    guard let index = moments.firstIndex(where: { $0.id == original.id }) else {
      throw MomentError.missingMoment
    }
    guard moments[index].text == original.text else { throw MomentError.changedMoment }
    let old = moments[index]
    moments[index] = .init(
      id: old.id, text: text, createdAt: old.createdAt, happenedAt: old.happenedAt,
      source: old.source, analysisData: nil, processingState: "pending")
    facts.removeAll { $0.derivation?.momentID == original.id }
    return moments[index]
  }
  func deleteMoment(_ original: MomentSnapshot) throws {
    if fails { throw TestFailure.unavailable }
    guard let current = moments.first(where: { $0.id == original.id }) else {
      throw MomentError.missingMoment
    }
    guard current.text == original.text else { throw MomentError.changedMoment }
    moments.removeAll { $0.id == original.id }
    facts.removeAll { $0.derivation?.momentID == original.id }
  }
  func saveAnalysis(_ analysis: MomentAnalysis, momentID: UUID) throws -> MomentSnapshot {
    if fails { throw TestFailure.unavailable }
    guard let index = moments.firstIndex(where: { $0.id == momentID }) else {
      throw MomentError.missingMoment
    }
    moments[index].analysisData = try JSONEncoder().encode(analysis)
    moments[index].processingState = "complete"
    return moments[index]
  }
  func markAnalysesPending() throws -> [MomentSnapshot] {
    if fails { throw TestFailure.unavailable }
    for index in moments.indices { moments[index].processingState = "pending" }
    return moments
  }
  func loadFacts() throws -> [PersonalFactSnapshot] {
    if fails { throw TestFailure.unavailable }
    return facts
  }
  func saveFact(_ fact: PersonalFactSnapshot) throws {
    if fails { throw TestFailure.unavailable }
    facts.insert(fact, at: 0)
  }
  func replaceDerivedFacts(_ replacements: [PersonalFactSnapshot], source: MomentSnapshot) throws {
    if fails { throw TestFailure.unavailable }
    guard moments.contains(where: { $0.id == source.id && $0.text == source.text }),
      replacements.allSatisfy({ $0.isSupported(by: source) })
    else { throw MomentError.missingMoment }
    facts.removeAll { $0.derivation?.momentID == source.id }
    facts.append(contentsOf: replacements)
  }
  func exportArchive() throws -> Data {
    if fails { throw TestFailure.unavailable }
    return try JSONEncoder().encode(
      PersonalArchive(
        exportedAt: Date(timeIntervalSince1970: 100),
        moments: moments.map(PersonalArchive.MomentRecord.init), facts: facts))
  }
}
@MainActor final class MemoryPreferences: PreferencesRepository {
  var colourThemeID: String?
  var onboarded = false
  var lockEnabled = false
}
@MainActor final class AuthenticationStub: DeviceAuthentication {
  var success = true
  var suspended = false
  var pending: CheckedContinuation<Bool, Error>?
  var calls = 0
  func authenticate() async throws -> Bool {
    calls += 1
    if suspended { return try await withCheckedThrowingContinuation { pending = $0 } }
    return success
  }
  func cancel() {}  // Intentionally completes late to test the manager's generation guard.
  func complete() {
    pending?.resume(returning: success)
    pending = nil
  }
}
actor FailingProcessor: MomentProcessor {
  func analyse(_ input: MomentInput) throws -> MomentAnalysis { throw TestFailure.unavailable }
}
@MainActor struct TestAppModelFactory {
  let repository = MemoryRepository()
  let preferences = MemoryPreferences()
  let authentication = AuthenticationStub()
  let app: AppModel
  init(processor: (any MomentProcessor)? = nil) {
    let now: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) }
    let moments = MomentsManager(
      repository: repository, processor: processor ?? LocalMomentProcessor(now: now), now: now)
    let profile = ProfileManager(repository: repository, now: now)
    let query = QueryManager(
      repository: repository, retriever: MomentRetriever(), index: LocalQueryIndex())
    app = AppModel(
      moments: moments, profile: profile,
      query: query,
      authentication: AuthenticationManager(client: authentication, preferences: preferences),
      settings: SettingsManager(
        preferences: preferences, repository: repository, moments: moments, profile: profile),
      conversations: ConversationsManager(
        repository: MemoryConversationRepository(), query: query, now: now),
      lifeMap: LifeMapManager(repository: repository, extractor: LifeMapExtractor()),
      backup: BackupStub())
  }
}

actor MemoryConversationRepository: ConversationRepository {
  var items: [Conversation] = []
  var fails = false
  func setFailure(_ value: Bool) { fails = value }
  func load() throws -> [Conversation] {
    if fails { throw TestFailure.unavailable }
    return items
  }
  func save(_ conversations: [Conversation]) throws {
    if fails { throw TestFailure.unavailable }
    items = conversations
  }
  func export(_ conversations: [Conversation]) throws -> Data {
    try JSONEncoder().encode(conversations)
  }
}

@MainActor final class BackupStub: BackupFeature {
  var errorContext: RecoveryFailureContext?
  var syncIssue: CloudSyncIssue?
  var accountStatus: String?
  var isCheckingAccount = false
  var checks = 0
  func checkSyncAvailability() async { checks += 1 }
  var isRestoring = false
  var localCopies: [RecoveryCopy] = []
  func loadLocalCopies() async {}
  var isWorking = false
  var lastBackup: Date?
  var status = "Ready"
  var syncStatus = "Ready"
  var error: String?
  var preview: RecoverySnapshot?
  var requests: [Bool] = []
  var restored = false
  var inspected: URL?
  func observeChanges() {}
  func backup(force: Bool) async { requests.append(force) }
  func inspect(_ url: URL) async { inspected = url }
  func restorePreview() async { restored = true }
  func discardPreview() { preview = nil }
}

actor CloudAccountStub: CloudAccountChecking {
  var state: CloudAccountState = .available
  func setState(_ state: CloudAccountState) { self.state = state }
  func check() -> CloudAccountState { state }
}
