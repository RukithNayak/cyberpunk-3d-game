# PLAYER-05 — Gameplay HUD and pause/settings

**Status:** Accepted for Stage 1, 24 October 2026 (Asia/Kolkata). Owner: Main Agent.

## Delivered

- Added a fullscreen pause/settings overlay using the existing shared cyberpunk Theme and container-based layout.
- Escape opens and closes the pause menu. Opening it takes the player's `pause_menu` control lock and pauses the scene tree. Resume unpauses, releases only that lock, and requests safe mouse recapture. Settings remain processable while the tree is paused.
- Added resume, settings, back and quit controls. Settings adjust FOV, look sensitivity and invert-look through `PlayerInputSettings`, persist to the existing user settings file, and apply to the player. The new Escape binding defaults to pause. Existing settings files without a saved pause binding continue to load with Escape as the default.
- Connected the existing combat fixture's player to the HUD pause manager. No audio controls, audio assets or audio implementation were added; combat audio is deferred as PLAYER-08 and is not a WORLD-06 dependency.

## Verification

| Command / action | Exit / result |
| --- | --- |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_hud` before implementation | 1; 9 passed, 1 failed as expected because `res://ui/pause_settings.tscn` was missing |
| `godot --headless --path game --editor --import` | 0; new pause menu script/scene and resources imported |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_hud` | 0; 16 cases, 0 failures, including Escape action routing, pause lock/tree pause, keyboard focus, settings persistence/application, healing, and mouse resume |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` (run before final HUD healing assertion) | 0; 1,063 cases, 0 failures. Engine shutdown logged one ObjectDB instance and one `GodotBody3D` RID allocation warning. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` (latest run) | 1; 1,051 cases, 2 failures: AI-03 navigation route was empty at map iteration 2 / region iteration 1, and the isolated-suite wrapper reported the child failure. PLAYER-05 focused suite remained green. Shutdown logged three ObjectDB instances and one `GodotBody3D` RID allocation warning. |
| `git diff --check` | 0; no whitespace errors |
| Godot MCP `run_project` on `res://tests/scenes/combat_feedback.tscn`, then `get_debug_output` and `stop_project` | Godot 4.7.2 Compatibility renderer on Apple M5; runtime `errors` and final errors were empty. This was a fixture smoke check, not a human visual/playtest review. |

## Scope and remaining work

The player's pause/settings scope is accepted. Audio remains explicitly deferred to [PLAYER-08](../tasks/player-health-combat.md#player-08-add-synchronized-combat-audio-deferred). No alternate-resolution work or broader UI redesign was done. Human playtesting of pause interaction and visible pause-screen art direction was not performed. The latest full-suite run is not green because of the known intermittent AI-03 route race; this failure is outside PLAYER-05 and is retained as an integration risk.

### Mouse-look focus recovery follow-up

24 October 2026: Regression reproduced in `player_controller`: after the game window regained focus, the controller intentionally left the mouse uncaptured and had no click-to-recapture path. Added a left-click recapture path when the player can act, has no control locks, and the window is focused. A synthetic mouse-motion check verifies yaw and pitch change after recapture. `player_controller` suite: red 44 cases / 2 expected failures before the fix; green 44 / 44 after. Godot import exit 0. The game window can now recover mouse-look after focus returns without changing pause/inventory/dialogue locks.

**Next eligible task:** WORLD-06, the integrated feasibility build. Its direct task dependencies are satisfied after PLAYER-05 acceptance; measure and report its remaining runtime, inference, traversal, save/relaunch and human-playtest criteria there.
