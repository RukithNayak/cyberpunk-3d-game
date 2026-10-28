extends Node
class_name WeaponStateMachine
## Coordinates accepted weapon actions while inventory services retain ammo/item ownership.

signal action_state_changed(state_name: String)
signal shot_committed(result: HitResult, weapon_uuid: String)
signal reload_completed(weapon_uuid: String, rounds: int)

enum ActionState { IDLE, FIRING, RELOADING, HEALING }

const WEAPON_STATS_SCRIPT: Script = preload("res://features/combat/weapon_stats.gd")

var _player: Node
var _weapon_controller: WeaponController
var _equipment: EquipmentService
var _consumables: ConsumableService
var _health: HealthState
var _state: ActionState = ActionState.IDLE
var _action_token: int = 0
var _action_item_uuid: String = ""
var _heal_grid_position: Vector2i = Vector2i.ZERO


func configure(player: Node, weapon_controller: WeaponController, equipment: EquipmentService, consumables: ConsumableService, health: HealthState) -> void:
	_disconnect_services()
	_player = player
	_weapon_controller = weapon_controller
	_equipment = equipment
	_consumables = consumables
	_health = health
	if _equipment != null and not _equipment.equipment_changed.is_connected(_on_equipment_changed):
		_equipment.equipment_changed.connect(_on_equipment_changed)
	if _health != null and not _health.on_death.is_connected(cancel_action):
		_health.on_death.connect(cancel_action)
	if _player != null and _player.has_signal("control_lock_changed"):
		var lock_signal: Signal = _player.get("control_lock_changed")
		if not lock_signal.is_connected(_on_control_lock_changed):
			lock_signal.connect(_on_control_lock_changed)
	cancel_action()


func fire_current_weapon() -> HitResult:
	var empty_result: HitResult = HitResult.new()
	if _state != ActionState.IDLE or not _can_commit_action() or _equipment == null or _weapon_controller == null:
		empty_result.rejected_reason = "Action is unavailable"
		return empty_result
	var active: Dictionary = _equipment.get_active_weapon_stats()
	var uuid: String = String(active.get("item_uuid", ""))
	var item: ItemInstance = _equipment.inventory.get_item(uuid) if _equipment.inventory != null else null
	if active.is_empty() or item == null or item.magazine_ammo <= 0:
		empty_result.rejected_reason = "Magazine is empty"
		return empty_result
	var updated: ItemInstance = item.duplicate(true) as ItemInstance
	updated.magazine_ammo -= 1
	if not _equipment.inventory.try_update_items([updated]):
		empty_result.rejected_reason = "Magazine transaction failed"
		return empty_result
	_set_state(ActionState.FIRING)
	var result: HitResult = _weapon_controller.fire_weapon(_stats_from_active(active))
	if not result.fired:
		var current: ItemInstance = _equipment.inventory.get_item(uuid)
		if current != null:
			var refunded: ItemInstance = current.duplicate(true) as ItemInstance
			refunded.magazine_ammo += 1
			_equipment.inventory.try_update_items([refunded])
	_set_state(ActionState.IDLE)
	if result.fired:
		shot_committed.emit(result, uuid)
	return result


func begin_reload() -> int:
	if _state != ActionState.IDLE or not _can_commit_action() or _equipment == null:
		return 0
	var active: Dictionary = _equipment.get_active_weapon_stats()
	var uuid: String = String(active.get("item_uuid", ""))
	var item: ItemInstance = _equipment.inventory.get_item(uuid) if _equipment.inventory != null else null
	var capacity: int = int(active.get("magazine_capacity", 0))
	if item == null or item.magazine_ammo >= capacity or _equipment.ammo_pouch == null or _equipment.ammo_pouch.get_ammo(String(active.get("weapon_family", ""))) <= 0:
		return 0
	_action_token += 1
	_action_item_uuid = uuid
	_set_state(ActionState.RELOADING)
	return _action_token


func complete_reload(token: int) -> bool:
	if not _valid_pending(ActionState.RELOADING, token) or not _can_commit_action() or _active_uuid() != _action_item_uuid:
		return false
	var uuid: String = _action_item_uuid
	var moved: int = _equipment.reload_weapon(uuid)
	_clear_action()
	if moved > 0:
		reload_completed.emit(uuid, moved)
		return true
	return false


func begin_heal(grid_position: Vector2i) -> int:
	if _state != ActionState.IDLE or not _can_commit_action(true) or _consumables == null or _consumables.inventory == null or _health == null or _health.is_dead():
		return 0
	var item: ItemInstance = _consumables.inventory.get_item_at(grid_position)
	if item == null:
		return 0
	_action_token += 1
	_action_item_uuid = item.uuid
	_heal_grid_position = grid_position
	_set_state(ActionState.HEALING)
	return _action_token


func complete_heal(token: int) -> bool:
	if not _valid_pending(ActionState.HEALING, token) or not _can_commit_action(true) or _health == null or _health.is_dead():
		return false
	var item: ItemInstance = _consumables.inventory.get_item_at(_heal_grid_position) if _consumables != null and _consumables.inventory != null else null
	if item == null or item.uuid != _action_item_uuid:
		_clear_action()
		return false
	var hp_before: int = _health.current_hp
	var used: bool = _consumables.use_consumable(Vector2(_heal_grid_position))
	_clear_action()
	return used and _health.current_hp > hp_before


func cancel_action() -> void:
	_action_token += 1
	_action_item_uuid = ""
	_set_state(ActionState.IDLE)


func get_action_token() -> int:
	return _action_token


func get_state_name() -> String:
	return ActionState.keys()[_state].to_lower()


func is_action_pending() -> bool:
	return _state == ActionState.RELOADING or _state == ActionState.HEALING


func is_configured() -> bool:
	return _player != null and _weapon_controller != null and _equipment != null and _consumables != null and _health != null


func set_reduced_camera_shake(enabled: bool) -> bool:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("set_reduced_camera_shake"):
		return false
	_player.call("set_reduced_camera_shake", enabled)
	return true


func _valid_pending(expected: ActionState, token: int) -> bool:
	return token > 0 and token == _action_token and _state == expected and not _action_item_uuid.is_empty()


func _can_commit_action(allow_inventory_lock: bool = false) -> bool:
	if _player == null or not is_instance_valid(_player) or _health != null and _health.is_dead():
		return false
	if allow_inventory_lock and _player.has_method("can_use_inventory_action"):
		return bool(_player.call("can_use_inventory_action"))
	if _player.has_method("can_fire"):
		return bool(_player.call("can_fire"))
	return bool(_player.get("is_alive")) and bool(_player.get("can_act"))


func _active_uuid() -> String:
	return String(_equipment.get_active_weapon_stats().get("item_uuid", "")) if _equipment != null else ""


func _stats_from_active(values: Dictionary) -> WeaponStats:
	var stats: WeaponStats = WEAPON_STATS_SCRIPT.new() as WeaponStats
	stats.damage = maxi(1, int(values.get("damage", 1)))
	stats.fire_rate_per_second = maxf(0.1, float(values.get("fire_rate_per_second", 5.0)))
	stats.range_m = maxf(1.0, float(values.get("range_m", 40.0)))
	stats.spread_degrees = maxf(0.0, float(values.get("spread_degrees", 0.0)))
	stats.recoil_degrees = maxf(0.0, float(values.get("recoil_degrees", 0.0)))
	stats.falloff_start_m = maxf(0.0, float(values.get("falloff_start_m", 20.0)))
	stats.minimum_damage = maxf(0.0, float(values.get("minimum_damage", 12.0)))
	return stats


func _on_equipment_changed(_slot: String, _uuid: String) -> void:
	if is_action_pending() and _active_uuid() != _action_item_uuid:
		cancel_action()


func _on_control_lock_changed(locked: bool) -> void:
	if locked:
		cancel_action()


func _set_state(value: ActionState) -> void:
	if _state == value:
		return
	_state = value
	action_state_changed.emit(get_state_name())


func _clear_action() -> void:
	_action_item_uuid = ""
	_set_state(ActionState.IDLE)


func _disconnect_services() -> void:
	if _equipment != null and _equipment.equipment_changed.is_connected(_on_equipment_changed):
		_equipment.equipment_changed.disconnect(_on_equipment_changed)
	if _health != null and _health.on_death.is_connected(cancel_action):
		_health.on_death.disconnect(cancel_action)
	if _player != null and _player.has_signal("control_lock_changed"):
		var lock_signal: Signal = _player.get("control_lock_changed")
		if lock_signal.is_connected(_on_control_lock_changed):
			lock_signal.disconnect(_on_control_lock_changed)


func _exit_tree() -> void:
	_disconnect_services()
