extends StaticBody3D
class_name HackableImplant
## Transient implant target delegating damage/stun ownership to TacticalAgent.

signal implant_disrupted(target_uuid: String, duration_seconds: float, damage: int)

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var persistent_uuid: String = ""
@export var source_faction_id: String = "player"
@export var owner_agent_path: NodePath = ^".."

var _agent: TacticalAgent
var _uuid_regex: RegEx = RegEx.new()


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func _enter_tree() -> void:
	add_to_group(&"hackable_implant")


func _ready() -> void:
	_agent = get_node_or_null(owner_agent_path) as TacticalAgent
	# Keep the implant ray-queryable while avoiding a second physical body on the guard.
	collision_layer = 2
	collision_mask = 0


func get_persistent_uuid() -> String:
	return persistent_uuid


func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
	return _is_live_node(self) and _is_valid_hack(definition) and _has_valid_identity() \
		and _agent != null and _is_live_node(_agent) and _agent.can_accept_implant_disruption() \
		and is_finite(definition.effect_duration_seconds) and definition.effect_duration_seconds > 0.0 \
		and is_finite(definition.impact_damage) and definition.impact_damage > 0.0 \
		and not source_faction_id.is_empty() and source_faction_id == source_faction_id.strip_edges()


func apply_hack(definition: Resource, operator: Node3D) -> bool:
	if not can_accept_hack(definition, operator):
		return false
	if not _agent.apply_stun(definition.effect_duration_seconds):
		return false
	var damage: int = maxi(1, roundi(definition.impact_damage))
	_agent.apply_damage(damage, source_faction_id, operator)
	implant_disrupted.emit(persistent_uuid, definition.effect_duration_seconds, damage)
	return true


func _is_valid_hack(definition: Resource) -> bool:
	return definition != null and int(definition.get("ability_id")) == HackDefinition.Ability.DISRUPT_IMPLANT


func _has_valid_identity() -> bool:
	return _uuid_regex.search(persistent_uuid) != null


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
