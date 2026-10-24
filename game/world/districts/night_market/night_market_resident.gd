extends CharacterBody3D
class_name NightMarketResident
## Lightweight damageable civilian used by the playable Night Market slice.

signal died

const STARTING_HEALTH: int = 60

@export var display_name: String = "Resident"

var health_state: HealthState
var is_alive: bool = true

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _nameplate: Label3D = get_node("Nameplate") as Label3D


func _ready() -> void:
	health_state = HealthState.new(STARTING_HEALTH)
	health_state.health_changed.connect(_on_health_changed)
	health_state.on_death.connect(_on_died)


func apply_damage(amount: int, source_faction: String) -> void:
	if not is_alive or source_faction != "player" or amount <= 0 or health_state == null:
		return
	health_state.apply_damage(amount, source_faction)


func _on_health_changed(current: int, maximum: int) -> void:
	if is_alive and _nameplate != null:
		_nameplate.text = "%s // %d / %d HP" % [_base_name(), current, maximum]


func _on_died() -> void:
	if not is_alive:
		return
	is_alive = false
	_collision_shape.set_deferred("disabled", true)
	_nameplate.text = "%s // DOWN" % _base_name()
	_nameplate.modulate = Color("89979d")
	var interaction_prompt: Label3D = get_node_or_null("InteractionPrompt") as Label3D
	if interaction_prompt != null:
		interaction_prompt.visible = false
	if not _play_character_clip("death"):
		var fall: Tween = create_tween()
		fall.tween_property(_visuals, "rotation:z", deg_to_rad(82.0), 0.32)
		fall.parallel().tween_property(_visuals, "position:y", 0.24, 0.32)
	died.emit()


func _play_character_clip(clip_key: String) -> bool:
	var players: Array[Node] = _visuals.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return false
	var animation_player: AnimationPlayer = players[0] as AnimationPlayer
	for animation_name: StringName in animation_player.get_animation_list():
		if String(animation_name).to_lower().contains(clip_key):
			animation_player.play(animation_name)
			return true
	return false


func _base_name() -> String:
	return display_name
