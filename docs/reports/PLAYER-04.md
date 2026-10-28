# PLAYER-04 — Weapon transactions and player snapshots

**Status:** Accepted for Stage 1, 23 October 2026 (Asia/Kolkata).  
**Owner:** Main Agent.  
**Scope:** Coordinate accepted shots, magazines, reload/heal action callbacks, cancellation and data-only player restore hooks with the existing INV-03/INV-04 owners.

## Changes

- Added `WeaponStateMachine` with idle/firing/reloading/healing states. It reserves one magazine round before hitscan, restores that round on a rejected shot, transfers reserve ammunition only on a valid reload callback token, and rejects stale/repeated callbacks.
- Reload/heal actions cancel on death, equipment swap or non-inventory control locks. Healing remains available while the inventory UI alone owns its input lock. Inventory UI routes use through the state machine when configured.
- Added `PlayerSnapshot.capture/prepare/commit_prepared` for health and position. It contains primitive data only, validates the entire candidate before mutation and cancels stale action callbacks on restore. Inventory snapshots continue to own rolled weapon stats and magazine state.
- Added the machine to `player.tscn`; the existing fire signal uses it whenever authoritative services are configured.

## Verification

Commands ran from the repository root with Godot `4.7.2.stable.official.ed1daf0bf`:

| Command | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Import completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite weapon_transactions` | 0 | `Suite weapon_transactions: 24 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_equipment` | 0 | `Suite inventory_equipment: 35 cases, 0 failures` (run during implementation). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hitscan` | 0 | `Suite hitscan: 11 cases, 0 failures` (run during implementation). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | Final integrated run: 523 cases, 0 failures. Existing shutdown logs report one ObjectDB and one physics body RID leak. |

Focused evidence covers firing during reload, rejected-shot refund, empty reserves, repeated animation callback tokens, ammo conservation, swap/death/pause cancellation, once-only healing, save/load during reload (magazine, rolls and reserve restore) and checkpoint restore rejecting stale callbacks. The action exposes a token callback for animation integration; there is no authored reload animation clip in the current approved Stage 0/1 assets.

## Runtime evidence

Godot MCP launched `res://tests/scenes/combat_feedback.tscn`; `get_debug_output` returned an empty error list and `stop_project` returned empty `finalErrors`. Fullscreen captures are in [combat HUD evidence](../evidence/CYBERPUNK-UI-OVERHAUL/combat-hud-fullscreen.png). The capture confirms the HUD in the lit blockout; it does not establish human combat feel or audio timing.
