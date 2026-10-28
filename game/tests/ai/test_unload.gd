extends RefCounted
## AI-04 lifecycle/persistence regression using real WorldManager and registry owners.

const RECORD_SCRIPT_PATH: String = "res://features/npcs/npc_simulation_record.gd"
const GOON_SCENE_PATH: String = "res://features/npcs/goon.tscn"
const UUID_A: String = "123e4567-e89b-42d3-a456-426614174011"
const UUID_B: String = "123e4567-e89b-42d3-a456-426614174012"

class TestTarget extends Node3D:
	var damage_calls: int = 0
	var alive: bool = true

	func is_alive() -> bool:
		return alive

	func apply_damage(amount: int, _source_faction: String) -> void:
		if amount > 0 and alive:
			damage_calls += 1


var _navigation_ready: bool = true


func run(check: Callable) -> void:
	var record_script: Script = load(RECORD_SCRIPT_PATH) as Script
	var goon_scene: PackedScene = load(GOON_SCENE_PATH) as PackedScene
	check.call(record_script != null, "AI-04 simulation record service is available")
	check.call(goon_scene != null, "AI unload fixture can instantiate goons")
	if record_script == null or goon_scene == null:
		return
	await _test_chunk_unload_restore(check, record_script, goon_scene)


func _test_chunk_unload_restore(check: Callable, record_script: Script, goon_scene: PackedScene) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	root.name = "AiUnloadFixture"
	tree.root.add_child(root)
	var manifest: ChunkManifest = ChunkManifest.new()
	check.call(manifest.configure(_chunk_records()), "AI-04 two-chunk manifest configures")
	var manager: WorldManager = WorldManager.new()
	check.call(manager.configure(manifest, 0.0, 0.0), "AI-04 manager configures for lifecycle signals")
	var registry: EntityRegistry = EntityRegistry.new()
	registry.register_entity(UUID_A, {"owner": "district_a"})
	registry.register_entity(UUID_B, {"owner": "district_b"})
	var factions: FactionState = FactionState.new(["gang_a", "player"])
	factions.set_faction_standing("player", -50)
	var service: RefCounted = record_script.new()
	check.call(bool(service.call("configure", registry, manager, factions, Callable(self, "_is_navigation_ready"))), "simulation service connects to the authoritative owners")

	var generation_a: int = _enter_chunk(manager, "district_a", Vector3(-5.0, 0.0, 0.0))
	var pursuit_actor: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3(-5.0, 0.0, 0.0))
	pursuit_actor.global_rotation = Vector3(0.0, 0.7, 0.0)
	var pursuit_target: TestTarget = _make_target(root, Vector3(-1.0, 0.0, 0.0))
	pursuit_actor.call("set_candidate_target", pursuit_target, "player")
	pursuit_actor.call("tick", 1.0 / 60.0)
	pursuit_actor.call("apply_damage", 18, "player")
	check.call(String(pursuit_actor.call("get_substate_name")) == "pursue", "first NPC is unloaded during combat pursuit")
	check.call(bool(service.call("register_actor", UUID_A, "district_a", generation_a, pursuit_actor)), "combat NPC registers under its stable UUID")
	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	var generation_b: int = manager.get_lifecycle_generation("district_b")
	check.call(manager.acknowledge_activated("district_b", generation_b), "neighboring chunk activates after the pursuit chunk unloads")
	var state_a: Dictionary = registry.get_entity_state(UUID_A)
	var record_a: Dictionary = state_a.get("npc_simulation", {})
	check.call(int(record_a.get("health", {}).get("current", -1)) == 62, "pre-unload commits NPC health to registry truth")
	check.call(bool(record_a.get("flags", {}).get("dead", true)) == false, "surviving NPC is recorded as alive")
	check.call((record_a.get("pose", {}).get("position", []) as Array).size() == 3, "pre-unload stores world pose as data-only components")
	check.call((record_a.get("pose", {}).get("rotation", []) as Array).size() == 4, "pre-unload stores world rotation as quaternion data")
	check.call(not _contains_node(record_a), "persistent NPC record retains no runtime Node references")
	check.call(int(service.call("get_active_actor_count")) == 0, "pre-unload releases transient actor ownership")
	check.call(pursuit_actor.get("_combat_target") == null and pursuit_actor.get("_candidate_target") == null, "pre-unload clears transient target Nodes")
	var pursuit_damage_calls: int = pursuit_target.damage_calls
	check.call(not bool(pursuit_actor.call("tick", 1.0 / 60.0)) and pursuit_target.damage_calls == pursuit_damage_calls, "unloaded pursuit cannot deliver a late damage callback")
	check.call(registry.get_entity_state(UUID_A)["owner"] == "district_a", "NPC commit preserves unrelated entity data")
	pursuit_actor.queue_free()

	var attack_actor: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3(5.0, 0.0, 0.0))
	var attack_target: TestTarget = _make_target(root, Vector3(6.2, 0.0, 0.0))
	attack_actor.call("set_candidate_target", attack_target, "player")
	attack_actor.call("tick", 1.0 / 60.0)
	check.call(attack_target.damage_calls == 1 and String(attack_actor.call("get_substate_name")) == "attack", "second NPC attacks before unload")
	check.call(bool(attack_actor.call("apply_stun", 5.0)), "second NPC enters stun before unload")
	check.call(bool(service.call("register_actor", UUID_B, "district_b", generation_b, attack_actor)), "attacking NPC registers under a distinct UUID")
	manager.update_player_position(Vector3(-5.0, 0.0, 0.0))
	var reentry_generation_a: int = manager.get_lifecycle_generation("district_a")
	check.call(manager.acknowledge_activated("district_a", reentry_generation_a), "district A re-enters before district B for reverse-order restore")
	var record_b: Dictionary = registry.get_entity_state(UUID_B).get("npc_simulation", {})
	check.call(bool(record_b.get("flags", {}).get("stunned", false)) == false, "transient stun state is not serialized as durable NPC state")
	var attack_damage_calls: int = attack_target.damage_calls
	check.call(attack_actor.get("_combat_target") == null and not bool(attack_actor.call("tick", 1.0 / 60.0)) and attack_target.damage_calls == attack_damage_calls, "unloaded attack/stun cannot invoke volatile combat callbacks")
	attack_actor.queue_free()

	var adapters: SnapshotAdapters = SnapshotAdapters.new(registry, factions, Callable(self, "_capture_empty"), Callable(self, "_prepare_dictionary"), Callable(self, "_commit_dictionary"), Callable(self, "_capture_empty"), Callable(self, "_prepare_dictionary"), Callable(self, "_commit_dictionary"))
	var save_snapshot: Dictionary = adapters.capture_snapshot()
	var saved_entities: Array = save_snapshot.get("entities", [])
	check.call(_snapshot_has_record(saved_entities, UUID_B), "CORE-04 snapshot adapter captures NPC entity records")
	check.call(adapters.validate_snapshot(save_snapshot), "CORE-04 validates the NPC record in a save snapshot")

	_navigation_ready = false
	var restored_a: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3.ZERO, false)
	check.call(not bool(service.call("register_actor", UUID_A, "district_a", reentry_generation_a, restored_a)), "saved actor waits while navigation is not ready")
	_navigation_ready = true
	check.call(bool(service.call("register_actor", UUID_A, "district_a", reentry_generation_a, restored_a)), "saved actor restores after navigation becomes ready")
	check.call(restored_a.global_position.distance_to(Vector3(-5.0, 0.0, 0.0)) < 0.01, "restore applies saved world position")
	check.call(is_equal_approx(restored_a.global_rotation.y, 0.7), "restore applies saved world rotation")
	check.call(restored_a.get("health_state").current_hp == 62 and String(restored_a.call("get_state_name")) == "idle", "restore preserves health and restarts volatile pursuit as idle")
	check.call(int(service.call("get_active_actor_count")) == 1, "restored UUID has exactly one active actor owner")
	var duplicate_a: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3.ZERO)
	check.call(not bool(service.call("register_actor", UUID_A, "district_a", reentry_generation_a, duplicate_a)), "one active UUID cannot acquire a second actor")
	duplicate_a.queue_free()

	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	var reentry_generation_b: int = manager.get_lifecycle_generation("district_b")
	check.call(manager.acknowledge_activated("district_b", reentry_generation_b), "district B re-enters after district A")
	var restored_b: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3.ZERO, false)
	check.call(bool(service.call("register_actor", UUID_B, "district_b", reentry_generation_b, restored_b)), "NPC restores correctly when chunks re-enter in reverse order")
	check.call(restored_b.global_position.distance_to(Vector3(5.0, 0.0, 0.0)) < 0.01 and restored_b.get("health_state").current_hp == 80, "reverse-order restore preserves the second NPC pose and health")
	restored_b.call("apply_damage", 1000, "player")
	check.call(String(restored_b.call("get_state_name")) == "dead", "lethal damage marks durable NPC death")
	manager.update_player_position(Vector3(-5.0, 0.0, 0.0))
	manager.acknowledge_activated("district_a", manager.get_lifecycle_generation("district_a"))
	restored_b.queue_free()
	manager.update_player_position(Vector3(5.0, 0.0, 0.0))
	var dead_generation_b: int = manager.get_lifecycle_generation("district_b")
	manager.acknowledge_activated("district_b", dead_generation_b)
	var restored_dead: TacticalAgent = await _make_actor(root, goon_scene, factions, "gang_a", Vector3.ZERO, false)
	check.call(bool(service.call("register_actor", UUID_B, "district_b", dead_generation_b, restored_dead)), "dead NPC record is accepted after navigation readiness")
	check.call(String(restored_dead.call("get_state_name")) == "dead" and restored_dead.get("health_state").current_hp == 0, "dead NPC remains dead after unload and restoration")
	root.queue_free()
	await tree.process_frame


func _chunk_records() -> Array[Dictionary]:
	return [
		{"id": "district_a", "bounds": AABB(Vector3(-10.0, -2.0, -5.0), Vector3(10.0, 5.0, 10.0)), "scene_path": "res://world/fixtures/chunk_a.tscn", "adjacent": ["district_b"]},
		{"id": "district_b", "bounds": AABB(Vector3(0.0, -2.0, -5.0), Vector3(10.0, 5.0, 10.0)), "scene_path": "res://world/fixtures/chunk_b.tscn", "adjacent": ["district_a"]},
	]


func _enter_chunk(manager: WorldManager, chunk_id: String, position: Vector3) -> int:
	manager.update_player_position(position)
	var generation: int = manager.get_lifecycle_generation(chunk_id)
	manager.acknowledge_activated(chunk_id, generation)
	return generation


func _make_actor(root: Node3D, scene: PackedScene, factions: FactionState, faction_id: String, position: Vector3, configure_agent: bool = true) -> TacticalAgent:
	var actor: TacticalAgent = scene.instantiate() as TacticalAgent
	actor.set("process_ai", false)
	actor.get_node("NavigationDriver").set("process_navigation", false)
	actor.position = position
	root.add_child(actor)
	await (Engine.get_main_loop() as SceneTree).process_frame
	if configure_agent:
		actor.call("configure", factions, faction_id)
	return actor


func _make_target(root: Node3D, position: Vector3) -> TestTarget:
	var target: TestTarget = TestTarget.new()
	target.position = position
	root.add_child(target)
	return target


func _is_navigation_ready(_actor: Node) -> bool:
	return _navigation_ready


func _capture_empty() -> Dictionary:
	return {}


func _prepare_dictionary(data: Dictionary) -> Dictionary:
	return {"ok": true, "prepared": data.duplicate(true)}


func _commit_dictionary(_data: Dictionary) -> void:
	pass


func _snapshot_has_record(records: Array, uuid: String) -> bool:
	for record_variant: Variant in records:
		if record_variant is Dictionary and record_variant.get("uuid") == uuid:
			return (record_variant.get("state", {}) as Dictionary).has("npc_simulation")
	return false


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
