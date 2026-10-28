extends VBoxContainer
class_name MissionJournal
## Event-driven, presentation-only mission and credit summary.

var _director: MissionDirector
var _rows: VBoxContainer
var _credits_label: Label


func _ready() -> void:
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	add_child(_rows)
	_credits_label = Label.new()
	_credits_label.name = "Credits"
	_credits_label.text = "CREDITS  // 0"
	_credits_label.theme_type_variation = &"CyberpunkAccent"
	add_child(_credits_label)


func configure(director: MissionDirector) -> bool:
	if director == null:
		return false
	if _director != null and _director.mission_changed.is_connected(_on_mission_changed):
		_director.mission_changed.disconnect(_on_mission_changed)
	_director = director
	if not _director.mission_changed.is_connected(_on_mission_changed):
		_director.mission_changed.connect(_on_mission_changed)
	_refresh()
	return true


func _exit_tree() -> void:
	if _director != null and _director.mission_changed.is_connected(_on_mission_changed):
		_director.mission_changed.disconnect(_on_mission_changed)


func _on_mission_changed(_mission_id: String, _state: String, _credits: int) -> void:
	_refresh()


func _refresh() -> void:
	if _director == null or _rows == null:
		return
	for child: Node in _rows.get_children():
		child.queue_free()
	_credits_label.text = "CREDITS  // %d" % _director.get_credits()
	var snapshot: Dictionary = _director.capture_snapshot()
	var missions: Array = snapshot.get("missions", [])
	if missions.is_empty():
		_rows.add_child(_make_label("NO ACTIVE CONTRACTS", &"CyberpunkMuted"))
		return
	for row_variant: Variant in missions:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var state: String = String(row.get("state", "unknown")).to_upper()
		var title: String = "SIGNAL CACHE  // %s" % state
		_rows.add_child(_make_label(title, &"CyberpunkAccent" if state == "ACTIVE" else &"CyberpunkHeader"))
		_rows.add_child(_make_label("RECOVER CACHE • %d CR" % int(row.get("reward_credits", 0)), &"CyberpunkMuted"))


func _make_label(value: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
