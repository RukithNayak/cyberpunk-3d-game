extends RefCounted
class_name PlayerInputSettings

const FORMAT_VERSION: int = 1
const DEFAULT_PATH: String = "user://player_settings.json"
const MIN_FOV: float = 60.0
const MAX_FOV: float = 120.0
const MIN_SENSITIVITY: float = 0.0001
const MAX_SENSITIVITY: float = 0.01

const DEFAULT_KEYS: Dictionary = {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"jump": KEY_SPACE,
	&"run": KEY_SHIFT,
	&"crouch": KEY_CTRL,
	&"interact": KEY_E,
	&"fire": KEY_ENTER,
	&"pause": KEY_ESCAPE,
}

var settings_path: String
var _fov: float = 90.0
var _sensitivity: float = 0.002
var _invert_look: bool = false
var _bindings: Dictionary = {}


func _init(path: String = DEFAULT_PATH) -> void:
	settings_path = path
	_ensure_actions()


func restore_defaults() -> bool:
	_fov = 90.0
	_sensitivity = 0.002
	_invert_look = false
	_bindings.clear()
	for action: StringName in DEFAULT_KEYS:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = DEFAULT_KEYS[action]
		_bindings[action] = event
		_apply_binding(action, event)
	return true


func set_camera_settings(fov: float, sensitivity: float, invert_look: bool) -> bool:
	if not is_finite(fov) or fov < MIN_FOV or fov > MAX_FOV:
		return false
	if not is_finite(sensitivity) or sensitivity < MIN_SENSITIVITY or sensitivity > MAX_SENSITIVITY:
		return false
	_fov = fov
	_sensitivity = sensitivity
	_invert_look = invert_look
	return true


func get_fov() -> float:
	return _fov


func get_sensitivity() -> float:
	return _sensitivity


func get_invert_look() -> bool:
	return _invert_look


func rebind(action: StringName, event: InputEvent) -> bool:
	if not DEFAULT_KEYS.has(action) or not _is_supported_binding(event):
		return false
	for other_action: StringName in _bindings:
		if other_action != action and _events_conflict(event, _bindings[other_action]):
			return false
	var copied: InputEvent = event.duplicate() as InputEvent
	_bindings[action] = copied
	_apply_binding(action, copied)
	return true


func save_settings() -> bool:
	var saved_bindings: Dictionary = {}
	for action: StringName in _bindings:
		saved_bindings[String(action)] = _encode_event(_bindings[action] as InputEvent)
	var payload: Dictionary = {
		"version": FORMAT_VERSION,
		"fov": _fov,
		"sensitivity": _sensitivity,
		"invert_look": _invert_look,
		"bindings": saved_bindings,
	}
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK


func load_settings() -> bool:
	if not FileAccess.file_exists(settings_path):
		return false
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = parsed
	if int(payload.get("version", -1)) != FORMAT_VERSION:
		return false
	var fov: float = float(payload.get("fov", NAN))
	var sensitivity: float = float(payload.get("sensitivity", NAN))
	var invert: Variant = payload.get("invert_look", null)
	if not is_finite(fov) or fov < MIN_FOV or fov > MAX_FOV:
		return false
	if not is_finite(sensitivity) or sensitivity < MIN_SENSITIVITY or sensitivity > MAX_SENSITIVITY:
		return false
	if typeof(invert) != TYPE_BOOL or typeof(payload.get("bindings")) != TYPE_DICTIONARY:
		return false
	var decoded: Dictionary = {}
	var bindings: Dictionary = payload["bindings"]
	for action: StringName in DEFAULT_KEYS:
		var event: InputEvent
		if bindings.has(String(action)):
			event = _decode_event(bindings[String(action)])
		elif action == &"pause":
			var default_pause: InputEventKey = InputEventKey.new()
			default_pause.physical_keycode = KEY_ESCAPE
			event = default_pause
		else:
			return false
		if event == null:
			return false
		if event == null or not _is_supported_binding(event):
			return false
		for other: StringName in decoded:
			if _events_conflict(event, decoded[other] as InputEvent):
				return false
		decoded[action] = event
	_fov = fov
	_sensitivity = sensitivity
	_invert_look = invert
	_bindings = decoded
	for action: StringName in _bindings:
		_apply_binding(action, _bindings[action] as InputEvent)
	return true


func _ensure_actions() -> void:
	for action: StringName in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = DEFAULT_KEYS[action]
			InputMap.action_add_event(action, event)
			_bindings[action] = event
		else:
			var events: Array[InputEvent] = InputMap.action_get_events(action)
			if not events.is_empty():
				_bindings[action] = events[0].duplicate()
			else:
				var fallback: InputEventKey = InputEventKey.new()
				fallback.physical_keycode = DEFAULT_KEYS[action]
				_bindings[action] = fallback
				InputMap.action_add_event(action, fallback)


func _apply_binding(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate())


func _is_supported_binding(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode != KEY_NONE
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index > MOUSE_BUTTON_NONE
	return false


func _events_conflict(left: InputEvent, right: InputEvent) -> bool:
	if left is InputEventKey and right is InputEventKey:
		return (left as InputEventKey).physical_keycode == (right as InputEventKey).physical_keycode
	if left is InputEventMouseButton and right is InputEventMouseButton:
		return (left as InputEventMouseButton).button_index == (right as InputEventMouseButton).button_index
	return false


func _encode_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return {"kind": "key", "physical_keycode": key.physical_keycode, "shift": key.shift_pressed, "ctrl": key.ctrl_pressed, "alt": key.alt_pressed, "meta": key.meta_pressed}
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	return {"kind": "mouse", "button_index": mouse.button_index}


func _decode_event(data: Variant) -> InputEvent:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var record: Dictionary = data
	match record.get("kind", ""):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(record.get("physical_keycode", KEY_NONE)) as Key
			key.shift_pressed = bool(record.get("shift", false))
			key.ctrl_pressed = bool(record.get("ctrl", false))
			key.alt_pressed = bool(record.get("alt", false))
			key.meta_pressed = bool(record.get("meta", false))
			return key
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(record.get("button_index", MOUSE_BUTTON_NONE)) as MouseButton
			return mouse
	return null
