# Cyberpunk UI Overhaul Implementation Plan

> **Execution:** Main Agent, inline; existing dirty worktree preserved.

**Goal:** Restyle the inventory and add a compact authoritative gameplay HUD using one reusable Godot Theme and restrained UI shaders.

**Architecture:** INV-05 owns the shared Theme and inventory presentation. PLAYER-04 coordinates shots, reloads and consumables through the accepted inventory services and exposes data-only checkpoint hooks. PLAYER-05 consumes those owners for HUD/feedback. Persistent snapshots contain dictionaries and primitive values only.

**Spec:** [Cyberpunk UI overhaul design](../specs/2026-10-23-cyberpunk-ui-overhaul-design.md)

**Global constraints:** Stage 0/1 only; Godot 4.7.2 typed GDScript; preserve unrelated dirty files; no dependencies/assets/downloads; data owners remain authoritative; fullscreen is the target; run focused checks and one visual/runtime smoke check, record exact exits and unavailable evidence.

**Review focus:** Ammo conservation across interrupted reload; one-time shot/heal commits; prepared snapshot validation before commit; UI values reflect service state; screen shader remains subtle and text readable; no hardcoded per-node color/style overrides or absolute-positioned layout structures.

## Tasks

### Task 1 — Shared cyberpunk Theme and inventory restyle (INV-05)

**Files:** `game/ui/cyberpunk_theme.tres`, `game/ui/scanline.gdshader`, `game/ui/status_flicker.gdshader`, `game/ui/inventory_ui.gd`, `game/ui/inventory_ui.tscn`, `game/project.godot`, `docs/tasks/inventory-equipment.md`.

**Interfaces:** Project-level `gui/theme/custom`; shared named StyleBox variations for panels, buttons and grid cells; system monospace fallback. Keep all service operations, signals, focus, input locks and drag cancellation unchanged.

**Steps:** (1) Extend the existing inventory UI suite to assert it receives the shared Theme and retains interaction semantics. Run `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_ui` and confirm the new theme assertion fails. (2) Add global Theme and low-intensity canvas shaders; restructure generated controls under responsive containers and use Theme variations instead of node overrides. (3) Run inventory UI suite, import and Godot runtime fixture smoke.

**Expected:** test exits nonzero before implementation, then focused suite/import/runtime exit 0; visual capture inspected when available.

### Task 2 — Weapon, reload, heal and player snapshot coordination (PLAYER-04)

**Files:** `game/features/combat/weapon_state_machine.gd`, `game/features/combat/weapon_controller.gd`, `game/features/player/player_snapshot.gd`, `game/features/player/player_controller.gd`, `game/tests/combat/test_weapon_transactions.gd`, `game/tests/run_tests.gd`, `docs/tasks/player-health-combat.md`.

**Interfaces:** ItemInstance owns magazine and rolled stats; EquipmentService and AmmoPouch own equipment/reserves; HealthState owns HP; PlayerSnapshot exposes validated capture/prepare/commit dictionaries for health and position. No Nodes are serialized.

**Steps:** (1) Add focused regressions for duplicate fire/reload callbacks, ammo conservation, reload cancellation on swap/death/lock and player snapshot round-trip. Run the suite and observe failure. (2) Implement explicit idle/firing/reloading transitions and transactional shot consumption/reload; cancel pending work on owner state changes; add prepared player snapshot hooks. (3) Run the focused weapon transaction suite, inventory equipment suite, import and player fixture runtime smoke.

**Expected:** regressions fail before implementation and pass after; all ammo/item transactions are conserved; import/runtime have no script errors.

### Task 3 — Gameplay HUD and combat feedback (PLAYER-05)

**Files:** `game/ui/player_hud.tscn`, `game/ui/player_hud.gd`, `game/features/combat/combat_feedback.gd`, `game/tests/scenes/combat_feedback.tscn`, `game/tests/player/test_hud.gd`, `game/tests/run_tests.gd`, `game/project.godot`, `docs/tasks/player-health-combat.md`.

**Interfaces:** HealthState, WeaponStateMachine, EquipmentService and AmmoPouch signals/state; Theme from Task 1; feedback events derive from accepted shot/hit results and never apply damage.

**Steps:** (1) Add tests for authoritative HP/magazine/reserve refresh and one feedback event per accepted shot. (2) Build a fullscreen CanvasLayer with container-based corner panels and center crosshair; add restrained transient hit/damage/death indication and reduced shake setting. Set the runnable combat fixture as the main scene while no production gameplay scene exists. (3) Run focused HUD tests, import, Godot HUD/combat fixture smoke, and inspect available fullscreen runtime output/capture.

**Expected:** focus suite and import exit 0, runtime has no script/shader errors; visual capture inspected when available, otherwise limitation recorded.

## Progress ledger

- Preflight: INV-05 is accepted and has no Theme; PLAYER-04 has no implementation and all listed prerequisites are accepted; PLAYER-05 is unstarted and depends on PLAYER-04 plus INV-04. Shared interface: PLAYER-04 produces stable weapon/ammo/health snapshot reads consumed by PLAYER-05; keep presentation read-only.
- Worktree is already dirty on `codex/stage-0-readiness`; isolation would require migrating numerous unrelated user changes. Ruling: execute inline in the existing tree, editing only listed owned files and task/report docs, because preserving the handoff is safer than rebasing a large dirty tree.
