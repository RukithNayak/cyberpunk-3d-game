# Cyberpunk 3D FPS — Development Proposal

**Date:** 23 October 2026  
**Status:** Draft for discussion; recommendations are not approved requirements.  
**Purpose:** Define a feasible AI-assisted production pipeline for a larger cyberpunk world with first-person gun combat and generative NPCs.

## 1. Direction and first step

Build a first-person cyberpunk action game set in one seamless city with distinct districts, NPC-supplied missions, responsive gun combat, environmental/combat hacking, and selected NPCs who can hold contextual, unscripted conversations. Use AI to produce code, asset-generation scripts, concepts, narrative drafts, and verification tooling. The user supplies creative direction, makes product decisions, and playtests.

The immediate step is to settle release platforms and the remaining gameplay decisions, then verify the toolchain on the user-reported M5 MacBook Air with 16 GB RAM. The first development milestone should then be a **technical feasibility build** that runs combat, two connected world chunks, and one local generative NPC together. It is a test of the production architecture, not a replacement for the larger game.

Do not start by generating an entire city or downloading a large language model. Establish a reproducible toolchain, a reference asset, and a combined performance baseline first. Expand the world using the systems proved by that baseline.

## 2. Confirmed requirements and open decisions

### Confirmed by the user

- A 3D cyberpunk-themed video game developed using AI.
- One seamless city, larger than a single alley or small encounter space, with a few detailed interiors where NPCs may reside.
- Stylized, detailed cyberpunk visuals.
- NPCs supply missions and support conversations.
- Enemy goons, possibly organized into gangs.
- Hacking abilities used in combat and the environment.
- Multiple weapon types with loot rarity.
- Proper health and inventory management systems.
- No vehicles.
- Development hardware: M5 MacBook Air with 16 GB RAM, as reported by the user.
- First-person perspective and gun combat.
- Generative AI integrated into NPCs.
- Codex for coding and automation.
- Existing ChatGPT Plus subscription; additional tools should be free or covered by existing access.
- Actual 3D assets are necessary; images alone are insufficient.
- Game-development and Blender skill collections are installed locally.

### Proposed defaults requiring review

| Decision | Recommendation | Reason |
|---|---|---|
| Engine | Godot 4.7.2 | Already installed; scriptable, lightweight development workflow; substantial installed skill coverage |
| Language | Typed GDScript | Keeps the initial toolchain small and aligns with installed Godot skills |
| Visual execution | Modular architecture with strong silhouettes and detailed materials | Implements the confirmed stylized, detailed cyberpunk direction |
| Play mode | Single-player | Keeps combat, persistence, and generative NPC synchronization tractable |
| Internal world organization | Streamed chunks within one seamless city; selected detailed interiors | Preserves continuous city traversal while controlling active content |
| Runtime NPC inference | Local Ollama model, selected by benchmark | Avoids mandatory per-request cloud charges |
| Dialogue presentation | Text first; optional speech later | Tests conversation quality without adding voice-generation dependencies |
| Initial development platform | macOS | Matches the current workstation; release targets remain unconfirmed |

These are recommendations, not claims that the user has chosen them. Seamless city traversal, stylized detailed visuals, and no vehicles are confirmed. Multiplayer/single-player status, final map size, and release platforms remain open. The plan assumes single-player until clarified.

### Local environment observations

Checked during preparation of this proposal:

- Workspace has Git metadata and no game implementation or existing `AGENTS.md` was found.
- `godot --version` reports `4.7.2.stable.official.ed1daf0bf`.
- Godot is accessible through `/opt/homebrew/bin/godot`; `/Applications/Godot.app` exists.
- Ollama is accessible through `/usr/local/bin/ollama`; `/Applications/Ollama.app` exists.
- Ollama server health, available models, and inference speed have not been tested.
- Blender was not found through `command -v blender` or at `/Applications/Blender.app`. It may be installed elsewhere.
- The user reports an M5 MacBook Air with 16 GB RAM. Available storage and sustained performance remain unverified; the hardware query attempted in this environment was restricted.
- Treat 16 GB as a combined system/game/model memory constraint. Select the model and renderer by concurrent-load benchmarks, including sustained thermal behavior.
- All 22 `blender-*` skill directories are present under `/Users/rukithnayak/.agents/skills`.
- Skill scripts have been inspected as instructions, not executed or validated against an installed Blender runtime.

## 3. Approaches and proposed tech stack

### Engine approaches

| Approach | Advantages for this project | Tradeoffs | Status |
|---|---|---|---|
| Godot + Blender + Ollama | Small toolchain, editable scripts/scenes, free engine, installed skills, local inference option | City streaming and persistence require project-specific engineering; renderer and inference must share hardware resources | Recommended starting point |
| Unreal + Blender + Ollama | Integrated large-world tools, mature shooter and visual workflows | Heavier editor/content workflow; more work through engine assets and editor tooling; commercial terms apply | Alternative if realistic visuals dominate and hardware supports it |
| Unity + Blender + Ollama | C# workflow and broad 3D ecosystem | Additional setup and version/package management; no specific project advantage established yet | Viable alternative, not currently recommended |

The final engine decision should precede scaffolding or producing a large asset library. Do not choose an engine solely because a skill collection contains more files for it. If benchmarks disqualify the recommended approach, revise the proposal before building dependent systems.

### Recommended stack

| Layer | Proposed technology | Responsibility |
|---|---|---|
| Game runtime | Godot 4.7.2, pinned | Gameplay, physics, navigation, UI, audio, rendering |
| Gameplay code | Typed GDScript and Godot Resources | Controllers and configurable weapon/NPC/mission data |
| 3D authoring | Blender, version confirmed before use | Meshes, UVs, rigs, animation, baking, asset review |
| Asset automation | Blender Python scripts and Geometry Nodes | Reproducible modular kits and batch asset processing |
| Runtime interchange | GLB/glTF for Godot, verified through round-trip tests | Meshes, image-backed materials, skeletons, animation |
| Texture/art drafts | Existing ChatGPT image tools | Concepts, advertisements, decals, screen graphics, texture references |
| Runtime language model | Ollama local HTTP API | Conversations and validated high-level NPC proposals |
| AI provider abstraction | Project-owned interface | Real local provider plus deterministic mock/fallback provider |
| Persistence | Versioned data saves with stable IDs | Player state, world changes, missions, NPC memory |
| Development assistant | Codex using installed skills | Implementation, automation, review, debugging, documentation |
| Version control | Git; consider Git LFS when binary assets warrant it | Source history and recoverable milestones |
| Verification | Godot headless checks, in-engine playtests, Blender QA, profiler captures | Functional, visual, export, and performance evidence |

Start with built-in engine functionality. Add dependencies only when a specific need justifies maintenance and packaging cost. A separate Python or Node backend is not required initially: the game can call the local provider through HTTP.

### Cost boundaries

The intended development software budget is zero beyond the existing Plus subscription, subject to its usage limits. This does not imply unlimited generation or free cloud hosting.

- OpenAI API billing is separate from ChatGPT subscription usage. Do not use a ChatGPT login as an in-game API mechanism.
- Local inference avoids per-request hosting fees but consumes RAM, compute, storage, and power.
- Free model weights have individual licenses; review the selected model before distribution.
- Downloaded assets must have recorded licenses; AI-generated assets need source/generation records.
- Storefront fees, signing/notarization requirements, hosting, and commercial voice services are release decisions outside the initial software budget.
- No paid service, large model download, or new runtime dependency is assumed approved by this proposal.

## 4. Proposed game scope

### Product pillars

1. **Readable, satisfying first-person combat:** movement, aiming, weapon response, enemy feedback, and fair encounters.
2. **A seamless city worth exploring:** recognizable districts, vertical routes, landmarks, detailed NPC interiors, and continuous street traversal.
3. **NPCs with continuity:** conversations reflect identity, legitimate knowledge, relationships, and player actions.
4. **A coherent cyberpunk identity:** consistent architecture, material language, advertisements, lighting, sound, and faction cues.

### Candidate first complete game

The following is a scope proposal for estimating production, not a fixed commitment or a map-size cap:

| Area | Candidate scope |
|---|---|
| World | One seamless city with three proposed substantial districts: commercial/market, industrial/service, and corporate/security; no visible loading transitions while walking between districts |
| Traversal | Walking, running, crouching, jumping; rooftops and stairs where gameplay supports them; no vehicles |
| Interiors | A selected set of mission spaces, shops, safe areas, and utility spaces |
| Weapons and loot | At least three proposed firearm families, such as pistol, automatic weapon, and shotgun, with data-driven rarity tiers and bounded stat variation |
| Hostiles | Enemy goons with three proposed behavior roles and possible gang affiliation, using reusable animation/equipment; drone is optional |
| Missions | NPC-supplied jobs built from validated mission templates plus authored story content; exact counts and duration after a representative mission is built |
| Hacking | Combat and environmental actions against tagged devices/targets, with clear costs, range, feedback, and cooldowns |
| Health and inventory | Health/damage/healing/death, weapon equipment, ammunition, consumables, loot pickup, capacity, and persistent item state |
| Generative NPCs | A small roster of named conversational NPCs distributed across districts; one active model request initially |
| Ambient population | Lightweight conventional behaviors; no requirement for every pedestrian to run an LLM |
| Persistence | Player loadout, mission outcomes, important world changes, relationships, and bounded NPC memories |
| Presentation | One coherent baseline lighting/weather mood, subtitles, settings, HUD, and spatial sound |

Determine physical dimensions from traversal times, encounter spacing, landmarks, and performance. Do not equate a large decorative skyline with accessible playable space. Decide the target amount of walkable and interior content explicitly.

Vehicles are excluded by the user. Multiplayer, a fully enterable city, destructible buildings, a full day/night simulation, survival crafting, and voiced conversations are **expansion candidates**, not included in this baseline without user direction. If any is central to the intended game, promote it now so architecture and milestones account for it.

## 5. Feature design

### First-person player and combat

- Configurable field of view, mouse sensitivity, invert-look, and input rebinding.
- Predictable movement, collision, stairs/slopes, jump and crouch behavior.
- Data-driven damage, firing cadence, ammunition, reload timing, recoil, spread, and range.
- Hitscan for initial firearms; projectiles only where they create a distinct gameplay need.
- Resolve aim and muzzle obstruction so shooting near walls cannot bypass cover.
- Keep first-person arms/weapons separate from world pickup and NPC weapon representations where useful.
- Coordinate reload/fire animation, ammunition updates, damage, sound, and muzzle effects through explicit state transitions.
- Clear hit reactions and impact feedback; optional/reduced camera shake and other comfort settings.
- Death, checkpoint/reload behavior, pause, and a safe settings flow.

### Loot, inventory, and health

- Define weapon families separately from rarity; rarity should not silently replace weapon identity or guarantee a better weapon in every circumstance.
- Proposed tiers: common, uncommon, rare, epic. Names, drop rates, stat ranges, and tier count require balance review.
- Give each item instance a stable ID; store rolled stats, ammo state, and equipment state so reloads and save/load cannot reroll or duplicate loot.
- Use seeded weighted drop tables with bounded outcomes and reproducible debugging seeds.
- Provide pickup, inspect, equip/swap, drop, and use-consumable actions. Propose limited equipment slots plus a capacity-limited backpack; settle weight versus slot capacity before UI implementation.
- Separate reserve ammo from magazine state. Define whether ammo is shared by caliber or weapon family.
- Health includes visible current/max values, damage feedback, healing items, death, and checkpoint restoration. Armor, regeneration, and limb damage are optional pending design.
- Verify full-inventory pickup, swapping equipped weapons, interrupted reload/healing, death during interactions, and repeated save/load without duplication or item loss.

### Hacking in combat and the environment

- Treat hacking as a normal gameplay subsystem with explicit target tags, range, visibility/access rules, costs, and cooldowns; it does not depend on LLM response latency.
- Candidate actions: disable a camera, unlock an eligible door, trigger a distraction, temporarily disrupt an enemy implant, and disable a turret. Select a small initial set before implementation.
- Proposed resource: rechargeable hacking energy with per-ability cooldowns; tuning and whether regeneration is permitted remain design decisions.
- Communicate valid targets, current effect, remaining duration, failure reason, and resource use through readable world/UI feedback.
- Validate each hack against authoritative target state. Mission-critical locks require explicit rules and alternate routes where intended.
- Persist permanent effects; restore timed effects consistently after saving. Cancel transient operations safely when targets unload or are destroyed.
- Enemies may investigate distractions or react to security changes through conventional AI events.

### Enemy and civilian AI

- Perception based on line of sight, range, sound/events, and explicit alert state.
- Conventional patrol, investigate, pursue, attack, reposition, retreat, and search states.
- Navigation uses engine facilities; avoid rebuilding A* when an engine navmesh meets the need.
- Behavior trees or utility scoring only when state complexity warrants them.
- Debug overlays expose current state, destination, perception, and stuck recovery.
- Distant/inactive NPCs use simplified simulation or persistent records instead of full combat processing.

### Generative NPC architecture

Use two cooperating layers: ordinary gameplay code owns world truth and immediate actions; the language model produces dialogue and optionally proposes a bounded high-level action.

Request flow:

1. Capture a snapshot of NPC identity, known facts, relationship state, allowed actions, and bounded memory.
2. Queue an asynchronous provider request with an NPC ID, conversation ID, and request generation number.
3. Display an appropriate waiting state while gameplay remains responsive.
4. Parse a schema-constrained response; validate types, size, action name, parameters, and current preconditions.
5. Commit only permitted state changes and record an auditable dialogue/memory event.
6. Discard stale responses after NPC death, district unloading, conversation cancellation, or changed request generation.

Initial allowed actions should be small: disclose a known fact, offer an eligible job, accept a permitted trade, or request a defined interaction.

NPC mission supply uses a mission director: code selects eligible templates and existing world targets, assigns stable IDs, validates reachability/faction rules and rewards, and tracks offered/accepted/active/completed/failed states. The model can personalize the explanation and propose an allowed template; it cannot invent a nonexistent district, impossible target, arbitrary reward, or unchecked objective. Persistent offered and accepted jobs survive chunk unloading and model failure. Start with delivery, retrieval, clearing a hostile location, and hacking an existing device as candidate templates. Provide an authored fallback offer for important progression. The model cannot invent inventory, award money, complete missions, or execute arbitrary code.

Memory separates persistent factual events from compact summaries. NPC knowledge is scoped: remembering a conversation does not grant knowledge of unseen player actions. Summaries are derived context, not authoritative mission records.

Limit concurrency and context length; prioritize player-facing interaction. Support cancellation, deadlines, malformed output, provider unavailability, and model changes. Ship a deterministic fallback interaction path so mission progress survives failed inference. Start with text; speech recognition, speech synthesis, and facial synchronization are separate optional systems.

For deployment, decide whether players run a bundled/local model, configure their own compatible provider, or use a hosted service. Local development is not a complete consumer distribution solution. Record model license, download size, installation steps, and minimum hardware before selecting a release strategy.

### World structure and persistence

- Present one continuous city to the player. Districts and chunks are internal organization, with no loading screens or forced travel menu between streets.
- Author reusable modules and assemble districts with deliberate combat and exploration design.
- Selected detailed interiors connect through doors/vestibules that allow preloading. Interior transition presentation needs confirmation; propose continuous entry wherever performance allows.
- Use procedural variation for secondary detail and repeated architecture; preserve designed landmarks and mission routes.
- Separate world layout data from runtime scene instances.
- Give persistent entities stable IDs independent of load order or scene-tree paths.
- Load nearby chunks asynchronously, with a bounded activation budget on the main thread.
- Unload only after serializing relevant changes; cancel or redirect work targeting unloaded entities.
- Persist destroyed/collected objects, opened doors, mission changes, and named NPC state.
- Design navigation connections and NPC handoff at chunk boundaries.
- Use hysteresis/preload margins to avoid repeated load/unload at boundaries.
- Test alternative routes, backtracking, fast movement, and save/load at boundaries.

## 6. Art and asset-production methodology

AI images provide concepts and surface artwork. Blender produces the actual meshes, rigs, animation, UVs, collision proxies, and exportable materials.

### Reference asset before bulk generation

Make one representative modular wall/doorway and one close-up mechanical prop. Evaluate both at player eye height inside the engine. Use those results to define scale, palette, silhouette, material response, trim/detail density, and practical texture/triangle budgets. Do not mass-produce a city kit before the target is coherent.

### Repeatable asset pipeline

1. Write the asset brief: gameplay role, dimensions, pivot, material family, collision, animation, and target engine.
2. Generate or select references and record the visual choice.
3. Build editable Blender sources with Python or Geometry Nodes where appropriate.
4. Clean topology; UV unwrap; establish consistent texel density.
5. Bake detail and procedural materials to exportable image maps when needed.
6. Build simplified collisions and appropriate LODs; retain instancing/reuse where the importer supports it.
7. Run asset QA, inspect contact sheets, and review animated deformation where applicable.
8. Export to the engine and verify orientation, scale, materials, collision, and clips.
9. Profile representative repeated use, not only an isolated asset.
10. Keep source files, generation scripts/seeds, texture sources, export settings, and provenance together.

Blender Geometry Nodes and material graphs do not automatically execute in Godot. Export evaluated geometry/instance data and bake or recreate materials. Rain simulations and cinematic lighting demonstrated in Blender must be translated into engine-native effects for interactive use.

Character quality is a separate production risk. Automated retopology and rig fitting are starting points; shoulder/elbow deformation, hands, first-person reloads, and facial expressions require visual review. A good still render is not evidence of a working game character.

## 7. Agent skills and responsibilities

Skills are task-specific instructions and scripts, not extra model subscriptions or automatic tool connections. Load only those needed for the current task.

### Installed game-development skills

| Work | Skills |
|---|---|
| Task routing | `router` |
| FPS gameplay | `fps-shooter`, `camera-systems`, `input-systems`, `physics-tuning` |
| Enemy decisions | `game-ai`; `ai-behavior-trees-utility-ai` when justified |
| World layout | `level-design`, `procedural-gen` |
| Presentation | `game-feel`, `audio-design`, `game-ui-ux`, `shader-programming` |
| Persistent progression | `save-systems`; `dialogue-systems` for authored/fallback conversations |
| Art direction | `create-game-assets` |
| Performance | `performance-optimization` |
| Godot foundation | `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups`, `godot-resources` |
| Godot 3D/runtime | `godot-3d-essentials`, `godot-physics`, `godot-animation`, `godot-shaders`, `godot-audio`, `godot-ui-control` |
| Verification/distribution | `godot-gdscript-headless-testing`, `godot-export` |

If the engine changes, replace the engine-specific set; do not combine incompatible engine APIs. Publishing skills apply only when release work is requested.

### Installed Blender skills

| Priority | Skills | Project use |
|---|---|---|
| Foundation | `blender-core`, `blender-scene-setup`, `blender-workflow-recipes` | Execution, scale, naming, collections, repeatable workflows |
| City and weapons | `blender-hardsurface-modeling`, `blender-geometry-nodes` | Modules, guns, mechanical props, procedural variation |
| Surfaces | `blender-pbr-materials`, `blender-retopology-uv`, `blender-texture-baking` | Exportable materials and efficient detail |
| Characters | `blender-character-rigging`, `blender-animation` | NPC and first-person animation |
| Production gates | `blender-asset-qa`, `blender-game-optimization`, `blender-export-pipelines` | Geometry checks, budgets, LODs, export verification |
| Scale up | `blender-pipeline-automation` | Batch conversion, inventory, and exports |
| Optional | `blender-facial-shapekeys`, `blender-sculpting` | Facial animation and organic character detail |
| Visual references | `blender-lighting-lookdev`, `blender-rendering`, `blender-time-of-day`, `blender-weather-fx` | Previews and atmosphere studies |
| As needed | `blender-simulation`, `blender-addon-development` | Baked secondary motion and reusable authoring tools |

The collection declares Blender 5.2+ compatibility. Confirm the actual Blender version and run a small environment/export check before trusting version-specific examples or bundled scripts. MCP is optional because headless execution is supported.

### Guidance still needed

- Generative NPC request lifecycle, memory/knowledge boundaries, action schema, evaluation, and provider adapters.
- Chunk streaming, stable identity, persistence, and navigation handoff.
- Project-specific modular city rules and asset budgets.
- Integrated performance checks with rendering and inference active together.

Capture these in ordinary project documentation first. Turn stable, repeatedly useful workflows into custom skills after real implementation experience; avoid installing or writing generic duplicates.

### Future `AGENTS.md`

After stack decisions, create a short root `AGENTS.md` documenting engine version, actual commands, folder responsibilities, skill routing, cost constraints, source/export rules, and verification requirements. Reference detailed documents rather than embedding every skill. Do not treat this proposal as authorization for unrelated account changes, publishing, or paid services.

## 8. Working methodology and proposed repository layout

For each feature: state the expected player behavior, implement the smallest complete behavior, verify it in isolation, integrate it with world state, and playtest it in a representative district. Keep changes recoverable through small Git commits once implementation begins. Preserve user work and avoid unrelated refactors.

Use targeted automated tests for consequential logic: ammo/state transitions, save migration, action validation, stale model responses, and chunk persistence. Use in-engine review for feel, art, animation, navigation, and loading. Headless success alone does not establish visual or gameplay quality.

Proposed layout, to create only after decisions are settled:

```text
PROPOSAL.md
AGENTS.md
game/                     # Godot project and runtime assets
  features/player/
  features/combat/
  features/npcs/
  features/dialogue/
  features/missions/
  world/                  # Districts, chunk metadata, streaming
  persistence/
  ui/
  assets/                 # Engine-facing exports and import settings
  tests/
art/                      # Editable Blender sources and texture sources
tools/blender/            # Project-owned generation/export scripts
docs/                     # Art bible, architecture, budgets, playtest records
benchmarks/               # Reproduction scenarios and recorded results
```

Keep imported engine assets separate from editable sources. Do not commit generated caches, credentials, model weights, or every temporary render. Decide binary storage policy before the repository accumulates large files.

## 9. Milestones and acceptance gates

No calendar estimates are promised before measuring throughput on representative assets and missions. Each milestone should leave a reviewable artifact and a repeatable verification scenario.

| Stage | Deliverable | Acceptance gate |
|---|---|---|
| 0. Decisions and toolchain | Hardware/platform brief; selected engine/renderer; verified Blender execution | Exact tool versions recorded; sample mesh exported and imported correctly; local inference availability established |
| 1. Integrated feasibility | Greybox FPS with one gun, enemy, two seamlessly connected chunks, NPC mission offer, one hack, a loot pickup/inventory interaction, health/healing, and save/load | Combat remains responsive during inference and traversal; no visible loading interruption between test chunks; hack, inventory, mission, health, and world state survive relevant save/unload scenarios; measured performance report |
| 2. Art and gameplay reference | Representative combat/exploration area, first-person weapon/arms, modular kit, finished NPC interaction | Consistent visuals; verified animation/materials; a complete mission loop; representative asset budgets |
| 3. World systems | District assembly, chunk streaming, persistence, navigation connections | Backtracking and boundary tests pass; named NPCs and mission objects remain consistent; no sustained memory growth across repeated traversal |
| 4. Content expansion | Continuous city expansion, weapons/rarities, hacking targets, gang encounters, missions, NPC roster | Larger-world scope delivered; every district has purpose and landmarks; repeatable generation/export pipeline |
| 5. Release candidate | Packaged builds, settings, save migration, fallback dialogue, installation guide | Target-platform testing, sustained performance run, clean-machine/local-model setup test, credits/provenance complete |

### Suggested feasibility measurements

These are starting targets to ratify against hardware, not measured results:

- Aim for 60 FPS at a documented resolution/quality preset; record median and tail frame times, not only average FPS.
- Record game-only and game-plus-inference results, memory use, provider model/quantization/context, and sustained run duration.
- On the 16 GB development machine, benchmark small quantized models before larger ones; leave explicit memory headroom for the OS, game, and tools. Start with one concurrent model request and one conversational NPC; test provider deadlines such as 15 seconds and fallback behavior explicitly.
- Measure time to first visible response and complete response; choose a user-facing latency target after comparing candidate models.
- Traverse chunk boundaries repeatedly while fighting and while a request is pending.
- Confirm hit detection respects cover, reload cannot duplicate ammo, and dead/unloaded NPCs cannot apply late actions.
- Save, fully quit, relaunch, and verify player, mission, entity, and NPC memory state.
- Benchmark an actual packaged build on target hardware before declaring performance acceptable.

If the combined test fails, first reduce active simulation, expensive effects, context/model size, and inference frequency. Reconsider renderer or engine only with evidence. Changing the larger-world goal requires a product discussion; do not silently substitute a tiny arena.

## 10. Principal risks and responses

| Risk | Response |
|---|---|
| Rendering and local inference compete for memory/compute | Combined early benchmark, bounded requests, lightweight model options, fallbacks |
| Procedural city looks repetitive or lacks purpose | Authored landmarks/routes, reusable kits, controlled variation, district-level playtests |
| Generated assets look good but fail in-game | Geometry QA, animation stress poses, export round trips, engine captures |
| Skill examples differ from installed APIs | Pin versions, inspect actual API capabilities, run small representative checks |
| NPC contradicts lore or corrupts progression | Scoped knowledge, authoritative game state, validated actions, deterministic mission fallback |
| Streaming loses state or applies late actions | Stable IDs, explicit ownership, request cancellation/generation checks, boundary regression scenarios |
| Every feature grows into a separate project | Maintain baseline and expansion lists; estimate content from measured production throughput |
| “AI-only” is interpreted as zero supervision | Agree whether existing assets/mocap are acceptable; retain human creative decisions and playtests |
| Local AI works for development but is hard to distribute | Select model licensing, installation, minimum requirements, and offline/fallback behavior before release |

## 11. Questions for the user

The initial chat answers have been incorporated. These remaining questions refine the proposed defaults; there is no need to repeat the confirmed hardware, visual style, seamless-city requirement, or no-vehicle decision.

1. Which release platforms should players use? Hardware is confirmed as an M5 MacBook Air with 16 GB RAM.
2. Which games are useful visual and gameplay references for the confirmed stylized, detailed cyberpunk direction?
3. Should this be single-player only? The seamless city, selected detailed NPC interiors, and no vehicles are confirmed. Must interior entry also be completely seamless?
4. What is the main player fantasy: mercenary jobs, faction conflict, investigation, or something else? Should gangs have reputation and hostility that persist?
5. Should generative NPCs mainly converse, or also negotiate, remember events, suggest missions, and choose high-level actions? Is voice essential?
6. Does “purely using AI” allow free existing assets and animations, or should all shipped creative assets be generated for this project? Which hacking abilities and inventory capacity model are most appealing?
7. Is this initially a personal experiment or an intended public/commercial release? How should players obtain/run the NPC model?

Do not block every activity on every answer. Hardware and visual direction are established; engine choice and release targets affect the first build. Narrative details can evolve later. Multiplayer, seamless interior entry, and mandatory voice should be settled early because they change architecture and scope.

## 12. Next action after review

Update this proposal with the user's answers, settle the engine, release targets, and remaining world-transition details, then write a focused implementation plan for Stage 0 and Stage 1. The first concrete asset is a reference modular piece; the first concrete runtime is the combined combat/streaming/NPC feasibility build. No game code, installations, or large downloads are part of this document-writing task.

## 13. References and evidence

- [Godot 3D performance guidance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html): culling, LOD, and large-world optimization context.
- [Ollama API introduction](https://docs.ollama.com/api/introduction): local and cloud endpoints; local model integration.
- [Official OpenAI pricing documentation](https://learn.chatgpt.com/docs/pricing): subscription limits and separately billed API usage.
- [Unreal licensing](https://www.unrealengine.com/license): alternative engine commercial terms.
- Installed game-development instructions: `/Users/rukithnayak/.agents/skills/router/SKILL.md` and the relevant specialized skills reviewed in this conversation.
- Installed Blender instructions: `/Users/rukithnayak/.agents/skills/blender-core/SKILL.md`, `/Users/rukithnayak/.agents/skills/blender-workflow-recipes/SKILL.md`, and specialized skills inspected locally.

The architecture, candidate content counts, milestone gates, and benchmark targets above are project recommendations. They are not claims of existing implementation or performance guarantees.
