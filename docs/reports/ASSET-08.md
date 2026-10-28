# ASSET-08 — Night Market architecture and streetscape

**Status: in progress.** Imported a 300 m × 300 m Lantern Market district slice from the user-authorized MIT-licensed upstream project to accelerate the environment base. The Godot asset check and fullscreen visual smoke pass. Collision proxies, the repeated-use observation, and final Blender QA/acceptance remain open.

## Reused deliverables

- Editable extracted source: [neon_market_district.blend](../../art/source/environment/night_market/neon_market_district.blend).
- Godot district scene source: [neon_market_district.glb](../../game/assets/environment/night_market/neon_market_district.glb).
- Additional props copied from upstream: [neon_market_kiosk.glb](../../game/assets/environment/night_market/neon_market_kiosk.glb), [neon_district_relay.glb](../../game/assets/environment/night_market/neon_district_relay.glb), and [neon_district_energy_crate.glb](../../game/assets/environment/night_market/neon_district_energy_crate.glb).
- Compact scene fixture: [neon_market_world_preview.tscn](../../game/tests/scenes/neon_market_world_preview.tscn); single-pass import checker: [verify_asset08_import.gd](../../tools/godot/verify_asset08_import.gd).
- Upstream commit and checksums: [asset-manifest.md](../asset-manifest.md). MIT license and third-party notices are retained in [art/source/third_party/neon-district](../../art/source/third_party/neon-district/).

The district slice contains 428 mesh objects: 211 architecture, 146 signage, 44 storefront assemblies, and 27 market/residential assemblies. Blender source reported 127,356 base triangles and five shared export materials; Godot reports 428 MeshInstance3D nodes, five materials, and aggregate bounds of (251.99, 47.11875, 222.35) m. The exported GLB is 10,034,704 bytes; editable subset source is 4,246,853 bytes. No campaign image textures remain in the subset. The source is voxel-styled and offers a fast large-area visual base; it does not replace the locally authored close-range hero storefront.

## Verification

| Command/tool | Result |
|---|---|
| /Applications/Blender.app/Contents/MacOS/Blender -b --disable-autoexec art/source/third_party/neon-district/neon-district-city.blend --python-exit-code 1 -P tools/blender/extract_neon_market_slice.py -- --out game/assets/environment/night_market/neon_market_district.glb | Exit 0; Blender 5.2.3; 428 selected objects; 127,356 base triangles; campaign image list empty. |
| /Applications/Blender.app/Contents/MacOS/Blender -b --disable-autoexec art/source/environment/night_market/neon_market_district.blend --python-expr inspection | Exit 0; one extracted scene, 428 objects, zero images, five materials. |
| Blender MCP `get_blendfile_summary_datablocks_for_cli` for the extracted source | Tool error: configured server could not find executable `blender`; source inspection was completed with the approved local Blender 5.2.3 executable above. |
| godot --headless --path game --editor --import | Exit 0; imported district GLB. |
| `godot --headless --path game --script '/Users/rukithnayak/Documents/ChatGPT/Cyberpunk 3D Game/tools/godot/verify_asset08_import.gd'` | Exit 0; 428 meshes, five materials, bounds (251.99, 47.11875, 222.35) m; ASSET08_IMPORT PASS. |
| godot --path game res://tests/scenes/neon_market_world_preview.tscn | Launched on Godot 4.7.2 / OpenGL 4.1 Metal, then stopped cleanly (exit 0). Fullscreen visual evidence: [preview](../evidence/ASSET-08/neon_market_preview.png). |
| `git diff --check` | Exit 0 after report and tracker edits. |

## Acceptance still open

- The source GLB remains render-only. The separate Night Market launch scene now generates a ground plane and structural blockers; this does not complete ASSET-08's exported asset collision-separation criterion. The old preview remains fixed-camera.
- The upstream source uses voxel/stylized architecture, not the locally authored high-detail close-range door material treatment.
- The locally authored modular kit remains in the working tree. Its prior Blender QA reported errors and warnings; it is not part of the accepted district slice and is not claimed as passed.
- No repeated-use draw-call/frame/memory observation was made. WORLD-06 numeric budget ratification remains separate.
- The imported kiosk, relay and crate GLBs are present but have not yet been placed into the playable neighborhood.

The bounded [WORLD-10 launch slice](WORLD-10.md) now provides a walkable ground plane, structural collision and a tested short street route. Next within ASSET-08: complete modular-family coverage and decide how the locally authored batch supplements the reused architecture set.
