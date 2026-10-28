# WORLD-10 — Playable Night Market launch slice

**Status: complete, bounded exploration slice.** The project now starts in the imported Night Market district with the existing first-person controller. A generated collision body provides one walkable ground box and 56 low-cost structural boxes derived from Blender-authored meshes named `solid`. Decorative meshes remain non-solid. This does not complete the wider ASSET-08 kit or WORLD-08 neighborhood.

## Changed files

- [night_market.tscn](../../game/world/districts/night_market/night_market.tscn) composes the imported district and existing player with lighting/environment.
- [night_market_collision_builder.gd](../../game/world/districts/night_market/night_market_collision_builder.gd) builds the ground and structural blockers from imported mesh bounds.
- [project.godot](../../game/project.godot) now uses the Night Market as `run/main_scene`; the existing fullscreen mode remains enabled.
- [verify_night_market_playable.gd](../../tools/godot/verify_night_market_playable.gd) checks startup configuration, camera/input, collision and movement.
- [startup frame](../evidence/WORLD-10/night_market_startup_frame.png).

## Verification

| Command or tool | Exit/result |
|---|---|
| `godot --headless --path game --script '/Users/rukithnayak/Documents/ChatGPT/Cyberpunk 3D Game/tools/godot/verify_night_market_playable.gd'` before scene implementation | 1 as expected: configured startup scene and scene load failed because the target scene did not exist. |
| Same focused verifier after implementation | 0; 13 checks passed: fullscreen startup, scene load, active player/camera and mouse-capture setting, 57 collision shapes, street-ground start, wall ray blocked, forward movement and grounded state. |
| `godot --headless --path game --editor --import` | 0; project and imported assets initialized without reported import errors. |
| `godot --path game` | 0 after manual stop; native Godot 4.7.2 / Metal launched the configured main scene and logged `NIGHT_MARKET_COLLISION structural_shapes=56`. |
| `godot --path game --write-movie /tmp/night_market_runtime.png --quit-after 1` | 0; one engine startup frame written to `/tmp/night_market_runtime00000000.png` and copied to project evidence. Movie Maker captures at the configured 960 × 540 viewport size; project startup remains configured for fullscreen mode. |
| Godot MCP `run_project` → `get_debug_output` → `stop_project` | Started; debug output reported Godot 4.7.2, `structural_shapes=56`, and `errors: []`; stop completed. |
| `git diff --check` | 0 after source, report, task and tracker updates. |

## Limits

- Structural blockers use mesh axis-aligned boxes. They stop entry into buildings cheaply, but can cover doors or shallow openings represented inside one `solid` mesh; detailed doorway traversal remains for the fuller district pass.
- The ground is a simple box under the full district bounds. Building interiors, stairs, navigation, NPCs, interaction, and gameplay scenarios are not added here.
- The controller's mouse-capture setting is enabled and camera is active. A human mouse-look check was not performed in this session.
- The saved startup frame is a single Movie Maker viewport frame, not a measured fullscreen performance or packaging result.
