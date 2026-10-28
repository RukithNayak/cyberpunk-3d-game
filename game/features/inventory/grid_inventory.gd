extends RefCounted
class_name GridInventory
## Data-only grid owner. Runtime world Nodes are accepted only by pickup and never retained.

signal inventory_changed

const MAX_ITEM_DIMENSION: int = ItemDefinition.MAX_DIMENSION
const MAX_ITEMS: int = 1024

var grid_size: Vector2i = Vector2i.ZERO
var _items: Dictionary = {}


func _init(configured_size: Vector2i = Vector2i(10, 6)) -> void:
	if configured_size.x > 0 and configured_size.y > 0:
		grid_size = configured_size


func try_add_item(item: ItemInstance) -> bool:
	if not _can_insert(item, ""):
		return false
	_items[item.uuid] = item.duplicate(true)
	inventory_changed.emit()
	return true


## Movement is all-or-nothing: a rejected target leaves the stored item untouched.
func try_move_item(uuid: String, new_position: Vector2i) -> bool:
	if not _items.has(uuid):
		return false
	var current: ItemInstance = _items[uuid] as ItemInstance
	var candidate: ItemInstance = current.duplicate(true) as ItemInstance
	candidate.grid_position = new_position
	if not _can_insert(candidate, uuid):
		return false
	_items[uuid] = candidate
	inventory_changed.emit()
	return true


## Removal either returns an independent item copy and relinquishes ownership, or changes nothing.
func remove_item(uuid: String) -> ItemInstance:
	if not _items.has(uuid):
		return null
	var removed: ItemInstance = (_items[uuid] as ItemInstance).duplicate(true) as ItemInstance
	_items.erase(uuid)
	inventory_changed.emit()
	return removed


## Pickup commits inventory ownership before queueing the transient world projection for deletion.
## On any failed precondition or insertion, the world drop remains untouched.
func try_pickup_item(item: ItemInstance, world_drop: Node) -> bool:
	if not is_instance_valid(world_drop) or not world_drop.is_inside_tree() or world_drop.is_queued_for_deletion():
		return false
	if not _can_insert(item, ""):
		return false
	_items[item.uuid] = item.duplicate(true)
	world_drop.queue_free()
	inventory_changed.emit()
	return true


## Returns a copy so callers cannot mutate authoritative inventory data by alias.
func get_item(uuid: String) -> ItemInstance:
	if not _items.has(uuid):
		return null
	return (_items[uuid] as ItemInstance).duplicate(true) as ItemInstance


func get_item_count() -> int:
	return _items.size()


## Prepares a complete data-only replacement without changing inventory ownership.
func prepare_replacement(items: Array[ItemInstance]) -> Dictionary:
	if grid_size.x <= 0 or grid_size.y <= 0 or items.size() > MAX_ITEMS:
		return {"ok": false}
	var seen: Dictionary = {}
	var rows: Array[Dictionary] = []
	var candidates: Array[ItemInstance] = []
	for item: ItemInstance in items:
		if item == null or not item.is_valid() or seen.has(item.uuid) or not _is_within_bounds(item):
			return {"ok": false}
		seen[item.uuid] = true
		candidates.append(item)
		rows.append(item.to_data())
	for left_index: int in range(candidates.size()):
		for right_index: int in range(left_index + 1, candidates.size()):
			var left: ItemInstance = candidates[left_index]
			var right: ItemInstance = candidates[right_index]
			if _rectangles_overlap(left.grid_position, left.dimensions, right.grid_position, right.dimensions):
				return {"ok": false}
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["uuid"]) < String(right["uuid"]))
	return {"ok": true, "prepared": {"grid_size": [grid_size.x, grid_size.y], "items": rows}}


## Commits only plans returned by prepare_replacement; hydration intentionally emits no signal.
func commit_prepared_replacement(prepared: Dictionary) -> void:
	var replacement: Dictionary = {}
	for item_data: Dictionary in prepared["items"]:
		var item: ItemInstance = ItemInstance.new()
		assert(item.load_data(item_data))
		replacement[item.uuid] = item
	_items = replacement


## Deferred publication lets multi-owner operations commit before listeners observe a change.
func notify_inventory_changed() -> void:
	inventory_changed.emit()


## Returns an independent copy of the item occupying the requested grid cell.
func get_item_at(cell: Vector2i) -> ItemInstance:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return null
	for stored_uuid: Variant in _items:
		var stored: ItemInstance = _items[stored_uuid] as ItemInstance
		if cell.x >= stored.grid_position.x and cell.x < stored.grid_position.x + stored.dimensions.x \
			and cell.y >= stored.grid_position.y and cell.y < stored.grid_position.y + stored.dimensions.y:
			return stored.duplicate(true) as ItemInstance
	return null


## Returns deep copies of every owned item so services can stage atomic updates.
func get_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for stored: Variant in _items.values():
		result.append((stored as ItemInstance).duplicate(true) as ItemInstance)
	return result


## Replaces existing instances as one transaction. Every candidate is validated against
## the final layout before any authoritative record changes or listeners are notified.
func try_update_items(updates: Array[ItemInstance]) -> bool:
	if updates.is_empty():
		return false
	var staged_by_uuid: Dictionary = {}
	for candidate: ItemInstance in updates:
		if candidate == null or not _items.has(candidate.uuid) or staged_by_uuid.has(candidate.uuid):
			return false
		if not candidate.is_valid() or not _is_within_bounds(candidate):
			return false
		staged_by_uuid[candidate.uuid] = candidate.duplicate(true)

	var final_items: Array[ItemInstance] = []
	for stored_uuid: Variant in _items:
		var item: ItemInstance = staged_by_uuid.get(String(stored_uuid), _items[stored_uuid]) as ItemInstance
		final_items.append(item)
	for left_index: int in range(final_items.size()):
		for right_index: int in range(left_index + 1, final_items.size()):
			var left: ItemInstance = final_items[left_index]
			var right: ItemInstance = final_items[right_index]
			if _rectangles_overlap(left.grid_position, left.dimensions, right.grid_position, right.dimensions):
				return false
	for uuid: Variant in staged_by_uuid:
		_items[uuid] = staged_by_uuid[uuid]
	inventory_changed.emit()
	return true


func _can_insert(item: ItemInstance, ignored_uuid: String) -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0 or item == null or not item.is_valid():
		return false
	if _items.has(item.uuid) and item.uuid != ignored_uuid:
		return false
	if not _is_within_bounds(item):
		return false
	var position: Vector2i = item.grid_position
	var dimensions: Vector2i = item.dimensions
	for stored_uuid: Variant in _items:
		if String(stored_uuid) == ignored_uuid:
			continue
		var stored: ItemInstance = _items[stored_uuid] as ItemInstance
		if _rectangles_overlap(position, dimensions, stored.grid_position, stored.dimensions):
			return false
	return true


func _is_within_bounds(item: ItemInstance) -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return false
	var position: Vector2i = item.grid_position
	var dimensions: Vector2i = item.dimensions
	if position.x < 0 or position.y < 0 or dimensions.x > MAX_ITEM_DIMENSION or dimensions.y > MAX_ITEM_DIMENSION:
		return false
	return position.x <= grid_size.x - dimensions.x and position.y <= grid_size.y - dimensions.y


func _rectangles_overlap(a_position: Vector2i, a_size: Vector2i, b_position: Vector2i, b_size: Vector2i) -> bool:
	return a_position.x < b_position.x + b_size.x and b_position.x < a_position.x + a_size.x \
		and a_position.y < b_position.y + b_size.y and b_position.y < a_position.y + a_size.y
