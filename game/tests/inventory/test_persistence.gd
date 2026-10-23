extends RefCounted

var _inventory_snapshot: RefCounted
var _player_state: Dictionary = {"health": 100}
var _other_domains: Dictionary = {"other": {"keep": true}}


func run(check: Callable) -> void:
	var snapshot_script: Script = load("res://features/inventory/inventory_snapshot.gd") as Script
	var grants_script: Script = load("res://features/inventory/item_grants.gd") as Script
	check.call(snapshot_script != null, "inventory snapshot service is available")
	check.call(grants_script != null, "idempotent item grant service is available")
	if snapshot_script == null or grants_script == null:
		return
	var definition: ItemDefinition = _definition("save_pistol", &"pistol", 12)
	var scrap: ItemDefinition = _definition("save_scrap", &"", 0)
	var definitions: Dictionary = {"save_pistol": definition, "save_scrap": scrap}
	var grid: GridInventory = GridInventory.new(Vector2i(2, 2))
	var pouch: AmmoPouch = AmmoPouch.new(100)
	var grants: RefCounted = grants_script.new(grid, definitions) as RefCounted
	_inventory_snapshot = snapshot_script.new(grid, pouch, definitions, grants) as RefCounted
	var equipment: EquipmentService = EquipmentService.new(grid, definitions, pouch)
	var weapon: ItemInstance = _item(definition, 1, Vector2i.ZERO, 7, {"damage": 31.5})
	check.call(grid.try_add_item(weapon) and equipment.equip_item(weapon.uuid, "primary"), "equipped weapon is prepared for persistence")
	check.call(pouch.add_ammo("pistol", 18), "reserve ammunition is prepared for persistence")

	var registry: EntityRegistry = EntityRegistry.new()
	var faction_ids: Array[String] = ["corpos"]
	var factions: FactionState = FactionState.new(faction_ids)
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
	var directory: String = "user://inventory_persistence_%d" % OS.get_process_id()
	var store: SaveStore = SaveStore.new(directory, Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"))
	check.call(store.save_to_disk(0) == OK, "first equipped inventory snapshot saves through CORE-04 adapters")
	var good_slot_zero: PackedByteArray = FileAccess.get_file_as_bytes("%s/slot_00.save" % directory)
	_test_corrupt_inventory_load(check, adapters, store, directory, good_slot_zero, grid)

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var dropped: ItemInstance = equipment.drop_item(weapon.uuid)
	dropped.grid_position = Vector2i(1, 0)
	var world_drop: Node = Node.new()
	tree.root.add_child(world_drop)
	await tree.process_frame
	check.call(grid.try_pickup_item(dropped, world_drop), "dropped item is picked back up before second save")
	check.call(world_drop.is_queued_for_deletion() and equipment.equip_item(weapon.uuid, "primary"), "pickup removal and re-equip are applied")
	await tree.process_frame
	check.call(store.save_to_disk(1) == OK, "second inventory state saves with its new grid placement")

	var blockers: Array[ItemInstance] = [
		_item(scrap, 11, Vector2i.ZERO),
		_item(scrap, 12, Vector2i(0, 1)),
		_item(scrap, 13, Vector2i(1, 1)),
	]
	for blocker: ItemInstance in blockers:
		check.call(grid.try_add_item(blocker), "inventory accepts blocker for full-grid reward fixture")
	var reward: ItemInstance = _item(scrap, 20, Vector2i(1, 1))
	check.call(not bool(grants.call("grant", "reward.alpha", reward)), "full inventory rejects immediate reward grant")
	check.call(bool(grants.call("has_pending", "reward.alpha")), "rejected full-grid grant retains an unclaimed entitlement")
	check.call(store.save_to_disk(2) == OK, "pending entitlement saves through the domain snapshot adapter")
	var good_slot_two: PackedByteArray = FileAccess.get_file_as_bytes("%s/slot_02.save" % directory)

	check.call(store.load_from_disk(0) == OK, "first save restores prior equipment state")
	var restored_weapon: ItemInstance = grid.get_item(weapon.uuid)
	check.call(restored_weapon != null and restored_weapon.grid_position == Vector2i.ZERO and restored_weapon.magazine_ammo == 7 and restored_weapon.rolled_stats["damage"] == 31.5 and equipment.is_equipped(restored_weapon), "first load preserves grid position, equipment, rolls, and magazine")
	check.call(pouch.get_ammo("pistol") == 18 and _other_domains == {"other": {"keep": true}}, "first load preserves family reserves and unrelated domain data")
	check.call(store.load_from_disk(1) == OK and grid.get_item(weapon.uuid).grid_position == Vector2i(1, 0), "second save independently restores the dropped-and-picked-up placement")
	check.call(store.load_from_disk(2) == OK and bool(grants.call("has_pending", "reward.alpha")), "pending entitlement survives load after a full-grid rejection")
	check.call(grid.remove_item(blockers[2].uuid) != null, "freeing one grid cell permits reward retry")
	check.call(bool(grants.call("retry_pending", "reward.alpha")), "pending reward commits after grid capacity becomes available")
	var count_after_award: int = grid.get_item_count()
	check.call(count_after_award == 4 and not bool(grants.call("has_pending", "reward.alpha")), "one reward item is committed and entitlement is claimed")
	check.call(bool(grants.call("grant", "reward.alpha", reward)) and grid.get_item_count() == count_after_award, "replaying a claimed reward transaction does not duplicate its item")
	check.call(store.save_to_disk(3) == OK, "claimed grant ledger is saved")
	check.call(grid.remove_item(reward.uuid) != null and store.load_from_disk(3) == OK, "save load restores the awarded item and its claimed transaction")
	var restored_count: int = grid.get_item_count()
	check.call(bool(grants.call("grant", "reward.alpha", reward)) and grid.get_item_count() == restored_count, "replaying the grant after load remains idempotent")
	_test_corrupt_snapshot_rejected(check, adapters, grid)
	_cleanup(directory)


func _test_corrupt_inventory_load(check: Callable, adapters: SnapshotAdapters, store: SaveStore, directory: String, good_bytes: PackedByteArray, grid: GridInventory) -> void:
	var before: Dictionary = adapters.capture_snapshot()
	var corrupted: Dictionary = before.duplicate(true)
	corrupted["domains"]["inventory"]["items"].append(corrupted["domains"]["inventory"]["items"][0].duplicate(true))
	var envelope: Dictionary = {"format": SaveStore.FORMAT_ID, "version": str(SaveStore.CURRENT_VERSION), "payload": store.call("_encode_value", corrupted)}
	_write_bytes("%s/slot_00.save" % directory, JSON.stringify(envelope).to_utf8_buffer())
	check.call(store.load_from_disk(0) != OK and adapters.capture_snapshot() == before, "duplicate item UUID load rejects without partially changing inventory or adapters")
	_write_bytes("%s/slot_00.save" % directory, good_bytes)
	var invalid_reference: Dictionary = before["domains"]["inventory"].duplicate(true)
	invalid_reference["items"][0]["item_id"] = "missing_item"
	check.call(not bool(_inventory_snapshot.call("validate_snapshot", invalid_reference)) and grid.get_item_count() == before.domains.inventory.items.size(), "unknown item definition rejects before hydration")


func _test_corrupt_snapshot_rejected(check: Callable, adapters: SnapshotAdapters, grid: GridInventory) -> void:
	var before: Dictionary = adapters.capture_snapshot()
	var invalid: Dictionary = before["domains"]["inventory"].duplicate(true)
	invalid["items"][0]["dimensions"] = [99, 1]
	check.call(not bool(_inventory_snapshot.call("validate_snapshot", invalid)) and grid.get_item_count() == before.domains.inventory.items.size(), "out-of-range item dimensions reject without partial hydration")


func _definition(item_id: String, family: StringName, magazine_capacity: int) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = StringName(item_id)
	definition.display_name = item_id
	definition.dimensions = Vector2i.ONE
	definition.weapon_family = family
	definition.magazine_capacity = magazine_capacity
	return definition


func _item(definition: ItemDefinition, serial: int, position: Vector2i, magazine_ammo: int = 0, rolled_stats: Dictionary = {}) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-%012d" % serial
	item.item_id = definition.item_id
	item.grid_position = position
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine_ammo
	item.rolled_stats = rolled_stats.duplicate(true)
	return item


func _capture_player() -> Dictionary:
	return _player_state.duplicate(true)


func _prepare_player(candidate: Dictionary) -> Dictionary:
	return {"ok": candidate.has("health"), "prepared": candidate.duplicate(true)}


func _commit_player(prepared: Dictionary) -> void:
	_player_state = prepared.duplicate(true)


func _capture_domains() -> Dictionary:
	var result: Dictionary = _other_domains.duplicate(true)
	result["inventory"] = _inventory_snapshot.call("capture_snapshot")
	return result


func _prepare_domains(candidate: Dictionary) -> Dictionary:
	if not candidate.has("inventory"):
		return {"ok": false, "prepared": {}}
	var inventory_result: Dictionary = _inventory_snapshot.call("prepare_snapshot", candidate["inventory"])
	if not inventory_result.get("ok", false):
		return {"ok": false, "prepared": {}}
	var extra_domains: Dictionary = candidate.duplicate(true)
	extra_domains.erase("inventory")
	return {"ok": true, "prepared": {"inventory": inventory_result["prepared"], "other_domains": extra_domains}}


func _commit_domains(prepared: Dictionary) -> void:
	_inventory_snapshot.call("commit_prepared_snapshot", prepared["inventory"])
	_other_domains = prepared["other_domains"].duplicate(true)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var directory_path: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()


func _cleanup(directory: String) -> void:
	for slot: int in range(4):
		var path: String = "%s/slot_%02d.save" % [directory, slot]
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
