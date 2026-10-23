# Master Progress

**Updated:** 23 October 2026 (Asia/Kolkata)  
**Overall status:** Stage 0/1 implementation in progress. CORE-01/02/03/04, WORLD-01/02, PLAYER-02 and ASSET-01/02 accepted. WORLD-03 is next eligible; ASSET-03 and PLAYER-01 retain unassigned partial handoffs. Blender/Godot MCP tools are active; no worker is left running.  
**Evidence:** [CORE-01 report](reports/CORE-01.md) and [fresh toolchain checks](toolchain.md). Minimal Godot scaffold and test harness now exist; gameplay and integrated gates remain incomplete.

## Source and scope

This plan uses [proposal](proposal.md) and [detailed design](detailed_design.md), which correspond to the requested proposal and detailed-design documents despite their different filenames. The detailed design names eight modules and approves Stage 0/1 implementation. It settles earlier proposal questions on engine/language, single-player, grid capacity model, family ammo, interior fades, regenerating hacking energy and text-first NPCs with generation blips.

The proposal’s confirmed requirements remain in scope. Candidate city/weapon/role counts, rarity tuning and later milestones are not silently promoted into commitments. The task files include deferred expansion outlines for coverage; split and approve these before executing Stage 2–5 work. These documents plan implementation; they do not execute it or authorize installations, downloads or publishing.

## Checklist semantics and completion gate

- A module checkbox means the **entire module** is complete, including its approved expanded scope, passing task acceptance/tests and applicable integration evidence. All module boxes remain unchecked; Stage 1 completion alone does not complete a module.
- Each task file has separate deliverable, acceptance, test and evidence checkboxes. Keep them unchecked until demonstrated. Record worker/commit/evidence and update this tracker when work changes state.
- Overall implementation is complete only when every module and release acceptance gate is complete for the explicitly agreed final scope. A deferred task can be removed only through a recorded scope decision, never by checking it as done.

- [ ] **Overall implementation complete:** all eight module gates and the acceptance gates for the agreed release scope are satisfied.

## Module status and task index

- [ ] **[Core State & Persistence Registry](tasks/core-state-persistence.md) — entire module complete.** Status: in progress. Stage 0/1: 4/5 tasks; deferred: 1 outline(s).
  Task IDs: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06.

- [ ] **[World & Scene Manager](tasks/world-scene-manager.md) — entire module complete.** Status: in progress. Stage 0/1: 2/6 tasks; deferred: 1 outline(s).
  Task IDs: WORLD-01, WORLD-02, WORLD-03, WORLD-04, WORLD-05, WORLD-06, WORLD-07.

- [ ] **[Player, Health & Combat Core](tasks/player-health-combat.md) — entire module complete.** Status: in progress. Stage 0/1: 1/5 tasks; deferred: 1 outline(s).
  Task IDs: PLAYER-01, PLAYER-02, PLAYER-03, PLAYER-04, PLAYER-05, PLAYER-06.

- [ ] **[Inventory & Equipment](tasks/inventory-equipment.md) — entire module complete.** Status: not started. Stage 0/1: 0/5 tasks; deferred: 1 outline(s).
  Task IDs: INV-01, INV-02, INV-03, INV-04, INV-05, INV-06.

- [ ] **[Faction & Tactical AI](tasks/faction-tactical-ai.md) — entire module complete.** Status: not started. Stage 0/1: 0/5 tasks; deferred: 1 outline(s).
  Task IDs: AI-01, AI-02, AI-03, AI-04, AI-05, AI-06.

- [ ] **[Hacking Subsystem](tasks/hacking-subsystem.md) — entire module complete.** Status: not started. Stage 0/1: 0/5 tasks; deferred: 0 outline(s).
  Task IDs: HACK-01, HACK-02, HACK-03, HACK-04, HACK-05.

- [ ] **[Generative NPC & Mission Orchestrator](tasks/generative-npc-mission-orchestrator.md) — entire module complete.** Status: not started. Stage 0/1: 0/6 tasks; deferred: 1 outline(s).
  Task IDs: NPC-01, NPC-02, NPC-03, NPC-04, NPC-05, NPC-06, NPC-07.

- [ ] **[Offline Asset Pipeline](tasks/offline-asset-pipeline.md) — entire module complete.** Status: in progress. Stage 0/1: 2/4 tasks; deferred: 2 outline(s).
  Task IDs: ASSET-01, ASSET-02, ASSET-03, ASSET-04, ASSET-05, ASSET-06.

## Completed work

- [x] Read the proposal and detailed design; identify the eight module boundaries and resolved versus open decisions.
- [x] Create one task file per module, with acceptance criteria, test expectations, dependencies, proposed file ownership and completion checklists.
- [x] Define shared sequencing, integration gates and initial status tracking.
- [x] Validate local links, unique task IDs, per-task acceptance/test/evidence fields, unchecked implementation/module status and an acyclic dependency graph.
- [x] CORE-01 accepted: Godot pin, typed test harness, native launch and toolchain evidence; no gameplay/performance acceptance.
- [x] CORE-04 accepted: data-only migration/adapters, opaque-record preservation and clock policy; Main Agent regression fix red→green, migrations 22/22 and integrated all 142/142. [Report](reports/CORE-04.md).
- [x] WORLD-02 accepted: callback invalidation/budget and native request-token fixes, focused 42/42, integrated 184/184, real physics and Godot MCP rendered traversal/captures. [Report](reports/WORLD-02.md).

## Task ledger

| Task | Stage / dependencies | Status | Owner / model | Owned paths | Change reference | Evidence / blocker / next action |
|---|---|---|---|---|---|---|
| TOOL-01 | 0 / explicit user connection repair | complete; native activation verified | Main Agent / session model | user Codex Blender MCP entry, isolated MCP environment, docs/tasks/tooling-connections.md, docs/reports/TOOL-01.md | working tree / user configuration | Native Blender MCP call succeeded 23 October 2026: 5.2.3 LTS, scene preserved; evidence/WORLD-02/blender-mcp-probe.json; Godot MCP also active at 4.7.2 |
| CORE-01 | 0 / none | complete | Main Agent / session model | AGENTS.md, .gitignore, game/project.godot, game/tests/, docs/toolchain.md | working tree | Accepted; sample/all 2/2, intentional fail 1, unknown 2, import/native launch 0; reports/CORE-01.md |
| CORE-02 | 1 / CORE-01 | complete | registry / gpt-6-luna medium | game/persistence/{entity_registry,faction_state}.gd, game/tests/persistence/test_registry.gd, docs/state-contracts.md | working tree | Accepted 39/39; independent review clean; reports/CORE-02-worker.md |
| PLAYER-01 | 1 / CORE-01 | partial; unassigned | historical player_controller assignment; no live worker | game/features/player/{player_controller,input_settings}.gd, player.tscn, game/tests/scenes/player_movement.tscn, game/tests/player/test_controller.gd | working tree | test_controller.gd exists; controller/settings/player scene and movement fixture absent; preserve test and resume later |
| PLAYER-02 | 1 / CORE-02 | complete | Main Agent / session model | game/features/player/health_state.gd, game/tests/player/test_health.gd | working tree | Accepted 19/19 focused, all 60/60; reports/PLAYER-02.md |
| WORLD-02 | 1 / WORLD-01, CORE-01 | complete | Main Agent / session model; bounded reviewer world02_review / gpt-6-luna medium | game/world/chunk_loader.gd, game/tests/world/test_chunk_loader.gd; coordinated runtime fixture, runner integration and contracts | working tree on codex/stage-0-readiness | Accepted 23 October 2026; callback red6 and native-token red2 fixed; focused42/all184, physics7, rendered10; reports/WORLD-02.md |
| WORLD-01 | 1 / CORE-02 | complete | world_manifest / gpt-6-luna medium | game/world/{chunk_manifest,world_manager}.gd, game/world/fixtures/chunk_{a,b}.tscn, game/tests/world/test_manifest.gd | working tree | Accepted 37/37 after red6 review fixes; reports/WORLD-01-worker.md |
| CORE-04 | 1 / CORE-03 | complete | Main Agent / session model; historical worker metadata unverified | save_migrations.gd, snapshot_adapters.gd, test_migrations.gd, state-contracts migration section; coordinated registry/faction snapshot APIs, save migration hook and runner integration | working tree on codex/stage-0-readiness | Accepted 23 October 2026; rejected-migration false success fixed red→green; migrations 22/22, all 142/142, import/sample exit 0; reports/CORE-04.md |
| CORE-03 | 1 / CORE-02 | complete | save_store / gpt-6-luna medium | game/persistence/save_store.gd, game/tests/persistence/test_save_store.gd, docs/state-contracts.md save envelope | working tree | Accepted 23/23; independent review clean; reports/CORE-03-worker.md |
| ASSET-03 | 0 / ASSET-02, CORE-01 | partial; unassigned | historical asset_export assignment; no live worker | tools/blender/export_modular_kit.py, game/assets/reference/, game/tests/scenes/asset_roundtrip.tscn, docs/asset-roundtrip.md | working tree | exporter, GLBs, maps and metadata exist; fixture/report absent; repeatability/visual acceptance unverified; native Blender MCP now available; sources untouched during WORLD-02 |
| ASSET-02 | 0 / ASSET-01 | complete | reference_assets / gpt-6-luna medium | art/reference/{wall_doorway,mechanical_prop}.blend, tools/blender/build_reference.py, docs/art-reference.md, docs/evidence/ASSET-02/ | working tree | Accepted all four QA checks exit 0, visual review; reports/ASSET-02-worker.md |
| ASSET-01 | 0 / none | complete | asset_readiness / gpt-6-luna medium | docs/asset-pipeline.md, tools/blender/check_environment.py, art/reference/, docs/asset-provenance.md | working tree | Accepted; export, QA, structural Godot import exit 0; reports/ASSET-01-worker.md |

Main Agent exclusively owns shared toolchain/tracker/configuration and acceptance updates. The repository began without commits; all existing source documents and partial handoffs were preserved. On 23 October 2026 the user authorized committing the entire project snapshot and pushing the current `codex/stage-0-readiness` branch to `https://github.com/RukithNayak/cyberpunk-3d-game`. Integrated all passes 184 checks, including accepted migrations and chunk loading; the pre-commit rerun also passed 184/184, exit 0. PLAYER-01 remains outside all pending its task acceptance. Work occurs in the supplied workspace; ignored caches, credentials and model weights remain excluded.

## Dependencies and recommended sequence

| Wave | Eligible work | Exit / sequencing rule |
|---|---|---|
| 0 — readiness | CORE-01 and ASSET-01 | Verify actual tools; record unavailable prerequisites. No bulk assets or model downloads. |
| 1 — contracts/reference | CORE-02 → CORE-03 → CORE-04; ASSET-02 → ASSET-03 | Publish state, save, faction, lifecycle and time contracts before dependent implementations. ASSET-03 also needs CORE-01. |
| 2 — isolated features | WORLD-01/02; PLAYER-01/02/03; INV-01/02/03; AI-01/02/03; HACK-01; NPC-01/02/03; ASSET-04 | Follow each task’s specific dependencies; use mocks/fixtures, not whole-system imports. PLAYER-04 needs INV-03; INV-03 needs PLAYER-02, avoiding a combat/inventory cycle. |
| 3 — stateful integration | WORLD-03/04; INV-04/05; PLAYER-04/05; AI-04 → WORLD-05 → AI-05; HACK-02/03/04/05; NPC-04/05/06 | WORLD-05 uses AI-03 and requires AI-04’s unload record contract for final acceptance. NPC-04 consumes INV-04 grants; no mission/inventory reverse dependency. |
| 4 — checkpoint and feasibility | CORE-05 → WORLD-06 | Cross-system context is confined to checkpoint restoration, navigation handoff and the combined feasibility gate. All direct prerequisites in WORLD-06 must pass first. |
| Later — scope dependent | CORE-06, WORLD-07, PLAYER-06, INV-06, AI-06, NPC-07, ASSET-05/06 | Approve content/targets, decompose each outline into small tickets, then execute. Do not create an entire city before feasibility evidence. |

WORLD-02 is accepted; its read-only reviewer has finished, and no task/worker is left active at this handoff. Other prior worker names identify historical assignments. Exact dependencies in each task take precedence over this wave summary. Preserve unaccepted player/asset files until their bounded review or resumption.

## Milestone checklists

- [ ] **Stage 0 — decisions/toolchain:** CORE-01 and ASSET-01/02/03 complete; exact versions verified, sample actual mesh round-trips, local inference availability/model inventory recorded, and remaining renderer/platform risks documented. An unavailable required runtime remains a blocker rather than an assumed pass.
- [ ] **Stage 1 — integrated feasibility:** all tasks marked Stage 1 complete; WORLD-06 provides combined combat/traversal/inference, state-restoration, fallback, packaged-build and human playtest evidence. Memory/frame/latency acceptance thresholds must be recorded before assessing performance.
- [ ] **Stage 2 — art/gameplay reference (deferred):** reviewed kit, first-person animation, NPC interaction, complete mission loop and asset budgets.
- [ ] **Stage 3 — world systems (deferred):** approved district layouts, reliable backtracking/navigation/persistence and bounded sustained memory.
- [ ] **Stage 4 — content expansion (deferred):** approved walkable city, weapons, rarity, hacking, encounter, mission and named-NPC scope delivered.
- [ ] **Stage 5 — release candidate (deferred):** target exports, compatibility saves, clean-machine model/fallback setup, credits/licenses and sustained packaged-build evidence.

## Blockers and risks

| Issue | Status / impact | Owner task and response |
|---|---|---|
| Tool availability/version discrepancy | Godot 4.7.2 and Blender 5.2.3 freshly verified. Godot import/native launch pass. Blender smoke succeeds with approved sandbox escalation; geometry QA and structural Godot import pass. | CORE-01 / ASSET-01 verify actual executables and smoke tests; record blockers without installing or downloading implicitly. |
| Model availability, license and distribution | Ollama 0.40.8 installed; HTTP endpoint refuses connection (exit 7). Four local manifests inventoried; no inference/license validation. Real-provider acceptance pending; mock/fallback development remains eligible. | CORE-01 inventories existing models; NPC-06 evaluates suitable available weights; NPC-07 covers approved distribution. |
| Shared 16 GB memory and thermal budget | Rendering, tools and inference compete. 60 FPS is proposed; no renderer, sustained memory headroom or latency threshold has been proved. | ASSET-04 proposes measured asset/renderer limits; WORLD-06 records and ratifies combined limits before pass/fail. |
| Model action authority | Design adds give_item, faction admission and combat actions beyond the proposal’s narrow examples. Blind execution would corrupt progression. | NPC-04 supports these only through authored permissions, existing IDs, bounded rewards and idempotent grants; unconfigured actions reject. |
| Chunk/navigation/state ownership | Boundary races can duplicate NPCs, lose loot or apply stale dialogue/hacks. | WORLD-02/03/05, AI-04, HACK-05 and NPC-02 verify lifecycle generations, stable IDs and unload behavior. |
| Incomplete numeric gameplay contracts | Faction thresholds, grid dimensions, hack costs/cooldowns/security durations and loot bounds are unspecified. | Owning CORE-02, INV-01/02 and HACK-01/03 tasks publish explicit configurable values as tuning defaults, with boundary tests; do not label them approved balance. |
| Release/content decisions | Platforms, final accessible city size, visual references, economy and model delivery remain open. Not a blanket blocker for Stage 0/1. | Record decisions before WORLD-07 and later content tickets. Detailed design settles single-player/interior fades; do not reopen them as prerequisites. |
| Asset/character production | Exported materials, rigs and free-source licensing may fail despite appealing still images. | ASSET-01/03/05 require provenance, round-trip captures, geometry QA and animated deformation review. |

## Next recommended task

**WORLD-03 — Hydrate and unload persistent entities** in [World & Scene Manager](tasks/world-scene-manager.md). WORLD-02 and CORE-04 are accepted. Start with bounded ownership of `game/world/entity_hydrator.gd` and `game/tests/world/test_chunk_persistence.gd`; consume the registry/snapshot and generation-tagged lifecycle contracts. Observe failing door/loot/NPC unload/reload regressions before implementation; register any suite with Main Agent coordination.

ASSET-03 remains an alternative eligible partial task: preserve the existing exporter/assets, complete repeatability and in-engine fixture/evidence under the applicable Blender skills. Native Blender 5.2.3 and Godot 4.7.2 MCP calls now succeed. CORE-05 is blocked by unfinished PLAYER-04, INV-04, NPC-05 and HACK-05. Do not install tools or download models implicitly.

## Session decisions and active next steps

- CORE-01 accepted 23 October 2026; working-tree change; reviewer gpt-6-luna medium found no material issue. CORE-02 is now dependency-ready.
- Initial Git branch creation was sandbox denied; approved escalation then created codex/stage-0-readiness. Existing untracked docs preserved; no initial commit made.
- Blender worker sandbox startup crashed before Python; Main Agent repeated outside sandbox successfully (exit 0, 1,648-byte GLB). ASSET-01 accepted after QA, contact-sheet review and structural Godot import. ASSET-02 now eligible.

- ASSET-01 accepted 23 October 2026 (Asia/Kolkata), worker gpt-6-luna medium, Main Agent reproduction. Export/QA/structural import pass; production reference/visual roundtrip remain ASSET-02/03.

- CORE-02 accepted 23 October 2026 (Asia/Kolkata), 39/39 focused checks, worker/reviewer gpt-6-luna medium. Main integrated registry into all (41/41, exit 0). CORE-03 eligible; no new gameplay balance commitments.

- PLAYER-02 accepted 23 October 2026 (Asia/Kolkata), Main Agent; 19/19 focused after 11 expected red failures, integrated all 60/60. PLAYER-01 still eligible; no consumer may infer movement/combat acceptance.

- WORLD-01 review (gpt-6-luna medium) found synchronous pre-unload publication and generation-reuse defects. Initial review held the task in progress; fixes subsequently passed 37/37 and re-review. WORLD-02 was unlocked only after acceptance.

- CORE-03 accepted 23 October 2026, 23/23 focused checks reproduced; worker/reviewer gpt-6-luna medium found no material issue. CORE-04 now eligible. Callback consumer atomicity must be proved in adapters/integration.

- CORE-04 supporting integration scope recorded before coding: expose copy snapshot/validated replacement APIs in registry/faction and connect migration hook in SaveStore if needed; this serves the existing adapter acceptance, not new gameplay scope. Main authorized exclusive writes to these shared persistence files for the CORE-04 worker.

- WORLD-01 accepted 23 October 2026 after 37/37 reproduction, independent review clean following six red regression failures. WORLD-02 eligible; authorized supporting integration in world_manager.gd/world-contracts.md as existing loader handoff scope.

- ASSET-02 accepted 23 October 2026; two editable references, all four QA runs reproduced, visual review and hashes verified. Accepted warning categories: flat cap n-gons and hidden opposite-facing closed assembly contacts. Provisional art/budgets remain proposals. ASSET-03 now eligible.

- Resume reconciliation, 23 October 2026 (Asia/Kolkata): historical worker assignments are inactive. WORLD-02 has implementation/tests/report awaiting review; ASSET-03 has exporter/generated assets but no round-trip fixture/report; PLAYER-01 has a test but lacks implementation and fixture. Preserved all partial source files; no delegation or scope expansion.
- CORE-04 accepted 23 October 2026, Main Agent / session model. Existing handoff verified at 21/21; new false-success regression failed at 22 checks/one failure (exit 1), then passed 22/22 after SaveStore rejected `ok: false, error: OK`. Unknown-root ownership contract documented; migration suite included in all (142/142, exit 0). Import and sample exit 0. [Report and review](reports/CORE-04.md), [command/exit manifest](evidence/CORE-04/verification.json). Next: WORLD-02 review; WORLD-03 remains blocked until that acceptance. No visual/performance or real gameplay-domain integration claimed.

- WORLD-02 accepted 23 October 2026 (Asia/Kolkata), Main Agent with bounded reviewer gpt-6-luna / medium. Preserved baseline 33/33; callback generation/recursive-budget regressions red6→green, native retry/cancel token regressions red2→green. Final focused42/all184, import/sample/physics exit0; expected unknown/malformed2 and deliberate1. Real capsule support/traversal verified headless7 and rendered10 at 960×540 Compatibility via Godot MCP; three captures inspected. [Report](reports/WORLD-02.md), [review](reports/WORLD-02-review.md), [commands/exits](evidence/WORLD-02/verification.json). WORLD-03 is now eligible. No sustained performance, navigation/hydration, production player feel or human playtest gate accepted.
- TOOL-01 activation follow-up: native Blender MCP environment query succeeded (5.2.3 LTS, current scene unchanged). Godot MCP version/project/runtime calls also succeeded. Existing asset/player partial files were preserved, and no new dependency or software installation occurred in this implementation task.
