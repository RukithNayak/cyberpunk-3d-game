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

`ChunkLoader` is a transient `Node` configured once with `configure(manager, manifest, activation_root, backend, activation_budget, timeout_msec, clock, entity_lifecycle = null) -> bool`. The backend and clock are injectable for deterministic tests; production uses `ResourceLoader.load_threaded_request`, status polling and `load_threaded_get` only after `THREAD_LOAD_LOADED`. Each process-frame pump reconciles manager desired IDs and generations, polls outstanding work, and instantiates no more than the configured activation budget. A single `PackedScene.instantiate()` is indivisible and can exceed a frame budget; fixtures are small and no performance threshold is claimed.

Repeated desired-state observations coalesce to one in-flight request per chunk. `chunk_activated`, `chunk_failed`, and `chunk_unloaded` each publish a `{chunk_id, lifecycle_generation}` payload; activation also supplies the transient `Node3D`, and failure supplies a reason. Before activation the loader rechecks both desired membership and the current generation. Work that finishes after unload is discarded. A stale active instance remains available through rapid re-entry and is acknowledged for the fresh desired generation rather than duplicated. Leaving the desired set clears pending activation and unloads the transient instance. Timeout and resource failures publish one failure per generation and stop automatic retries; `retry_chunk(chunk_id)` restarts work only while that chunk is desired.

Scene entry (`_ready`) and the manager's activation acknowledgement can synchronously invalidate the request. The loader rechecks desired membership, generation and instance validity after both boundaries before publishing its own activation. Invalidated terrain is retired; if the manager already acknowledged it active, its current retirement generation is acknowledged deactivated. Retained-instance re-entry uses the same checks. Recursive pumps from callbacks return without work, preserving the outer pump's activation budget.

The production backend owns one native threaded-load token per requested path. A retry coalesces with its own in-progress or completed-but-unconsumed request instead of acquiring another token. Successful retrieval consumes that token. On subsequent pumps, the optional backend hook `release_unused(pending_paths)` consumes completed requests no longer needed by any pending chunk. It never calls `load_threaded_get` while work is in progress. Godot background work itself is not cancelable here: cancellation invalidates activation immediately, and unused results are drained when complete while the loader continues pumping. This is not a proof of bounded memory for large scenes or teardown with long-running jobs; WORLD-06 must measure that workload.

For authored adjacent chunks with touching X/Z bounds, the loader places a temporary collision wall at the shared edge while the neighbor has no active instance. This keeps the currently active floor intact and prevents crossing into unavailable space. The wall is removed after the neighbor activates. `res://tests/scenes/chunk_streaming.tscn` verifies real capsule collision/support through delayed neighbor status, injected failure, explicit retry, crossing, unload and backtracking; its backend uses actual threaded resources with controlled neighbor status. Overview captures document the fixture, not production art quality. Navigation synchronization, entity hydration, production player feel, large-scene frame-time/memory and human playtest gates remain separate work.

## Persistent entity projection lifecycle (WORLD-03)

Each authored chunk may include `entities`, defaulting to an empty array. Descriptors have exactly `uuid`, `node_path`, and `initial_state`. UUIDs use CORE-02 canonical identities and must be unique across the manifest. Node paths are distinct relative descendant paths within each chunk; empty, absolute, `.`/`..`, empty-segment and property/subname paths reject. Initial dictionaries obey the registry's data-only limits. Descriptors are copied; a manifest failure changes no accepted manifest. Entity targets are validated at hydration time, after all scene resources are available.

`EntityHydrator.configure(registry, manifest, manager) -> bool` binds a transient service once. Only the registry owns durable records; the hydrator keeps runtime Node bindings outside persistent state. Projection nodes implement `apply_persistent_state(state: Dictionary) -> void` and `set_interaction_enabled(enabled: bool) -> void`. They consume copies, must not mutate the registry, and must preserve hydrated values in `_ready`. Generic test projections do not implement gameplay authority, NPC behavior, loot rewards, inventory or missions.

The optional loader lifecycle protocol is:

- `prepare_chunk(chunk_id, generation, instance) -> bool`: before scene entry, validate the full descriptor set/targets/ownership, atomically register missing defaults through registry preparation, then project current records with interactions disabled. Existing records win over defaults. Collected/destroyed records suppress their projection; retained re-entry may therefore legitimately have no matching tombstoned node. Valid authored defaults may remain if a subsequent callback cancels scene activation.
- `activate_chunk(chunk_id, generation, instance) -> bool`: after scene entry but before manager acknowledgement/loader activation publication, validate the prepared root/current desired generation and enable interactions. This synchronous ordering allows rejection to remain retryable PRELOADING rather than falsely ACTIVE; manager activation observers receive fully hydrated projections. No process frame runs between enable and acknowledgement. Generation/instance checks run after each callback boundary. Retained instance re-entry prepares again before activation.
- `retire_chunk(chunk_id, generation, instance) -> void`: release only matching runtime ownership before teardown/rejected preparation. `chunk_pre_unload` also revokes bindings and disables interactions synchronously, allowing other consumers to cancel pending work. Cleanup must not erase newer generation/root bindings installed by a callback.

`commit_entity_delta(uuid, delta, generation) -> bool` requires a currently bound, valid, unsuppressed identity and matching desired generation before calling registry's checked commit API. Accepted mutations commit immediately and then project the registry copy. The save boundary therefore never depends on scraping mutable scene Nodes. Collected/destroyed tombstones revoke their binding, disable/remove the projection and remain in registry data for backtracking/save restoration. Domain-specific permissions and preconditions remain the responsibility of the owning gameplay services.

`get_runtime_entity(uuid)` returns only a current valid projection (otherwise null); `get_bound_entity_count()` counts runtime bindings. `interactions_invalidated(payload)` publishes `{chunk_id, lifecycle_generation, entity_uuids}` for retired active bindings; the generation is the retirement generation. Listeners must reject stale generations and tolerate reentrant publication. State is already committed and old authority revoked before callbacks can issue another interaction.

`res://tests/scenes/chunk_persistence.tscn` integrates real threaded chunks, generic door/loot/NPC projections, SnapshotAdapters and a real temporary SaveStore slot. It verifies save at pre-unload, removal of all runtime chunks, data restore, reverse-order re-entry, tombstones and stale writes. It is supporting WORLD-03 evidence, not the CORE-05 checkpoint/production-domain or WORLD-06 performance gate.

## Navigation handoff (WORLD-05)

`NavigationHandoff.configure(manager, manifest, loader, npc_simulation, persistent_actor_root) -> bool` binds once to the real `ChunkLoader`. The persistent actor root must live outside streamed chunk roots. The world service tracks each active root and its `NavigationRegion3D` instances by the loader's lifecycle generation. All desired chunks must be active, each region must be attached to the actor's `World3D.navigation_map`, and both map and regions must report a synchronized iteration before the service publishes readiness or allows an attached actor's AI/navigation to resume. Configure `NpcSimulationRecord` with `Callable(handoff, "is_navigation_ready_for_actor")` so its restore and ownership-transfer checks use the same gate.

`attach_actor(uuid, chunk_id, generation, actor) -> bool` binds one current actor to one streamed chunk and sets its `NavigationAgent3D` to the shared world map. While a desired neighbor loads or synchronizes, AI and driver movement stay paused. Once the actor's world position belongs to a different chunk and that destination is active and synchronized, the coordinator calls AI-04's generation-checked `transfer_actor`, reparents the same actor under the persistent root without changing its world transform, and updates its active chunk ownership. Manifest IDs are sorted; when bounds overlap at the exact boundary, the first containing ID owns the actor. A transfer cannot be accepted for a stale source/destination generation.

On final owner unload, AI-04 synchronously commits the data-only NPC record from `chunk_pre_unload`; after `ChunkLoader` finishes teardown, the coordinator releases any persistent runtime projection still owned by that chunk. The next authored projection calls `attach_actor` with its fresh chunk generation, and AI-04 restores it only after nav readiness. The coordinator never stores Nodes in the registry. `res://tests/scenes/navigation_boundary.tscn` exercises real threaded chunk loading, delayed map synchronization, pursuit in both directions, stale-generation reversal, source/destination unload and UUID restoration. Its generated two-rectangle maps and collision floors are test fixtures only; production navmesh authoring, player/world composition, larger map performance and human traversal feel remain later gates.

## Interior transitions (WORLD-04)

`InteriorTransition` is a project autoload so its fade overlay and transition state survive scene replacement. `request_interior_transition(scene_path)` rejects empty/non-`res://` paths and duplicate requests. It locks the current player through optional `add_control_lock(&"interior_transition")`, starts `ResourceLoader.load_threaded_request`, and emits `transition_started(scene_path)`. `transition_state_changed(state)` publishes `IDLE`, `LOADING`, `FADING_OUT`, `SWITCHING`, or `FADING_IN`. On successful load it fades to black, replaces the scene, positions a present player at the destination's optional `PlayerSpawn` marker, fades in, unlocks controls and emits `transition_finished(scene_path)`.

The first successful transition from a file-backed scene stores only the scene path and player `Vector3` needed to return; it does not retain scene Nodes. `return_from_interior()` reloads that scene asynchronously and restores the position. Existing data-only services remain outside scene ownership and survive the replacement. Missing paths, load errors, timeouts or scene replacement errors leave the current scene in place, fade back, unlock controls and emit `transition_failed(scene_path, reason)`. The threaded loader and control adapter are injectable for focused tests; production uses Godot's threaded resource loader. This is a gameplay-blocking transition, not a synchronous main-thread load.
