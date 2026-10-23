extends RefCounted
class_name AmmoPouch
## Data-only reserve ammunition, indexed by weapon family.

const DEFAULT_FAMILY_CAPACITY: int = 999

var family_capacity: int = DEFAULT_FAMILY_CAPACITY
var _reserves: Dictionary = {}


func _init(max_per_family: int = DEFAULT_FAMILY_CAPACITY) -> void:
	if max_per_family > 0:
		family_capacity = max_per_family


func add_ammo(family: String, amount: int) -> bool:
	if not _is_valid_family(family) or amount <= 0:
		return false
	var key: String = family.to_lower()
	var current: int = int(_reserves.get(key, 0))
	if amount > family_capacity - current:
		return false
	_reserves[key] = current + amount
	return true


func consume_ammo(family: String, amount: int) -> bool:
	if not _is_valid_family(family) or amount <= 0:
		return false
	var key: String = family.to_lower()
	var current: int = int(_reserves.get(key, 0))
	if amount > current:
		return false
	var remaining: int = current - amount
	if remaining == 0:
		_reserves.erase(key)
	else:
		_reserves[key] = remaining
	return true


func get_ammo(family: String) -> int:
	if not _is_valid_family(family):
		return 0
	return int(_reserves.get(family.to_lower(), 0))


func get_reserves() -> Dictionary:
	return _reserves.duplicate(true)


func prepare_replacement(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY:
		return {"ok": false}
	var replacement: Dictionary = {}
	for family_variant: Variant in candidate:
		if typeof(family_variant) != TYPE_STRING:
			return {"ok": false}
		var family: String = String(family_variant)
		var amount: Variant = candidate[family_variant]
		if not _is_valid_family(family) or family != family.to_lower() or typeof(amount) != TYPE_INT or amount < 0 or amount > family_capacity:
			return {"ok": false}
		if amount > 0:
			replacement[family] = amount
	return {"ok": true, "prepared": {"reserves": replacement}}


func commit_prepared_replacement(prepared: Dictionary) -> void:
	_reserves = prepared["reserves"].duplicate(true)


func _is_valid_family(family: String) -> bool:
	return ItemDefinition._is_valid_identifier(family.to_lower())
