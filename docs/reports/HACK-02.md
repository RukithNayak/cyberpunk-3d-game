# HACK-02 — Door unlock feasibility hack

**Status:** Accepted, Stage 1. **Owner:** Main Agent. **Date:** 23 October 2026.

Implemented an authored `HackableDoor` projection using a stable UUID and the WORLD-03 `EntityHydrator` lifecycle generation. Mission-critical and already-open doors reject before energy charge. Successful UNLOCK_DOOR commits `{locked: false, open: true}` through the hydrator/CORE-02 registry, disables the blocking `CollisionShape3D`, and emits state feedback. Rehydrating a saved record restores its open collider state. Persistent records contain data only; mission-critical status remains authored configuration.

## Verification

| Command / check | Exit | Observed result |
| --- | ---: | --- |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_door` | 0 | 25 cases, 0 failures; includes mock lock-only mutation, CharacterBody3D collision/traversal, restricted/repeated/disappearing targets, SaveStore round-trip, and fresh projection reload. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_energy` | 0 | 30 cases, 0 failures. |
| `godot --headless --path game --editor --import` | 0 | Project scan/import completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 581 cases, 0 failures. Shutdown logged one ObjectDB leak and one `GodotBody3D` RID leak; focused door suite did not log either. |
| `git diff --check` | 0 | No whitespace errors. |
| Godot MCP `get_godot_version` | n/a | `4.7.2.stable.official.ed1daf0bf`. |

The door fixture runs actual Godot 3D physics under the project runtime and proves the player is blocked before unlock and has no blocking collision after unlock/reload. It is programmatic/headless; no rendered capture or human playtest was needed or recorded. Mission-critical restriction is an authored flag that scene content must set deliberately. There is no production door scene/content integration in this task.

## Files

- `game/features/hacking/targets/hackable_door.gd`
- `game/tests/hacking/test_door.gd`
- `game/tests/run_tests.gd`
- `docs/tasks/hacking-subsystem.md`
- `docs/master-progress.md`

No external services, downloads, dependency installation, or Blender changes were used.
