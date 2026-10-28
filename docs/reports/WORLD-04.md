# WORLD-04 — Safe interior transitions

23 October 2026 (Asia/Kolkata), Main Agent. Implemented an autoload coordinator
that asynchronously loads scenes, fades between them, rejects overlapping
requests, restores controls on failure, and saves/restores the exterior player
position. It keeps authoritative registry data outside the scene tree. Added
small exterior/interior fixtures and focused suite.

Files: `game/world/interior_transition.gd`; `game/world/fixtures/{interior,exterior,transition_player.gd}`; `game/tests/world/test_interiors.gd`; `game/project.godot`; `game/tests/run_tests.gd`; `docs/world-contracts.md`; WORLD-04 task/tracker.

Checks from repository root:
- `godot --headless --path game --editor --import` — exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite interiors` — exit 0, 21 checks, zero failures.
- `git diff --check` — exit 0.

The focused suite entered and returned twice, checked spawn/return positions and registry preservation, and exercised duplicate, missing-scene and load-timeout recovery. No rendered capture or full-suite run; both remain unrun. Minor integration limit: the future player controller should implement `add_control_lock` / `remove_control_lock`; a node in the `player` group or named `Player` is used when present. Next recommended task: PLAYER-01.
