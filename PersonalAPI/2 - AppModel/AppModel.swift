import Foundation

/// The single live graph. Feature rules and screen state belong to their owners.
@MainActor final class AppModel {
  static let shared = AppModel.live()
  let backupFeature: any BackupFeature
  let lifeMapFeature: any LifeMapFeature
  let momentsFeature: any MomentsFeature
  let profileFeature: any ProfileFeature
  let conversationsFeature: any ConversationsFeature
  let queryFeature: any QueryFeature
  let authenticationFeature: any AuthenticationFeature
  let settingsFeature: any SettingsFeature
  private var launchTask: Task<Void, Never>?

  init(
    moments: any MomentsFeature, profile: any ProfileFeature, query: any QueryFeature,
    authentication: any AuthenticationFeature, settings: any SettingsFeature,
    conversations: any ConversationsFeature, lifeMap: any LifeMapFeature, backup: any BackupFeature
  ) {
    backupFeature = backup
    lifeMapFeature = lifeMap
    conversationsFeature = conversations
    momentsFeature = moments
    profileFeature = profile
    queryFeature = query
    authenticationFeature = authentication
    settingsFeature = settings
  }
  static func live() -> AppModel {
    let now: @Sendable () -> Date = { Date() }
    let repository = LocalDataStore(cloudEnabled: true)
    let preferences = LocalPreferences(defaults: .standard)
    let moments = MomentsManager(
      repository: repository, processor: LocalMomentProcessor(now: now), now: now)
    let profile = ProfileManager(repository: repository, now: now)
    let query = QueryManager(
      repository: repository, retriever: MomentRetriever(), index: LocalQueryIndex(),
      semanticSearch: OnDeviceMomentSearch(), answerer: OnDeviceMomentAnswerer())
    let conversations = ConversationsManager(
      repository: repository, query: query, now: now)
    let backup = BackupManager(
      repository: repository,
      files: RecoveryBackupFiles(
        folder: URL.applicationSupportDirectory.appendingPathComponent("PersonalAPI/Backups")),
      account: CloudAccountChecker(), preferences: preferences, now: now,
      canRestore: { !conversations.isBusy },
      reload: {
        async let refreshMoments: Void = moments.refresh()
        async let refreshProfile: Void = profile.refresh()
        _ = await (refreshMoments, refreshProfile)
        try await conversations.refresh()
      })
    return AppModel(
      moments: moments, profile: profile,
      query: query,
      authentication: AuthenticationManager(
        client: LocalDeviceAuthentication(), preferences: preferences),
      settings: SettingsManager(
        preferences: preferences, repository: repository, moments: moments, profile: profile),
      conversations: conversations,
      lifeMap: LifeMapManager(repository: repository, extractor: LifeMapExtractor()), backup: backup
    )
  }
  func applicationDidFinishLaunching() {
    guard launchTask == nil else { return }
    // Preferences are ready before any screen renders; construction itself does no I/O.
    authenticationFeature.loadPreference()
    settingsFeature.loadPreference()
    backupFeature.observeChanges()
    launchTask = Task {
      async let moments: Void = momentsFeature.loadIfRequired()
      async let profile: Void = profileFeature.loadIfRequired()
      _ = await (moments, profile)
      await backupFeature.backup(force: false)
    }
  }
  func awaitInitialLoads() async { await launchTask?.value }
}
