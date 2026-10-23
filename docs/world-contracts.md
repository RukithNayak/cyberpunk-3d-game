# World lifecycle contracts

Stage 1 WORLD-01 publishes the manifest and desired lifecycle interface consumed by WORLD-02. It does not load, instantiate, free, or hydrate chunk resources at runtime.

## Chunk manifest

`ChunkManifest` is an in-memory `RefCounted` service. `configure(records: Array) -> bool` binds it once, replacing its contents only after the complete candidate passes validation. Later configuration attempts return false without changing the manifest. Each record has:

```gdscript
{"id": "district_block_a", "bounds": AABB(...), "scene_path": "res://world/fixtures/chunk_a.tscn", "adjacent": ["district_block_b"]}
```

IDs begin with an ASCII letter and contain only ASCII letters, digits, `_` or `-`; IDs are unique. Bounds are finite, positive-size world-space `AABB`s. A scene path must resolve to an instantiable `PackedScene`. Adjacent IDs must exist, cannot repeat, and must list each other symmetrically. Adjacency declares authored topology; runtime streaming distance is independent. `get_chunk_ids()` returns sorted IDs and `get_chunk(id)` returns a deep copy. The manifest retains no Nodes or loaded scene instances.

## Desired lifecycle

`WorldManager.configure(manifest, preload_margin, hysteresis_margin) -> bool` binds the manager once and accepts finite non-negative margins. Later configuration attempts return false without changing state or lifecycle generations. Defaults are 12 m preload and 4 m hysteresis. These are engineering defaults to make the boundary contract executable, not approved city streaming or performance tuning.

`update_player_position(pos: Vector3) -> void` computes desired chunk IDs. A chunk enters the desired set when its bounds expanded by `preload_margin` contain the player position. An already desired chunk remains desired until its bounds expanded by `preload_margin + hysteresis_margin` no longer contain the player. `get_desired_chunk_ids()` returns sorted IDs. The manager exposes `UNLOADED`, `PRELOADING`, and `ACTIVE`; each newly desired period enters `PRELOADING` with a fresh generation, including re-entry while an older active instance awaits teardown. Loading and resource ownership remain with WORLD-02.

Lifecycle handoff signals each carry a dictionary with exactly the stable chunk ID and a monotonically increasing per-chunk `lifecycle_generation`:

```gdscript
{"chunk_id": "district_block_a", "lifecycle_generation": 3}
```

- `chunk_pre_unload(payload)` fires when a desired chunk leaves the set. Before emitting, the manager commits the reduced desired set, advances the generation, and changes a pending preload to `UNLOADED`, so synchronous listeners observe the new state. An active chunk remains `ACTIVE` until its owner confirms teardown.
- `acknowledge_activated(chunk_id, generation) -> bool` accepts only the current generation of a desired `PRELOADING` chunk, moves it to `ACTIVE`, and emits `chunk_activated(payload)`.
- `acknowledge_deactivated(chunk_id, generation) -> bool` accepts only the current generation of an `ACTIVE` chunk outside the desired set, moves it to `UNLOADED`, and emits `chunk_deactivated(payload)`.

Consumers compare generations before accepting asynchronous completion. The manager keeps desired lifecycle state only; it has no `ResourceLoader` jobs, scene ownership, persistence adapters, navigation readiness or interior transitions.

## Seam fixtures

`chunk_a.tscn` and `chunk_b.tscn` occupy adjacent 10 m-wide floor slabs with collision bounds meeting at x=0. Both include a `FirstPersonSeamView` marker at y=1.7 m. These are greybox feasibility fixtures and visual evidence; they do not define final district geometry or a human playtest gate.

## Asynchronous chunk loader

`ChunkLoader` is a transient `Node` configured once with `configure(manager, manifest, activation_root, backend, activation_budget, timeout_msec, clock) -> bool`. The backend and clock are injectable for deterministic tests; production uses `ResourceLoader.load_threaded_request`, status polling and `load_threaded_get` only after `THREAD_LOAD_LOADED`. Each process-frame pump reconciles manager desired IDs and generations, polls outstanding work, and instantiates no more than the configured activation budget. A single `PackedScene.instantiate()` is indivisible and can exceed a frame budget; fixtures are small and no performance threshold is claimed.

Repeated desired-state observations coalesce to one in-flight request per chunk. `chunk_activated`, `chunk_failed`, and `chunk_unloaded` each publish a `{chunk_id, lifecycle_generation}` payload; activation also supplies the transient `Node3D`, and failure supplies a reason. Before activation the loader rechecks both desired membership and the current generation. Work that finishes after unload is discarded. A stale active instance remains available through rapid re-entry and is acknowledged for the fresh desired generation rather than duplicated. Leaving the desired set clears pending activation and unloads the transient instance. Timeout and resource failures publish one failure per generation and stop automatic retries; `retry_chunk(chunk_id)` restarts work only while that chunk is desired.

Scene entry (`_ready`) and the manager's activation acknowledgement can synchronously invalidate the request. The loader rechecks desired membership, generation and instance validity after both boundaries before publishing its own activation. Invalidated terrain is retired; if the manager already acknowledged it active, its current retirement generation is acknowledged deactivated. Retained-instance re-entry uses the same checks. Recursive pumps from callbacks return without work, preserving the outer pump's activation budget.

The production backend owns one native threaded-load token per requested path. A retry coalesces with its own in-progress or completed-but-unconsumed request instead of acquiring another token. Successful retrieval consumes that token. On subsequent pumps, the optional backend hook `release_unused(pending_paths)` consumes completed requests no longer needed by any pending chunk. It never calls `load_threaded_get` while work is in progress. Godot background work itself is not cancelable here: cancellation invalidates activation immediately, and unused results are drained when complete while the loader continues pumping. This is not a proof of bounded memory for large scenes or teardown with long-running jobs; WORLD-06 must measure that workload.

For authored adjacent chunks with touching X/Z bounds, the loader places a temporary collision wall at the shared edge while the neighbor has no active instance. This keeps the currently active floor intact and prevents crossing into unavailable space. The wall is removed after the neighbor activates. `res://tests/scenes/chunk_streaming.tscn` verifies real capsule collision/support through delayed neighbor status, injected failure, explicit retry, crossing, unload and backtracking; its backend uses actual threaded resources with controlled neighbor status. Overview captures document the fixture, not production art quality. Navigation synchronization, entity hydration, production player feel, large-scene frame-time/memory and human playtest gates remain separate work.
