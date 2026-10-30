# Personal API

> Build the dataset of yourself that future AI will be able to interrogate.

A private lifetime dataset, built one Moment at a time. Training stays useful forever. Think in years, not days; usefulness depends on the evidence accumulated, not a gamified score.

## Rules of the product

- The user owns the dataset. No developer server receives life data.
- Original user input is canonical. Never replace it with an AI summary, inferred emotion or generated tag.
- Save raw Moments before attempting enrichment. Processing failure must never lose a thought.
- Derived metadata and future indexes are disposable and regenerable from original sources. Record the processor and version.
- Open export is a core feature. Stable IDs, original text, source, timestamps and profile facts must leave the app intact.
- Answers must expose their evidence. Retrieved text and inferred conclusions are different things. Abstain when evidence is missing; do not manufacture personal history or causal explanations.
- Privacy is architectural. Collection should be deliberate, minimal and understandable.
- iCloud is synchronization through the user’s account. Do not claim it is a backup or enabled until configured and verified.

## Version 0.1: the complete loop

1. Introduce the long-term purpose with one onboarding screen.
2. Add labelled profile facts, or log a Moment with an optional user-provided event date.
3. Commit original text to local SwiftData storage immediately.
4. Produce an extractive title through the interchangeable Moment Processor boundary.
5. Query original Moments by meaning with on-device AI, or explicit keyword fallback; inspect every matching source.
6. Export the complete current dataset as versioned JSON.

Four tabs: Profile, Training (initial tab), Query, Settings. Dark mode only, content first, restrained typography and controls. Query is available from the first entry so ingestion/retrieval can be evaluated immediately.

## Honest boundaries

The current processor is deterministic and only extracts a title. The schema has space for factual tags, categories, themes, emotions, significance, life-event classification and evidence-supported event-date extraction. Foundation Models enrichment is not implemented yet.

Query uses the on-device Foundation Models language model where available to select relevant original Moments by meaning, capped at 20 results. Model selection can be wrong. Retrieved sources support a concise on-device answer with optional inspection of the original sources; users can inspect the original entries. Availability or generation failure uses explicitly labelled keyword overlap. Relative-date resolution and cross-entry reasoning are not implemented. It searches Moments only; profile facts are stored and exported but not retrieved yet. Feedback is session-local.

Face ID/device-passcode lock and inactive-screen concealment are included. This is an application access gate, not a separately encrypted vault. Exported JSON is plaintext and outside the app lock.

Public dataset import, HealthKit and attachments remain out of scope. Private CloudKit sync and recovery backups require the signed-device verification described in Documentation/ICLOUD_AND_RECOVERY.md. Profile corrections and portable archive import are subsequent work. Settings supports journal entry editing and deletion; the user’s revised words become canonical, with derived metadata regenerated. Do not market this prototype as a sole lifetime archive; users can export now.

## Next acceptance milestones

- Real-device capture, restart, lock/unlock and export verification.
- Import/export round trips with conflict handling and schema migrations.
- Availability-gated on-device structured enrichment with source spans and uncertainty.
- Semantic retrieval evaluated against a small labelled collection of known questions and source IDs.
- Evidence-grounded synthesis evaluated separately from retrieval.
- Complete signed-device iCloud account, conflict and recovery verification before release.

## Conversation prototype

Query supports saved conversations with follow-up questions, a New chat action and independent chat deletion/export. Journal entries remain the factual source. Conversational questions help interpret references but are not automatically saved as life facts. Previous AI output never becomes evidence for the next answer.

When information is missing, log a memory from the conversation, save it, return and choose Answer again. Each answer fetches current journal evidence. Useful/Not helpful feedback and an optional explanation are saved against the answer for evaluation, not local-model training.
