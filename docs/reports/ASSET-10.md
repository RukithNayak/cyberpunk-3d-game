# ASSET-10 — Night Market civilian characters

**Status:** Blocked on ASSET-09 acceptance. The vendor and courier exports replace the two primitive civilian visuals; the Blender QA gate and pose review remain open. These files and runtime changes were created in the same bounded builder pass and are preserved, but ASSET-10 acceptance must wait for its stated dependency.

## Deliverables

- Authored Blender source collection library: `art/source/characters/night_market/crowd/night_market_crowd.blend`.
- Godot GLBs: market vendor (6,748 triangles, 1.69 m) and market courier (6,660 triangles, 1.76 m); each has 12 material slots, one UV map, a rig, and Idle/Walk/Interact/Combat/Death clips.
- Each character has generated 512 × 512 fabric base-color, roughness, and normal maps. No downloaded models.
- `night_market_runtime.gd` replaces the civilian capsule mannequins with their respective models and uses the imported Idle/Walk clips; the resident's existing damage/death handling remains attached. Authored Death is selected when available, with the existing fall as fallback.
- Captures: [vendor](../evidence/ASSET-10/market_vendor_material.png), [courier](../evidence/ASSET-10/market_courier_material.png).

## Verification

| Command | Exit | Result |
|---|---:|---|
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 --python tools/blender/build_night_market_characters.py > /tmp/npc_blender_build.log 2>&1; code=$?; tail -7 /tmp/npc_blender_build.log; exit $code` | 0 | Blender 5.2.3 LTS exported both GLBs, source library, and material previews. |
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 art/source/characters/night_market/crowd/night_market_crowd.blend --python /Users/rukithnayak/blender-skills/skills/blender-asset-qa/scripts/qa_check.py -- --objects CHR_MARKET_VENDOR_Render --profile game --no-modifiers` | 0 | Checker executed; result `pass:false`. UV bounds/overlap, topology degenerates, transforms, and weights pass. It reports eight coplanar overlaps and four detached outfit/detail islands; 62 n-gons are warnings. The foot bottom is at z=0.034 m. |
| `/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 art/source/characters/night_market/crowd/night_market_crowd.blend --python /Users/rukithnayak/blender-skills/skills/blender-asset-qa/scripts/qa_check.py -- --objects CHR_MARKET_COURIER_Render --profile game --no-modifiers` | 0 | Checker executed; result `pass:false`. UV bounds/overlap, topology degenerates, transforms, and weights pass. It reports eight coplanar overlaps and eight detached accessory/detail islands; 66 n-gons are warnings. The foot bottom is at z=0.036 m. |
| `godot --headless --path game --editor --import && godot --headless --path game --quit-after 180` | 0 | Both GLBs imported in Godot 4.7.2; Night Market logged `NIGHT_MARKET_READY`; no new runtime errors were emitted. |

The checker used `--no-modifiers` because the source file is an appendable collection library without a populated scene. Its `pass:false` results remain open. A fullscreen in-engine visual check and authored-pose deformation review remain unrun.

Godot MCP start/debug/stop also succeeded. Its output contained the expected Night Market ready message and three pre-existing GDScript shadowing/unused-variable warnings; no runtime errors were reported.
