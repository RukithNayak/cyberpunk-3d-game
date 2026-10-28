extends RefCounted
class_name ItemGrants
## Idempotent reward delivery with persisted full-grid entitlements.

signal item_granted(transaction_id: String, item_uuid: String)

const MAX_TRANSACTIONS: int = 1024
const TRANSACTION_ID_PATTERN: String = "^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$"

var inventory: GridInventory
var definitions: Dictionary = {}
var _pending: Dictionary = {}
var _claimed: Dictionary = {}


func _init(grid: GridInventory = null, item_definitions: Dictionary = {}) -> void:
	inventory = grid
	definitions = item_definitions.duplicate()


## Returns true once this transaction's item is owned; false leaves full-grid awards pending.
func grant(transaction_id: String, item: ItemInstance) -> bool:
	if inventory == null or not _is_valid_transaction_id(transaction_id) or not _is_valid_item(item):
		return false
	var item_data: Dictionary = item.to_data()
	if _claimed.has(transaction_id):
		var claimed_record: Dictionary = _claimed[transaction_id]
		return claimed_record["uuid"] == item.uuid and claimed_record["item_id"] == String(item.item_id)
	if _pending.has(transaction_id):
		if _pending[transaction_id] != item_data:
			return false
		return _try_commit_pending(transaction_id)
	if _pending.size() + _claimed.size() >= MAX_TRANSACTIONS:
		return false
	_pending[transaction_id] = item_data.duplicate(true)
	return _try_commit_pending(transaction_id)


func retry_pending(transaction_id: String) -> bool:
	if not _pending.has(transaction_id):
		return false
	return _try_commit_pending(transaction_id)


func retry_pending_grants() -> int:
	var transaction_ids: Array = _pending.keys()
	transaction_ids.sort()
	var granted_count: int = 0
	for transaction_id_variant: Variant in transaction_ids:
		if _try_commit_pending(String(transaction_id_variant)):
			granted_count += 1
	return granted_count


func has_pending(transaction_id: String) -> bool:
	return _pending.has(transaction_id)


func get_pending_count() -> int:
	return _pending.size()


func capture_snapshot() -> Dictionary:
	return {"pending": _sorted_copy(_pending), "claimed": _sorted_copy(_claimed)}


func prepare_snapshot(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY or candidate.size() != 2:
		return {"ok": false}
	if typeof(candidate.get("pending")) != TYPE_DICTIONARY or typeof(candidate.get("claimed")) != TYPE_DICTIONARY:
		return {"ok": false}
	var pending_source: Dictionary = candidate["pending"]
	var claimed_source: Dictionary = candidate["claimed"]
	if pending_source.size() + claimed_source.size() > MAX_TRANSACTIONS:
		return {"ok": false}
	var pending_copy: Dictionary = {}
	var claimed_copy: Dictionary = {}
	var seen_item_uuids: Dictionary = {}
	for transaction_id_variant: Variant in pending_source:
		if typeof(transaction_id_variant) != TYPE_STRING or not _is_valid_transaction_id(String(transaction_id_variant)):
			return {"ok": false}
		var transaction_id: String = String(transaction_id_variant)
		if claimed_source.has(transaction_id):
			return {"ok": false}
		var item_data: Variant = pending_source[transaction_id]
		var pending_item: ItemInstance = _item_from_data(item_data)
		if pending_item == null or seen_item_uuids.has(pending_item.uuid):
			return {"ok": false}
		seen_item_uuids[pending_item.uuid] = true
		pending_copy[transaction_id] = (item_data as Dictionary).duplicate(true)
	for transaction_id_variant: Variant in claimed_source:
		if typeof(transaction_id_variant) != TYPE_STRING or not _is_valid_transaction_id(String(transaction_id_variant)):
			return {"ok": false}
		var transaction_id: String = String(transaction_id_variant)
		var record: Variant = claimed_source[transaction_id]
		if typeof(record) != TYPE_DICTIONARY or record.size() != 2 or typeof(record.get("uuid")) != TYPE_STRING or typeof(record.get("item_id")) != TYPE_STRING:
			return {"ok": false}
		var uuid: String = record["uuid"]
		var item_id: String = record["item_id"]
		if not ItemInstance._is_valid_uuid(uuid) or not ItemDefinition._is_valid_identifier(item_id) or seen_item_uuids.has(uuid):
			return {"ok": false}
		seen_item_uuids[uuid] = true
		claimed_copy[transaction_id] = {"uuid": uuid, "item_id": item_id}
	return {"ok": true, "prepared": {"pending": pending_copy, "claimed": claimed_copy}}


func commit_prepared_snapshot(prepared: Dictionary) -> void:
	_pending = prepared["pending"].duplicate(true)
	_claimed = prepared["claimed"].duplicate(true)


func _try_commit_pending(transaction_id: String) -> bool:
	if inventory == null or not _pending.has(transaction_id):
		return false
	var item: ItemInstance = _item_from_data(_pending[transaction_id])
	if item == null:
		return false
	var replacement_items: Array[ItemInstance] = inventory.get_items()
	replacement_items.append(item)
	var prepared: Dictionary = inventory.prepare_replacement(replacement_items)
	if not prepared.get("ok", false):
		return false
	# Commit both owners before either emits a notification; listeners cannot observe a half grant.
	inventory.commit_prepared_replacement(prepared["prepared"])
	_pending.erase(transaction_id)
	_claimed[transaction_id] = {"uuid": item.uuid, "item_id": String(item.item_id)}
	inventory.notify_inventory_changed()
	item_granted.emit(transaction_id, item.uuid)
	return true


func _is_valid_item(item: ItemInstance) -> bool:
	if item == null:
		return false
	var definition: ItemDefinition = _definition_for(String(item.item_id))
	return definition != null and item.is_valid(definition)


func _item_from_data(item_data: Variant) -> ItemInstance:
	if typeof(item_data) != TYPE_DICTIONARY:
		return null
	var item: ItemInstance = ItemInstance.new()
	if not item.load_data(item_data):
		return null
	if not _is_valid_item(item):
		return null
	return item


func _definition_for(item_id: String) -> ItemDefinition:
	var candidate: Variant = definitions.get(item_id, definitions.get(StringName(item_id)))
	if not candidate is ItemDefinition:
		return null
	var definition: ItemDefinition = candidate as ItemDefinition
	return definition if definition.is_valid() and String(definition.item_id) == item_id else null


func _is_valid_transaction_id(value: String) -> bool:
	var expression: RegEx = RegEx.new()
	if value.to_utf8_buffer().size() > 128 or expression.compile(TRANSACTION_ID_PATTERN) != OK:
		return false
	return expression.search(value) != null


func _sorted_copy(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort()
	for key_variant: Variant in keys:
		var value: Variant = source[key_variant]
		result[key_variant] = value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else value
	return result
