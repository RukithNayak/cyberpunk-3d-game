## Task
- ID and title: WORLD-03 — Hydrate and unload persistent entities
- Status: ready for Main Agent review
- Worker/model/reasoning: Follow-up ran in the existing subagent context; no model override was applied. Requested dispatch setting: `gpt-6-luna / medium`; actual model/reasoning remained inherited and was not independently verifiable. This follow-up does not claim that override.
- Branch/commit or working-tree change reference: `codex/stage-0-readiness`, uncommitted working-tree changes

## Files changed
- `game/world/entity_hydrator.gd` — transient registry-to-scene projection service with generation validation, prepare/activate/retire phases, tombstones, immediate authority commits, and interaction invalidation.
- `game/tests/world/test_chunk_persistence.gd` — 51 named behavior checks across hydration, door/loot/NPC state, save boundary, stale work, re-entry, callback cancellation and reentrant ownership.
- `game/tests/world/fixtures/persistent_projection.gd` — test projection that records ready-time state and interaction state and can trigger callback-driven lifecycle changes.
- `docs/evidence/WORLD-03/hydrator-red.log` — behavioral RED from the API shell: 35 cases, 20 expected failures, exit 1.
- `docs/evidence/WORLD-03/hydrator-green.log` — final focused GREEN: 35 cases, zero failures, exit 0.
- `docs/evidence/WORLD-03/hydrator-reentrancy-red.log` — initial tombstone reentrancy RED: 47 cases, two behavior failures, exit 1.
- `docs/evidence/WORLD-03/hydrator-all-reentrancy-red.log` — combined old-order RED: 51 cases, five behavior failures, exit 1.
- `docs/evidence/WORLD-03/hydrator-retained-red.log` — retained-instance RED: 51 cases, one behavior failure, exit 1.
- `docs/evidence/WORLD-03/hydrator-reentrancy-green.log` — final reentrancy GREEN: 51 cases, zero failures, exit 0.
- `docs/reports/WORLD-03-worker.md` — this worker report.

## Tests run
- Working directory: `/Users/rukithnayak/Documents/ChatGPT/Cyberpunk 3D Game`; exact command: `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_persistence`; exit 1 during RED, 35 cases and 20 behavioral failures. The failure log shows the missing behavior across prepare/default registration, ready-time projection, activation, state commits, tombstones, invalidation, save-boundary persistence, re-entry and cancellation. See `docs/evidence/WORLD-03/hydrator-red.log`.
- Same working directory and exact command; exit 0 during GREEN, 35 cases and zero failures. This includes a real `SaveStore` disk slot round-trip before unload and callback-driven prepare invalidation. See `docs/evidence/WORLD-03/hydrator-green.log`.
- Same working directory and exact command; reentrancy RED exit 1, 51 cases. The combined old-order reproduction failed five assertions covering loss of newer retirement bindings, enabled projection after canceled activation, and tombstone callback ownership/data. See `docs/evidence/WORLD-03/hydrator-all-reentrancy-red.log`.
- Same working directory and exact command; retained-instance RED exit 1, 51 cases and one failure: an old retirement callback disabled a later projection rebound to the same Node under a newer generation. See `docs/evidence/WORLD-03/hydrator-retained-red.log`.
- Same working directory and exact command; final reentrancy GREEN exit 0, 51 cases and zero failures. This includes re-entry on both replacement and retained instances, tombstone callback re-entry, and an activated projection for the invalid-Node registry-boundary case. See `docs/evidence/WORLD-03/hydrator-reentrancy-green.log`.
- Not run: full `all` suite. Main Agent owns the loader integration and cross-system runtime fixture.

## Results
- Authored persistent entities prepare against a current desired generation, merge only missing defaults into the registry through prepared snapshot replacement, and project copied registry state before scene entry. The projection fixture's `_ready` observes the hydrated door state with interactions disabled.
- Activation enables current prepared projections; duplicate live preparation rejects. Mutations first pass generation/binding validation, commit to the authoritative registry immediately, and reproject the updated copy.
- `collected` tombstones immediately disable and unbind loot, remove the projection, and keep it absent when the retained scene is prepared again. Door and NPC UUID records survive retirement/re-entry without duplicate runtime bindings.
- Manager pre-unload revokes bindings, disables interactions and emits one invalidation payload for the active chunk. Stale generations and invalid data deltas do not mutate current state.
- A missing runtime target rejects preparation before any authored defaults or bindings are committed. A callback that invalidates the generation cancels staged preparation; independently valid authored defaults can remain registered.
- Reentrant cleanup now captures and revokes only the old generation's ownership before invoking projection callbacks. Before each remaining disable callback, cleanup checks whether that UUID/node has been rebound; this preserves later projections when a callback reactivates the same retained scene. Activation publishes the exact binding before enabling it, allowing cancellation to disable it. Tombstone cleanup similarly revokes the old binding before callback dispatch and performs only Node cleanup afterward, preserving newer chunk/entity bindings.
- The real SaveStore regression saves and reloads a snapshot after door/loot mutations and before chunk retirement; the validator observes the current registry values.
- Consumed shared APIs: validated `ChunkManifest.get_chunk()` entity descriptors, `EntityRegistry` copy-out/prepared snapshot methods and `try_commit_state_delta`, and `WorldManager` desired IDs, lifecycle generations and `chunk_pre_unload`.

## Risks
- The focused worker suite exercises lifecycle-service reentrancy directly. Main Agent still owns final loader integration and runtime-fixture acceptance.
- Door, loot and NPC are generic projection fixtures. No gameplay-specific reward, mission or inventory behavior is included.
- The focused suite verifies re-entry and tombstone behavior on a retained instance; Main Agent's runtime fixture remains the integrated streaming acceptance evidence.

## Follow-up tasks
- Main Agent: validate the loader's `prepare_chunk` / `activate_chunk` / `retire_chunk` ordering with the hydrator and run the integrated runtime fixture; required before WORLD-03 acceptance.
- Main Agent: review and accept this worker deliverable, then update task and tracker evidence.
