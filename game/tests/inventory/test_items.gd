extends RefCounted

const DEFINITION_PATH: String = "res://features/inventory/item_definition.gd"
const INSTANCE_PATH: String = "res://features/inventory/item_instance.gd"
const LOOT_PATH: String = "res://features/inventory/loot_table.gd"


func run(check: Callable) -> void:
	var definition_script: Script = load(DEFINITION_PATH) as Script
	var instance_script: Script = load(INSTANCE_PATH) as Script
	var loot_script: Script = load(LOOT_PATH) as Script
	check.call(definition_script != null, "item definition resource is available")
	check.call(instance_script != null, "item instance resource is available")
	check.call(loot_script != null, "loot table resource is available")
	if definition_script == null or instance_script == null or loot_script == null:
		return

	var definition: Resource = definition_script.new() as Resource
	definition.set("item_id", &"street_pistol")
	definition.set("display_name", "Street Pistol")
	definition.set("dimensions", Vector2i(2, 1))
	definition.set("weapon_family", &"pistol")
	definition.set("magazine_capacity", 12)
	definition.set("base_stats", {"damage": 24.0, "fire_rate": 5.0})
	check.call(bool(definition.call("is_valid")), "valid weapon definition is accepted")
	definition.set("dimensions", Vector2i(0, 1))
	check.call(not bool(definition.call("is_valid")), "nonpositive item dimensions are rejected")
	definition.set("dimensions", Vector2i(2, 1))
	var second_definition: Resource = definition_script.new() as Resource
	second_definition.set("item_id", &"street_rifle")
	second_definition.set("display_name", "Street Rifle")
	second_definition.set("dimensions", Vector2i(3, 2))
	second_definition.set("weapon_family", &"rifle")
	second_definition.set("magazine_capacity", 12)
	second_definition.set("base_stats", {"damage": 42.0, "fire_rate": 2.0})

	var loot: Resource = loot_script.new() as Resource
	var item_definitions: Array[ItemDefinition] = [definition as ItemDefinition, second_definition as ItemDefinition]
	loot.set("definitions", item_definitions)
	loot.set("definition_weights", PackedInt32Array([1, 3]))
	loot.set("rarity_tiers", PackedStringArray(["common", "rare"]))
	loot.set("rarity_weights", PackedInt32Array([3, 1]))
	loot.set("rarity_stat_multipliers", {"common": Vector2(0.9, 1.1), "rare": Vector2(1.2, 1.5)})
	check.call(bool(loot.call("is_valid")), "valid weighted loot table is accepted")
	var first: Resource = loot.call("roll_item", 7741, Vector2i(3, 2), 6) as Resource
	var same_seed: Resource = loot.call("roll_item", 7741, Vector2i(3, 2), 6) as Resource
	check.call(first != null and same_seed != null, "valid seeded loot produces item instances")
	if first == null or same_seed == null:
		return
	check.call(first.get("item_id") == same_seed.get("item_id") and ["street_pistol", "street_rifle"].has(String(first.get("item_id"))), "same seed repeats the weighted item definition")
	check.call(first.get("rarity_tier") == same_seed.get("rarity_tier") and first.get("rolled_stats") == same_seed.get("rolled_stats"), "same seed repeats rarity and stat rolls")
	check.call(first.get("uuid") != same_seed.get("uuid"), "each spawned item receives a unique UUID")
	var selected_definition: ItemDefinition = definition as ItemDefinition if first.get("item_id") == &"street_pistol" else second_definition as ItemDefinition
	check.call(bool(first.call("is_valid", selected_definition)), "spawned item has a canonical identity and valid bounded data")
	var tier_bounds: Vector2 = loot.get("rarity_stat_multipliers")[String(first.get("rarity_tier"))]
	var rolled_damage: float = float(first.get("rolled_stats")["damage"])
	var base_damage: float = float(selected_definition.base_stats["damage"])
	check.call(rolled_damage >= base_damage * tier_bounds.x and rolled_damage <= base_damage * tier_bounds.y, "rolled stats stay inside the configured tier bounds")
	var selected_items: Dictionary = {}
	for seed: int in range(24):
		var weighted_item: ItemInstance = loot.call("roll_item", seed) as ItemInstance
		if weighted_item != null:
			selected_items[String(weighted_item.item_id)] = true
	check.call(selected_items.size() == 2, "weighted table can select each configured item definition")
	var alternate_tier: Resource = loot_script.new() as Resource
	var alternate_definitions: Array[ItemDefinition] = [selected_definition]
	alternate_tier.set("definitions", alternate_definitions)
	alternate_tier.set("definition_weights", PackedInt32Array([1]))
	alternate_tier.set("rarity_tiers", PackedStringArray(["legendary"]))
	alternate_tier.set("rarity_weights", PackedInt32Array([1]))
	alternate_tier.set("rarity_stat_multipliers", {"legendary": Vector2(1.6, 1.6)})
	var same_weapon_new_tier: Resource = alternate_tier.call("roll_item", 7741, Vector2i.ZERO, 0) as Resource
	check.call(same_weapon_new_tier != null and same_weapon_new_tier.get("item_id") == first.get("item_id") and same_weapon_new_tier.get("rarity_tier") == &"legendary", "rarity changes do not change the underlying item identity")
	check.call(first.get("dimensions") == selected_definition.dimensions and first.get("grid_position") == Vector2i(3, 2), "spawn copies item dimensions and requested grid position")
	check.call(first.get("magazine_ammo") == 6, "spawn records current magazine ammunition")
	first.set("equipment_state", {"equipped": true, "slot": "primary"})
	var instance: Resource = instance_script.new() as Resource
	var serialized_item: String = JSON.stringify(first.call("to_data"), "", true, true)
	var decoded_item: Variant = JSON.parse_string(serialized_item)
	check.call(typeof(decoded_item) == TYPE_DICTIONARY and bool(instance.call("load_data", decoded_item, selected_definition)), "JSON item instance reloads against its definition")
	check.call(instance.call("to_data") == first.call("to_data"), "UUID, rarity, rolls, magazine and equipment state round-trip without rerolling")
	var runtime_node: Node = Node.new()
	var unsafe_data: Dictionary = first.call("to_data")
	unsafe_data["equipment_state"] = {"runtime_node": runtime_node}
	var unsafe_instance: Resource = instance_script.new() as Resource
	check.call(not bool(unsafe_instance.call("load_data", unsafe_data, selected_definition)), "persistent item data rejects Nodes in equipment state")
	runtime_node.free()
	var invalid_magazine: Resource = loot.call("roll_item", 7741, Vector2i.ZERO, 13) as Resource
	check.call(invalid_magazine == null, "magazine above definition capacity is rejected")
	loot.set("definition_weights", PackedInt32Array([0, 3]))
	check.call(not bool(loot.call("is_valid")), "zero definition weight invalidates the loot table")
	check.call(loot.call("roll_item", 7741, Vector2i.ZERO, 0) == null, "invalid definition weights cannot spawn an item")
	loot.set("definition_weights", PackedInt32Array([1, 3]))
	loot.set("rarity_weights", PackedInt32Array([3, 0]))
	check.call(not bool(loot.call("is_valid")), "zero rarity weight invalidates the loot table")
	check.call(loot.call("roll_item", 7741, Vector2i.ZERO, 0) == null, "invalid loot weights cannot spawn an item")
