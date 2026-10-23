extends Control
class_name PauseSettings

var _player: Node
var _settings: PlayerInputSettings
var _settings_panel: VBoxContainer
var _main_panel: VBoxContainer
var _fov_slider: HSlider
var _sensitivity_slider: HSlider
var _invert_toggle: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = load("res://ui/cyberpunk_theme.tres") as Theme
	_build_interface()
	visible = false


func configure(player: Node) -> void:
	_player = player
	_settings = _player.call("get_settings") as PlayerInputSettings if _player != null else null
	if _settings != null and _fov_slider != null:
		_sync_settings_controls()


func is_open() -> bool:
	return visible


func is_settings_visible() -> bool:
	return _settings_panel != null and _settings_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if visible:
			resume_game()
		else:
			open_pause()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.call("add_control_lock", &"pause_menu")
	get_tree().paused = true
	visible = true
	_show_main()
	_resume_button.grab_focus()


func resume_game() -> void:
	if not visible:
		return
	get_tree().paused = false
	visible = false
	if _player != null and is_instance_valid(_player):
		_player.call("remove_control_lock", &"pause_menu")
		_player.call("resume_mouse_capture")


func show_settings() -> void:
	if _settings == null:
		_settings = _player.call("get_settings") as PlayerInputSettings if _player != null else null
	if _settings == null:
		return
	_sync_settings_controls()
	_main_panel.visible = false
	_settings_panel.visible = true
	_fov_slider.grab_focus()


func _show_main() -> void:
	_settings_panel.visible = false
	_main_panel.visible = true
	_resume_button.grab_focus()


func _commit_camera_settings(_value: float = 0.0) -> void:
	if _settings == null:
		return
	if not _settings.set_camera_settings(_fov_slider.value, _sensitivity_slider.value, _invert_toggle.button_pressed):
		return
	if not _settings.save_settings():
		return
	if _player != null and is_instance_valid(_player):
		_player.call("apply_settings", _settings)


func _on_invert_toggled(_enabled: bool) -> void:
	_commit_camera_settings()


func _sync_settings_controls() -> void:
	_fov_slider.set_value_no_signal(_settings.get_fov())
	_sensitivity_slider.set_value_no_signal(_settings.get_sensitivity())
	_invert_toggle.set_pressed_no_signal(_settings.get_invert_look())
	_fov_value.text = "%.0f°" % _settings.get_fov()
	_sensitivity_value.text = "%.4f" % _settings.get_sensitivity()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.025, 0.055, 0.065, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.add_theme_constant_override("separation", 18)
	panel.add_child(pages)
	var title: Label = Label.new()
	title.text = "SYSTEM PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"CyberpunkHeader"
	pages.add_child(title)
	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 10)
	pages.add_child(_main_panel)
	_resume_button = _button("RESUME SESSION", _on_resume)
	_main_panel.add_child(_resume_button)
	_main_panel.add_child(_button("SYSTEM SETTINGS", show_settings))
	_main_panel.add_child(_button("QUIT TO DESKTOP", _on_quit))
	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 10)
	_settings_panel.visible = false
	pages.add_child(_settings_panel)
	_add_slider("CAMERA FIELD OF VIEW", 60.0, 120.0, 1.0, "90°")
	_fov_slider.value = 90.0
	_add_slider("LOOK SENSITIVITY", 0.0001, 0.01, 0.0001, "0.0020")
	_sensitivity_slider.value = 0.002
	_invert_toggle = CheckButton.new()
	_invert_toggle.text = "INVERT VERTICAL LOOK"
	_invert_toggle.theme_type_variation = &"CyberpunkAccent"
	_invert_toggle.toggled.connect(_on_invert_toggled)
	_settings_panel.add_child(_invert_toggle)
	_settings_panel.add_child(_button("BACK", _show_main))


var _resume_button: Button
var _fov_value: Label
var _sensitivity_value: Label


func _add_slider(caption: String, minimum: float, maximum: float, step: float, initial: String) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	_settings_panel.add_child(group)
	var row: HBoxContainer = HBoxContainer.new()
	group.add_child(row)
	var label: Label = Label.new()
	label.text = caption
	label.theme_type_variation = &"CyberpunkMuted"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value: Label = Label.new()
	value.text = initial
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.theme_type_variation = &"CyberpunkAccent"
	row.add_child(value)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(slider)
	if caption.begins_with("CAMERA"):
		_fov_slider = slider
		_fov_value = value
		slider.value_changed.connect(func(amount: float) -> void:
			_fov_value.text = "%.0f°" % amount
			_commit_camera_settings()
		)
	else:
		_sensitivity_slider = slider
		_sensitivity_value = value
		slider.value_changed.connect(func(amount: float) -> void:
			_sensitivity_value.text = "%.4f" % amount
			_commit_camera_settings()
		)


func _button(caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48.0
	button.pressed.connect(callback)
	return button


func _on_resume() -> void:
	resume_game()


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
