extends RefCounted
class_name HackingService
## Validates an ability and target before charging, then commits through the target adapter.

signal energy_changed(current: float, maximum: float)
signal hack_committed(target_uuid: String, ability_id: int, remaining_energy: float)
signal hack_rejected(target_uuid: String, ability_id: int, reason: StringName)

const TARGET_UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
const REASON_UNCONFIGURED: StringName = &"unconfigured"
const REASON_INVALID_TARGET: StringName = &"invalid_target"
const REASON_INVALID_ABILITY: StringName = &"invalid_ability"
const REASON_TARGET_TAG: StringName = &"wrong_target_tag"
const REASON_TARGET_IDENTITY: StringName = &"missing_target_identity"
const REASON_OUT_OF_RANGE: StringName = &"out_of_range"
const REASON_NO_LINE_OF_SIGHT: StringName = &"blocked_line_of_sight"
const REASON_COOLDOWN: StringName = &"cooldown"
const REASON_INSUFFICIENT_ENERGY: StringName = &"insufficient_energy"
const REASON_TARGET_STATE: StringName = &"target_rejected"
const REASON_TARGET_COMMIT: StringName = &"target_commit_failed"
const REASON_REENTRANT: StringName = &"request_in_progress"

var last_rejection_reason: StringName = &""

var _operator: Node3D
var _state: HackingState
var _definitions: Dictionary = {}
var _line_of_sight_check: Callable
var _pending_requests: Dictionary = {}
var _uuid_regex: RegEx = RegEx.new()
var _configured: bool = false


func _init() -> void:
	_uuid_regex.compile(TARGET_UUID_PATTERN)


func configure(operator: Node3D, state: HackingState, definitions: Array, line_of_sight_check: Callable = Callable()) -> bool:
	if _configured or operator == null or state == null or definitions.is_empty():
		return false
	var staged_definitions: Dictionary = {}
	for candidate: Variant in definitions:
		if not candidate is HackDefinition or not (candidate as HackDefinition).is_valid():
			return false
		var definition: HackDefinition = candidate as HackDefinition
		if staged_definitions.has(definition.ability_id):
			return false
		staged_definitions[definition.ability_id] = definition
	_operator = operator
	_state = state
	_definitions = staged_definitions
	_line_of_sight_check = line_of_sight_check
	_configured = true
	return true


func get_default_definitions() -> Array[HackDefinition]:
	var definitions: Array[HackDefinition] = []
	var records: Array[Dictionary] = [
		{"id": HackDefinition.Ability.DISABLE_CAMERA, "name": "Disable Camera", "group": &"hackable_camera", "cost": 20.0, "cooldown": 10.0, "duration": 8.0, "damage": 0.0},
		{"id": HackDefinition.Ability.UNLOCK_DOOR, "name": "Unlock Door", "group": &"hackable_door", "cost": 30.0, "cooldown": 5.0, "duration": 0.0, "damage": 0.0},
		{"id": HackDefinition.Ability.TRIGGER_DISTRACTION, "name": "Trigger Distraction", "group": &"hackable_distraction", "cost": 15.0, "cooldown": 6.0, "duration": 0.0, "damage": 0.0},
		{"id": HackDefinition.Ability.DISRUPT_IMPLANT, "name": "Disrupt Implant", "group": &"hackable_implant", "cost": 35.0, "cooldown": 12.0, "duration": 3.0, "damage": 8.0},
		{"id": HackDefinition.Ability.DISABLE_TURRET, "name": "Disable Turret", "group": &"hackable_turret", "cost": 45.0, "cooldown": 20.0, "duration": 10.0, "damage": 0.0},
	]
	for record: Dictionary in records:
		var definition: HackDefinition = HackDefinition.new()
		definition.ability_id = int(record["id"])
		definition.display_name = String(record["name"])
		definition.required_target_group = StringName(record["group"])
		definition.energy_cost = float(record["cost"])
		definition.cooldown_seconds = float(record["cooldown"])
		definition.effect_duration_seconds = float(record["duration"])
		definition.maximum_range = 18.0
		definition.impact_damage = float(record["damage"])
		definitions.append(definition)
	return definitions


func request_hack(target_node: Node3D, hack_type: int) -> bool:
	if not _configured:
		return _reject("", hack_type, REASON_UNCONFIGURED)
	if not _is_live_node(_operator) or not _is_live_node(target_node):
		return _reject("", hack_type, REASON_INVALID_TARGET)
	if not _definitions.has(hack_type):
		return _reject("", hack_type, REASON_INVALID_ABILITY)
	var definition: HackDefinition = _definitions[hack_type]
	if not target_node.is_in_group(definition.required_target_group):
		return _reject("", hack_type, REASON_TARGET_TAG)
	if not target_node.has_method("get_persistent_uuid"):
		return _reject("", hack_type, REASON_TARGET_IDENTITY)
	var target_uuid: String = String(target_node.call("get_persistent_uuid"))
	if _uuid_regex.search(target_uuid) == null:
		return _reject(target_uuid, hack_type, REASON_TARGET_IDENTITY)
	var request_key: String = "%s::%d" % [target_uuid, hack_type]
	if _pending_requests.has(request_key):
		return _reject(target_uuid, hack_type, REASON_REENTRANT)
	_pending_requests[request_key] = true
	var reason: StringName = _eligibility_failure(target_node, target_uuid, definition)
	if reason == &"" and not target_node.has_method("can_accept_hack"):
		reason = REASON_TARGET_STATE
	if reason == &"":
		var target_accepts: bool = bool(target_node.call("can_accept_hack", definition, _operator))
		if not target_accepts:
			reason = REASON_TARGET_STATE
	if reason == &"":
		reason = _eligibility_failure(target_node, target_uuid, definition)
	if reason == &"" and not target_node.has_method("apply_hack"):
		reason = REASON_TARGET_COMMIT
	if reason != &"":
		_pending_requests.erase(request_key)
		return _reject(target_uuid, hack_type, reason)
	if not _state.try_spend(definition.energy_cost):
		_pending_requests.erase(request_key)
		return _reject(target_uuid, hack_type, REASON_INSUFFICIENT_ENERGY)
	var committed: bool = bool(target_node.call("apply_hack", definition, _operator))
	if not committed:
		_state.refund(definition.energy_cost)
		_pending_requests.erase(request_key)
		return _reject(target_uuid, hack_type, REASON_TARGET_COMMIT)
	_state.start_cooldown(target_uuid, hack_type, definition.cooldown_seconds)
	_pending_requests.erase(request_key)
	last_rejection_reason = &""
	energy_changed.emit(_state.current_energy, _state.max_energy)
	hack_committed.emit(target_uuid, hack_type, _state.current_energy)
	return true


func tick_energy_regen(delta: float) -> void:
	if _configured:
		var previous_energy: float = _state.current_energy
		if _state.tick(delta) and not is_equal_approx(previous_energy, _state.current_energy):
			energy_changed.emit(_state.current_energy, _state.max_energy)


func get_last_rejection_reason() -> StringName:
	return last_rejection_reason


func _eligibility_failure(target_node: Node3D, target_uuid: String, definition: HackDefinition) -> StringName:
	if not _is_live_node(_operator) or not _is_live_node(target_node):
		return REASON_INVALID_TARGET
	if not target_node.is_in_group(definition.required_target_group):
		return REASON_TARGET_TAG
	if not target_node.has_method("get_persistent_uuid") or String(target_node.call("get_persistent_uuid")) != target_uuid:
		return REASON_TARGET_IDENTITY
	if _operator.global_position.distance_to(target_node.global_position) > definition.maximum_range:
		return REASON_OUT_OF_RANGE
	if not _has_line_of_sight(target_node):
		return REASON_NO_LINE_OF_SIGHT
	if _state.get_cooldown_remaining(target_uuid, definition.ability_id) > 0.0:
		return REASON_COOLDOWN
	if _state.current_energy < definition.energy_cost:
		return REASON_INSUFFICIENT_ENERGY
	return &""


func _has_line_of_sight(target_node: Node3D) -> bool:
	var origin: Vector3 = _operator.global_position + Vector3.UP * 1.5
	var destination: Vector3 = target_node.global_position
	if _line_of_sight_check.is_valid():
		return bool(_line_of_sight_check.call(origin, destination))
	var world: World3D = _operator.get_world_3d()
	if world == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination)
	if _operator is CollisionObject3D:
		query.exclude = [(_operator as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Variant = hit.get("collider")
	return collider == target_node or collider is Node and target_node.is_ancestor_of(collider as Node)


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


func _reject(target_uuid: String, ability_id: int, reason: StringName) -> bool:
	last_rejection_reason = reason
	hack_rejected.emit(target_uuid, ability_id, reason)
	return false


