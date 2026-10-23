extends Node
class_name WeaponController

signal shot_fired(result: HitResult)

const HIT_RESULT_SCRIPT: Script = preload("res://features/combat/hit_result.gd")
const DEFAULT_SEED: int = 173

@export var default_weapon_stats: WeaponStats
@export_flags_3d_physics var hit_mask: int = 0xFFFFFFFF
@export var random_seed: int = DEFAULT_SEED

var _player: Node
var _camera: Camera3D
var _muzzle: Marker3D
var _next_fire_msec: int = 0
var _clock: Callable
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = random_seed
	_player = get_parent()
	if _player != null:
		_camera = _player.find_child("Camera3D", true, false) as Camera3D
		_muzzle = _player.find_child("Muzzle", true, false) as Marker3D
		if _player.has_signal("fire_requested"):
			_player.fire_requested.connect(_on_fire_requested)


func set_clock_for_testing(clock: Callable) -> bool:
	if not clock.is_valid():
		return false
	_clock = clock
	return true


func set_random_seed(seed_value: int) -> void:
	random_seed = seed_value
	_random.seed = seed_value


func fire_weapon(weapon_stats: Resource) -> HitResult:
	var result: HitResult = HIT_RESULT_SCRIPT.new() as HitResult
	var stats: WeaponStats = weapon_stats as WeaponStats
	if stats == null:
		return _reject(result, "Invalid weapon stats")
	if not _actor_can_fire():
		return _reject(result, "Actor cannot fire")
	if _camera == null or _muzzle == null or not is_instance_valid(_camera) or not is_instance_valid(_muzzle):
		return _reject(result, "Weapon camera or muzzle is unavailable")
	var now_msec: int = _now_msec()
	if now_msec < _next_fire_msec:
		return _reject(result, "Weapon is on cooldown")
	if stats.damage < 1 or stats.range_m <= 0.0 or stats.fire_rate_per_second <= 0.0:
		return _reject(result, "Weapon stats are outside valid firing bounds")

	var direction: Vector3 = _spread_direction(_camera.global_basis, stats.spread_degrees)
	var camera_origin: Vector3 = _camera.global_position
	var max_distance: float = stats.range_m
	var camera_hit: Dictionary = _raycast(camera_origin, direction, max_distance)
	var aim_point: Vector3 = camera_origin + direction * max_distance
	if not camera_hit.is_empty():
		aim_point = camera_hit["position"]

	var muzzle_origin: Vector3 = _muzzle.global_position
	var muzzle_delta: Vector3 = aim_point - muzzle_origin
	var muzzle_length: float = minf(muzzle_delta.length(), max_distance)
	var muzzle_hit: Dictionary = _raycast(muzzle_origin, muzzle_delta.normalized(), muzzle_length)
	var actual_hit: Dictionary = muzzle_hit if not muzzle_hit.is_empty() else camera_hit
	result.fired = true
	if not actual_hit.is_empty():
		result.hit_position = actual_hit["position"]
		result.surface_normal = actual_hit["normal"]
		result.target_node = actual_hit["collider"] as Node
		result.distance_m = camera_origin.distance_to(result.hit_position)
		if result.target_node != null and result.target_node.has_method("apply_damage"):
			result.damage_applied = stats.damage_at_distance(result.distance_m)
			result.target_node.call("apply_damage", result.damage_applied, String(stats.source_faction))
	else:
		result.hit_position = aim_point
		result.distance_m = max_distance

	_next_fire_msec = now_msec + maxi(1, ceili(1000.0 / stats.fire_rate_per_second))
	if _player.has_method("apply_recoil"):
		_player.call("apply_recoil", stats.recoil_degrees)
	shot_fired.emit(result)
	return result


func _actor_can_fire() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("can_fire"):
		return bool(_player.call("can_fire"))
	return bool(_player.get("can_act")) and bool(_player.get("is_alive"))


func _raycast(origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	if distance <= 0.0 or direction.is_zero_approx():
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance, hit_mask)
	var exclusions: Array[RID] = []
	if _player is CollisionObject3D:
		exclusions.append((_player as CollisionObject3D).get_rid())
	query.exclude = exclusions
	query.collide_with_areas = false
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)


func _spread_direction(basis: Basis, degrees: float) -> Vector3:
	var forward: Vector3 = -basis.z.normalized()
	if degrees <= 0.0:
		return forward
	var spread: float = tan(deg_to_rad(degrees))
	var horizontal: float = _random.randf_range(-spread, spread)
	var vertical: float = _random.randf_range(-spread, spread)
	return (forward + basis.x * horizontal + basis.y * vertical).normalized()


func _now_msec() -> int:
	return int(_clock.call()) if _clock.is_valid() else Time.get_ticks_msec()


func _reject(result: HitResult, reason: String) -> HitResult:
	result.rejected_reason = reason
	return result


func _on_fire_requested() -> void:
	var action_machine: Node = get_parent().get_node_or_null("WeaponStateMachine") if get_parent() != null else null
	if action_machine != null and action_machine.has_method("is_configured") and bool(action_machine.call("is_configured")):
		action_machine.call("fire_current_weapon")
		return
	if default_weapon_stats != null:
		fire_weapon(default_weapon_stats)
