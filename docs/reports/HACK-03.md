# HACK-03 — timed camera and turret effects

## Status

Accepted by Main Agent, 23 October 2026 (Asia/Kolkata), Stage 1. HACK-01 and AI-01 prerequisites are accepted. Runtime effects remain transient until HACK-05. HACK-06 now owns representative world encounters for the full ability set.

## Changes

- Added `HackableCamera`, a stable-UUID tagged target with range/FOV/physics-occlusion detection queries. DISABLE_CAMERA turns detection off for the configured HackDefinition duration and restores it on expiry.
- Added `HackableTurret`, a stable-UUID tagged target configured from live `FactionState` plus an explicit neutral/friendly override mode. A friendly turret protects the player and may target factions currently hostile to the player. Effect expiry recomputes current faction standing; no faction standing is permanently changed.
- Both targets reject reapplication while active. Service cooldowns remain the authoritative request gate. Destroyed turrets stop the effect without a later allegiance restore.
- Added the `hacking_security` suite and registered it in the normal focused and integrated runner paths.
- Recorded HACK-06 as a Stage 1 scenario coverage task at the user's request; added it as a direct WORLD-06 dependency.

## Verification

| Command/tool | Exit / observed result |
|---|---|
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_security` before implementation | 1; expected red: camera and turret target scripts were missing (2 failures) |
| `godot --headless --path game --editor --import` | 0; both target classes registered successfully |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_security` | 0; 23 cases passed |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_door` | 0; 25 cases passed |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_energy` | 0; 30 cases passed |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0; 771 cases passed. Shutdown printed one ObjectDB leak and one `GodotBody3D` RID leak warning. |
| Godot MCP `get_godot_version` / `get_project_info` | Godot 4.7.2; project metadata returned (21 scenes, 85 scripts, 8 assets). |
| `git diff --check` | 0 |

The headless SceneTree tests use real Godot 3D physics for camera occlusion and target identity. Effect time is advanced deterministically through the Node process callback. No rendered camera/turret scene exists yet, so visual presentation and player-facing target feedback remain unreviewed; HACK-06 creates the security scenarios and HACK-05 owns the HUD.

## Follow-up

- HACK-04 implements distraction and implant disruption.
- HACK-05 handles effect persistence and target feedback.
- HACK-06 creates a stealth route and security corridor that exercise all five abilities with alternate/no-hack routes before WORLD-06.
- The integrated suite is green, but its teardown ObjectDB/RID warnings remain recorded.
