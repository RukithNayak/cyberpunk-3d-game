# NPC-03 — Deterministic retrieval mission lifecycle

**Status:** Accepted, Stage 1. 23 October 2026 (Asia/Kolkata).
**Owner:** Main Agent.
**Dependencies:** NPC-01 and CORE-04 accepted.

## Delivered

- Added `MissionTemplate`, a validated data-only resource contract, and one authored `retrieve_signal_cache.tres` template. It targets the existing WORLD-03 loot projection UUID and includes an authored fallback offer, `night_market` eligibility, and a 125-credit reward within the documented engineering bound.
- Added `MissionDirector` with deterministic mission/reward transaction IDs, eligibility checks against current faction standings, registered target presence and reachability checks, and offered→accepted→active→completed/failed transitions. Stale faction eligibility is checked again before acceptance and activation.
- Completion requires the authoritative entity record to show the target as collected. The director awards its bounded credit reward once. Model dialogue has no method to complete a mission or alter mission state.
- Added pure `prepare_snapshot`, data-only `capture_snapshot`, and no-signal `commit_prepared_snapshot` for CORE-04’s `domains.missions` owner. The snapshot validates state transitions, template/target/reward identity and credit totals. No Nodes are stored.
- Added and registered the `missions` suite. It covers missing/unreachable targets, hostile/low-standing factions, invalid reward bounds, repeated offers/transitions, objective failure, no model-claimed completion, snapshot round trips for all five lifecycle states, and SaveStore restore while the target is unavailable after unload.

## Verification

- `godot --headless --path game --editor --import` — exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite missions` — 41 cases, 0 failures, exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` — 951 cases, 0 failures, exit 0. Existing shutdown warnings remain: one ObjectDB instance and one `GodotBody3D` RID leak.
- `git diff --check` — exit 0.

No Blender or Godot MCP visual check applies to this data and logic task. The sample references the existing WORLD-03 loot fixture; it does not add geometry, mission UI or new world scenarios. A fuller in-game pickup interaction is outside this task’s existing files and is not claimed.

## Next

NPC-04 — guarded deterministic action dispatch — is next; it depends on NPC-02/03, INV-04 and AI-02, all accepted.
