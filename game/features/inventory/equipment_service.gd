extends RefCounted
class_name EquipmentService
## Owns equipment-slot state while GridInventory remains the authoritative item owner.

signal equipment_changed(slot: String, item_uuid: String)

var inventory: GridInventory
var definitions: Dictionary = {}
var ammo_pouch: AmmoPouch


func _init(grid: GridInventory = null, item_definitions: Dictionary = {}, reserves: AmmoPouch = null) -> void:
	inventory = grid
	definitions = item_definitions.duplicate()
	ammo_pouch = reserves


func equip_item(uuid: String, slot: String = "primary") -> bool:
	if inventory == null or not _is_valid_slot(slot):
		return false
	var target: ItemInstance = inventory.get_item(uuid)
	if target == null or not _is_weapon(target):
		return false
	var target_state: Dictionary = target.equipment_state.duplicate(true)
	if bool(target_state.get("equipped", false)):
		if String(target_state.get("slot", "")) == slot:
			return true
		return false

	var updates: Array[ItemInstance] = []
	for current: ItemInstance in inventory.get_items():
		if current.uuid == uuid:
			continue
		if not _is_equipped(current):
			continue
		if String(current.equipment_state.get("slot", "")) == slot:
			var unequipped: ItemInstance = current.duplicate(true) as ItemInstance
			unequipped.equipment_state.erase("equipped")
			unequipped.equipment_state.erase("slot")
			updates.append(unequipped)
	target.equipment_state["equipped"] = true
	target.equipment_state["slot"] = slot
	updates.append(target)
	if not inventory.try_update_items(updates):
		return false
	equipment_changed.emit(slot, uuid)
	return true


func unequip_item(uuid: String) -> bool:
	if inventory == null:
		return false
	var item: ItemInstance = inventory.get_item(uuid)
	if item == null or not _is_equipped(item):
		return false
	var slot: String = String(item.equipment_state.get("slot", ""))
	item.equipment_state.erase("equipped")
	item.equipment_state.erase("slot")
	if not inventory.try_update_items([item]):
		return false
	equipment_changed.emit(slot, "")
	return true


## Returns an independent, unequipped item record for the caller to project into the world.
func drop_item(uuid: String) -> ItemInstance:
	if inventory == null:
		return null
	var dropped: ItemInstance = inventory.remove_item(uuid)
	if dropped == null:
		return null
	var slot: String = String(dropped.equipment_state.get("slot", "")) if _is_equipped(dropped) else ""
	dropped.equipment_state.erase("equipped")
	dropped.equipment_state.erase("slot")
	if not slot.is_empty():
		equipment_changed.emit(slot, "")
	return dropped


## Returns the rounds moved from family reserve to the item's magazine.
func reload_weapon(uuid: String) -> int:
	if inventory == null or ammo_pouch == null:
		return 0
	var item: ItemInstance = inventory.get_item(uuid)
	if item == null or not _is_equipped(item):
		return 0
	var definition: ItemDefinition = _definition_for(item)
	if definition == null or definition.weapon_family.is_empty() or definition.magazine_capacity <= item.magazine_ammo:
		return 0
	var family: String = String(definition.weapon_family)
	var available: int = ammo_pouch.get_ammo(family)
	var moved: int = mini(definition.magazine_capacity - item.magazine_ammo, available)
	if moved <= 0:
		return 0
	var updated: ItemInstance = item.duplicate(true) as ItemInstance
	updated.magazine_ammo += moved
	if not ammo_pouch.consume_ammo(family, moved):
		return 0
	if not inventory.try_update_items([updated]):
		ammo_pouch.add_ammo(family, moved)
		return 0
	return moved


func get_active_weapon_stats(slot: String = "primary") -> Dictionary:
	if inventory == null:
		return {}
	for item: ItemInstance in inventory.get_items():
		if not _is_equipped(item) or String(item.equipment_state.get("slot", "")) != slot:
			continue
		var definition: ItemDefinition = _definition_for(item)
		if definition == null or definition.weapon_family.is_empty():
			return {}
		var stats: Dictionary = definition.base_stats.duplicate(true)
		for key: Variant in item.rolled_stats:
			stats[key] = item.rolled_stats[key]
		stats["item_id"] = String(item.item_id)
		stats["item_uuid"] = item.uuid
		stats["weapon_family"] = String(definition.weapon_family)
		stats["magazine_capacity"] = definition.magazine_capacity
		stats["magazine_ammo"] = item.magazine_ammo
		return stats
	return {}


func is_equipped(item: ItemInstance) -> bool:
	return _is_equipped(item)


func _is_equipped(item: ItemInstance) -> bool:
	return item != null and bool(item.equipment_state.get("equipped", false)) and not String(item.equipment_state.get("slot", "")).is_empty()


func _is_weapon(item: ItemInstance) -> bool:
	var definition: ItemDefinition = _definition_for(item)
	return definition != null and not definition.weapon_family.is_empty()


func _definition_for(item: ItemInstance) -> ItemDefinition:
	if item == null:
		return null
	var candidate: Variant = definitions.get(String(item.item_id), definitions.get(item.item_id))
	if not candidate is ItemDefinition or not (candidate as ItemDefinition).is_valid():
		return null
	var definition: ItemDefinition = candidate as ItemDefinition
	if not item.is_valid(definition):
		return null
	return definition


func _is_valid_slot(slot: String) -> bool:
	return ItemDefinition._is_valid_identifier(slot)
