# WORLD-06 Night Market Playtest Block

**Status:** Layout implemented; WORLD-06 remains in progress.
**Owner:** Main Agent.
**Date:** 24 October 2026 (Asia/Kolkata).

## Scope

The user approved a compact walkable Night Market block as a test-sized WORLD-06 fixture. The layout adds a start plaza, neon-marked market street, four market stalls, backdrop storefronts, a hack-marked service alley, and a neon gate at the two-chunk crossing. Existing gameplay targets, authoritative services, chunk contracts, project main scene, and benchmark semantics remain unchanged. Geometry is authored with Godot primitives; no Blender assets, downloads, or dependencies were added.

## Files

- `game/tests/scenes/feasibility.gd` — fixture geometry, materials, signs and named landmarks; smoke assertion for the plaza/street/alley.
- `benchmarks/feasibility/headless_smoke.json` — refreshed runtime smoke observations from the new run; not used as a performance pass.
- `docs/tasks/world-scene-manager.md` — records the added Stage 1 scope before fixture implementation.
- `docs/master-progress.md` — current WORLD-06 status note.
- `docs/reports/WORLD-06.md` — integration report note.

## Verification

| Command / check | Result |
| --- | --- |
| `godot --headless --path game res://tests/scenes/feasibility.tscn -- --smoke` before layout implementation | Exit 1, as expected: 24/25 passed; new layout-landmark assertion failed because `StartPlaza`, `MarketStreet`, and `ServiceAlley` did not exist. Existing mechanic assertions passed. |
| `godot --headless --path game --editor --import` | Exit 0. |
| `godot --headless --path game res://tests/scenes/feasibility.tscn -- --smoke` after implementation | Exit 0; 25/25 passed, including combat, NPC mission/dialogue, chunk crossing/backtracking, hacking, loot, healing, checkpoint restore, fresh-process reload and offline fallback. Existing dialogue focus warnings and one child-process ObjectDB shutdown leak were present. |
| Godot MCP `get_godot_version` | Returned `4.7.2.stable.official.ed1daf0bf`. |
| Godot MCP `get_project_info` | Returned project path and metadata: 29 scenes, 121 scripts, 8 assets. |
| Runtime visual inspection / screenshot | Not run. Process inspection found an existing `godot --path game res://tests/scenes/feasibility.tscn` process (PID 34381), likely the user's active test session. It was left untouched to avoid interrupting play. Thus visual quality and collision feel remain for the user to inspect in a restarted/current scene. |
| Full test suite / benchmark | Not rerun; this fixture-only layout is covered by the owning WORLD-06 smoke. Existing full-suite, benchmark and packaging evidence remain as recorded in the main WORLD-06 report. |

## Acceptance state

The new smoke assertion and structural layout checks pass. The new block has not received visual art-direction or human playtest acceptance. WORLD-06 remains incomplete pending human playtest notes, packaged macOS evidence, and performance/headroom gates. The current running game process predates the changes; restart `feasibility.tscn` to load the Night Market layout.
