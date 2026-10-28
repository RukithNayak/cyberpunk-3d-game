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

- [x] **NPC-01 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** CORE-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/{provider,mock_provider,context_snapshot,response_validator,llm_response}.gd`; `game/tests/dialogue/test_schema.gd`; coordinated runner registration.

**Interfaces:** ContextSnapshot includes NPC identity, scoped facts, bounded memory, eligible templates and standing; LLMResponse contains dialogue_text and proposed_action. Provider publishes completion with NPC/conversation/request-generation IDs.

**Supporting contract recorded before implementation:** Context payload has exact fields `npc_identity` (`npc_id`, `display_name`, `faction_id`), `scoped_facts`, `memory_summary`, `eligible_mission_templates`, and integer `faction_standing`. IDs use lowercase `[a-z0-9][a-z0-9_.-]{0,79}`; defaults cap facts/templates at 32 entries, fact text at 240 chars, memory at 1,200 chars, display name at 80 chars, and serialized request/response JSON at 8 KiB. `LLMResponse` is data-only and never dispatches actions. Response JSON has exactly `dialogue_text` and `proposed_action`; action is null or `{action, parameters}`. The allowlist is the six detailed-design actions; every action has an exact parameter key set (begin_fight has none), and IDs must pass the same identifier rule. Text is bounded at 1,200 chars. Provider API emits raw JSON with NPC ID, conversation ID and generation; MockProvider offers deterministic valid, delayed and malformed responses and has no gameplay-state references or mutation capability.

- [x] **Acceptance:** Enforced explicit JSON types, exact action parameter keys, size limits and the six-action allowlist. The mock emits deterministic valid, delayed and malformed responses. Schema returns inert proposals and directly executes no action. Engineering limits are recorded as configurable defaults.

- [x] **Test expectations:** Covered malformed JSON, oversized text/body/context, missing/unknown keys, wrong types, unknown actions, extra/wrong action parameters and instruction-like context text. Confirmed validation of all six proposals mutates neither registry nor faction standing.

- [x] **Evidence recorded:** [NPC-01 report](../reports/NPC-01.md); `dialogue_schema`44/44 and final integrated `all`887/887 exit0; import and diff check exit0. The first full run hit the documented intermittent AI-03 navigation fixture race; retry passed. No scene/MCP visual check applies.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Context and response data are strictly bounded; provider proposals remain inert until a later authoritative dispatcher validates them. `MockDialogueProvider` exercises valid, delayed and invalid responses with request identity. See [report](../reports/NPC-01.md).

### NPC-02: Implement asynchronous Ollama lifecycle and fallback

- [x] **NPC-02 — deliverable complete** (Stage 1; offline/mock-backed acceptance).

**Dependencies / sequencing:** NPC-01, CORE-01. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/ollama_provider.gd`; `game/features/dialogue/dialogue_orchestrator.gd`; `game/tests/dialogue/test_requests.gd`.

**Interfaces:** `submit_dialogue_request(npc_id: String, prompt: String) -> void`; `_on_http_response_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void`.

**Supporting contract recorded before implementation:** `OllamaProvider` is a Node adapter using one Godot `HTTPRequest` to POST `/api/chat`; the model name is required configuration, streaming is disabled, JSON-schema output format is requested, and the existing NPC-01 validator remains authoritative. `DialogueOrchestrator` is the only queue/generation owner: one in-flight request plus at most two queued requests, with bounded prompt/context sizes and a configurable 15-second default timeout. Conversation setup binds the NPC ID, conversation ID, validated `ContextSnapshot`, and authored fallback text; the task's two-argument `submit_dialogue_request` remains intact. Invalid HTTP status/body, timeout, provider offline, or invalid model JSON returns fallback exactly once. Cancellation, conversation replacement, death or unload invalidates the generation and drops queued/late/duplicate responses without invoking an action dispatcher. MockProvider is used for deterministic offline, delayed, timeout and reordering tests; no model installation/download is needed.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Offline/mock-backed lifecycle acceptance is complete. The live endpoint smoke check is explicitly deferred because `127.0.0.1:11434` refused the check (curl exit7); this does not block the implemented no-model fallback path. See [NPC-02 report](../reports/NPC-02.md).

- [x] **Acceptance:** Uses non-blocking HTTP, one concurrent request and bounded context/queue. Uses configurable 15-second default deadline; timeout, HTTP error, missing model/provider or invalid output routes to authored fallback. Conversation cancellation/replacement/unload increments generations and invalidates results; late/duplicate responses do nothing. Callers use the shared cancellation method for walk-away/death lifecycle events.

- [x] **Test expectations:** Fake provider and timer tests cover offline, 4xx/5xx, timeout, malformed body, stale/duplicate replies, model switch and queue saturation. Confirm submission returns while a reply is pending, fallback emits once, and cancelled/stale proposals never reach dialogue presentation.

- [x] **Evidence recorded:** [NPC-02 report](../reports/NPC-02.md); focused `dialogue_requests`23/23 and `dialogue_schema`44/44; integrated `all`910/910; import and diff-check exit0. Local Ollama endpoint check exited7 (connection refused); live inference remains unverified and no model was installed.

### NPC-03: Build deterministic mission offers and lifecycle

- [x] **NPC-03 — deliverable complete** (Stage 1).

**Supporting contract recorded before implementation:** `MissionTemplate` is a data-only Godot `Resource` with exact authored ID, retrieval target UUID, issuer faction ID, minimum standing, bounded credit reward (0–1,000 engineering cap), target label and authored fallback offer. `MissionDirector` is a data-only service configured with the accepted `EntityRegistry`, `FactionState`, templates and a reachability `Callable`; it rejects unknown, missing, already-collected, unreachable, hostile/under-standing or invalid-reward offers. The shipped `retrieve_signal_cache.tres` template is bound to the existing WORLD-03 loot projection UUID `00000000-0000-4000-8000-000000000032`. A mission ID and reward transaction ID derive deterministically from the stable template/target IDs. Lifecycle is offered→accepted→active→completed or failed; completion requires the registry's code-owned target record to show `collected == true`; failure requires an authored failure reason. Reward credits are bounded and applied once by the director; model prose cannot complete an objective. Mission snapshot uses `domains.missions` shape `{version, credits, missions}` and implements pure prepare plus no-signal commit for CORE-04; snapshots contain only stable IDs and data, so mission state survives chunk unload and provider loss.

**Dependencies / sequencing:** NPC-01, CORE-04. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/missions/mission_director.gd`; `game/features/missions/mission_template.gd`; `game/features/missions/retrieve_signal_cache.tres`; `game/tests/missions/test_lifecycle.gd`; coordinated runner registration.

**Interfaces:** `offer_mission(template_id)` proposes an existing eligible template; director creates stable mission/target/reward IDs and owns offered/accepted/active/completed/failed transitions.

- [x] **Acceptance:** Authored the retrieval template and fallback against the existing reachable WORLD-03 loot fixture. Offer eligibility validates current faction rules, stable target existence/reachability and bounded reward. Persisted offers/states survive provider failure and chunk unload; code-owned target collection alone completes the objective.

- [x] **Test expectations:** Covered missing/unreachable target, hostile/low-standing faction, invalid reward, repeated offer/accept/complete and failed objectives. Round-tripped offered, accepted, active, completed and failed states; model text cannot complete an uncollected objective.

- [x] **Evidence recorded:** [NPC-03 report](../reports/NPC-03.md); focused `missions`41/41, integrated `all`951/951, import and diff-check exit0. No scene or visual change applies.


Accepted 23 October 2026 (Asia/Kolkata), Main Agent. The sample retrieval offer is data-driven and authoritative mission state is independent of provider output and chunk-loaded Nodes. See [NPC-03 report](../reports/NPC-03.md).

### NPC-04: Add guarded deterministic action dispatch

- [x] **NPC-04 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-02, NPC-03, INV-04, AI-02. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/action_dispatcher.gd`; `game/tests/dialogue/test_actions.gd`; `docs/npc-action-policy.md`.

**Interfaces:** Handle `offer_mission(template_id)`, `initiate_trade(inventory_id)`, `accept_into_faction(faction_id)`, `begin_fight()`, `disclose_fact(fact_id)`, `give_item(item_id)` using current-state eligibility and idempotent transaction IDs.

**Supporting contract recorded before implementation:** `ActionDispatcher` binds the active NPC/conversation, resolves the current live actor for every dispatch, revalidates model output through NPC-01's `ResponseValidator`, accepts only increasing request generations, and derives a stable transaction ID from NPC/conversation/generation. It receives narrow authority adapters: MissionDirector plus NPC→template allowlists; inventory→merchant mapping plus current stock validator and open-trade callback; faction state plus per-faction allowed-NPC/min-standing/join-standing rule; NPC fight allowlist plus a live TacticalAgent and player resolver; current fact-availability and commit callbacks; ItemGrants plus a current preauthorized ItemInstance resolver. Each service rechecks eligibility at commit. Missing or unsupported adapters reject safely. Duplicate responses return their cached result without repeating side effects; item grants use the same stable transaction ID and ItemGrants' persisted entitlement on replay/full inventory. No Node is stored in persistent data. The full owner-written rule table is `docs/npc-action-policy.md`.

- [x] **Acceptance:** Authoritative code rechecks actor validity, permission and preconditions immediately before commit. Trades reference allowed merchant stock; faction acceptance needs an authored eligibility rule; fighting requires a permitted live NPC transition; facts must be known/disclosable; items require a preauthorized quest/reward entitlement. Unsupported/unconfigured actions reject safely. Model cannot invent items, rewards, factions or executable code.

- [x] **Test expectations:** Inject invented IDs, reward inflation, unauthorized faction acceptance/hostility, stale eligibility and duplicated responses. Assert zero unauthorized mutations and one reward on replay; full inventory preserves entitlement. Exercise allowed and rejected cases for each of the six actions.

- [x] **Evidence recorded:** Import exit 0; focused `dialogue_actions` 41 cases/0 failures exit 0; integrated `all` 992 cases/0 failures exit 0; `git diff --check` exit 0. Integrated suite emitted the existing one ObjectDB instance and one `GodotBody3D` RID shutdown leak warnings. See [NPC-04 report](../reports/NPC-04.md); no visual capture applies to this logic task.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. `ActionDispatcher` validates model output and live conversation authority before executing the six allowlisted actions. Explicit adapters enforce mission permissions, merchant ownership/current stock, authored faction admission, live permitted combat transitions, known disclosures, and preauthorized ItemGrants; stable transaction IDs and duplicate caching prevent replay effects. Full inventory retains pending reward entitlement. Focused and integrated evidence is in [NPC-04 report](../reports/NPC-04.md).

### NPC-05: Persist scoped knowledge and bounded memory

- [x] **NPC-05 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-03, NPC-04, CORE-04, WORLD-03. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/dialogue/npc_memory.gd`; `game/features/dialogue/dialogue_snapshot.gd`; `game/tests/dialogue/test_memory.gd`.

**Interfaces:** Store factual events separately from derived summaries; registry holds stable NPC, conversation, mission and action transaction IDs.

**Supporting contract recorded before implementation:** `NpcMemory` is a runtime-only data owner keyed by stable NPC IDs (never Node references). Its v1 `domains.npc_memory` snapshot stores exact authored fact IDs plus source (`witnessed`/`disclosed`) and stable evidence ID, a bounded transcript of player/NPC/system lines keyed by stable conversation ID, and a separate bounded derived summary. `record_fact` accepts a fact only when it exists in the authored fact catalog and a game-owned `authorize_fact_evidence(npc_id, fact_id, source, evidence_id)` callback returns boolean true; model text and summaries cannot call this commit path. Transcript and summary content are never promoted to facts. Snapshot capture returns copies; prepare validates the exact schema and current authored fact IDs without mutation; commit only swaps prepared data and executes no actions. `DialogueSnapshot` coordinates only `npc_memory` and `missions`, preserves unknown domain records opaquely, and builds the existing `ContextSnapshot` from verified fact text, current faction standing in `FactionState`, and an upstream game-validated eligible template list. Mission/faction truth remains with MissionDirector/FactionState and their existing CORE-04 snapshot participants. Restoring memory never replays disclosure, action, reward or faction callbacks. Initial bounds: 64 NPC records, 32 facts/NPC, 32 recent dialogue lines/NPC, 500 characters/line, 1,200 summary characters/NPC; existing ContextSnapshot limits the final provider payload to 8 KiB.

- [x] **Acceptance:** Only witnessed/legitimately disclosed facts enter context. Summaries cannot overwrite missions or world truth; bound history/context size and log auditable commits. Restore knowledge, relationships, offers and memories after unload/relaunch without re-executing actions.

- [x] **Test expectations:** Assert unseen player actions stay unknown, hostile prompt text cannot become a fact, oversized history is bounded, summaries cannot complete missions and loading history never replays rewards or faction changes.

- [x] **Evidence recorded:** Import exit 0; focused `dialogue_memory` 30 cases/0 failures exit 0; integrated `all` 1,022 cases/0 failures exit 0; SaveStore disk reload into recreated memory/faction/mission owners; `git diff --check` exit 0. Integrated suite emitted one ObjectDB and one `GodotBody3D` RID shutdown warning. See [NPC-05 report](../reports/NPC-05.md); no visual capture applies.

Accepted 23 October 2026 (Asia/Kolkata), Main Agent. Authored fact IDs can enter memory only with live authorized evidence; transcript and derived summary remain separate data. `DialogueSnapshot` restores the NPC-memory and mission domains without replaying effects and builds bounded context with current authoritative faction standing. SaveStore reload and integrated evidence are in [NPC-05 report](../reports/NPC-05.md).

### NPC-06: Build text dialogue, mission interaction and local-provider evaluation

- [x] **NPC-06 — deliverable complete** (Stage 1).

**Dependencies / sequencing:** NPC-02, NPC-05, INV-05. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/ui/dialogue_ui.{tscn,gd}`; `game/ui/mission_journal.gd`; `game/features/dialogue/generation_audio.gd`; `game/features/dialogue/mock_provider.gd` (offline fixture mode); `game/features/missions/mission_director.gd` (lifecycle signal); `game/tests/dialogue/test_ui.gd`; `game/tests/missions/test_lifecycle.gd`; `game/tests/scenes/dialogue_demo.{tscn,gd}`; `game/tests/run_tests.gd`; `benchmarks/npc/`; `docs/model-evaluation.md`.

**Implementation status — 23 October 2026:** Main Agent owns NPC-06. Supporting integration recorded before implementation: add `MissionDirector.mission_changed(mission_id, state, credits)` after each successful state commit (including credit updates, once per actual transition); the dialogue UI receives typed orchestrator/dispatcher/mission adapters through `configure`, displays authored fallback and provider results, and offers an authored mission request so offline progression does not depend on model output. Add a named-NPC demo fixture and focused dialogue UI suite (including runner registration) to make the job/reward loop runnable. Add a deterministic generated audio blip with volume/mute controls and stop it on close/cancel/timeout. The fixture/test, offline mode in the mock provider, mission director signal, mission tests and runner are supporting integration paths for the existing acceptance criteria, not expanded gameplay scope. Evaluate only an already installed local model; no pulls/downloads.

**Interfaces:** UI consumes orchestrator waiting/fallback/completion events and mission lifecycle signals; basic generation blips are presentation only.

- [x] **Acceptance:** Named Mara Vega opens the responsive conversation UI; controls cover waiting, cancel, text/subtitles, volume and mute. Authored request/accept path completes the registry-validated retrieval and one-time reward when the dialogue provider is offline or invalid. Trade is reported unavailable when no authorized merchant panel exists. Existing local `llama3:willowbrook` was evaluated with its license/context/setup and latency recorded; no model was pulled.

- [x] **Test expectations:** Focused UI fixture covers valid/mock output, offline fallback, invalid action, cancellation, retrieval/reward, audio mute/volume/timeout/close, keyboard focus return, and journal reconstruction from the mission snapshot. One-time mission SaveStore reload remains covered by the existing missions suite. Model quality deviation is recorded; only one concurrent local inference sample was collected, with sustained/concurrent-load measurement explicitly assigned to WORLD-06.

- [x] **Evidence recorded:** Import0; `dialogue_ui`15/15, `missions`46/46, integrated `all`1042/1042, and `git diff --check`0. Godot MCP 4.7.2 runtime started the demo with no runtime errors; existing nonfatal script warnings recorded. Full-screen capture, raw Ollama measurements, and limitations are in [NPC-06 report](../reports/NPC-06.md), [model evaluation](../model-evaluation.md), [benchmark output](../../benchmarks/npc/llama3_willowbrook_latest.json), and [UI capture](../evidence/NPC-06/dialogue_initial.png). Manual listening/playtest and concurrent load remain unrun.

Accepted 24 October 2026 (Asia/Kolkata), Main Agent. Demo launch: `godot --path game res://tests/scenes/dialogue_demo.tscn`. The scene is a service-wired NPC interaction fixture; it is not yet attached to the game's main combat scene. Sustained concurrent Ollama/GPU/rendering measurements are an explicit WORLD-06 follow-up.

### NPC-07: Expand templates, roster and release provider setup

- [ ] **NPC-07 — deliverable complete** (Stage 2–5 (deferred)).

**Dependencies / sequencing:** WORLD-06; approved mission/roster/model distribution scope. Prerequisite IDs resolve through the master progress task index.

**Files / ownership:** `game/features/missions/data/`; `game/features/dialogue/npcs/`; `docs/model-installation.md`.

**Interfaces:** Extend existing schemas with reviewed data; no new action names without validator/policy tests.

- [ ] **Acceptance:** Split delivery, clearing-hostiles and existing-device hacking templates into individual tasks. Expand named NPCs and authored content from measured mission throughput. Decide local model delivery/license/minimum requirements before release; voice remains optional expansion.

- [ ] **Test expectations:** Per-template reachability, fallback, one-time reward and unload/save regressions; roster knowledge-boundary tests and clean-machine provider/fallback setup test.

- [ ] **Evidence recorded:** Add focused commands/results and applicable capture/report links here before checking the deliverable.
