# Player, Health & Combat Core Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Deliver responsive first-person movement, health and cover-respecting gun combat.

**Architecture:** Owns controller and combat state; inventory owns item/ammo records, UI owns presentation adapters within this module. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 3](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### PLAYER-01: Build the first-person controller and input settings

- [ ] **PLAYER-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/player/player_controller.gd`; `game/features/player/player.tscn`; `game/features/player/input_settings.gd`; `game/tests/scenes/player_movement.tscn`.

**Interfaces:** Expose movement state and control lock hooks for dialogue, pause and interior transitions; named input actions rather than hardcoded keys.

- [ ] **Acceptance:** Walk, run, crouch and jump with predictable collision, stairs/slopes and head clearance. Configurable FOV, sensitivity, invert-look and rebinding persist as settings. Mouse capture resumes safely after pause/focus loss.

- [ ] **Test expectations:** Playtest stairs, slopes, low ceilings and ledges at multiple frame rates. Verify rebinding conflicts, setting restoration, menu focus and no movement/fire while control lock is active.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### PLAYER-02: Implement bounded health and death events

- [x] **PLAYER-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/player/health_state.gd`; `game/tests/player/test_health.gd`.

**Interfaces:** `apply_damage(amount: int, source_faction: String) -> void`; `heal(amount: int) -> void`; emit `on_death` once per living-to-dead transition.

- [x] **Acceptance:** Clamp HP to 0..max_hp, ignore negative damage/heal, validate maximum HP and explicitly prevent healing from reviving a dead actor outside checkpoint restore. Emit health changes for the HUD.

- [x] **Test expectations:** Assert zero/negative/oversized amounts, maximum bounds, repeated lethal hits, healing while dead and explicit restore. Death event fires once until a valid restore.

- [x] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent; codex/stage-0-readiness working tree. Health 19/19 after expected 11 behavioral failures; integrated all 60/60, exits 0. [Report/commands/contracts](../reports/PLAYER-02.md). No movement or visual acceptance implied.

### PLAYER-03: Implement one firearm and obstruction-safe hitscan

- [ ] **PLAYER-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-01, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/combat/weapon_stats.gd`; `game/features/combat/weapon_controller.gd`; `game/features/combat/hit_result.gd`; `game/tests/combat/test_hitscan.gd`.

**Interfaces:** `fire_weapon(weapon_stats: Resource) -> HitResult`; HitResult contains hit_position, surface_normal, target_node and damage_applied; target_node is transient and never serialized.

- [ ] **Acceptance:** Data controls cadence, damage, range, spread and recoil. Resolve camera aim plus muzzle obstruction so cover cannot be bypassed. Start with hitscan only; reject firing when dead, paused or transitioning.

- [ ] **Test expectations:** Fixture rays cover unobstructed targets, a muzzle against a wall, camera/muzzle disagreement, range limits and no-hit results. Assert cadence and one damage application per shot with deterministic spread seeds.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### PLAYER-04: Coordinate reload, ammo, healing and checkpoint snapshots

- [ ] **PLAYER-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-03, INV-03, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/combat/weapon_state_machine.gd`; `game/features/player/player_snapshot.gd`; `game/tests/combat/test_weapon_transactions.gd`.

**Interfaces:** Consume INV-03 equipment/ammo transactions; serialize magazine and rolled weapon stats through inventory’s ItemInstance, player health/position through the player adapter.

- [ ] **Acceptance:** Explicit idle/fire/reload states coordinate animation events and ammo changes once. Cancel reload/healing safely on death, swap and pause/transition as documented. Supply checkpoint restore hooks without requiring CORE-05.

- [ ] **Test expectations:** Test fire during reload, empty reserve, repeated animation callbacks, swap/death during reload/heal and save/load mid-action. Total ammunition is conserved and one consumable produces at most one heal.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### PLAYER-05: Add combat HUD, feedback and comfort controls

- [ ] **PLAYER-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-04, INV-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/ui/player_hud.tscn`; `game/ui/player_hud.gd`; `game/features/combat/combat_feedback.gd`; `game/tests/scenes/combat_feedback.tscn`.

**Interfaces:** Observe health/ammo/equipment signals; expose reduced/disabled camera shake and pause/settings controls.

- [ ] **Acceptance:** Visible HP, magazine/reserve counts, crosshair, hit/damage/death feedback and synchronized muzzle/impact/spatial audio work with greybox assets. HUD reflects authoritative state and survives checkpoint restoration; feedback never determines damage.

- [ ] **Test expectations:** Playtest readability, audio timing, pause/resume and reduced-shake settings; assert one visible/audio event per accepted shot and correct HUD after healing, reload and restore.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### PLAYER-06: Produce reference combat presentation and weapon families

- [ ] **PLAYER-06 — deliverable complete** (Stage 2–4 (deferred)).

**Dependencies / sequencing:** WORLD-06, ASSET-05; weapon family and rarity balance review. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/combat/data/`; `game/features/player/viewmodels/`; `docs/combat-playtests.md`.

**Interfaces:** Reuse WeaponStats and inventory instances; split pistol/automatic/shotgun tuning and each animation set into separate later tickets.

- [ ] **Acceptance:** Integrate reviewed first-person arms/weapons, reload clips and family-specific behavior after feasibility. Add projectiles only for an approved distinct weapon need.

- [ ] **Test expectations:** Per-family cover/cadence/ammo regressions plus in-engine reload alignment, animation interruption, hit readability and feel review with representative content.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
