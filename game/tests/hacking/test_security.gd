extends RefCounted

const CAMERA_PATH: String = "res://features/hacking/targets/hackable_camera.gd"
const TURRET_PATH: String = "res://features/hacking/targets/hackable_turret.gd"
const PLAYER_UUID: String = "123e4567-e89b-42d3-a456-426614174010"
const CAMERA_UUID: String = "123e4567-e89b-42d3-a456-426614174011"
const TURRET_UUID: String = "123e4567-e89b-42d3-a456-426614174012"
const DESTROYED_TURRET_UUID: String = "123e4567-e89b-42d3-a456-426614174013"


func run(check: Callable) -> void:
	var camera_script: Script = load(CAMERA_PATH) as Script
	var turret_script: Script = load(TURRET_PATH) as Script
	check.call(camera_script != null, "HACK-03 security camera target script exists")
	check.call(turret_script != null, "HACK-03 security turret target script exists")
	if camera_script != null:
		await _test_camera_effect(check, camera_script)
	if turret_script != null:
		await _test_turret_effect(check, turret_script)


func _test_camera_effect(check: Callable, camera_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = tree.root
	var operator: Node3D = Node3D.new()
	var camera: StaticBody3D = camera_script.new() as StaticBody3D
	var player: CharacterBody3D = CharacterBody3D.new()
	operator.name = "CameraHackOperator"
	camera.name = "HackableCamera"
	player.name = "CameraObservedPlayer"
	camera.set("persistent_uuid", CAMERA_UUID)
	camera.position = Vector3(0.0, 2.0, 0.0)
	player.position = Vector3(0.0, 1.0, -8.0)
	camera.add_child(_box_shape(Vector3(0.8, 0.8, 0.5)))
	player.add_child(_capsule_shape(0.4, 1.8))
	root.add_child(operator)
	root.add_child(camera)
	root.add_child(player)
	await tree.physics_frame
	check.call(bool(camera.call("can_detect_target", player)), "active camera detects a player in its view cone and line of sight")
	player.position = Vector3(8.0, 1.0, -8.0)
	await tree.physics_frame
	check.call(not bool(camera.call("can_detect_target", player)), "camera rejects targets outside its configured view cone")
	player.position = Vector3(0.0, 1.0, -80.0)
	check.call(not bool(camera.call("can_detect_target", player)), "camera rejects targets beyond its configured detection range")
	player.position = Vector3(0.0, 1.0, -8.0)
	await tree.physics_frame

	var factions: FactionState = FactionState.new(["player", "corp_security", "gang_a"])
	factions.set_faction_standing("corp_security", -50)
	var hacking_state: HackingState = HackingState.new()
	hacking_state.configure(100.0, 0.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, hacking_state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(service.request_hack(camera, HackDefinition.Ability.DISABLE_CAMERA), "eligible camera accepts DISABLE_CAMERA")
	check.call(not bool(camera.call("get", "detection_enabled")) and not bool(camera.call("can_detect_target", player)), "DISABLE_CAMERA suppresses camera detection")
	var energy_after_hack: float = hacking_state.current_energy
	check.call(not service.request_hack(camera, HackDefinition.Ability.DISABLE_CAMERA) and is_equal_approx(hacking_state.current_energy, energy_after_hack), "active camera effect rejects reapplication without another energy charge")
	camera.call("_process", 7.9)
	check.call(not bool(camera.call("get", "detection_enabled")), "camera remains disabled before configured duration expires")
	camera.call("_process", 0.2)
	check.call(bool(camera.call("get", "detection_enabled")) and bool(camera.call("can_detect_target", player)), "camera restores detection when its effect expires")

	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.position = Vector3(0.0, 2.0, -4.0)
	blocker.add_child(_box_shape(Vector3(3.0, 3.0, 0.5)))
	root.add_child(blocker)
	await tree.physics_frame
	check.call(not bool(camera.call("can_detect_target", player)), "camera detection respects an occluding wall")
	root.remove_child(blocker)
	blocker.free()
	root.remove_child(player)
	player.free()
	root.remove_child(camera)
	camera.free()
	root.remove_child(operator)
	operator.free()


func _test_turret_effect(check: Callable, turret_script: Script) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = tree.root
	var operator: Node3D = Node3D.new()
	var turret: StaticBody3D = turret_script.new() as StaticBody3D
	turret.name = "HackableTurret"
	turret.set("persistent_uuid", TURRET_UUID)
	turret.set("faction_id", "corp_security")
	turret.set("player_faction_id", "player")
	turret.set("temporary_override_mode", 2) # Explicit FRIENDLY mode.
	turret.position = Vector3(0.0, 1.0, -5.0)
	turret.add_child(_box_shape(Vector3(1.0, 1.4, 1.0)))
	root.add_child(operator)
	root.add_child(turret)
	await tree.physics_frame
	var factions: FactionState = FactionState.new(["player", "corp_security", "gang_a"])
	factions.set_faction_standing("corp_security", -50)
	factions.set_faction_standing("gang_a", -50)
	check.call(bool(turret.call("configure", factions)), "turret accepts explicit faction and friendly-mode configuration")
	check.call(bool(turret.call("is_hostile_to_player")), "hostile faction turret targets player before hacking")
	check.call(not bool(turret.call("can_target_faction", "gang_a")), "hostile turret does not target an unrelated faction before hacking")
	var hacking_state: HackingState = HackingState.new()
	hacking_state.configure(100.0, 0.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, hacking_state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(service.request_hack(turret, HackDefinition.Ability.DISABLE_TURRET), "eligible hostile turret accepts DISABLE_TURRET")
	check.call(not bool(turret.call("is_hostile_to_player")) and bool(turret.call("can_target_faction", "gang_a")), "friendly override creates a safe player crossing and targets hostile gangs")
	var energy_after_hack: float = hacking_state.current_energy
	check.call(not service.request_hack(turret, HackDefinition.Ability.DISABLE_TURRET) and is_equal_approx(hacking_state.current_energy, energy_after_hack), "turret effect reapplication is rejected during cooldown without charge")
	factions.set_faction_standing("corp_security", 0)
	turret.call("_process", 10.1)
	check.call(not bool(turret.call("is_hostile_to_player")) and not bool(turret.call("can_target_faction", "gang_a")), "expiry restores current faction authority rather than stale pre-hack hostility")
	root.remove_child(turret)
	turret.free()

	var destroyed_turret: StaticBody3D = turret_script.new() as StaticBody3D
	destroyed_turret.name = "DestroyedDuringHackTurret"
	destroyed_turret.set("persistent_uuid", DESTROYED_TURRET_UUID)
	destroyed_turret.set("faction_id", "corp_security")
	destroyed_turret.set("player_faction_id", "player")
	destroyed_turret.set("temporary_override_mode", 1) # Explicit NEUTRAL mode.
	destroyed_turret.add_child(_box_shape(Vector3(1.0, 1.4, 1.0)))
	root.add_child(destroyed_turret)
	await tree.physics_frame
	factions.set_faction_standing("corp_security", -50)
	check.call(bool(destroyed_turret.call("configure", factions)), "second turret configures before the destruction case")
	check.call(bool(destroyed_turret.call("is_hostile_to_player")), "neutral-mode target starts hostile before the effect")
	var destruction_state: HackingState = HackingState.new()
	destruction_state.configure(100.0, 0.0, 100.0)
	var destruction_service: HackingService = HackingService.new()
	destruction_service.configure(operator, destruction_state, destruction_service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(destruction_service.request_hack(destroyed_turret, HackDefinition.Ability.DISABLE_TURRET), "explicit neutral turret accepts DISABLE_TURRET")
	check.call(not bool(destroyed_turret.call("can_target_faction", "player")) and not bool(destroyed_turret.call("can_target_faction", "gang_a")), "neutral override ceases fire against all factions")
	destroyed_turret.call("mark_destroyed")
	destroyed_turret.call("_process", 20.0)
	check.call(bool(destroyed_turret.call("get", "is_destroyed")) and int(destroyed_turret.call("get_effective_mode")) == 3 and not bool(destroyed_turret.call("is_hostile_to_player")), "destroyed turret does not restore allegiance when its effect timer elapses")
	root.remove_child(destroyed_turret)
	destroyed_turret.free()
	root.remove_child(operator)
	operator.free()
	await tree.process_frame


func _box_shape(size: Vector3) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	return collision


func _capsule_shape(radius: float, height: float) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	collision.shape = capsule
	return collision
