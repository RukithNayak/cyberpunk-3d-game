# Faction & Tactical AI Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Provide deterministic perception, hostility, enemy behavior and lightweight ambient simulation.

**Architecture:** Owns perception/decisions, never LLM-driven frame actions. Registry owns standing; world manager owns chunk and nav lifecycle. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 5](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### AI-01: Implement faction-aware perception

- [x] **AI-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/perception.gd`; `game/features/npcs/faction_rules.gd`; `game/tests/ai/test_perception.gd`.

**Interfaces:** `notify_sound_event(position: Vector3, radius: float, faction_id: String) -> void`; `evaluate_target_hostility(target_faction: String) -> bool` reads CORE-02 standing thresholds.

**Supporting contract (recorded before implementation):** The perception component keeps runtime-only `PerceptionData` with separate current visual contact/seen position, last-known position, and a bounded array of heard event records. The configurable default sight range is 20 m, physics query mask is layer 1, and the retained sound-event cap is 16 per observer; these are engineering defaults, not approved balance. Visual knowledge updates only when a live target is within range and no world collider blocks the ray. Losing sight clears current visual contact but preserves the last-known position; unseen movement never updates either position. Sound radius is inclusive and uses distance only, so walls do not block it. Sound records include source position and faction ID. `FactionRules` reads the live `FactionState` on every query, uses its published inclusive thresholds, and treats unknown IDs as non-hostile; it stores no standing copy.

- [x] **Acceptance:** PerceptionData distinguishes seen position, last-known position and heard events. Range/LOS gates visual knowledge; sound can trigger investigation through a wall without granting visual knowledge. Unknown factions follow documented safe defaults.

- [x] **Test expectations:** Test occluded/visible targets, sound radius edges, friendly/hostile thresholds and reputation changes while a target is present. Unseen movement cannot update last-seen position.

- [x] **Evidence recorded:** [AI-01 report](../reports/AI-01.md); focused20/20, all601, import and diff-check exit0. Godot MCP version4.7.2. Real headless physics ray checks passed; no rendered capture/human playtest recorded.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Runtime perception separates current sight, last-known location and nearby sound records; faction hostility/alliance queries read current CORE-02 standings and unknown IDs default safely. See [report](../reports/AI-01.md).

### AI-02: Build the deterministic goon state machine

- [x] **AI-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-01, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/tactical_agent.gd`; `game/features/npcs/goon.tscn`; `game/tests/ai/test_states.gd`.

**Interfaces:** AIState includes IDLE/INVESTIGATE/COMBAT/FLEE; accept perception, damage, stun and authored hostility events.

**Supporting contract (recorded before implementation):** `TacticalAgent` owns a transient `HealthState` and consumes its child `NpcPerception`; no persistent records or target Nodes are stored in save data. Its deterministic states are IDLE, INVESTIGATE, COMBAT, FLEE and terminal DEAD. Substates are PATROL, INVESTIGATE, SEARCH, PURSUE, ATTACK, REPOSITION, FLEE and STUNNED. `tick(delta)` is the explicit deterministic update (also called by `_physics_process` in play); movement is emitted as destination/speed intent for AI-03 navigation to consume. Authored patrol points advance in listed order and wrap. Last-known-position investigation never reads an unseen target's live transform and enters SEARCH after reaching that point, then returns to patrol/idle after the configured search time. Combat keeps target identity only as a transient Node reference, checks live `FactionState` hostility each tick, pursues beyond 1.75 m, attacks inside 1.75 m and backs off inside 0.9 m. Damage per attack defaults to 10 and cadence to 1.25 s; health defaults to 80; flee threshold defaults to 25% health; movement speed defaults to 2.5 m/s; investigation search to 3 s; stun is capped at 30 s. These are configurable engineering defaults, not approved balance. Cooldown stops while stunned, and death/stun suppress attacks. Authored hostility overrides are transient target-faction flags and never mutate `FactionState`. Attack damage calls the target's validated `apply_damage(amount, source_faction)` method once per elapsed cadence; one tick cannot emit multiple attacks after a long frame. Invalid/non-finite or negative time and invalid config reject without advancing state.

- [x] **Acceptance:** Patrol/investigate/search, pursue/attack/reposition and flee are deterministic substates/actions. Damage and attack intervals are bounded; dead/stunned actors cannot attack. Conventional events drive distractions and security reactions.

- [x] **Test expectations:** Use a fixed clock/seed to assert state transitions and attack cadence; cover lost sight, expired investigation, stun during attack, lethal damage and a change to allied standing.

- [x] **Evidence recorded:** [AI-02 report](../reports/AI-02.md); focused32/32, all633, import and diff-check exit0. Godot MCP version4.7.2. Fixed-clock scene-tree checks passed; no navigation/rendered capture/human playtest recorded.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Deterministic tactical states emit movement intents for AI-03; bounded combat and authored events use HealthState and live faction authority. The goon scene is an NPC blockout, not a completed model or navigable enemy. See [report](../reports/AI-02.md).

### AI-03: Add navigation and recovery in an isolated scene

- **Supporting scope recorded before implementation (23 October 2026):** Attach the AI-owned `NavigationDriver` to the existing goon scene so real tactical movement works, add `game/tests/ai/test_navigation.gd` and register the focused `ai_navigation` suite in the shared runner, and add a small isolated navigable scene fixture plus an AI debug overlay. Run the fixture in a dedicated SubViewport/World3D and on a fixture-owned NavigationServer map so integrated suite state cannot contaminate readiness. Update the prior AI-02 decision-only fixture to disable the locomotion child. Navigation readiness is injected through an optional provider callable; absent WORLD-05 integration, local readiness requires a valid synchronized NavigationServer map. Driver uses built-in `NavigationAgent3D`, caps stuck/unreachable recovery, returns to last valid nav point or queues safe despawn when none exists. No edits to `game/world/`, no custom pathfinding, and no cross-chunk behavior are included.

- [x] **AI-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-02, WORLD-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/navigation_driver.gd`; `game/tests/scenes/ai_navigation.tscn`; `game/features/npcs/ai_debug_overlay.gd`.

**Interfaces:** Use engine navigation with readiness input from WORLD-05; expose current state, destination, perception and last-valid point for debugging.

- [x] **Acceptance:** Goon reaches heard events and combat positions with bounded stuck recovery. If navmap drops or actor leaves mesh, recover to a valid point or safely despawn. Do not implement a custom A* system.

- [x] **Test expectations:** Sound behind a wall produces a navigable investigation; test unreachable targets, stuck corners, map removal and off-mesh spawn. Review debug overlays and recovery in-engine.

- [x] **Evidence recorded:** [AI-03 report](../reports/AI-03.md); focused suite 15/15 and integrated suite 649/649, import and diff check exit 0. Godot MCP confirms 4.7.2; in-engine debug overlay capture at [navigation preview](../evidence/AI-03/navigation-preview.png). The blockout fixture is smoke evidence, not final NPC art or human playtest acceptance.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `NavigationDriver` consumes AI-02 movement intent through built-in navigation and exposes readiness, state, destination, perception, and last valid position. Bounded recovery handles stuck motion, unreachable destinations, off-mesh spawn, and navmap removal. WORLD-05 readiness can be injected; cross-chunk handoff remains deferred to WORLD-05. See [report](../reports/AI-03.md).

### AI-04: Serialize simplified simulation on unload

- **Supporting scope recorded before implementation (23 October 2026):** Implement `NpcSimulationRecord` as a transient registry/lifecycle coordinator plus a bounded data-only record stored under each NPC's existing `EntityRegistry` UUID. Record schema v1 contains chunk ID, faction ID, current/max health, world position, normalized world rotation quaternion, and a durable `dead` flag; pursuit/attack/stun timers, target Nodes, perception targets and movement callbacks are volatile and are cleared on unload. Consume `WorldManager.chunk_pre_unload` synchronously, prepare a complete registry replacement, and commit before deactivating actors. Add capture/invalidate/restore methods to `TacticalAgent`; restoration is gated on nav readiness and per-UUID runtime ownership prevents duplicate actors. Add an `ai_unload` focused suite, runner registration and a short report. No edits to `game/world/` or persistence core, no save schema/root changes, and no NPC model production are included.

- [x] **AI-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-03, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/npc_simulation_record.gd`; supporting actor API in `game/features/npcs/tactical_agent.gd`; `game/tests/ai/test_unload.gd`; Main Agent-owned runner registration and tracker/report updates.

**Interfaces:** Consume WORLD-01 pre-unload events and CORE-04 adapters; store UUID, faction, health, pose and durable AI flags without Nodes.

- [x] **Acceptance:** Downgrade distant/unloaded NPCs to data records, invalidate targets and restore exactly one actor after navigation is ready. Dead actors remain dead; volatile combat callbacks cannot run after unload.

- [x] **Test expectations:** Unload during pursuit, attack and stun; restore in a different chunk order. Assert preserved durable state, one actor per UUID, no post-unload damage and no retained node references.

- [x] **Evidence recorded:** [AI-04 report](../reports/AI-04.md) records focused/regression checks and the unrelated intermittent `ai_navigation` failure in the integrated suite.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `ai_unload` 38/38, `ai_states` 32/32, standalone `ai_navigation` 15/15, import and diff-check exit 0. Integrated `all` remains 672/674 passing because the isolated AI-03 navigation child intermittently reports an empty route at map iteration 2; standalone navigation passes. See [report](../reports/AI-04.md). WORLD-05 is now eligible; its navigation-boundary integration must account for the known fixture race.

### AI-05: Add ambient behavior and encounter validation

- [ ] **AI-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-04, WORLD-05. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/ambient_agent.gd`; `game/tests/scenes/encounter_fixture.tscn`; `docs/ai-playtests.md`.

**Interfaces:** Use shared faction/perception events with reduced update frequency for ambient NPCs; no inference requests for background pedestrians.

- [ ] **Acceptance:** One goon encounter and lightweight ambient actor operate across the seam. Factions populate configured areas; alerts and distractions are readable. Debug switches expose update counts for concurrent-load profiling.

- [ ] **Test expectations:** Playtest pursuit/backtracking, faction change, sound distraction and crowd unload; verify no friendly-fire target selection errors and bounded processing when inactive.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### AI-06: Expand roles and gang encounters

- [ ] **AI-06 — deliverable complete** (Stage 2–4 (deferred)).

**Dependencies / sequencing:** WORLD-06, ASSET-05; approved role and district scope. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/data/`; `game/world/encounters/`; `docs/encounter-balance.md`.

**Interfaces:** Extend deterministic state/action configurations instead of introducing a new decision runtime without demonstrated need.

- [ ] **Acceptance:** Split each approved goon role, faction distribution and encounter into separate tickets. Candidate three roles and gang organization remain content decisions; drones are optional.

- [ ] **Test expectations:** Per-role tests for fair attacks, navigation and recovery, plus district encounter playtests and representative crowd performance.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
