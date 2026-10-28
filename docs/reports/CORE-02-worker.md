## Task
- ID and title: CORE-02 — Define registry and stable-identity contracts
- Status: ready for Main Agent review
- Worker/model/reasoning: delegated implementation worker; model metadata unavailable in this execution context
- Branch/commit or working-tree change reference: shared working tree; no commit

## Files changed
- `game/persistence/entity_registry.gd` — data-only UUID-keyed registry, defensive validation, copied lookup, recursive delta merge.
- `game/persistence/faction_state.gd` — bounded faction standing state, configurable thresholds, safe integer adjustment.
- `game/tests/persistence/test_registry.gd` — 39 focused assertions for the public contracts and validation edges.
- `docs/state-contracts.md` — identity, value, merge, unknown-ID, and faction threshold contracts.
- `docs/reports/CORE-02-worker.md` — this implementation and verification report.

## Tests run
- Working directory: repository root. `godot --headless --path game --script /tmp/core02_red.gd` — exit 1; temporary harness reported 1 case, 1 failure because the registry script was not yet present. Expected pre-implementation failure.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite registry` before the final safeguards — exit 1; 39 cases, 3 failures: merged state exceeded its container bound, and maximum/minimum integer standing adjustments overflowed the standing clamp. These were expected behavioral regressions.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite registry` after implementation — exit 0; 39 cases, 0 failures.
- Working directory: repository root. `godot --headless --path game --editor --import` — exit 0; Godot 4.7.2 registered both global classes and completed project initialization.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite sample` — exit 0; 2 cases, 0 failures.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` — exit 0; 2 cases, 0 failures. CORE-02 is registered as a focused suite by the Main Agent and is not yet included in `all` pending integration review.
- Not run: visual, performance, save/load, chunk unload and restart checks are outside this registry-contract deliverable; persistence adapters are CORE-03/04.

## Results
- Stable identity and duplicate handling — IDs must be canonical lowercase UUID text, version nibble 1–8 and valid RFC variant; invalid and duplicate registration warn and preserve existing records. Format validates identity but does not generate IDs or guarantee uniqueness against other systems.
- Copying and delta behavior — lookup returns a deep copy; deltas recursively merge dictionaries, replace arrays/scalars/null, and only commit after both delta and merged state pass validation.
- Data boundaries — only JSON-like values are allowed; Nodes and other Objects, packed arrays, non-finite floats, invalid keys, over-depth data, oversized containers/strings, and over-budget values are rejected. Unknown entity deltas do not create records.
- Faction contract — standing clamps to `-100..100`; defaults are inclusive hostile `-50`, allied `+50`; valid thresholds are configurable. Unknown reads are neutral `0`; unknown writes return false and status queries return false.
- Contracts published: `docs/state-contracts.md`. Integration assumption: consumers provide known faction IDs at construction and mint/persist stable UUIDs independently of scene Nodes.

## Risks
- UUID validation selects canonical RFC textual UUIDs from versions 1–8. Existing non-UUID IDs such as `door_123` must migrate or receive IDs from an owning identity source before registering.
- `register_entity` and `commit_state_delta` retain the required void signatures; rejection is observable through warnings and unchanged state, not a return code.
- Registry state is currently in memory; disk safety, migrations and save envelopes remain unimplemented by design.

## Follow-up tasks
- CORE-03/04: add versioned snapshot/save adapters that preserve these data bounds and failed-write/load guarantees; owner Main Agent scheduling.
- Main Agent: review and integrate the focused `registry` suite into `all`; the shared runner registration is owned by Main Agent.
