extends RefCounted
class_name PlayerSnapshot
## Data-only player checkpoint adapter. Inventory owns equipment, rolls and magazines.

const MAX_ABS_POSITION: float = 1000000.0

var _player: Node3D
var _health: HealthState
var _actions: WeaponStateMachine


func _init(player: Node3D = null, health: HealthState = null, actions: WeaponStateMachine = null) -> void:
	_player = player
	_health = health
	_actions = actions


func capture() -> Dictionary:
	if _player == null or _health == null or not is_instance_valid(_player):
		return {}
	var position: Vector3 = _player.global_position
	return {"health": _health.current_hp, "max_health": _health.max_hp, "position": [position.x, position.y, position.z]}


func prepare(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 3 or typeof(candidate.get("health")) != TYPE_INT or typeof(candidate.get("max_health")) != TYPE_INT or typeof(candidate.get("position")) != TYPE_ARRAY:
		return {"ok": false, "prepared": {}}
	var health: int = candidate["health"]
	var maximum: int = candidate["max_health"]
	var coordinates: Array = candidate["position"]
	if maximum <= 0 or health < 0 or health > maximum or coordinates.size() != 3:
		return {"ok": false, "prepared": {}}
	for coordinate: Variant in coordinates:
		if (typeof(coordinate) != TYPE_FLOAT and typeof(coordinate) != TYPE_INT) or not is_finite(float(coordinate)) or absf(float(coordinate)) > MAX_ABS_POSITION:
			return {"ok": false, "prepared": {}}
	return {"ok": true, "prepared": {"health": health, "max_health": maximum, "position": [float(coordinates[0]), float(coordinates[1]), float(coordinates[2])]}}


func commit_prepared(prepared: Dictionary) -> bool:
	var checked: Dictionary = prepare(prepared)
	if not bool(checked.get("ok", false)) or _player == null or _health == null or not is_instance_valid(_player):
		return false
	var data: Dictionary = checked["prepared"]
	if not _health.restore(int(data["health"]), int(data["max_health"])):
		return false
	if _actions != null:
		_actions.cancel_action()
	var coordinates: Array = data["position"]
	_player.global_position = Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	return true
