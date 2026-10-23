# WORLD-11 — Night Market color, HUD and NPC presence

**Status: complete for the bounded presentation task.** The Night Market startup scene now renders the authored district vertex colors through a stronger blue/magenta facade palette, warmer windows, colored street lighting and neon wayfinding. The existing health/ammo/pause HUD and inventory are initialized with a starter pistol and medkit. Four named street figures are visible.

## Files changed

- `game/world/districts/night_market/night_market.tscn` — adjusted ambient/key lighting, tone mapping and color response.
- `game/world/districts/night_market/night_market_runtime.gd` — applies shared cached material tints to the imported district, configures existing player/inventory services, creates neon signs and lights, and places four named resident/guard silhouettes.
- `tools/godot/verify_night_market_playable.gd` — adds HUD, inventory and resident assertions while retaining all WORLD-10 movement/collision checks.
- `docs/tasks/world-scene-manager.md`, `docs/master-progress.md` — recorded and closed the bounded task.
- `docs/evidence/WORLD-11/night_market_fullscreen.png` — inspected fullscreen runtime capture.

## Verification

| Command/tool | Result |
|---|---|
| `godot --headless --path game --editor --import` | Exit 0; import/editor initialization completed without errors. |
| `godot --headless --path game --script res://../tools/godot/verify_night_market_playable.gd` | Exit 0; all 18 checks passed, including fullscreen startup, configured HUD/inventory, Tab open/Escape close with player control lock, four residents, 57 colliders, wall blocking and grounded street movement. |
| Godot MCP `run_project` + `get_debug_output` | Started on Godot 4.7.2 / Metal; `NIGHT_MARKET_COLLISION structural_shapes=56`; `errors: []`. |
| macOS `screencapture -x docs/evidence/WORLD-11/night_market_fullscreen.png` | Exit 0; fullscreen capture visually inspected. |
| `git diff --check` | Exit 0. |

The one-shot screenshot is visual evidence only; it is not a performance measurement. The world figures are colored blockout silhouettes, not the custom rigged Mara/security models. They do not move, collide, speak, fight, persist or offer missions. The imported street still reads very dark away from the neon pools, and the rest of the 300 m neighborhood is not yet dressed to WORLD-08 acceptance.
