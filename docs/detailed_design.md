# docs/detailed-design.md

**Status:** Approved for Stage 0 / Stage 1 Implementation
**Target Environment:** macOS, M5 MacBook Air (16 GB Unified Memory)
**Core Stack:** Godot 4.7.2 (Typed GDScript), Blender 5.2, Local Ollama HTTP
**Paradigm:** Single-player strictly

---

## 1. Core State & Persistence Registry (Module)

**Responsibilities:**
Maintains the centralized, version-controlled source of truth for the game world, player state, and NPC relationships. Ensures data remains decoupled from ephemeral scene nodes so saving, loading, and chunk unloads do not lose or duplicate data.

**Data Structures:**
*   `EntityState`: Dictionary mapping stable UUIDs to positional data and flags (e.g., `{ "uuid": "door_123", "is_unlocked": true }`).
*   `FactionState`: Dictionary mapping faction IDs to a relationship integer (`-100` to `100`), where thresholds define allied or hostile status.

**Public Interfaces & Contracts:**
*   `register_entity(uuid: String, initial_state: Dictionary) -> void`
*   `commit_state_delta(uuid: String, delta: Dictionary) -> void`
*   `get_faction_standing(faction_id: String) -> int`
*   `save_to_disk(slot: int) -> Error`

**Error Handling:**
Rejects duplicate UUID registrations with a logged warning. If save data schema mismatches the current version, routes to an idempotent migration pipeline.

**Test Strategy:**
Headless unit tests confirming that saving, reloading, and unloading a chunk perfectly restores an entity's modified state without duplication.

**Integration Points & Coupling Risks:**
*   **Coupling Risk:** High. Every other system depends on this. It must remain purely data-driven and hold zero references to Godot `Node3D` instances.

---

## 2. World & Scene Manager (Module)

**Responsibilities:**
Manages dynamic loading of the environment to fit within the 16 GB memory budget. Street-to-street traversal is handled via background chunk streaming, while detailed interiors are handled via efficient scene transitions (brief fades).

**Data Structures:**
*   `ChunkManifest`: Array of adjacent chunk IDs.
*   `LoadState`: Enum (`UNLOADED`, `PRELOADING`, `ACTIVE`).

**Public Interfaces & Contracts:**
*   `request_interior_transition(scene_path: String) -> void`: Triggers a blocking scene fade.
*   `update_player_position(pos: Vector3) -> void`: Evaluates spatial hysteresis margins to stream exterior chunks.

**Error Handling:**
If an interior scene path is invalid, falls back to the current scene and logs a pathing error. Fails gracefully if background resource loading times out.

**Test Strategy:**
Automated boundary regression: instantiate player at a chunk boundary, force rapid crossing back and forth, and verify memory doesn't leak and main-thread hitching stays within frame budget.

**Integration Points & Coupling Risks:**
*   Interacts with the **Persistence Registry** to hydrate nodes as they spawn.
*   **Coupling Risk:** Handoffs for AI navigation meshes across dynamically loaded exterior chunks are notoriously fragile and must be tightly synchronized.

---

## 3. Player, Health & Combat Core (Module)

**Responsibilities:**
Handles first-person camera, movement, inputs, aiming, and resolution of damage.

**Data Structures:**
*   `HealthState`: Holds `current_hp` and `max_hp`.
*   `HitResult`: Struct containing `hit_position`, `surface_normal`, `target_node`, and `damage_applied`.

**Public Interfaces & Contracts:**
*   `apply_damage(amount: int, source_faction: String) -> void`
*   `heal(amount: int) -> void`: Restores `current_hp` up to `max_hp`.
*   `fire_weapon(weapon_stats: Resource) -> HitResult`: Casts hitscan rays or spawns projectiles based on weapon type.

**Error Handling:**
Clamps healing and damage inputs to prevent negative health or overflow.

**Test Strategy:**
Unit tests for HP math (clamping, death triggers). Raycast tests ensuring muzzle obstruction properly registers physical cover.

**Integration Points & Coupling Risks:**
*   Listens to the **Inventory Module** for active weapon parameters.
*   Emits `on_death` signals to trigger checkpoints.

---

## 4. Inventory & Equipment (Module)

**Responsibilities:**
Manages all player possessions using a slot-based grid inventory. Manages weapon equip states, loot rarity tiers, and consumable consumption.

**Data Structures:**
*   `GridInventory`: 2D array representing slots.
*   `ItemInstance`: Struct with `uuid`, `item_id`, `grid_position`, `dimensions (w, h)`, and `rarity_tier`.
*   `AmmoPouch`: Dictionary tracking ammo counts keyed by weapon family (e.g., `PISTOL`, `SHOTGUN`, `RIFLE`).

**Public Interfaces & Contracts:**
*   `try_add_item(item: ItemInstance) -> bool`: Checks grid availability and inserts if space permits.
*   `consume_ammo(family: String, amount: int) -> bool`
*   `use_consumable(grid_pos: Vector2) -> void`

**Error Handling:**
If an item cannot fit in the grid upon loot pickup, rejects the transaction and leaves the physical loot drop in the world.

**Test Strategy:**
Automated grid-packing tests (testing overlaps, out-of-bounds insertions). Tests verifying save/load cycles do not reroll loot stats or duplicate grid items.

**Integration Points & Coupling Risks:**
*   Tightly coupled to UI rendering for the drag-and-drop grid. Separation of data (`GridInventory`) from presentation (`InventoryUI`) is critical.

---

## 5. Faction & Tactical AI (Module)

**Responsibilities:**
Drives deterministic enemy goon behavior and ambient population. Factions natively populate distinct districts.

**Data Structures:**
*   `AIState`: Enum (`IDLE`, `INVESTIGATE`, `COMBAT`, `FLEE`).
*   `PerceptionData`: Tracks known player position, line of sight, and sound events.

**Public Interfaces & Contracts:**
*   `notify_sound_event(position: Vector3, radius: float, faction_id: String) -> void`
*   `evaluate_target_hostility(target_faction: String) -> bool`: Queries Persistence Registry to check if relationship is allied or hostile.

**Error Handling:**
Failsafes for navigation map drops (if AI falls off navmesh, reset to last known valid point or despawn).

**Test Strategy:**
In-engine isolation tests: spawn an AI, trigger a sound event behind a wall, verify transition to `INVESTIGATE` and pathfinding success.

**Integration Points & Coupling Risks:**
*   Reads faction standing from the **Persistence Registry**.
*   **Coupling Risk:** Tactical AI must downgrade smoothly to simplified simulation records when chunks unload.

---

## 6. Hacking Subsystem (Module)

**Responsibilities:**
Executes immediate, frame-accurate cyber-actions against world elements. Uses an energy pool that regenerates automatically over time.

**Viable Hacks & Mechanical Impact:**
1.  **DISABLE_CAMERA:** Disables detection cone for X seconds. Use case: Stealth infiltration.
2.  **UNLOCK_DOOR:** Bypasses keyed locks. Use case: Accessing alternate routes or loot rooms.
3.  **TRIGGER_DISTRACTION:** Forces nearby AI into `INVESTIGATE` state at the target's location. Use case: Pulling guards out of choke points.
4.  **DISRUPT_IMPLANT:** Applies a 3-second stun and minor damage to an enemy. Use case: Interrupting enemy reloads or heavy attacks.
5.  **DISABLE_TURRET:** Flags a hostile automated turret as friendly or neutral for X seconds. Use case: Creating safe zones in heavy combat corridors.

**Data Structures:**
*   `HackingState`: Tracks `current_energy`, `max_energy`, and `regen_rate_per_sec`.
*   `ActiveHack`: Struct tracking `target_uuid`, `hack_type`, and `remaining_duration`.

**Public Interfaces & Contracts:**
*   `request_hack(target_node: Node3D, hack_type: int) -> bool`
*   `tick_energy_regen(delta: float) -> void`

**Error Handling:**
Rejects requests if energy is insufficient or the target lacks the appropriate hackable component tag.

**Test Strategy:**
Unit test energy depletion and regeneration math. Mock target nodes to ensure `UNLOCK_DOOR` strictly mutates the lock state without breaking pathing.

**Integration Points & Coupling Risks:**
*   Interacts directly with physical objects in the **World Manager** and entities in the **Tactical AI** system.

---

## 7. Generative NPC & Mission Orchestrator (Module)

**Responsibilities:**
Manages asynchronous HTTP inference requests to the local Ollama API. Uses strict JSON schemas to bridge generative dialogue (text-only, with basic generation audio blips) to deterministic world actions.

**Allowed Deterministic Actions:**
*   `offer_mission(template_id)`: Bridges to Mission Director.
*   `initiate_trade(inventory_id)`: Opens a merchant UI.
*   `accept_into_faction(faction_id)`: Mutates reputation in Persistence Registry so the faction becomes allied.
*   `begin_fight()`: Instantly shifts the NPC to hostile and triggers combat.
*   `disclose_fact(fact_id)`: Unlocks lore or an objective marker.
*   `give_item(item_id)`: Hands the player a quest item or reward.

**Data Structures:**
*   `ContextSnapshot`: JSON payload containing NPC identity, memory summary, eligible mission templates, and faction standing.
*   `LLMResponse`: Validated struct containing `dialogue_text` and `proposed_action`.

**Public Interfaces & Contracts:**
*   `submit_dialogue_request(npc_id: String, prompt: String) -> void`
*   `_on_http_response_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void`

**Error Handling:**
If Ollama times out (e.g., >15s), returns malformed JSON, or hallucinates an action parameter, the orchestrator instantly routes to the deterministic authored fallback dialogue. Checks `request_generation_id` to drop late responses if the player walked away.

**Test Strategy:**
Headless tests injecting broken JSON, out-of-bounds parameters, and late HTTP responses to guarantee the game never soft-locks or accepts invalid actions.

**Integration Points & Coupling Risks:**
*   **Coupling Risk:** High network/threading risk. Must remain completely non-blocking to the main Godot thread to prevent game freezes during inference.

---

## 8. Offline Asset Pipeline (Module)

**Responsibilities:**
Uses the newly installed Blender 5.2 to execute automated scripts for polycount checks, geometry node baking, and GLB exporting.

**Data Structures:**
*   Not applicable to runtime; outputs standardized `.glb` files and Godot resource metadata.

**Public Interfaces & Contracts:**
*   `export_modular_kit.py`: Headless Blender script to normalize UVs and bake PBR textures before Godot import.

**Integration Points & Coupling Risks:**
*   **Rigging Strategy:** Custom mechanical/hard-surface assets are built 100% in Blender. For humanoid enemy goons, we will integrate standard free 3rd-party skeletal rigs (e.g., Mixamo) to save baseline animation time, wrapping them in Godot `AnimationTree` state machines.