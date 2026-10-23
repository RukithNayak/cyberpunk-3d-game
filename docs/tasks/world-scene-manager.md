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

**Night Market fixture scope recorded 24 October 2026 before implementation:** Add a walkable, lightweight Godot-authored plaza, market street, and service alley around the existing WORLD-06 player, NPC, enemy, loot and hack targets. Include named layout landmarks for fixture smoke checks, readable neon wayfinding, and collidable storefront/stall blockout props while keeping the existing interaction clearances, positions, streaming contracts, smoke/benchmark semantics, project main scene and production modules unchanged. Use no downloaded or newly authored Blender assets and no new dependencies. This is test-only Stage 1 dressing, not WORLD-07 district expansion.

**Interfaces:** Compose existing module interfaces only; owns cross-system acceptance and benchmark reporting, not new gameplay logic.

- [ ] **Acceptance:** Combine one gun/enemy, two seamless chunks, one NPC mission offer, one hack, loot/grid inventory, healing and save/load. Record resolution/renderer, model/quantization/context, OS/game/model memory, sustained duration, median/tail frame times, first/full response latency and packaged macOS results. Ratify numeric performance/headroom thresholds before evaluating pass/fail; 60 FPS is a proposed target, not an achieved result.

- [ ] **Test expectations:** Traverse and backtrack during combat/inference; cancel dialogue by walking away/unloading/death. Save, quit, relaunch and compare domain states. Include provider-offline fallback, boundary memory/hitch regression and game-only versus concurrent inference measurements; record human playtest findings and failures.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

24 October 2026 evidence: implementation report [WORLD-06](../reports/WORLD-06.md), structured integration/measurement record [feasibility report](../feasibility-report.md), [fullscreen capture](../../benchmarks/feasibility/feasibility_startup.png) and [raw benchmarks](../../benchmarks/feasibility/). Import exit 0; latest fixture smoke 24/24 (exit 0), including delayed-response cancellation after walking away, chunk unload and player death; the real Ollama exchange, checkpoint recovery and offline fallback also passed. The latest opt-in 90-second benchmark exited 0 with 22 successful in-game requests and five activated boundaries. The concurrent model probe exited 0 and recorded host capacity, game/model RSS and first/full response times. Nine stale project Godot test processes were stopped before repeats; a separate desktop Godot app remained, and game-only frame/process outliers persisted, so measurements are descriptive. The no-extra-probe and initially contended runs are preserved. Godot MCP launch/read/stop succeeded with no runtime errors (existing script warnings reported). The first `all` run passed 1064/1064; a final rerun exited 1 at 1051 cases/2 failures due to the known intermittent AI-03 empty navigation route and its isolated-suite wrapper. Export failed because there is no `export_presets.cfg`; the export-template directory is empty. Performance thresholds remain unratified, free-memory headroom is not measured, packaged macOS evidence and human playtest findings are outstanding. All WORLD-06 checkboxes stay unchecked.

24 October 2026 Night Market fixture evidence: added landmark smoke assertion observed red before implementation (24/25; expected missing-layout assertion), then `godot --headless --path game --editor --import` exit 0 and `godot --headless --path game res://tests/scenes/feasibility.tscn -- --smoke` exit 0 (25/25). See [Night Market report](../reports/WORLD-06-night-market.md). Runtime visual inspection remains unrun while the existing user feasibility process is preserved; human playtest, packaged build, and performance acceptance remain open.

### WORLD-07: Expand city layout and prepare distribution

**Scope clarification recorded 24 October 2026:** The user approved the first Night Market neighborhood as the separate Stage 2 tasks WORLD-08/09 and ASSET-07/08/09, INV-07 and HACK-07. WORLD-07 remains the later multi-district expansion and release/distribution outline after the first neighborhood and feasibility evidence; do not merge the initial neighborhood back into the test-only WORLD-06 fixture.

- [ ] **WORLD-07 — deliverable complete** (Stage 2–5 (deferred)).

**Dependencies / sequencing:** WORLD-06; approved playable scope, platform and budget decisions. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/districts/`; `benchmarks/world/`; `game/export_presets.cfg`; `docs/release-checklist.md`.

**Interfaces:** Use existing manifests, navigation and lifecycle contracts; expansion is content in the same continuous exterior city.

- [ ] **Acceptance:** After feasibility, split approved district layouts/interiors into individual content tickets with landmarks, routes, travel-time and budget criteria. Split release exports, clean-machine model setup and signing/distribution decisions into target-specific tickets. Candidate three districts is not a fixed requirement.

- [ ] **Test expectations:** Validate every added district’s alternate routes, backtracking, mission reachability and sustained memory; test selected packaged platforms and local-model/fallback installation on a clean machine.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### WORLD-08: Assemble the streamed Night Market neighborhood

- [ ] **WORLD-08 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** WORLD-01/02/03/04/05, ASSET-08/09, INV-07 and HACK-07. ASSET-07 must also be accepted as the hero quality reference. WORLD-06 packaging/headroom evidence remains open and must be reconciled before integrated performance acceptance; it does not prevent independent Blender asset authoring.

**Files / ownership:** `game/world/districts/night_market/`; `game/assets/environment/night_market/`; `game/assets/characters/night_market/`; world fixtures/tests; `docs/reports/WORLD-08.md`; tracked neighborhood evidence/measurements.

**Interfaces:** Use current manifest/loader/navigation/interior-transition/entity hydration contracts and module service APIs. Keep existing feasibility fixture and project main scene unchanged; provide a separate entry scene.

**Supporting scope recorded before implementation:** Assemble an approximately 300 m × 300 m 3 × 3 urban grid (subject to approved measurement and task acceptance) with 8–12 m avenues, narrower alleys, a central night market, repair row, security crossing, utility court, rooftop/vertical landmarks, two connected route loops and three enterable spaces. Use imported Blender models and physical textures, not primitive rectangles as final set dressing.

- [ ] **Acceptance:** The neighborhood supports the authored NPC mission and configured vendor, combat with cover/flank, multiple connected hack scenarios with bypass, loot/healing/inventory, three interior transitions, checkpoint save/reload and free traversal/backtracking. Player routes, alternate access and named landmarks remain legible at first-person scale.
- [ ] **Test expectations:** Validate chunk crossings/backtracking, actor/loot/door persistence, navigation readiness, merchant transactions, hacking routes, interiors/return points, mouse look, checkpoint, and fullscreen visual/material quality. Run Godot import, relevant focused suites and a Godot MCP visual runtime check. Record draw calls, route frame intervals, game/model memory and chunk hitches; do not claim pass/fail for unratified limits.
- [ ] **Evidence recorded:** Attach exact commands/tool results, inspected fullscreen captures and structured integration report.

### WORLD-09: Playtest and polish the Night Market neighborhood

- [ ] **WORLD-09 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** WORLD-08 and ASSET-07/08/09, HACK-07, INV-07. Human playtest is required.

**Files / ownership:** Approved Night Market scenes/assets, world evidence, `docs/reports/WORLD-09.md` and tracker update.

- [ ] **Acceptance:** Human free-walk confirms the area feels like a coherent, detailed cyberpunk neighborhood at full-screen first-person scale; essential mission/combat/hacking/vendor/loot routes can be found and completed. Blocking collision, navigation, visibility or interaction issues are fixed.
- [ ] **Test expectations:** Record the human route, reading of landmarks, movement/look, dialogue/trade, fight/flank, hacks/bypasses, interiors, pickups, and save/load. Re-run affected focused checks and update performance observations; World-wide perf limits remain separate until ratified.
- [ ] **Evidence recorded:** Link playtest notes, before/after captures, exact verification results and remaining issues.

### WORLD-10: Make the Night Market immediately playable

- [x] **WORLD-10 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** PLAYER-01, ASSET-08 district visual base. This is a bounded exploration launch slice; it does not satisfy WORLD-08/09 or ASSET-08's full modular-kit acceptance.

**Files / ownership:** `game/world/districts/night_market/`; `game/project.godot`; focused launch/movement verifier; `docs/reports/WORLD-10.md`; evidence.

**Supporting scope recorded before implementation (24 October 2026):** The user requested practical collision on the reused district assets and a runnable game using them, authorizing the Night Market scene as the project startup scene. Add a walkable ground plane and low-cost static structural blockers derived from authored Blender `solid` meshes. Keep decorative neon, windows and other non-structural meshes non-solid. Place the existing first-person player at a clear street position. Preserve existing gameplay fixture files. This launch-scene decision supersedes WORLD-08's earlier instruction to keep the project main scene unchanged; the feasibility fixture remains intact.

- [x] **Acceptance:** `godot --path game` opens into the imported Night Market with the existing first-person controller and camera active. Player moves along the street, remains grounded, and is blocked by district structural colliders. Project startup is configured for fullscreen; decorative meshes remain non-solid.
- [x] **Test expectations:** One focused Godot verifier checks startup scene, fullscreen setting, player/camera/mouse capture, ground and structural collision count, wall blocking, grounded state and forward movement. One startup render frame was captured. Full suite, performance budget and WORLD-08 integration acceptance are outside this task.
- [x] **Evidence recorded:** Exact commands/exits, observed collision/movement result and runtime frame/report recorded in [WORLD-10 report](../reports/WORLD-10.md) and [evidence](../evidence/WORLD-10/night_market_startup_frame.png).

### WORLD-11: Add Night Market color, HUD and NPC presence

- [x] **WORLD-11 — deliverable complete** (Stage 2; scoped by the user's 24 October 2026 request to color the Night Market and add standard UI/NPC presence).

**Dependencies / sequencing:** WORLD-10, PLAYER-05, INV-05, AI-05. NPC-06 services are reusable only if a later task adds interaction; this task is limited to scene presentation and ambient residents.

**Files / ownership:** `game/world/districts/night_market/night_market.tscn`; new `night_market_runtime.gd`; `docs/reports/WORLD-11.md`; `docs/evidence/WORLD-11/`.

**Supporting scope recorded before implementation (24 October 2026):** Tune the existing imported district's engine lighting/color response so its authored vertex colors read clearly without altering upstream source meshes. Add the existing configured PlayerHUD and starter inventory UI to the fullscreen startup scene with a basic pistol/health setup. Populate the street with a small set of visible, named, colored humanoid blockout residents and a security guard. Residents are visual ambience only: no dialogue, navigation, combat, persistence, or custom character models are added; those remain ASSET-09/WORLD-08/NPC integration scope.

- [x] **Acceptance:** Runtime view shows discernible varied cyberpunk district colors rather than blown-out white buildings; standard health/ammo/crosshair/pause HUD and Tab inventory work; multiple resident silhouettes and a guard are visible in the street.
- [x] **Test expectations:** Godot import and one quick runtime start/capture; verify no runtime errors, configured HUD and ambient NPC node count. Do not perform alternate-resolution or broad suite testing.
- [x] **Evidence recorded:** Exact commands/results and the fullscreen capture, with known visual limitations, are recorded in [WORLD-11 report](../reports/WORLD-11.md) and [evidence](../evidence/WORLD-11/night_market_fullscreen.png).

Accepted 24 October 2026 (Asia/Kolkata), Main Agent. Import exit 0, focused launch verifier18/18 exit 0, including Tab open/Escape close and player control restoration; Godot MCP runtime errors empty, fullscreen capture inspected and diff check exit 0. The figures are visual placeholders; custom characters and interactive NPC/world integration remain ASSET-09/WORLD-08 scope. [Report](../reports/WORLD-11.md).

### WORLD-12: Connect Night Market dialogue, combat and ambient motion

- [x] **WORLD-12 — deliverable complete** (Stage 2; scoped by the user's 24 October 2026 report that Mara cannot be spoken to, the gun has no visible effect, enemies do not die, and the world feels static).

**Dependencies / sequencing:** WORLD-11, PLAYER-03/04/05, AI-02/03, NPC-01/02/03/04/05/06. Existing accepted services and the WORLD-06 fixture are read-only reference implementations; the main agent owns startup integration.

**Files / ownership:** `game/world/districts/night_market/night_market_runtime.gd`; `game/ui/player_hud.gd` (status feedback method only); `tools/godot/verify_night_market_playable.gd`; `docs/reports/WORLD-12.md`; `docs/evidence/WORLD-12/`.

**Supporting scope recorded before implementation (24 October 2026):** Compose the accepted DialogueUI/DialogueOrchestrator/OllamaProvider/ActionDispatcher with a reachable named Mara in the startup scene; expose an E-key interaction and authored fallback when Ollama is unavailable. Retain the existing deterministic mission authority and configure it against the existing retrieval template. Add a configured, collidable TacticalAgent security target to the player's view, use the existing magazine/ammo fire path, and make accepted lethal damage visibly read as a defeated guard. Make two ambient residents visibly walk short authored loops and add subtle sign/light pulse so the startup street has motion. Keep all persistent state data-only; no new model download, custom rig, navmesh production, new dependency, or district production batch.

- [x] **Acceptance:** E opens Mara's responsive dialogue; a message reaches the configured local Ollama model and displays its validated response, while provider failure still displays authored fallback. Aimed pistol shots consume ammo and damage the security target; lethal damage moves it to a visible dead state. Nearby residents move and signage/lighting changes over time. Inventory, mouse capture and collision traversal from WORLD-11/WORLD-10 still work.
- [x] **Test expectations:** One focused verifier checks service configuration, E interaction/control lock, a real hitscan hit and lethal security state, ambient movement and retained movement/collision checks. One actual Ollama exchange when the local server is available; one Godot MCP runtime error check and fullscreen capture. Broad suite, alternate resolutions, and performance benchmarking are not part of this fix.
- [x] **Evidence recorded:** Exact commands/exits, whether inference used the model or fallback, Godot runtime errors, one inspected fullscreen capture, and remaining presentation limits.

Accepted 24 October 2026 (Asia/Kolkata), Main Agent. Import and focused integration verifier exited 0; verifier passed 29 checks, including both live `llama3:willowbrook` response and deliberately unavailable-model authored fallback, E control lock/restore, four actual pistol hits consuming ammo and reducing guard health to zero, visible down state, pedestrian movement, collision and inventory behavior. Godot MCP startup succeeded; debug output had no runtime errors (three pre-existing GDScript warnings in `dialogue_orchestrator.gd`, `perception.gd`, and `tactical_agent.gd`). Inspected fullscreen capture at [WORLD-12 startup](../evidence/WORLD-12/night_market_startup.png). Figures remain low-poly placeholders and ambient loops are short authored walks; custom character models, broader street simulation, and WORLD-08 neighborhood acceptance remain open. [Report](../reports/WORLD-12.md).

### WORLD-13: Add visible pistol projectiles and killable residents

- [x] **WORLD-13 — deliverable complete** (Stage 2; scoped by the user's 24 October 2026 report that pistol fire has no visible bullet animation and every NPC should be killable).

**Dependencies / sequencing:** WORLD-12, PLAYER-04. Use the current hitscan/ammo/damage path and data-only HealthState; no projectile collision or persistence change.

**Files / ownership:** `game/world/districts/night_market/night_market_runtime.gd`; new `game/world/districts/night_market/night_market_resident.gd`; `tools/godot/verify_night_market_playable.gd`; `docs/reports/WORLD-13.md`; `docs/evidence/WORLD-13/`.

**Supporting scope recorded before implementation:** Spawn a short-lived, emissive moving bullet visual for each accepted pistol shot along its existing muzzle-to-hit path. Give Mara, the vendor, and the pedestrian real capsule hitboxes plus the same data-only HealthState damage contract as the security guard. Every named NPC must take starter-pistol hits and visibly enter a down state; a down Mara cannot start dialogue. Keep NPC death transient in this prototype and preserve the deterministic hitscan authority, existing ammo commit, ambient behavior for survivors, and no-new-dependencies rule.

- [x] **Acceptance:** Each shot presents a visible moving bullet/tracer; aiming at Mara, the vendor, the pedestrian or security consumes ammo and reduces that actor's health; lethal damage visibly drops each actor and removes its collider. Dead Mara is unavailable to the dialogue resolver. Survivors retain their ambient walk loops and live Mara retains Ollama/fallback dialogue.
- [x] **Test expectations:** Extend the focused fullscreen-start verifier to observe projectile movement, hit and kill all four named NPCs through the existing weapon action, verify dead Mara cannot resolve, and retain the previous dialogue/fallback/collision checks. Run import, that focused verifier, one quick Godot MCP startup and inspect a fullscreen capture. Full test suite, alternate resolutions and performance profiling are outside this task.
- [x] **Evidence recorded:** Exact commands/exits, all four deaths, projectile movement, Godot runtime errors, inspected fullscreen capture, and transient-death/placeholder limitations.

Accepted 24 October 2026 (Asia/Kolkata), Main Agent. Import exited 0; focused playable verifier passed 43/43 (exit 0), observing the animated emissive bullet move toward its hit position, reload, and actual starter-pistol hits/lethal kills/collider removal for security, Mara, vendor and pedestrian. Down Mara no longer resolves as a dialogue actor; live Ollama and unavailable-model fallback checks remain green. Godot MCP startup succeeded with no runtime errors (three existing GDScript shadow/unused warnings). Inspected fullscreen capture at [WORLD-13 startup](../evidence/WORLD-13/night_market_startup.png). Shot visuals are short-lived and health/deaths are transient; character models remain blockout mannequins and the bullet is a visual animation over authoritative hitscan. [Report](../reports/WORLD-13.md).
