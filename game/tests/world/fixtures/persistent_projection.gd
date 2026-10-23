extends Node3D
## Small authored projection used by chunk persistence regressions.

var persistent_state: Dictionary = {}
var interactions_enabled: bool = false
var ready_state: Dictionary = {}
var ready_interactions_enabled: bool = false
var invalidation_callback: Callable
var fail_apply: bool = false


func apply_persistent_state(state: Dictionary) -> void:
	if fail_apply:
		return
	persistent_state = state.duplicate(true)
	if invalidation_callback.is_valid():
		invalidation_callback.call()


func set_interaction_enabled(enabled: bool) -> void:
	interactions_enabled = enabled
	if invalidation_callback.is_valid():
		invalidation_callback.call()


func _ready() -> void:
	ready_state = persistent_state.duplicate(true)
	ready_interactions_enabled = interactions_enabled
