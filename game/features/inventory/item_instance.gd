extends Resource
class_name ItemInstance
## Runtime-owned item data; serialized values contain no engine Nodes or resources.

const FORMAT_VERSION: int = 1
const MAX_ROLLED_STATS: int = 32
const MAX_EQUIPMENT_STATE_DEPTH: int = 8
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var uuid: String = ""
@export var item_id: StringName = &""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var dimensions: Vector2i = Vector2i.ONE
@export var rarity_tier: StringName = &"common"
@export var rolled_stats: Dictionary = {}
@export var magazine_ammo: int = 0
@export var equipment_state: Dictionary = {}


func is_valid(definition: ItemDefinition = null) -> bool:
	if not _is_valid_uuid(uuid) or not ItemDefinition._is_valid_identifier(String(item_id)):
		return false
	if grid_position.x < 0 or grid_position.y < 0:
		return false
	if dimensions.x < 1 or dimensions.y < 1 or dimensions.x > ItemDefinition.MAX_DIMENSION or dimensions.y > ItemDefinition.MAX_DIMENSION:
		return false
	if not ItemDefinition._is_valid_identifier(String(rarity_tier)):
		return false
	if magazine_ammo < 0 or magazine_ammo > ItemDefinition.MAX_MAGAZINE_CAPACITY:
		return false
	if rolled_stats.size() > MAX_ROLLED_STATS:
		return false
	for key: Variant in rolled_stats:
		if typeof(key) != TYPE_STRING or not ItemDefinition._is_valid_identifier(String(key)):
			return false
		var value: Variant = rolled_stats[key]
		if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	if not _is_safe_value(equipment_state, 0):
		return false
	if definition != null:
		if not definition.is_valid() or item_id != definition.item_id or dimensions != definition.dimensions:
			return false
		if magazine_ammo > definition.magazine_capacity:
			return false
	return true


func generate_uuid() -> String:
	var crypto: Crypto = Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex_digits: String = "0123456789abcdef"
	var compact: String = ""
	for byte_value: int in bytes:
		compact += hex_digits.substr(byte_value >> 4, 1)
		compact += hex_digits.substr(byte_value & 0x0f, 1)
	return "%s-%s-%s-%s-%s" % [compact.substr(0, 8), compact.substr(8, 4), compact.substr(12, 4), compact.substr(16, 4), compact.substr(20, 12)]


func to_data() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"uuid": uuid,
		"item_id": String(item_id),
		"grid_position": [grid_position.x, grid_position.y],
		"dimensions": [dimensions.x, dimensions.y],
		"rarity_tier": String(rarity_tier),
		"rolled_stats": rolled_stats.duplicate(true),
		"magazine_ammo": magazine_ammo,
		"equipment_state": equipment_state.duplicate(true),
	}


func load_data(data: Dictionary, definition: ItemDefinition = null) -> bool:
	if not _is_integral_number(data.get("version")) or int(data["version"]) != FORMAT_VERSION:
		return false
	if typeof(data.get("uuid")) != TYPE_STRING or typeof(data.get("item_id")) != TYPE_STRING:
		return false
	if typeof(data.get("rarity_tier")) != TYPE_STRING or not _is_integral_number(data.get("magazine_ammo")):
		return false
	if not data.get("grid_position") is Array or not data.get("dimensions") is Array:
		return false
	var saved_position: Array = data["grid_position"]
	var saved_dimensions: Array = data["dimensions"]
	if saved_position.size() != 2 or saved_dimensions.size() != 2:
		return false
	for value: Variant in saved_position + saved_dimensions:
		if not _is_integral_number(value) or float(value) < 0.0 or float(value) > 2147483647.0:
			return false
	if typeof(data.get("rolled_stats")) != TYPE_DICTIONARY or typeof(data.get("equipment_state")) != TYPE_DICTIONARY:
		return false
	var candidate: ItemInstance = ItemInstance.new()
	candidate.uuid = data["uuid"]
	candidate.item_id = StringName(data["item_id"])
	candidate.grid_position = Vector2i(int(saved_position[0]), int(saved_position[1]))
	candidate.dimensions = Vector2i(int(saved_dimensions[0]), int(saved_dimensions[1]))
	candidate.rarity_tier = StringName(data["rarity_tier"])
	candidate.rolled_stats = (data["rolled_stats"] as Dictionary).duplicate(true)
	candidate.magazine_ammo = int(data["magazine_ammo"])
	candidate.equipment_state = (data["equipment_state"] as Dictionary).duplicate(true)
	if not candidate.is_valid(definition):
		return false
	uuid = candidate.uuid
	item_id = candidate.item_id
	grid_position = candidate.grid_position
	dimensions = candidate.dimensions
	rarity_tier = candidate.rarity_tier
	rolled_stats = candidate.rolled_stats
	magazine_ammo = candidate.magazine_ammo
	equipment_state = candidate.equipment_state
	return true


static func _is_valid_uuid(value: String) -> bool:
	var expression: RegEx = RegEx.new()
	if expression.compile(UUID_PATTERN) != OK:
		return false
	return expression.search(value) != null


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value


static func _is_safe_value(value: Variant, depth: int) -> bool:
	if depth > MAX_EQUIPMENT_STATE_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			return value.length() <= 4096
		TYPE_ARRAY:
			if value.size() > 256:
				return false
			for entry: Variant in value:
				if not _is_safe_value(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 128:
				return false
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or key.length() > 128 or not _is_safe_value(value[key], depth + 1):
					return false
			return true
		_:
			return false
