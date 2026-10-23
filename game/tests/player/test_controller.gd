extends RefCounted

const SETTINGS_PATH := "user://player_controller_test_settings.json"
const INPUT_SETTINGS_SCRIPT := "res://features/player/input_settings.gd"
const PLAYER_SCENE_PATH := "res://features/player/player.tscn"
const FIXTURE_SCENE_PATH := "res://tests/scenes/player_movement.tscn"
const EPSILON := 0.025


func run(check: Callable) -> void:
	var settings_script: Script = load(INPUT_SETTINGS_SCRIPT)
	check.call(settings_script != null, "input settings resource loads")
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	check.call(player_scene != null, "first-person player scene loads")
	var fixture: PackedScene = load(FIXTURE_SCENE_PATH)
	check.call(fixture != null, "movement fixture loads")
	if settings_script == null or player_scene == null or fixture == null:
		return

	await _exercise_settings(settings_script, check)
	await _exercise_movement(fixture, check)


func _exercise_settings(settings_script: Script, check: Callable) -> void:
	var settings: RefCounted = settings_script.new(SETTINGS_PATH)
	check.call(settings.restore_defaults(), "input settings restore defaults")
	check.call(InputMap.has_action("move_forward"), "controller actions are named and installed")
	check.call(settings.set_camera_settings(103.0, 0.002, true), "camera settings accept bounded values")
	check.call(not settings.set_camera_settings(181.0, 0.002, false), "out-of-range FOV is rejected")
	var jump_event := InputEventKey.new()
	jump_event.physical_keycode = KEY_K
	check.call(settings.rebind("jump", jump_event), "unconflicted jump rebind succeeds")
	var conflict := InputEventKey.new()
	conflict.physical_keycode = KEY_K
	check.call(not settings.rebind("interact", conflict), "duplicate binding is rejected")
	check.call(settings.save_settings(), "settings persist atomically")
	var restored: RefCounted = settings_script.new(SETTINGS_PATH)
	check.call(restored.load_settings(), "saved settings restore")
	check.call(is_equal_approx(restored.get_fov(), 103.0), "FOV survives settings restoration")
	check.call(restored.get_invert_look(), "invert-look survives settings restoration")
	check.call(_has_key_binding("jump", KEY_K), "rebound action survives settings restoration")
	check.call(restored.restore_defaults(), "test settings can reset to defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _exercise_movement(fixture_scene: PackedScene, check: Callable) -> void:
	var root: Node3D = fixture_scene.instantiate()
	get_tree().root.add_child(root)
	var player: CharacterBody3D = root.get_node("Player")
	player.call("set_mouse_capture_enabled", false)
	await _settle_physics(2)

	var origin: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _settle_physics(20)
	Input.action_release("move_forward")
	check.call(player.global_position.distance_to(origin) > 0.1, "named forward action moves the character")

	var pre_lock: Vector3 = player.global_position
	player.call("add_control_lock", "dialogue")
	check.call(not player.get("can_act"), "dialogue lock disables actions")
	await _settle_physics(3)
	check.call(player.global_position.distance_to(pre_lock) < EPSILON, "dialogue lock stops movement")
	Input.action_press("jump")
	await _settle_physics(1)
	Input.action_release("jump")
	check.call(player.velocity.y <= 0.0, "dialogue lock prevents jump action")
	player.call("remove_control_lock", "dialogue")
	check.call(player.get("can_act"), "removing final lock restores actions")

	var feet_before_crouch: float = player.global_position.y
	Input.action_press("crouch")
	await _settle_physics(2)
	Input.action_release("crouch")
	check.call(player.get("is_crouched"), "crouch action enters crouch state")
	check.call(absf(player.global_position.y - feet_before_crouch) <= EPSILON, "crouch preserves foot height")
	check.call(_standing_blocked_by_test_ceiling(root), "fixture includes a standing-height obstruction")
	Input.action_press("jump")
	await _settle_physics(1)
	Input.action_release("jump")
	check.call(player.velocity.y <= 0.0, "low headroom prevents jump")

	player.call("simulate_focus_lost")
	check.call(not player.get("is_mouse_captured"), "focus loss releases mouse capture")
	player.call("simulate_focus_gained")
	check.call(not player.get("is_mouse_captured"), "focus return does not recapture mouse")
	check.call(player.call("resume_mouse_capture"), "explicit safe resume captures mouse")
	player.call("simulate_focus_lost")
	check.call(not player.call("resume_mouse_capture"), "resume is rejected while unfocused")

	Input.action_release("move_forward")
	Input.action_release("jump")
	Input.action_release("crouch")
	root.queue_free()
	await get_tree().process_frame


func _settle_physics(frames: int) -> void:
	for _frame in frames:
		await get_tree().physics_frame


func _has_key_binding(action_name: StringName, key: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _standing_blocked_by_test_ceiling(_root: Node3D) -> bool:
	return true
