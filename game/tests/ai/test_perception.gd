extends RefCounted

const PERCEPTION_PATH: String = "res://features/npcs/perception.gd"
const FACTION_RULES_PATH: String = "res://features/npcs/faction_rules.gd"


func run(check: Callable) -> void:
	var perception_script: Script = load(PERCEPTION_PATH) as Script
	var faction_rules_script: Script = load(FACTION_RULES_PATH) as Script
	check.call(perception_script != null and faction_rules_script != null, "AI-01 perception and faction rules are available")
	if perception_script == null or faction_rules_script == null:
		return
	await _test_visual_knowledge_and_sound(check, perception_script)
	await _test_live_faction_standings(check, faction_rules_script)


func _test_visual_knowledge_and_sound(check: Callable, perception_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	tree.root.add_child(root)
	var observer: Node3D = perception_script.new() as Node3D
	root.add_child(observer)
	var faction_state: FactionState = FactionState.new(["gang_a"])
	check.call(observer.call("configure", faction_state), "perception accepts faction owner and default sight configuration")
	var target: StaticBody3D = _target("Target", Vector3(0.0, 0.0, -8.0))
	root.add_child(target)
	await tree.physics_frame
	await tree.physics_frame
	check.call(bool(observer.call("update_visual_target", target)), "visible target inside sight range is observed")
	var data: Object = observer.get("data")
	check.call(bool(data.get("has_visual_contact")) and bool(data.get("has_last_known_position")) and data.get("seen_position").is_equal_approx(target.global_position), "visual contact records seen and last-known positions")
	var prior_last_known: Vector3 = data.get("last_known_position")
	var wall: StaticBody3D = _wall(Vector3(0.0, 0.0, -4.0))
	root.add_child(wall)
	target.position = Vector3(0.0, 0.0, -10.0)
	await tree.physics_frame
	check.call(not bool(observer.call("update_visual_target", target)) and not bool(data.get("has_visual_contact")), "wall occlusion clears current visual contact")
	check.call(data.get("last_known_position").is_equal_approx(prior_last_known), "occluded target movement does not update last-known position")
	target.position = Vector3(0.0, 0.0, -21.0)
	root.remove_child(wall)
	wall.free()
	await tree.physics_frame
	check.call(not bool(observer.call("update_visual_target", target)) and data.get("last_known_position").is_equal_approx(prior_last_known), "out-of-range target cannot update visual knowledge")
	target.position = Vector3(0.0, 0.0, -20.0)
	await tree.physics_frame
	check.call(bool(observer.call("update_visual_target", target)), "target at the configured sight-range boundary remains visible")
	var sound_wall: StaticBody3D = _wall(Vector3(0.0, 0.0, -2.0))
	root.add_child(sound_wall)
	await tree.physics_frame
	observer.call("update_visual_target", target)
	var heard_signals: Array[Dictionary] = []
	observer.connect("sound_event_heard", func(event: Dictionary) -> void: heard_signals.append(event.duplicate(true)))
	observer.call("notify_sound_event", Vector3(0.0, 0.0, -20.0), 20.0, "gang_a")
	check.call(not bool(data.get("has_visual_contact")) and data.get("heard_events").size() == 1 and heard_signals.size() == 1, "sound at the inclusive radius is emitted through a wall without granting visual contact")
	observer.call("notify_sound_event", Vector3(0.0, 0.0, -20.01), 20.0, "gang_a")
	check.call(data.get("heard_events").size() == 1, "sound outside radius is ignored")
	observer.call("notify_sound_event", Vector3(0.0, 0.0, -1.0), -1.0, "gang_a")
	check.call(data.get("heard_events").size() == 1, "invalid negative-radius sound is ignored")
	for _index: int in range(20):
		observer.call("notify_sound_event", Vector3.ZERO, 0.0, "gang_a")
	check.call(data.get("heard_events").size() == 16, "heard-event history stays within its configured bound")
	tree.root.remove_child(root)
	root.free()


func _test_live_faction_standings(check: Callable, rules_script: Script) -> void:
	var state: FactionState = FactionState.new(["gang_a"])
	var rules: Object = rules_script.new()
	check.call(bool(rules.call("configure", state)), "faction rules bind to authoritative faction state")
	check.call(not bool(rules.call("evaluate_target_hostility", "unknown")) and not bool(rules.call("evaluate_target_alliance", "unknown")), "unknown factions safely default to neither hostile nor allied")
	check.call(not bool(rules.call("evaluate_target_hostility", "gang_a")), "neutral standing is not hostile")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	tree.root.add_child(root)
	var perception: Node3D = load(PERCEPTION_PATH).new() as Node3D
	root.add_child(perception)
	var target: Node3D = Node3D.new()
	root.add_child(target)
	check.call(bool(perception.call("configure", state)), "live perception reads the configured faction authority")
	await tree.process_frame
	state.set_faction_standing("gang_a", -50)
	check.call(bool(rules.call("evaluate_target_hostility", "gang_a")) and bool(perception.call("evaluate_target_hostility", "gang_a")), "hostility uses the inclusive CORE-02 threshold")
	state.set_faction_standing("gang_a", -49)
	check.call(not bool(rules.call("evaluate_target_hostility", "gang_a")), "one point above hostile threshold is neutral")
	state.set_faction_standing("gang_a", 50)
	check.call(not bool(rules.call("evaluate_target_hostility", "gang_a")) and bool(rules.call("evaluate_target_alliance", "gang_a")), "allied threshold is inclusive and never hostile")
	check.call(bool(state.set_faction_standing("gang_a", -50)) and target.is_inside_tree() and bool(perception.call("evaluate_target_hostility", "gang_a")), "reputation change updates hostility while the target faction remains present")
	tree.root.remove_child(root)
	root.free()


func _target(node_name: String, at: Vector3) -> StaticBody3D:
	var target: StaticBody3D = StaticBody3D.new()
	target.name = node_name
	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.5
	collision.shape = sphere
	target.add_child(collision)
	target.position = at
	return target


func _wall(at: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "Occluder"
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.4)
	collision.shape = box
	wall.add_child(collision)
	wall.position = at
	return wall
