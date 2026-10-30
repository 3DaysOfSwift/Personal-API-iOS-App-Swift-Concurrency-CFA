import Foundation
import SwiftData

@Model final class Moment {
  var id: UUID = UUID()
  private(set) var text: String = ""
  var createdAt: Date = Date()
  var happenedAt: Date?
  var source: String = "manual"
  var analysisData: Data?
  var processingState: String = "pending"
  func replaceTextFromUserEdit(_ text: String) { self.text = text }
  init(text: String, happenedAt: Date? = nil) {
    self.text = text
    self.happenedAt = happenedAt
  }
}

@Model final class PersonalFact {
  var id: UUID = UUID()
  var label: String = ""
  var value: String = ""
  var createdAt: Date = Date()
  var derivationData: Data?
  init(label: String, value: String) {
    self.label = label
    self.value = value
  }
}

@Model final class StoredConversation {
  var id: UUID = UUID()
  var payload: Data = Data()
  init(id: UUID, payload: Data) {
    self.id = id
    self.payload = payload
  }
}
