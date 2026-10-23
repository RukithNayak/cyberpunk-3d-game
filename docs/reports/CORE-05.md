# CORE-05 — Checkpoint Controller

**Status:** Accepted for Stage 1, 24 October 2026 (Asia/Kolkata). Owner: Main Agent.

## Delivered

- Added `CheckpointController`, which binds player death to a synchronous validated checkpoint restore using the existing `SaveStore` and `SnapshotAdapters` contracts.
- It guards nested saves/loads, validates and keeps an in-memory recovery snapshot, reports missing/corrupt disk loads through recovery/failure signals, and disconnects from health on tree exit.
- The fixture composes actual `PlayerSnapshot`, `InventorySnapshot`, `DialogueSnapshot` (`NpcMemory` and `MissionDirector`), and `HackSnapshot` participants. It checks persistent registry/world flags, an already-dead NPC, a completed mission and reward, equipment/ammo, verified NPC fact, and active hack data.
- A child Godot process reloads the real native `user://` checkpoint from a fresh set of owners. Replayed item grants and mission completion do not re-award loot or credits.

## Verification

| Command / action | Exit / result |
| --- | --- |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite checkpoint` before implementation | 1; expected regression: checkpoint controller resource missing |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite checkpoint` after implementation | 0; 15 cases, 0 failures; relaunch child suite 1 case, 0 failures |
| Child command (invoked by the checkpoint suite): `godot --headless --path <project-path> --script res://tests/run_tests.gd -- --suite checkpoint_relaunch_child` | 0; fresh process hydrated saved domain state |
| `godot --headless --path game --editor --import` | 0; scripts/classes imported, including `CheckpointController` |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` (final run) | 1; 1,044 cases, 2 failures. The isolated AI navigation fixture intermittently returned an empty route (`navigation map returns a routed path around the wall`); its wrapper also failed. This is the existing AI-03 race recorded in the tracker, not a checkpoint assertion. A prior integration run in this session passed 1,057/1,057 before the final test cleanup change; final status is the failing run above. |
| `git diff --check` | 0 |
| Godot MCP `run_project` on `res://tests/scenes/checkpoint_fixture.tscn`; `get_debug_output`; `stop_project` | Started/stopped on Godot 4.7.2; runtime errors and final errors were empty. |

The final integrated run also logged 3 ObjectDB instances and 1 `GodotBody3D` RID at shutdown. The focused checkpoint run exited cleanly. No visual-quality claim is made for this nonvisual persistence fixture.

## Deferred / next

The intermittent AI-03 navigation failure remains recorded for its owning task. WORLD-06 is not yet eligible because it depends on PLAYER-05, which remains in progress: the approved UI design excludes audio and pause/settings work required by PLAYER-05's task acceptance. Resolve that scope conflict before starting WORLD-06.
