extends Control
class_name AiDebugOverlay
## Optional in-scene diagnostic view; never participates in gameplay decisions.

@export var navigation_driver_path: NodePath = NodePath("../NavigationDriver")
@export var refresh_interval: float = 0.15

var _elapsed: float = 0.0
var _driver: Node
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.name = "Readout"
	_label.position = Vector2(12.0, 12.0)
	_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.8, 1.0))
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	_driver = get_node_or_null(navigation_driver_path)
	refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = 0.0
	refresh()


func refresh() -> void:
	if _label == null:
		return
	if _driver == null or not is_instance_valid(_driver):
		_driver = get_node_or_null(navigation_driver_path)
	if _driver == null:
		_label.text = "AI NAV / unavailable"
		return
	var destination: Vector3 = _driver.call("get_destination")
	var last_point: Vector3 = _driver.get("last_valid_position")
	var has_last: bool = _driver.get("has_last_valid_position")
	var perception: String = _driver.call("get_perception_summary")
	_label.text = "AI %s / %s\nNAV %s / %s\nDEST %s\nLAST %s" % [
		String(_driver.call("get_state_name")).to_upper(),
		String(_driver.get("debug_state")).to_upper(),
		"READY" if bool(_driver.get("navigation_ready")) else "WAIT",
		perception.to_upper(),
		_vector_text(destination),
		_vector_text(last_point) if has_last else "none",
	]


func _vector_text(value: Vector3) -> String:
	return "%.1f, %.1f, %.1f" % [value.x, value.y, value.z]
