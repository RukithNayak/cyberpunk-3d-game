extends RefCounted

const GOON_SCENE_PATH: String = "res://features/npcs/goon.tscn"
const AGENT_SCRIPT_PATH: String = "res://features/npcs/tactical_agent.gd"


class TestTarget extends StaticBody3D:
	var damage_total: int = 0
	var damage_calls: int = 0
	var alive: bool = true

	func is_alive() -> bool:
		return alive

	func apply_damage(amount: int, _source_faction: String) -> void:
		if amount <= 0 or not alive:
			return
		damage_total += amount
		damage_calls += 1


func run(check: Callable) -> void:
	var scene: PackedScene = load(GOON_SCENE_PATH) as PackedScene
	var agent_script: Script = load(AGENT_SCRIPT_PATH) as Script
	check.call(scene != null and agent_script != null, "AI-02 goon scene and tactical agent script are available")
	if scene == null or agent_script == null:
		return
	await _test_state_machine(check, scene)


func _test_state_machine(check: Callable, scene: PackedScene) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	tree.root.add_child(root)
	var agent: Node3D = scene.instantiate() as Node3D
	root.add_child(agent)
	agent.set_physics_process(false)
	agent.set("process_ai", false)
	agent.get_node("NavigationDriver").set("process_navigation", false)
	await tree.physics_frame
	check.call(agent.is_inside_tree(), "goon fixture is ready in the active scene tree")
	var factions: FactionState = FactionState.new(["gang_a", "player"])
	factions.set_faction_standing("player", -50)
	var route: Array[Vector3] = [Vector3(3.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)]
	check.call(bool(agent.call("configure", factions, "gang_a", route)), "goon accepts its faction authority and patrol route")
	check.call(not bool(agent.call("tick", 0.3)) and String(agent.call("get_state_name")).to_upper() == "IDLE", "oversized simulation step rejects without advancing agent state")
	check.call(bool(agent.call("tick", 1.0 / 60.0)) and String(agent.call("get_substate_name")).to_upper() == "PATROL" and (agent.call("get_movement_destination") as Vector3).is_equal_approx(route[0]), "idle agent deterministically emits the first patrol destination")
	agent.global_position = route[0]
	agent.call("tick", 1.0 / 60.0)
	check.call((agent.call("get_movement_destination") as Vector3).is_equal_approx(route[1]), "patrol route advances in authored order")
	agent.position = Vector3.ZERO
	var invalid_agent: Node3D = scene.instantiate() as Node3D
	root.add_child(invalid_agent)
	invalid_agent.set("process_ai", false)
	await tree.physics_frame
	invalid_agent.set("attack_damage", 101)
	check.call(not bool(invalid_agent.call("configure", factions, "gang_a")), "out-of-bound attack damage rejects agent configuration")
	root.remove_child(invalid_agent)
	invalid_agent.free()

	var target: TestTarget = _target("Hostile", Vector3(0.0, 0.0, -4.0))
	root.add_child(target)
	await tree.physics_frame
	await tree.physics_frame
	agent.call("set_candidate_target", target, "player")
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "COMBAT" and String(agent.call("get_substate_name")).to_upper() == "PURSUE", "visible hostile initiates combat pursuit")
	check.call((agent.call("get_movement_destination") as Vector3).is_equal_approx(target.global_position), "pursuit targets the currently observed location")
	target.position = Vector3(0.0, 0.0, -0.6)
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_substate_name")).to_upper() == "REPOSITION" and (agent.call("get_movement_destination") as Vector3).distance_to(target.global_position) > agent.global_position.distance_to(target.global_position), "too-close combat target produces a deterministic reposition intent")
	target.position = Vector3(0.0, 0.0, -1.4)
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_substate_name")).to_upper() == "ATTACK" and target.damage_calls == 1 and target.damage_total == 10, "in-range target receives one bounded attack")
	for _index: int in range(4):
		agent.call("tick", 0.25)
	check.call(target.damage_calls == 1, "attack cadence prevents early repeated damage")
	agent.call("tick", 0.25)
	check.call(target.damage_calls == 2 and target.damage_total == 20, "attack repeats once at the exact configured cadence")

	check.call(bool(agent.call("apply_stun", 1.0)), "agent accepts a bounded stun event")
	for _index: int in range(4):
		agent.call("tick", 0.25)
	check.call(String(agent.call("get_substate_name")).to_upper() == "STUNNED" and target.damage_calls == 2, "stunned agent cannot attack while stun time elapses")
	agent.call("tick", 1.0 / 60.0)
	check.call(target.damage_calls == 2, "attack cooldown resumes after stun rather than bursting")
	for _index: int in range(5):
		agent.call("tick", 0.25)
	check.call(target.damage_calls == 3, "attack resumes at bounded cadence after stun ends")

	factions.set_faction_standing("player", 50)
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "IDLE" and target.damage_calls == 3, "standing change to allied stops attacks while target remains present")
	factions.set_faction_standing("player", -50)
	var unknown_target: TestTarget = _target("UnknownFaction", Vector3(1.4, 0.0, -0.4))
	root.add_child(unknown_target)
	await tree.physics_frame
	check.call(bool(agent.call("set_authored_hostility", "unknown_gang", true)), "authored hostility event accepts a transient faction override")
	agent.call("set_candidate_target", unknown_target, "unknown_gang")
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "COMBAT", "authored hostility can engage an otherwise unknown faction")
	agent.call("clear_authored_hostility", "unknown_gang")
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "IDLE" and not factions.is_hostile("unknown_gang"), "clearing override restores safe faction default without mutating authority (state=%s hostile=%s)" % [str(agent.call("get_state_name")), str(factions.is_hostile("unknown_gang"))])
	root.remove_child(unknown_target)
	unknown_target.free()

	var wall: StaticBody3D = _wall(Vector3(0.0, 0.0, -2.0))
	root.add_child(wall)
	agent.call("set_candidate_target", target, "player")
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "COMBAT", "visible hostile returns agent to combat before sight is lost")
	wall.position = Vector3(0.0, 0.0, -2.0)
	target.position = Vector3(0.0, 0.0, -4.0)
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "INVESTIGATE" and String(agent.call("get_substate_name")).to_upper() == "INVESTIGATE", "lost sight transitions to investigation")
	var last_known: Vector3 = agent.call("get_movement_destination")
	target.position = Vector3(0.0, 0.0, -9.0)
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call((agent.call("get_movement_destination") as Vector3).is_equal_approx(last_known), "unseen target movement does not change investigation destination")
	agent.global_position = last_known
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_substate_name")).to_upper() == "SEARCH", "reaching last-known position enters search")
	for _index: int in range(12):
		agent.call("tick", 0.25)
	check.call(String(agent.call("get_state_name")).to_upper() == "IDLE", "search ends after configured investigation duration")

	var perception: Node = agent.get_node("Perception")
	var prior_heard: int = perception.get("data").get("heard_events").size()
	perception.call("notify_sound_event", Vector3(0.0, 0.0, -3.0), 5.0, "gang_a")
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "INVESTIGATE" and (agent.call("get_movement_destination") as Vector3).is_equal_approx(Vector3(0.0, 0.0, -3.0)) and perception.get("data").get("heard_events").size() == prior_heard + 1, "through-wall sound starts investigation at its source")

	var health: HealthState = agent.get("health_state") as HealthState
	check.call(health != null, "agent owns data-only health state")
	health.apply_damage(61, "test")
	agent.call("set_candidate_target", target, "player")
	target.position = Vector3(0.0, 0.0, -2.5)
	root.remove_child(wall)
	wall.free()
	await tree.physics_frame
	agent.call("tick", 1.0 / 60.0)
	check.call(String(agent.call("get_state_name")).to_upper() == "FLEE" and String(agent.call("get_substate_name")).to_upper() == "FLEE", "low health deterministically selects flee behavior")
	var flee_destination: Vector3 = agent.call("get_movement_destination")
	check.call(flee_destination.distance_to(target.global_position) > agent.global_position.distance_to(target.global_position), "flee intent moves away from last-known hostile position")
	health.apply_damage(1000, "test")
	agent.call("tick", 1.0 / 60.0)
	var calls_on_death: int = target.damage_calls
	check.call(String(agent.call("get_state_name")).to_upper() == "DEAD" and not bool(agent.call("tick", 1.0 / 60.0)) and target.damage_calls == calls_on_death, "lethal damage permanently prevents further state actions and attacks")
	check.call(not bool(agent.call("apply_stun", 0.0)) and not bool(agent.call("tick", -0.1)), "invalid stun duration and negative time are rejected")
	tree.root.remove_child(root)
	root.free()


func _target(node_name: String, at: Vector3) -> TestTarget:
	var target: TestTarget = TestTarget.new()
	target.name = node_name
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.4
	shape_node.shape = shape
	target.add_child(shape_node)
	target.position = at
	return target


func _wall(at: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.4)
	collision.shape = box
	wall.add_child(collision)
	wall.position = at
	return wall
