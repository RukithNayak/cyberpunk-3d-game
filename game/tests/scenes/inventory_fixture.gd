extends Control
## Self-contained playable fixture for the inventory UI and its accepted services.


class FixturePlayer extends Node:
	signal lock_changed(can_act: bool)
	var can_act: bool = true
	var _locks: Dictionary = {}

	func add_control_lock(lock_id: StringName) -> void:
		_locks[lock_id] = true
		can_act = false
		lock_changed.emit(can_act)

	func remove_control_lock(lock_id: StringName) -> void:
		_locks.erase(lock_id)
		can_act = _locks.is_empty()
		lock_changed.emit(can_act)


var _definitions: Dictionary = {}
var _inventory: GridInventory
var _ammo: AmmoPouch
var _grants: ItemGrants
var _snapshot: InventorySnapshot
var _equipment: EquipmentService
var _health: HealthState
var _player: FixturePlayer
var _ui: InventoryUI
var _save_store: SaveStore
var _world_drops: Array[Node] = []
var _next_serial: int = 50
var _input_status: Label
var _loot_status: Label
var _debug_toolbar: HBoxContainer


func _ready() -> void:
	_build_fixture_backdrop()
	_setup_services()
	_setup_save_store()
	_add_player_input_stub()
	_setup_inventory_ui()
	_setup_toolbar()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_F1:
		get_tree().change_scene_to_file("res://tests/scenes/inventory_fixture.tscn")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F2 and _debug_toolbar != null:
		_debug_toolbar.visible = not _debug_toolbar.visible
		get_viewport().set_input_as_handled()


func _build_fixture_backdrop() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.012, 0.02, 0.045)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(0.0, 0.76, 0.92, 0.8)
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.offset_top = 0.0
	strip.offset_bottom = 3.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)


func _setup_services() -> void:
	_definitions = _build_definitions()
	_inventory = GridInventory.new(Vector2i(6, 4))
	_ammo = AmmoPouch.new(100)
	_grants = ItemGrants.new(_inventory, _definitions)
	_snapshot = InventorySnapshot.new(_inventory, _ammo, _definitions, _grants)
	_equipment = EquipmentService.new(_inventory, _definitions, _ammo)
	_health = HealthState.new(100)
	_health.apply_damage(34, "inventory_fixture")
	_ammo.add_ammo("pistol", 24)
	_ammo.add_ammo("rifle", 48)
	_inventory.try_add_item(_make_item(_definitions["ui_pistol"], 1, Vector2i(0, 0), 9, {"damage": 26.0}))
	_inventory.try_add_item(_make_item(_definitions["ui_rifle"], 2, Vector2i(2, 0), 17, {"damage": 32.0}))
	_inventory.try_add_item(_make_item(_definitions["ui_medkit"], 3, Vector2i(0, 2)))
	_equipment.equip_item("00000000-0000-4000-8000-000000000001", "primary")


func _setup_save_store() -> void:
	var registry: EntityRegistry = EntityRegistry.new()
	var factions: FactionState = FactionState.new(["fixture_faction"])
	var adapters: SnapshotAdapters = SnapshotAdapters.new(
		registry,
		factions,
		Callable(self, "_capture_player"),
		Callable(self, "_prepare_player"),
		Callable(self, "_commit_player"),
		Callable(self, "_capture_domains"),
		Callable(self, "_prepare_domains"),
		Callable(self, "_commit_domains")
	)
	_save_store = SaveStore.new("user://inventory_fixture", Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"))


func _add_player_input_stub() -> void:
	_player = FixturePlayer.new()
	_player.name = "FixturePlayerInput"
	add_child(_player)


func _setup_inventory_ui() -> void:
	var ui_scene: PackedScene = load("res://ui/inventory_ui.tscn") as PackedScene
	_ui = ui_scene.instantiate() as InventoryUI
	_ui.name = "InventoryUI"
	_ui.configure(_inventory, _equipment, ConsumableService.new(_inventory, _definitions, _health), _health, _player, _save_store)
	_ui.item_dropped.connect(_on_item_dropped)
	add_child(_ui)
	var loot: ItemInstance = _make_item(_definitions["ui_scrap"], 20, Vector2i(5, 3))
	var loot_node: Node = Node.new()
	loot_node.name = "NearbyLootDrop"
	loot_node.set_meta("inventory_item", loot.to_data())
	add_child(loot_node)
	_ui.set_nearby_pickup(loot, loot_node)
	_player.lock_changed.connect(_refresh_input_status)


func _setup_toolbar() -> void:
	_debug_toolbar = HBoxContainer.new()
	_debug_toolbar.anchor_left = 0.035
	_debug_toolbar.anchor_top = 0.006
	_debug_toolbar.anchor_right = 0.965
	_debug_toolbar.anchor_bottom = 0.052
	_debug_toolbar.add_theme_constant_override("separation", 10)
	_debug_toolbar.visible = false
	add_child(_debug_toolbar)
	var row: HBoxContainer = _debug_toolbar
	var title: Label = Label.new()
	title.text = "INV-05 PLAYTEST"
	title.add_theme_color_override("font_color", Color(0.35, 0.91, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var fill_button: Button = Button.new()
	fill_button.text = "Fill Grid"
	fill_button.tooltip_text = "Occupy all empty cells to test rejected pickup."
	fill_button.pressed.connect(_fill_empty_cells)
	row.add_child(fill_button)
	var damage_button: Button = Button.new()
	damage_button.text = "Take Damage"
	damage_button.pressed.connect(_hurt_player)
	row.add_child(damage_button)
	_input_status = Label.new()
	_input_status.custom_minimum_size.x = 125.0
	row.add_child(_input_status)
	_refresh_input_status()
	_loot_status = Label.new()
	_loot_status.custom_minimum_size.x = 110.0
	_loot_status.text = "World drops: 0"
	_loot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loot_status.add_theme_color_override("font_color", Color(0.94, 0.64, 0.35))
	row.add_child(_loot_status)
	var note: Label = Label.new()
	note.anchor_left = 0.035
	note.anchor_top = 0.952
	note.anchor_right = 0.965
	note.anchor_bottom = 0.995
	note.text = "TAB / ESC CLOSE   •   F1 RELOAD TEST   •   F2 TEST CONTROLS"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(0.42, 0.67, 0.78))
	add_child(note)


func _fill_empty_cells() -> void:
	for y: int in range(_inventory.grid_size.y):
		for x: int in range(_inventory.grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _inventory.get_item_at(cell) != null:
				continue
			_next_serial += 1
			var filler: ItemInstance = _make_item(_definitions["ui_scrap"], _next_serial, cell)
			_inventory.try_add_item(filler)
	_ui.refresh_view()


func _hurt_player() -> void:
	_health.apply_damage(10, "fixture_button")
	_ui.refresh_view()


func _on_item_dropped(item: ItemInstance) -> void:
	var drop: Node = Node.new()
	drop.name = "Dropped_%s" % item.uuid.substr(item.uuid.length() - 4)
	drop.set_meta("inventory_item", item.to_data())
	add_child(drop)
	_world_drops.append(drop)
	_loot_status.text = "World drops: %d" % _world_drops.size()
	if _ui.nearby_item == null:
		_ui.set_nearby_pickup(item, drop)


func _refresh_input_status(_can_act: bool = false) -> void:
	if _input_status == null or _player == null:
		return
	_input_status.text = "INPUT: FREE" if _player.can_act else "INPUT: LOCKED"
	_input_status.add_theme_color_override("font_color", Color(0.4, 0.94, 0.55) if _player.can_act else Color(1.0, 0.43, 0.52))


func _capture_player() -> Dictionary:
	return {"health": _health.current_hp, "max_health": _health.max_hp}


func _prepare_player(candidate: Dictionary) -> Dictionary:
	if typeof(candidate.get("health")) != TYPE_INT or typeof(candidate.get("max_health")) != TYPE_INT:
		return {"ok": false, "prepared": {}}
	var maximum: int = candidate["max_health"]
	var current: int = candidate["health"]
	return {"ok": maximum > 0 and current >= 0 and current <= maximum, "prepared": {"health": current, "max_health": maximum}}


func _commit_player(prepared: Dictionary) -> void:
	_health.restore(prepared["health"], prepared["max_health"])
	_ui.refresh_view()


func _capture_domains() -> Dictionary:
	return {"inventory": _snapshot.capture_snapshot()}


func _prepare_domains(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 1 or not candidate.has("inventory"):
		return {"ok": false, "prepared": {}}
	var prepared: Dictionary = _snapshot.prepare_snapshot(candidate["inventory"])
	return {"ok": bool(prepared.get("ok", false)), "prepared": prepared.get("prepared", {})}


func _commit_domains(prepared: Dictionary) -> void:
	_snapshot.commit_prepared_snapshot(prepared["inventory"])
	_ui.refresh_view()


func _build_definitions() -> Dictionary:
	var pistol: ItemDefinition = _definition("ui_pistol", "Tactical Pistol", &"pistol", 12, 0)
	pistol.base_stats = {"damage": 22.0}
	var rifle: ItemDefinition = _definition("ui_rifle", "Compact Rifle", &"rifle", 24, 0)
	rifle.base_stats = {"damage": 28.0}
	var medkit: ItemDefinition = _definition("ui_medkit", "Field Medkit", &"", 0, 25)
	var scrap: ItemDefinition = _definition("ui_scrap", "Circuit Scrap", &"", 0, 0)
	return {"ui_pistol": pistol, "ui_rifle": rifle, "ui_medkit": medkit, "ui_scrap": scrap}


func _definition(item_id: String, title: String, family: StringName, magazine: int, healing: int) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = StringName(item_id)
	definition.display_name = title
	definition.weapon_family = family
	definition.magazine_capacity = magazine
	definition.consumable_heal_amount = healing
	return definition


func _make_item(definition: ItemDefinition, serial: int, cell: Vector2i, magazine: int = 0, rolls: Dictionary = {}) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-%012d" % serial
	item.item_id = definition.item_id
	item.grid_position = cell
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	item.rolled_stats = rolls.duplicate(true)
	return item
