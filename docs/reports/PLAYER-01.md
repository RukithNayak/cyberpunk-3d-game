# PLAYER-01 — First-person controller and input settings

23 October 2026 (Asia/Kolkata), Main Agent. Added a typed `CharacterBody3D`
player scene with camera, named walk/run/crouch/jump/interact/fire actions, saved
FOV/sensitivity/invert-look and rebind settings, duplicate binding checks, control
locks, crouch headroom query and focus-safe mouse capture. The movement fixture
uses a real floor and low ceiling. Added the controller suite to `all`.

Files: `game/features/player/{player_controller,input_settings}.gd`; `game/features/player/player.tscn`; `game/tests/scenes/player_movement.tscn`; `game/tests/player/test_controller.gd`; `game/tests/run_tests.gd`; PLAYER-01 task/tracker.

Checks:
- `godot --headless --path game --editor --import` — exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_controller` — exit 0, 37 checks, zero failures.
- `python3 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game` — exit 0, 82 files, zero errors/warnings.
- Godot MCP 4.7.2 `run_project` on `res://tests/scenes/player_movement.tscn` — started; debug output had no errors; stopped cleanly, final errors empty.
- `git diff --check` — exit 0.

No full-suite run or rendered capture. Hands-on stairs, slopes, ledges, multiple frame rates and menu focus remain unrun. Next eligible task: PLAYER-03.
