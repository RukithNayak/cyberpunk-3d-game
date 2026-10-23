extends CharacterBody3D
class_name PlayerController

signal fire_requested
signal control_lock_changed(locked: bool)

const INPUT_SETTINGS_SCRIPT: Script = preload("res://features/player/input_settings.gd")
const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 6.0
const CROUCH_SPEED: float = 2.0
const GROUND_ACCELERATION: float = 22.0
const AIR_ACCELERATION: float = 8.0
const JUMP_VELOCITY: float = 4.5
const STANDING_HEIGHT: float = 1.8
const CROUCHED_HEIGHT: float = 1.2
const BODY_RADIUS: float = 0.34
const STANDING_COLLISION_Y: float = STANDING_HEIGHT * 0.5
const DEFAULT_SETTINGS_PATH: String = "user://player_settings.json"

@export_range(60.0, 120.0, 1.0) var camera_fov: float = 90.0
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.002
@export var invert_look: bool = false
@export var capture_mouse_on_start: bool = true

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _body_shape: CollisionShape3D = $CollisionShape3D

var can_act: bool = true
var is_alive: bool = true
var is_crouched: bool = false
var is_mouse_captured: bool = false
var reduced_camera_shake: bool = false
var _focused: bool = true
var _control_locks: Dictionary = {}
var _standing_capsule: CapsuleShape3D
var _settings: PlayerInputSettings
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _jump_buffer_seconds: float = 0.12
var _jump_buffer_timer: float = 0.0
var _jump_was_pressed: bool = false


func _ready() -> void:
	_standing_capsule = _body_shape.shape as CapsuleShape3D
	_settings = INPUT_SETTINGS_SCRIPT.new(DEFAULT_SETTINGS_PATH) as PlayerInputSettings
	if not _settings.load_settings():
		_settings.restore_defaults()
	apply_settings(_settings)
	if capture_mouse_on_start:
		set_mouse_capture_enabled(true)


func _physics_process(delta: float) -> void:
	if can_fire() and Input.is_action_just_pressed("fire"):
		fire_requested.emit()
	var jump_is_pressed: bool = Input.is_action_pressed("jump")
	var jump_edge: bool = Input.is_action_just_pressed("jump") or (jump_is_pressed and not _jump_was_pressed)
	_jump_was_pressed = jump_is_pressed
	if can_act and not is_crouched and jump_edge:
		_jump_buffer_timer = _jump_buffer_seconds
	elif not can_act:
		_jump_buffer_timer = 0.0
	if Input.is_action_just_pressed("crouch") and can_act:
		if is_crouched:
			if can_stand():
				_set_crouched(false)
		else:
			_set_crouched(true)
	if not can_act:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction: Vector3 = (global_transform.basis * local_direction).normalized()
	var speed: float = CROUCH_SPEED if is_crouched else (RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED)
	var acceleration: float = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, world_direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, world_direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _jump_buffer_timer > 0.0 and not is_crouched:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not can_act or not is_mouse_captured or not event is InputEventMouseMotion:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var invert_sign: float = 1.0 if invert_look else -1.0
	rotate_y(-motion.relative.x * mouse_sensitivity)
	_head.rotation.x = clampf(_head.rotation.x + motion.relative.y * mouse_sensitivity * invert_sign, deg_to_rad(-85.0), deg_to_rad(85.0))


func add_control_lock(lock_id: StringName) -> void:
	if String(lock_id).is_empty():
		return
	_control_locks[lock_id] = true
	can_act = false
	set_mouse_capture_enabled(false)
	control_lock_changed.emit(true)


func remove_control_lock(lock_id: StringName) -> void:
	_control_locks.erase(lock_id)
	can_act = _control_locks.is_empty()
	control_lock_changed.emit(not can_act)


func has_control_locks() -> bool:
	return not _control_locks.is_empty()


func can_use_inventory_action() -> bool:
	if not is_alive:
		return false
	for lock_id: Variant in _control_locks:
		if StringName(lock_id) != &"inventory_ui":
			return false
	return true


func can_fire() -> bool:
	return is_alive and can_act and _control_locks.is_empty()


func apply_recoil(degrees: float) -> void:
	if not can_act or not is_finite(degrees):
		return
	var comfort_scale: float = 0.35 if reduced_camera_shake else 1.0
	_head.rotation.x = clampf(_head.rotation.x - deg_to_rad(degrees * comfort_scale), deg_to_rad(-85.0), deg_to_rad(85.0))


func set_reduced_camera_shake(enabled: bool) -> void:
	reduced_camera_shake = enabled


func set_mouse_capture_enabled(enabled: bool) -> void:
	is_mouse_captured = enabled and _focused and _control_locks.is_empty()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE


func resume_mouse_capture() -> bool:
	if not _focused or not _control_locks.is_empty():
		return false
	set_mouse_capture_enabled(true)
	return is_mouse_captured


func simulate_focus_lost() -> void:
	_focused = false
	set_mouse_capture_enabled(false)


func simulate_focus_gained() -> void:
	_focused = true
	set_mouse_capture_enabled(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		simulate_focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		simulate_focus_gained()


func apply_settings(settings: PlayerInputSettings) -> void:
	if settings == null:
		return
	camera_fov = settings.get_fov()
	mouse_sensitivity = settings.get_sensitivity()
	invert_look = settings.get_invert_look()
	if is_instance_valid(_camera):
		_camera.fov = camera_fov


func can_stand() -> bool:
	if not is_crouched:
		return true
	var extra_height: float = STANDING_HEIGHT - CROUCHED_HEIGHT
	var headroom: BoxShape3D = BoxShape3D.new()
	headroom.size = Vector3(BODY_RADIUS * 2.0, extra_height, BODY_RADIUS * 2.0)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = headroom
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (CROUCHED_HEIGHT + extra_height * 0.5))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.01
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_crouched(crouched: bool) -> void:
	if is_crouched == crouched:
		return
	is_crouched = crouched
	var capsule: CapsuleShape3D = _standing_capsule
	if crouched:
		var short_capsule: CapsuleShape3D = capsule.duplicate() as CapsuleShape3D
		short_capsule.height = CROUCHED_HEIGHT
		_body_shape.shape = short_capsule
		_body_shape.position.y = STANDING_COLLISION_Y - (STANDING_HEIGHT - CROUCHED_HEIGHT) * 0.5
		_head.position.y = 1.05
	else:
		_body_shape.shape = capsule
		_body_shape.position.y = STANDING_COLLISION_Y
		_head.position.y = 1.62


func get_settings() -> PlayerInputSettings:
	return _settings
