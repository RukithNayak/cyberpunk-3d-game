# Asset pipeline conventions

Status: proposed conventions for Stage 0/1, based on the approved asset workflow and Godot glTF target. The minimal Blender 5.2.3 headless export and Blender asset QA now pass when run with approved escalation; Godot import is still pending and these conventions are not evidence of a completed engine import.

## Units, axes, pivots, names

- Use metric scene units with `scale_length = 1.0`: one Blender unit represents one meter. Model and report dimensions in meters; apply rotation and scale before export. Keep world up as Z in Blender; export glTF with Y-up conversion enabled so the result uses glTF/Godot's Y-up convention.
- Modular architecture pieces use the lower southwest grid corner at world origin (0,0,0), with dimensions aligned to an agreed grid multiple. Standalone props use a bottom-center pivot. Characters use a ground-level pivot centered between the feet. State exceptions in the asset brief and provenance record.
- Asset IDs use lowercase snake case: `<category>_<descriptor>_<variant>`, for example `env_wall_panel_a`. Blender object/mesh names use a stable uppercase prefix and ID, e.g. `ENV_WallPanel_A`; materials use `M_<AssetId>_<Purpose>`; texture maps use `<asset_id>_<map>_<resolution>`, e.g. `env_wall_panel_a_basecolor_2k`. Avoid `.001` suffixes and spaces in exported names.
- Keep source and engine exports separate. Editable `.blend`, procedural scripts, and authored texture sources belong in `art/source/<category>/<asset_id>/`. Engine-facing `.glb` files belong in `game/assets/<category>/`. Temporary renders and caches stay out of source control. This layout is a convention; the Godot project has not yet been created.

## Materials and interchange

- Use glTF-compatible Principled BSDF materials and standard metallic/roughness workflow. Bake procedural nodes and Geometry Nodes results to mesh/material data before export; Godot does not execute Blender node graphs.
- Base color and emissive color textures use sRGB. Normal, roughness, metallic, ambient occlusion, masks, and displacement data use Non-Color/linear interpretation. Pack metallic/roughness/occlusion only with documented channel assignments. Keep normal maps tangent-space unless the asset/export contract explicitly states otherwise.
- Export GLB for a self-contained runtime artifact where practical. Use relative external texture paths only when a deliberate `.gltf` plus texture folder contract is chosen. Include mesh, UVs, material assignments and required animations; exclude cameras/lights and unneeded authoring helpers. Collision proxies should have explicit names and remain distinguishable from render meshes.
- Validate each GLB by opening/importing it in the pinned Godot version and checking orientation, scale, material/texture appearance, hierarchy, and animation when applicable. The Godot import check is pending; the minimal GLB has passed Blender-side structural validation and must still be imported by Godot.

## Review gate and binary policy

- Before accepting an asset, record dimensions, triangle count, object/material count, pivot, export settings, file size, and automated QA findings. Review a visual contact sheet from multiple angles and resolve or explain warnings. Then confirm successful Godot import.
- Keep small, intentional `.blend` sources, generation scripts, provenance, and reviewed GLB milestones in Git. Do not add render caches, temporary exports, or unreviewed bulk outputs. Do not add Git LFS until measured repository growth justifies it and the repository owners choose a storage policy. Record hashes for delivered source/export pairs where reproducibility matters.
- This smoke fixture is operational evidence only and is not approved art direction or a production reference asset.
