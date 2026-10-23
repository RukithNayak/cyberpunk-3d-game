# WORLD-05 — Navigation handoff across chunk boundaries

**Status:** Accepted, Stage 1<br>
**Owner:** Main Agent<br>
**Date:** 23 October 2026 (Asia/Kolkata)

## Delivered

- Added `NavigationHandoff`, which observes real loader activation/unload events and tracks each chunk's navigation regions by lifecycle generation. It publishes readiness only after all desired chunks are active, their regions share the actor's world navigation map, and map/region synchronization iterations are nonzero.
- NPCs attach by UUID and remain paused while desired navigation data is pending. As an actor crosses into a synchronized chunk, the coordinator asks AI-04 to validate and transfer the UUID owner, then reparents the same actor under a persistent runtime root while preserving world transform. Sorted manifest IDs define shared-boundary ownership.
- AI-04's transfer API checks both current source and destination generations before changing active ownership. Final-owner unload commits the existing data-only record before the persistent Node projection is freed; a fresh projection restores after map readiness.
- Added a real threaded two-chunk headless fixture with delayed destination navigation, pursuit in both directions, stale-generation reversal, unload and fresh UUID restoration. Added the shared runtime integration contract.
- Regression-first evidence: the initial `navigation_handoff` run exited 1 with two expected failures because the coordinator and chunk fixture scripts were missing.

## Verification

Commands run from the repository root:

| Command | Exit | Observed result |
| --- | ---: | --- |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite navigation_handoff` | 0 | 40 cases, 0 failures |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite ai_unload` | 0 | 38 cases, 0 failures |
| `godot --headless --path game --editor --import` | 0 | Import and class registration completed |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 727 cases, 0 failures; nested `ai_navigation` 15/15 and `navigation_handoff` 40/40 |
| `python3 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game` | 0 | 0 errors, 0 warnings across 189 files |
| `git diff --check` | 0 | No whitespace errors |

Godot MCP confirmed `4.7.2.stable.official.ed1daf0bf` and project metadata for `game` (18 scenes, 77 scripts at inspection). The integrated run still prints one ObjectDB instance and one `GodotBody3D` RID teardown warning. The AI-03 empty-route navigation synchronization race seen in earlier runs did not recur during this integration run.

## Limits

The test exercised actual Godot physics/navigation and the threaded chunk loader in headless mode. No rendered capture or human traversal playtest was produced. Production district navmesh authoring and composition into a playable world remain later Stage 1 integration work; no custom pathfinding or performance threshold is claimed.
