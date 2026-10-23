extends RefCounted

const GRID_PATH: String = "res://features/inventory/grid_inventory.gd"


func run(check: Callable) -> void:
	var grid_script: Script = load(GRID_PATH) as Script
	check.call(grid_script != null, "configured grid inventory service is available")
	if grid_script == null:
		return
	var grid: RefCounted = grid_script.new(Vector2i(4, 3)) as RefCounted
	var change_events: Array[int] = [0]
	grid.connect("inventory_changed", func() -> void: change_events[0] += 1)
	var edge_item: ItemInstance = _item("edge_item", Vector2i(2, 2), Vector2i(2, 1))
	check.call(bool(grid.call("try_add_item", edge_item)), "multi-cell item fits exactly at the configured lower-right corner")
	check.call(change_events[0] == 1, "successful insertion emits inventory_changed")
	check.call(bool(grid.call("try_add_item", _item("blocker", Vector2i.ZERO))), "another cell can be independently occupied")
	check.call(not bool(grid.call("try_add_item", _item("overlap", Vector2i(3, 2)))), "overlapping insertion is rejected")
	check.call(change_events[0] == 2, "rejected insertion does not emit inventory_changed")
	check.call(not bool(grid.call("try_add_item", _item("negative", Vector2i(-1, 0)))), "negative placement is rejected")
	check.call(not bool(grid.call("try_add_item", _item("outside", Vector2i(4, 0)))), "out-of-bounds placement is rejected")
	var duplicate: ItemInstance = edge_item.duplicate(true) as ItemInstance
	check.call(not bool(grid.call("try_add_item", duplicate)), "duplicate UUID insertion is rejected")
	check.call(not bool(grid.call("try_move_item", edge_item.uuid, Vector2i(3, 2))), "failed out-of-bounds movement is rejected")
	check.call(not bool(grid.call("try_move_item", edge_item.uuid, Vector2i.ZERO)), "movement into an occupied cell is rejected")
	var retained: ItemInstance = grid.call("get_item", edge_item.uuid) as ItemInstance
	check.call(retained != null and retained.grid_position == Vector2i(2, 2), "failed movement preserves the original placement")
	check.call(bool(grid.call("try_move_item", edge_item.uuid, Vector2i(2, 0))), "valid movement commits")
	retained = grid.call("get_item", edge_item.uuid) as ItemInstance
	check.call(retained != null and retained.grid_position == Vector2i(2, 0), "movement updates the stored placement")
	var removed: ItemInstance = grid.call("remove_item", edge_item.uuid) as ItemInstance
	check.call(removed != null and grid.call("get_item", edge_item.uuid) == null, "remove returns the item and clears its grid ownership")
	check.call(grid.call("remove_item", edge_item.uuid) == null, "removing a missing UUID has no effect")

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var full_grid: RefCounted = grid_script.new(Vector2i(1, 1)) as RefCounted
	check.call(bool(full_grid.call("try_add_item", _item("occupant", Vector2i.ZERO))), "one-cell inventory can be filled")
	var full_drop: Node = Node.new()
	tree.root.add_child(full_drop)
	await tree.process_frame
	check.call(not bool(full_grid.call("try_pickup_item", _item("blocked_drop", Vector2i.ZERO), full_drop)), "full inventory rejects pickup")
	check.call(not full_drop.is_queued_for_deletion() and is_instance_valid(full_drop), "failed pickup leaves world loot intact")

	var pickup_grid: RefCounted = grid_script.new(Vector2i(2, 2)) as RefCounted
	var world_drop: Node = Node.new()
	tree.root.add_child(world_drop)
	await tree.process_frame
	var successful_item: ItemInstance = _item("successful_drop", Vector2i.ZERO)
	check.call(successful_item.is_valid(), "pickup test item satisfies item data validation")
	check.call(world_drop.is_inside_tree() and not world_drop.is_queued_for_deletion(), "pickup test world drop is active")
	check.call(bool(pickup_grid.call("try_pickup_item", successful_item, world_drop)), "valid pickup inserts the item")
	check.call(world_drop.is_queued_for_deletion(), "world loot is removed only after successful insertion")
	check.call(pickup_grid.call("get_item", successful_item.uuid) != null, "successful pickup establishes inventory ownership")
	var duplicate_drop: Node = Node.new()
	tree.root.add_child(duplicate_drop)
	await tree.process_frame
	check.call(not bool(pickup_grid.call("try_pickup_item", successful_item, duplicate_drop)), "duplicate pickup is rejected")
	check.call(not duplicate_drop.is_queued_for_deletion(), "duplicate pickup leaves its world drop intact")
	full_drop.free()
	duplicate_drop.free()


func _item(item_id: String, position: Vector2i, dimensions: Vector2i = Vector2i.ONE) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.uuid = "00000000-0000-4000-8000-%012d" % (abs(item_id.hash()) % 999999999999)
	item.item_id = StringName(item_id)
	item.grid_position = position
	item.dimensions = dimensions
	item.rarity_tier = &"common"
	return item
