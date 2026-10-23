# PLAYER-07 — Make the movement fixture visually legible

**Status:** Accepted, Stage 1.  
**Owner:** Main Agent.  
**Root cause:** `player_movement.tscn` had collision bodies only. It had no mesh instances, lights or environment, and the project default clear color is near black.

## Change

Added visible floor and low-ceiling meshes that match the existing collision shapes, a simple lit sky/environment, directional and fill lights, and a few colored blockout facades with a cyan sign. This is a test/demo fixture only; no production city assets were added.

## Verification

| Command / action | Exit / observed result |
|---|---|
| `godot --headless --path game --editor --import` | 0 |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite player_controller` | 0; 37 cases, 0 failures. Engine teardown also printed one ObjectDB and one physics-body RID leak warning. |
| `godot --path game --write-movie /tmp/player-movement-bright.png --quit-after 2 res://tests/scenes/player_movement.tscn` | 0; wrote numbered PNG frames. Godot printed the same short-run ObjectDB/RID teardown warnings. |
| Godot MCP `run_project` on `res://tests/scenes/player_movement.tscn` | Started; `get_debug_output` errors empty; `stop_project` final errors empty. |
| Screenshot visual inspection | [player-movement.png](../evidence/PLAYER-07/player-movement.png) shows the ground, cyan sign, facade blocks and colored sky. |

The teardown warnings occur on short test/capture process exits; they do not appear in the MCP runtime error list. The fixture is a readable blockout, not production art.
