extends RefCounted


func run(check: Callable) -> void:
	var equipment_script: Script = load("res://features/inventory/equipment_service.gd") as Script
	var ammo_script: Script = load("res://features/inventory/ammo_pouch.gd") as Script
	var consumable_script: Script = load("res://features/inventory/consumable_service.gd") as Script
	check.call(equipment_script != null, "equipment service is available")
	check.call(ammo_script != null, "family ammo pouch is available")
	check.call(consumable_script != null, "consumable service is available")
	if equipment_script == null or ammo_script == null or consumable_script == null:
		return

	var pistol: ItemDefinition = _definition("test_pistol", &"pistol", 10, 0, {"damage": 20.0, "fire_rate": 4.0})
	var rifle: ItemDefinition = _definition("test_rifle", &"rifle", 5, 0, {"damage": 35.0, "fire_rate": 2.0})
	var medkit: ItemDefinition = _definition("test_medkit", &"", 0, 25, {})
	var definitions: Dictionary = {"test_pistol": pistol, "test_rifle": rifle, "test_medkit": medkit}
	var grid_script: Script = load("res://features/inventory/grid_inventory.gd") as Script
	var grid: RefCounted = grid_script.new(Vector2i(8, 4)) as RefCounted
	var pistol_item: ItemInstance = _item(pistol, 1, Vector2i(0, 0), 4, {"damage": 24.0})
	var rifle_item: ItemInstance = _item(rifle, 2, Vector2i(2, 0), 3)
	check.call(bool(grid.call("try_add_item", pistol_item)) and bool(grid.call("try_add_item", rifle_item)), "weapon instances enter inventory")
	var pouch: RefCounted = ammo_script.new(100) as RefCounted
	check.call(bool(pouch.call("add_ammo", "pistol", 10)), "reserve ammo is added by family")
	check.call(not bool(pouch.call("consume_ammo", "pistol", 0)) and not bool(pouch.call("consume_ammo", "pistol", -1)), "zero and negative ammo consumption are rejected")
	check.call(not bool(pouch.call("consume_ammo", "pistol", 11)) and int(pouch.call("get_ammo", "pistol")) == 10, "insufficient ammo leaves family reserve unchanged")
	check.call(not bool(pouch.call("consume_ammo", "rifle", 1)), "wrong family cannot consume pistol reserve")
	check.call(bool(pouch.call("consume_ammo", "pistol", 3)) and int(pouch.call("get_ammo", "pistol")) == 7, "valid family ammo consumption commits")
	check.call(not bool(pouch.call("add_ammo", "pistol", 101)) and int(pouch.call("get_ammo", "pistol")) == 7, "reserve capacity rejects overflow atomically")

	var equipment: RefCounted = equipment_script.new(grid, definitions, pouch) as RefCounted
	check.call(bool(equipment.call("equip_item", pistol_item.uuid, "primary")), "weapon can be equipped into primary slot")
	var active_stats: Dictionary = equipment.call("get_active_weapon_stats") as Dictionary
	check.call(active_stats.get("damage") == 24.0 and active_stats.get("weapon_family") == "pistol", "active stats combine item rolls and weapon family")
	check.call(bool(equipment.call("equip_item", rifle_item.uuid, "primary")), "equipping another weapon swaps the slot")
	var stored_pistol: ItemInstance = grid.call("get_item", pistol_item.uuid) as ItemInstance
	var stored_rifle: ItemInstance = grid.call("get_item", rifle_item.uuid) as ItemInstance
	check.call(stored_pistol != null and not bool(equipment.call("is_equipped", stored_pistol)), "swapped weapon is no longer equipped")
	check.call(stored_rifle != null and bool(equipment.call("is_equipped", stored_rifle)), "new weapon is the sole equipped instance")
	check.call(not bool(equipment.call("equip_item", rifle_item.uuid, "secondary")), "one item cannot be equipped in duplicate slots")
	check.call(int(equipment.call("reload_weapon", rifle_item.uuid)) == 0 and int(pouch.call("get_ammo", "pistol")) == 7, "wrong-family reserve cannot reload a rifle")

	check.call(bool(pouch.call("add_ammo", "rifle", 10)), "rifle reserve is independent from pistol reserve")
	check.call(int(equipment.call("reload_weapon", rifle_item.uuid)) == 2, "reload transfers only the magazine's remaining capacity")
	stored_rifle = grid.call("get_item", rifle_item.uuid) as ItemInstance
	check.call(int(pouch.call("get_ammo", "rifle")) == 8 and stored_rifle.magazine_ammo == 5, "reload commits magazine and reserve transfer together")
	check.call(int(equipment.call("reload_weapon", rifle_item.uuid)) == 0 and int(pouch.call("get_ammo", "rifle")) == 8, "full magazine does not consume reserve")
	var dropped: ItemInstance = equipment.call("drop_item", rifle_item.uuid) as ItemInstance
	check.call(dropped != null and not bool(equipment.call("is_equipped", dropped)), "dropping an equipped weapon clears equipment state")
	check.call(grid.call("get_item", rifle_item.uuid) == null, "dropped item leaves inventory ownership")

	var health: RefCounted = HealthState.new(100)
	health.call("apply_damage", 50, "test")
	var medkit_item: ItemInstance = _item(medkit, 3, Vector2i(4, 0))
	check.call(bool(grid.call("try_add_item", medkit_item)), "medkit enters inventory")
	var consumables: RefCounted = consumable_script.new(grid, definitions, health) as RefCounted
	var nested_use_results: Array[bool] = []
	var nested_use_callback: Callable = func(_current: int, _maximum: int) -> void: nested_use_results.append(bool(consumables.call("use_consumable", Vector2(4.0, 0.0))))
	health.connect("health_changed", nested_use_callback)
	check.call(bool(consumables.call("use_consumable", Vector2(4.0, 0.0))), "valid medkit use heals and consumes once")
	check.call(health.get("current_hp") == 75 and grid.call("get_item", medkit_item.uuid) == null, "successful healing commits the health effect and item removal")
	check.call(nested_use_results.size() == 1 and not nested_use_results[0], "reentrant double-use callback is rejected")
	health.disconnect("health_changed", nested_use_callback)
	check.call(not bool(consumables.call("use_consumable", Vector2(4.0, 0.0))), "consumed item cannot be reused")

	var full_hp_item: ItemInstance = _item(medkit, 4, Vector2i(6, 0))
	check.call(bool(grid.call("try_add_item", full_hp_item)), "second medkit enters inventory")
	health.call("heal", 25)
	check.call(not bool(consumables.call("use_consumable", Vector2(6.0, 0.0))), "full-health use is rejected")
	check.call(grid.call("get_item", full_hp_item.uuid) != null, "full-health rejection preserves medkit")
	var dead_hp_item: ItemInstance = _item(medkit, 5, Vector2i(7, 0))
	check.call(bool(grid.call("try_add_item", dead_hp_item)), "third medkit enters inventory")
	health.call("apply_damage", 100, "test")
	check.call(not bool(consumables.call("use_consumable", Vector2(7.0, 0.0))), "dead-player healing is rejected")
	check.call(grid.call("get_item", dead_hp_item.uuid) != null, "dead-player rejection preserves medkit")
	check.call(not bool(consumables.call("use_consumable", Vector2(6.5, 0.0))), "fractional grid coordinates are rejected")


func _definition(item_id: String, family: StringName, magazine_capacity: int, heal_amount: int, stats: Dictionary) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.item_id = StringName(item_id)
	definition.display_name = item_id.capitalize()
	definition.dimensions = Vector2i.ONE
	definition.weapon_family = family
	definition.magazine_capacity = magazine_capacity
	definition.set("consumable_heal_amount", heal_amount)
	definition.base_stats = stats
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
