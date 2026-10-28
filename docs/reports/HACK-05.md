# HACK-05 Verification Report

Date: 23 October 2026 (Asia/Kolkata)

Task: Persist timed effects and present target feedback (Stage 1)

## Changes

- Added `HackSnapshot`, whose CORE-04 domain callbacks store only target UUID, ability ID, remaining duration and chunk ID. Runtime target references are weak and are never serialized.
- Bound effect time to WORLD-01 activation/unload events and the active gameplay simulation tick. Effects pause while their chunk is unloaded or the game is offline, then resume on a matching rehydrated target.
- Extended camera, turret and implant targets to accept externally clocked effects and restore/clear them without duplicating implant damage.
- Added an optional `HackSnapshot` to HackingService plus a side-effect-free target status query.
- Added a reusable, container-based HackingHUD scene using the global theme. It shows target eligibility, ability cost, cooldown, duration, commit/rejection feedback and provider outage.
- Permanent door unlocks remain in their existing EntityRegistry record; HACK-05 does not duplicate them in `active_hacks`.

## Verification

| Command / check | Exit | Result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Scripts and scene imported. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_effects` | 0 | 29 cases, 0 failures. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_security` | 0 | 23 cases, 0 failures (also included in final integrated run). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_combat` | 0 | 19 cases, 0 failures (also included in final integrated run). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite ai_states` | 0 | 32 cases, 0 failures (also included in final integrated run). |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | 819 cases, 0 failures. Shutdown still reports one ObjectDB leak and one `GodotBody3D` RID leak. |
| Godot MCP: launch `res://ui/hacking_hud.tscn`, inspect debug output | — | Godot 4.7.2 / OpenGL Metal. Final `errors` list empty. No screenshot or human readability playtest recorded. |

The focused regression first failed as expected because `HackSnapshot` and `HackingHUD` were absent (2 missing-resource failures; exit 1). An intermediate HUD assertion expected an unpadded duration; the displayed value is deliberately zero-padded, and the assertion was corrected. The final test confirms actual SaveStore save/load into same and fresh snapshot owners, paused chunk-unload time, fresh-projection restore and expiry, data-only persistence, rejection of a target registered in another chunk, status/result feedback, and provider-offline messaging.

## Limits and next step

HACK-06 still needs the two authored security encounter fixtures. Combat readability should be reviewed in those contexts. They are representative Stage 1 scenarios, not the final city: the project remains aimed at a large, continuous, walkable cyberpunk world with distinct districts and room for broader content later.
