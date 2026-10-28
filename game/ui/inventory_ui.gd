extends Control
class_name InventoryUI
## Responsive presentation over authoritative inventory/equipment services.

signal item_dropped(item: ItemInstance)

const PLAYER_LOCK_ID: StringName = &"inventory_ui"
const CELL_SIZE: Vector2 = Vector2(150.0, 150.0)

var inventory: GridInventory
var equipment: EquipmentService
var consumables: ConsumableService
var health_state: HealthState
var player_controller: Node
var save_store: SaveStore
var nearby_item: ItemInstance
var nearby_drop: Node

var is_dragging: bool = false
var drag_uuid: String = ""
var drag_grab_offset: Vector2i = Vector2i.ZERO
var drag_preview_valid: bool = false
var drag_preview_anchor: Vector2i = Vector2i(-1, -1)
var selected_uuid: String = ""

var _backdrop: ColorRect
var _panel: PanelContainer
var _grid: GridContainer
var _details: Label
var _health_label: Label
var _status: Label
var _pickup_label: Label
var _equip_button: Button
var _use_button: Button
var _drop_button: Button
var _pickup_button: Button
var _save_button: Button
var _load_button: Button
var _cell_buttons: Array[Button] = []
var _hover_cell: Vector2i = Vector2i.ZERO
var _refresh_scheduled: bool = false


func configure(grid: GridInventory, equipment_service: EquipmentService, consumable_service: ConsumableService, health: HealthState, player: Node, saves: SaveStore = null) -> void:
	if inventory != null and inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.disconnect(_on_inventory_changed)
	if health_state != null and health_state.health_changed.is_connected(_on_health_changed):
		health_state.health_changed.disconnect(_on_health_changed)
	if equipment != null and equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.disconnect(_on_equipment_changed)
	inventory = grid
	equipment = equipment_service
	consumables = consumable_service
	health_state = health
	player_controller = player
	save_store = saves
	_connect_inventory_signal()
	if health_state != null and not health_state.health_changed.is_connected(_on_health_changed):
		health_state.health_changed.connect(_on_health_changed)
	if equipment != null and not equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.connect(_on_equipment_changed)
	if is_node_ready():
		_rebuild_grid()
		_refresh_details()
		_update_action_buttons()


func _ready() -> void:
	_build_interface()
	_connect_inventory_signal()
	_rebuild_grid()
	_refresh_details()
	_refresh_health()
	_update_action_buttons()
	open_inventory()


func open_inventory() -> void:
	visible = true
	if player_controller != null and is_instance_valid(player_controller) and player_controller.has_method("add_control_lock"):
		player_controller.call("add_control_lock", PLAYER_LOCK_ID)
	if not _cell_buttons.is_empty():
		_cell_buttons[0].grab_focus()


func close_inventory() -> void:
	cancel_drag()
	visible = false
	_release_player_lock()


func toggle_inventory() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func select_cell(cell: Vector2i) -> bool:
	if inventory == null:
		return false
	var item: ItemInstance = inventory.get_item_at(cell)
	selected_uuid = item.uuid if item != null else ""
	_refresh_details()
	_update_action_buttons()
	_update_cell_styles()
	return item != null


func begin_drag_at(cell: Vector2i) -> bool:
	if inventory == null:
		return false
	var item: ItemInstance = inventory.get_item_at(cell)
	if item == null:
		return false
	select_cell(cell)
	is_dragging = true
	drag_uuid = item.uuid
	drag_grab_offset = cell - item.grid_position
	drag_preview_anchor = item.grid_position
	drag_preview_valid = true
	_update_cell_styles()
	return true


func preview_drag_at(cell: Vector2i) -> bool:
	if not is_dragging or inventory == null:
		return false
	drag_preview_anchor = cell - drag_grab_offset
	var candidates: Array[ItemInstance] = inventory.get_items()
	var found: bool = false
	for candidate: ItemInstance in candidates:
		if candidate.uuid == drag_uuid:
			candidate.grid_position = drag_preview_anchor
			found = true
			break
	var prepared: Dictionary = inventory.prepare_replacement(candidates) if found else {"ok": false}
	drag_preview_valid = bool(prepared.get("ok", false))
	_update_cell_styles()
	return drag_preview_valid


func commit_drag_at(cell: Vector2i) -> bool:
	if not is_dragging or inventory == null:
		return false
	var destination: Vector2i = cell - drag_grab_offset
	var can_commit: bool = preview_drag_at(cell)
	var moving_uuid: String = drag_uuid
	_clear_drag()
	var committed: bool = can_commit and inventory.try_move_item(moving_uuid, destination)
	if committed:
		_status.text = "Moved item to %d, %d." % [destination.x + 1, destination.y + 1]
	else:
		_status.text = "Cannot place there: the item overlaps or is outside the grid."
	_update_cell_styles()
	_refresh_details()
	return committed


func cancel_drag() -> void:
	if not is_dragging:
		return
	_clear_drag()
	_status.text = "Move cancelled. The item remains in its original cell."
	_update_cell_styles()


func equip_selected() -> bool:
	var item: ItemInstance = _selected_item()
	if item == null or equipment == null:
		return false
	var changed: bool
	if equipment.is_equipped(item):
		changed = equipment.unequip_item(item.uuid)
	else:
		changed = equipment.equip_item(item.uuid, "primary")
	_status.text = "Equipment updated." if changed else "Cannot equip this item in the primary slot."
	_refresh_view()
	return changed


func drop_selected() -> bool:
	var item: ItemInstance = _selected_item()
	if item == null or equipment == null:
		return false
	if get_signal_connection_list("item_dropped").is_empty():
		_status.text = "Drop unavailable: no world pickup receiver is connected."
		return false
	var dropped: ItemInstance = equipment.drop_item(item.uuid)
	if dropped == null:
		_status.text = "Drop failed; the item remains in inventory."
		return false
	item_dropped.emit(dropped)
	selected_uuid = ""
	_status.text = "Dropped %s into the world." % _display_name(dropped)
	_refresh_view()
	return true


func use_selected() -> bool:
	var item: ItemInstance = _selected_item()
	if item == null or consumables == null:
		return false
	var consumed: bool
	var action_machine: Node = player_controller.get_node_or_null("WeaponStateMachine") if player_controller != null and is_instance_valid(player_controller) else null
	if action_machine != null and action_machine.has_method("is_configured") and bool(action_machine.call("is_configured")):
		var token: int = int(action_machine.call("begin_heal", item.grid_position))
		consumed = token > 0 and bool(action_machine.call("complete_heal", token))
	else:
		consumed = consumables.use_consumable(Vector2(item.grid_position))
	_status.text = "Used %s." % _display_name(item) if consumed else "Cannot use this item right now."
	_refresh_view()
	return consumed


func set_nearby_pickup(item: ItemInstance, world_drop: Node) -> void:
	nearby_item = item.duplicate(true) as ItemInstance if item != null else null
	nearby_drop = world_drop
	_refresh_pickup()
	_update_action_buttons()


func pickup_nearby() -> bool:
	if inventory == null or nearby_item == null or nearby_drop == null:
		_status.text = "No nearby loot is available."
		return false
	if not inventory.try_pickup_item(nearby_item, nearby_drop):
		_status.text = "Pickup rejected: inventory is full or the loot is no longer available."
		return false
	_status.text = "Picked up %s." % _display_name(nearby_item)
	nearby_item = null
	nearby_drop = null
	_refresh_view()
	return true


func refresh_view() -> void:
	_refresh_view()


func get_selected_details_text() -> String:
	return _details.text if _details != null else ""


func get_status_text() -> String:
	return _status.text if _status != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_ESCAPE and visible:
		close_inventory()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		toggle_inventory()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	cancel_drag()
	_release_player_lock()


func _release_player_lock() -> void:
	if player_controller != null and is_instance_valid(player_controller) and player_controller.has_method("remove_control_lock"):
		player_controller.call("remove_control_lock", PLAYER_LOCK_ID)
		if player_controller.has_method("resume_mouse_capture"):
			player_controller.call("resume_mouse_capture")


func _build_interface() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.1, 0.14, 0.16, 1)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scanline_shader: Shader = load("res://ui/scanline.gdshader") as Shader
	var scanline_material: ShaderMaterial = ShaderMaterial.new()
	scanline_material.shader = scanline_shader
	_backdrop.material = scanline_material
	add_child(_backdrop)
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_top", 22)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_bottom", 22)
	add_child(margins)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(_panel)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	_panel.add_child(columns)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	columns.add_child(left)
	var heading_row: HBoxContainer = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 24)
	left.add_child(heading_row)
	var heading_column: VBoxContainer = VBoxContainer.new()
	heading_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_column.add_theme_constant_override("separation", 2)
	heading_row.add_child(heading_column)
	var heading: Label = Label.new()
	heading.text = "PERSONAL LINK"
	heading.theme_type_variation = &"CyberpunkHeader"
	heading_column.add_child(heading)
	var inventory_subtitle: Label = Label.new()
	inventory_subtitle.text = "FIELD EQUIPMENT  /  CARRIED ITEMS"
	inventory_subtitle.theme_type_variation = &"CyberpunkAccent"
	heading_column.add_child(inventory_subtitle)
	var capacity_readout: Label = Label.new()
	capacity_readout.theme_type_variation = &"CyberpunkHeader"
	capacity_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capacity_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_readout.custom_minimum_size.x = 190.0
	capacity_readout.text = "INVENTORY  /  %02d SLOTS" % (inventory.grid_size.x * inventory.grid_size.y) if inventory != null else "INVENTORY"
	heading_row.add_child(capacity_readout)
	var instructions: Label = Label.new()
	instructions.text = "SELECT TO INSPECT     •     DRAG TO REPOSITION     •     TAB / ESC TO CLOSE"
	instructions.theme_type_variation = &"CyberpunkMuted"
	left.add_child(instructions)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.add_child(_grid)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 42.0
	_status.theme_type_variation = &"CyberpunkStatus"
	var flicker_shader: Shader = load("res://ui/status_flicker.gdshader") as Shader
	var flicker_material: ShaderMaterial = ShaderMaterial.new()
	flicker_material.shader = flicker_shader
	_status.material = flicker_material
	left.add_child(_status)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size.x = 350.0
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.8
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	var inspect_heading: Label = Label.new()
	inspect_heading.text = "ITEM READOUT  /  01"
	inspect_heading.theme_type_variation = &"CyberpunkHeader"
	right.add_child(inspect_heading)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.y = 145.0
	_details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(_details)
	var action_caption: Label = _section_caption("FIELD ACTIONS")
	right.add_child(action_caption)
	_health_label = Label.new()
	_health_label.theme_type_variation = &"CyberpunkAccent"
	right.add_child(_health_label)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	right.add_child(action_row)
	_equip_button = _make_button("EQUIP", action_row, equip_selected)
	_drop_button = _make_button("DROP", action_row, drop_selected)
	_use_button = _make_button("USE", action_row, use_selected)
	var loot_heading: Label = Label.new()
	loot_heading.text = "NEARBY LOOT  /  SIGNAL"
	loot_heading.theme_type_variation = &"CyberpunkHeader"
	right.add_child(loot_heading)
	_pickup_label = Label.new()
	_pickup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_pickup_label)
	_pickup_button = _make_button("Pick Up Nearby Loot", right, pickup_nearby)
	var save_row: HBoxContainer = HBoxContainer.new()
	right.add_child(save_row)
	_save_button = _make_button("Save", save_row, save_game)
	_load_button = _make_button("Load", save_row, load_game)
	_status.text = "Choose an item to inspect it."


func _make_button(title: String, parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 38.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _section_caption(value: String) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.theme_type_variation = &"CyberpunkMuted"
	return label


func _rebuild_grid() -> void:
	if _grid == null or inventory == null:
		return
	var focused_index: int = -1
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	for index: int in range(_cell_buttons.size()):
		if is_instance_valid(focus_owner) and _cell_buttons[index] == focus_owner:
			focused_index = index
			break
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cell_buttons.clear()
	_grid.columns = inventory.grid_size.x
	var occupied: Dictionary = {}
	for item: ItemInstance in inventory.get_items():
		for y: int in range(item.dimensions.y):
			for x: int in range(item.dimensions.x):
				occupied[Vector2i(item.grid_position.x + x, item.grid_position.y + y)] = item
	for y: int in range(inventory.grid_size.y):
		for x: int in range(inventory.grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var button: Button = Button.new()
			button.custom_minimum_size = CELL_SIZE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_ALL
			button.clip_text = true
			button.tooltip_text = "Empty slot"
			var item_variant: Variant = occupied.get(cell)
			if item_variant is ItemInstance:
				var item: ItemInstance = item_variant as ItemInstance
				if item.grid_position == cell:
					_populate_item_card(button, item)
				button.tooltip_text = "%s — %s" % [_display_name(item), String(item.rarity_tier).to_upper()]
			else:
				button.text = "·"
			var is_selected: bool = item_variant is ItemInstance and (item_variant as ItemInstance).uuid == selected_uuid
			var is_preview: bool = is_dragging and cell == drag_preview_anchor
			button.theme_type_variation = _cell_variation(item_variant, is_selected, is_preview)
			button.pressed.connect(_on_cell_pressed.bind(cell))
			button.gui_input.connect(_on_cell_gui_input.bind(cell))
			button.mouse_entered.connect(_on_cell_mouse_entered.bind(cell))
			_grid.add_child(button)
			_cell_buttons.append(button)
	if focused_index >= 0 and focused_index < _cell_buttons.size():
		_cell_buttons[focused_index].grab_focus()


func _update_cell_styles() -> void:
	if inventory == null:
		return
	for index: int in range(_cell_buttons.size()):
		var cell: Vector2i = Vector2i(index % inventory.grid_size.x, floori(float(index) / float(inventory.grid_size.x)))
		var button: Button = _cell_buttons[index]
		var item: ItemInstance = inventory.get_item_at(cell)
		var selected: bool = item != null and item.uuid == selected_uuid
		var preview: bool = is_dragging and cell == drag_preview_anchor
		button.theme_type_variation = _cell_variation(item, selected, preview)


func _cell_variation(item_variant: Variant, selected: bool, preview: bool) -> StringName:
	if preview and not drag_preview_valid:
		return &"CyberpunkInventoryInvalidCell"
	if selected or preview:
		return &"CyberpunkInventorySelectedCell"
	if item_variant is ItemInstance:
		return &"CyberpunkInventoryItemCell"
	return &"CyberpunkInventoryCell"


func _on_cell_pressed(cell: Vector2i) -> void:
	select_cell(cell)


func _on_cell_gui_input(event: InputEvent, cell: Vector2i) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			select_cell(cell)
			begin_drag_at(cell)
		elif is_dragging:
			commit_drag_at(_hover_cell)
	elif event is InputEventMouseMotion and is_dragging:
		preview_drag_at(_hover_cell)


func _on_cell_mouse_entered(cell: Vector2i) -> void:
	_hover_cell = cell
	if is_dragging:
		preview_drag_at(cell)


func _refresh_view() -> void:
	if is_dragging:
		cancel_drag()
	if selected_uuid != "" and inventory.get_item(selected_uuid) == null:
		selected_uuid = ""
	_rebuild_grid()
	_refresh_details()
	_refresh_pickup()
	_update_action_buttons()


func _refresh_details() -> void:
	if _details == null:
		return
	var item: ItemInstance = _selected_item()
	if item == null:
		_details.text = "No item selected.\n\nSelect an occupied cell for its rarity, rolled stats and ammunition."
		return
	var definition: ItemDefinition = _definition_for(item)
	if definition == null:
		_details.text = "Unknown item definition."
		return
	var lines: PackedStringArray = [
		_display_name(item),
		"%s  •  %d × %d" % [String(item.rarity_tier).to_upper(), item.dimensions.x, item.dimensions.y],
	]
	for stat_variant: Variant in item.rolled_stats:
		lines.append("%s  %s" % [String(stat_variant).capitalize(), str(item.rolled_stats[stat_variant])])
	if not definition.weapon_family.is_empty():
		lines.append("Magazine  %d / %d" % [item.magazine_ammo, definition.magazine_capacity])
		lines.append("%s reserve  %d" % [String(definition.weapon_family).capitalize(), int(inventory_reserves().get(String(definition.weapon_family), 0))])
	if definition.consumable_heal_amount > 0:
		lines.append("Restores up to %d HP" % definition.consumable_heal_amount)
	if equipment != null and equipment.is_equipped(item):
		lines.append("Equipped: %s" % String(item.equipment_state.get("slot", "" )).to_upper())
	_details.text = "\n".join(lines)
	_refresh_health()


func _refresh_health() -> void:
	if _health_label == null:
		return
	if health_state == null:
		_health_label.text = "Health unavailable"
		return
	_health_label.text = "VITALS  %d / %d HP" % [health_state.current_hp, health_state.max_hp]


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh_health()


func _on_equipment_changed(_slot: String, _item_uuid: String) -> void:
	_refresh_details()
	_update_action_buttons()


func _refresh_pickup() -> void:
	if _pickup_label == null:
		return
	if nearby_item == null or nearby_drop == null:
		_pickup_label.text = "No loot in reach."
	else:
		_pickup_label.text = "%s  •  %s" % [_display_name(nearby_item), String(nearby_item.rarity_tier).to_upper()]


func _update_action_buttons() -> void:
	if _equip_button == null:
		return
	var item: ItemInstance = _selected_item()
	var definition: ItemDefinition = _definition_for(item) if item != null else null
	_equip_button.disabled = definition == null or definition.weapon_family.is_empty()
	_equip_button.text = "Unequip Primary" if item != null and equipment != null and equipment.is_equipped(item) else "Equip Primary"
	_drop_button.disabled = item == null or equipment == null
	_use_button.disabled = item == null or consumables == null or definition == null or definition.consumable_heal_amount <= 0
	_pickup_button.disabled = nearby_item == null or nearby_drop == null
	_save_button.disabled = save_store == null
	_load_button.disabled = save_store == null


func _selected_item() -> ItemInstance:
	return inventory.get_item(selected_uuid) if inventory != null and selected_uuid != "" else null


func _definition_for(item: ItemInstance) -> ItemDefinition:
	if item == null or equipment == null:
		return null
	var candidate: Variant = equipment.definitions.get(String(item.item_id), equipment.definitions.get(item.item_id))
	return candidate as ItemDefinition if candidate is ItemDefinition else null


func inventory_reserves() -> Dictionary:
	return equipment.ammo_pouch.get_reserves() if equipment != null and equipment.ammo_pouch != null else {}


func _display_name(item: ItemInstance) -> String:
	var definition: ItemDefinition = _definition_for(item)
	return definition.display_name if definition != null else String(item.item_id).capitalize()


func _short_name(value: String) -> String:
	return value.substr(0, mini(8, value.length()))


func _populate_item_card(button: Button, item: ItemInstance) -> void:
	var definition: ItemDefinition = _definition_for(item)
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 8)
	card_margin.add_theme_constant_override("margin_top", 5)
	card_margin.add_theme_constant_override("margin_right", 8)
	card_margin.add_theme_constant_override("margin_bottom", 5)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card_margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(stack)
	var glyph: Label = Label.new()
	glyph.text = _item_glyph(definition)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.theme_type_variation = &"CyberpunkItemGlyph"
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(glyph)
	var title: Label = Label.new()
	var display_name: String = _display_name(item).to_upper()
	title.text = display_name.substr(0, mini(20, display_name.length()))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.theme_type_variation = &"CyberpunkItemName"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)
	var metadata: Label = Label.new()
	metadata.text = "%s  /  %d × %d" % [String(item.rarity_tier).to_upper(), item.dimensions.x, item.dimensions.y]
	metadata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metadata.theme_type_variation = &"CyberpunkItemMeta"
	metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(metadata)
	if definition != null and definition.magazine_capacity > 0:
		var ammunition: Label = Label.new()
		ammunition.text = "MAG  %02d / %02d" % [item.magazine_ammo, definition.magazine_capacity]
		ammunition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammunition.theme_type_variation = &"CyberpunkItemMeta"
		ammunition.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(ammunition)


func _item_glyph(definition: ItemDefinition) -> String:
	if definition == null:
		return "◇"
	if definition.consumable_heal_amount > 0:
		return "✚"
	if definition.weapon_family == &"pistol":
		return "⌖"
	if not definition.weapon_family.is_empty():
		return "◈"
	return "⬡"


func _refresh_view_after_inventory_change() -> void:
	_refresh_scheduled = false
	_refresh_view()


func _on_inventory_changed() -> void:
	if _refresh_scheduled:
		return
	_refresh_scheduled = true
	call_deferred("_refresh_view_after_inventory_change")


func _connect_inventory_signal() -> void:
	if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)


func _clear_drag() -> void:
	is_dragging = false
	drag_uuid = ""
	drag_grab_offset = Vector2i.ZERO
	drag_preview_valid = false
	drag_preview_anchor = Vector2i(-1, -1)


func save_game() -> bool:
	if save_store == null:
		_status.text = "Save is unavailable in this scene."
		return false
	var result: Error = save_store.save_to_disk(0)
	_status.text = "Inventory saved to slot 1." if result == OK else "Save failed: %s." % error_string(result)
	return result == OK


func load_game() -> bool:
	if save_store == null:
		_status.text = "Load is unavailable in this scene."
		return false
	var result: Error = save_store.load_from_disk(0)
	if result != OK:
		_status.text = "Load failed: %s." % error_string(result)
		return false
	selected_uuid = "" if inventory.get_item(selected_uuid) == null else selected_uuid
	_refresh_view()
	_status.text = "Inventory loaded from slot 1."
	return true
