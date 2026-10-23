## Task
- ID and title: WORLD-01 — Define manifest and chunk lifecycle fixtures
- Status: ready for Main Agent review
- Worker/model/reasoning: Codex / model and reasoning not exposed by this worker handoff
- Branch/commit or working-tree change reference: shared working tree; no commit

## Files changed
- `game/world/chunk_manifest.gd` — atomic validated manifest for chunk IDs, world-space bounds, scene resources, and symmetric adjacency.
- `game/world/world_manager.gd` — desired lifecycle state, configurable preload/hysteresis margins, generation-tagged lifecycle signals, and activation/deactivation acknowledgements; no runtime loading.
- `game/world/fixtures/chunk_a.tscn` — greybox floor slab, collision, seam marker and 1.7 m viewpoint marker.
- `game/world/fixtures/chunk_b.tscn` — adjacent greybox floor slab, collision, seam marker and 1.7 m viewpoint marker.
- `game/tests/world/test_manifest.gd` — 37 focused checks for malformed records, adjacency/resource validation, seam geometry, desired sets, hysteresis, lifecycle generations and review regressions.
- `docs/world-contracts.md` — manifest, default margins, lifecycle event and WORLD-02 handoff contract.
- `docs/evidence/WORLD-01/chunk-seam-first-person.png` — 1280×720 renderer capture from the seam preview at first-person camera height.
- `docs/reports/WORLD-01-worker.md` — this evidence report.

## Tests run
- Working directory: repository root. Red command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest`; exit 1. Expected pre-implementation failure: `res://world/chunk_manifest.gd` was absent and the case `chunk manifest script is available` failed. The initial sandbox run also logged inability to write `user://logs`; subsequent Godot runs used the authorized `godot` command escalation.
- Working directory: repository root. `godot --headless --path game --editor --import`; exit 0 after implementation. Godot 4.7.2 registered `ChunkManifest` and `WorldManager` and completed project initialization/import.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest`; exit 0; 29 cases, 0 failures. Cases include malformed/duplicate IDs, unknown and asymmetric adjacency, missing and non-3D scenes, non-positive bounds, valid manifest, meeting collision bounds, first-person markers, preload boundary, hysteresis retention/release, and current/stale activation and deactivation generations.
- Review regression red run: `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest`; exit 1; 37 cases, 6 failures. Observed failures covered accepting a built-in `Node3D` subclass as a scene root, one-time binding for manifest and manager, synchronous pre-unload listeners seeing committed state, and new generation/preloading on re-entry during pending teardown.
- Review regression green run: `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest`; exit 0; 37 cases, 0 failures, no leak warnings. All six review regressions now pass.
- Working directory: repository root. `godot --path game --script /private/tmp/world_seam_capture.gd`; exit 0. OpenGL 4.1 Metal renderer on Apple M5 captured 1280×720 to `docs/evidence/WORLD-01/chunk-seam-first-person.png`; camera at 1.7 m faces across the adjacent slabs. The image shows contiguous floor surfaces meeting at the seam and both fixture markers.
- Not run: `godot --headless --path game --script res://tests/run_tests.gd -- --suite all`; not required for this focused task. No runtime loader, resource cancellation, persistence hydration, frame-time or memory behavior was exercised because those belong to WORLD-02 and later integration work. No human playtest was performed.

## Results
- Manifest acceptance — implemented and observed passing: rejected malformed and duplicate IDs, unknown/asymmetric adjacency, invalid/non-3D resources and invalid bounds; valid symmetric records remain available by sorted ID and copied record lookup.
- Review fixes — observed passing: manifest and manager bind once; a later configure attempt returns false without replacing records, margins, or lifecycle generations. `ClassDB.is_parent_class` accepts built-in Node3D-derived chunk roots while rejecting a `Control` root. `chunk_pre_unload` listeners observe the already-committed desired set and generation. Re-entering an active chunk while teardown is pending starts a new `PRELOADING` generation, invalidating the previous teardown acknowledgement.
- Seam fixtures — observed passing in the focused scene check: floor collision bounds meet at x=0 and viewpoints are at 1.7 m. Renderer evidence is at `docs/evidence/WORLD-01/chunk-seam-first-person.png`; it supports greybox seam continuity only, not final visual quality or traversal playtest acceptance.
- Desired lifecycle — observed passing: with test configuration 2 m preload / 1 m hysteresis, chunks are selected near the seam, retained on recrossing inside the hysteresis margin, and released beyond it. Defaults 12 m / 4 m are configurable engineering defaults, not approved tuning.
- Published contracts — `docs/world-contracts.md` defines record schema, bounds/adjacency policy, preload and hysteresis rules, `UNLOADED`/`PRELOADING`/`ACTIVE`, the event payload `{chunk_id, lifecycle_generation}`, and the WORLD-02 resource ownership boundary.
- Event payloads and generations — observed passing for `chunk_pre_unload`, `chunk_activated`, and `chunk_deactivated`; stale acknowledgements are rejected. `WorldManager` stores desired lifecycle state only and does not start or complete resource loads.

## Risks
- The manager exposes acknowledgements that WORLD-02 must call at actual resource lifecycle boundaries. Until that integration exists, `ACTIVE` is only an acknowledged state and does not prove a scene is present.
- The 12 m / 4 m defaults are illustrative engineering values and have no measured memory or hitch acceptance behind them.
- The screenshot is a simple greybox render, not evidence of visual quality, performance, or player traversal feel.

## Follow-up tasks
- WORLD-02 — Main Agent integration: connect generation-tagged desired lifecycle to asynchronous resource loading and release, ensuring stale load completions cannot reactivate retired chunks.
