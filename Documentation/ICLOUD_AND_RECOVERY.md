# iCloud sync and recovery backups

## Behaviour contract

- Local saves remain the completion boundary. CloudKit propagation and iCloud Drive upload are separate operations with separate status.
- The live database uses the private container `iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI.SwiftData` for journal entries, facts and conversations. No developer server is involved.
- This app is pre-release: one current database schema stores entries, facts and chats. No legacy chat-file import or historical schema migration is maintained.
- Chat commits apply only the caller's changes, compare modified/deleted records with the caller's originals, and preserve unseen chats. Late journal analysis checks the source text again in storage. CloudKit's cross-device conflict resolution is still eventual; the app does not promise a global transaction across devices.
- Launch, foreground and local database changes request automatic backup. Changes are captured at most once per 24 hours; manual backup bypasses that interval. iOS does not guarantee a daily background execution time. If the app is closed, the next eligible active session performs the backup.
- Recovery files include original text, dates, IDs, facts, derived metadata, chats, app version/build and the selected colour-theme ID. Face ID/passcode preferences are not transferred. Life Map is derived again from journal text.
- Latest and Previous rotate when content changes. Weekly copies are retained every seven days when the app gets a backup opportunity, even if content is unchanged. No automatic weekly deletion policy is applied.
- Each installation has its own iCloud Drive `Documents/Backups/<installation UUID>` folder. A new empty installation creates no snapshot. Account changes pause copying of retained files to protect the previous account's data.
- Settings → iCloud sync and recovery backups exposes manual backup, local recovery copies, file selection, preview counts/date and a replacement confirmation. Recovery JSON is distinct from the public dataset-export JSON.
- Restore validates first, writes a pre-restore local snapshot, then replaces all three collections in one database transaction. Failure to save the safety copy aborts restoration. Cancellation while queued does not restore. Once the transaction starts it completes durably. Restored changes propagate through CloudKit.
- Backup, preview and restore operations use the existing FIFO gate across suspension points. Database writes run on the storage actor; file work runs on the backup-file actor. Observers have retained task owners. No GCD is introduced.

## Apple account setup required

The project contains entitlements, private-container selection, iCloud Documents configuration and remote-notification background mode. They do not create containers in an Apple developer account.

1. Select the development team in Xcode and enable iCloud (CloudKit and iCloud Documents) and Push Notifications for the existing app identifier.
2. Create/assign both container identifiers above and `iCloud.com.3DaysOfSwiftConcurrency.PersonalAPI` for iCloud Drive; regenerate provisioning profiles as needed.
3. Run a signed development build on a device signed into iCloud. Verify that CloudKit creates the development schema. Inspect the container in CloudKit Console before deploying its schema to Production for distribution.
4. Do not ship until the device checks below pass. An unsigned build or a local test is not evidence of cloud transport.

## Required device checks

- Test creation, persistence and recovery using a fresh installation. Old development stores are not a supported upgrade path.
- On two signed devices using the same account, verify creation, edits and deletions for all three collections, including offline edits and concurrent edits to the same chat.
- Confirm the UI refreshes after imports. Verify a chat being answered during an import rejects a stale save and can reload afterward.
- Sign out, disable iCloud Drive, reconnect and change accounts. Verify local saves remain available and backup copying reports unavailable/pending/confirmed states honestly.
- Confirm Latest, Previous and Weekly in Files → iCloud Drive → Personal API. Wait for upload, then recover from a second installation. Verify its own folder never overwrites the original device's backups.
- Restore a nonempty backup and an empty backup; inspect the pre-restore copy, source text, facts, chats and next-launch theme. Confirm replacement also reaches the other device.
- Test malformed, unsupported, partially downloaded and inaccessible files. No live records should change on validation or pre-restore-write failure.
- Exercise very large journals and chats before claiming production-scale performance; snapshots currently load whole collections.

## Automated evidence

The shared macOS tests cover database conversation persistence, stale writes, daily throttling, manual override, weekly retention, independent installation folders, account guard, corrupt files, pre-restore safety, failed restores, queued cancellation, backup/restore serialization and the Backups ViewModel.

The cloud-copy policy tests use a local file adapter. They do not validate NSFileCoordinator, CloudKit, provisioning, Files UI or actual iCloud upload. Xcode build verification on this machine was blocked by unavailable CoreSimulator runtimes during asset-catalog compilation.

## Sync troubleshooting

The Backups screen keeps sync failures separate from recovery-file failures, so a successful backup cannot erase a sync error. It shows guidance for account, restriction, connection, quota and configuration failures, plus expandable error details. Configuration failures require a developer fix, not changes to the user's account.

“Check iCloud again” calls CloudKit accountStatus. It does not force SwiftData transport or claim that records have synced. A newer sync event takes priority over an older account check. “Open app settings” uses Apple's supported app-settings URL; the screen explains how to reach Apple Account settings manually. Availability is checked again when returning to this screen.
