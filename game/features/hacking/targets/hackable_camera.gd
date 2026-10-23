extends StaticBody3D
class_name HackableCamera
## Runtime security sensor. Detection is queried by its owning encounter/AI system.

signal detection_state_changed(target_uuid: String, enabled: bool)

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var persistent_uuid: String = ""
@export var chunk_id: String = ""
@export_range(0.5, 100.0, 0.5) var detection_range: float = 18.0
@export_range(1.0, 179.0, 1.0) var field_of_view_degrees: float = 70.0
@export_flags_3d_physics var detection_collision_mask: int = 1

var detection_enabled: bool = true
var effect_remaining_seconds: float = 0.0
var _external_hack_clock: bool = false

var _uuid_regex: RegEx = RegEx.new()


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func _enter_tree() -> void:
	add_to_group(&"hackable_camera")


func _process(delta: float) -> void:
	if _external_hack_clock or not is_finite(delta) or delta < 0.0 or effect_remaining_seconds <= 0.0:
		return
	effect_remaining_seconds = maxf(0.0, effect_remaining_seconds - delta)
	if effect_remaining_seconds == 0.0 and not detection_enabled and is_inside_tree() and not is_queued_for_deletion():
		detection_enabled = true
		detection_state_changed.emit(persistent_uuid, true)


func get_persistent_uuid() -> String:
	return persistent_uuid


func get_hack_chunk_id() -> String:
	return chunk_id


func set_external_hack_clock(enabled: bool) -> void:
	_external_hack_clock = enabled


func restore_hack_effect(ability_id: int, remaining_seconds: float) -> bool:
	if ability_id != HackDefinition.Ability.DISABLE_CAMERA or not is_finite(remaining_seconds) or remaining_seconds <= 0.0:
		return false
	detection_enabled = false
	effect_remaining_seconds = remaining_seconds
	detection_state_changed.emit(persistent_uuid, false)
	return true


func set_hack_remaining(ability_id: int, remaining_seconds: float) -> bool:
	if ability_id != HackDefinition.Ability.DISABLE_CAMERA or not is_finite(remaining_seconds) or remaining_seconds < 0.0:
		return false
	effect_remaining_seconds = remaining_seconds
	if remaining_seconds == 0.0 and not detection_enabled:
		detection_enabled = true
		detection_state_changed.emit(persistent_uuid, true)
	return true


func clear_hack_effect(ability_id: int) -> bool:
	return set_hack_remaining(ability_id, 0.0)


func can_detect_target(target: Node3D) -> bool:
	if not detection_enabled or not _is_live_node(target):
		return false
	if not is_finite(detection_range) or detection_range <= 0.0:
		return false
	if not is_finite(field_of_view_degrees) or field_of_view_degrees <= 0.0 or field_of_view_degrees >= 180.0:
		return false
	if detection_collision_mask <= 0:
		return false
	var offset: Vector3 = target.global_position - global_position
	var distance: float = offset.length()
	if not is_finite(distance) or distance <= 0.001 or distance > detection_range:
		return false
	var forward: Vector3 = -global_basis.z.normalized()
	var direction: Vector3 = offset / distance
	if forward.dot(direction) < cos(deg_to_rad(field_of_view_degrees * 0.5)):
		return false
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, target.global_position, detection_collision_mask)
	query.exclude = [get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Variant = hit.get("collider")
	return collider == target or collider is Node and target.is_ancestor_of(collider as Node)


func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
	return _is_live_node(self) and _is_valid_hack(definition) and detection_enabled \
		and effect_remaining_seconds <= 0.0 and _has_valid_identity() \
		and is_finite(definition.effect_duration_seconds) and definition.effect_duration_seconds > 0.0


func apply_hack(definition: Resource, operator: Node3D) -> bool:
	if not can_accept_hack(definition, operator):
		return false
	detection_enabled = false
	effect_remaining_seconds = definition.effect_duration_seconds
	detection_state_changed.emit(persistent_uuid, false)
	return true


func _is_valid_hack(definition: Resource) -> bool:
	return definition != null and int(definition.get("ability_id")) == HackDefinition.Ability.DISABLE_CAMERA


func _has_valid_identity() -> bool:
	return _uuid_regex.search(persistent_uuid) != null


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
