extends Node3D
class_name NpcPerception
## Runtime-only visual/sound perception. Faction standing remains CORE-02-owned.

signal sound_event_heard(event: Dictionary)

const DEFAULT_SIGHT_RANGE: float = 20.0
const DEFAULT_COLLISION_MASK: int = 1
const DEFAULT_SOUND_EVENT_LIMIT: int = 16
const MAX_SOUND_EVENT_LIMIT: int = 64


class PerceptionData extends RefCounted:
	var has_visual_contact: bool = false
	var seen_position: Vector3 = Vector3.ZERO
	var has_seen_position: bool = false
	var last_known_position: Vector3 = Vector3.ZERO
	var has_last_known_position: bool = false
	var heard_events: Array[Dictionary] = []


var data: PerceptionData = PerceptionData.new()
var sight_range: float = DEFAULT_SIGHT_RANGE
var collision_mask: int = DEFAULT_COLLISION_MASK
var sound_event_limit: int = DEFAULT_SOUND_EVENT_LIMIT

var _faction_rules: FactionRules
var _configured: bool = false


func _enter_tree() -> void:
	add_to_group(&"npc_perception")


func configure(faction_state: FactionState, configured_sight_range: float = DEFAULT_SIGHT_RANGE, configured_collision_mask: int = DEFAULT_COLLISION_MASK, configured_sound_event_limit: int = DEFAULT_SOUND_EVENT_LIMIT) -> bool:
	if _configured or faction_state == null:
		return false
	if not is_finite(configured_sight_range) or configured_sight_range <= 0.0:
		return false
	if configured_collision_mask <= 0 or configured_sound_event_limit < 1 or configured_sound_event_limit > MAX_SOUND_EVENT_LIMIT:
		return false
	var rules: FactionRules = FactionRules.new()
	if not rules.configure(faction_state):
		return false
	sight_range = configured_sight_range
	collision_mask = configured_collision_mask
	sound_event_limit = configured_sound_event_limit
	_faction_rules = rules
	_configured = true
	return true


func update_visual_target(target: Node3D) -> bool:
	data.has_visual_contact = false
	data.seen_position = Vector3.ZERO
	if not _configured or not _is_live_node(target):
		return false
	var target_position: Vector3 = target.global_position
	var distance: float = global_position.distance_to(target_position)
	if not is_finite(distance) or distance > sight_range or not _has_clear_line_of_sight(target, target_position):
		return false
	data.has_visual_contact = true
	data.seen_position = target_position
	data.has_seen_position = true
	data.last_known_position = target_position
	data.has_last_known_position = true
	return true


func notify_sound_event(position: Vector3, radius: float, faction_id: String) -> void:
	if not _configured or not _is_finite_vector(position) or not is_finite(radius) or radius < 0.0 or faction_id.is_empty() or faction_id != faction_id.strip_edges():
		return
	var distance: float = global_position.distance_to(position)
	if not is_finite(distance) or distance > radius:
		return
	var event: Dictionary = {"position": position, "faction_id": faction_id, "distance": distance}
	data.heard_events.append(event)
	while data.heard_events.size() > sound_event_limit:
		data.heard_events.pop_front()
	sound_event_heard.emit(event.duplicate(true))


func evaluate_target_hostility(target_faction: String) -> bool:
	return _faction_rules != null and _faction_rules.evaluate_target_hostility(target_faction)


func evaluate_target_alliance(target_faction: String) -> bool:
	return _faction_rules != null and _faction_rules.evaluate_target_alliance(target_faction)


func _has_clear_line_of_sight(target: Node3D, target_position: Vector3) -> bool:
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, target_position, collision_mask)
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is CollisionObject3D:
			query.exclude.append((ancestor as CollisionObject3D).get_rid())
			break
		ancestor = ancestor.get_parent()
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Variant = hit.get("collider")
	return collider == target or (collider is Node and target.is_ancestor_of(collider as Node))


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
