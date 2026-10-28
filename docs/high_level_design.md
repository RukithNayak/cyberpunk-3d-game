# High-Level System Design: Cyberpunk 3D FPS

**Status:** Draft (Pending Requirement Sign-off)  
**Target Environment:** macOS (M5 MacBook Air, 16 GB Unified Memory baseline)  
**Proposed Core Stack:** Godot 4.7.2 (Typed GDScript), Blender (Python/Geometry Nodes -> GLB/glTF), Ollama (Local HTTP API)

---

## 1. Architecture Overview

The system is designed as a single-player, local-first 3D First-Person Shooter set in a seamless, chunk-streamed cyberpunk city. The architecture separates **authoritative, deterministic gameplay simulation** from **asynchronous, non-blocking generative AI inference**:

1. **Authoritative Simulation Layer (Godot Engine):** Owns all world truth, physics, hit detection, inventory state, mission progression, and entity lifecycle. It never waits synchronously on external processes.
2. **Generative Inference Layer (Local LLM Service):** Operates out-of-process via an HTTP adapter (Ollama). It consumes read-only context snapshots to generate conversational dialogue and propose bounded, schema-validated high-level actions, which the simulation layer may accept or reject.
3. **Offline Asset & Content Pipeline:** Decouples heavy procedural geometry generation and texture baking (Blender + AI concept tools) from the runtime engine, outputting optimized, budget-verified `.glb`/`.gltf` artifacts.

```text
+-----------------------------------------------------------------------------------+
|                           RUNTIME GAME CLIENT (Godot 4.7.2)                       |
|                                                                                   |
|  +-------------------+    +-----------------------+    +-----------------------+  |
|  | Presentation & UI |<-->| Player & Combat Core  |<-->| Hacking & Interaction |  |
|  +-------------------+    +-----------------------+    +-----------------------+  |
|            ^                          ^                            ^              |
|            |                          v                            v              |
|            |              +----------------------------------------+              |
|            |              |     Authoritative World State &        |              |
|            +------------->|     Mission / Inventory Managers       |              |
|                           +----------------------------------------+              |
|                                 ^             ^              ^                    |
|                                 |             |              |                    |
|                                 v             v              v                    |
|  +-------------------+    +-----------+  +---------+  +------------------------+  |
|  | World Streaming & |    | Save/Load |  | Tact.   |  | Generative NPC         |  |
|  | Chunk Manager     |<-->| System    |  | AI (BT) |  | Orchestrator & Adapter |  |
|  +-------------------+    +-----------+  +---------+  +------------------------+  |
+-------------------------------------------------------------------|---------------+
                                                                    | Async HTTP
                                                                    v (JSON Schema)
+-----------------------------------+               +-------------------------------+
| OFFLINE ASSET PIPELINE            |               | LOCAL AI SERVICE (Ollama)     |
| [AI Art] -> [Blender/GeoNodes]    |               | - Quantized Local LLM         |
|          -> [QA Gate] -> [GLB] ===|==> (Imports)  | - Zero Cloud Cost             |
+-----------------------------------+               +-------------------------------+
```

---

## 2. Major Components & Relationships

### 2.1. World Streaming & Chunk Manager
* **Responsibilities:** Divides the seamless city and detailed interiors into spatial chunks. Manages asynchronous background loading, main-thread instantiation budgets, hysteresis margins at boundaries, and navigation mesh stitching/handoffs.
* **Relationships:** 
  * Queries and commits chunk delta states to the **Persistence & State Registry** before unloading.
  * Notifies the **Generative NPC Orchestrator** and **Tactical AI System** when entities enter or leave active simulation ranges.

### 2.2. Player, Combat & Weapon System
* **Responsibilities:** Handles 3D character movement, camera/FOV control, input rebinding, hitscan/projectile weapon state machines, muzzle obstruction checks, and health/damage resolution.
* **Relationships:**
  * Reads weapon definitions and rolled stats from the **Inventory & Loot System**.
  * Emits combat/sound events to the **Tactical & Ambient AI System** and updates the **UI/Presentation Layer**.

### 2.3. Inventory, Loot & Equipment System
* **Responsibilities:** Manages item instances with stable UUIDs, seeded weighted drop tables, rarity tiers, equipment slots, backpack capacity, and separated magazine vs. reserve ammunition states.
* **Relationships:**
  * Supplies active weapon/consumable parameters to the **Player & Combat System**.
  * Synchronizes all item state mutations with the **Persistence & State Registry** to prevent duplication or rerolls on reload.

### 2.4. Hacking & Environmental Interaction System
* **Responsibilities:** Executes deterministic, low-latency combat and environmental hacks (cameras, doors, turrets, enemy implants) governed by range, line-of-sight, target tags, cooldowns, and rechargeable hacking energy.
* **Relationships:**
  * Mutates target states in the **Combat** and **World** layers.
  * Emits distraction/security events to the **Tactical AI System** and logs persistent state changes (e.g., permanently unlocked doors) to the **Persistence Registry**.

### 2.5. Tactical & Ambient AI System
* **Responsibilities:** Runs conventional, deterministic game AI (navmesh pathfinding, line-of-sight/sound perception, alert states, combat roles for gang goons, and lightweight ambient pedestrian routines).
* **Relationships:**
  * Operates independently of the LLM for real-time responsiveness.
  * Reacts to signals from the **Combat** and **Hacking** systems; downgrades distant entities to simplified simulation records when instructed by the **Chunk Manager**.

### 2.6. Mission Director
* **Responsibilities:** Owns authoritative mission templates (delivery, retrieval, hostile clear, device hack), tracks mission lifecycle (`offered` $\rightarrow$ `accepted` $\rightarrow$ `active` $\rightarrow$ `completed`/`failed`), and validates world target reachability and rewards.
* **Relationships:**
  * Exposes a bounded list of eligible mission templates to the **Generative NPC Orchestrator** so NPCs can pitch contextualized jobs.
  * Listens to **World**, **Inventory**, and **Combat** state changes to advance mission objectives.

### 2.7. Generative NPC Orchestrator & AI Provider Adapter
* **Responsibilities:** Manages conversational state, constructs scoped memory/fact snapshots, queues asynchronous inference requests with generation counters, enforces response deadlines, validates returned JSON against strict schemas, and provides a deterministic fallback dialogue path.
* **Relationships:**
  * Communicates externally with the **Ollama HTTP API** (or internal deterministic mock/fallback provider).
  * Reads allowed actions and world facts from the **Mission Director** and **Persistence Registry**, and submits validated high-level proposals (e.g., offer job, disclose fact, initiate trade) back to them.

### 2.8. Persistence & Authoritative State Registry
* **Responsibilities:** Maintains a versioned, stable-ID registry of all persistent state: player loadout, entity states across unloaded chunks, active/completed missions, faction relationships, and separated NPC factual event logs vs. compact conversation summaries.
* **Relationships:** Central source of truth read and written by all gameplay managers during save/load cycles and chunk transitions.

### 2.9. Offline Asset Authoring & QA Pipeline
* **Responsibilities:** Automates 3D modular kit creation, UV/texel normalization, PBR texture baking, collision proxy generation, and LOD creation via Blender Python and Geometry Nodes, gated by automated QA scripts before exporting to Godot.
* **Relationships:** Feeds verified `.glb`/`.gltf` assets and Godot Resource definitions into the runtime project.

---

## 3. Data Flow and Control Flow

### 3.1. Generative NPC Conversation & Action Flow
Control remains strictly non-blocking on the main game thread:
1. **Trigger:** Player initiates dialogue with a named NPC.
2. **Snapshot Assembly:** The **Generative NPC Orchestrator** queries the **Persistence Registry** and **Mission Director** to build a scoped context payload (`NPC Identity`, `Scoped Known Facts`, `Relationship State`, `Compact Memory Summary`, `Eligible Mission Templates`, `Allowed Action Schema`).
3. **Async Dispatch:** Orchestrator increments the `request_generation_id`, displays a non-blocking UI waiting state, and sends an asynchronous HTTP POST request to the local **Ollama API** with a strict timeout deadline (e.g., 15s).
4. **Validation Gate:** When the response arrives, the Orchestrator verifies:
   * Is the `request_generation_id` still current?
   * Is the NPC still alive, in range, and in a loaded chunk?
   * Does the payload conform to the JSON schema and size bounds?
   * Are the proposed action parameters (e.g., `offer_mission(template_id)`) still valid against authoritative preconditions?
5. **Commit or Fallback:** If valid, the **Mission Director** / **Persistence Registry** commits the state change, logs an auditable memory event, and displays the dialogue. If invalid, timed out, or stale, the response is discarded or routed to the **Deterministic Fallback Provider**.

### 3.2. Seamless World Streaming & Handoff Flow
1. **Movement:** Player approaches a district boundary or interior vestibule.
2. **Preload (Hysteresis):** **Chunk Manager** detects entry into the preload margin and initiates background thread loading of adjacent chunk resources.
3. **State Hydration:** Before instantiating nodes on the main thread (within a per-frame time budget), the **Chunk Manager** queries the **Persistence Registry** by stable entity IDs to apply deltas (e.g., previously looted containers, unlocked doors, dead enemies, timed hack durations).
4. **Boundary Unload:** When the player moves beyond the unload margin, the **Chunk Manager** cancels any pending transient tasks/LLM requests targeting that chunk, serializes modified entity states to the **Persistence Registry**, transitions persistent NPCs to lightweight simulation records, and frees the scene nodes.

### 3.3. Combat & Hacking Loop (Synchronous/Frame-Accurate)
1. **Input:** Player fires a weapon or triggers a hack ability.
2. **Validation:** **Combat/Hacking System** synchronously checks ammo/energy costs, cooldowns, range, and raycast obstruction against physical collision layers.
3. **Resolution:** Applies immediate state mutations (health reduction, implant disruption, camera disable), triggers audio/visual feedback, and broadcasts conventional AI perception events to nearby **Tactical AI** agents.

---

## 4. External Dependencies

| Dependency | Type | Role in Architecture | Constraints & Licensing Notes |
|---|---|---|---|
| **Godot Engine (`4.7.2`)** | Runtime & Editor | Core game engine, physics, rendering, GDScript execution, headless test runner | Pinned version; MIT license; installed locally. |
| **Ollama (`Local HTTP`)** | Runtime Service | Local LLM inference server for generative NPCs | Shares 16 GB RAM with OS and Godot; model weights require license audit prior to distribution. |
| **Blender (`5.2+` target)** | Offline Tooling | 3D modeling, Geometry Nodes, UV/baking, rigging, automated asset QA, GLB export | Must locate/verify local binary installation; scripts execute headlessly. |
| **ChatGPT Plus / Codex** | Offline Dev & Art | Concept generation, 2D decal/ad creation, code generation & automation | Strict development-time tool only; **cannot** be used as a runtime API. |
| **Git (and optional Git LFS)** | Version Control | Source code, scene files, and binary asset milestone tracking | Binary storage policy must be established before bulk asset generation. |

---

## 5. Key Design Decisions and Tradeoffs

1. **Two-Layer NPC Architecture (Authoritative Code vs. Advisory LLM)**
   * *Decision:* The LLM generates dialogue and proposes actions from a strict enum/schema, while deterministic GDScript owns all state, inventory, and mission creation.
   * *Tradeoff:* Sacrifices unbounded "emergent" AI sandbox freedom to guarantee game progression cannot be soft-locked, corrupted, or hallucinated by the model.
2. **Local Inference via Ollama over Cloud LLM APIs**
   * *Decision:* Run quantized local models over HTTP on the host machine.
   * *Tradeoff:* Eliminates per-request cloud costs and runtime internet dependencies, but introduces severe memory/compute contention on a 16 GB RAM MacBook Air and complicates end-user packaging.
3. **Godot 4.7.2 + Typed GDScript over Unreal/Unity**
   * *Decision:* Use Godot with native GDScript and Resources.
   * *Tradeoff:* Provides a lightweight editor footprint (crucial when running local LLMs alongside the game) and rapid iteration with installed skills, at the cost of having to custom-engineer chunk streaming and persistence systems that come built-in with Unreal.
4. **Baked GLB Exports over Runtime Procedural Geometry**
   * *Decision:* Evaluate Blender Geometry Nodes and bake procedural materials into standard PBR textures and static/LOD meshes during the offline export phase.
   * *Tradeoff:* Increases disk storage and build-step complexity, but ensures predictable frame times and cross-engine material compatibility at runtime.
5. **Deterministic Hacking & Tactical AI**
   * *Decision:* Keep combat AI (goons) and hacking mechanics 100% conventional and synchronous.
   * *Tradeoff:* Ensures crisp 60 FPS shooter responsiveness, avoiding multi-second LLM latency during firefights.

---

## 6. Security, Reliability, and Observability Considerations

### 6.1. Security & Trust Boundaries
* **Untrusted LLM Output:** Treat all responses from the local Ollama endpoint as untrusted external input. Enforce strict JSON schema parsing, maximum payload size limits, and parameter allowlists. Never pass LLM output to dynamic code evaluation (`Expression`, `OS.execute`, or script loading).
* **Scoped NPC Knowledge (Information Isolation):** Prevent "omniscient NPC" leaks by strictly scoping the context payload to facts the specific NPC has witnessed or been told. Do not expose global world state or unrevealed plot data in the prompt.
* **Credential & Cost Protection:** Hard-block any usage of personal ChatGPT accounts or paid API keys in client runtime code. Bind local provider connections strictly to `localhost` (`127.0.0.1`).

### 6.2. Reliability & Fault Tolerance
* **Graceful AI Degradation:** If Ollama is unreachable, times out, returns malformed JSON, or is mid-generation when a chunk unloads, the **Generative NPC Orchestrator** must cleanly cancel/ignore the request and seamlessly transition to the **Deterministic Fallback Provider** (authored dialogue/mission offer) so progression is never blocked.
* **Generation Counters & Stale State Protection:** Every async request is tagged with `(npc_id, conversation_id, request_generation_id)`. If an NPC dies, enters combat, or unloads while a request is in flight, late responses are automatically dropped.
* **Idempotent Persistence & Save Migration:** Every spawned item, door, and NPC uses a deterministic/stable UUID. Save files include schema version headers to support migration and prevent item duplication or stat re-rolling upon reload.
* **Single Concurrency Cap:** Limit runtime LLM inference to a single active request at a time to prevent memory exhaustion (OOM) and thermal throttling on 16 GB hardware.

### 6.3. Observability & Verification
* **In-Engine Debug Overlays:** Provide toggleable runtime HUDs displaying Tactical AI states (current state, nav target, perception alerts), Chunk Streaming states (loaded/preloading/unloading chunks, main-thread instantiation spikes), and LLM Queue status.
* **Combined Load Profiling:** Capture telemetry combining rendering and active LLM inference—specifically tracking median and 99th-percentile (tail) frame times, unified memory consumption, time-to-first-token (TTFT), and total inference latency.
* **Audit Logging:** Record an auditable trace of every LLM prompt snapshot, raw response, validation pass/fail reason, and committed state mutation to rapidly debug narrative or mission bugs.
* **Headless Verification Gates:** Automated Godot headless test suites for state logic (ammo math, save/load integrity, stale response rejection) and headless Blender QA checks (polycount, manifold geometry, UV bounds) prior to asset import.

---

## 7. Risks and Mitigations

| ID | Risk Description | Impact | Mitigation Strategy |
|---|---|---|---|
| **R1** | **Hardware Resource Contention:** Running 3D rendering, chunk streaming, and local LLM inference simultaneously exceeds the 16 GB unified memory budget or causes thermal throttling on the M5 MacBook Air. | High | Execute Stage 1 combined benchmark early; restrict to small quantized models; cap concurrency at 1 active request; bound context window sizes; enforce strict VRAM/texture budgets. |
| **R2** | **State Corruption Across Chunk Boundaries:** Unloading a chunk while an NPC request is pending or an entity is mid-interaction causes crashes, lost items, or ghost actions. | High | Enforce strict ownership in the **Persistence Registry** using stable IDs; serialize state prior to unload; invalidate in-flight async requests via generation counters upon chunk exit or death. |
| **R3** | **LLM Hallucinations Breaking Missions:** The language model invents non-existent districts, impossible targets, or arbitrary item rewards. | High | **Mission Director** selects eligible templates and targets in code first; LLM is restricted to selecting from provided IDs and generating flavor text; invalid schemas trigger authored fallbacks. |
| **R4** | **3D Asset Pipeline Mismatch:** AI-assisted/procedural Blender models look good in renders but fail in-engine due to bad topology, broken rigs, unbaked Geometry Nodes, or missing collisions. | Medium | Build and validate a single Reference Asset (wall/door + prop) in Godot before bulk production; bake all procedural materials/nodes to standard GLB; enforce automated Blender QA gates. |
| **R5** | **Toolchain & Environment Gaps:** Blender binary was not found in standard paths (`/Applications/Blender.app` or `PATH`), and Ollama model performance is unverified. | Medium | Gate all production on Stage 0 verification: locate/install Blender 5.2+, verify headless script execution against installed skills, and benchmark Ollama server health. |
| **R6** | **End-User Distribution Friction:** Relying on a local Ollama setup works for development but is difficult to package and license for end-user players. | Medium | Abstract LLM calls behind a clean **AI Provider Interface** so the backend can swap between bundled local weights, user-supplied local servers, hosted APIs, or offline fallbacks before release. |

---

## 8. Open Questions & Clarifications Required

Before we lock this High-Level Design and break it down into Stage 0 / Stage 1 implementation tasks, please clarify the following points from the proposal:

1. **Proposed Stack & Single-Player Sign-off:** Do you approve the recommended baseline stack (**Godot 4.7.2 + Typed GDScript + Blender + Local Ollama**) and confirming the architecture as **strictly single-player**?
2. **Target Release Platforms & Distribution Model:** Is this primarily a personal project/experiment for macOS, or do you plan to distribute it publicly/commercially (e.g., Windows/Linux/macOS via Steam)? If distributed to players, how should they run the NPC model (bundled local runtime, bring-your-own Ollama, or fallback-capable)?
3. **Interior Transitions:** Streets between districts will stream seamlessly without loading screens. For detailed NPC interiors, must entry also be 100% seamless (via airlocks/vestibules), or is a brief fade/transition acceptable if needed to protect the 16 GB RAM budget?
4. **Generative NPC Autonomy & Voice:** Should generative NPCs be limited to conversation and offering pre-validated missions/trades, or do you want them to trigger broader high-level world actions (e.g., dynamically changing faction hostility or calling in ambushes)? Additionally, is text-only dialogue approved for the baseline, or is voice synthesis/lip-sync a hard requirement for you?
5. **Gameplay Systems (Factions, Inventory, Hacking):**
   * **Gangs/Factions:** Do you want a persistent faction reputation and hostility system across districts, or are enemies simple encounter-based goons?
   * **Inventory & Ammo:** Should backpack capacity be **slot-based** or **weight-based**, and should reserve ammo be shared by **weapon family** (e.g., all pistols) or specific **caliber**?
   * **Hacking:** Which initial 3–4 hacking abilities do you want in the baseline (e.g., disable camera, unlock door, trigger distraction, disrupt enemy implant, disable turret), and should hacking energy regenerate automatically over time?
6. **Asset Sourcing Policy & Visual References:** Does your goal of developing the game "using AI" allow mixing in free, permissively licensed existing 3D assets/animations (e.g., for human rigs/mocap), or must 100% of shipped meshes and animations be generated via our Blender + AI pipeline? Also, what specific games or media serve as your primary visual and gameplay references?
7. **Local Blender Path:** During environment checks, Godot and Ollama were found, but Blender was not detected in `/Applications/Blender.app` or on `PATH`. Is Blender already installed at a custom path on your MacBook, or should we install Blender 5.2+ as part of environment setup?