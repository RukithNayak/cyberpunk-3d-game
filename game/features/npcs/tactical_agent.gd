extends CharacterBody3D
class_name TacticalAgent
## Deterministic goon decisions. Locomotion is an intent consumed by AI-03 navigation.

signal state_changed(state: int, substate: int)
signal movement_intent_changed(destination: Vector3, speed: float, active: bool)
signal attack_delivered(target: Node3D, amount: int)
signal agent_died

enum AIState { IDLE, INVESTIGATE, COMBAT, FLEE, DEAD }
enum Substate { IDLE, PATROL, INVESTIGATE, SEARCH, PURSUE, ATTACK, REPOSITION, FLEE, STUNNED, DEAD }

const MAX_TICK_SECONDS: float = 0.25
const MAX_STUN_SECONDS: float = 30.0
const MAX_DAMAGE_PER_ATTACK: int = 100
const MAX_ATTACK_INTERVAL: float = 60.0
const DEFAULT_MAX_HEALTH: int = 80
const DEFAULT_ATTACK_DAMAGE: int = 10
const DEFAULT_ATTACK_INTERVAL: float = 1.25
const DEFAULT_ATTACK_RANGE: float = 1.75
const DEFAULT_REPOSITION_RANGE: float = 0.9
const DEFAULT_FLEE_HEALTH_RATIO: float = 0.25
const DEFAULT_MOVE_SPEED: float = 2.5
const DEFAULT_SEARCH_SECONDS: float = 3.0
const ARRIVAL_DISTANCE: float = 0.35
const REPOSITION_DISTANCE: float = 2.0
const FLEE_DISTANCE: float = 8.0

@export_range(1, 10000, 1) var maximum_health: int = DEFAULT_MAX_HEALTH
@export_range(1, MAX_DAMAGE_PER_ATTACK, 1) var attack_damage: int = DEFAULT_ATTACK_DAMAGE
@export_range(0.25, MAX_ATTACK_INTERVAL, 0.05) var attack_interval_seconds: float = DEFAULT_ATTACK_INTERVAL
@export_range(0.1, 20.0, 0.05) var attack_range: float = DEFAULT_ATTACK_RANGE
@export_range(0.0, 19.9, 0.05) var preferred_attack_distance: float = DEFAULT_REPOSITION_RANGE
@export_range(0.01, 1.0, 0.01) var flee_health_ratio: float = DEFAULT_FLEE_HEALTH_RATIO
@export_range(0.1, 20.0, 0.05) var movement_speed: float = DEFAULT_MOVE_SPEED
@export_range(0.1, 60.0, 0.1) var search_duration_seconds: float = DEFAULT_SEARCH_SECONDS
@export var process_ai: bool = true

var state: AIState = AIState.IDLE
var substate: Substate = Substate.IDLE
var health_state: HealthState
var movement_destination: Vector3 = Vector3.ZERO
var has_movement_intent: bool = false

var _perception: NpcPerception
var _faction_id: String = ""
var _configured: bool = false
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _candidate_target: Node3D
var _candidate_faction: String = ""
var _combat_target: Node3D
var _combat_faction: String = ""
var _last_hostile_position: Vector3 = Vector3.ZERO
var _has_last_hostile_position: bool = false
var _authored_hostility: Dictionary = {}
var _attack_remaining: float = 0.0
var _stun_remaining: float = 0.0
var _search_remaining: float = 0.0
var _movement_speed_intent: float = 0.0
var _unloaded: bool = false


func _ready() -> void:
	_perception = get_node_or_null("Perception") as NpcPerception
	if _perception != null and not _perception.sound_event_heard.is_connected(_on_sound_event_heard):
		_perception.sound_event_heard.connect(_on_sound_event_heard)


func _physics_process(delta: float) -> void:
	if process_ai:
		tick(delta)


func configure(faction_state: FactionState, faction_id: String, patrol_points: Array[Vector3] = []) -> bool:
	if _configured or faction_state == null or faction_id.is_empty() or faction_id != faction_id.strip_edges():
		return false
	if maximum_health <= 0 or maximum_health > 10000 or attack_damage <= 0 or attack_damage > MAX_DAMAGE_PER_ATTACK:
		return false
	if not is_finite(attack_interval_seconds) or attack_interval_seconds < 0.25 or attack_interval_seconds > MAX_ATTACK_INTERVAL:
		return false
	if not is_finite(attack_range) or attack_range <= preferred_attack_distance or not is_finite(preferred_attack_distance) or preferred_attack_distance < 0.0:
		return false
	if not is_finite(flee_health_ratio) or flee_health_ratio <= 0.0 or flee_health_ratio > 1.0:
		return false
	if not is_finite(movement_speed) or movement_speed <= 0.0 or not is_finite(search_duration_seconds) or search_duration_seconds <= 0.0:
		return false
	for point: Vector3 in patrol_points:
		if not _is_finite_vector(point):
			return false
	if _perception == null:
		_perception = get_node_or_null("Perception") as NpcPerception
	if _perception == null or not _perception.configure(faction_state):
		return false
	if not _perception.sound_event_heard.is_connected(_on_sound_event_heard):
		_perception.sound_event_heard.connect(_on_sound_event_heard)
	health_state = HealthState.new(maximum_health)
	health_state.on_death.connect(_on_death)
	_faction_id = faction_id
	_patrol_points = patrol_points.duplicate()
	_patrol_index = 0
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func capture_simulation_data() -> Dictionary:
	if not _configured or health_state == null:
		return {}
	return {
		"faction_id": _faction_id,
		"current_health": health_state.current_hp,
		"maximum_health": health_state.max_hp,
		"position": global_position,
		"rotation": global_basis.get_rotation_quaternion().normalized(),
		"dead": state == AIState.DEAD or health_state.is_dead(),
	}


func restore_simulation_state(faction_state: FactionState, faction_id: String, current_health: int, maximum: int, world_position: Vector3, world_rotation: Quaternion, dead: bool) -> bool:
	if _configured or _unloaded or faction_state == null or faction_id.is_empty() or faction_id != faction_id.strip_edges():
		return false
	if maximum <= 0 or maximum > 10000 or current_health < 0 or current_health > maximum:
		return false
	if dead != (current_health == 0) or not _is_finite_vector(world_position):
		return false
	if not is_finite(world_rotation.x) or not is_finite(world_rotation.y) or not is_finite(world_rotation.z) or not is_finite(world_rotation.w):
		return false
	if world_rotation.length_squared() <= 0.000001:
		return false
	if not configure(faction_state, faction_id):
		return false
	if not health_state.restore(current_health, maximum):
		return false
	global_position = world_position
	global_basis = Basis(world_rotation.normalized())
	_candidate_target = null
	_candidate_faction = ""
	_combat_target = null
	_combat_faction = ""
	_last_hostile_position = Vector3.ZERO
	_has_last_hostile_position = false
	_attack_remaining = 0.0
	_stun_remaining = 0.0
	_search_remaining = 0.0
	_authored_hostility.clear()
	if dead:
		state = AIState.DEAD
		substate = Substate.DEAD
		has_movement_intent = false
		process_ai = false
	else:
		state = AIState.IDLE
		substate = Substate.IDLE
		has_movement_intent = false
		process_ai = true
	_unloaded = false
	return true


func prepare_for_unload() -> void:
	if _unloaded:
		return
	_unloaded = true
	process_ai = false
	_candidate_target = null
	_candidate_faction = ""
	_combat_target = null
	_combat_faction = ""
	_last_hostile_position = Vector3.ZERO
	_has_last_hostile_position = false
	_attack_remaining = 0.0
	_stun_remaining = 0.0
	_search_remaining = 0.0
	_authored_hostility.clear()
	if _perception != null:
		if _perception.sound_event_heard.is_connected(_on_sound_event_heard):
			_perception.sound_event_heard.disconnect(_on_sound_event_heard)
		_perception.data.has_visual_contact = false
		_perception.data.seen_position = Vector3.ZERO
		_perception.data.has_seen_position = false
		_perception.data.last_known_position = Vector3.ZERO
		_perception.data.has_last_known_position = false
		_perception.data.heard_events.clear()
	var driver: Node = get_node_or_null("NavigationDriver")
	if driver != null:
		driver.set("process_navigation", false)
	if state != AIState.DEAD:
		state = AIState.IDLE
		substate = Substate.IDLE
		movement_destination = Vector3.ZERO
		has_movement_intent = false
		_movement_speed_intent = 0.0
		movement_intent_changed.emit(Vector3.ZERO, 0.0, false)


func set_candidate_target(target: Node3D, target_faction: String) -> bool:
	if not _configured or (target != null and (not _is_live_node(target) or target_faction.is_empty() or target_faction != target_faction.strip_edges())):
		return false
	_candidate_target = target
	_candidate_faction = target_faction if target != null else ""
	return true


func set_authored_hostility(target_faction: String, hostile: bool) -> bool:
	if not _configured or target_faction.is_empty() or target_faction != target_faction.strip_edges():
		return false
	_authored_hostility[target_faction] = hostile
	return true


func clear_authored_hostility(target_faction: String) -> void:
	_authored_hostility.erase(target_faction)


func apply_stun(duration_seconds: float) -> bool:
	if not _configured or not is_finite(duration_seconds) or duration_seconds <= 0.0 or duration_seconds > MAX_STUN_SECONDS or state == AIState.DEAD:
		return false
	_stun_remaining = maxf(_stun_remaining, duration_seconds)
	_set_substate(Substate.STUNNED)
	_set_movement_intent(Vector3.ZERO, 0.0, false)
	return true


func apply_damage(amount: int, source_faction: String, attacker: Node3D = null) -> void:
	if not _configured or state == AIState.DEAD or amount <= 0:
		return
	health_state.apply_damage(amount, source_faction)
	if state == AIState.DEAD:
		return
	if attacker != null and _is_live_node(attacker) and _is_hostile(source_faction):
		_candidate_target = attacker
		_candidate_faction = source_faction


func tick(delta: float) -> bool:
	if not _configured or _unloaded or not is_finite(delta) or delta < 0.0 or delta > MAX_TICK_SECONDS:
		return false
	if state == AIState.DEAD or health_state.is_dead():
		_on_death()
		return false
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		_set_substate(Substate.STUNNED)
		_set_movement_intent(Vector3.ZERO, 0.0, false)
		return true
	_update_perception_and_target()
	if state == AIState.DEAD:
		return false
	match state:
		AIState.IDLE:
			_advance_patrol()
		AIState.INVESTIGATE:
			_advance_investigation(delta)
		AIState.COMBAT:
			_advance_combat(delta)
		AIState.FLEE:
			_advance_flee()
		AIState.DEAD:
			return false
	return true


func get_state_name() -> StringName:
	return AIState.keys()[state].to_lower()


func get_substate_name() -> StringName:
	return Substate.keys()[substate].to_lower()


func get_movement_destination() -> Vector3:
	return movement_destination


func get_health_ratio() -> float:
	if health_state == null or health_state.max_hp <= 0:
		return 0.0
	return float(health_state.current_hp) / float(health_state.max_hp)


func _update_perception_and_target() -> void:
	if _candidate_target != null and not _is_live_node(_candidate_target):
		_candidate_target = null
		_candidate_faction = ""
	var visible: bool = _perception.update_visual_target(_candidate_target)
	if visible and _is_hostile(_candidate_faction):
		_last_hostile_position = _candidate_target.global_position
		_has_last_hostile_position = true
		if get_health_ratio() <= flee_health_ratio:
			_combat_target = null
			_set_state(AIState.FLEE)
			return
		_combat_target = _candidate_target
		_combat_faction = _candidate_faction
		_set_state(AIState.COMBAT)
		return
	if visible and not _is_hostile(_candidate_faction) and state == AIState.COMBAT and _combat_target == _candidate_target:
		_combat_target = null
		_combat_faction = ""
		_set_state(AIState.IDLE)
		return
	if state == AIState.COMBAT and (_combat_target == null or not _is_live_node(_combat_target) or _combat_target == _candidate_target):
		var lost_faction: String = _combat_faction
		_combat_target = null
		_combat_faction = ""
		if _is_hostile(lost_faction) and _perception.data.has_last_known_position:
			_last_hostile_position = _perception.data.last_known_position
			_has_last_hostile_position = true
			_set_state(AIState.INVESTIGATE)
		else:
			_set_state(AIState.IDLE)


func _advance_patrol() -> void:
	if _patrol_points.is_empty():
		_set_substate(Substate.IDLE)
		_set_movement_intent(Vector3.ZERO, 0.0, false)
		return
	var destination: Vector3 = _patrol_points[_patrol_index]
	if global_position.distance_to(destination) <= ARRIVAL_DISTANCE:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		destination = _patrol_points[_patrol_index]
	_set_substate(Substate.PATROL)
	_set_movement_intent(destination, movement_speed, true)


func _advance_investigation(delta: float) -> void:
	if not _has_last_hostile_position:
		_set_state(AIState.IDLE)
		return
	if global_position.distance_to(_last_hostile_position) > ARRIVAL_DISTANCE:
		_search_remaining = search_duration_seconds
		_set_substate(Substate.INVESTIGATE)
		_set_movement_intent(_last_hostile_position, movement_speed, true)
		return
	if substate != Substate.SEARCH:
		_search_remaining = search_duration_seconds
	_set_substate(Substate.SEARCH)
	_set_movement_intent(Vector3.ZERO, 0.0, false)
	_search_remaining = maxf(0.0, _search_remaining - delta)
	if _search_remaining <= 0.0:
		_has_last_hostile_position = false
		_set_state(AIState.IDLE)


func _advance_combat(delta: float) -> void:
	if not _is_damageable_target(_combat_target):
		_combat_target = null
		_combat_faction = ""
		_set_state(AIState.INVESTIGATE if _has_last_hostile_position else AIState.IDLE)
		return
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	var target_position: Vector3 = _last_hostile_position
	var distance: float = global_position.distance_to(target_position)
	if distance > attack_range:
		_set_substate(Substate.PURSUE)
		_set_movement_intent(target_position, movement_speed, true)
		return
	if distance < preferred_attack_distance:
		var away: Vector3 = global_position - target_position
		if away.length_squared() <= 0.000001:
			away = Vector3.RIGHT
		var reposition_destination: Vector3 = global_position + away.normalized() * REPOSITION_DISTANCE
		_set_substate(Substate.REPOSITION)
		_set_movement_intent(reposition_destination, movement_speed, true)
		return
	_set_substate(Substate.ATTACK)
	_set_movement_intent(Vector3.ZERO, 0.0, false)
	if _attack_remaining <= 0.0 and _is_hostile(_combat_faction) and _is_damageable_target(_combat_target):
		var damage: int = clampi(attack_damage, 1, MAX_DAMAGE_PER_ATTACK)
		_combat_target.call("apply_damage", damage, _faction_id)
		_attack_remaining = attack_interval_seconds
		attack_delivered.emit(_combat_target, damage)


func _advance_flee() -> void:
	var away: Vector3 = global_position - _last_hostile_position if _has_last_hostile_position else Vector3.RIGHT
	if away.length_squared() <= 0.000001:
		away = Vector3.RIGHT
	_set_substate(Substate.FLEE)
	_set_movement_intent(global_position + away.normalized() * FLEE_DISTANCE, movement_speed, true)


func _on_sound_event_heard(event: Dictionary) -> void:
	if state == AIState.DEAD or state == AIState.COMBAT or state == AIState.FLEE or typeof(event.get("position")) != TYPE_VECTOR3:
		return
	_last_hostile_position = event["position"]
	_has_last_hostile_position = true
	_combat_target = null
	_combat_faction = ""
	_search_remaining = search_duration_seconds
	_set_state(AIState.INVESTIGATE)


func _on_death() -> void:
	if state == AIState.DEAD:
		return
	state = AIState.DEAD
	substate = Substate.DEAD
	_candidate_target = null
	_combat_target = null
	has_movement_intent = false
	_movement_speed_intent = 0.0
	state_changed.emit(state, substate)
	movement_intent_changed.emit(Vector3.ZERO, 0.0, false)
	agent_died.emit()


func _is_hostile(target_faction: String) -> bool:
	if _authored_hostility.has(target_faction):
		return bool(_authored_hostility[target_faction])
	return _perception != null and _perception.evaluate_target_hostility(target_faction)


func _is_damageable_target(target: Node3D) -> bool:
	return _is_live_node(target) and target.has_method("apply_damage") and (not target.has_method("is_alive") or bool(target.call("is_alive")))


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


func _set_state(next_state: AIState) -> void:
	if state == next_state:
		return
	state = next_state
	match state:
		AIState.IDLE:
			substate = Substate.IDLE
		AIState.INVESTIGATE:
			substate = Substate.INVESTIGATE
			_search_remaining = search_duration_seconds
		AIState.COMBAT:
			substate = Substate.PURSUE
		AIState.FLEE:
			substate = Substate.FLEE
		AIState.DEAD:
			substate = Substate.DEAD
	state_changed.emit(state, substate)


func _set_substate(next_substate: Substate) -> void:
	if substate == next_substate:
		return
	substate = next_substate
	state_changed.emit(state, substate)


func _set_movement_intent(destination: Vector3, speed: float, active: bool) -> void:
	if has_movement_intent == active and (not active or movement_destination.is_equal_approx(destination) and is_equal_approx(_movement_speed_intent, speed)):
		return
	has_movement_intent = active
	movement_destination = destination
	_movement_speed_intent = speed
	movement_intent_changed.emit(destination, speed, active)


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
