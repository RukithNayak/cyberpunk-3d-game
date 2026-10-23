extends StaticBody3D
class_name HackableDistraction
## One-shot sound source that notifies nearby AI perception components.

signal distraction_triggered(target_uuid: String, world_position: Vector3, radius: float)

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var persistent_uuid: String = ""
@export var source_faction_id: String = "player"
@export_range(0.5, 50.0, 0.5) var sound_radius: float = 12.0

var _uuid_regex: RegEx = RegEx.new()


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func _enter_tree() -> void:
	add_to_group(&"hackable_distraction")


func _ready() -> void:
	# Sound emitters are targets, not solid obstacles for guards or the player.
	collision_layer = 2
	collision_mask = 0


func get_persistent_uuid() -> String:
	return persistent_uuid


func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
	return _is_live_node(self) and _is_valid_hack(definition) and _has_valid_identity() \
		and is_finite(sound_radius) and sound_radius > 0.0 \
		and not source_faction_id.is_empty() and source_faction_id == source_faction_id.strip_edges()


func apply_hack(definition: Resource, operator: Node3D) -> bool:
	if not can_accept_hack(definition, operator):
		return false
	var world_position: Vector3 = global_position
	for perception: Node in get_tree().get_nodes_in_group(&"npc_perception"):
		if perception.has_method("notify_sound_event"):
			perception.call("notify_sound_event", world_position, sound_radius, source_faction_id)
	distraction_triggered.emit(persistent_uuid, world_position, sound_radius)
	return true


func _is_valid_hack(definition: Resource) -> bool:
	return definition != null and int(definition.get("ability_id")) == HackDefinition.Ability.TRIGGER_DISTRACTION


func _has_valid_identity() -> bool:
	return _uuid_regex.search(persistent_uuid) != null


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
