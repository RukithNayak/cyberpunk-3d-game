# Hacking Subsystem Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Execute validated immediate hacks with regenerating energy and durable effects.

**Architecture:** Owns ability eligibility, costs and effect lifetimes; target adapters own local behavior, registry owns durable state. No model latency in this path. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 6](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### HACK-01: Define abilities, eligibility and energy rules

- [ ] **HACK-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/hack_definition.gd`; `game/features/hacking/hacking_state.gd`; `game/features/hacking/hacking_service.gd`; `game/tests/hacking/test_energy.gd`.

**Interfaces:** `request_hack(target_node: Node3D, hack_type: int) -> bool`; `tick_energy_regen(delta: float) -> void`; ActiveHack uses target_uuid, hack_type and remaining_duration.

- [ ] **Acceptance:** Check tags, range, line of sight/access, energy, cooldown and current target state before charging. Automatic regeneration clamps to max. Costs, cooldowns and unspecified durations/damage are configurable and explicitly marked tuning values.

- [ ] **Test expectations:** Test exact cost/max boundaries, insufficient energy, negative delta/cost, wrong tag, blocked/out-of-range targets and cooldown spam; rejection spends no energy.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### HACK-02: Implement door unlock as the feasibility hack

- [ ] **HACK-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_door.gd`; `game/tests/hacking/test_door.gd`.

**Interfaces:** UNLOCK_DOOR commits only eligible lock-state changes through CORE-02; emits target-state feedback for UI and navigation.

- [ ] **Acceptance:** An eligible locked door unlocks once; mission-critical restrictions are explicit. Re-hacking an unlocked door does not charge again. Collider/door traversal remains valid and unlock persists across unload.

- [ ] **Test expectations:** Mock target test checks only lock state changes; in-engine fixture verifies traversal. Cover restricted door, repeated request, disappearing target and unlock/save/unload/reload.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### HACK-03: Implement timed camera and turret effects

- [ ] **HACK-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, AI-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_camera.gd`; `game/features/hacking/targets/hackable_turret.gd`; `game/tests/hacking/test_security.gd`.

**Interfaces:** DISABLE_CAMERA removes detection for configured duration; DISABLE_TURRET uses an explicitly configured neutral/friendly override and restores prior allegiance.

- [ ] **Acceptance:** Publish chosen temporary durations and turret mode in data, not inferred defaults. Reapplication follows one documented refresh/reject policy. Expiry restores prior state without undoing later authoritative destruction or faction changes.

- [ ] **Test expectations:** Advance a fake clock through start/reapply/expiry; test disabled detection, turret targeting, target destruction and allegiance change during an effect. No permanent faction mutation from a temporary hack.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### HACK-04: Implement distraction and implant disruption

- [ ] **HACK-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, AI-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_distraction.gd`; `game/features/hacking/targets/hackable_implant.gd`; `game/tests/hacking/test_combat_hacks.gd`.

**Interfaces:** TRIGGER_DISTRACTION emits AI-01 sound/investigation events; DISRUPT_IMPLANT invokes AI stun and normal damage services.

- [ ] **Acceptance:** Distraction affects eligible listeners at target location. Implant disruption applies the specified 3-second stun and configurable minor damage; interruptions cannot duplicate damage or allow attacks during stun.

- [ ] **Test expectations:** Test guard behind cover investigates distraction, exact 3-second stun duration with a controlled clock, dead/immune target rejection, repeated callbacks and interruption of an attack/reload.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### HACK-05: Persist effects and present target feedback

- [ ] **HACK-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-02, HACK-03, HACK-04, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/hack_snapshot.gd`; `game/ui/hacking_hud.gd`; `game/tests/hacking/test_effect_persistence.gd`.

**Interfaces:** Use CORE-04’s documented timed-effect clock policy and WORLD-01 lifecycle events; HUD reads eligibility/effect events.

- [ ] **Acceptance:** Persist permanent flags and remaining timed effects; unloading cancels transient operations without losing durable truth. Save/load restores durations consistently; invalid targets cannot receive delayed effects. Show valid target, cost, cooldown, duration and rejection reason.

- [ ] **Test expectations:** Save mid-effect, unload/destroy target, reload and advance the agreed clock; verify energy, effect expiry and cleanup. Playtest readable feedback during combat and provider failure.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
