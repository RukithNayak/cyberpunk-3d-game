extends Node3D
## Streaming/navigation integration fixture for WORLD-05.

const GOON_SCENE_PATH: String = "res://features/npcs/goon.tscn"
const CHUNK_A_PATH: String = "res://tests/world/fixtures/navigation_chunk_a.tscn"
const CHUNK_B_PATH: String = "res://tests/world/fixtures/navigation_chunk_b.tscn"
const NPC_UUID: String = "123e4567-e89b-42d3-a456-426614174021"
const PLAYER_FACTION: String = "player"
const GANG_FACTION: String = "gang_a"
const MAX_WAIT_FRAMES: int = 240


func run(check: Callable) -> void:
	var service_script: Script = load("res://world/navigation_handoff.gd") as Script
	var chunk_script: Script = load("res://tests/world/fixtures/navigation_chunk.gd") as Script
	check.call(service_script != null, "WORLD-05 navigation handoff coordinator is available")
	check.call(chunk_script != null, "WORLD-05 streamed navigation chunk fixture is available")
	if service_script == null or chunk_script == null:
		return
	await _test_streamed_pursuit_and_reverse_handoff(check, service_script)


func _test_streamed_pursuit_and_reverse_handoff(check: Callable, service_script: Script) -> void:
	var manifest: ChunkManifest = ChunkManifest.new()
	check.call(manifest.configure(_chunk_records()), "WORLD-05 two-chunk navigation manifest configures")
	var manager: WorldManager = WorldManager.new()
	check.call(manager.configure(manifest, 1.0, 0.75), "WORLD-05 lifecycle configures around the seam")
	var chunk_root: Node3D = Node3D.new()
	chunk_root.name = "StreamedChunks"
	add_child(chunk_root)
	var actor_root: Node3D = Node3D.new()
	actor_root.name = "PersistentNPCs"
	add_child(actor_root)
	var loader: ChunkLoader = ChunkLoader.new()
	add_child(loader)
	check.call(loader.configure(manager, manifest, chunk_root), "WORLD-05 uses the real threaded chunk loader")
	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity(NPC_UUID, {"spawn": "district_a"})
	var factions: FactionState = FactionState.new([GANG_FACTION, PLAYER_FACTION])
	factions.set_faction_standing(PLAYER_FACTION, -50)
	var handoff: Node = service_script.new() as Node
	add_child(handoff)
	var simulation_script: Script = load("res://features/npcs/npc_simulation_record.gd") as Script
	var simulation: RefCounted = simulation_script.new() as RefCounted
	check.call(bool(simulation.call("configure", registry, manager, factions, Callable(handoff, "is_navigation_ready_for_actor"))), "AI-04 registry service accepts world navigation readiness")
	var configured: bool = bool(handoff.call("configure", manager, manifest, loader, simulation, actor_root))
	check.call(configured, "WORLD-05 connects streaming, AI records, and persistent actor ownership")
	if not configured:
		return
	check.call(String(handoff.call("_owner_at_position", Vector3(0.0, 0.0, 0.0))) == "district_a", "exact seam ownership is deterministic for the shared boundary")

	manager.update_player_position(Vector3(-3.0, 0.0, 0.0))
	var chunk_a_generation: int = manager.get_lifecycle_generation("district_a")
	check.call(await _wait_for_chunk(manager, loader, "district_a", chunk_a_generation), "first navigation chunk activates through threaded loading")
	var actor: TacticalAgent = await _spawn_goon(loader.get_active_instance("district_a"), factions, Vector3(-3.0, 0.0, 0.0))
	(actor.get_node("Perception") as Node3D).position.y = 0.9
	var target: TestTarget = TestTarget.new()
	target.name = "PlayerTarget"
	target.position = Vector3(7.0, 1.0, 0.0)
	add_child(target)
	actor.call("set_candidate_target", target, PLAYER_FACTION)
	check.call(bool(handoff.call("attach_actor", NPC_UUID, "district_a", chunk_a_generation, actor)), "NPC acquires one navigation-aware UUID owner")
	check.call(await _wait_for_navigation(handoff, actor), "AI begins after its current chunk map synchronizes")
	check.call(actor.process_ai, "AI remains active while its current chunk is the only desired navigation map")

	manager.update_player_position(Vector3(-0.5, 0.0, 0.0))
	var chunk_b_generation: int = manager.get_lifecycle_generation("district_b")
	handoff.call("_process", 1.0 / 60.0)
	var actor_driver: Node = actor.get_node("NavigationDriver")
	check.call(not actor.process_ai and not bool(actor_driver.get("process_navigation")), "seam crossing pauses AI and movement while the destination map synchronizes")
	check.call(await _wait_for_chunk(manager, loader, "district_b", chunk_b_generation), "destination chunk activates while the source remains loaded")
	var navigation_ready: bool = await _wait_for_navigation(handoff, actor)
	if not navigation_ready:
		print("WORLD05_NAV_DIAG desired=%s actor_owner=%s actor_pos=%s ai=%s nav=%s map_active=%s map_iteration=%d chunks=%s" % [manager.get_desired_chunk_ids(), handoff.call("get_actor_chunk_id", NPC_UUID), actor.global_position, actor.process_ai, actor.get_node("NavigationDriver").get("navigation_ready"), NavigationServer3D.map_is_active(actor.get_world_3d().navigation_map), NavigationServer3D.map_get_iteration_id(actor.get_world_3d().navigation_map), handoff.call("get_navigation_debug_state")])
	check.call(navigation_ready, "AI resumes only after both chunk regions synchronize")
	check.call(actor.process_ai and bool(handoff.call("is_navigation_ready_for_actor", actor)), "navigation readiness is published to the actor after synchronization")
	check.call(not bool(simulation.call("transfer_actor", NPC_UUID, "district_a", chunk_a_generation + 99, "district_b", chunk_b_generation, actor)) and String(simulation.call("get_actor_chunk_id", NPC_UUID)) == "district_a", "stale source generation cannot transfer UUID ownership")
	check.call(not bool(simulation.call("transfer_actor", NPC_UUID, "district_a", chunk_a_generation, "district_b", chunk_b_generation + 99, actor)) and String(simulation.call("get_actor_chunk_id", NPC_UUID)) == "district_a", "stale destination generation cannot transfer UUID ownership")
	var started_x: float = actor.global_position.x
	var crossed: bool = await _wait_for_actor_owner(handoff, actor, "district_b")
	if not crossed:
		var driver: Node = actor.get_node("NavigationDriver")
		var navigation_agent: NavigationAgent3D = driver.get_node("NavigationAgent3D") as NavigationAgent3D
		var world_map: RID = actor.get_world_3d().navigation_map
		print("WORLD05_MOVE_DIAG pos=%s target=%s visible=%s state=%s substate=%s intent=%s destination=%s driver=%s nav_ready=%s path=%s map_path=%s" % [actor.global_position, target.global_position, actor.get_node("Perception").get("data").get("has_visual_contact"), actor.call("get_state_name"), actor.call("get_substate_name"), actor.get("has_movement_intent"), actor.get("movement_destination"), driver.get("debug_state"), driver.get("navigation_ready"), navigation_agent.get_current_navigation_path(), NavigationServer3D.map_get_path(world_map, actor.global_position, target.global_position, true)])
	check.call(crossed and actor.global_position.x > 0.0 and actor.global_position.x > started_x, "hostile pursuit follows the target across the connected chunk seam")
	if not crossed:
		return
	check.call(actor.get_parent() == actor_root and simulation.call("get_active_actor", NPC_UUID) == actor, "seam handoff keeps exactly one actor under persistent ownership")
	var transferred_count: int = int(handoff.call("get_transfer_count", NPC_UUID))
	check.call(transferred_count == 1, "stable UUID transfers to the destination exactly once")

	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	check.call(await _wait_until_unloaded(loader, "district_a"), "source chunk unloads after the actor transfers out")
	check.call(is_instance_valid(actor) and actor.process_ai and simulation.call("get_active_actor", NPC_UUID) == actor, "source unload neither strands nor duplicates the transferred actor")

	manager.update_player_position(Vector3(-1.5, 0.0, 0.0))
	var returning_generation: int = manager.get_lifecycle_generation("district_a")
	check.call(not await _wait_for_navigation(handoff, actor, 2), "returning AI pauses while a fresh chunk generation synchronizes")
	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	await _wait_frames(4)
	check.call(manager.get_lifecycle_generation("district_a") > returning_generation and String(handoff.call("get_actor_chunk_id", NPC_UUID)) == "district_b" and bool(handoff.call("is_navigation_ready_for_actor", actor)), "reversing direction invalidates the stale generation while preserving valid destination navigation")
	manager.update_player_position(Vector3(-1.5, 0.0, 0.0))
	returning_generation = manager.get_lifecycle_generation("district_a")
	check.call(await _wait_for_chunk(manager, loader, "district_a", returning_generation), "backtracking reactivates the source chunk with a fresh generation")
	target.global_position = Vector3(-7.0, 1.0, 0.0)
	check.call(await _wait_for_navigation(handoff, actor), "AI resumes after reverse-direction map synchronization")
	var returned: bool = await _wait_for_actor_owner(handoff, actor, "district_a")
	if not returned:
		var reverse_driver: Node = actor.get_node("NavigationDriver")
		var reverse_agent: NavigationAgent3D = reverse_driver.get_node("NavigationAgent3D") as NavigationAgent3D
		print("WORLD05_REVERSE_DIAG pos=%s target=%s visible=%s state=%s substate=%s intent=%s destination=%s driver=%s nav_ready=%s path=%s" % [actor.global_position, target.global_position, actor.get_node("Perception").get("data").get("has_visual_contact"), actor.call("get_state_name"), actor.call("get_substate_name"), actor.get("has_movement_intent"), actor.get("movement_destination"), reverse_driver.get("debug_state"), reverse_driver.get("navigation_ready"), reverse_agent.get_current_navigation_path()])
	check.call(returned and actor.global_position.x < 0.0, "NPC pursuit returns across the seam without a second UUID owner")
	check.call(int(handoff.call("get_transfer_count", NPC_UUID)) == 2 and simulation.call("get_active_actor", NPC_UUID) == actor, "backtracking performs one reverse owner transfer")

	manager.update_player_position(Vector3(-5.0, 0.0, 0.0))
	check.call(await _wait_until_unloaded(loader, "district_b"), "destination chunk unloads after reverse handoff")
	check.call(is_instance_valid(actor) and actor.process_ai and simulation.call("get_active_actor", NPC_UUID) == actor, "reverse unload retains exactly one live actor")
	var saved_pose: Vector3 = actor.global_position
	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	check.call(await _wait_until_unloaded(loader, "district_a"), "last-owned chunk unload commits NPC state before freeing its projection")
	check.call(actor.is_queued_for_deletion() and simulation.call("get_active_actor", NPC_UUID) == null, "retired persistent projection releases its runtime actor")
	var saved_record: Dictionary = registry.get_entity_state(NPC_UUID).get("npc_simulation", {})
	check.call(not saved_record.is_empty() and not _contains_node(saved_record), "unload record retains durable data without runtime Node references")
	manager.update_player_position(Vector3(-5.0, 0.0, 0.0))
	var restore_generation: int = manager.get_lifecycle_generation("district_a")
	check.call(await _wait_for_chunk(manager, loader, "district_a", restore_generation), "backtracking restores the saved NPC chunk under a fresh generation")
	var restored_actor: TacticalAgent = await _spawn_goon(loader.get_active_instance("district_a"), factions, Vector3.ZERO, false)
	check.call(bool(handoff.call("attach_actor", NPC_UUID, "district_a", restore_generation, restored_actor)), "restored NPC attaches through the generation-aware handoff")
	var restored_ready: bool = await _wait_for_navigation(handoff, restored_actor)
	if not restored_ready:
		print("WORLD05_RESTORE_DIAG state=%s actor_configured=%s actor_chunk=%s nav_state=%s driver_ready=%s chunks=%s record=%s" % [simulation.call("get_active_actor_count"), restored_actor.call("is_configured"), handoff.call("get_actor_chunk_id", NPC_UUID), handoff.call("is_navigation_ready_for_actor", restored_actor), restored_actor.get_node("NavigationDriver").get("navigation_ready"), handoff.call("get_navigation_debug_state"), simulation.call("get_record", NPC_UUID)])
	check.call(restored_ready, "restored actor waits for its re-entered navmap")
	check.call(restored_actor.global_position.distance_to(saved_pose) < 0.6 and simulation.call("get_active_actor", NPC_UUID) == restored_actor, "AI-04 record restores the same UUID once at its last world position")
	check.call(int(simulation.call("get_active_actor_count")) == 1, "re-entry leaves one active runtime actor for the stable UUID")
	var duplicate_actor: TacticalAgent = await _spawn_goon(loader.get_active_instance("district_a"), factions, Vector3.ZERO, false)
	check.call(not bool(handoff.call("attach_actor", NPC_UUID, "district_a", restore_generation, duplicate_actor)), "a duplicate projection cannot attach to an already-owned UUID")
	duplicate_actor.queue_free()


func _chunk_records() -> Array[Dictionary]:
	return [
		{"id": "district_a", "bounds": AABB(Vector3(-10.0, -2.0, -5.0), Vector3(10.0, 5.0, 10.0)), "scene_path": CHUNK_A_PATH, "adjacent": ["district_b"]},
		{"id": "district_b", "bounds": AABB(Vector3(0.0, -2.0, -5.0), Vector3(10.0, 5.0, 10.0)), "scene_path": CHUNK_B_PATH, "adjacent": ["district_a"]},
	]


func _spawn_goon(parent: Node, factions: FactionState, position: Vector3, configure_agent: bool = true) -> TacticalAgent:
	var scene: PackedScene = load(GOON_SCENE_PATH) as PackedScene
	var actor: TacticalAgent = scene.instantiate() as TacticalAgent
	actor.process_ai = false
	actor.get_node("NavigationDriver").set("process_navigation", false)
	actor.position = position
	parent.add_child(actor)
	await get_tree().physics_frame
	if configure_agent:
		actor.call("configure", factions, GANG_FACTION)
	return actor


func _wait_for_chunk(manager: WorldManager, loader: ChunkLoader, chunk_id: String, generation: int) -> bool:
	for _frame: int in range(MAX_WAIT_FRAMES):
		loader.pump_frame()
		if manager.get_lifecycle_generation(chunk_id) == generation and manager.get_load_state(chunk_id) == WorldManager.LoadState.ACTIVE and loader.get_active_instance(chunk_id) != null:
			return true
		await get_tree().physics_frame
	return false


func _wait_for_navigation(handoff: Node, actor: TacticalAgent, minimum_frames: int = MAX_WAIT_FRAMES) -> bool:
	for _frame: int in range(minimum_frames):
		handoff.call("_process", 1.0 / 60.0)
		if actor.process_ai and bool(handoff.call("is_navigation_ready_for_actor", actor)):
			return true
		await get_tree().physics_frame
	return false


func _wait_for_actor_owner(handoff: Node, actor: TacticalAgent, chunk_id: String) -> bool:
	for _frame: int in range(MAX_WAIT_FRAMES):
		handoff.call("_process", 1.0 / 60.0)
		if String(handoff.call("get_actor_chunk_id", NPC_UUID)) == chunk_id:
			return true
		await get_tree().physics_frame
	return false


func _wait_until_unloaded(loader: ChunkLoader, chunk_id: String) -> bool:
	for _frame: int in range(MAX_WAIT_FRAMES):
		loader.pump_frame()
		if loader.get_active_instance(chunk_id) == null:
			return true
		await get_tree().physics_frame
	return false


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(frame_count):
		await get_tree().physics_frame


class TestTarget extends Node3D:
	var alive: bool = true

	func is_alive() -> bool:
		return alive

	func apply_damage(_amount: int, _source_faction: String) -> void:
		pass


func _contains_node(value: Variant) -> bool:
	if value is Node:
		return true
	if typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if _contains_node(item):
				return true
	if typeof(value) == TYPE_DICTIONARY:
		for key: Variant in value:
			if _contains_node(value[key]):
				return true
	return false
