extends Node3D
class_name NpcNavigationDriver
## Drives a TacticalAgent with Godot's navigation map and bounded recovery.

signal recovered(reason: StringName, position: Vector3)
signal safely_despawned(reason: StringName)

const DEFAULT_STUCK_SECONDS: float = 2.0
const DEFAULT_UNREACHABLE_SECONDS: float = 3.0
const DEFAULT_PROGRESS_DISTANCE: float = 0.12
const DEFAULT_ARRIVAL_DISTANCE: float = 0.55
const MAX_RECOVERY_ATTEMPTS: int = 2
const RECOVERY_SEARCH_RADIUS: float = 1.5
const PROJECTION_TOLERANCE: float = 0.8
const TARGET_PROJECTION_TOLERANCE: float = 1.25

@export_range(0.25, 10.0, 0.25) var stuck_timeout_seconds: float = DEFAULT_STUCK_SECONDS
@export_range(0.5, 10.0, 0.25) var unreachable_timeout_seconds: float = DEFAULT_UNREACHABLE_SECONDS
@export_range(0.1, 5.0, 0.1) var arrival_distance: float = DEFAULT_ARRIVAL_DISTANCE
@export var process_navigation: bool = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var last_valid_position: Vector3 = Vector3.ZERO
var has_last_valid_position: bool = false
var navigation_ready: bool = false
var debug_state: StringName = &"waiting"
var _readiness_provider: Callable
var _actor: CharacterBody3D
var _intent_active: bool = false
var _path_target_set: bool = false
var _destination: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _stuck_seconds: float = 0.0
var _unreachable_seconds: float = 0.0
var _no_map_seconds: float = 0.0
var _off_mesh_seconds: float = 0.0
var _has_seen_navigation: bool = false
var _recovery_attempts: int = 0
var _last_progress_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_actor = get_parent() as CharacterBody3D
	if _actor == null:
		_set_debug_state(&"invalid_actor")
		return
	if _actor.has_signal("movement_intent_changed"):
		var signal_ref: Signal = _actor.get("movement_intent_changed")
		if not signal_ref.is_connected(_on_movement_intent_changed):
			signal_ref.connect(_on_movement_intent_changed)
	_update_last_valid()


func set_readiness_provider(provider: Callable) -> bool:
	if provider.is_valid() and provider.get_argument_count() != 0:
		return false
	_readiness_provider = provider
	return true


func get_destination() -> Vector3:
	return _destination


func get_state_name() -> StringName:
	if _actor != null and is_instance_valid(_actor) and _actor.has_method("get_state_name"):
		return StringName(_actor.call("get_state_name"))
	return &"unavailable"


func get_perception_summary() -> String:
	if _actor == null or not is_instance_valid(_actor):
		return "unavailable"
	var perception: Node = _actor.get_node_or_null("Perception")
	if perception == null:
		return "none"
	var data: Variant = perception.get("data")
	if data == null:
		return "none"
	if bool(data.get("has_visual_contact")):
		return "visual contact"
	if bool(data.get("has_last_known_position")):
		return "last known position"
	var heard: Variant = data.get("heard_events")
	return "heard event (%d)" % heard.size() if heard is Array and not heard.is_empty() else "none"


func _physics_process(delta: float) -> void:
	if not process_navigation or _actor == null or not is_instance_valid(_actor) or _actor.is_queued_for_deletion():
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	var bounded_delta: float = minf(delta, 0.25)
	navigation_ready = _is_navigation_ready()
	if not navigation_ready:
		debug_state = &"waiting_for_navigation"
		_stop_actor()
		if _has_seen_navigation:
			_no_map_seconds += bounded_delta
			if _no_map_seconds >= unreachable_timeout_seconds:
				_recover_or_despawn(&"navigation_unavailable")
		return
	_has_seen_navigation = true
	_no_map_seconds = 0.0
	if not _update_last_valid():
		if has_last_valid_position:
			_actor.global_position = last_valid_position
			_actor.velocity = Vector3.ZERO
			recovered.emit(&"off_mesh", last_valid_position)
		else:
			_off_mesh_seconds += bounded_delta
			_set_debug_state(&"waiting_for_valid_point")
			_stop_actor()
			if _off_mesh_seconds >= unreachable_timeout_seconds:
				_recover_or_despawn(&"off_mesh_without_recovery_point")
		return
	_off_mesh_seconds = 0.0
	if not _intent_active or _speed <= 0.0:
		debug_state = &"idle"
		_stuck_seconds = 0.0
		_unreachable_seconds = 0.0
		_stop_actor()
		return
	if not _path_target_set:
		var target_projection: Vector3 = NavigationServer3D.map_get_closest_point(navigation_agent.get_navigation_map(), _destination)
		if target_projection.distance_to(_destination) > TARGET_PROJECTION_TOLERANCE:
			_unreachable_seconds += bounded_delta
			_set_debug_state(&"unreachable")
			_stop_actor()
			if _unreachable_seconds >= unreachable_timeout_seconds:
				_recover_or_despawn(&"unreachable_target")
			return
		navigation_agent.target_position = _destination
		_path_target_set = true
	if not navigation_agent.is_target_reachable():
		_unreachable_seconds += bounded_delta
	else:
		_unreachable_seconds = 0.0
	if _unreachable_seconds >= unreachable_timeout_seconds:
		_recover_or_despawn(&"unreachable_target")
		return
	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var current_path: PackedVector3Array = navigation_agent.get_current_navigation_path()
	if current_path.size() < 2 and _actor.global_position.distance_to(_destination) > arrival_distance:
		_set_debug_state(&"path_pending")
		_stop_actor()
		return
	var planar_direction: Vector3 = next_position - _actor.global_position
	planar_direction.y = 0.0
	if _actor.global_position.distance_to(_destination) <= arrival_distance or (current_path.size() >= 2 and navigation_agent.is_navigation_finished()):
		_set_debug_state(&"arrived")
		_stop_actor()
		return
	if planar_direction.length_squared() > 0.0001:
		planar_direction = planar_direction.normalized()
		_actor.velocity.x = planar_direction.x * _speed
		_actor.velocity.z = planar_direction.z * _speed
	else:
		_actor.velocity.x = 0.0
		_actor.velocity.z = 0.0
	if not _actor.is_on_floor():
		_actor.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
	else:
		_actor.velocity.y = 0.0
	_actor.move_and_slide()
	_check_progress(bounded_delta)


func _is_navigation_ready() -> bool:
	if _readiness_provider.is_valid():
		var supplied: Variant = _readiness_provider.call()
		return supplied is bool and supplied
	var map_rid: RID = navigation_agent.get_navigation_map()
	if not map_rid.is_valid() or NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		return false
	if NavigationServer3D.map_get_regions(map_rid).is_empty():
		return false
	var nearest_owner: RID = NavigationServer3D.map_get_closest_point_owner(map_rid, _actor.global_position)
	return nearest_owner.is_valid()


func _update_last_valid() -> bool:
	if not navigation_ready and not _is_navigation_ready():
		return false
	var map_rid: RID = navigation_agent.get_navigation_map()
	if not map_rid.is_valid() or NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		return false
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, _actor.global_position)
	if closest.distance_to(_actor.global_position) > PROJECTION_TOLERANCE:
		return false
	last_valid_position = closest
	has_last_valid_position = true
	return true


func _check_progress(delta: float) -> void:
	if _actor.global_position.distance_to(_last_progress_position) >= DEFAULT_PROGRESS_DISTANCE:
		_last_progress_position = _actor.global_position
		_stuck_seconds = 0.0
		_recovery_attempts = 0
	else:
		_stuck_seconds += delta
	if _stuck_seconds >= stuck_timeout_seconds:
		_recover_or_despawn(&"stuck")
	else:
		_set_debug_state(&"moving")


func _recover_or_despawn(reason: StringName) -> void:
	if has_last_valid_position and _recovery_attempts < MAX_RECOVERY_ATTEMPTS:
		_recovery_attempts += 1
		_actor.global_position = last_valid_position
		_actor.velocity = Vector3.ZERO
		_stuck_seconds = 0.0
		_unreachable_seconds = 0.0
		_last_progress_position = last_valid_position
		if _intent_active and _destination.distance_to(last_valid_position) <= RECOVERY_SEARCH_RADIUS:
			_intent_active = false
		_set_debug_state(&"recovered")
		recovered.emit(reason, last_valid_position)
		return
	_set_debug_state(&"despawned")
	safely_despawned.emit(reason)
	_actor.queue_free()


func _on_movement_intent_changed(destination: Vector3, speed: float, active: bool) -> void:
	if not _is_finite_vector(destination) or not is_finite(speed) or speed < 0.0:
		return
	_destination = destination
	_speed = speed
	_intent_active = active and speed > 0.0
	_path_target_set = false
	_unreachable_seconds = 0.0
	_stuck_seconds = 0.0
	_last_progress_position = _actor.global_position if _actor != null else Vector3.ZERO
	_set_debug_state(&"path_pending" if _intent_active else &"idle")


func _stop_actor() -> void:
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
	if _actor.is_on_floor():
		_actor.velocity.y = 0.0
	_actor.move_and_slide()


func _set_debug_state(value: StringName) -> void:
	debug_state = value


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
