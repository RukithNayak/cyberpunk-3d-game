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
	check.call(is_equal_approx(restored.get_sensitivity(), 0.002), "look sensitivity survives settings restoration")
	check.call(restored.get_invert_look(), "invert-look survives settings restoration")
	check.call(_has_key_binding("jump", KEY_K), "rebound action survives settings restoration")
	check.call(restored.restore_defaults(), "test settings can reset to defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _exercise_movement(fixture_scene: PackedScene, check: Callable) -> void:
	var root: Node3D = fixture_scene.instantiate()
	_scene_tree().root.add_child(root)
	var player: CharacterBody3D = root.get_node("Player")
	player.call("set_mouse_capture_enabled", false)
	await _settle_physics(2)
	player.call("add_control_lock", &"inventory_ui")
	check.call(player.call("can_use_inventory_action") and not player.call("can_fire"), "inventory lock permits a consumable transaction but blocks combat input")
	player.call("add_control_lock", &"pause")
	check.call(not player.call("can_use_inventory_action"), "pause lock blocks inventory healing")
	player.call("remove_control_lock", &"pause")
	check.call(player.call("can_use_inventory_action"), "inventory healing resumes when only the inventory lock remains")
	player.call("remove_control_lock", &"inventory_ui")
	var head: Node3D = player.get_node("Head") as Node3D
	check.call(player.has_method("set_reduced_camera_shake"), "player exposes the HUD camera comfort control")
	if player.has_method("set_reduced_camera_shake"):
		var recoil_start: float = head.rotation.x
		player.call("set_reduced_camera_shake", true)
		player.call("apply_recoil", 10.0)
		check.call(absf(absf(head.rotation.x - recoil_start) - deg_to_rad(3.5)) < EPSILON, "reduced camera feedback scales recoil to a gentler level")
		recoil_start = head.rotation.x
		player.call("set_reduced_camera_shake", false)
		player.call("apply_recoil", 10.0)
		check.call(absf(absf(head.rotation.x - recoil_start) - deg_to_rad(10.0)) < EPSILON, "standard camera feedback restores full recoil")
		head.rotation.x = 0.0

	var origin: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _settle_physics(20)
	Input.action_release("move_forward")
	var walk_distance: float = player.global_position.distance_to(origin)
	check.call(walk_distance > 0.1, "named forward action moves the character (%s, velocity=%s)" % [str(walk_distance), str(player.velocity)])
	var run_origin: Vector3 = player.global_position
	Input.action_press("move_forward")
	Input.action_press("run")
	await _settle_physics(20)
	Input.action_release("move_forward")
	Input.action_release("run")
	var run_distance: float = player.global_position.distance_to(run_origin)
	check.call(run_distance > walk_distance * 1.15, "run action increases movement speed (%s > %s)" % [str(run_distance), str(walk_distance)])

	var pre_lock: Vector3 = player.global_position
	player.call("add_control_lock", "dialogue")
	check.call(not player.get("can_act"), "dialogue lock disables actions")
	await _settle_physics(3)
	check.call(player.global_position.distance_to(pre_lock) < EPSILON, "dialogue lock stops movement")
	Input.action_press("jump")
	await _settle_physics(1)
	Input.action_release("jump")
	await _settle_physics(1)
	check.call(player.velocity.y <= 0.0, "dialogue lock prevents jump action")
	player.call("remove_control_lock", "dialogue")
	check.call(player.get("can_act"), "removing final lock restores actions")
	check.call(player.call("resume_mouse_capture"), "mouse capture can resume after a control lock")
	player.call("set_mouse_capture_enabled", false)

	var feet_before_crouch: float = player.global_position.y
	Input.action_press("crouch")
	await _settle_physics(2)
	Input.action_release("crouch")
	check.call(player.get("is_crouched"), "crouch action enters crouch state")
	check.call(absf(player.global_position.y - feet_before_crouch) <= EPSILON, "crouch preserves foot height (%s -> %s)" % [str(feet_before_crouch), str(player.global_position.y)])
	check.call(absf(player.get_node("Head").position.y - 1.05) < EPSILON, "crouch lowers first-person camera")
	player.global_position = Vector3(0.0, feet_before_crouch, 0.0)
	player.velocity = Vector3.ZERO
	await _settle_physics(20)
	check.call(player.is_on_floor(), "player settles on floor beneath the low ceiling")
	check.call(_standing_blocked_by_test_ceiling(root), "real physics query detects a standing-height obstruction")
	Input.action_press("jump")
	await _settle_physics(1)
	Input.action_release("jump")
	check.call(player.velocity.y <= 0.0, "low headroom prevents jump (%s, crouched=%s)" % [str(player.velocity.y), str(player.get("is_crouched"))])
	root.get_node("LowCeiling").queue_free()
	await _settle_physics(2)
	Input.action_press("crouch")
	await _settle_physics(1)
	Input.action_release("crouch")
	await _settle_physics(4)
	check.call(not player.get("is_crouched"), "player can stand after obstruction removal")
	check.call(player.is_on_floor(), "player remains grounded before jumping (%s)" % str(player.velocity.y))
	Input.action_press("jump")
	await _settle_physics(1)
	Input.action_release("jump")
	check.call(player.velocity.y > 0.0, "jump action launches when headroom is clear (%s)" % str(player.velocity.y))
	await _settle_physics(60)
	check.call(player.is_on_floor(), "jump lands on the collision floor")

	player.call("simulate_focus_lost")
	check.call(not player.get("is_mouse_captured"), "focus loss releases mouse capture")
	player.call("simulate_focus_gained")
	check.call(not player.get("is_mouse_captured"), "focus return does not recapture mouse")
	var recapture_click: InputEventMouseButton = InputEventMouseButton.new()
	recapture_click.button_index = MOUSE_BUTTON_LEFT
	recapture_click.pressed = true
	player.call("_unhandled_input", recapture_click)
	check.call(player.get("is_mouse_captured"), "left-click after focus return recaptures mouse for look")
	var look_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	look_motion.relative = Vector2(24.0, 12.0)
	var yaw_before_look: float = player.rotation.y
	var pitch_before_look: float = head.rotation.x
	player.call("_input", look_motion)
	check.call(not is_equal_approx(player.rotation.y, yaw_before_look) and not is_equal_approx(head.rotation.x, pitch_before_look), "mouse motion after recapture rotates player and camera")
	var overlay_layer: CanvasLayer = CanvasLayer.new()
	root.add_child(overlay_layer)
	var dialogue_overlay: Control = Control.new()
	dialogue_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(dialogue_overlay)
	await _scene_tree().process_frame
	var routed_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	routed_motion.position = _scene_tree().root.get_visible_rect().size * 0.5
	routed_motion.global_position = routed_motion.position
	routed_motion.relative = Vector2(24.0, 12.0)
	yaw_before_look = player.rotation.y
	pitch_before_look = head.rotation.x
	_scene_tree().root.push_input(routed_motion)
	check.call(not is_equal_approx(player.rotation.y, yaw_before_look) and not is_equal_approx(head.rotation.x, pitch_before_look), "mouse look receives motion while full-screen dialogue UI is visible")
	overlay_layer.queue_free()
	await _scene_tree().process_frame
	player.call("simulate_focus_lost")
	check.call(not player.call("resume_mouse_capture"), "resume is rejected while unfocused")

	Input.action_release("move_forward")
	Input.action_release("jump")
	Input.action_release("crouch")
	root.queue_free()
	await _scene_tree().process_frame


func _settle_physics(frames: int) -> void:
	for _frame in frames:
		await _scene_tree().physics_frame


func _has_key_binding(action_name: StringName, key: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _standing_blocked_by_test_ceiling(root: Node3D) -> bool:
	var player: Node = root.get_node_or_null("Player")
	return player != null and not bool(player.call("can_stand"))


func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
