# Hacking Subsystem Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Execute validated immediate hacks with regenerating energy and durable effects.

**Architecture:** Owns ability eligibility, costs and effect lifetimes; target adapters own local behavior, registry owns durable state. No model latency in this path. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 6](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

## Global constraints

- Source priority: detailed design is approved for Stage 0/1; proposal confirmed requirements remain binding. Where the design is more specific, use it: single-player, Godot 4.7.2 with typed GDScript, Blender 5.2 target, local Ollama HTTP, grid inventory, family-keyed ammo, regenerating hack energy, and brief interior fades. Verify installed tools rather than assuming availability.
- Preserve the larger seamless exterior city direction, selected detailed interiors, stylized detailed visuals, first-person gun combat and no vehicles. Two chunks are feasibility content, not the final city scope.
- Target environment is the user-reported M5 MacBook Air with 16 GB shared memory. Do not assert benchmarks or release platforms have been verified. No paid service, large model download, new dependency or publishing is authorized by these plans.
- Persistent IDs and domain data survive unload/save/restart; runtime Nodes remain transient. Generative output is untrusted, bounded and subordinate to deterministic gameplay authority.

## Execution and completion rules

- Read the linked source sections, this file and the prerequisite tasks only; mock adjacent services until integration tasks require them. Proposed implementation paths below do not exist yet.
- Each task is a single bounded deliverable intended for one focused worker. If a deferred expansion task is selected, first split its content batches into separately reviewable tickets; it is not permission for an open-ended production pass.
- Follow the fast prototype verification policy in [AGENTS.md](../../AGENTS.md): focused checks and a quick gameplay/asset smoke check; routine red-first testing, exhaustive edge cases and separate review are optional. Task test expectations guide risk coverage; deferred checks must be recorded honestly.
- Accept working task behavior under the fast prototype policy; record minor bugs and deferred checks without marking those checks passed. Crashes, save corruption, blocked progression and unauthorized model actions remain blockers. Keep a short report with exact commands/exits and preserve unrelated work.
- All implementation boxes start unchecked. Checking off planning documentation does not indicate game implementation is complete. Deferred Stage 2–5 work is outside the currently approved Stage 0/1 scope.

## Review focus

- Save/load failures must preserve valid live and disk state (CORE-03/04); reward replays must not duplicate inventory (INV-04, NPC-04).
- Scene unload/death/cancel must invalidate late work and preserve UUID ownership (WORLD-02/03/05, AI-04, NPC-02).
- Interrupted reload/heal and repeated callbacks must conserve ammo/items and prevent attacks while dead (PLAYER-04, INV-03).
- Prompt injection, unseen facts and invalid/stale action parameters must never mutate progression (NPC-01/04/05).
- Concurrent inference, streaming and combat must remain responsive within explicitly ratified memory/frame budgets (WORLD-06); visual/playtest evidence is required in addition to headless checks.

## Task checklist

### HACK-01: Define abilities, eligibility and energy rules

- [x] **HACK-01 — deliverable complete** (Stage 1).

**Supporting contract recorded before implementation (23 October 2026):** `HackDefinition` owns five configurable ability records; defaults are engineering/tuning values and are not approved balance: energy max 100 and regen 8/sec; DISABLE_CAMERA 20 energy / 10 sec cooldown / 8 sec duration; UNLOCK_DOOR 30 / 5 sec cooldown / permanent effect; TRIGGER_DISTRACTION 15 / 6 sec / instant; DISRUPT_IMPLANT 35 / 12 sec / 3 sec / 8 damage; DISABLE_TURRET 45 / 20 sec / 10 sec. Default range is 18 m. Each target declares its required group and implements `get_persistent_uuid()`, `can_accept_hack(definition, operator)`, and all-or-nothing `apply_hack(definition, operator)` (false must leave target state unchanged). The service checks group, stable identity, range, line of sight, cooldown, energy and target preconditions before charging; it refunds energy if target commit declines. LoS uses an injectable callable in tests and a physics ray in runtime. `HackingState` stores only energy and target/ability cooldown data, never Nodes. Add `game/features/hacking/active_hack.gd` for the already documented data contract (`target_uuid`, `hack_type`, `remaining_duration`).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/{hack_definition,active_hack,hacking_state,hacking_service}.gd`; `game/tests/hacking/test_energy.gd`; `game/tests/run_tests.gd`.

**Interfaces:** `request_hack(target_node: Node3D, hack_type: int) -> bool`; `tick_energy_regen(delta: float) -> void`; ActiveHack uses target_uuid, hack_type and remaining_duration.

- [x] **Acceptance:** Check tags, range, line of sight/access, energy, cooldown and current target state before charging. Automatic regeneration clamps to max. Costs, cooldowns and unspecified durations/damage are configurable and explicitly marked tuning values.

- [x] **Test expectations:** Test exact cost/max boundaries, insufficient energy, negative delta/cost, wrong tag, blocked/out-of-range targets and cooldown spam; rejection spends no energy.

- [x] **Evidence recorded:** [HACK-01 report](../reports/HACK-01.md); focused suite30/30, import exit0 and diff check exit0. Godot MCP reports 4.7.2. Concrete door target-adapter integration and collision traversal are verified by HACK-02; default physics-ray line-of-sight without the injected test callback remains unrun.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Five configurable definitions and transactional eligibility/energy/cooldown service implemented. Rejected eligibility requests spend no energy; failed target commits refund and do not start cooldowns. `HackingState` retains only numeric energy/cooldown data. See [report](../reports/HACK-01.md).

### HACK-02: Implement door unlock as the feasibility hack

- [x] **HACK-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_door.gd`; `game/tests/hacking/test_door.gd`.

**Interfaces:** UNLOCK_DOOR commits only eligible lock-state changes through CORE-02; emits target-state feedback for UI and navigation.

**Supporting contract (recorded before implementation):** `HackableDoor` is an authored `StaticBody3D` with a canonical UUID, a `hackable_door` group tag, an authored `mission_critical` restriction, and a child `CollisionShape3D`. Its setup binds the accepted `EntityHydrator` plus the current chunk lifecycle generation before hydration. Entity state uses only `locked` and `open` booleans; defaults are `locked=true`, `open=false`. Successful UNLOCK_DOOR atomically commits `{locked: false, open: true}` through `commit_entity_delta` and disables the blocking shape after the hydrator reprojects state. Mission-critical or already-unlocked doors reject with no energy charge. Rehydration applies the two durable flags to the projection; lifecycle interaction gating remains controlled by WORLD-03. No Nodes enter persistent state. Test fixture may construct physics bodies in code in `test_door.gd`; no reusable production scene or project integration is added.

- [x] **Acceptance:** An eligible locked door unlocks once; mission-critical restrictions are explicit. Re-hacking an unlocked door does not charge again. Collider/door traversal remains valid and unlock persists across unload.

- [x] **Test expectations:** Mock target test checks only lock state changes; in-engine fixture verifies traversal. Cover restricted door, repeat request, disappearing target and unlock/save/unload/reload.

- [x] **Evidence recorded:** [HACK-02 report](../reports/HACK-02.md); door25/25, HACK-01 energy30/30, all581, import and diff-check exit0. Godot MCP version4.7.2. Programmatic physics traversal and fresh hydration verified; no rendered capture/human playtest recorded.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `HackableDoor` commits unlock/open state through the WORLD-03 generation-bound hydrator and CORE-02 registry, rejects mission-critical/repeat requests before charge, disables its collider only after the commit, and restores traversal state after SaveStore reload and fresh projection hydration. See [report](../reports/HACK-02.md).

### HACK-03: Implement timed camera and turret effects

- [x] **HACK-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, AI-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_camera.gd`; `game/features/hacking/targets/hackable_turret.gd`; `game/tests/hacking/test_security.gd`.

**Interfaces:** DISABLE_CAMERA removes detection for configured duration; DISABLE_TURRET uses an explicitly configured neutral/friendly override and restores prior allegiance.

**Supporting contract recorded before implementation, 23 October 2026:** Camera detection is queried through a target-owned `can_detect_target(Node3D)` API that checks enabled state, exported FOV/range, and live physics line-of-sight. Camera effect duration uses its `HackDefinition` data (current tuning default 8 seconds). Turret effect duration uses the definition (current tuning default 10 seconds); the scene must explicitly configure the temporary mode as neutral or friendly before the target can accept a hack. Neutral never selects targets; friendly selects factions currently hostile to the player via live `FactionRules`. After expiry, normal hostility is recomputed from `FactionState`, so standing changes during the effect are preserved. Active effects reject reapplication; HackingService cooldowns also reject requests until elapsed. Targets destroyed during an effect do not restore or mutate external faction state. Durations/modes are configurable tuning, not approved balance. Effects remain transient until HACK-05.

- [x] **Acceptance:** Camera/turret durations use explicit HackDefinition values (8/10 seconds), and turret nodes require an explicit neutral/friendly mode. Reapplication is rejected during an active effect and by the configured cooldown. Expiry recomputes current faction hostility; target destruction cancels the temporary projection without writing faction state.

- [x] **Test expectations:** Deterministically advanced effect time through start/expiry; verified camera FOV/physics occlusion and suppression, neutral/friendly turret targeting, reapply rejection, target destruction, and faction standing changes during an effect. No faction mutation is performed by the target adapters.

- [x] **Evidence recorded:** [HACK-03 report](../reports/HACK-03.md); `hacking_security`23/23, `hacking_door`25/25, `hacking_energy`30/30, integrated `all`771/771, import and diff check exit0. Integrated shutdown still emits one ObjectDB and one physics-body RID leak warning. Godot MCP confirmed 4.7.2; no target scene exists for visual review yet. HACK-06 owns representative world scenarios.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Target scripts provide queried camera detection and temporary turret allegiance modes, with HackingService eligibility/cost/cooldown handling. Timed effects are runtime-only pending HACK-05. See [report](../reports/HACK-03.md).

### HACK-04: Implement distraction and implant disruption

- [x] **HACK-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-01, AI-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/targets/hackable_distraction.gd`; `game/features/hacking/targets/hackable_implant.gd`; `game/features/npcs/perception.gd`; `game/features/npcs/tactical_agent.gd`; `game/tests/hacking/test_combat_hacks.gd`.

**Interfaces:** TRIGGER_DISTRACTION emits AI-01 sound/investigation events; DISRUPT_IMPLANT invokes AI stun and normal damage services.

**Supporting scope recorded before implementation, 23 October 2026:** Register `NpcPerception` instances in the `npc_perception` runtime group so a distraction target can broadcast to nearby listeners without owning their Nodes. Add a small `TacticalAgent.can_accept_implant_disruption()` query so the target can reject dead, unloaded, or already-stunned agents before any mutation. Preserve AI-01's distance-only sound radius (walls do not block it) and AI-02's normal health/stun ownership. Damage source faction and sound radius are per-target authored tuning; no persistent Node references are added.

- [x] **Acceptance:** Distraction affects eligible listeners at target location. Implant disruption applies the specified 3-second stun and configurable minor damage; interruptions cannot duplicate damage or allow attacks during stun.

- [x] **Test expectations:** Tested a guard behind cover investigating at the distraction source, sound radius gating, cooldown/repeated callback, active attack interrupted by implant disruption, exact 3-second stun under a controlled clock, damage deduplication, and dead target rejection. Reload interruption is not applicable because AI-02 has no reload substate.

- [x] **Evidence recorded:** [HACK-04 report](../reports/HACK-04.md); focused combat19/19, AI states32/32, AI perception20/20, HACK energy30/30, door25/25, security23/23, all790/790; import exit0. Full integrated suite retains the known ObjectDB and physics-body RID shutdown warnings. See report for exact commands and results.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Distraction broadcasts are decoupled through the runtime listener group and preserve AI-01 distance-only sound semantics. Implant disruption delegates damage and timed stun to AI-02, rejecting invalid targets before mutation. See [report](../reports/HACK-04.md).

### HACK-05: Persist effects and present target feedback

- [x] **HACK-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** HACK-02, HACK-03, HACK-04, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/hacking/{hack_snapshot,hacking_service}.gd`; `game/features/hacking/targets/{hackable_camera,hackable_turret,hackable_implant}.gd`; `game/ui/{hacking_hud.gd,hacking_hud.tscn}`; `game/tests/hacking/test_effect_persistence.gd`; coordinated test-runner registration.

**Interfaces:** Use CORE-04’s documented timed-effect clock policy and WORLD-01 lifecycle events; HUD reads eligibility/effect events.

**Supporting contract recorded before implementation, 23 October 2026:** CORE-04 `domains.active_hacks` is owned by a data-only `HackSnapshot` API with `capture_domain`, `prepare_domain`, and `commit_domain` callbacks suitable for composition with the existing CORE-04 `SnapshotAdapters`; records contain only canonical target UUID, ability ID, remaining seconds, and owning chunk ID. Existing permanent UNLOCK_DOOR flags remain authoritative in the target's EntityRegistry record and are not duplicated in the hack domain. The runtime effect owner keeps Node references only in a separate weak-reference projection cache. It receives WORLD-01 `chunk_pre_unload`/`chunk_activated` events, pauses effect time while a chunk is inactive, and requires a freshly hydrated target with a matching UUID before reapplying a saved remainder; stale or missing targets are discarded without delayed mutation. Active time advances only from the gameplay simulation tick; offline time never advances. HackingService optionally records timed hacks after a target commit and offers a side-effect-free status query. HackingHUD presents that query and service result/rejection signals, including a visible provider-offline state. Display cost, cooldown and duration values are existing configurable tuning defaults, not approved balance.

- [x] **Acceptance:** Permanent UNLOCK_DOOR flags remain in the existing EntityRegistry save path; timed camera/turret/implant effects persist only as target UUID, ability ID, remaining seconds and chunk ID. WORLD-01 unload pauses duration; CORE-04 SaveStore reload resumes it on a same-UUID projection, and mismatched-chunk targets do not receive the effect. HackingHUD displays eligibility, cost, cooldown, duration, commit/rejection, and provider-offline state.

- [x] **Test expectations:** Saved mid-effect through CORE-04 SaveStore, reloaded into same and fresh snapshot owners, verified unload pause/re-entry, cleanup on expiry, rejection for a mismatched chunk projection, and no Nodes in saved domain data. HUD feedback and provider failure are covered in-engine/headlessly. Human combat readability remains at WORLD-06.

- [x] **Evidence recorded:** [HACK-05 report](../reports/HACK-05.md); `hacking_effects`29/29 and integrated `all`819/819, both exit0; import exit0; Godot MCP scene launch had empty errors after a HUD warning fix. Existing ObjectDB/physics RID shutdown warnings remain in the integrated runner.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `HackSnapshot` provides CORE-04 domain callbacks, data-only timed records and weak runtime projection bindings; WORLD-01 chunk events pause/resume the active simulation clock. HackingHUD consumes a side-effect-free HackingService status query and its result signals. Permanent unlock truth remains in existing entity state. See [report](../reports/HACK-05.md).

### HACK-06: Author representative hacking encounter scenarios

- [x] **HACK-06 — deliverable complete** (Stage 1; added at the user's request on 23 October 2026).

**Dependencies / sequencing:** HACK-02, HACK-03, HACK-04, HACK-05, AI-03, WORLD-03, ASSET-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/world/fixtures/hacking/{stealth_route,security_corridor}.{tscn,gd}`; shared `game/world/fixtures/hacking/hacking_encounter_base.gd`; `game/tests/world/test_hacking_scenarios.gd`; coordinated test-runner registration.

**Interfaces:** Compose existing target, AI, player, navigation and asset contracts. Do not add a second source of gameplay truth or persistent Node references. These are Stage 1 representative scenarios, not the final district/city content.

**Supporting contract recorded before implementation, 23 October 2026:** `stealth_route` is a neon-market maintenance alley with an obvious camera-covered approach, a durable service-door shortcut, and a physical outer bypass that remains walkable without hacking; `security_corridor` is a visually separate corporate transit/security spine with a turret-covered crossing, concrete cover/flank, guard distraction device and implant target. Each fixture owns a stable chunk ID, authored UUIDs, approach/player markers, floor/walls/collision and its service setup; it binds door persistence through the existing EntityRegistry/EntityHydrator and hacking effects through the existing HackingService/HackSnapshot. Geometry uses existing ASSET-03 reference meshes plus engine-authored structural blocks/signage/emissive lighting; no model downloads, new Blender assets or persistent Node references. Route checks exercise the authored route graph and actual blocking geometry. These are focused Stage 1 encounter samples only; the large continuous walkable city and distinct districts remain the project direction and later production scope.

**Implementation clarification recorded before coding:** Both fixtures subclass a shared `HackingEncounterBase` that owns repeated scene construction and setup of accepted managers/services; each fixture keeps its layout, route markers and visual palette authored in its own scene script. This avoids duplicated lifecycle/configuration glue while keeping the encounter layouts independently editable.

- [x] **Acceptance:** Provide at least two visually distinct cyberpunk security encounters. The stealth route uses camera surveillance and an eligible locked-door shortcut with a viable un-hacked route; the security corridor uses a turret-covered crossing with nearby cover/flanking and an enemy implant/distraction opportunity. Targets are reachable and visible from natural approach points, hacking each has a clear tactical consequence, and a no-hack/resource-depleted route remains possible. Preserve room for later distinct districts and larger continuous-city content.

- [x] **Test expectations:** Loaded both scenes and verified target UUIDs/tags/range/line-of-sight, route reachability, guard response to distraction/implant disruption, and timed camera/turret effect consequences. Rendered scene captures are recorded; detailed human free-walk/combat readability playtest is deferred to WORLD-06.

- [x] **Evidence recorded:** [HACK-06 report](../reports/HACK-06.md); `hacking_scenarios`24/24 and integrated `all`843/843 exit0; import and diff check exit0; Godot MCP launched both scenes with no runtime errors. Existing AI script-shadowing warnings and integrated shutdown leaks are noted in the report.


Accepted 23 October 2026 (Asia/Kolkata), Main Agent. The neon-market alley combines a camera-covered shortcut with a verified maintenance bypass; the corporate transit spine combines a turret crossing with cover, flank, distraction and implant tactics. Both preserve the larger continuous cyberpunk city direction. Human encounter playtest remains at WORLD-06. See [report](../reports/HACK-06.md).

### HACK-07: Integrate district hacking routes in Night Market

- [ ] **HACK-07 — deliverable complete** (Stage 2; specifically approved 24 October 2026).

**Dependencies / sequencing:** HACK-06, WORLD-05, ASSET-03 and the approved Night Market neighborhood design.

**Files / ownership:** District-owned target instances and encounter setup under `game/world/districts/night_market/`; focused fixture/tests coordinated with WORLD-08; `docs/reports/HACK-07.md`.

**Interfaces:** Compose existing HackingService, HackableDoor, camera, turret/distraction/implant effects, entity persistence and navigation contracts. No second state owner.

- [ ] **Acceptance:** Market district contains a visible surveilled approach, a detailed hackable service-door shortcut, an alternate walkable bypass, and at least one additional reachable utility/security target with a distinct existing hacking consequence. Every encounter remains navigable without hacking or when energy is depleted.
- [ ] **Test expectations:** Verify target UUID/lifecycle state, distance/line of sight, route reachability, effect consequence, bypass, and save/unload/reload. If a route requires new hacking behavior, add a separate bounded task before expanding capability.
- [ ] **Evidence recorded:** Record focused tests, in-engine screenshots, manual route notes and report.
