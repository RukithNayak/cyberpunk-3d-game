extends Control
class_name HackingHUD
## Responsive target readout for the authoritative HackingService.

var _service: HackingService
var _target_ref: WeakRef
var _ability_id: int = -1
var _event_text: String = ""
var _event_remaining: float = 0.0
var _name_label: Label
var _detail_label: Label
var _status_label: Label


func _ready() -> void:
	_build_interface()
	refresh()


func _exit_tree() -> void:
	_disconnect_service()


func _process(delta: float) -> void:
	if _event_remaining > 0.0:
		_event_remaining = maxf(0.0, _event_remaining - maxf(0.0, delta))
		if _event_remaining == 0.0:
			_event_text = ""
	refresh()


func configure(service: HackingService) -> void:
	_disconnect_service()
	_service = service
	if _service != null:
		_service.hack_committed.connect(_on_hack_committed)
		_service.hack_rejected.connect(_on_hack_rejected)
	refresh()


func present_target(target: Node3D, ability_id: int) -> void:
	_target_ref = weakref(target) if is_instance_valid(target) else null
	_ability_id = ability_id
	_event_text = ""
	_event_remaining = 0.0
	refresh()


func clear_target() -> void:
	_target_ref = null
	_ability_id = -1
	_event_text = ""
	_event_remaining = 0.0
	refresh()


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func get_detail_text() -> String:
	return _detail_label.text if _detail_label != null else ""


func refresh() -> void:
	if _status_label == null or _detail_label == null or _name_label == null:
		return
	if _service == null:
		_name_label.text = "NEURAL LINK"
		_detail_label.text = "COST  --    COOL  --    DUR  --"
		_status_label.text = "HACK PROVIDER OFFLINE"
		_status_label.theme_type_variation = &"CyberpunkWarning"
		return
	var target: Node3D = _target_ref.get_ref() as Node3D if _target_ref != null else null
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		_name_label.text = "NEURAL LINK"
		_detail_label.text = "ACQUIRE A HACKABLE SIGNAL"
		_status_label.text = _event_text if _event_remaining > 0.0 else "SCANNING  /  STANDBY"
		_status_label.theme_type_variation = &"CyberpunkStatus"
		return
	var info: Dictionary = _service.get_target_status(target, _ability_id)
	_name_label.text = String(info.get("name", "UNKNOWN SIGNAL")).to_upper()
	_detail_label.text = "COST %02.0f    COOL %04.1f    DUR %04.1f" % [float(info.get("cost", 0.0)), float(info.get("cooldown", 0.0)), float(info.get("duration", 0.0))]
	if _event_remaining > 0.0:
		_status_label.text = _event_text
		_status_label.theme_type_variation = &"CyberpunkAccent" if _event_text == "LINK ESTABLISHED" else &"CyberpunkWarning"
	elif bool(info.get("valid", false)):
		_status_label.text = "READY  /  PRESS INTERACT"
		_status_label.theme_type_variation = &"CyberpunkAccent"
	else:
		_status_label.text = "LOCKED  /  " + String(info.get("reason", "unavailable")).replace("_", " ").to_upper()
		_status_label.theme_type_variation = &"CyberpunkWarning"


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 24)
	margins.add_theme_constant_override("margin_top", 24)
	margins.add_theme_constant_override("margin_right", 24)
	margins.add_theme_constant_override("margin_bottom", 24)
	add_child(margins)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(rows)
	var top_row: HBoxContainer = HBoxContainer.new()
	rows.add_child(top_row)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	top_row.add_child(panel)
	var inset: MarginContainer = MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 16)
	inset.add_theme_constant_override("margin_top", 12)
	inset.add_theme_constant_override("margin_right", 16)
	inset.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inset)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	inset.add_child(stack)
	var caption: Label = Label.new()
	caption.text = "NEURAL INTRUSION  /  TARGET DATA"
	caption.theme_type_variation = &"CyberpunkMuted"
	stack.add_child(caption)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"CyberpunkHeader"
	stack.add_child(_name_label)
	_detail_label = Label.new()
	_detail_label.theme_type_variation = &"CyberpunkMuted"
	stack.add_child(_detail_label)
	_status_label = Label.new()
	_status_label.theme_type_variation = &"CyberpunkStatus"
	stack.add_child(_status_label)
	var vertical_spacer: Control = Control.new()
	vertical_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(vertical_spacer)


func _disconnect_service() -> void:
	if _service == null:
		return
	if _service.hack_committed.is_connected(_on_hack_committed):
		_service.hack_committed.disconnect(_on_hack_committed)
	if _service.hack_rejected.is_connected(_on_hack_rejected):
		_service.hack_rejected.disconnect(_on_hack_rejected)


func _on_hack_committed(_target_uuid: String, _signal_ability_id: int, _remaining_energy: float) -> void:
	_event_text = "LINK ESTABLISHED"
	_event_remaining = 1.5
	refresh()


func _on_hack_rejected(_target_uuid: String, _signal_ability_id: int, reason: StringName) -> void:
	_event_text = "ACCESS DENIED  /  " + String(reason).replace("_", " ").to_upper()
	_event_remaining = 1.5
	refresh()
