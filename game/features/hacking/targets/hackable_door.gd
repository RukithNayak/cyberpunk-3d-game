extends StaticBody3D
class_name HackableDoor
## Authored door projection. EntityHydrator owns its durable state by UUID.

signal door_state_changed(state: Dictionary)

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var persistent_uuid: String = ""
@export var mission_critical: bool = false
@export var collision_shape_path: NodePath = ^"CollisionShape3D"

var locked: bool = true
var open: bool = false
var interactions_enabled: bool = false

var _hydrator: EntityHydrator
var _lifecycle_generation: int = -1
var _uuid_regex: RegEx = RegEx.new()
var _collision_shape: CollisionShape3D


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func _enter_tree() -> void:
	add_to_group(&"hackable_door")


func _ready() -> void:
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	if _collision_shape == null:
		push_error("HackableDoor requires a CollisionShape3D at collision_shape_path")
		return
	_collision_shape.disabled = open


func configure_lifecycle(hydrator: EntityHydrator, generation: int) -> bool:
	if _hydrator != null or hydrator == null or generation < 0 or _uuid_regex.search(persistent_uuid) == null:
		return false
	_hydrator = hydrator
	_lifecycle_generation = generation
	return true


func get_persistent_uuid() -> String:
	return persistent_uuid


func apply_persistent_state(state: Dictionary) -> void:
	if typeof(state.get("locked")) != TYPE_BOOL or typeof(state.get("open")) != TYPE_BOOL:
		return
	var next_locked: bool = state["locked"]
	var next_open: bool = state["open"]
	if next_locked and next_open:
		return
	locked = next_locked
	open = next_open
	_update_collision()


func set_interaction_enabled(enabled: bool) -> void:
	interactions_enabled = enabled


func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
	return _is_valid_hack(definition) and interactions_enabled and locked and not mission_critical and _is_live()


func apply_hack(definition: Resource, _operator: Node3D) -> bool:
	if not can_accept_hack(definition, _operator) or _hydrator == null:
		return false
	if not _hydrator.commit_entity_delta(persistent_uuid, {"locked": false, "open": true}, _lifecycle_generation):
		return false
	door_state_changed.emit({"uuid": persistent_uuid, "locked": locked, "open": open})
	return not locked and open


func _is_valid_hack(definition: Resource) -> bool:
	return definition != null and int(definition.get("ability_id")) == HackDefinition.Ability.UNLOCK_DOOR


func _is_live() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _uuid_regex.search(persistent_uuid) != null


func _update_collision() -> void:
	if _collision_shape == null:
		_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", open)
