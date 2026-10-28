extends RefCounted
class_name ConsumableService
## Applies authored healing effects and consumes inventory-owned med items once.

var inventory: GridInventory
var definitions: Dictionary = {}
var health_state: HealthState
var _consuming: Dictionary = {}


func _init(grid: GridInventory = null, item_definitions: Dictionary = {}, health: HealthState = null) -> void:
	inventory = grid
	definitions = item_definitions.duplicate()
	health_state = health


func use_consumable(grid_pos: Vector2) -> bool:
	if inventory == null or health_state == null or not _is_integer_cell(grid_pos):
		return false
	if health_state.is_dead() or health_state.current_hp >= health_state.max_hp:
		return false
	var item: ItemInstance = inventory.get_item_at(Vector2i(int(grid_pos.x), int(grid_pos.y)))
	if item == null or _consuming.has(item.uuid):
		return false
	var definition: ItemDefinition = _definition_for(item)
	if definition == null or definition.consumable_heal_amount <= 0:
		return false
	_consuming[item.uuid] = true
	var hp_before: int = health_state.current_hp
	health_state.heal(definition.consumable_heal_amount)
	var healed: bool = health_state.current_hp > hp_before
	if healed:
		inventory.remove_item(item.uuid)
	_consuming.erase(item.uuid)
	return healed


func _is_integer_cell(grid_pos: Vector2) -> bool:
	return is_finite(grid_pos.x) and is_finite(grid_pos.y) and floor(grid_pos.x) == grid_pos.x and floor(grid_pos.y) == grid_pos.y


func _definition_for(item: ItemInstance) -> ItemDefinition:
	var candidate: Variant = definitions.get(String(item.item_id), definitions.get(item.item_id))
	if not candidate is ItemDefinition or not (candidate as ItemDefinition).is_valid():
		return null
	var definition: ItemDefinition = candidate as ItemDefinition
	return definition if item.is_valid(definition) else null
