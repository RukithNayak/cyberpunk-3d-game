extends Node3D

var interaction_locks: Dictionary = {}

func add_control_lock(lock_id: StringName) -> void:
	interaction_locks[lock_id] = true

func remove_control_lock(lock_id: StringName) -> void:
	interaction_locks.erase(lock_id)

func is_control_locked() -> bool:
	return not interaction_locks.is_empty()
