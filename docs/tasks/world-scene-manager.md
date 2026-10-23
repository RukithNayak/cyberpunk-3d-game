# World & Scene Manager Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Stream continuous exterior chunks and safely transition to selected interiors.

**Architecture:** Owns loading, activation, hydration and unload lifecycle. AI owns navigation behavior; persistence owns durable truth. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 2](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

## Global constraints

- Source priority: detailed design is approved for Stage 0/1; proposal confirmed requirements remain binding. Where the design is more specific, use it: single-player, Godot 4.7.2 with typed GDScript, Blender 5.2 target, local Ollama HTTP, grid inventory, family-keyed ammo, regenerating hack energy, and brief interior fades. Verify installed tools rather than assuming availability.
- Preserve the larger seamless exterior city direction, selected detailed interiors, stylized detailed visuals, first-person gun combat and no vehicles. Two chunks are feasibility content, not the final city scope.
- Target environment is the user-reported M5 MacBook Air with 16 GB shared memory. Do not assert benchmarks or release platforms have been verified. No paid service, large model download, new dependency or publishing is authorized by these plans.
- Persistent IDs and domain data survive unload/save/restart; runtime Nodes remain transient. Generative output is untrusted, bounded and subordinate to deterministic gameplay authority.

## Execution and completion rules

- Read the linked source sections, this file and the prerequisite tasks only; mock adjacent services until integration tasks require them. Proposed implementation paths below do not exist yet.
- Each task is a single bounded deliverable intended for one focused worker. If a deferred expansion task is selected, first split its content batches into separately reviewable tickets; it is not permission for an open-ended production pass.
- Follow the fast prototype verification policy in [AGENTS.md](../../AGENTS.md): focused checks and a quick gameplay/asset smoke check; routine red-first testing, exhaustive edge cases and separate review are optional. Task test expectations guide risk coverage; deferred checks must be recorded honestly.
- Accept working task behavior under the fast prototype policy; record minor bugs and deferred checks without marking those checks passed. Crashes, save corruption, blocked progression and unauthorized model actions remain blockers. Keep a short report with exact commands/exits and preserve unrelated work.
- All implementation boxes start unchecked. Checking off planning documentation does not indicate game implementation is complete. Deferred Stage 2–5 work is outside the currently approved Stage 0/1 scope.

## Review focus

- Save/load failures must preserve valid live and disk state (CORE-03/04); reward replays must not duplicate inventory (INV-04, NPC-04).
- Scene unload/death/cancel must invalidate late work and preserve UUID ownership (WORLD-02/03/05, AI-04, NPC-02).
- Interrupted reload/heal and repeated callbacks must conserve ammo/items and prevent attacks while dead (PLAYER-04, INV-03).
- Prompt injection, unseen facts and invalid/stale action parameters must never mutate progression (NPC-01/04/05).
- Concurrent inference, streaming and combat must remain responsive within explicitly ratified memory/frame budgets (WORLD-06); visual/playtest evidence is required in addition to headless checks.

## Task checklist

### WORLD-01: Define manifest and chunk lifecycle fixtures

- [x] **WORLD-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/chunk_manifest.gd`; `game/world/world_manager.gd`; `game/world/fixtures/chunk_a.tscn`; `game/world/fixtures/chunk_b.tscn`; `game/tests/world/test_manifest.gd`.

**Interfaces:** `ChunkManifest` stores IDs, bounds, scene paths and adjacency; `LoadState` is UNLOADED/PRELOADING/ACTIVE; `update_player_position(pos: Vector3) -> void`.

- [x] **Acceptance:** Two greybox chunks share a traversable seam. Validate IDs, adjacency and resources; define preload and hysteresis margins as configuration. Publish pre-unload, activated and deactivated event payloads containing chunk IDs and lifecycle generations.

- [x] **Test expectations:** Cover malformed manifests, unknown neighbor IDs, boundary positions and asymmetric adjacency policy. Fixture movement across the seam triggers expected desired load sets without flicker.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), world_manifest worker and independent reviewer gpt-6-luna medium; Main Agent reproduced 37/37. Review regressions: red 6, green 37/37. [Report](../reports/WORLD-01-worker.md), [contract](../world-contracts.md), [capture](../evidence/WORLD-01/chunk-seam-first-person.png). Working-tree branch codex/stage-0-readiness. Async loading remains WORLD-02.

### WORLD-02: Add asynchronous preload and bounded activation

Resumed 23 October 2026, Main Agent. Supporting acceptance work recorded before edits: add callback-invalidation regressions and a small test-only `game/tests/world/fixtures/activation_redirect.gd`; add `game/tests/scenes/chunk_streaming.{gd,tscn}` for real physics traversal/rendered evidence; integrate the accepted suite in `game/tests/run_tests.gd` and publish corrections in `docs/world-contracts.md`. These serve WORLD-02's existing stale-work/no-fall-through acceptance; no player-controller, hydration, navigation or asset-production scope is added. Unborn branch session baseline preserved under `/private/tmp/cyberpunk-world02-before/` for actual diff review.

- [x] **WORLD-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** WORLD-01, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/chunk_loader.gd`; `game/tests/world/test_chunk_loader.gd`.

**Interfaces:** WorldManager consumes ChunkLoader completion/failure events tagged with chunk ID and lifecycle generation.

- [x] **Acceptance:** Background resource loading never blocks street movement. Activation work is budgeted over frames; duplicate requests coalesce and stale completions cannot reactivate unwanted chunks. Timeout/missing-resource failures preserve valid current terrain and allow retry.

- [x] **Test expectations:** Inject delayed, duplicate, missing, timed-out and out-of-order load completions. Assert bounded activation work, one scene per chunk, cleanup of pending work and no fall-through while a neighbor is unavailable.

- [x] **Evidence recorded:** [Main Agent acceptance report](../reports/WORLD-02.md), [bounded review](../reports/WORLD-02-review.md), [exact final commands/exits](../evidence/WORLD-02/verification.json), [focused 42/42](../evidence/WORLD-02/chunk_loader.log), [integrated 184/184](../evidence/WORLD-02/all.log), [runtime data](../evidence/WORLD-02/runtime-rendered.json), [blocked](../evidence/WORLD-02/blocked-seam.png), [crossed](../evidence/WORLD-02/crossed-seam.png), [returned](../evidence/WORLD-02/returned-seam.png).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent / session model; reviewer gpt-6-luna / medium. Callback regressions reproduced red (40 checks/six failures) and green, native retry/cancellation cleanup red (42 checks/two failures) then green 42/42. Import/sample/all and standalone physics exits 0; unknown/malformed arguments exit 2 and deliberate failure exits 1 as expected. Godot MCP rendered fixture passed ten checks with zero errors; Main Agent inspected all three overview captures. Activation count and two-chunk collision/support are verified; large-scene frame-time/memory, production player feel and human playtest remain later gates. WORLD-03 now has its WORLD-02/CORE-04 prerequisites accepted.

### WORLD-03: Hydrate and unload persistent entities

Supporting integration scope recorded before implementation (23 October 2026): optional authored entity descriptors in `chunk_manifest.gd`, pre-entry/activation/retirement hooks in `chunk_loader.gd`, a boolean registry commit adapter in `entity_registry.gd`, corresponding regressions in their existing suites, and test-only projection/runtime fixtures. These support WORLD-03's existing hydration-before-interaction and unload/save-boundary requirements. Main owns shared files/runner/contracts; bounded worker owns hydrator and persistence tests. [Design/ownership ledger](../briefs/WORLD-03.md).

- [x] **WORLD-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** WORLD-02, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/entity_hydrator.gd`; `game/tests/world/test_chunk_persistence.gd`.

**Interfaces:** Use CORE-02 registry contracts and WORLD-01 pre-unload/activation events; entity identity comes from authored manifest data.

- [x] **Acceptance:** Hydrate modified entities before enabling interactions. Commit relevant changes before unloading; notify consumers to invalidate pending interactions and model requests. Collected/destroyed records do not respawn on backtracking.

- [x] **Test expectations:** Unlock a door, collect loot and alter an NPC record; unload/reload in reverse order and assert identical UUID/state with no duplicates. Exercise save at a boundary and stale loader responses after unload.

- [x] **Evidence recorded:** [Main Agent report](../reports/WORLD-03.md), [worker report](../reports/WORLD-03-worker.md), [review/resolution](../reports/WORLD-03-review.md), [exact commands/exits](../evidence/WORLD-03/verification.json), [focused54](../evidence/WORLD-03/chunk_persistence.log), [all258](../evidence/WORLD-03/all.log), [runtime](../evidence/WORLD-03/runtime-rendered.json), [before](../evidence/WORLD-03/before-changes.png), [restored](../evidence/WORLD-03/after-restore.png).

Accepted 23 October 2026 (Asia/Kolkata), Main Agent integration with bounded implementer/reviewer (requested gpt-6-luna / medium). Behavior-first hydrator red35/20→green; callback red51/5 and retained-root red51/1 corrected; final focused54/all258, registry44, manifest45, loader49, import/sample/runtime exit0. Real SnapshotAdapters/SaveStore boundary save, complete runtime unload, reverse-order reload and stale-generation rejection passed headless12 and rendered14. Two captures inspected; no final engine/script/leak warnings. Generic entity projections establish persistence/lifecycle only; gameplay-specific modules/checkpoints/performance remain their own gates. WORLD-04 now eligible.

### WORLD-04: Implement safe interior fades

- [x] **WORLD-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Supporting scope recorded before implementation (23 October 2026):** Register the transition coordinator as a Godot autoload so its fade/loading state survives scene replacement; add a native asynchronous resource backend, injectable backend for focused checks, and a small control/return-position adapter using the existing player group/name when present. Add a minimal exterior test fixture with a player so repeated entry/return can be exercised, and register the WORLD-04 suite in the existing runner. No production player controller or standalone gameplay is added.

**Files / ownership:** `game/world/interior_transition.gd`; `game/world/fixtures/{interior,exterior,transition_player}`; `game/tests/world/test_interiors.gd`; `game/tests/run_tests.gd`; `game/project.godot`; `docs/world-contracts.md`.

**Interfaces:** `request_interior_transition(scene_path: String) -> void` temporarily locks player interaction during a brief fade and publishes transition state.

- [x] **Acceptance:** Autoload transition coordinator performs asynchronous loads with brief fades while preserving seamless exterior behavior. Return position and registry data survive scene replacement; missing path and timed-out load retain current scene and restore controls. Blocking is a gameplay transition, not a synchronous load stall.

- [x] **Test expectations:** Two enter/exit cycles, duplicate requests, missing scene and injected timeout pass in `interiors` suite. Current scene survives failures; controls, return position and registry data are retained.

- [x] **Evidence recorded:** [WORLD-04 report](../reports/WORLD-04.md); focused suite, 21 checks, exit 0. Import exit 0. No rendered capture; transition fade duration and scene changes are exercised in the automated fixture.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Focused suite verifies two enter/return cycles, spawn and return position, persistent registry data, duplicate rejection, missing path and timed-out load. Visual capture not produced; the headless transition test exercises the configured Tween. [Report](../reports/WORLD-04.md).

### WORLD-05: Verify navigation handoff across chunk boundaries

Supporting scope recorded before implementation (23 October 2026): add a world-owned `NavigationHandoff` coordinator that tracks active chunk navigation regions by lifecycle generation, provides AI readiness only after every desired chunk map/region synchronizes, and deterministically assigns exact-boundary ownership to the lexicographically first containing manifest ID. Connect actor attachment and crossing to AI-04's UUID registry owner; on a ready destination, reparent the single actor to a persistent runtime root and atomically transfer its chunk/generation ownership, so source unload cannot retire it. On final owner unload, AI-04 captures state before the persistent projection is freed; re-entry attaches/restores a fresh actor. Add test-only navigation chunk fixtures plus a real threaded two-chunk boundary scene/suite, runner integration, and the shared navigation contract. This is feasibility content only: no production city navmesh, player integration, custom pathfinding, or performance budget is added.

- [x] **WORLD-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** WORLD-03, AI-03, AI-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/navigation_handoff.gd`; supporting transfer API in `game/features/npcs/npc_simulation_record.gd`; `game/tests/scenes/navigation_boundary.tscn`; `game/tests/world/{test_navigation_handoff.gd,fixtures/navigation_chunk*.tscn,fixtures/navigation_chunk.gd}`; Main Agent-owned runner, shared contract, task/report and tracker.

**Interfaces:** Publish navigation readiness before AI resumes; transfer each NPC UUID once using WORLD-01 lifecycle events and AI-04 records.

- [x] **Acceptance:** AI waits for synchronized navigation maps, follows the player across the two-chunk seam and is not duplicated or stranded during backtracking. Define ownership at the exact boundary.

- [x] **Test expectations:** Run repeated seam pursuits, unload a destination and reverse direction during synchronization. Check one owner per NPC, valid path recovery and no frame of navigation against an unavailable map. AI-04 is required before the unload scenario is accepted.

- [x] **Evidence recorded:** [WORLD-05 report](../reports/WORLD-05.md) records headless streamed physics/navigation evidence, exact commands/exits, Godot MCP version/project metadata, and remaining visual/production-world limits.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `navigation_handoff` 40/40, `ai_unload` 38/38, import exit 0, integrated `all` 727/727 (exit 0), and `git diff --check` exit 0. Navigation readiness uses all desired chunk generations and synchronized regions; real pursuit transfers UUID ownership once, reverses successfully after cancelling a stale generation, then saves/restores under a new generation. Exact boundary chooses the lexicographically first containing manifest ID. The integrated run logged one ObjectDB and one body RID teardown warning. See [report](../reports/WORLD-05.md); production district navmesh and player/world composition remain later work.

### WORLD-06: Assemble and measure the integrated feasibility build

- [ ] **WORLD-06 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-05, WORLD-04, WORLD-05, PLAYER-05, INV-05, AI-05, HACK-05, HACK-06, NPC-06, ASSET-03, ASSET-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/tests/scenes/feasibility.tscn`; `benchmarks/feasibility/`; `docs/feasibility-report.md`.

**Supporting implementation scope recorded 24 October 2026 before implementation:** The runnable feasibility scene requires an attached typed script, so the fixture files are `game/tests/scenes/feasibility.{tscn,gd}`. Store reproducible benchmark drivers/raw observations only under `benchmarks/feasibility/`; record integrated results and missing acceptance evidence in `docs/feasibility-report.md` and the task report. Do not alter production module ownership, project main-scene configuration, release presets, or unrelated benchmark files.

**Acceptance-detail recorded 24 October 2026 before implementation:** Keep Mara as a fixture-only runtime actor parented to streamed chunk A, close the fixture dialogue if the player leaves the interaction radius, the actor's chunk unloads, or player death fires, and smoke-check that an in-flight model response cannot publish after each cancellation. Add an opt-in `--benchmark` mode in the same fixture that records a 30-second no-request baseline followed by 60 seconds of repeated Ollama requests with seam traversal/backtracking; write per-phase frame/process/physics/draw-call/static-memory samples, request latencies and boundary load/hitch observations to `benchmarks/feasibility/sustained_load.json`. No production module ownership changes.

**Interfaces:** Compose existing module interfaces only; owns cross-system acceptance and benchmark reporting, not new gameplay logic.

- [ ] **Acceptance:** Combine one gun/enemy, two seamless chunks, one NPC mission offer, one hack, loot/grid inventory, healing and save/load. Record resolution/renderer, model/quantization/context, OS/game/model memory, sustained duration, median/tail frame times, first/full response latency and packaged macOS results. Ratify numeric performance/headroom thresholds before evaluating pass/fail; 60 FPS is a proposed target, not an achieved result.

- [ ] **Test expectations:** Traverse and backtrack during combat/inference; cancel dialogue by walking away/unloading/death. Save, quit, relaunch and compare domain states. Include provider-offline fallback, boundary memory/hitch regression and game-only versus concurrent inference measurements; record human playtest findings and failures.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

24 October 2026 evidence: implementation report [WORLD-06](../reports/WORLD-06.md), structured integration/measurement record [feasibility report](../feasibility-report.md), [fullscreen capture](../../benchmarks/feasibility/feasibility_startup.png) and [raw benchmarks](../../benchmarks/feasibility/). Import exit 0; latest fixture smoke 24/24 (exit 0), including delayed-response cancellation after walking away, chunk unload and player death; the real Ollama exchange, checkpoint recovery and offline fallback also passed. The latest opt-in 90-second benchmark exited 0 with 22 successful in-game requests and five activated boundaries. The concurrent model probe exited 0 and recorded host capacity, game/model RSS and first/full response times. Nine stale project Godot test processes were stopped before repeats; a separate desktop Godot app remained, and game-only frame/process outliers persisted, so measurements are descriptive. The no-extra-probe and initially contended runs are preserved. Godot MCP launch/read/stop succeeded with no runtime errors (existing script warnings reported). The first `all` run passed 1064/1064; a final rerun exited 1 at 1051 cases/2 failures due to the known intermittent AI-03 empty navigation route and its isolated-suite wrapper. Export failed because there is no `export_presets.cfg`; the export-template directory is empty. Performance thresholds remain unratified, free-memory headroom is not measured, packaged macOS evidence and human playtest findings are outstanding. All WORLD-06 checkboxes stay unchecked.

### WORLD-07: Expand city layout and prepare distribution

- [ ] **WORLD-07 — deliverable complete** (Stage 2–5 (deferred)).

**Dependencies / sequencing:** WORLD-06; approved playable scope, platform and budget decisions. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/districts/`; `benchmarks/world/`; `game/export_presets.cfg`; `docs/release-checklist.md`.

**Interfaces:** Use existing manifests, navigation and lifecycle contracts; expansion is content in the same continuous exterior city.

- [ ] **Acceptance:** After feasibility, split approved district layouts/interiors into individual content tickets with landmarks, routes, travel-time and budget criteria. Split release exports, clean-machine model setup and signing/distribution decisions into target-specific tickets. Candidate three districts is not a fixed requirement.

- [ ] **Test expectations:** Validate every added district’s alternate routes, backtracking, mission reachability and sustained memory; test selected packaged platforms and local-model/fallback installation on a clean machine.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
