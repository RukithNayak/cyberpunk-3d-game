extends CanvasLayer

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, reason: String)
signal transition_state_changed(state: int)

enum State { IDLE, LOADING, FADING_OUT, SWITCHING, FADING_IN }

const FADE_SECONDS: float = 0.18
const LOAD_TIMEOUT_MSEC: int = 15000
const CONTROL_LOCK: StringName = &"interior_transition"
const PLAYER_GROUP: StringName = &"player"
const SPAWN_MARKER: StringName = &"PlayerSpawn"

var state: State = State.IDLE
var load_timeout_msec: int = LOAD_TIMEOUT_MSEC
var fade_seconds: float = FADE_SECONDS
var _backend: Object
var _overlay: ColorRect
var _request_path: String = ""
var _load_started_msec: int = 0
var _return_scene_path: String = ""
var _return_position: Vector3 = Vector3.ZERO
var _return_valid: bool = false
var _returning: bool = false
var _controls_locked: bool = false
var _fading_in: bool = false


func _ready() -> void:
	_backend = _NativeBackend.new()
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.color = Color.BLACK
	_overlay.color.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	set_process(true)


func set_backend_for_testing(backend: Object) -> bool:
	if state != State.IDLE or backend == null:
		return false
	for method: String in ["request", "status", "get_scene"]:
		if not backend.has_method(method):
			return false
	_backend = backend
	return true


func reset_backend() -> bool:
	if state != State.IDLE:
		return false
	_backend = _NativeBackend.new()
	return true


func request_interior_transition(scene_path: String) -> void:
	_request(scene_path, false)


func return_from_interior() -> void:
	if not _return_valid:
		transition_failed.emit("", "No saved exterior return point")
		return
	_request(_return_scene_path, true)


func _request(scene_path: String, returning: bool) -> void:
	if state != State.IDLE:
		transition_failed.emit(scene_path, "Transition already in progress")
		return
	if scene_path.is_empty() or not scene_path.begins_with("res://"):
		transition_failed.emit(scene_path, "Invalid scene path")
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		transition_failed.emit(scene_path, "No current scene")
		return
	_request_path = scene_path
	_returning = returning
	var next_return_scene: String = ""
	var next_return_position: Vector3 = Vector3.ZERO
	var next_return_valid: bool = false
	if not returning:
		var current: Node = tree.current_scene
		if not current.scene_file_path.is_empty() and current.scene_file_path != scene_path:
			next_return_scene = current.scene_file_path
			var player: Node = _find_player()
			if player is Node3D:
				next_return_position = (player as Node3D).global_position
				next_return_valid = true
	_lock_controls()
	var result: int = int(_backend.call("request", scene_path))
	if result != OK:
		_fail("Scene resource request failed (%d)" % result)
		return
	if next_return_valid:
		_return_scene_path = next_return_scene
		_return_position = next_return_position
		_return_valid = true
	_load_started_msec = Time.get_ticks_msec()
	_set_state(State.LOADING)
	transition_started.emit(scene_path)


func _process(_delta: float) -> void:
	if state == State.LOADING:
		_poll_load()
	elif state == State.FADING_IN and _fading_in:
		_fading_in = false
		_set_state(State.IDLE)
		_unlock_controls()
		transition_finished.emit(_request_path)


func _poll_load() -> void:
	if Time.get_ticks_msec() - _load_started_msec >= load_timeout_msec:
		_fail("Scene resource load timed out")
		return
	var load_status: int = int(_backend.call("status", _request_path))
	if load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if load_status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("Scene resource could not be loaded")
		return
	var packed: PackedScene = _backend.call("get_scene", _request_path) as PackedScene
	if packed == null:
		_fail("Loaded resource is not a PackedScene")
		return
	_set_state(State.FADING_OUT)
	_fade_to(1.0, func() -> void: _switch_scene(packed))


func _switch_scene(packed: PackedScene) -> void:
	_set_state(State.SWITCHING)
	if not packed.can_instantiate():
		_fail("Scene could not be instantiated")
		return
	var tree: SceneTree = get_tree()
	var error: Error = tree.change_scene_to_packed(packed)
	if error != OK:
		_fail("Scene replacement failed (%d)" % error)
		return
	_finish_scene_switch(tree)


func _finish_scene_switch(tree: SceneTree) -> void:
	await tree.scene_changed
	_lock_controls()
	var player: Node = _find_player()
	if player is Node3D:
		var player_3d: Node3D = player as Node3D
		if _returning:
			player_3d.global_position = _return_position
			_return_valid = false
		else:
			var marker: Node = get_tree().current_scene.find_child(String(SPAWN_MARKER), true, false)
			if marker is Node3D:
				player_3d.global_position = (marker as Node3D).global_position
	_set_state(State.FADING_IN)
	_fade_to(0.0, func() -> void: _fading_in = true)


func _fade_to(alpha: float, finished: Callable) -> void:
	if _overlay == null or fade_seconds <= 0.0:
		if _overlay != null:
			var color: Color = _overlay.color
			color.a = alpha
			_overlay.color = color
		finished.call()
		return
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", alpha, fade_seconds)
	tween.finished.connect(finished, CONNECT_ONE_SHOT)


func _fail(reason: String) -> void:
	var failed_path: String = _request_path
	_set_state(State.FADING_IN)
	_fade_to(0.0, func() -> void:
		_set_state(State.IDLE)
		_unlock_controls()
		transition_failed.emit(failed_path, reason)
	)


func _lock_controls() -> void:
	var player: Node = _find_player()
	if player != null and player.has_method("add_control_lock"):
		player.call("add_control_lock", CONTROL_LOCK)
		_controls_locked = true


func _unlock_controls() -> void:
	var player: Node = _find_player()
	if _controls_locked and player != null and player.has_method("remove_control_lock"):
		player.call("remove_control_lock", CONTROL_LOCK)
	_controls_locked = false


func _find_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(PLAYER_GROUP)
	if player == null and tree.current_scene != null:
		player = tree.current_scene.find_child("Player", true, false)
		if player != null:
			player.add_to_group(PLAYER_GROUP)
	return player


func _set_state(next_state: State) -> void:
	state = next_state
	transition_state_changed.emit(state)


class _NativeBackend extends RefCounted:
	var _paths: Dictionary = {}

	func request(path: String) -> int:
		if not ResourceLoader.exists(path, "PackedScene"):
			return ERR_FILE_NOT_FOUND
		var result: Error = ResourceLoader.load_threaded_request(path, "PackedScene", true)
		if result == OK:
			_paths[path] = true
		return result

	func status(path: String) -> int:
		if not _paths.has(path):
			return ResourceLoader.THREAD_LOAD_FAILED
		var progress: Array = []
		var result: int = ResourceLoader.load_threaded_get_status(path, progress)
		if result != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_paths.erase(path)
		return result

	func get_scene(path: String) -> PackedScene:
		return ResourceLoader.load_threaded_get(path) as PackedScene
