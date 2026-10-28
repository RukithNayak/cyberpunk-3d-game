## Task
- ID and title: CORE-04 — Add idempotent migrations and domain snapshot adapters
- Status: ready for Main Agent review
- Worker/model/reasoning: delegated persistence worker; model/reasoning override was not exposed in this task context
- Branch/commit or working-tree change reference: shared working tree; no commit

## Files changed
- `game/persistence/save_migrations.gd` — pure ordered v0→v1 snapshot migration; renames legacy `domain_records` to `domains`, rejects missing/future steps, and preserves other records.
- `game/persistence/snapshot_adapters.gd` — data-only capture, validation, prepare-all/commit-all adapter around existing state owners and callbacks.
- `game/persistence/entity_registry.gd` — stable ordered snapshot export plus bounded validation and prepared replacement methods; registry remains authoritative.
- `game/persistence/faction_state.gd` — deterministic standings export plus fixed-roster validation and prepared replacement methods; faction state remains authoritative.
- `game/persistence/save_store.gd` — optional migration service hook before v1 validation; a boolean false apply result rejects the load.
- `game/tests/persistence/test_migrations.gd` — previous-schema, rejection, adapter and migrated SaveStore regressions.
- `docs/state-contracts.md` — v0/v1 migration, adapter ownership/callback, value-budget and timed-effect clock contracts.
- `docs/reports/CORE-04-worker.md` — this evidence report.

## Tests run
- Working directory: repository root. Exact command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite migrations`. Before implementation, the registered suite ran 1 case with the expected failure `ordered save migration service is available` because `save_migrations.gd` was absent (exit 1). Godot also reported its sandboxed `user://` log and macOS certificate access warnings during this red run; the final suite used the approved Godot filesystem access.
- Final focused command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite migrations`; exit 0, 18 cases, 0 failures. Cases cover repeatable and idempotent migration, stable IDs and opaque domains, missing/future steps, failed migration byte/live preservation, scene-free snapshots, int64/float preservation, copy isolation, engine-object and duplicate-ID rejection, all-owner prepare failure, and old-file migration through SaveStore and prepared atomic apply.
- Existing registry command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite registry`; exit 0, 39 cases, 0 failures. Expected registry warnings appear in rejection-path tests.
- Existing SaveStore command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite save_store`; exit 0, 23 cases, 0 failures.
- Whitespace check: `git diff --check`; exit 0.
- A first implementation run exposed a GDScript method-name parse error in `FactionState.validate_snapshot_standings`; it was corrected before final runs. One intermediate fixture run also exposed a leaked temporary Node; the fixture now frees it and the final focused run exits without an ObjectDB leak warning.
- Not run: full `all` suite and editor import; Main Agent integration owns those checks.

## Results
- Migration acceptance: the previous v0 tagged-codec fixture migrates `domain_records` to `domains`; applying the current-version migration again returns identical data. Stable entity UUIDs, unknown domain payloads, and unrelated root records are retained.
- Failure safety: a missing migration step, future version, unsafe migration, invalid participant preparation, or candidate rejection returns an error before changing authoritative owners. The original file bytes remain unchanged on failed and successful old-version loads; migration does not auto-save.
- Adapter contract: `EntityRegistry` and `FactionState` remain the live owners. Adapter capture returns deep copies; it validates data-only shapes and owner bounds; apply prepares registry, faction, player and domain callbacks before any owner commit. Commit methods are synchronous, void and contractually silent/infallible. SaveStore treats an adapter `false` result as a rejected load.
- Domain ownership: the documented root keys are `player`, `entities`, `factions`, and `domains`; planned domain keys include `inventory`, `missions`, `npc_memory`, and `active_hacks`. Current player/domain participants are test fixtures only. No gameplay-domain integration is claimed. Domain owners must preserve opaque records and only apply keys they own.
- Time policy: remaining durations pause while unloaded/offline and advance only on the active, unpaused simulation clock; this is an engineering default for HACK-05, not approved balance.
- Budgets: adapter/migrated roots observe SaveStore’s 19-level envelope bound, 1,024 entries per container, 10,000 value budget, 16 KiB strings and 256-byte keys; each entity state also observes the registry’s own depth/value bounds. Existing signed int64 and float value types remain intact through snapshot copies.

## Risks
- Actual player, inventory, mission, NPC-memory and hack owners do not yet exist. Future callback integrations must honor mutation-free prepare and silent/infallible commit contracts, defer notifications until all swaps complete, and preserve opaque domain records.
- `SnapshotAdapters` is callback-driven; its transaction guarantee depends on every production participant following the documented prepare/commit contract.

## Follow-up tasks
- Main Agent: reproduce focused checks on integrated state and decide whether to include `migrations` in `all`; task runner already had the `migrations` case when this work began, so it was not edited here.
- Future owning gameplay tasks: implement their actual data owners and callback participants; no blocker to the current adapter/migration review.
