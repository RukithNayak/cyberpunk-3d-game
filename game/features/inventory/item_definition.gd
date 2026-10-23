extends Resource
class_name ItemDefinition
## Authored item identity and base properties. Rarity is rolled separately.

const MAX_DIMENSION: int = 16
const MAX_MAGAZINE_CAPACITY: int = 128
const MAX_BASE_STATS: int = 32

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var dimensions: Vector2i = Vector2i.ONE
@export var weapon_family: StringName = &""
@export_range(0, MAX_MAGAZINE_CAPACITY, 1) var magazine_capacity: int = 0
@export_range(0, 1000, 1) var consumable_heal_amount: int = 0
@export var base_stats: Dictionary = {}


func is_valid() -> bool:
	if not _is_valid_identifier(String(item_id)):
		return false
	if display_name.strip_edges().is_empty() or display_name.length() > 80:
		return false
	if dimensions.x < 1 or dimensions.y < 1 or dimensions.x > MAX_DIMENSION or dimensions.y > MAX_DIMENSION:
		return false
	if magazine_capacity < 0 or magazine_capacity > MAX_MAGAZINE_CAPACITY:
		return false
	if consumable_heal_amount < 0 or consumable_heal_amount > 1000:
		return false
	if not weapon_family.is_empty() and not _is_valid_identifier(String(weapon_family)):
		return false
	if base_stats.size() > MAX_BASE_STATS:
		return false
	for key: Variant in base_stats:
		if typeof(key) != TYPE_STRING:
			return false
		if not _is_valid_identifier(String(key)):
			return false
		var value: Variant = base_stats[key]
		if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	return true


static func _is_valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value != value.to_lower():
		return false
	var first_code: int = value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index: int in range(1, value.length()):
		var code: int = value.unicode_at(index)
		if (code < 97 or code > 122) and (code < 48 or code > 57) and code != 95:
			return false
	return true
