# SQLite storage and dashboard split

1. Introduce a local SQLite database in Application Support, with transactions, WAL,
   schema versioning, preferences, binary image assets, per-file scan checkpoints,
   and indexed daily usage rows. Migrate existing app preferences and JSON caches
   only after successful database writes. Codex-owned logs remain read-only.
2. Preserve incremental parsing, duplicate-event suppression, model pricing, cache
   accounting, local calendar boundaries, and independent today/history scans.
   Persist only changed files. Store view snapshots and decoded images in memory.
3. Split today's details and activity overview into independent cards. Add a
   visibility toggle and ordering entry; migrate existing order and visibility.
4. Add a Data settings page showing database size and usage history. Allow cleanup
   older than a chosen retention period, including a custom number of days and all
   recorded usage. Confirm the concrete range in the UI, preserve settings/images,
   persist a cutoff to prevent reimport, and reclaim SQLite space off the UI thread.
5. Verify migrations/restarts, incremental updates, duplicate and archived records,
   model/long-context calculations, cleanup and concurrent scans, UI ordering and
   visibility. Compare a fresh scan with an independent calculation over real logs,
   measure cold/warm/incremental scans, visually inspect the app, and produce a
   signed local app and ZIP without publishing or performing Git writes.

Existing uncommitted changes are retained. SQLite becomes the source of persisted
application data; external Codex data and Sparkle/macOS-owned state stay external.
