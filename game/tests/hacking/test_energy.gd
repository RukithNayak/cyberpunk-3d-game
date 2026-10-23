extends RefCounted

const DEFINITION_PATH: String = "res://features/hacking/hack_definition.gd"
const STATE_PATH: String = "res://features/hacking/hacking_state.gd"
const SERVICE_PATH: String = "res://features/hacking/hacking_service.gd"
const ACTIVE_HACK_PATH: String = "res://features/hacking/active_hack.gd"

var _line_of_sight_allowed: bool = true


class HackTargetStub extends Node3D:
	var uuid: String = "123e4567-e89b-42d3-a456-426614174000"
	var can_accept: bool = true
	var commit_succeeds: bool = true
	var commit_count: int = 0
	var effect_committed: bool = false

	func get_persistent_uuid() -> String:
		return uuid

	func can_accept_hack(_definition: Resource, _operator: Node3D) -> bool:
		return can_accept

	func apply_hack(_definition: Resource, _operator: Node3D) -> bool:
		commit_count += 1
		if commit_succeeds:
			effect_committed = true
		return effect_committed


func run(check: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	var definition_script: Script = load(DEFINITION_PATH) as Script
	var state_script: Script = load(STATE_PATH) as Script
	var service_script: Script = load(SERVICE_PATH) as Script
	var active_hack_script: Script = load(ACTIVE_HACK_PATH) as Script
	check.call(definition_script != null and state_script != null and service_script != null and active_hack_script != null, "HACK-01 resources and service are available")
	if definition_script == null or state_script == null or service_script == null or active_hack_script == null:
		return
	_test_default_definitions(check, service_script, definition_script)
	_test_energy_math(check, state_script)
	await _test_request_eligibility_and_commit(check, state_script, service_script)
	await _test_exact_cost_boundary(check, state_script, service_script)
	_test_active_hack_data(check, active_hack_script)


func _test_default_definitions(check: Callable, service_script: Script, definition_script: Script) -> void:
	var service: Object = service_script.new()
	var definitions: Array = service.call("get_default_definitions")
	check.call(definitions.size() == 5, "the five detailed-design hacks have default definitions")
	if definitions.size() != 5:
		return
	var expected: Array[Dictionary] = [
		{"id": 0, "cost": 20.0, "cooldown": 10.0, "duration": 8.0, "damage": 0.0},
		{"id": 1, "cost": 30.0, "cooldown": 5.0, "duration": 0.0, "damage": 0.0},
		{"id": 2, "cost": 15.0, "cooldown": 6.0, "duration": 0.0, "damage": 0.0},
		{"id": 3, "cost": 35.0, "cooldown": 12.0, "duration": 3.0, "damage": 8.0},
		{"id": 4, "cost": 45.0, "cooldown": 20.0, "duration": 10.0, "damage": 0.0},
	]
	var all_match: bool = true
	for entry: Dictionary in expected:
		var found: Resource = _definition_for(definitions, int(entry["id"]))
		all_match = all_match and found != null
		if found != null:
			all_match = all_match and is_equal_approx(float(found.get("energy_cost")), float(entry["cost"]))
			all_match = all_match and is_equal_approx(float(found.get("cooldown_seconds")), float(entry["cooldown"]))
			all_match = all_match and is_equal_approx(float(found.get("effect_duration_seconds")), float(entry["duration"]))
			all_match = all_match and is_equal_approx(float(found.get("maximum_range")), 18.0)
			all_match = all_match and is_equal_approx(float(found.get("impact_damage")), float(entry["damage"]))
	check.call(all_match, "ability costs, cooldowns and durations match recorded tuning defaults")
	var invalid_definition: Resource = definition_script.new() as Resource
	invalid_definition.set("energy_cost", -1.0)
	check.call(not bool(invalid_definition.call("is_valid")), "negative ability cost is rejected")
	invalid_definition.set("energy_cost", 0.0)
	check.call(not bool(invalid_definition.call("is_valid")), "zero ability cost is rejected")


func _test_energy_math(check: Callable, state_script: Script) -> void:
	var default_state: Object = state_script.new()
	check.call(is_equal_approx(float(default_state.get("current_energy")), 100.0) and is_equal_approx(float(default_state.get("max_energy")), 100.0) and is_equal_approx(float(default_state.get("regen_rate_per_sec")), 8.0), "energy defaults match recorded tuning values")
	var state: Object = state_script.new()
	check.call(bool(state.call("configure", 100.0, 8.0, 100.0)), "energy state accepts bounded initial values")
	check.call(bool(state.call("try_spend", 100.0)) and is_zero_approx(float(state.get("current_energy"))), "energy can be spent at the exact available boundary")
	check.call(not bool(state.call("try_spend", 0.1)), "insufficient energy leaves the pool unchanged")
	check.call(bool(state.call("tick", 2.0)) and is_equal_approx(float(state.get("current_energy")), 16.0), "energy regenerates by rate times elapsed seconds")
	check.call(bool(state.call("tick", 100.0)) and is_equal_approx(float(state.get("current_energy")), 100.0), "energy regeneration clamps at maximum")
	check.call(not bool(state.call("tick", -1.0)) and is_equal_approx(float(state.get("current_energy")), 100.0), "negative elapsed time is rejected without energy mutation")
	check.call(not bool(state.call("configure", 0.0, 8.0, 0.0)), "non-positive energy maximum is rejected")
	check.call(not bool(state.call("configure", 100.0, -1.0, 0.0)), "negative regeneration rate is rejected")
	check.call(not bool(state.call("configure", 100.0, 8.0, -2.0)), "negative starting energy is rejected")


func _test_request_eligibility_and_commit(check: Callable, state_script: Script, service_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var operator: Node3D = Node3D.new()
	var target: HackTargetStub = HackTargetStub.new()
	tree.root.add_child(operator)
	tree.root.add_child(target)
	target.position = Vector3(0.0, 0.0, -5.0)
	await tree.process_frame
	var service: Object = service_script.new()
	var state: Object = state_script.new()
	state.call("configure", 100.0, 8.0, 100.0)
	var definitions: Array = service.call("get_default_definitions")
	var door: Resource = _definition_for(definitions, 1)
	target.add_to_group(StringName(door.get("required_target_group")))
	var configured: bool = bool(service.call("configure", operator, state, definitions, Callable(self, "_line_of_sight")))
	check.call(configured, "hacking service accepts the valid operator/state/catalog")
	var initial_energy: float = float(state.get("current_energy"))
	check.call(bool(service.call("request_hack", target, 1)), "eligible tagged target accepts its hack")
	check.call(is_equal_approx(float(state.get("current_energy")), initial_energy - float(door.get("energy_cost"))) and target.commit_count == 1, "successful hack commits once then charges its configured cost")
	var after_first: float = float(state.get("current_energy"))
	check.call(not bool(service.call("request_hack", target, 1)) and is_equal_approx(float(state.get("current_energy")), after_first) and target.commit_count == 1, "same target and ability cannot bypass active cooldown")
	state.call("tick", float(door.get("cooldown_seconds")) + 0.1)
	check.call(bool(service.call("request_hack", target, 1)), "target may be hacked again when eligible after cooldown")

	var no_tag_target: HackTargetStub = HackTargetStub.new()
	no_tag_target.position = Vector3(0.0, 0.0, -5.0)
	tree.root.add_child(no_tag_target)
	var energy_before_reject: float = float(state.get("current_energy"))
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject), "wrong target tag rejects without spending energy")
	no_tag_target.add_to_group(StringName(door.get("required_target_group")))
	_line_of_sight_allowed = false
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject), "blocked line of sight rejects without spending energy")
	_line_of_sight_allowed = true
	no_tag_target.position = Vector3(0.0, 0.0, -100.0)
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject), "out-of-range target rejects without spending energy")
	no_tag_target.position = Vector3(0.0, 0.0, -5.0)
	no_tag_target.can_accept = false
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject), "target access/current-state rejection does not spend energy")
	no_tag_target.can_accept = true
	no_tag_target.uuid = "not-a-stable-uuid"
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject), "missing stable target identity rejects without spending energy")
	no_tag_target.uuid = "123e4567-e89b-42d3-a456-426614174001"
	no_tag_target.commit_succeeds = false
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_equal_approx(float(state.get("current_energy")), energy_before_reject) and not no_tag_target.effect_committed, "declined target commit preserves target state and refunds energy")
	check.call(float(state.call("get_cooldown_remaining", no_tag_target.uuid, 1)) == 0.0, "declined target commit does not start a cooldown")
	state.set("current_energy", 0.0)
	no_tag_target.commit_succeeds = true
	var commits_before_energy_failure: int = no_tag_target.commit_count
	check.call(not bool(service.call("request_hack", no_tag_target, 1)) and is_zero_approx(float(state.get("current_energy"))) and no_tag_target.commit_count == commits_before_energy_failure, "insufficient energy rejects before target commit")

	no_tag_target.queue_free()
	target.queue_free()
	operator.queue_free()
	_line_of_sight_allowed = true
	await tree.process_frame


func _test_active_hack_data(check: Callable, active_hack_script: Script) -> void:
	var active_hack: Object = active_hack_script.new()
	active_hack.set("target_uuid", "123e4567-e89b-42d3-a456-426614174000")
	active_hack.set("hack_type", 0)
	active_hack.set("remaining_duration", 8.0)
	var data: Dictionary = active_hack.call("to_data")
	check.call(data == {"target_uuid": "123e4567-e89b-42d3-a456-426614174000", "hack_type": 0, "remaining_duration": 8.0}, "active hack record contains only stable identity and effect data")


func _test_exact_cost_boundary(check: Callable, state_script: Script, service_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var operator: Node3D = Node3D.new()
	var target: HackTargetStub = HackTargetStub.new()
	tree.root.add_child(operator)
	tree.root.add_child(target)
	target.position = Vector3(0.0, 0.0, -4.0)
	await tree.process_frame
	var service: Object = service_script.new()
	var state: Object = state_script.new()
	state.call("configure", 100.0, 0.0, 30.0)
	var definitions: Array = service.call("get_default_definitions")
	var door: Resource = _definition_for(definitions, 1)
	target.add_to_group(StringName(door.get("required_target_group")))
	service.call("configure", operator, state, definitions, Callable(self, "_line_of_sight"))
	check.call(bool(service.call("request_hack", target, 1)) and is_zero_approx(float(state.get("current_energy"))) and target.commit_count == 1, "a request with exactly its configured cost succeeds and spends to zero")
	target.queue_free()
	operator.queue_free()
	await tree.process_frame


func _definition_for(definitions: Array, ability_id: int) -> Resource:
	for candidate: Variant in definitions:
		if candidate is Resource and int((candidate as Resource).get("ability_id")) == ability_id:
			return candidate as Resource
	return null


func _line_of_sight(_origin: Vector3, _destination: Vector3) -> bool:
	return _line_of_sight_allowed
