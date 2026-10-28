# Core State & Persistence Registry Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Provide scene-independent authoritative state and recoverable versioned saves.

**Architecture:** Owns records, serialization and faction values. Gameplay modules own domain rules; registry records never retain scene nodes. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 1](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### CORE-02: Define registry and stable-identity contracts

- [ ] **CORE-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/persistence/entity_registry.gd`; `game/persistence/faction_state.gd`; `game/tests/persistence/test_registry.gd`; `docs/state-contracts.md`.

**Interfaces:** `register_entity(uuid: String, initial_state: Dictionary) -> void`; `commit_state_delta(uuid: String, delta: Dictionary) -> void`; `get_faction_standing(faction_id: String) -> int`. Add documented copy-returning state lookup and faction mutation contracts for consumers.

- [ ] **Acceptance:** EntityState uses stable UUIDs independent of scene paths/load order. Duplicate registration warns and preserves existing state. Specify unknown-ID behavior, allowed serializable values, delta merge semantics and faction thresholds before consumers implement them; clamp standing to -100..100. Registry owns no Node references.

- [ ] **Test expectations:** Assert duplicate registration preserves modified flags; mutating a returned copy cannot alter truth. Reject node-valued state, invalid UUIDs/deltas and unknown faction mutations as documented. Cover -100/100 bounds and each hostility threshold.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

