extends Resource
class_name LootTable
## Configurable weighted item/rarity rolls; generated instance IDs are independent of roll seeds.

const MAX_DEFINITIONS: int = 256
const MAX_RARITY_TIERS: int = 16
const MAX_ENTRY_WEIGHT: int = 1_000_000
const MAX_STAT_MULTIPLIER: float = 8.0

@export var definitions: Array[ItemDefinition] = []
@export var definition_weights: PackedInt32Array = PackedInt32Array()
@export var rarity_tiers: PackedStringArray = PackedStringArray()
@export var rarity_weights: PackedInt32Array = PackedInt32Array()
@export var rarity_stat_multipliers: Dictionary = {}


func is_valid() -> bool:
	if definitions.is_empty() or definitions.size() > MAX_DEFINITIONS or definition_weights.size() != definitions.size():
		return false
	if rarity_tiers.is_empty() or rarity_tiers.size() > MAX_RARITY_TIERS or rarity_weights.size() != rarity_tiers.size():
		return false
	var seen_items: Dictionary = {}
	for index: int in range(definitions.size()):
		var definition: ItemDefinition = definitions[index]
		var weight: int = definition_weights[index]
		if definition == null or not definition.is_valid() or weight <= 0 or weight > MAX_ENTRY_WEIGHT:
			return false
		if seen_items.has(definition.item_id):
			return false
		seen_items[definition.item_id] = true
	var seen_rarities: Dictionary = {}
	for index: int in range(rarity_tiers.size()):
		var tier: String = rarity_tiers[index]
		var weight: int = rarity_weights[index]
		if not ItemDefinition._is_valid_identifier(tier) or weight <= 0 or weight > MAX_ENTRY_WEIGHT:
			return false
		if seen_rarities.has(tier) or not rarity_stat_multipliers.has(tier):
			return false
		var bounds: Variant = rarity_stat_multipliers[tier]
		if typeof(bounds) != TYPE_VECTOR2:
			return false
		var range: Vector2 = bounds
		if not is_finite(range.x) or not is_finite(range.y) or range.x < 0.0 or range.y < range.x or range.y > MAX_STAT_MULTIPLIER:
			return false
		seen_rarities[tier] = true
	return true


func roll_item(seed: int, grid_position: Vector2i = Vector2i.ZERO, magazine_ammo: int = 0) -> ItemInstance:
	if not is_valid() or grid_position.x < 0 or grid_position.y < 0:
		return null
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed
	var definition_index: int = _choose_index(definition_weights, random)
	var rarity_index: int = _choose_index(rarity_weights, random)
	var definition: ItemDefinition = definitions[definition_index]
	if magazine_ammo < 0 or magazine_ammo > definition.magazine_capacity:
		return null
	var rarity_tier: String = rarity_tiers[rarity_index]
	var bounds: Vector2 = rarity_stat_multipliers[rarity_tier]
	var stat_keys: Array[String] = []
	for key: Variant in definition.base_stats:
		stat_keys.append(String(key))
	stat_keys.sort()
	var stats: Dictionary = {}
	for key: String in stat_keys:
		var base_value: Variant = definition.base_stats[key]
		var multiplier: float = random.randf_range(bounds.x, bounds.y)
		var rolled_value: float = float(base_value) * multiplier
		stats[key] = roundi(rolled_value) if typeof(base_value) == TYPE_INT else rolled_value
	var instance: ItemInstance = ItemInstance.new()
	instance.uuid = instance.generate_uuid()
	instance.item_id = definition.item_id
	instance.grid_position = grid_position
	instance.dimensions = definition.dimensions
	instance.rarity_tier = StringName(rarity_tier)
	instance.rolled_stats = stats
	instance.magazine_ammo = magazine_ammo
	if not instance.is_valid(definition):
		return null
	return instance


func _choose_index(weights: PackedInt32Array, random: RandomNumberGenerator) -> int:
	var total_weight: int = 0
	for weight: int in weights:
		total_weight += weight
	var choice: int = random.randi_range(1, total_weight)
	for index: int in range(weights.size()):
		choice -= weights[index]
		if choice <= 0:
			return index
	return weights.size() - 1
