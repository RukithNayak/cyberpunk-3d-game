extends RefCounted

const HYDRATOR_PATH: String = "res://world/entity_hydrator.gd"
const PROJECTION_SCRIPT: Script = preload("res://tests/world/fixtures/persistent_projection.gd")
const UUID_DOOR: String = "00000000-0000-4000-8000-000000000031"
const UUID_LOOT: String = "00000000-0000-4000-8000-000000000032"
const UUID_NPC: String = "00000000-0000-4000-8000-000000000033"
const CHUNK_ID: String = "persist_room"
const SCENE_PATH: String = "user://world_03_projection_fixture.tscn"


func run(check: Callable) -> void:
	var script: Script = load(HYDRATOR_PATH) as Script
	check.call(script != null, "entity hydrator service script is available")
	if script == null:
		return
	var scene: PackedScene = _make_projection_scene()
	if scene == null:
		check.call(false, "projection fixture scene can be prepared")
		return
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_LOOT, "Loot", {"collected": false}), _descriptor(UUID_NPC, "NPC", {"trust": 1})], SCENE_PATH)
	check.call(manifest != null, "valid persistent projection manifest is accepted")
	if manifest == null:
		return
	check.call(manifest.get_chunk(CHUNK_ID).get("entities", []).size() == 3, "manifest publishes all authored persistent entity descriptors")
	var manager: WorldManager = WorldManager.new()
	check.call(manager.configure(manifest, 0.0, 0.0), "persistent test world manager configures")
	manager.update_player_position(Vector3(0.0, 0.0, 0.0))
	var generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: RefCounted = script.new()
	check.call(hydrator.call("configure", registry, manifest, manager), "hydrator accepts registry, manifest and lifecycle manager")
	var root: Node3D = scene.instantiate() as Node3D
	check.call(hydrator.call("prepare_chunk", CHUNK_ID, generation, root), "whole chunk defaults prepare before scene entry")
	check.call(registry.has_entity(UUID_DOOR) and registry.has_entity(UUID_LOOT) and registry.has_entity(UUID_NPC), "prepare registers all missing authored defaults")
	var door: Node3D = root.get_node("Door") as Node3D
	var loot: Node3D = root.get_node("Loot") as Node3D
	var npc: Node3D = root.get_node("NPC") as Node3D
	check.call(not door.get("interactions_enabled") and not loot.get("interactions_enabled") and not npc.get("interactions_enabled"), "prepared projections remain non-interactive")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(root)
	await tree.process_frame
	check.call(door.get("ready_state") == {"locked": true} and not bool(door.get("ready_interactions_enabled")), "door _ready observes hydrated state while interactions are disabled (%s / %s)" % [str(door.get("ready_state")), str(door.get("ready_interactions_enabled"))])
	check.call(hydrator.call("activate_chunk", CHUNK_ID, generation, root), "current prepared chunk activates")
	check.call(bool(door.get("interactions_enabled")) and hydrator.call("get_bound_entity_count") == 3, "activation enables exactly the live projections")
	check.call(not hydrator.call("prepare_chunk", CHUNK_ID, generation, root), "duplicate live chunk preparation is rejected")
	check.call(hydrator.call("commit_entity_delta", UUID_DOOR, {"locked": false}, generation), "door state mutation commits through current generation")
	check.call(registry.get_entity_state(UUID_DOOR).get("locked") == false and door.get("persistent_state").get("locked") == false, "door delta is authoritative immediately and reprojected")
	check.call(hydrator.call("commit_entity_delta", UUID_LOOT, {"collected": true}, generation), "loot collection tombstone commits")
	check.call(not loot.get("interactions_enabled") and hydrator.call("get_runtime_entity", UUID_LOOT) == null, "collected loot projection is disabled and unbound")
	check.call(hydrator.call("commit_entity_delta", UUID_NPC, {"trust": 4, "memory": {"met": true}}, generation), "NPC record delta commits")
	check.call(registry.get_entity_state(UUID_NPC) == {"trust": 4, "memory": {"met": true}}, "NPC record preserves recursively merged data")
	var invalidated: Array[Dictionary] = []
	hydrator.connect("interactions_invalidated", func(payload: Dictionary) -> void: invalidated.append(payload.duplicate(true)))
	manager.update_player_position(Vector3(100.0, 0.0, 0.0))
	check.call(invalidated.size() == 1 and invalidated[0].get("chunk_id") == CHUNK_ID and invalidated[0].get("lifecycle_generation") == manager.get_lifecycle_generation(CHUNK_ID), "pre-unload invalidates live interactions with retirement generation")
	check.call(hydrator.call("get_bound_entity_count") == 0 and not door.get("interactions_enabled"), "retirement revokes bindings and disables retained projection")
	check.call(registry.get_entity_state(UUID_DOOR).get("locked") == false and registry.get_entity_state(UUID_LOOT).get("collected") == true, "save-boundary registry reads include mutations before unload")
	var boundary_path: String = "user://world_03_boundary_save"
	var boundary_store: SaveStore = SaveStore.new(boundary_path, func() -> Dictionary:
		return {"player": {}, "entities": registry.snapshot_records(), "factions": {}, "domains": {}}
	, func(candidate: Dictionary) -> bool:
		return _snapshot_has_boundary_state(candidate)
	, func(_candidate: Dictionary) -> bool:
		return true
	)
	check.call(boundary_store.save_to_disk(1) == OK and boundary_store.load_from_disk(1) == OK, "real SaveStore round trips authoritative entity state at the unload boundary")
	var stale_generation: int = generation
	check.call(not hydrator.call("commit_entity_delta", UUID_DOOR, {"locked": true}, stale_generation), "stale generation cannot write after unload")
	tree.root.remove_child(root)
	manager.update_player_position(Vector3(0.0, 0.0, 0.0))
	var reverse_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	check.call(hydrator.call("prepare_chunk", CHUNK_ID, reverse_generation, root), "retained instance prepares again on reverse entry")
	check.call(root.get_node_or_null("Loot") == null, "tombstoned loot projection stays removed on backtracking")
	tree.root.add_child(root)
	check.call(hydrator.call("activate_chunk", CHUNK_ID, reverse_generation, root), "reverse-entry chunk activates with current generation")
	check.call(hydrator.call("get_runtime_entity", UUID_DOOR) == door and registry.get_entity_state(UUID_NPC).get("trust") == 4, "reverse order preserves UUID ownership and NPC state without duplicate bindings")
	var stale_live: int = reverse_generation - 1
	check.call(not hydrator.call("commit_entity_delta", UUID_NPC, {"trust": 99}, stale_live), "older generation cannot overwrite live progress")
	check.call(registry.get_entity_state(UUID_NPC).get("trust") == 4, "stale rejection leaves newer NPC record intact")
	hydrator.call("retire_chunk", CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID) + 1, root)
	tree.root.remove_child(root)
	root.free()
	var bad_manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_NPC, "Missing", {"trust": 1})], SCENE_PATH)
	if bad_manifest != null:
		var bad_registry: EntityRegistry = EntityRegistry.new()
		var bad_manager: WorldManager = WorldManager.new()
		bad_manager.configure(bad_manifest, 0.0, 0.0)
		bad_manager.update_player_position(Vector3.ZERO)
		var bad_hydrator: RefCounted = script.new()
		bad_hydrator.call("configure", bad_registry, bad_manifest, bad_manager)
		var bad_root: Node3D = scene.instantiate() as Node3D
		check.call(not bad_hydrator.call("prepare_chunk", CHUNK_ID, bad_manager.get_lifecycle_generation(CHUNK_ID), bad_root), "missing target rejects whole chunk preparation")
		check.call(not bad_registry.has_entity(UUID_DOOR) and bad_hydrator.call("get_bound_entity_count") == 0, "failed preparation registers no partial defaults or bindings")
		bad_root.free()
	else:
		check.call(false, "invalid-target manifest fixture is accepted for runtime atomicity check")
	var fresh_manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true})], SCENE_PATH)
	if fresh_manifest != null:
		var fresh_registry: EntityRegistry = EntityRegistry.new()
		var fresh_manager: WorldManager = WorldManager.new()
		fresh_manager.configure(fresh_manifest, 0.0, 0.0)
		fresh_manager.update_player_position(Vector3.ZERO)
		var fresh_hydrator: RefCounted = script.new()
		fresh_hydrator.call("configure", fresh_registry, fresh_manifest, fresh_manager)
		var fresh_root: Node3D = scene.instantiate() as Node3D
		fresh_hydrator.call("prepare_chunk", CHUNK_ID, fresh_manager.get_lifecycle_generation(CHUNK_ID), fresh_root)
		fresh_hydrator.call("activate_chunk", CHUNK_ID, fresh_manager.get_lifecycle_generation(CHUNK_ID), fresh_root)
		var forbidden_value: Node = Node.new()
		check.call(not fresh_hydrator.call("commit_entity_delta", UUID_DOOR, {"bad": forbidden_value}, fresh_manager.get_lifecycle_generation(CHUNK_ID)), "invalid data delta rejects without mutation")
		forbidden_value.free()
		check.call(fresh_registry.get_entity_state(UUID_DOOR) == {"locked": true}, "invalid delta has no partial authority effect")
		fresh_hydrator.call("retire_chunk", CHUNK_ID, fresh_manager.get_lifecycle_generation(CHUNK_ID), fresh_root)
		fresh_root.free()
	var cancel_manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true})], SCENE_PATH)
	if cancel_manifest != null:
		var cancel_registry: EntityRegistry = EntityRegistry.new()
		var cancel_manager: WorldManager = WorldManager.new()
		cancel_manager.configure(cancel_manifest, 0.0, 0.0)
		cancel_manager.update_player_position(Vector3.ZERO)
		var cancel_hydrator: RefCounted = script.new()
		cancel_hydrator.call("configure", cancel_registry, cancel_manifest, cancel_manager)
		var cancel_root: Node3D = scene.instantiate() as Node3D
		var cancel_projection: Node3D = cancel_root.get_node("Door") as Node3D
		cancel_projection.set("invalidation_callback", func() -> void: cancel_manager.update_player_position(Vector3(20.0, 0.0, 0.0)))
		check.call(not cancel_hydrator.call("prepare_chunk", CHUNK_ID, cancel_manager.get_lifecycle_generation(CHUNK_ID), cancel_root), "generation invalidation from projection callback cancels preparation")
		check.call(cancel_registry.has_entity(UUID_DOOR) and cancel_hydrator.call("get_bound_entity_count") == 0, "authored defaults may remain after callback cancellation without staged live ownership")
		cancel_root.free()
	else:
		check.call(false, "callback cancellation manifest fixture is available")
	_test_retirement_callback_reentry(check, script, scene)
	_test_same_instance_retirement_reentry(check, script, scene)
	_test_activation_callback_cancellation(check, script, scene)
	_test_tombstone_callback_reentry(check, script, scene)
	_test_destroyed_record_reentry(check, script, scene)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(boundary_path.path_join("slot_01.save")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(boundary_path))


func _descriptor(uuid: String, node_path: String, initial_state: Dictionary) -> Dictionary:
	return {"uuid": uuid, "node_path": node_path, "initial_state": initial_state}


func _manifest(entities: Array[Dictionary], scene_path: String) -> ChunkManifest:
	var manifest: ChunkManifest = ChunkManifest.new()
	var records: Array[Dictionary] = [{
		"id": CHUNK_ID,
		"bounds": AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0)),
		"scene_path": scene_path,
		"adjacent": [],
		"entities": entities
	}]
	return manifest if manifest.configure(records) else null


func _make_projection_scene() -> PackedScene:
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "ProjectionRoom"
	for projection_name: String in ["Door", "Loot", "NPC"]:
		var projection: Node3D = PROJECTION_SCRIPT.new() as Node3D
		projection.name = projection_name
		scene_root.add_child(projection)
		projection.owner = scene_root
	var packed: PackedScene = PackedScene.new()
	if packed.pack(scene_root) != OK:
		scene_root.free()
		return null
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	scene_root.free()
	return packed if error == OK else null


func _snapshot_has_boundary_state(candidate: Dictionary) -> bool:
	if not candidate.has("entities") or typeof(candidate["entities"]) != TYPE_ARRAY:
		return false
	var records: Dictionary = {}
	for record: Dictionary in candidate["entities"]:
		records[record["uuid"]] = record["state"]
	return records.get(UUID_DOOR, {}).get("locked") == false and records.get(UUID_LOOT, {}).get("collected") == true


func _test_destroyed_record_reentry(check: Callable, script: Script, scene: PackedScene) -> void:
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_NPC, "NPC", {"destroyed": false, "trust": 1})], SCENE_PATH)
	var manager: WorldManager = WorldManager.new()
	assert(manager.configure(manifest, 0.0, 0.0))
	manager.update_player_position(Vector3.ZERO)
	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity(UUID_NPC, {"destroyed": true, "trust": 7})
	var hydrator: RefCounted = script.new()
	assert(hydrator.call("configure", registry, manifest, manager))
	var instance: Node3D = scene.instantiate() as Node3D
	var generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	var prepared: bool = hydrator.call("prepare_chunk", CHUNK_ID, generation, instance)
	check.call(prepared and instance.get_node_or_null("NPC") == null and hydrator.call("activate_chunk", CHUNK_ID, generation, instance), "saved destroyed record suppresses an authored live NPC projection")
	check.call(not hydrator.call("commit_entity_delta", UUID_NPC, {"destroyed": false}, generation) and registry.get_entity_state(UUID_NPC) == {"destroyed": true, "trust": 7}, "suppressed destroyed identity cannot be revived by an interaction")
	manager.update_player_position(Vector3(20, 0, 0))
	instance.free()
	manager.update_player_position(Vector3.ZERO)
	instance = scene.instantiate() as Node3D
	check.call(hydrator.call("prepare_chunk", CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID), instance) and instance.get_node_or_null("NPC") == null and registry.get_entity_state(UUID_NPC) == {"destroyed": true, "trust": 7}, "destroyed NPC stays absent on fresh-instance backtracking with stable saved data")
	hydrator.call("retire_chunk", CHUNK_ID, manager.get_lifecycle_generation(CHUNK_ID), instance)
	instance.free()


func _test_retirement_callback_reentry(check: Callable, script: Script, scene: PackedScene) -> void:
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_LOOT, "Loot", {"collected": false}), _descriptor(UUID_NPC, "NPC", {"trust": 1})], SCENE_PATH)
	var manager: WorldManager = WorldManager.new()
	manager.configure(manifest, 0.0, 0.0)
	manager.update_player_position(Vector3.ZERO)
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: RefCounted = script.new()
	hydrator.call("configure", registry, manifest, manager)
	var old_root: Node3D = scene.instantiate() as Node3D
	var old_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	hydrator.call("prepare_chunk", CHUNK_ID, old_generation, old_root)
	hydrator.call("activate_chunk", CHUNK_ID, old_generation, old_root)
	var callback_fired: Array[bool] = [false]
	var newer_root: Array[Node3D] = []
	var old_door: Node3D = old_root.get_node("Door") as Node3D
	old_door.set("invalidation_callback", func() -> void:
		if callback_fired[0]:
			return
		callback_fired[0] = true
		manager.update_player_position(Vector3(100.0, 0.0, 0.0))
		manager.update_player_position(Vector3.ZERO)
		var new_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
		var replacement: Node3D = scene.instantiate() as Node3D
		newer_root.append(replacement)
		check.call(hydrator.call("prepare_chunk", CHUNK_ID, new_generation, replacement), "retirement callback can prepare a newly entered generation")
		check.call(hydrator.call("activate_chunk", CHUNK_ID, new_generation, replacement), "retirement callback can activate a newly entered generation")
	)
	manager.update_player_position(Vector3(100.0, 0.0, 0.0))
	var replacement_door: Node3D = newer_root[0].get_node("Door") as Node3D if not newer_root.is_empty() else null
	check.call(replacement_door != null and bool(replacement_door.get("interactions_enabled")) and hydrator.call("get_runtime_entity", UUID_DOOR) == replacement_door, "older retirement callback preserves newer generation bindings")
	check.call(hydrator.call("commit_entity_delta", UUID_DOOR, {"locked": false}, manager.get_lifecycle_generation(CHUNK_ID)), "newer binding remains writable after reentrant retirement")
	old_root.free()
	if not newer_root.is_empty():
		newer_root[0].free()


func _test_activation_callback_cancellation(check: Callable, script: Script, scene: PackedScene) -> void:
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_LOOT, "Loot", {"collected": false}), _descriptor(UUID_NPC, "NPC", {"trust": 1})], SCENE_PATH)
	var manager: WorldManager = WorldManager.new()
	manager.configure(manifest, 0.0, 0.0)
	manager.update_player_position(Vector3.ZERO)
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: RefCounted = script.new()
	hydrator.call("configure", registry, manifest, manager)
	var root: Node3D = scene.instantiate() as Node3D
	var generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	hydrator.call("prepare_chunk", CHUNK_ID, generation, root)
	var callback_fired: Array[bool] = [false]
	var door: Node3D = root.get_node("Door") as Node3D
	door.set("invalidation_callback", func() -> void:
		if callback_fired[0]:
			return
		callback_fired[0] = true
		manager.update_player_position(Vector3(100.0, 0.0, 0.0))
	)
	check.call(not hydrator.call("activate_chunk", CHUNK_ID, generation, root), "activation callback invalidation rejects the stale generation")
	check.call(not door.get("interactions_enabled") and not (root.get_node("Loot") as Node3D).get("interactions_enabled") and not (root.get_node("NPC") as Node3D).get("interactions_enabled"), "activation cancellation leaves every staged projection disabled")
	root.free()


func _test_same_instance_retirement_reentry(check: Callable, script: Script, scene: PackedScene) -> void:
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_LOOT, "Loot", {"collected": false})], SCENE_PATH)
	var manager: WorldManager = WorldManager.new()
	manager.configure(manifest, 0.0, 0.0)
	manager.update_player_position(Vector3.ZERO)
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: RefCounted = script.new()
	hydrator.call("configure", registry, manifest, manager)
	var retained_root: Node3D = scene.instantiate() as Node3D
	var old_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	hydrator.call("prepare_chunk", CHUNK_ID, old_generation, retained_root)
	hydrator.call("activate_chunk", CHUNK_ID, old_generation, retained_root)
	var callback_fired: Array[bool] = [false]
	var door: Node3D = retained_root.get_node("Door") as Node3D
	var loot: Node3D = retained_root.get_node("Loot") as Node3D
	door.set("invalidation_callback", func() -> void:
		if callback_fired[0]:
			return
		callback_fired[0] = true
		manager.update_player_position(Vector3.ZERO)
		var new_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
		check.call(hydrator.call("prepare_chunk", CHUNK_ID, new_generation, retained_root), "retirement callback prepares the retained instance at its newer generation")
		check.call(hydrator.call("activate_chunk", CHUNK_ID, new_generation, retained_root), "retirement callback reactivates the retained instance")
	)
	manager.update_player_position(Vector3(100.0, 0.0, 0.0))
	var new_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	check.call(bool(door.get("interactions_enabled")) and bool(loot.get("interactions_enabled")), "old retirement leaves every same-instance newer projection enabled")
	check.call(hydrator.call("get_runtime_entity", UUID_LOOT) == loot and hydrator.call("commit_entity_delta", UUID_LOOT, {"collected": false, "visited": true}, new_generation), "same-instance newer binding remains readable and writable")
	retained_root.free()


func _test_tombstone_callback_reentry(check: Callable, script: Script, scene: PackedScene) -> void:
	var manifest: ChunkManifest = _manifest([_descriptor(UUID_DOOR, "Door", {"locked": true}), _descriptor(UUID_LOOT, "Loot", {"collected": false}), _descriptor(UUID_NPC, "NPC", {"trust": 1})], SCENE_PATH)
	var manager: WorldManager = WorldManager.new()
	manager.configure(manifest, 0.0, 0.0)
	manager.update_player_position(Vector3.ZERO)
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: RefCounted = script.new()
	hydrator.call("configure", registry, manifest, manager)
	var old_root: Node3D = scene.instantiate() as Node3D
	var generation: int = manager.get_lifecycle_generation(CHUNK_ID)
	hydrator.call("prepare_chunk", CHUNK_ID, generation, old_root)
	hydrator.call("activate_chunk", CHUNK_ID, generation, old_root)
	var callback_fired: Array[bool] = [false]
	var nested_write_accepted: Array[bool] = [false]
	var newer_root: Array[Node3D] = []
	var loot: Node3D = old_root.get_node("Loot") as Node3D
	loot.set("invalidation_callback", func() -> void:
		if callback_fired[0]:
			return
		callback_fired[0] = true
		nested_write_accepted[0] = hydrator.call("commit_entity_delta", UUID_LOOT, {"collected": false}, generation)
		manager.update_player_position(Vector3(100.0, 0.0, 0.0))
		manager.update_player_position(Vector3.ZERO)
		var new_generation: int = manager.get_lifecycle_generation(CHUNK_ID)
		var replacement: Node3D = scene.instantiate() as Node3D
		newer_root.append(replacement)
		check.call(hydrator.call("prepare_chunk", CHUNK_ID, new_generation, replacement), "tombstone callback prepares a newer chunk generation")
		check.call(hydrator.call("activate_chunk", CHUNK_ID, new_generation, replacement), "tombstone callback activates a newer chunk generation")
	)
	check.call(hydrator.call("commit_entity_delta", UUID_LOOT, {"collected": true}, generation), "collected tombstone commits through a reentrant projection callback")
	var replacement_door: Node3D = newer_root[0].get_node("Door") as Node3D if not newer_root.is_empty() else null
	var replacement_npc: Node3D = newer_root[0].get_node("NPC") as Node3D if not newer_root.is_empty() else null
	check.call(replacement_door != null and replacement_npc != null and hydrator.call("get_runtime_entity", UUID_DOOR) == replacement_door and hydrator.call("get_runtime_entity", UUID_NPC) == replacement_npc, "tombstone cleanup preserves other newer-generation entity bindings")
	check.call(not newer_root.is_empty() and newer_root[0].get_node_or_null("Loot") == null, "newer-generation tombstoned projection remains suppressed")
	check.call(not nested_write_accepted[0] and registry.get_entity_state(UUID_LOOT).get("collected") == true, "tombstone revokes its old owner before callback can issue a reentrant stale delta")
	old_root.free()
	if not newer_root.is_empty():
		newer_root[0].free()
