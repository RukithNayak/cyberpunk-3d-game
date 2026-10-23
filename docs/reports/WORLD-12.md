# WORLD-12 — Night Market gameplay hookup

**Status:** Complete, 24 October 2026 (Asia/Kolkata)
**Scope:** Connect existing dialogue/combat services to the Night Market start scene and make street ambience move.

## Changes

- Connected named Mara to the existing `DialogueUI`, `DialogueOrchestrator`, local Ollama provider (`llama3:willowbrook`), and authorized `retrieve_signal_cache` mission. Added a visible `E // TALK` marker and player-control/mouse-capture handling while the dialogue panel is open.
- Added guarded status feedback for interaction range, hits, reloads and kills. The HUD now lists the talk/fire/reload controls.
- Replaced the visual-only security placeholder with a configured, collidable `TacticalAgent`. The starter pistol's existing hitscan/ammo path damages it; lethal damage disables its collider and lowers its mesh with a visible `SECURITY // DOWN` label.
- Added short walking/limb loops for two residents and subtle street-light pulses.
- Extended the focused verifier to cover the scene's dialogue, fallback, combat, movement, inventory, and collision interactions.

## Verification

| Command/tool | Exit/result |
| --- | --- |
| `godot --headless --path game --editor --import` | 0 |
| `godot --headless --path game --script res://../tools/godot/verify_night_market_playable.gd` | 0; 29 assertions passed |
| Focused local-model exchange | Passed; `llama3:willowbrook` produced a validated nonempty response (`used_fallback=false`) |
| Focused unavailable-model probe | Passed; an intentionally nonexistent Ollama model produced a nonempty authored fallback |
| Godot MCP `run_project` on `game/`, then `get_debug_output` | Startup succeeded; no runtime errors. Three pre-existing GDScript warnings remain in `dialogue_orchestrator.gd`, `perception.gd`, and `tactical_agent.gd`. |
| Fullscreen capture and visual review | Captured and inspected at [night_market_startup.png](../evidence/WORLD-12/night_market_startup.png) |

The focused verifier observed the player walking while grounded, 57 collision shapes, a moving pedestrian, E opening dialogue and locking player controls, closing dialogue restoring controls, four aimed pistol hits reducing guard health to zero, the visible down state, and magazine ammo consumption. Inventory open/close and wall collision checks also passed.

The broad test suite, alternate resolutions, and performance benchmarking were not run; they are outside this task. Existing mannequin-style residents and short loop paths are prototypes, not final character/world simulation. The screenshot is a runtime acceptance capture, not a claim that the neighborhood is fully realized; WORLD-08/09 and ASSET-09 remain open.
