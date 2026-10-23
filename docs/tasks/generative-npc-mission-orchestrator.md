# Generative NPC & Mission Orchestrator Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for inline implementation, or `superpowers:subagent-driven-development` if subagent execution is explicitly selected. Steps use checkbox syntax for tracking.

**Goal:** Provide asynchronous local dialogue and code-validated mission/action execution with reliable fallbacks.

**Architecture:** Provider generates text/proposals only. Mission director owns objectives/rewards; inventory and faction services validate changes. NPC factual knowledge is bounded and scoped. Keep data and presentation separate; integrate through the contracts named below.

**Tech Stack:** Godot 4.7.2 / typed GDScript; Blender 5.2 for offline assets; local Ollama HTTP for inference.

**Spec:** [Proposal](../PROPOSAL.md), [detailed design — module 7](../detailed_design_document.md); shared sequencing/status: [master progress](../master-progress.md).

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

### NPC-01: Define response schema, context and mock provider

- [ ] **NPC-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/provider.gd`; `game/features/dialogue/mock_provider.gd`; `game/features/dialogue/context_snapshot.gd`; `game/features/dialogue/response_validator.gd`; `game/tests/dialogue/test_schema.gd`.

**Interfaces:** ContextSnapshot includes NPC identity, scoped facts, bounded memory, eligible templates and standing; LLMResponse contains dialogue_text and proposed_action. Provider publishes completion with NPC/conversation/request-generation IDs.

- [ ] **Acceptance:** Enforce explicit JSON types, size limits and action allowlist. Mock provider emits deterministic valid, delayed and invalid responses. Schema recognizes all six detailed-design actions but cannot directly execute them. Document limits as configurable engineering defaults.

- [ ] **Test expectations:** Inject broken JSON, huge text/body, missing/unknown keys, incorrect types, unknown actions and invalid parameters. Assert no gameplay state changes from parsing or prompt-injected commands.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-02: Implement asynchronous Ollama lifecycle and fallback

- [ ] **NPC-02 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-01, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/ollama_provider.gd`; `game/features/dialogue/dialogue_orchestrator.gd`; `game/tests/dialogue/test_requests.gd`.

**Interfaces:** `submit_dialogue_request(npc_id: String, prompt: String) -> void`; `_on_http_response_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void`.

- [ ] **Acceptance:** Use non-blocking HTTP, initially one concurrent request and bounded context/queue. Use configurable 15-second initial deadline; timeout, HTTP error, missing model/provider or invalid output routes to authored fallback. Cancel/increment generations on walk-away, death, unload and conversation replacement; late/duplicate responses do nothing.

- [ ] **Test expectations:** Fake provider/clock tests cover offline, 4xx/5xx, timeout, malformed body, reordered/duplicate replies, model switch and queue saturation. Assert main-loop progress during pending requests, fallback once and zero stale action commits.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-03: Build deterministic mission offers and lifecycle

- [ ] **NPC-03 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-01, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/missions/mission_director.gd`; `game/features/missions/mission_template.gd`; `game/tests/missions/test_lifecycle.gd`.

**Interfaces:** `offer_mission(template_id)` proposes an existing eligible template; director creates stable mission/target/reward IDs and owns offered/accepted/active/completed/failed transitions.

- [ ] **Acceptance:** Implement one retrieval template against existing reachable fixtures and authored fallback offer. Validate eligibility, target existence/reachability, faction rules and reward bounds. Offers/accepted jobs survive provider failure and chunk unload; code alone validates objectives.

- [ ] **Test expectations:** Test missing/unreachable target, forbidden faction, invalid reward, repeated offer/accept/complete and failed objectives. Persist each lifecycle state; model text claiming completion cannot change progress.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-04: Add guarded deterministic action dispatch

- [ ] **NPC-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-02, NPC-03, INV-04, AI-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/action_dispatcher.gd`; `game/tests/dialogue/test_actions.gd`; `docs/npc-action-policy.md`.

**Interfaces:** Handle `offer_mission(template_id)`, `initiate_trade(inventory_id)`, `accept_into_faction(faction_id)`, `begin_fight()`, `disclose_fact(fact_id)`, `give_item(item_id)` using current-state eligibility and idempotent transaction IDs.

- [ ] **Acceptance:** Authoritative code rechecks actor validity, permission and preconditions immediately before commit. Trades reference allowed merchant stock; faction acceptance needs an authored eligibility rule; fighting requires a permitted live NPC transition; facts must be known/disclosable; items require a preauthorized quest/reward entitlement. Unsupported/unconfigured actions reject safely. Model cannot invent items, rewards, factions or executable code.

- [ ] **Test expectations:** Inject invented IDs, reward inflation, unauthorized faction acceptance/hostility, stale eligibility and duplicated responses. Assert zero unauthorized mutations and one reward on replay; full inventory preserves entitlement. Exercise allowed and rejected cases for each of the six actions.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-05: Persist scoped knowledge and bounded memory

- [ ] **NPC-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-03, NPC-04, CORE-04, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/npc_memory.gd`; `game/features/dialogue/dialogue_snapshot.gd`; `game/tests/dialogue/test_memory.gd`.

**Interfaces:** Store factual events separately from derived summaries; registry holds stable NPC, conversation, mission and action transaction IDs.

- [ ] **Acceptance:** Only witnessed/legitimately disclosed facts enter context. Summaries cannot overwrite missions or world truth; bound history/context size and log auditable commits. Restore knowledge, relationships, offers and memories after unload/relaunch without re-executing actions.

- [ ] **Test expectations:** Assert unseen player actions stay unknown, hostile prompt text cannot become a fact, oversized history is bounded, summaries cannot complete missions and loading history never replays rewards or faction changes.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-06: Build text dialogue, mission interaction and local-provider evaluation

- [ ] **NPC-06 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-02, NPC-05, INV-05. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/ui/dialogue_ui.tscn`; `game/ui/mission_journal.gd`; `game/features/dialogue/generation_audio.gd`; `benchmarks/npc/`; `docs/model-evaluation.md`.

**Interfaces:** UI consumes orchestrator waiting/fallback/completion events and mission lifecycle signals; basic generation blips are presentation only.

- [ ] **Acceptance:** One named NPC offers/accepts a job; dialogue supports waiting, cancel, text/subtitles and accessible audio-volume/mute controls. Fallback allows a complete mission/reward loop. Inventory-backed trade requests open a bounded interaction panel or explain unavailability. Evaluate an already available suitable local model; record license/context/latency and setup, and flag missing model rather than downloading without authorization.

- [ ] **Test expectations:** Playtest retrieval/return/reward with provider available, offline and mid-dialogue cancellation. Test audio stops on close/timeout, focus recovers and journal survives restart. Record response quality/scoped-knowledge failures and concurrent-load data for WORLD-06.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.

### NPC-07: Expand templates, roster and release provider setup

- [ ] **NPC-07 — deliverable complete** (Stage 2–5 (deferred)).

**Dependencies / sequencing:** WORLD-06; approved mission/roster/model distribution scope. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/missions/data/`; `game/features/dialogue/npcs/`; `docs/model-installation.md`.

**Interfaces:** Extend existing schemas with reviewed data; no new action names without validator/policy tests.

- [ ] **Acceptance:** Split delivery, clearing-hostiles and existing-device hacking templates into individual tasks. Expand named NPCs and authored content from measured mission throughput. Decide local model delivery/license/minimum requirements before release; voice remains optional expansion.

- [ ] **Test expectations:** Per-template reachability, fallback, one-time reward and unload/save regressions; roster knowledge-boundary tests and clean-machine provider/fallback setup test.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
