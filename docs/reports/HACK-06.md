# HACK-06 — Representative cyberpunk hacking encounters

**Status:** Accepted, Stage 1. 23 October 2026 (Asia/Kolkata).  
**Owner:** Main Agent.  
**Scope:** Two encounter samples that exercise the accepted hacking contracts while keeping no-hack paths open. These samples do not define final city size; the project remains a large, continuous cyberpunk city with distinct districts.

## Delivered

- `stealth_route.tscn` / `stealth_route.gd`: neon-market maintenance alley with an approach covered by a surveillance camera, durable registry-backed service-door shortcut, and a collision-tested bypass around the locked door.
- `security_corridor.tscn` / `security_corridor.gd`: visually separate corporate transit/security space with a hostile turret crossing, waist-high cover, side flank, guard distraction device and implant target.
- `hacking_encounter_base.gd`: shared fixture construction for the scene geometry, unique authored UUIDs, active chunk lifecycle, EntityHydrator, HackSnapshot and HackingService composition. Each scene script retains its own encounter layout and palette.
- Existing ASSET-03 doorway and utility-junction GLBs used as dressing. Facade signage, emissive windows, street lighting and route markings are authored in Godot; no downloads or new Blender source assets.
- `test_hacking_scenarios.gd` and `hacking_scenarios` runner entry cover both scene loads, target identities/range/line-of-sight, camera and turret effect consequences, permanent door state, guard response to distraction/implant, and physical alternate routes.

## Verification

- `godot --headless --path game --editor --import` — exit 0.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite hacking_scenarios` — exit 0; 24 cases, 0 failures.
- `godot --headless --path game --script res://tests/run_tests.gd -- --suite all` — final exit 0; 843 cases, 0 failures. The runner still emits one ObjectDB and one `GodotBody3D` RID leak warning at shutdown.
- One earlier full-suite attempt in this session exited 1 because the pre-existing isolated `ai_navigation` fixture returned an empty path at map iteration 2 / region iteration 1. A subsequent run passed; the final post-change run also passed. This intermittent AI-03 fixture race is recorded in `docs/master-progress.md`.
- `git diff --check` — exit 0.
- Godot MCP `run_project` launched both `stealth_route.tscn` and `security_corridor.tscn` in Godot 4.7.2 on OpenGL/Metal. Debug output contained no runtime errors; it listed two existing script-shadowing warnings in `features/npcs/perception.gd:70` and `features/npcs/tactical_agent.gd:316`.
- Captures were inspected: [Neon Market alley](../evidence/HACK-06/stealth_route.png), [Corporate Transit corridor](../evidence/HACK-06/security_corridor.png). They show palette and layout differentiation with representative assets. Detailed human free-walk/combat readability playtest remains deferred to WORLD-06.

## Known limits

These are compact, authored Stage 1 encounter slices and greybox-quality scenery, not the full city or final art pass. WORLD-06 still needs combined-system, save/reload and human playtest evidence before the integrated feasibility gate can pass.
