import Foundation

protocol PersonalDataRepository: Sendable {
  func loadMoments() async throws -> [MomentSnapshot]
  func saveMoment(_ moment: MomentSnapshot) async throws
  func updateMoment(_ original: MomentSnapshot, text: String) async throws -> MomentSnapshot
  func deleteMoment(_ original: MomentSnapshot) async throws
  func saveAnalysis(_ analysis: MomentAnalysis, momentID: UUID) async throws -> MomentSnapshot
  func saveAnalysis(_ analysis: MomentAnalysis, source: MomentSnapshot) async throws
    -> MomentSnapshot
  func markAnalysesPending() async throws -> [MomentSnapshot]
  func loadFacts() async throws -> [PersonalFactSnapshot]
  func saveFact(_ fact: PersonalFactSnapshot) async throws
  func replaceDerivedFacts(_ facts: [PersonalFactSnapshot], source: MomentSnapshot) async throws
  func exportArchive() async throws -> Data
}

extension PersonalDataRepository {
  func saveAnalysis(_ analysis: MomentAnalysis, source: MomentSnapshot) async throws
    -> MomentSnapshot
  {
    try await saveAnalysis(analysis, momentID: source.id)
  }
}
