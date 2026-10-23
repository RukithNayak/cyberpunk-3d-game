extends CanvasLayer
class_name PlayerHUD
## Compact fullscreen presentation over authoritative player/combat services.

const SCANLINE_SHADER: Shader = preload("res://ui/scanline.gdshader")
const PAUSE_SCENE: PackedScene = preload("res://ui/pause_settings.tscn")

var health_state: HealthState
var actions: WeaponStateMachine
var equipment: EquipmentService
var combat_feedback: CombatFeedback
var _player: Node
var pause_menu: PauseSettings

var _health_label: Label
var _health_bar: ProgressBar
var _weapon_label: Label
var _ammo_label: Label
var _status_label: Label
var _crosshair: Label
var _comfort_button: Button
var _damage_flash: ColorRect
var _last_health: int = 0
var reduced_camera_shake: bool = false


func _ready() -> void:
	_build_interface()
	pause_menu = PAUSE_SCENE.instantiate() as PauseSettings
	add_child(pause_menu)


func _exit_tree() -> void:
	_disconnect_sources()


func configure(health: HealthState, action_machine: WeaponStateMachine, equipment_service: EquipmentService, player: Node = null) -> void:
	_disconnect_sources()
	health_state = health
	actions = action_machine
	equipment = equipment_service
	_player = player
	if pause_menu != null:
		pause_menu.configure(_player)
	combat_feedback = CombatFeedback.new()
	combat_feedback.feedback_event.connect(_on_feedback_event)
	if health_state != null:
		_last_health = health_state.current_hp
		health_state.health_changed.connect(_on_health_changed)
		health_state.on_death.connect(combat_feedback.register_death)
	if actions != null:
		actions.shot_committed.connect(_on_shot_committed)
		actions.reload_completed.connect(_on_reload_completed)
	if equipment != null and equipment.inventory != null:
		equipment.inventory.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _health_label == null:
		return
	if health_state == null:
		_health_label.text = "VITAL LINK  --"
		_health_bar.value = 0.0
	else:
		_health_label.text = "VITAL LINK   %03d / %03d" % [health_state.current_hp, health_state.max_hp]
		_health_bar.max_value = float(health_state.max_hp)
		_health_bar.value = float(health_state.current_hp)
	var active: Dictionary = equipment.get_active_weapon_stats() if equipment != null else {}
	if active.is_empty():
		_weapon_label.text = "NO WEAPON EQUIPPED"
		_ammo_label.text = "--  /  --"
		return
	var uuid: String = String(active.get("item_uuid", ""))
	var item: ItemInstance = equipment.inventory.get_item(uuid) if equipment.inventory != null else null
	var family: String = String(active.get("weapon_family", ""))
	var reserve: int = equipment.ammo_pouch.get_ammo(family) if equipment.ammo_pouch != null else 0
	_weapon_label.text = String(active.get("item_id", "WEAPON")).replace("_", " ").to_upper()
	_ammo_label.text = "%02d   /   %02d" % [item.magazine_ammo if item != null else 0, reserve]


func get_health_text() -> String:
	return _health_label.text if _health_label != null else ""


func get_ammo_text() -> String:
	return _ammo_label.text if _ammo_label != null else ""


func get_crosshair_text() -> String:
	return _crosshair.text if _crosshair != null else ""


func set_status_message(message: String) -> void:
	if _status_label != null and not message.strip_edges().is_empty():
		_status_label.text = message.to_upper()


func get_feedback_event_count() -> int:
	return combat_feedback.accepted_shot_count if combat_feedback != null else 0


func is_camera_shake_reduced() -> bool:
	return reduced_camera_shake


func _build_interface() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.06, 0.04, 0.0)
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margins)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margins.add_child(stack)
	var top_row: HBoxContainer = HBoxContainer.new()
	stack.add_child(top_row)
	var health_panel: PanelContainer = _panel()
	top_row.add_child(health_panel)
	var health_column: VBoxContainer = VBoxContainer.new()
	health_column.add_theme_constant_override("separation", 6)
	health_panel.add_child(health_column)
	_health_label = Label.new()
	_health_label.theme_type_variation = &"CyberpunkHeader"
	health_column.add_child(_section_caption("BIO-MONITOR"))
	health_column.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(190, 7)
	health_column.add_child(_health_bar)
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)
	var weapon_panel: PanelContainer = _panel()
	top_row.add_child(weapon_panel)
	var weapon_column: VBoxContainer = VBoxContainer.new()
	weapon_column.add_theme_constant_override("separation", 4)
	weapon_panel.add_child(weapon_column)
	weapon_column.add_child(_section_caption("ACTIVE FIREARM"))
	_weapon_label = Label.new()
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.theme_type_variation = &"CyberpunkAccent"
	weapon_column.add_child(_weapon_label)
	_comfort_button = Button.new()
	_comfort_button.text = "CAMERA KICK  /  STANDARD"
	_comfort_button.pressed.connect(_toggle_camera_comfort)
	weapon_column.add_child(_comfort_button)
	var spring: Control = Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spring)
	var bottom_row: HBoxContainer = HBoxContainer.new()
	stack.add_child(bottom_row)
	_status_label = Label.new()
	_status_label.theme_type_variation = &"CyberpunkStatus"
	_status_label.text = "NEURAL LINK  /  ACTIVE"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(_status_label)
	var ammo_panel: PanelContainer = _panel()
	bottom_row.add_child(ammo_panel)
	var ammo_column: VBoxContainer = VBoxContainer.new()
	ammo_column.add_theme_constant_override("separation", 2)
	ammo_panel.add_child(ammo_column)
	ammo_column.add_child(_section_caption("MAGAZINE  /  RESERVE"))
	_ammo_label = Label.new()
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.theme_type_variation = &"CyberpunkHeader"
	ammo_column.add_child(_ammo_label)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.theme_type_variation = &"CyberpunkCrosshair"
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_child(_crosshair)
	var scanline: ColorRect = ColorRect.new()
	scanline.color = Color.WHITE
	scanline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SCANLINE_SHADER
	scanline.material = material
	root.add_child(scanline)


func _panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	return panel


func _section_caption(value: String) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.theme_type_variation = &"CyberpunkMuted"
	return label


func _on_health_changed(current: int, _maximum: int) -> void:
	if combat_feedback != null:
		combat_feedback.register_health_change(_last_health, current)
	_last_health = current
	refresh()


func _on_shot_committed(result: HitResult, _uuid: String) -> void:
	if combat_feedback != null:
		combat_feedback.register_shot(result)
	refresh()


func _on_reload_completed(_uuid: String, _rounds: int) -> void:
	_status_label.text = "MAGAZINE  /  RELOADED"
	refresh()


func _on_feedback_event(kind: String) -> void:
	if kind == "hit":
		_crosshair.theme_type_variation = &"CyberpunkHitCrosshair"
		_status_label.text = "TARGET  /  CONFIRMED"
	elif kind == "damage":
		_status_label.text = "VITAL LINK  /  DAMAGE"
		_flash_damage()
	elif kind == "death":
		_status_label.text = "VITAL LINK  /  LOST"
		_status_label.theme_type_variation = &"CyberpunkWarning"
		_flash_damage()
	else:
		_status_label.text = "SHOT  /  CONFIRMED"
	_crosshair.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_crosshair, "modulate:a", 0.58, 0.22)


func _flash_damage() -> void:
	_damage_flash.color.a = 0.12
	var tween: Tween = create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.28)


func _toggle_camera_comfort() -> void:
	var requested: bool = not reduced_camera_shake
	if actions == null or not bool(actions.call("set_reduced_camera_shake", requested)):
		return
	reduced_camera_shake = requested
	_comfort_button.text = "CAMERA KICK  /  LOW" if reduced_camera_shake else "CAMERA KICK  /  STANDARD"


func _disconnect_sources() -> void:
	if health_state != null:
		if health_state.health_changed.is_connected(_on_health_changed):
			health_state.health_changed.disconnect(_on_health_changed)
		if combat_feedback != null and health_state.on_death.is_connected(combat_feedback.register_death):
			health_state.on_death.disconnect(combat_feedback.register_death)
	if actions != null:
		if actions.shot_committed.is_connected(_on_shot_committed):
			actions.shot_committed.disconnect(_on_shot_committed)
		if actions.reload_completed.is_connected(_on_reload_completed):
			actions.reload_completed.disconnect(_on_reload_completed)
	if equipment != null and equipment.inventory != null and equipment.inventory.inventory_changed.is_connected(refresh):
		equipment.inventory.inventory_changed.disconnect(refresh)
