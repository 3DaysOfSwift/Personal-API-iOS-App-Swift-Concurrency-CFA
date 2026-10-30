import CloudKit
import Foundation

enum CloudAccountState: Sendable {
  case available, signedOut, restricted, unavailable
}

struct CloudSyncIssue: Sendable, Equatable {
  enum Kind: Sendable { case account, restricted, network, storage, configuration, unknown }
  let kind: Kind
  let details: String?

  var guidance: String {
    switch kind {
    case .account:
      return
        "Open Settings, tap your name and sign in to your Apple Account. Under iCloud, check that Personal API is allowed to use iCloud. Then return here and check again."
    case .restricted:
      return
        "iCloud access is restricted. Check Screen Time or ask the person managing this device to allow iCloud access, then check again."
    case .network:
      return
        "Check your Wi-Fi or mobile data connection, then check again. Sync will retry automatically when the connection is available."
    case .storage:
      return
        "Your iCloud storage is full. Open Settings → your name → iCloud to free space or change your storage plan, then check again."
    case .configuration:
      return
        "This version of the app is not configured correctly for iCloud. This needs an app update from the developer; changing your iCloud settings will not fix it. Your local data is not deleted."
    case .unknown:
      return
        "Check your connection and iCloud account below. If the problem continues, share the error details with the app developer. Your local data is not deleted."
    }
  }

  var offersSettings: Bool { kind != .configuration }

  static func from(_ error: Error?) -> Self {
    guard let error else { return Self(kind: .unknown, details: nil) }
    let nsError = error as NSError
    let kind = classify(nsError, depth: 0)
    return Self(
      kind: kind, details: diagnosticDetails(nsError, depth: 0))
  }

  // Preserve underlying failures without dumping record IDs or record contents.
  private static func diagnosticDetails(_ error: NSError, depth: Int) -> String {
    let summary = "\(error.localizedDescription) (\(error.domain), \(error.code))"
    guard depth < 8 else { return summary }
    var messages = [summary]
    if let reason = error.localizedFailureReason { messages.append(reason) }
    for child in childErrors(error) {
      messages.append(diagnosticDetails(child, depth: depth + 1))
    }
    return messages.joined(separator: "\n\n")
  }

  private static func childErrors(_ error: NSError) -> [NSError] {
    var children: [NSError] = []
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      children.append(underlying)
    }
    if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
      children.append(contentsOf: partial.values.map { $0 as NSError })
    }
    if let detailed = error.userInfo["NSDetailedErrors"] as? [NSError] {
      children.append(contentsOf: detailed)
    }
    return children
  }

  private static func classify(_ error: NSError, depth: Int) -> Kind {
    guard depth < 8 else { return .unknown }
    if error.domain == CKErrorDomain, let code = CKError.Code(rawValue: error.code) {
      switch code {
      case .notAuthenticated: return .account
      case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
        return .network
      case .quotaExceeded: return .storage
      case .badContainer, .badDatabase, .missingEntitlement: return .configuration
      default: break
      }
    }
    for child in childErrors(error) {
      let kind = classify(child, depth: depth + 1)
      if kind != .unknown { return kind }
    }
    return .unknown
  }
}
