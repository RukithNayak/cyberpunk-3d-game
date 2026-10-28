extends RefCounted

var _snapshot_service: InventorySnapshot
var _health_for_save: HealthState
var _saved_player: Dictionary = {}


class PlayerLockStub extends Node:
	var locks: Dictionary = {}
	var can_act: bool = true
	var is_alive: bool = true

	func add_control_lock(lock_id: StringName) -> void:
		locks[lock_id] = true
		can_act = false

	func remove_control_lock(lock_id: StringName) -> void:
		locks.erase(lock_id)
		can_act = locks.is_empty()

	func can_fire() -> bool:
		return is_alive and can_act

	func can_use_inventory_action() -> bool:
		return is_alive and (locks.is_empty() or locks.size() == 1 and locks.has(&"inventory_ui"))


func run(check: Callable) -> void:
	check.call(String(ProjectSettings.get_setting("gui/theme/custom", "")) == "res://ui/cyberpunk_theme.tres", "project assigns the reusable cyberpunk Theme")
	var shared_theme: Theme = load("res://ui/cyberpunk_theme.tres") as Theme
	var display_font: SystemFont = shared_theme.default_font as SystemFont if shared_theme != null else null
	check.call(display_font != null and display_font.font_names.has("Avenir Next"), "shared Theme uses the revised Avenir display typography")
	var panel_style: StyleBoxFlat = shared_theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat if shared_theme != null else null
	check.call(panel_style != null and panel_style.bg_color.get_luminance() > 0.08, "shared panel surfaces have the brighter graphite contrast")
	var ui_scene: PackedScene = load("res://ui/inventory_ui.tscn") as PackedScene
	check.call(ui_scene != null, "inventory UI scene is available")
	if ui_scene == null:
		return
	var definitions: Dictionary = _definitions()
	var grid: GridInventory = GridInventory.new(Vector2i(4, 3))
	var pouch: AmmoPouch = AmmoPouch.new(100)
	var health: HealthState = HealthState.new(100)
	var player: PlayerLockStub = PlayerLockStub.new()
	var pistol: ItemInstance = _item(definitions["ui_pistol"], 1, Vector2i(0, 0), 5)
	var rifle: ItemInstance = _item(definitions["ui_rifle"], 2, Vector2i(1, 0), 3)
	var medkit: ItemInstance = _item(definitions["ui_medkit"], 3, Vector2i(0, 1))
	pistol.rolled_stats = {"damage": 24.0}
	check.call(grid.try_add_item(pistol) and grid.try_add_item(rifle) and grid.try_add_item(medkit), "inventory fixture records are prepared")
	check.call(pouch.add_ammo("pistol", 12) and pouch.add_ammo("rifle", 7), "family reserves are prepared")
	var equipment: EquipmentService = EquipmentService.new(grid, definitions, pouch)
	var consumables: ConsumableService = ConsumableService.new(grid, definitions, health)
	var action_machine: WeaponStateMachine = WeaponStateMachine.new()
	var weapon_controller: WeaponController = WeaponController.new()
	player.add_child(action_machine)
	action_machine.configure(player, weapon_controller, equipment, consumables, health)
	_snapshot_service = InventorySnapshot.new(grid, pouch, definitions, ItemGrants.new(grid, definitions))
	_health_for_save = health
	var adapters: SnapshotAdapters = SnapshotAdapters.new(
		EntityRegistry.new(),
		FactionState.new(["ui_test_faction"]),
		Callable(self, "_capture_player"),
		Callable(self, "_prepare_player"),
		Callable(self, "_commit_player"),
		Callable(self, "_capture_domains"),
		Callable(self, "_prepare_domains"),
		Callable(self, "_commit_domains")
	)
	var save_directory: String = "user://inventory_ui_test_%d" % OS.get_process_id()
	var save_store: SaveStore = SaveStore.new(save_directory, Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"))
	var ui: Control = ui_scene.instantiate() as Control
	ui.call("configure", grid, equipment, consumables, health, player, save_store)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	tree.root.add_child(ui)
	await tree.process_frame
	ui.call("open_inventory")
	var grid_control: GridContainer = ui.get("_grid") as GridContainer
	var first_card: Button = grid_control.get_child(0) as Button if grid_control != null and grid_control.get_child_count() > 0 else null
	check.call(first_card != null and first_card.custom_minimum_size.x >= 124.0 and first_card.custom_minimum_size.y >= 140.0, "inventory cells use readable equipment-card proportions")
	check.call(ui.visible and not player.can_act, "opening inventory locks player input")
	check.call(ui.get_viewport().gui_get_focus_owner() != null, "opening inventory selects a keyboard-navigation control")
	ui.call("select_cell", Vector2i.ZERO)
	var pistol_details: String = String(ui.call("get_selected_details_text"))
	check.call(pistol_details.contains("COMMON") and pistol_details.contains("Damage") and pistol_details.contains("24.0") and pistol_details.contains("5 / 12") and pistol_details.contains("Pistol reserve") and pistol_details.contains("12"), "inspection shows rarity, rolled stats, magazine and family reserves")
	check.call(bool(ui.call("begin_drag_at", Vector2i.ZERO)), "occupied cell begins a drag")
	check.call(not bool(ui.call("preview_drag_at", Vector2i(1, 0))), "overlap preview is invalid")
	check.call(not bool(ui.call("commit_drag_at", Vector2i(1, 0))) and grid.get_item(pistol.uuid).grid_position == Vector2i.ZERO, "failed placement preserves the item")
	check.call(bool(ui.call("begin_drag_at", Vector2i.ZERO)) and bool(ui.call("preview_drag_at", Vector2i(3, 0))), "free-cell placement preview is valid")
	check.call(bool(ui.call("commit_drag_at", Vector2i(3, 0))) and grid.get_item(pistol.uuid).grid_position == Vector2i(3, 0), "valid drag commits through inventory service")
	check.call(bool(ui.call("begin_drag_at", Vector2i(3, 0))), "second drag begins")
	ui.call("cancel_drag")
	check.call(grid.get_item(pistol.uuid).grid_position == Vector2i(3, 0), "cancelled drag leaves item in its authoritative cell")
	ui.call("select_cell", Vector2i(3, 0))
	check.call(bool(ui.call("equip_selected")) and equipment.is_equipped(grid.get_item(pistol.uuid)) and String(ui.call("get_selected_details_text")).contains("Equipped: PRIMARY"), "equip action uses equipment service and refreshes equipment event")
	ui.call("select_cell", Vector2i(1, 0))
	check.call(bool(ui.call("equip_selected")) and equipment.is_equipped(grid.get_item(rifle.uuid)) and not equipment.is_equipped(grid.get_item(pistol.uuid)), "equipping second weapon swaps through equipment service")
	ui.call("select_cell", Vector2i(0, 1))
	health.apply_damage(30, "fixture")
	check.call(bool(ui.call("use_selected")) and health.current_hp == 95 and grid.get_item(medkit.uuid) == null, "consumable action heals and consumes through service")
	ui.call("select_cell", Vector2i(1, 0))
	var dropped_items: Array[ItemInstance] = []
	ui.connect("item_dropped", func(item: ItemInstance) -> void: dropped_items.append(item))
	check.call(bool(ui.call("drop_selected")) and grid.get_item(rifle.uuid) == null and dropped_items.size() == 1 and not equipment.is_equipped(dropped_items[0]), "drop action transfers an unequipped item to the fixture")
	check.call(bool(ui.call("save_game")), "inventory UI saves through the CORE-04 save store")
	var displaced_rifle: ItemInstance = dropped_items.pop_back()
	displaced_rifle.grid_position = Vector2i(2, 1)
	check.call(grid.try_add_item(displaced_rifle), "save-load comparison mutates inventory after snapshot")
	check.call(bool(ui.call("load_game")), "inventory UI loads the saved inventory through CORE-04")
	ui.call("select_cell", Vector2i(3, 0))
	check.call(grid.get_item(pistol.uuid).grid_position == Vector2i(3, 0) and grid.get_item(rifle.uuid) == null and String(ui.call("get_selected_details_text")).contains("Tactical Pistol"), "UI refresh after save/load matches restored inventory model")
	var loot_item: ItemInstance = _item(definitions["ui_scrap"], 10, Vector2i(0, 2))
	var loot_node: Node = Node.new()
	tree.root.add_child(loot_node)
	await tree.process_frame
	ui.call("set_nearby_pickup", loot_item, loot_node)
	for y: int in range(3):
		for x: int in range(4):
			var cell_item: ItemInstance = grid.get_item_at(Vector2i(x, y))
			if cell_item == null:
				var filler: ItemInstance = _item(definitions["ui_scrap"], 100 + y * 4 + x, Vector2i(x, y))
				check.call(grid.try_add_item(filler), "fixture fills free grid cell")
	check.call(not bool(ui.call("pickup_nearby")) and loot_node.get_parent() == tree.root and String(ui.call("get_status_text")).to_lower().contains("full"), "full-grid pickup explains rejection and keeps world loot")
	var freed_cell: ItemInstance = grid.get_item_at(Vector2i(0, 2))
	if freed_cell != null:
		grid.remove_item(freed_cell.uuid)
	check.call(bool(ui.call("pickup_nearby")) and loot_node.is_queued_for_deletion() and grid.get_item(loot_item.uuid) != null, "pickup retries successfully after capacity is available")
	var mouse_press: InputEventMouseButton = InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	ui.call("_on_cell_gui_input", mouse_press, Vector2i(3, 0))
	ui.call("_on_cell_mouse_entered", Vector2i(2, 0))
	var mouse_release: InputEventMouseButton = InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	ui.call("_on_cell_gui_input", mouse_release, Vector2i(2, 0))
	check.call(not bool(ui.get("is_dragging")) and grid.get_item(pistol.uuid).grid_position == Vector2i(3, 0), "mouse event drag path cancels invalid overlap without moving item")
	check.call(bool(ui.call("begin_drag_at", Vector2i(3, 0))), "drag can start before closing the UI")
	ui.call("close_inventory")
	check.call(not ui.visible and player.can_act and not bool(ui.get("is_dragging")), "closing cancels drag and restores player control")
	ui.call("open_inventory")
	check.call(ui.visible and not player.can_act, "reopening inventory restores its player lock")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui.call("_unhandled_input", escape)
	check.call(not ui.visible and player.can_act, "Escape closes inventory and releases input lock")
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	ui.call("_unhandled_input", tab)
	check.call(ui.visible and not player.can_act, "Tab reopens inventory and reacquires its input lock")
	check.call(bool(ui.call("begin_drag_at", Vector2i(3, 0))), "scene-exit fixture starts a drag")
	ui.queue_free()
	await tree.process_frame
	check.call(player.can_act and grid.get_item(pistol.uuid).grid_position == Vector2i(3, 0), "scene exit cancels drag without moving the item and releases input lock")
	player.queue_free()
	weapon_controller.free()
	await tree.process_frame
	_cleanup_save(save_directory)


func _definitions() -> Dictionary:
	var pistol: ItemDefinition = _definition("ui_pistol", "Tactical Pistol", &"pistol", 12, 0, Vector2i.ONE)
	pistol.base_stats = {"damage": 21.0}
	var rifle: ItemDefinition = _definition("ui_rifle", "Compact Rifle", &"rifle", 20, 0, Vector2i.ONE)
	var medkit: ItemDefinition = _definition("ui_medkit", "Field Medkit", &"", 0, 25, Vector2i.ONE)
	var scrap: ItemDefinition = _definition("ui_scrap", "Circuit Scrap", &"", 0, 0, Vector2i.ONE)
	return {"ui_pistol": pistol, "ui_rifle": rifle, "ui_medkit": medkit, "ui_scrap": scrap}


func _definition(item_id: String, title: String, family: StringName, magazine: int, healing: int, size: Vector2i) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = StringName(item_id)
	definition.display_name = title
	definition.dimensions = size
	definition.weapon_family = family
	definition.magazine_capacity = magazine
	definition.consumable_heal_amount = healing
	return definition


func _item(definition: ItemDefinition, serial: int, cell: Vector2i, magazine: int = 0) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-%012d" % serial
	item.item_id = definition.item_id
	item.grid_position = cell
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	return item


func _capture_player() -> Dictionary:
	return {"health": _health_for_save.current_hp, "max_health": _health_for_save.max_hp}


func _prepare_player(candidate: Dictionary) -> Dictionary:
	if typeof(candidate.get("health")) != TYPE_INT or typeof(candidate.get("max_health")) != TYPE_INT:
		return {"ok": false, "prepared": {}}
	var maximum: int = candidate["max_health"]
	var current: int = candidate["health"]
	return {"ok": maximum > 0 and current >= 0 and current <= maximum, "prepared": {"health": current, "max_health": maximum}}


func _commit_player(prepared: Dictionary) -> void:
	_saved_player = prepared.duplicate(true)
	_health_for_save.restore(prepared["health"], prepared["max_health"])


func _capture_domains() -> Dictionary:
	return {"inventory": _snapshot_service.capture_snapshot()}


func _prepare_domains(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 1 or not candidate.has("inventory"):
		return {"ok": false, "prepared": {}}
	var prepared: Dictionary = _snapshot_service.prepare_snapshot(candidate["inventory"])
	return {"ok": bool(prepared.get("ok", false)), "prepared": {"inventory": prepared.get("prepared", {})}}


func _commit_domains(prepared: Dictionary) -> void:
	_snapshot_service.commit_prepared_snapshot(prepared["inventory"])


func _cleanup_save(directory: String) -> void:
	var path: String = "%s/slot_00.save" % directory
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
