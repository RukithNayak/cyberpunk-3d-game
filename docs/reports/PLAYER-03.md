# PLAYER-03 — Hitscan firearm

**Status:** Accepted, Stage 1.  
**Owner:** Main Agent.  
**Scope:** One default hitscan pistol, transient hit result, weapon stats, player fire/recoil wiring, obstruction-safe firing and focused physics tests. No ammo, reload, AI, hit effects or HUD.

## Changes

- Added `WeaponStats` with damage falloff, rate, range, spread, recoil and faction tuning, plus a default Street Pistol resource.
- Added `HitResult`; its `to_data()` intentionally omits the transient target Node.
- Added `WeaponController` with seeded spread, testable cadence clock, camera aim ray, muzzle obstruction ray, target damage dispatch, range and actor-state rejection.
- Wired named `fire` input and recoil into the player. Added a muzzle marker and controller to `player.tscn`.
- Added real-physics target/wall cases and registered `hitscan` both as a focused suite and under `all`.

## Verification

| Command / action | Exit / observed result |
|---|---|
| `godot --headless --path game --editor --import` | 0 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hitscan` | 0; 11 cases, 0 failures |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0; 327 cases, 0 failures |
| `git diff --check` | 0 |
| Godot MCP `run_project` on `res://tests/scenes/player_movement.tscn` | Started in debug mode; `get_debug_output` returned empty errors; `stop_project` returned empty `finalErrors`. |

The full test command emitted expected warnings from existing invalid-input registry and persistence tests; the runner reported no failures. No screenshot or human combat feel/playtest evidence was captured. The accepted behavior is limited to the checks above.

## Follow-up

INV-01 is eligible (CORE-02 accepted) and is recommended next to establish item records before INV-02/03 and the later PLAYER-04 inventory/combat transactions.
