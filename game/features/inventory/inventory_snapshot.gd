extends RefCounted
class_name InventorySnapshot
## Data-only inventory participant for the CORE-04 domain snapshot callbacks.

const SNAPSHOT_VERSION: int = 1

var inventory: GridInventory
var ammo_pouch: AmmoPouch
var definitions: Dictionary = {}
var item_grants: ItemGrants


func _init(grid: GridInventory = null, reserves: AmmoPouch = null, item_definitions: Dictionary = {}, grants: ItemGrants = null) -> void:
	inventory = grid
	ammo_pouch = reserves
	definitions = item_definitions.duplicate()
	item_grants = grants


func capture_snapshot() -> Dictionary:
	if inventory == null or ammo_pouch == null or item_grants == null:
		return {}
	var item_rows: Array[Dictionary] = []
	for item: ItemInstance in inventory.get_items():
		if not _item_matches_definition(item):
			return {}
		item_rows.append(item.to_data())
	item_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["uuid"]) < String(right["uuid"]))
	var result: Dictionary = {
		"version": SNAPSHOT_VERSION,
		"grid_size": [inventory.grid_size.x, inventory.grid_size.y],
		"items": item_rows,
		"reserves": ammo_pouch.get_reserves(),
		"grants": item_grants.capture_snapshot(),
	}
	return result if bool(prepare_snapshot(result).get("ok", false)) else {}


func validate_snapshot(candidate: Variant) -> bool:
	return bool(prepare_snapshot(candidate).get("ok", false))


## The returned prepared value contains serializable data only and mutates no live owner.
func prepare_snapshot(candidate: Variant) -> Dictionary:
	if inventory == null or ammo_pouch == null or item_grants == null:
		return {"ok": false}
	if typeof(candidate) != TYPE_DICTIONARY or candidate.size() != 5:
		return {"ok": false}
	if typeof(candidate.get("version")) != TYPE_INT or candidate["version"] != SNAPSHOT_VERSION:
		return {"ok": false}
	var saved_size: Variant = candidate.get("grid_size")
	if typeof(saved_size) != TYPE_ARRAY or saved_size.size() != 2 or typeof(saved_size[0]) != TYPE_INT or typeof(saved_size[1]) != TYPE_INT:
		return {"ok": false}
	if Vector2i(saved_size[0], saved_size[1]) != inventory.grid_size:
		return {"ok": false}
	if typeof(candidate.get("items")) != TYPE_ARRAY or candidate["items"].size() > GridInventory.MAX_ITEMS:
		return {"ok": false}
	var items: Array[ItemInstance] = []
	var seen_uuids: Dictionary = {}
	var equipped_slots: Dictionary = {}
	for row: Variant in candidate["items"]:
		var item: ItemInstance = _item_from_data(row)
		if item == null or seen_uuids.has(item.uuid) or not _valid_equipment_state(item, equipped_slots):
			return {"ok": false}
		seen_uuids[item.uuid] = true
		items.append(item)
	var grid_result: Dictionary = inventory.prepare_replacement(items)
	if not grid_result.get("ok", false):
		return {"ok": false}
	var ammo_result: Dictionary = ammo_pouch.prepare_replacement(candidate.get("reserves"))
	if not ammo_result.get("ok", false):
		return {"ok": false}
	var grants_result: Dictionary = item_grants.prepare_snapshot(candidate.get("grants"))
	if not grants_result.get("ok", false):
		return {"ok": false}
	var pending: Dictionary = grants_result["prepared"]["pending"]
	for item_data: Dictionary in pending.values():
		if seen_uuids.has(String(item_data.get("uuid", ""))):
			return {"ok": false}
	return {
		"ok": true,
		"prepared": {
			"grid": grid_result["prepared"],
			"reserves": ammo_result["prepared"],
			"grants": grants_result["prepared"],
		},
	}


## CORE-04 calls this only after every participant has prepared successfully; commits are silent.
func commit_prepared_snapshot(prepared: Dictionary) -> void:
	inventory.commit_prepared_replacement(prepared["grid"])
	ammo_pouch.commit_prepared_replacement(prepared["reserves"])
	item_grants.commit_prepared_snapshot(prepared["grants"])


func _item_from_data(row: Variant) -> ItemInstance:
	if typeof(row) != TYPE_DICTIONARY:
		return null
	var item: ItemInstance = ItemInstance.new()
	if not item.load_data(row):
		return null
	return item if _item_matches_definition(item) else null


func _item_matches_definition(item: ItemInstance) -> bool:
	var candidate: Variant = definitions.get(String(item.item_id), definitions.get(item.item_id))
	if not candidate is ItemDefinition:
		return false
	var definition: ItemDefinition = candidate as ItemDefinition
	return definition.is_valid() and item.is_valid(definition)


func _valid_equipment_state(item: ItemInstance, equipped_slots: Dictionary) -> bool:
	var state: Dictionary = item.equipment_state
	if state.has("equipped") and typeof(state["equipped"]) != TYPE_BOOL:
		return false
	if not bool(state.get("equipped", false)):
		return not state.has("slot")
	var slot: Variant = state.get("slot")
	if typeof(slot) != TYPE_STRING or not ItemDefinition._is_valid_identifier(slot) or equipped_slots.has(slot):
		return false
	equipped_slots[slot] = item.uuid
	return true
