# WORLD-13 — visible shots and killable Night Market NPCs

**Status:** Complete, 24 October 2026 (Asia/Kolkata)

## Changes

- Every successful pistol shot now spawns a brief emissive capsule projectile that travels from the muzzle to the resolved hit point. Damage and ammo still use the existing hitscan transaction.
- Mara, the vendor, and the pedestrian now have real capsule hitboxes, data-only `HealthState`, and visible down animations. Dead NPC colliders are disabled; down Mara no longer resolves for dialogue.
- Moved the pedestrian's short ambient loop into the open street after the first focused run showed the former route was occluded by a building collider.
- Extended the focused startup verifier to move-test the shot visual, reload, and shoot all four named NPCs to death.

## Verification

| Command/tool | Exit/result |
| --- | --- |
| `godot --headless --path game --editor --import` | 0 |
| `godot --headless --path game --script res://../tools/godot/verify_night_market_playable.gd` | 0; 43 assertions passed |
| Local-model integration | Passed with a validated `llama3:willowbrook` response; separate invalid-model request showed the authored fallback |
| Godot MCP `run_project` and `get_debug_output` | Startup succeeded; no runtime errors. Three pre-existing unused/shadowing warnings remain in the dialogue orchestrator and NPC AI scripts. |
| Fullscreen capture and visual review | Inspected [night_market_startup.png](../evidence/WORLD-13/night_market_startup.png) |

The focused run verified shot visual movement, ammo use and reload, security defeat, and hit/death/collider removal for Mara, the vendor and the pedestrian. It also verified dead Mara cannot be returned by the dialogue actor resolver, while live dialogue and fallback continue to work.

The projectile is a short visual animated over the authoritative hitscan result; it does not simulate projectile collision. NPC health/death is transient and not saved. NPC meshes remain blockout mannequins. The full test suite, alternate resolutions, performance profiling, and an in-flight rendered screenshot were not run; the runtime capture shows the startup scene, while the focused verifier checks the projectile's travel.
