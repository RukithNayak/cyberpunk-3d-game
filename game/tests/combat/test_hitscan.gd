extends RefCounted

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const WEAPON_STATS: Script = preload("res://features/combat/weapon_stats.gd")

var _tree: SceneTree
var _check: Callable
var _root: Node3D
var _player: PlayerController
var _weapon: WeaponController
var _target: DamageTarget
var _clock_msec: int = 1000


class DamageTarget extends StaticBody3D:
	var damage_total: int = 0
	var damage_calls: int = 0

	func apply_damage(amount: int, _source_faction: String) -> void:
		damage_total += amount
		damage_calls += 1


func run(check: Callable) -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_check = check
	await _setup_range_target()
	_weapon.default_weapon_stats.recoil_degrees = 1.2
	var hit: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(hit.fired and hit.target_node == _target, "hitscan resolves a camera-aimed target")
	_check.call(_target.damage_calls == 1 and hit.damage_applied == 24, "one accepted shot applies configured damage once")
	_check.call(is_equal_approx(_player.get_node("Head").rotation.x, deg_to_rad(-1.2)), "weapon recoil raises camera by configured amount")
	var cooldown: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(not cooldown.fired and not cooldown.rejected_reason.is_empty(), "fire cadence rejects a shot during cooldown")
	_clock_msec += 250
	_player.add_control_lock(&"pause")
	var paused: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(not paused.fired, "control lock rejects firing")
	_player.remove_control_lock(&"pause")
	_player.add_control_lock(&"transition")
	var transitioning: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(not transitioning.fired, "transition control lock rejects firing")
	_player.remove_control_lock(&"transition")
	_player.is_alive = false
	var dead: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(not dead.fired, "dead actor rejects firing")
	_player.is_alive = true
	await _reset_world()
	await _setup_range_target()
	var range_stats: WeaponStats = _new_stats(4.0)
	var out_of_range: HitResult = _weapon.fire_weapon(range_stats)
	_check.call(out_of_range.fired and out_of_range.target_node == null and _target.damage_calls == 0, "target beyond weapon range receives no damage")
	await _reset_world()
	await _setup_range_target()
	await _add_wall(Vector3(0.18, 1.6, -3.0), Vector3(0.12, 2.0, 0.15))
	var covered: HitResult = _weapon.fire_weapon(_weapon.default_weapon_stats)
	_check.call(covered.fired and covered.target_node != _target and _target.damage_calls == 0, "muzzle obstruction blocks camera-visible target")
	await _reset_world()
	await _setup_range_target()
	var clear_miss_stats: WeaponStats = _new_stats(20.0)
	_player.get_node("Head").rotation.y = deg_to_rad(25.0)
	var disagreement: HitResult = _weapon.fire_weapon(clear_miss_stats)
	_check.call(disagreement.fired and disagreement.target_node == null and _target.damage_calls == 0, "camera and muzzle disagreement does not damage off-aim target")
	await _reset_world()
	await _setup_range_target()
	var seed_a: Vector3 = _weapon._spread_direction(_weapon._camera.global_basis, 0.65)
	_weapon.set_random_seed(22)
	var first: Vector3 = _weapon._spread_direction(_weapon._camera.global_basis, 0.65)
	_weapon.set_random_seed(22)
	var second: Vector3 = _weapon._spread_direction(_weapon._camera.global_basis, 0.65)
	_check.call(seed_a != Vector3.ZERO and first.is_equal_approx(second), "spread is repeatable for a fixed seed")
	await _reset_world()


func _setup_range_target() -> void:
	_root = Node3D.new()
	_tree.root.add_child(_root)
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.capture_mouse_on_start = false
	_root.add_child(_player)
	_player.position = Vector3.ZERO
	_weapon = _player.get_node("WeaponController") as WeaponController
	_weapon.default_weapon_stats = _new_stats(40.0)
	_weapon.set_random_seed(173)
	_weapon.set_clock_for_testing(_read_clock)
	_target = DamageTarget.new()
	_target.name = "Target"
	_target.collision_layer = 1
	_root.add_child(_target)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.8
	shape_node.shape = shape
	_target.add_child(shape_node)
	_target.position = Vector3(0.0, 1.6, -8.0)
	await _tree.physics_frame
	await _tree.physics_frame
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO


func _add_wall(location: Vector3, dimensions: Vector3) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	_root.add_child(wall)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	wall.add_child(collider)
	wall.position = location
	await _tree.physics_frame


func _new_stats(weapon_range: float) -> WeaponStats:
	var stats: WeaponStats = WEAPON_STATS.new() as WeaponStats
	stats.range_m = weapon_range
	stats.spread_degrees = 0.0
	stats.recoil_degrees = 0.0
	return stats


func _read_clock() -> int:
	return _clock_msec


func _reset_world() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
		await _tree.process_frame
	_clock_msec += 1000
