extends RefCounted


class ShotStub extends WeaponController:
	var accept_shot: bool = true
	var calls: int = 0
	var last_stats: WeaponStats

	func fire_weapon(stats: Resource) -> HitResult:
		calls += 1
		last_stats = stats as WeaponStats
		var result: HitResult = HitResult.new()
		result.fired = accept_shot
		return result


class PlayerStub extends Node3D:
	signal control_lock_changed(locked: bool)
	var is_alive: bool = true
	var can_act: bool = true

	func can_fire() -> bool:
		return is_alive and can_act

	func has_control_locks() -> bool:
		return not can_act


var _grid: GridInventory
var _pouch: AmmoPouch
var _equipment: EquipmentService
var _health: HealthState
var _consumables: ConsumableService
var _player: PlayerStub
var _weapon: ShotStub
var _machine: Node
var _inventory_snapshot: InventorySnapshot
var _player_snapshot: PlayerSnapshot


func run(check: Callable) -> void:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = &"txn_pistol"
	definition.display_name = "Transaction Pistol"
	definition.weapon_family = &"pistol"
	definition.magazine_capacity = 6
	definition.base_stats = {"damage": 20.0, "fire_rate_per_second": 5.0, "range_m": 30.0, "spread_degrees": 0.0, "recoil_degrees": 0.0}
	var med_definition: ItemDefinition = ItemDefinition.new()
	med_definition.item_id = &"txn_medkit"
	med_definition.display_name = "Transaction Medkit"
	med_definition.consumable_heal_amount = 25
	_grid = GridInventory.new(Vector2i(4, 3))
	_pouch = AmmoPouch.new(100)
	_health = HealthState.new(100)
	_player = PlayerStub.new()
	var weapon_item: ItemInstance = _make_item(definition, 1, Vector2i.ZERO, 2)
	weapon_item.rolled_stats = {"damage": 24.0}
	var med_item: ItemInstance = _make_item(med_definition, 2, Vector2i(1, 0), 0)
	check.call(_grid.try_add_item(weapon_item) and _grid.try_add_item(med_item), "weapon and healing item enter inventory")
	check.call(_pouch.add_ammo("pistol", 8), "reserve ammo enters family pouch")
	_equipment = EquipmentService.new(_grid, {"txn_pistol": definition, "txn_medkit": med_definition}, _pouch)
	_equipment.equip_item(weapon_item.uuid, "primary")
	_consumables = ConsumableService.new(_grid, {"txn_pistol": definition, "txn_medkit": med_definition}, _health)
	_weapon = ShotStub.new()
	_machine = (load("res://features/combat/weapon_state_machine.gd") as Script).new() as WeaponStateMachine
	_machine.configure(_player, _weapon, _equipment, _consumables, _health)
	var first_shot: HitResult = _machine.call("fire_current_weapon") as HitResult
	check.call(first_shot.fired and _grid.get_item(weapon_item.uuid).magazine_ammo == 1, "accepted fire commits exactly one magazine round")
	_weapon.accept_shot = false
	var rejected_shot: HitResult = _machine.call("fire_current_weapon") as HitResult
	check.call(not rejected_shot.fired and _grid.get_item(weapon_item.uuid).magazine_ammo == 1, "rejected shot restores the reserved magazine round")
	_weapon.accept_shot = true
	var initial_reload: int = int(_machine.call("begin_reload"))
	check.call(initial_reload > 0 and String(_machine.call("get_state_name")) == "reloading", "reload begins with a one-use animation token")
	var reload_token: int = int(_machine.call("get_action_token"))
	var blocked_fire: HitResult = _machine.call("fire_current_weapon") as HitResult
	check.call(not blocked_fire.fired and String(_machine.call("get_state_name")) == "reloading", "fire input during reload cannot bypass the action state")
	check.call(bool(_machine.call("complete_reload", reload_token)) and _grid.get_item(weapon_item.uuid).magazine_ammo == 6 and _pouch.get_ammo("pistol") == 3, "reload completion transfers bounded reserve ammo once")
	check.call(not bool(_machine.call("complete_reload", reload_token)) and _pouch.get_ammo("pistol") == 3, "repeated reload callback cannot duplicate ammunition")
	check.call(_grid.get_item(weapon_item.uuid).magazine_ammo + _pouch.get_ammo("pistol") == 9, "accepted shot and reload preserve total ammunition")
	var before_swap: ItemInstance = _grid.get_item(weapon_item.uuid).duplicate(true) as ItemInstance
	before_swap.magazine_ammo = 1
	_grid.try_update_items([before_swap])
	var cancelled_reload: int = int(_machine.call("begin_reload"))
	var replacement: ItemInstance = _make_item(definition, 3, Vector2i(2, 0), 0)
	_grid.try_add_item(replacement)
	_equipment.equip_item(replacement.uuid, "primary")
	check.call(String(_machine.call("get_state_name")) == "idle" and not bool(_machine.call("complete_reload", cancelled_reload)), "weapon swap cancels outstanding reload callback")
	_equipment.equip_item(weapon_item.uuid, "primary")
	var before_death: ItemInstance = _grid.get_item(weapon_item.uuid).duplicate(true) as ItemInstance
	before_death.magazine_ammo = 1
	_grid.try_update_items([before_death])
	var death_reload: int = int(_machine.call("begin_reload"))
	_health.apply_damage(100, "fixture")
	check.call(String(_machine.call("get_state_name")) == "idle" and not bool(_machine.call("complete_reload", death_reload)), "death cancels reload callback")
	_health.restore(50, 100)
	var one_round: ItemInstance = _grid.get_item(weapon_item.uuid).duplicate(true) as ItemInstance
	one_round.magazine_ammo = 1
	_grid.try_update_items([one_round])
	_pouch.consume_ammo("pistol", 3)
	check.call(int(_machine.call("begin_reload")) == 0, "empty reserve rejects reload without changing the magazine")
	_pouch.add_ammo("pistol", 3)
	var pause_reload: int = int(_machine.call("begin_reload"))
	_player.can_act = false
	_player.control_lock_changed.emit(true)
	check.call(pause_reload > 0 and String(_machine.call("get_state_name")) == "idle" and not bool(_machine.call("complete_reload", pause_reload)), "pause or transition control lock cancels reload callback")
	_player.can_act = true
	_player.control_lock_changed.emit(false)
	_health.apply_damage(30, "fixture")
	var heal_token: int = int(_machine.call("begin_heal", Vector2i(1, 0)))
	check.call(heal_token > 0 and bool(_machine.call("complete_heal", heal_token)) and _health.current_hp == 45 and _grid.get_item(med_item.uuid) == null, "one healing callback applies authored heal and consumes one item")
	check.call(not bool(_machine.call("complete_heal", heal_token)) and _health.current_hp == 45, "repeated heal callback cannot heal twice")
	var cancelled_heal_item: ItemInstance = _make_item(med_definition, 4, Vector2i(1, 0), 0)
	_grid.try_add_item(cancelled_heal_item)
	var cancelled_heal: int = int(_machine.call("begin_heal", Vector2i(1, 0)))
	_health.apply_damage(100, "fixture")
	check.call(not bool(_machine.call("complete_heal", cancelled_heal)) and _grid.get_item(cancelled_heal_item.uuid) != null, "death cancels pending heal without consuming its item")
	_health.restore(45, 100)
	var swap_heal_token: int = int(_machine.call("begin_heal", Vector2i(1, 0)))
	_equipment.equip_item(replacement.uuid, "primary")
	check.call(swap_heal_token > 0 and String(_machine.call("get_state_name")) == "idle" and not bool(_machine.call("complete_heal", swap_heal_token)) and _grid.get_item(cancelled_heal_item.uuid) != null, "weapon swap cancels pending heal without consuming its item")
	_equipment.equip_item(weapon_item.uuid, "primary")
	_player.position = Vector3(1.5, 2.0, -3.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(_player)
	await tree.process_frame
	_player_snapshot = PlayerSnapshot.new(_player, _health, _machine)
	var captured: Dictionary = _player_snapshot.capture()
	var prepared: Dictionary = _player_snapshot.prepare(captured)
	check.call(bool(prepared.get("ok", false)), "player checkpoint snapshot validates health and position data")
	var checkpoint_reload: int = int(_machine.call("begin_reload"))
	var definitions: Dictionary = {"txn_pistol": definition, "txn_medkit": med_definition}
	_inventory_snapshot = InventorySnapshot.new(_grid, _pouch, definitions, ItemGrants.new(_grid, definitions))
	var adapters: SnapshotAdapters = SnapshotAdapters.new(
		EntityRegistry.new(), FactionState.new(["transaction_faction"]),
		Callable(self, "_capture_player"), Callable(self, "_prepare_player"), Callable(self, "_commit_player"),
		Callable(self, "_capture_domains"), Callable(self, "_prepare_domains"), Callable(self, "_commit_domains")
	)
	var save_directory: String = "user://weapon_transaction_%d" % OS.get_process_id()
	var save_store: SaveStore = SaveStore.new(save_directory, Callable(adapters, "capture_snapshot"), Callable(adapters, "validate_snapshot"), Callable(adapters, "apply_snapshot"))
	check.call(save_store.save_to_disk(0) == OK, "save store captures the checkpoint while reload is pending")
	check.call(bool(_machine.call("complete_reload", checkpoint_reload)), "in-flight reload can finish after an independent save capture")
	var post_reload: ItemInstance = _grid.get_item(weapon_item.uuid).duplicate(true) as ItemInstance
	post_reload.magazine_ammo = 1
	_grid.try_update_items([post_reload])
	_pouch.add_ammo("pistol", 3)
	var stale_reload: int = int(_machine.call("begin_reload"))
	_player.position = Vector3.ZERO
	_health.apply_damage(20, "fixture")
	check.call(checkpoint_reload > 0 and stale_reload > 0 and save_store.load_from_disk(0) == OK, "load restores a save made mid-reload and cancels the current action")
	var restored_item: ItemInstance = _grid.get_item(weapon_item.uuid)
	check.call(restored_item != null and restored_item.magazine_ammo == 1 and restored_item.rolled_stats.get("damage") == 24.0 and _pouch.get_ammo("pistol") == 3, "load restores pre-reload magazine, rolled stats and family reserve")
	check.call(_player.position.is_equal_approx(Vector3(1.5, 2.0, -3.0)) and _health.current_hp == 45 and String(_machine.call("get_state_name")) == "idle" and not bool(_machine.call("complete_reload", stale_reload)) and not bool(_machine.call("complete_reload", checkpoint_reload)), "checkpoint restore rejects both stale reload callbacks")
	var invalid_snapshot: Dictionary = _player_snapshot.prepare({"health": 200, "max_health": 100, "position": [0.0, 0.0, 0.0]})
	check.call(not invalid_snapshot.get("ok", false), "invalid checkpoint cannot partially alter player state")
	_cleanup_save(save_directory)
	_player.get_parent().remove_child(_player)
	_player.free()
	_machine.free()
	_weapon.free()


func _make_item(definition: ItemDefinition, serial: int, cell: Vector2i, magazine: int) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-%012d" % serial
	item.item_id = definition.item_id
	item.grid_position = cell
	item.dimensions = definition.dimensions
	item.rarity_tier = &"common"
	item.magazine_ammo = magazine
	return item


func _capture_player() -> Dictionary:
	return _player_snapshot.capture()


func _prepare_player(candidate: Dictionary) -> Dictionary:
	return _player_snapshot.prepare(candidate)


func _commit_player(prepared: Dictionary) -> void:
	_player_snapshot.commit_prepared(prepared)


func _capture_domains() -> Dictionary:
	return {"inventory": _inventory_snapshot.capture_snapshot()}


func _prepare_domains(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 1 or not candidate.has("inventory"):
		return {"ok": false, "prepared": {}}
	var prepared: Dictionary = _inventory_snapshot.prepare_snapshot(candidate["inventory"])
	return {"ok": bool(prepared.get("ok", false)), "prepared": {"inventory": prepared.get("prepared", {})}}


func _commit_domains(prepared: Dictionary) -> void:
	_inventory_snapshot.commit_prepared_snapshot(prepared["inventory"])


func _cleanup_save(directory: String) -> void:
	var path: String = "%s/slot_00.save" % directory
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
