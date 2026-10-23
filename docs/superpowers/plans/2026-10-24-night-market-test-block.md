# Night Market Test Block Implementation Plan

> **For agentic workers:** execute inline with the approved Stage 1 scope; this is a single cohesive fixture task.

**Goal:** Make WORLD-06's existing interactions reachable through a compact, readable, cyberpunk Night Market block.

**Architecture:** Add fixture-only environment geometry and landmarks around the existing test world. Keep all gameplay actors/services and chunk streaming contracts unchanged; validate required layout landmarks in the existing feasibility smoke and visually inspect a Godot runtime.

**Tech Stack:** Godot 4.7.2 typed GDScript and primitive MeshInstance3D/StaticBody3D fixtures.

**Spec:** `docs/superpowers/specs/2026-10-24-night-market-test-block-design.md`

## Global Constraints

- Stage 0/1 only; no production city, bulk asset creation, downloads, dependencies, or export setup.
- Preserve `benchmarks/feasibility/runtime_metrics.json` and existing user changes.
- Retain current target positions, IDs, interaction ranges, smoke/benchmark behavior, main scene and chunk contracts.

## Review Focus

- Geometry must leave player spawn and all current combat/NPC/loot/hack interaction positions accessible; checked by existing feasibility smoke.
- Geometry should read as a connected plaza, market street and service alley; inspect a runtime capture.
- Static props must not introduce script/runtime errors or change streaming/gameplay test outcomes; check fixture smoke and Godot debug output.

### Task 1: Night Market fixture layout

**Files:**
- Modify: `game/tests/scenes/feasibility.gd`
- Modify: `docs/tasks/world-scene-manager.md` (record fixture scope and acceptance evidence before implementation)
- Modify: `docs/reports/WORLD-06.md`
- Modify: `docs/master-progress.md`
- Create: `docs/reports/WORLD-06-night-market.md`

**Interfaces:**
- Consumes existing fixture's player, props, door, NPC and two streamed ground chunks without changing their interfaces.
- Produces named scene landmarks for spawn plaza, market street, and service alley; keeps walkway and interaction target clearances intact.

- [x] Record this bounded fixture layout scope and criteria in WORLD-06 before changing fixture code.
- [x] Add a failing assertion to the existing `--smoke` fixture proving the three named layout landmarks exist, and confirm it fails before implementation.
- [x] Add lightweight, collidable storefront/stall/blockout geometry and emissive signs/landmarks in unused route edges around current targets. Give the generated layout stable node names for smoke assertions.
- [x] Run `godot --headless --path game res://tests/scenes/feasibility.tscn -- --smoke`; exit 0, 25/25 passed.
- [ ] Inspect the scene visually via Godot MCP or a local Godot launch. Godot MCP version/project info succeeded, but runtime visual inspection remains unrun because PID 34381 is already running the fixture and was preserved.
- [x] Run `git diff --check`; exit 0. Inspected the diff and updated WORLD-06/task/master tracker and the structured report with exact results. WORLD-06 remains incomplete: human playtest, packaged result, and performance gates remain open.
