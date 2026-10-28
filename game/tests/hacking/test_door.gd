extends RefCounted

const DOOR_PATH: String = "res://features/hacking/targets/hackable_door.gd"


class MockDoorTarget extends Node3D:
	var state: Dictionary = {"locked": true, "open": false, "quest_flag": "preserved"}

	func _enter_tree() -> void:
		add_to_group(&"hackable_door")

	func get_persistent_uuid() -> String:
		return "00000000-0000-4000-8000-000000000045"

	func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
		return int(definition.get("ability_id")) == HackDefinition.Ability.UNLOCK_DOOR and bool(state["locked"])

	func apply_hack(definition: Resource, _operator: Node3D) -> bool:
		if not can_accept_hack(definition, _operator):
			return false
		state["locked"] = false
		return true


func run(check: Callable) -> void:
	var door_script: Script = load(DOOR_PATH) as Script
	check.call(door_script != null, "HACK-02 door target adapter is available")
	if door_script == null:
		return
	await _test_mock_target_mutates_lock_only(check)
	await _test_unlock_traversal_and_persistence(check, door_script)
	await _test_restricted_repeat_and_disappearing_target(check, door_script)


func _test_mock_target_mutates_lock_only(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var operator: Node3D = Node3D.new()
	var target: MockDoorTarget = MockDoorTarget.new()
	target.position = Vector3(0.0, 0.0, -2.0)
	tree.root.add_child(operator)
	tree.root.add_child(target)
	await tree.process_frame
	var state: HackingState = HackingState.new()
	state.configure(100.0, 8.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(service.request_hack(target, HackDefinition.Ability.UNLOCK_DOOR), "mock locked door accepts the unlock request")
	check.call(target.state == {"locked": false, "open": false, "quest_flag": "preserved"}, "mock target changes only its lock flag and preserves unrelated state")
	tree.root.remove_child(target)
	target.free()
	tree.root.remove_child(operator)
	operator.free()


func _test_unlock_traversal_and_persistence(check: Callable, door_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var uuid: String = "00000000-0000-4000-8000-000000000041"
	var manifest: ChunkManifest = _manifest(uuid)
	var manager: WorldManager = WorldManager.new()
	check.call(manager.configure(manifest, 0.0, 0.0), "door fixture world manager configures")
	manager.update_player_position(Vector3.ZERO)
	var generation: int = manager.get_lifecycle_generation("door_room")
	var registry: EntityRegistry = EntityRegistry.new()
	var hydrator: EntityHydrator = EntityHydrator.new()
	check.call(hydrator.configure(registry, manifest, manager), "door fixture hydrator configures")
	var room: Node3D = _room(door_script, uuid, hydrator, generation)
	check.call(hydrator.prepare_chunk("door_room", generation, room), "locked door hydrates with current lifecycle generation")
	tree.root.add_child(room)
	await tree.physics_frame
	check.call(hydrator.activate_chunk("door_room", generation, room), "door fixture activates")
	var door: Node3D = room.get_node("Door") as Node3D
	var player: CharacterBody3D = room.get_node("Player") as CharacterBody3D
	check.call(not bool((door.get_node("CollisionShape3D") as CollisionShape3D).disabled), "locked door starts with an enabled blocking shape")
	check.call(player.test_move(player.global_transform, Vector3(0.0, 0.0, -3.0)), "closed door blocks traversal before unlock")
	var state: HackingState = HackingState.new()
	var service: HackingService = HackingService.new()
	var operator: Node3D = Node3D.new()
	room.add_child(operator)
	operator.position = Vector3(0.0, 0.0, 2.0)
	state.configure(100.0, 8.0, 100.0)
	var definitions: Array[HackDefinition] = service.get_default_definitions()
	check.call(service.configure(operator, state, definitions, func(_from: Vector3, _to: Vector3) -> bool: return true), "door fixture hacking service configures")
	var committed: Array[Dictionary] = []
	door.door_state_changed.connect(func(payload: Dictionary) -> void: committed.append(payload.duplicate(true)))
	var unlock_requested: bool = service.request_hack(door, HackDefinition.Ability.UNLOCK_DOOR)
	check.call(unlock_requested, "eligible locked door accepts UNLOCK_DOOR (reason=%s enabled=%s locked=%s uuid=%s)" % [str(service.get_last_rejection_reason()), str(door.get("interactions_enabled")), str(door.get("locked")), str(door.call("get_persistent_uuid"))])
	await tree.physics_frame
	check.call(registry.get_entity_state(uuid) == {"locked": false, "open": true}, "unlock commits only durable lock/open flags to the entity registry")
	check.call(not bool(door.get("locked")) and bool(door.get("open")) and bool((door.get_node("CollisionShape3D") as CollisionShape3D).disabled), "successful unlock opens door and disables its blocking collider")
	check.call(not player.test_move(player.global_transform, Vector3(0.0, 0.0, -3.0)), "player can traverse after the door collider is disabled")
	check.call(committed.size() == 1 and committed[0].get("open") == true, "door emits state feedback after authoritative commit")
	var save_directory: String = "user://hack_door_save"
	var registry_holder: Array[EntityRegistry] = [registry]
	var store: SaveStore = SaveStore.new(save_directory, func() -> Dictionary:
		return {"player": {}, "entities": registry_holder[0].snapshot_records(), "factions": {}, "domains": {}}
	, func(_candidate: Dictionary) -> bool:
		return true
	, func(candidate: Dictionary) -> bool:
		var prepared: Dictionary = registry_holder[0].prepare_snapshot_replacement(candidate.get("entities", []))
		if not prepared.get("ok", false):
			return false
		registry_holder[0].commit_prepared_snapshot(prepared)
		return true
	)
	check.call(store.save_to_disk(1) == OK, "open door record saves through CORE-03 SaveStore")
	manager.update_player_position(Vector3(40.0, 0.0, 0.0))
	hydrator.retire_chunk("door_room", manager.get_lifecycle_generation("door_room"), room)
	tree.root.remove_child(room)
	room.free()
	registry_holder[0] = EntityRegistry.new()
	check.call(store.load_from_disk(1) == OK and registry_holder[0].get_entity_state(uuid) == {"locked": false, "open": true}, "saved open state restores into a fresh registry after unload")
	manager.update_player_position(Vector3.ZERO)
	var fresh_generation: int = manager.get_lifecycle_generation("door_room")
	var reloaded_room: Node3D = _room(door_script, uuid, hydrator, fresh_generation)
	check.call(hydrator.prepare_chunk("door_room", fresh_generation, reloaded_room), "fresh door projection hydrates after unload/re-entry")
	tree.root.add_child(reloaded_room)
	await tree.physics_frame
	check.call(hydrator.activate_chunk("door_room", fresh_generation, reloaded_room), "fresh door projection activates")
	var reloaded_player: CharacterBody3D = reloaded_room.get_node("Player") as CharacterBody3D
	check.call(bool(reloaded_room.get_node("Door").get("open")) and bool((reloaded_room.get_node("Door/CollisionShape3D") as CollisionShape3D).disabled) and not reloaded_player.test_move(reloaded_player.global_transform, Vector3(0.0, 0.0, -3.0)), "saved open door remains traversable on fresh projection reload")
	hydrator.retire_chunk("door_room", fresh_generation, reloaded_room)
	tree.root.remove_child(reloaded_room)
	reloaded_room.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_directory.path_join("slot_01.save")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_directory))


func _test_restricted_repeat_and_disappearing_target(check: Callable, door_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var registry: EntityRegistry = EntityRegistry.new()
	var uuid: String = "00000000-0000-4000-8000-000000000042"
	var normal_uuid: String = "00000000-0000-4000-8000-000000000043"
	var disappearing_uuid: String = "00000000-0000-4000-8000-000000000044"
	var manifest: ChunkManifest = _manifest(uuid, true, [normal_uuid, disappearing_uuid])
	var manager: WorldManager = WorldManager.new()
	manager.configure(manifest, 0.0, 0.0)
	manager.update_player_position(Vector3.ZERO)
	var generation: int = manager.get_lifecycle_generation("door_room")
	var hydrator: EntityHydrator = EntityHydrator.new()
	hydrator.configure(registry, manifest, manager)
	var room: Node3D = _room(door_script, uuid, hydrator, generation, true, [normal_uuid, disappearing_uuid])
	hydrator.prepare_chunk("door_room", generation, room)
	tree.root.add_child(room)
	await tree.physics_frame
	hydrator.activate_chunk("door_room", generation, room)
	var door: Node3D = room.get_node("Door") as Node3D
	var operator: Node3D = Node3D.new()
	room.add_child(operator)
	operator.position = Vector3(0.0, 0.0, 2.0)
	var state: HackingState = HackingState.new()
	state.configure(100.0, 8.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	var energy_before: float = state.current_energy
	check.call(not service.request_hack(door, HackDefinition.Ability.UNLOCK_DOOR) and is_equal_approx(state.current_energy, energy_before) and registry.get_entity_state(uuid).get("locked") == true, "mission-critical door rejects without charge or state change")
	var normal_door: Node3D = room.get_node("Door_1") as Node3D
	await tree.physics_frame
	check.call(service.request_hack(normal_door, HackDefinition.Ability.UNLOCK_DOOR), "ordinary door accepts first unlock")
	var energy_after_unlock: float = state.current_energy
	check.call(not service.request_hack(normal_door, HackDefinition.Ability.UNLOCK_DOOR) and is_equal_approx(state.current_energy, energy_after_unlock), "rehacking an unlocked door rejects without a second charge")
	var disappearing: Node3D = room.get_node("Door_2") as Node3D
	await tree.physics_frame
	check.call(service.request_hack(disappearing, HackDefinition.Ability.UNLOCK_DOOR), "second ordinary door can unlock before disappearing")
	var before_disappear: float = state.current_energy
	disappearing.queue_free()
	check.call(not service.request_hack(disappearing, HackDefinition.Ability.UNLOCK_DOOR) and is_equal_approx(state.current_energy, before_disappear), "disappearing target rejects without charging")
	hydrator.retire_chunk("door_room", generation, room)
	tree.root.remove_child(room)
	room.free()
	await tree.process_frame


func _manifest(uuid: String, _mission_critical: bool = false, extra_uuids: Array[String] = []) -> ChunkManifest:
	var manifest: ChunkManifest = ChunkManifest.new()
	var entities: Array[Dictionary] = [{"uuid": uuid, "node_path": "Door", "initial_state": {"locked": true, "open": false}}]
	for index: int in range(extra_uuids.size()):
		entities.append({"uuid": extra_uuids[index], "node_path": "Door_%d" % (index + 1), "initial_state": {"locked": true, "open": false}})
	return manifest if manifest.configure([{
		"id": "door_room",
		"bounds": AABB(Vector3(-5.0, -5.0, -5.0), Vector3(10.0, 10.0, 10.0)),
		"scene_path": "res://tests/scenes/player_movement.tscn",
		"adjacent": [],
		"entities": entities
	}]) else null


func _room(door_script: Script, uuid: String, hydrator: EntityHydrator, generation: int, mission_critical: bool = false, extra_uuids: Array[String] = []) -> Node3D:
	var room: Node3D = Node3D.new()
	room.name = "Room"
	var door: Node3D = _door(door_script, uuid, hydrator, generation, mission_critical)
	room.add_child(door)
	for index: int in range(extra_uuids.size()):
		var extra_door: Node3D = _door(door_script, extra_uuids[index], hydrator, generation, false)
		extra_door.name = "Door_%d" % (index + 1)
		room.add_child(extra_door)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	room.add_child(floor_body)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.2, 8.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.95, 1.2)
	room.add_child(player)
	var player_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.8
	player_shape.shape = capsule
	player.add_child(player_shape)
	return room


func _door(door_script: Script, uuid: String, hydrator: EntityHydrator, generation: int, mission_critical: bool) -> Node3D:
	var door: Node3D = door_script.new() as Node3D
	door.name = "Door"
	door.set("persistent_uuid", uuid)
	door.set("mission_critical", mission_critical)
	door.call("configure_lifecycle", hydrator, generation)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.4, 2.2, 0.2)
	shape.shape = box
	door.add_child(shape)
	return door
