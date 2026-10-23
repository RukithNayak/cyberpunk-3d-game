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

### PLAYER-01: Build the first-person controller and input settings

- [x] **PLAYER-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-01. Prerequisite IDs resolve through the master progress task index.

**Supporting scope recorded before implementation (23 October 2026):** Include the existing `player_controller` suite in the `all` suite; create its missing movement scene with a floor and low overhead obstacle; replace the placeholder headroom assertion with a real physics query. These complete the listed PLAYER-01 acceptance/test fixture; no combat or HUD scope is added.

**Files / ownership:** `game/features/player/player_controller.gd`; `game/features/player/player.tscn`; `game/features/player/input_settings.gd`; `game/tests/scenes/player_movement.tscn`.

**Interfaces:** Expose movement state and control lock hooks for dialogue, pause and interior transitions; named input actions rather than hardcoded keys.

- [x] **Acceptance:** Named actions drive first-person walk/run/crouch/jump with collision and headroom checks. FOV, sensitivity, invert-look and key/mouse bindings persist; duplicate bindings reject. Focus loss releases mouse, and explicit resume works after focus returns or control locks clear. Stairs/slopes and ledges are left for hands-on tuning.

- [x] **Test expectations:** `player_controller` focused suite covers settings round-trip/rebind conflicts, walk/run/jump/crouch, low ceiling clearance, floor landing, control locks and simulated focus changes.
- [ ] **Manual playtest:** stairs/slopes/ledges at multiple frame rates, in-window focus loss and menu focus were not exercised.

- [x] **Evidence recorded:** [PLAYER-01 report](../reports/PLAYER-01.md); focused 37/37, import and project reference check exit 0; Godot MCP launch with no runtime errors. Manual playtest and visual capture remain unrun.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Manual slope/stair/ledge and menu focus playtests remain outstanding; see [report](../reports/PLAYER-01.md).

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

- [x] **PLAYER-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-01, PLAYER-02. Prerequisite IDs resolve through the master progress task index.

**Supporting scope recorded before implementation (23 October 2026):** Add a compact default pistol `.tres`, wire the controller's named fire action/recoil into the player scene, and register `hitscan` in `all`. Build the test fixture from real physics bodies and a damage-recording target. The weapon controller receives transient actor state (alive/control locks); no reload, ammo, enemy AI, hit effects or HUD is added.

**Files / ownership:** `game/features/combat/weapon_stats.gd`; `game/features/combat/weapon_controller.gd`; `game/features/combat/hit_result.gd`; `game/tests/combat/test_hitscan.gd`.

**Interfaces:** `fire_weapon(weapon_stats: Resource) -> HitResult`; HitResult contains hit_position, surface_normal, target_node and damage_applied; target_node is transient and never serialized.

- [x] **Acceptance:** WeaponStats controls cadence, damage, range, spread and recoil. Camera aim resolves through a muzzle-origin obstruction ray so cover cannot be bypassed. The pistol is hitscan only; firing rejects dead actors and any control lock including pause/transition.

- [x] **Test expectations:** `hitscan` fixture covers unobstructed targets, muzzle wall interception, off-aim target rejection, range/no-hit, cadence, exactly one damage application, dead/locked actors, recoil and repeatable seeded spread.

- [x] **Evidence recorded:** [PLAYER-03 report](../reports/PLAYER-03.md); import, focused hitscan, integrated all suite and diff check pass. Godot MCP runtime launch/stop has no errors. No visual screenshot was captured.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent; focused 11/11 and integrated all 327/327. See [report](../reports/PLAYER-03.md).

### PLAYER-04: Coordinate reload, ammo, healing and checkpoint snapshots

- [x] **PLAYER-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-03, INV-03, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Supporting integration scope recorded before implementation (23 October 2026):** Add an explicit weapon action state owner that coordinates accepted hitscan shots, magazine consumption, reserve-to-magazine reload transactions and cancellation on death/equipment swap/control lock. Expose cancellable healing hooks for inventory UI consumers; permit healing while only the inventory UI lock is held, but reject it under pause/transition/dialogue locks. Add data-only player health/position capture and prepare/commit hooks for the existing snapshot adapter contract; do not modify shared `SnapshotAdapters`. This completes the listed PLAYER-04 interfaces and does not require CORE-05.

**Files / ownership:** `game/features/combat/{weapon_state_machine,weapon_controller}.gd`; `game/features/player/{player_controller,player_snapshot}.gd`; `game/features/player/player.tscn`; `game/tests/combat/test_weapon_transactions.gd`; `game/tests/run_tests.gd`. Consumer integration: `game/ui/inventory_ui.gd`.

**Interfaces:** Consume INV-03 equipment/ammo transactions; serialize magazine and rolled weapon stats through inventory’s ItemInstance, player health/position through the player adapter.

- [x] **Acceptance:** Explicit idle/fire/reload states coordinate animation callbacks and ammo changes once. Cancel reload/healing safely on death, swap and pause/transition as documented. Supply checkpoint restore hooks without requiring CORE-05.

- [x] **Test expectations:** Test fire during reload, empty reserve, repeated animation callbacks, swap/death during reload/heal and save/load mid-action. Total ammunition is conserved and one consumable produces at most one heal.

- [x] **Evidence recorded:** [PLAYER-04 report](../reports/PLAYER-04.md); focused weapon transactions 24/24, inventory equipment 35/35, import 0, all 523/523; `git diff --check` 0. Godot MCP player/HUD runtime errors empty.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Magazine and reserve remain inventory-owned; reload commits only at the animation callback token; data-only player snapshots validate before restore. See [report](../reports/PLAYER-04.md).

### PLAYER-05: Add combat HUD, feedback and comfort controls

- [x] **PLAYER-05 — deliverable complete** (Stage 1; accepted 24 October 2026).

**Dependencies / sequencing:** PLAYER-04, INV-04. Prerequisite IDs resolve through the master progress task index.

**Supporting UI scope recorded before implementation (23 October 2026):** Add a responsive fullscreen gameplay HUD using the shared INV-05 Theme, authoritative health/active weapon/magazine/reserve values, crosshair, and compact transient combat feedback. The HUD adds no minimap/objective placeholders or gameplay authority. Include a user-adjustable reduced camera-shake flag and focused fixture coverage within the existing PLAYER-05 acceptance. Since no production gameplay main scene exists yet, make the runnable combat/HUD fixture the project entry scene so a normal project launch visibly demonstrates the accepted prototype.

**User scope decision (24 October 2026):** Implement pause/settings as part of PLAYER-05, using the existing `PlayerInputSettings` owner for FOV, look sensitivity and invert-look; Escape is the default pause action. The pause layer provides resume, settings and quit controls, maintains a pause control lock, and restores mouse capture on resume. Audio remains unfulfilled and is tracked separately under PLAYER-08; it does not block PLAYER-05 or WORLD-06. Do not add audio controls, audio assets or alternate-resolution work here.

**Files / ownership:** `game/ui/{player_hud.tscn,player_hud.gd,pause_settings.tscn,pause_settings.gd}`; `game/features/player/input_settings.gd`; `game/features/combat/combat_feedback.gd`; `game/features/player/player_controller.gd`; `game/tests/scenes/combat_feedback.{tscn,gd}`; `game/tests/player/test_hud.gd`; `game/tests/player/test_controller.gd`; `game/tests/run_tests.gd`; `game/project.godot` main-scene integration (Main Agent). Shared style/fullscreen mode is owned by INV-05.

**Interfaces:** Observe health/ammo/equipment signals; expose reduced/disabled camera shake and pause/settings controls.

- [x] **Acceptance:** Visible HP, magazine/reserve counts, crosshair and hit/damage/death feedback work with greybox assets. HUD reflects authoritative state and survives checkpoint restoration; feedback never determines damage. Pause/resume and FOV/sensitivity/invert-look settings work and persist; pause blocks gameplay actions and resumes with safe mouse capture. Audio is deferred to PLAYER-08.

- [x] **Automated test expectations:** Focused HUD checks verify pause/resume control locks, settings focus/persistence, reduced-shake behavior and one visible feedback event per accepted shot; checks cover damage, healing, reload and checkpoint restoration. Audio timing is deferred to PLAYER-08.
- [ ] **Manual playtest:** Human pause-screen visual/art-direction and hands-on pause interaction review remains unrun.

- [x] **Evidence recorded:** [PLAYER-05 report](../reports/PLAYER-05.md) and [UI overhaul report](../reports/CYBERPUNK-UI-OVERHAUL.md); focused suite 16/16, import and diff check exit 0; Godot MCP fixture runtime errors empty. The latest integrated run exited 1 from the known AI-03 navigation race; a preceding run passed 1,063/1,063. Audio is deferred to PLAYER-08.

Accepted 24 October 2026 (Asia/Kolkata), Main Agent. Pause/settings work and automated checks are recorded in [PLAYER-05 report](../reports/PLAYER-05.md). Human pause-screen visual/art-direction playtest remains unrun; combat audio is deferred to PLAYER-08.

Mouse-look recovery follow-up, 24 October 2026: returning focus leaves capture released until the player clicks the game window; that click now recaptures for look. `player_controller` regression reproduced red (44 cases, 2 failures) and green (44/44); import exit 0. See the [PLAYER-05 report](../reports/PLAYER-05.md).

### PLAYER-06: Produce reference combat presentation and weapon families

- [ ] **PLAYER-06 — deliverable complete** (Stage 2–4 (deferred)).

**Dependencies / sequencing:** WORLD-06, ASSET-05; weapon family and rarity balance review. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/combat/data/`; `game/features/player/viewmodels/`; `docs/combat-playtests.md`.

**Interfaces:** Reuse WeaponStats and inventory instances; split pistol/automatic/shotgun tuning and each animation set into separate later tickets.

- [ ] **Acceptance:** Integrate reviewed first-person arms/weapons, reload clips and family-specific behavior after feasibility. Add projectiles only for an approved distinct weapon need.

- [ ] **Test expectations:** Per-family cover/cadence/ammo regressions plus in-engine reload alignment, animation interruption, hit readability and feel review with representative content.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### PLAYER-07: Make the movement fixture visually legible

- [x] **PLAYER-07 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** PLAYER-01. Prerequisite IDs resolve through the master progress task index.

**Supporting scope recorded before implementation (23 October 2026):** The player movement fixture has physics-only floor and ceiling bodies and renders no geometry or lighting. Add visible blockout surfaces, a basic environment/light, and a camera-readable view to the existing test scene; do not add production city content.

**Files / ownership:** `game/tests/scenes/player_movement.tscn`; report under `docs/reports/`.

- [x] **Acceptance:** Running the fixture presents a lit first-person view with visible ground and blockout geometry instead of a black screen.
- [x] **Test expectations:** Godot import and runtime smoke; inspect a screenshot from the running scene.
- [x] **Evidence recorded:** [PLAYER-07 report and screenshot](../reports/PLAYER-07.md); import, player fixture test and Godot MCP runtime check pass.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Screenshot confirms a colored sky, ground plane, cyan sign and visible blockout structures; see [evidence](../evidence/PLAYER-07/player-movement.png).

### PLAYER-08: Add synchronized combat audio (deferred)

- [ ] **PLAYER-08 — deliverable complete** (Stage 1; deferred by user on 24 October 2026).

**Dependencies / sequencing:** PLAYER-03, PLAYER-05. This work is not a prerequisite for WORLD-06 under the user's 24 October 2026 decision to leave audio unfulfilled for now.

**Files / ownership:** To be recorded when this deferred task is selected; do not add audio assets or code as part of PLAYER-05.

**Interfaces:** Consume accepted weapon-shot and combat-feedback events; presentation/audio never determines hits or damage.

- [ ] **Acceptance:** Muzzle, impact and spatial combat sounds synchronize once with accepted gameplay events; user settings can mute or adjust output without changing combat authority.
- [ ] **Test expectations:** Verify one audio event for each accepted shot/impact, no event for a rejected shot, and working mute/volume controls in the fullscreen gameplay fixture.
- [ ] **Evidence recorded:** Deferred until PLAYER-08 is selected.
