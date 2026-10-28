extends Node3D
class_name AmbientAgent
## Lightweight, event-driven pedestrian. It never requests generated behavior.

signal status_changed(status: int, message: String)

enum AmbientStatus { CALM, DISTRACTED, ALERT }

const MAX_UPDATE_INTERVAL: float = 30.0
const DEFAULT_UPDATE_INTERVAL: float = 0.75

@export_range(0.1, MAX_UPDATE_INTERVAL, 0.05) var update_interval_seconds: float = DEFAULT_UPDATE_INTERVAL
@export var debug_enabled: bool = false

var faction_id: String = ""
var area_id: String = ""
var status: AmbientStatus = AmbientStatus.CALM
var last_sound_position: Vector3 = Vector3.ZERO
var has_sound_position: bool = false

var _perception: NpcPerception
var _configured: bool = false
var _simulation_active: bool = true
var _elapsed_seconds: float = 0.0
var _update_count: int = 0
var _update_timer: Timer
var _status_label: Label3D
var _body: MeshInstance3D


func _ready() -> void:
	_perception = get_node_or_null("Perception") as NpcPerception
	if _perception == null:
		_perception = NpcPerception.new()
		_perception.name = "Perception"
		add_child(_perception)
	if not _perception.sound_event_heard.is_connected(_on_sound_event_heard):
		_perception.sound_event_heard.connect(_on_sound_event_heard)
	_ensure_update_timer()
	if _configured and _simulation_active:
		_update_timer.start()
	_create_blockout_presentation()
	_refresh_presentation()


func configure(faction_state: FactionState, configured_faction_id: String, configured_area_id: String, configured_update_interval: float = DEFAULT_UPDATE_INTERVAL) -> bool:
	if _configured or faction_state == null or not _valid_id(configured_faction_id) or not _valid_id(configured_area_id):
		return false
	if not is_finite(configured_update_interval) or configured_update_interval < 0.1 or configured_update_interval > MAX_UPDATE_INTERVAL:
		return false
	if _perception == null:
		_perception = get_node_or_null("Perception") as NpcPerception
	if _perception == null:
		_perception = NpcPerception.new()
		_perception.name = "Perception"
		add_child(_perception)
	if not _perception.configure(faction_state):
		return false
	if not _perception.sound_event_heard.is_connected(_on_sound_event_heard):
		_perception.sound_event_heard.connect(_on_sound_event_heard)
	faction_id = configured_faction_id
	area_id = configured_area_id
	update_interval_seconds = configured_update_interval
	_configured = true
	_ensure_update_timer()
	if is_inside_tree() and _simulation_active:
		_update_timer.start()
	_refresh_presentation()
	return true


## Advances a bounded low-frequency ambient update. Sound response remains event driven.
func tick(delta: float) -> bool:
	if not _configured or not is_finite(delta) or delta < 0.0 or delta > 1.0:
		return false
	if not _simulation_active or delta == 0.0:
		return true
	if _elapsed_seconds + delta >= update_interval_seconds - 0.000001:
		_elapsed_seconds = 0.0
		_update_count += 1
		if debug_enabled:
			_refresh_presentation()
	else:
		_elapsed_seconds += delta
	return true


func set_simulation_active(active: bool) -> void:
	_simulation_active = active
	if _update_timer == null:
		return
	if active and _configured and is_inside_tree():
		_update_timer.start()
	else:
		_update_timer.stop()


func is_simulation_active() -> bool:
	return _simulation_active


func get_update_count() -> int:
	return _update_count


func _ensure_update_timer() -> void:
	if _update_timer == null:
		_update_timer = Timer.new()
		_update_timer.name = "AmbientUpdateTimer"
		_update_timer.one_shot = false
		_update_timer.timeout.connect(_on_update_timer_timeout)
		add_child(_update_timer)
	_update_timer.wait_time = update_interval_seconds
	_update_timer.stop()


func _on_update_timer_timeout() -> void:
	if not _configured or not _simulation_active:
		return
	_update_count += 1
	if debug_enabled:
		_refresh_presentation()


func notify_sound_event(world_position: Vector3, radius: float, source_faction: String) -> void:
	if _configured:
		_perception.notify_sound_event(world_position, radius, source_faction)


func _on_sound_event_heard(event: Dictionary) -> void:
	var source_faction: String = String(event.get("faction_id", ""))
	var heard_position: Variant = event.get("position")
	if not heard_position is Vector3:
		return
	last_sound_position = heard_position
	has_sound_position = true
	status = AmbientStatus.ALERT if _perception.evaluate_target_hostility(source_faction) else AmbientStatus.DISTRACTED
	_refresh_presentation()
	status_changed.emit(status, _status_text())


func _create_blockout_presentation() -> void:
	if _body == null:
		_body = MeshInstance3D.new()
		_body.name = "AmbientBlockout"
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.27
		capsule.height = 1.55
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.92, 0.65, 0.24, 1.0)
		material.roughness = 0.78
		capsule.material = material
		_body.mesh = capsule
		_body.position.y = 0.78
		add_child(_body)
	if _status_label == null:
		_status_label = Label3D.new()
		_status_label.name = "AmbientStatus"
		_status_label.position.y = 1.75
		_status_label.font_size = 28
		_status_label.outline_size = 6
		_status_label.modulate = Color(1.0, 0.83, 0.38, 1.0)
		_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_status_label)


func _refresh_presentation() -> void:
	if _status_label == null:
		return
	_status_label.text = "%s  /  %s" % [faction_id.to_upper() if not faction_id.is_empty() else "AMBIENT", _status_text()]
	if debug_enabled:
		_status_label.text += "\nUPDATES %d" % _update_count
	_status_label.modulate = Color(1.0, 0.28, 0.22, 1.0) if status == AmbientStatus.ALERT else Color(0.28, 0.9, 1.0, 1.0) if status == AmbientStatus.DISTRACTED else Color(1.0, 0.83, 0.38, 1.0)


func _status_text() -> String:
	match status:
		AmbientStatus.ALERT:
			return "ALERT"
		AmbientStatus.DISTRACTED:
			return "DISTRACTED"
		_:
			return "CALM"


func _valid_id(value: String) -> bool:
	return not value.is_empty() and value == value.strip_edges()
