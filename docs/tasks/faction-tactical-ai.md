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
- For logic tasks, add the named regression cases, demonstrate failure for the new behavior, implement it, then run the focused suite. CORE-01 establishes the runner; use `godot --headless --path game --script res://tests/run_tests.gd -- --suite <suite>` with the module suite registered there. Blender/visual/performance tasks use the stated evidence rather than artificial unit tests.
- Check a task only after its implementation, acceptance criteria and test evidence pass. Record exact commands, results and visual/performance evidence alongside the task, plus any follow-up issue. Use a small focused change/commit; preserve unrelated work.
- All implementation boxes start unchecked. Checking off planning documentation does not indicate game implementation is complete. Deferred Stage 2–5 work is outside the currently approved Stage 0/1 scope.

## Review focus

- Save/load failures must preserve valid live and disk state (CORE-03/04); reward replays must not duplicate inventory (INV-04, NPC-04).
- Scene unload/death/cancel must invalidate late work and preserve UUID ownership (WORLD-02/03/05, AI-04, NPC-02).
- Interrupted reload/heal and repeated callbacks must conserve ammo/items and prevent attacks while dead (PLAYER-04, INV-03).
- Prompt injection, unseen facts and invalid/stale action parameters must never mutate progression (NPC-01/04/05).
- Concurrent inference, streaming and combat must remain responsive within explicitly ratified memory/frame budgets (WORLD-06); visual/playtest evidence is required in addition to headless checks.

## Task checklist

### AI-01: Implement faction-aware perception

- [ ] **AI-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/perception.gd`; `game/features/npcs/faction_rules.gd`; `game/tests/ai/test_perception.gd`.

**Interfaces:** `notify_sound_event(position: Vector3, radius: float, faction_id: String) -> void`; `evaluate_target_hostility(target_faction: String) -> bool` reads CORE-02 standing thresholds.

- [ ] **Acceptance:** PerceptionData distinguishes seen position, last-known position and heard events. Range/LOS gates visual knowledge; sound can trigger investigation through a wall without granting visual knowledge. Unknown factions follow documented safe defaults.

- [ ] **Test expectations:** Test occluded/visible targets, sound radius edges, friendly/hostile thresholds and reputation changes while a target is present. Unseen movement cannot update last-seen position.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### AI-02: Build the deterministic goon state machine

- [ ] **AI-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-01, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/tactical_agent.gd`; `game/features/npcs/goon.tscn`; `game/tests/ai/test_states.gd`.

**Interfaces:** AIState includes IDLE/INVESTIGATE/COMBAT/FLEE; accept perception, damage, stun and authored hostility events.

- [ ] **Acceptance:** Patrol/investigate/search, pursue/attack/reposition and flee are deterministic substates/actions. Damage and attack intervals are bounded; dead/stunned actors cannot attack. Conventional events drive distractions and security reactions.

- [ ] **Test expectations:** Use a fixed clock/seed to assert state transitions and attack cadence; cover lost sight, expired investigation, stun during attack, lethal damage and a change to allied standing.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### AI-03: Add navigation and recovery in an isolated scene

- [ ] **AI-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-02, WORLD-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/navigation_driver.gd`; `game/tests/scenes/ai_navigation.tscn`; `game/features/npcs/ai_debug_overlay.gd`.

**Interfaces:** Use engine navigation with readiness input from WORLD-05; expose current state, destination, perception and last-valid point for debugging.

- [ ] **Acceptance:** Goon reaches heard events and combat positions with bounded stuck recovery. If navmap drops or actor leaves mesh, recover to a valid point or safely despawn. Do not implement a custom A* system.

- [ ] **Test expectations:** Sound behind a wall produces a navigable investigation; test unreachable targets, stuck corners, map removal and off-mesh spawn. Review debug overlays and recovery in-engine.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### AI-04: Serialize simplified simulation on unload

- [ ] **AI-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** AI-03, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/npcs/npc_simulation_record.gd`; `game/tests/ai/test_unload.gd`.

**Interfaces:** Consume WORLD-01 pre-unload events and CORE-04 adapters; store UUID, faction, health, pose and durable AI flags without Nodes.

- [ ] **Acceptance:** Downgrade distant/unloaded NPCs to data records, invalidate targets and restore exactly one actor after navigation is ready. Dead actors remain dead; volatile combat callbacks cannot run after unload.

- [ ] **Test expectations:** Unload during pursuit, attack and stun; restore in a different chunk order. Assert preserved durable state, one actor per UUID, no post-unload damage and no retained node references.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

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
