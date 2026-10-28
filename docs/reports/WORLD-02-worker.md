## Task
- ID and title: WORLD-02 — Add asynchronous preload and bounded activation
- Status: ready for Main Agent review
- Worker/model/reasoning: subagent worker; model metadata unavailable in this handoff
- Branch/commit or working-tree change reference: shared working tree, no commit

## Files changed
- `game/world/chunk_loader.gd` — asynchronous ResourceLoader backend, injected deterministic backend/clock, lifecycle-generation checks, retry and timeout handling, per-frame activation budget, transient instance ownership, and collision barriers along unavailable adjacent seams.
- `game/tests/world/test_chunk_loader.gd` — 33 focused checks for coalescing, activation budget, exact instance count, out-of-order completion, stale generations, rapid active re-entry, missing/timeout retry, terrain retention, seam barrier, and real ResourceLoader process-frame progress.
- `docs/world-contracts.md` — loader lifecycle, activation, failure/retry, barrier and bounded-work contract.
- `docs/reports/WORLD-02-worker.md` — this evidence report.

## Tests run
- Working directory: repository root. Expected pre-implementation red: `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_loader`; observed `FAIL: chunk loader exists for async streaming regressions`, `Suite chunk_loader: 1 cases, 1 failures` (runner's nonzero failure exit; expected missing implementation).
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite chunk_loader`; exit 0; 33 cases, 0 failures. Includes delayed/duplicate/missing/timeout/out-of-order fixtures, activation limit, pending cleanup, one instance per chunk, stale generation discard, retained-instance re-entry, retry, valid floor retention and unavailable seam barrier.
- Working directory: repository root. `godot --headless --path game --script res://tests/run_tests.gd -- --suite world_manifest`; exit 0; 37 cases, 0 failures.
- Working directory: repository root. `godot --headless --path game --editor --import`; exit 0; Godot 4.7.2 scan/import completed and registered `ChunkLoader`.
- Real ResourceLoader integration check runs in the focused suite with a 5 second deterministic deadline: the engine process frame count advances while the threaded fixture request is pending/polled, then the chunk activates.
- Not run: sample/all suites (Main Agent owns shared integration checks); visual traversal, performance acceptance, and human playtest. No performance claim is made.

## Results
- Background resource request: production backend uses `load_threaded_request` and frame polling. The only resource retrieval call is guarded by `THREAD_LOAD_LOADED`; timeout/failure paths do not wait for resource completion.
- Bounded activation: tests prove no more than one scene instantiates per pump for configured budget 1. A single `PackedScene.instantiate()` call cannot be preempted; the fixtures are small and no frame-time guarantee is inferred.
- Duplicate and stale work: repeat synchronization produces one request per chunk. Desired membership and lifecycle generation are rechecked before instantiation. A completion after unload is discarded; rapid re-entry reuses a still-active instance under the new generation rather than creating a duplicate.
- Failure recovery: missing and timed-out requests clear pending bookkeeping, publish a tagged failure, and require `retry_chunk` to restart. A neighboring request failure leaves the currently active floor and seam barrier intact.
- Seam availability: touching X/Z adjacent bounds receive a temporary collision wall until the neighboring instance is active. This addresses collision availability only; navigation, visual blending and traversal quality remain outside this task.
- Contract published in `docs/world-contracts.md`; loader consumes the accepted manager desired set, lifecycle generation, activation/deactivation acknowledgements, and manifest records. Domain hydration remains WORLD-03.

## Risks
- The one-time WORLD-01 manifest validation uses synchronous `load` to validate authored scenes; street-time ownership here issues only threaded requests. The validation's setup-time cost is outside this loader's process-frame work.
- The seam barrier is generated for touching X/Z AABBs and does not cover vertical adjacency or visual seam presentation.
- A single large scene instantiation remains indivisible and could exceed a frame; activation budget limits count per frame, not measured milliseconds.
- Headless tests establish lifecycle and collision-object presence, not in-game player traversal, navigation synchronization, renderer quality, or performance acceptance.

## Follow-up tasks
- WORLD-03 — Main Agent scheduling after WORLD-02 review; hydrate persistent entities and commit them before unload.
- WORLD-05 — after its prerequisites; synchronize navigation readiness across chunk boundaries.
