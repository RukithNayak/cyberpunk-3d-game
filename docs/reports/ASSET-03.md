# ASSET-03 — Blender to Godot asset round-trip

## Status

Accepted by Main Agent, 23 October 2026 (Asia/Kolkata). Stage 0. Sources and
authored `.blend` files preserved. Blender MCP 5.2.3 was available but connected
to a blank untitled scene; source inspection/export used the installed local
Blender 5.2.3 executable. Godot MCP 4.7.2 launched the visual fixture.

## Changes

- Fixed `export_modular_kit.py` to print a valid metadata path when an external
  `--out-dir` is used. Previously it completed repeat checks but exited 1 while
  formatting the result path outside the repository.
- Regenerated current render GLBs/metadata with the accepted exporter. Source
  `.blend` files were read only. Basecolor/ORM maps and collision GLBs remain
  byte-identical to their prior tracked versions; refreshed render GLBs and
  metadata now match the exporter output.
- Added `asset_roundtrip.tscn` and a fixture script that checks import structure,
  sRGB base-color material use, linear ORM channel mapping, Y-up dimensions,
  collision shape creation, and first-person-height pier/opening ray behavior.
- Added rebuild/fixture guidance in [asset-roundtrip.md](../asset-roundtrip.md)
  and visual evidence at [asset_roundtrip.png](../evidence/ASSET-03/asset_roundtrip.png).

## Verification

| Command / tool | Exit / result |
|---|---|
| `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/export_modular_kit.py -- --out-dir /tmp/asset03-repro --repeat-check` (before path fix) | 1; repeat checks passed, then external metadata path formatting raised `ValueError` (regression reproduced) |
| `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/export_modular_kit.py -- --out-dir /tmp/asset03-repro --repeat-check` (after path fix) | 0; wall and prop each report semantic repeat PASS; both basecolor/ORM hashes and render/collision GLB bytes match exactly |
| `/Applications/Blender.app/Contents/MacOS/Blender -b art/reference/wall_doorway.blend --python-exit-code 1 -P /Users/rukithnayak/blender-skills/skills/blender-core/scripts/env_report.py` | 0; Blender 5.2.3 LTS, metric meters, scene source unchanged |
| `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/blender/export_modular_kit.py -- --out-dir game/assets/reference --repeat-check` | 0; canonical outputs regenerated; exact asset counts/bounds as above |
| `godot --headless --path game --editor --import` | 0; all eight GLBs and image maps imported |
| `godot --headless --path game --scene res://tests/scenes/asset_roundtrip.tscn` | 0; wall 13 mesh surfaces, 4×3.4×0.487 m; prop 30 mesh surfaces, 0.92×1.28×0.605 m; 43 image-backed PBR surfaces with normals/UV0, six static bodies/shapes; pier ray blocked and doorway ray clear |
| Godot MCP `run_project` for `res://tests/scenes/asset_roundtrip.tscn` | Started; fixture wrote 2940×1846 visual capture before exiting. Capture inspected: wall, opening, and prop visible with baked colors. MCP debug-output query happened after the self-terminating fixture had exited and reported no active process. |

The fixture's first authoring run had a GDScript indentation parse error, then a
headless screenshot attempt against the dummy renderer; both were fixed before
the passing focused run. Export emits Blender 5.2 deprecation warnings for
`Material.use_nodes` and a glTF warning that multiple image texture nodes share
the material sampler. Imported material assertions confirm base color and ORM
remain available through Godot's PBR material channels. These warnings are
recorded, not suppressed.

## Remaining limits

- Visual capture is a fixture smoke image, not human art-direction acceptance.
- Current source materials are constant values, so this validates baking to maps
  but does not exercise a connected procedural shader graph or normal map.
- No performance/budget profiling or large-scale asset production was performed;
  ASSET-04 owns measured repeated-use budgets.
