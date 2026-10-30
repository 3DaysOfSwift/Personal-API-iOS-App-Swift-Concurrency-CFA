// swift-tools-version: 5.9
import PackageDescription

// Tests the shared Model and presentation state on macOS; not an iOS UI harness.
let package = Package(
  name: "PersonalAPIModelChecks", platforms: [.macOS(.v14)],
  targets: [
    .target(
      name: "PersonalAPI", path: "PersonalAPI",
      exclude: [
        "1 - View/Views/Backups/BackupsView.swift", "3 - App Resources", "4 - Swift Extensions",
        "1 - View/Components",
        "1 - View/PersonalAPIApp.swift", "1 - View/Views/Answer Feedback/AnswerFeedbackView.swift",
        "1 - View/Views/Conversation History/ConversationHistoryView.swift",
        "1 - View/Views/Edit Journal Entry/EditJournalEntryView.swift",
        "1 - View/Views/Export/ExportView.swift",
        "1 - View/Views/Journal Entries/JournalEntriesView.swift",
        "1 - View/Views/Life Map/LifeMapView.swift", "1 - View/Views/Lock/LockView.swift",
        "1 - View/Views/Moment Detail/MomentDetailView.swift",
        "1 - View/Views/Onboarding/OnboardingView.swift", "1 - View/Views/Query/QueryView.swift",
        "1 - View/Views/Root/RootView.swift", "1 - View/Views/Settings/SettingsView.swift",
        "1 - View/Views/Training/TrainingView.swift",
      ],
      sources: [
        "1 - View/Theme", "2 - AppModel", "1 - View/Views/Backups/BackupsViewModel.swift",
        "1 - View/Views/Answer Feedback/AnswerFeedbackViewModel.swift",
        "1 - View/Views/Conversation History/ConversationHistoryViewModel.swift",
        "1 - View/Views/Edit Journal Entry/EditJournalEntryViewModel.swift",
        "1 - View/Views/Export/ExportViewModel.swift",
        "1 - View/Views/Journal Entries/JournalEntriesViewModel.swift",
        "1 - View/Views/Life Map/LifeMapViewModel.swift", "1 - View/Views/Lock/LockViewModel.swift",
        "1 - View/Views/Moment Detail/MomentDetailViewModel.swift",
        "1 - View/Views/Onboarding/OnboardingViewModel.swift",
        "1 - View/Views/Query/QueryViewModel.swift", "1 - View/Views/Root/RootViewModel.swift",
        "1 - View/Views/Settings/SettingsViewModel.swift",
        "1 - View/Views/Training/TrainingViewModel.swift",
        "1 - View/Views/Settings/ExportDocument.swift",
      ], swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
    .testTarget(
      name: "PersonalAPITests", dependencies: ["PersonalAPI"], path: "PersonalAPITests",
      exclude: ["RaceConditions.xctestplan"],
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
  ])
