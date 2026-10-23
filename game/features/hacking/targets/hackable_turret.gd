extends StaticBody3D
class_name HackableTurret
## Temporary allegiance override; persistent faction standings stay CORE-02-owned.

signal allegiance_changed(target_uuid: String, effective_mode: int, hacked: bool)
signal target_destroyed(target_uuid: String)

enum TemporaryOverrideMode { UNCONFIGURED, NEUTRAL, FRIENDLY }
enum EffectiveMode { HOSTILE, NEUTRAL, FRIENDLY, DESTROYED }

const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var persistent_uuid: String = ""
@export var faction_id: String = ""
@export var player_faction_id: String = "player"
@export_enum("Unconfigured", "Neutral", "Friendly") var temporary_override_mode: int = TemporaryOverrideMode.UNCONFIGURED
@export var collision_shape_path: NodePath = ^"CollisionShape3D"

var effect_remaining_seconds: float = 0.0
var override_active: bool = false
var is_destroyed: bool = false

var _faction_rules: FactionRules
var _uuid_regex: RegEx = RegEx.new()
var _collision_shape: CollisionShape3D


func _init() -> void:
	_uuid_regex.compile(UUID_PATTERN)


func _enter_tree() -> void:
	add_to_group(&"hackable_turret")


func _ready() -> void:
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D


func _process(delta: float) -> void:
	if is_destroyed or not is_finite(delta) or delta < 0.0 or effect_remaining_seconds <= 0.0:
		return
	effect_remaining_seconds = maxf(0.0, effect_remaining_seconds - delta)
	if effect_remaining_seconds == 0.0 and override_active and is_inside_tree() and not is_queued_for_deletion():
		override_active = false
		allegiance_changed.emit(persistent_uuid, get_effective_mode(), false)


func configure(faction_state: FactionState) -> bool:
	if _faction_rules != null or faction_state == null or not _has_valid_identity():
		return false
	if faction_id.is_empty() or faction_id != faction_id.strip_edges():
		return false
	if player_faction_id.is_empty() or player_faction_id != player_faction_id.strip_edges():
		return false
	if temporary_override_mode not in [TemporaryOverrideMode.NEUTRAL, TemporaryOverrideMode.FRIENDLY]:
		return false
	var rules: FactionRules = FactionRules.new()
	if not rules.configure(faction_state):
		return false
	_faction_rules = rules
	return true


func get_persistent_uuid() -> String:
	return persistent_uuid


func can_accept_hack(definition: Resource, _operator: Node3D) -> bool:
	return _is_live_node(self) and not is_destroyed and _is_valid_hack(definition) \
		and _faction_rules != null and _has_valid_identity() and not override_active \
		and is_hostile_to_player() and is_finite(definition.effect_duration_seconds) \
		and definition.effect_duration_seconds > 0.0


func apply_hack(definition: Resource, operator: Node3D) -> bool:
	if not can_accept_hack(definition, operator):
		return false
	override_active = true
	effect_remaining_seconds = definition.effect_duration_seconds
	allegiance_changed.emit(persistent_uuid, get_effective_mode(), true)
	return override_active


func is_hostile_to_player() -> bool:
	if is_destroyed or override_active or _faction_rules == null:
		return false
	return _faction_rules.evaluate_target_hostility(faction_id)


func can_target_faction(target_faction_id: String) -> bool:
	if is_destroyed or _faction_rules == null or target_faction_id.is_empty():
		return false
	if override_active:
		if temporary_override_mode == TemporaryOverrideMode.NEUTRAL:
			return false
		if temporary_override_mode == TemporaryOverrideMode.FRIENDLY:
			return _faction_rules.evaluate_target_hostility(target_faction_id)
	return is_hostile_to_player() and target_faction_id == player_faction_id


func get_effective_mode() -> int:
	if is_destroyed:
		return EffectiveMode.DESTROYED
	if override_active:
		return EffectiveMode.NEUTRAL if temporary_override_mode == TemporaryOverrideMode.NEUTRAL else EffectiveMode.FRIENDLY
	return EffectiveMode.HOSTILE if is_hostile_to_player() else EffectiveMode.NEUTRAL


func mark_destroyed() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	override_active = false
	effect_remaining_seconds = 0.0
	if _collision_shape == null:
		_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	target_destroyed.emit(persistent_uuid)


func _is_valid_hack(definition: Resource) -> bool:
	return definition != null and int(definition.get("ability_id")) == HackDefinition.Ability.DISABLE_TURRET


func _has_valid_identity() -> bool:
	return _uuid_regex.search(persistent_uuid) != null


func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
