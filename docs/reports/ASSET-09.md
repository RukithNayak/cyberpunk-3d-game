# ASSET-09 — Night Market hero characters

**Status:** In progress. Custom models are exported and integrated; full asset acceptance is blocked on the QA findings below and pose/deformation review.

## Deliverables

- Authored Blender source collection library: `art/source/characters/night_market/night_market_characters.blend`.
- Godot GLBs: Mara Vega (7,752 triangles, 1.72 m) and market security (6,856 triangles, 1.91 m); each has 12 material slots, one UV map, a rig, and Idle/Walk/Interact/Combat/Death clips.
- Each character has generated 512 × 512 fabric base-color, roughness, and normal maps. No downloaded models.
- Runtime hookup: `night_market_runtime.gd` instantiates Mara's GLB and plays Idle/Interact; `goon.tscn` uses the security GLB while retaining its CharacterBody, collider, perception, and navigation nodes. Security Idle/Death clips are connected.
- Captures: [Mara](../evidence/ASSET-09/mara_vega_material.png), [security](../evidence/ASSET-09/market_security_material.png).

## Verification

| Command | Exit | Result |
|---|---:|---|
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 --python tools/blender/build_night_market_characters.py > /tmp/npc_blender_build.log 2>&1; code=$?; tail -7 /tmp/npc_blender_build.log; exit $code` | 0 | Blender 5.2.3 LTS exported both GLBs, source library, and material previews. |
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 art/source/characters/night_market/night_market_characters.blend --python /Users/rukithnayak/blender-skills/skills/blender-asset-qa/scripts/qa_check.py -- --objects CHR_MARA_VEGA_Render --profile game --no-modifiers` | 0 | Checker executed; result `pass:false`. UV bounds/overlap, topology degenerates, transforms, and weights pass. It reports 14 coplanar overlaps and six detached costume/detail islands; 64 n-gons and 10 back-to-back pairs are warnings. The foot bottom is at z=0.035 m. |
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 art/source/characters/night_market/night_market_characters.blend --python /Users/rukithnayak/blender-skills/skills/blender-asset-qa/scripts/qa_check.py -- --objects CHR_MARKET_SECURITY_Render --profile game --no-modifiers` | 0 | Checker executed; result `pass:false`. UV bounds/overlap, topology degenerates, transforms, and weights pass. It reports 13 coplanar overlaps and nine detached armor/detail islands; 62 n-gons and two back-to-back pairs are warnings. The foot bottom is at z=0.039 m. |
| `godot --headless --path game --editor --import && godot --headless --path game --quit-after 180` | 0 | Both GLBs imported in Godot 4.7.2; Night Market logged `NIGHT_MARKET_READY`; no new runtime errors were emitted. |

The checker was run with `--no-modifiers` because the source file is an appendable collection library without a populated scene. Weight counts are still read from the mesh and armature modifier. The `pass:false` results remain open; layered outfit pieces explain some overlaps, but their visual/geometry acceptability has not been confirmed through a pose stress review.

The Blender MCP server disconnected during export attempts. The approved local Blender 5.2.3 executable was used for the successful export. A fullscreen in-engine visual check and authored-pose deformation inspection remain unrun.

Godot MCP start/debug/stop also succeeded. Its output contained the expected Night Market ready message and three pre-existing GDScript shadowing/unused-variable warnings; no runtime errors were reported.
