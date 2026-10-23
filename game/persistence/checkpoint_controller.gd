extends Node
class_name CheckpointController
## Coordinates player death with the existing validated SaveStore snapshot path.

signal checkpoint_saved(slot: int)
signal checkpoint_restored(slot: int)
signal checkpoint_recovered(slot: int, disk_error: Error)
signal checkpoint_failed(slot: int, error: Error)

var _store: SaveStore
var _adapters: SnapshotAdapters
var _health: HealthState
var _active_slot: int = 0
var _recovery_snapshot: Dictionary = {}
var _configured: bool = false
var _busy: bool = false
var _death_restore_pending: bool = false


func configure(store: SaveStore, adapters: SnapshotAdapters, health: HealthState, active_slot: int = 0) -> bool:
	if _configured or store == null or adapters == null or health == null or active_slot < SaveStore.MIN_SLOT or active_slot > SaveStore.MAX_SLOT:
		return false
	var initial_snapshot: Dictionary = adapters.capture_snapshot()
	if initial_snapshot.is_empty() or not adapters.validate_snapshot(initial_snapshot):
		return false
	_store = store
	_adapters = adapters
	_health = health
	_active_slot = active_slot
	_recovery_snapshot = initial_snapshot.duplicate(true)
	_health.on_death.connect(_on_player_death)
	_configured = true
	return true


func save_checkpoint(slot: int = -1) -> Error:
	if not _configured:
		return ERR_UNCONFIGURED
	if _busy:
		return ERR_BUSY
	var resolved_slot: int = _active_slot if slot < 0 else slot
	if resolved_slot < SaveStore.MIN_SLOT or resolved_slot > SaveStore.MAX_SLOT:
		return ERR_INVALID_PARAMETER
	_busy = true
	var save_error: Error = _store.save_to_disk(resolved_slot)
	if save_error == OK:
		var captured: Dictionary = _adapters.capture_snapshot()
		if not captured.is_empty() and _adapters.validate_snapshot(captured):
			_recovery_snapshot = captured.duplicate(true)
			_active_slot = resolved_slot
			checkpoint_saved.emit(resolved_slot)
		else:
			save_error = ERR_INVALID_DATA
	_finish_operation()
	return save_error


func restore_checkpoint(slot: int = -1) -> Error:
	if not _configured:
		return ERR_UNCONFIGURED
	if _busy:
		return ERR_BUSY
	var resolved_slot: int = _active_slot if slot < 0 else slot
	if resolved_slot < SaveStore.MIN_SLOT or resolved_slot > SaveStore.MAX_SLOT:
		return ERR_INVALID_PARAMETER
	_busy = true
	var load_error: Error = _store.load_from_disk(resolved_slot)
	if load_error == OK:
		_active_slot = resolved_slot
		var loaded_snapshot: Dictionary = _adapters.capture_snapshot()
		if not loaded_snapshot.is_empty() and _adapters.validate_snapshot(loaded_snapshot):
			_recovery_snapshot = loaded_snapshot.duplicate(true)
		checkpoint_restored.emit(resolved_slot)
	else:
		var recovered: bool = not _recovery_snapshot.is_empty() \
			and _adapters.validate_snapshot(_recovery_snapshot) \
			and _adapters.apply_snapshot(_recovery_snapshot.duplicate(true))
		if recovered:
			checkpoint_recovered.emit(resolved_slot, load_error)
		else:
			checkpoint_failed.emit(resolved_slot, load_error)
	_finish_operation()
	return load_error


func is_busy() -> bool:
	return _busy


func _exit_tree() -> void:
	if _health == null:
		return
	var death_callback: Callable = Callable(self, "_on_player_death")
	if _health.on_death.is_connected(death_callback):
		_health.on_death.disconnect(death_callback)


func _on_player_death() -> void:
	if not _configured:
		return
	if _busy:
		_death_restore_pending = true
		return
	restore_checkpoint(_active_slot)


func _finish_operation() -> void:
	_busy = false
	if not _death_restore_pending:
		return
	_death_restore_pending = false
	# Run before the current save/load call returns to gameplay control.
	restore_checkpoint(_active_slot)
