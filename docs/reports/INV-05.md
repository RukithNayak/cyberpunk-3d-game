# INV-05 — Inventory UI and loot fixture

**Status:** Accepted for Stage 1, 23 October 2026 (Asia/Kolkata).  
**Owner:** Main Agent.  
**Scope:** Responsive grid inventory UI consuming INV-02/03/04 services, with a runnable loot/save-load fixture.

## Changes

- Added an anchored inventory panel with selectable/focusable grid cells, item inspection (rarity, rolled stats, magazine and family reserve), valid/invalid move previews, pickup rejection text, and equip, drop and consumable actions through existing services.
- Added Tab/Escape open/close behavior, player input locking and mouse-capture resume. Closing or leaving the scene cancels an in-progress drag without changing inventory ownership.
- Added `inventory_fixture.tscn` with example pistol/rifle/medkit/loot, a full-grid control, health feedback, and real CORE-04 SaveStore buttons.
- Added and registered `inventory_ui` tests for GUI input handlers, service operations, failed/full-grid actions, retry, focus, input locks, SaveStore restoration, and scene-exit cancellation.

## Verification

All commands ran from the repository root with Godot `4.7.2.stable.official.ed1daf0bf`:

| Command | Exit | Observed result |
|---|---:|---|
| `godot --headless --path game --editor --import` | 0 | Project import completed. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite inventory_ui` | 0 | `Suite inventory_ui: 42 cases, 0 failures`. |
| `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` | 0 | `Suite all: 483 cases, 0 failures`. Shutdown still logs one ObjectDB instance and one physics body RID leak. |
| `python3 /Users/rukithnayak/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py game` | 0 | `0 errors, 0 warnings in 125 files checked`. |
| `git diff --check` | 0 | No whitespace errors. |

Godot MCP `run_project` launched `res://tests/scenes/inventory_fixture.tscn`; `get_debug_output` returned an empty error list. The first launch reported a typed integer-division warning; it was fixed and the latest runtime check was clean.

## Cyberpunk UI visual follow-up — 23 October 2026

The accepted INV-05 UI was restyled with the shared [Cyberpunk Theme](../../game/ui/cyberpunk_theme.tres), responsive containers and low-intensity scanline/status shaders. Re-run `inventory_ui` reports 43/43; integrated `all` reports 519/519 (both exit 0). Godot MCP runtime output is empty, and [fullscreen inventory evidence](../evidence/CYBERPUNK-UI-OVERHAUL/inventory-fullscreen.png) was captured and visually inspected. Fixture debug controls are on F2. See the [overhaul report](CYBERPUNK-UI-OVERHAUL.md).

## Deferred evidence

No screenshot or human click-through was captured. Godot MCP exposes runtime output but not UI input/capture in this session. `screencapture -x /tmp/inv05-inventory-fixture.png` exited 1 with `could not create image from display`. The task fixture remains runnable with `godot --path game game/tests/scenes/inventory_fixture.tscn`; only the current fullscreen configuration was considered, per the user's resolution preference.
