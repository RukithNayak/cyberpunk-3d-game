extends RefCounted

const GOON_SCENE_PATH: String = "res://features/npcs/goon.tscn"
const DISTRACTION_PATH: String = "res://features/hacking/targets/hackable_distraction.gd"
const IMPLANT_PATH: String = "res://features/hacking/targets/hackable_implant.gd"
const DISTRACTION_UUID: String = "123e4567-e89b-42d3-a456-426614174020"
const IMPLANT_UUID: String = "123e4567-e89b-42d3-a456-426614174021"


class TestDamageTarget extends StaticBody3D:
	var damage_calls: int = 0
	var damage_total: int = 0
	var current_health: int = 100

	func is_alive() -> bool:
		return current_health > 0

	func apply_damage(amount: int, _source_faction: String) -> void:
		if amount <= 0 or not is_alive():
			return
		damage_calls += 1
		damage_total += amount
		current_health = maxi(0, current_health - amount)


func run(check: Callable) -> void:
	var distraction_script: Script = load(DISTRACTION_PATH) as Script
	var implant_script: Script = load(IMPLANT_PATH) as Script
	var goon_scene: PackedScene = load(GOON_SCENE_PATH) as PackedScene
	check.call(distraction_script != null, "HACK-04 distraction target script exists")
	check.call(implant_script != null, "HACK-04 implant target script exists")
	check.call(goon_scene != null, "HACK-04 uses the existing AI-02 guard scene")
	if distraction_script != null and goon_scene != null:
		await _test_distraction_investigation(check, distraction_script, goon_scene)
	if implant_script != null and goon_scene != null:
		await _test_implant_interrupt(check, implant_script, goon_scene)


func _test_distraction_investigation(check: Callable, distraction_script: Script, goon_scene: PackedScene) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	var factions: FactionState = FactionState.new(["player", "gang_a"])
	factions.set_faction_standing("player", -50)
	var nearby_guard: CharacterBody3D = _new_guard(goon_scene, root, factions, "NearbyGuard", Vector3(0.0, 0.0, -9.0))
	var distant_guard: CharacterBody3D = _new_guard(goon_scene, root, factions, "DistantGuard", Vector3(0.0, 0.0, -30.0))
	var operator: Node3D = Node3D.new()
	root.name = "DistractionScenario"
	operator.name = "Hacker"
	var distraction: StaticBody3D = distraction_script.new() as StaticBody3D
	distraction.name = "HackableDistraction"
	distraction.set("persistent_uuid", DISTRACTION_UUID)
	distraction.set("sound_radius", 12.0)
	distraction.position = Vector3(0.0, 1.5, -4.0)
	root.add_child(operator)
	root.add_child(distraction)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = Vector3(0.0, 1.0, -6.5)
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(5.0, 3.0, 0.4)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	root.add_child(wall)
	tree.root.add_child(root)
	await tree.physics_frame
	var nearby_perception: Node = nearby_guard.get_node("Perception")
	var distant_perception: Node = distant_guard.get_node("Perception")
	check.call(nearby_perception.is_in_group("npc_perception") and distant_perception.is_in_group("npc_perception"), "AI perceptions register for decoupled distraction broadcasts")
	nearby_guard.call("configure", factions, "gang_a")
	distant_guard.call("configure", factions, "gang_a")
	var state: HackingState = HackingState.new()
	state.configure(100.0, 0.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(service.request_hack(distraction, HackDefinition.Ability.TRIGGER_DISTRACTION), "eligible sound source accepts TRIGGER_DISTRACTION")
	var nearby_heard: Array = nearby_perception.get("data").get("heard_events")
	var distant_heard: Array = distant_perception.get("data").get("heard_events")
	check.call(nearby_heard.size() == 1 and distant_heard.is_empty(), "sound reaches listeners within the authored radius only")
	nearby_guard.call("tick", 1.0 / 60.0)
	check.call(String(nearby_guard.call("get_state_name")).to_upper() == "INVESTIGATE" and (nearby_guard.call("get_movement_destination") as Vector3).is_equal_approx(distraction.global_position), "guard investigates the distraction position through cover")
	var energy_after_trigger: float = state.current_energy
	check.call(not service.request_hack(distraction, HackDefinition.Ability.TRIGGER_DISTRACTION) and is_equal_approx(state.current_energy, energy_after_trigger), "distraction cooldown prevents duplicate event and charge")
	tree.root.remove_child(root)
	root.free()
	await tree.process_frame


func _test_implant_interrupt(check: Callable, implant_script: Script, goon_scene: PackedScene) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node3D = Node3D.new()
	root.name = "ImplantScenario"
	var factions: FactionState = FactionState.new(["player", "gang_a"])
	factions.set_faction_standing("player", -50)
	var player: TestDamageTarget = TestDamageTarget.new()
	player.name = "PlayerTarget"
	player.position = Vector3(0.0, 1.0, 0.0)
	player.collision_layer = 2
	var agent: CharacterBody3D = goon_scene.instantiate() as CharacterBody3D
	agent.name = "CombatGuard"
	agent.position = Vector3(0.0, 0.0, -1.3)
	agent.set_physics_process(false)
	agent.set("process_ai", false)
	agent.get_node("NavigationDriver").set("process_navigation", false)
	var operator: Node3D = Node3D.new()
	operator.name = "Hacker"
	operator.position = Vector3(0.0, 0.0, 0.5)
	root.add_child(player)
	root.add_child(operator)
	root.add_child(agent)
	tree.root.add_child(root)
	await tree.physics_frame
	check.call(bool(agent.call("configure", factions, "gang_a")), "combat guard accepts the existing AI faction contract")
	# This isolated fixture is the open approach lane; exclude environment hits so
	# the regression measures combat interruption rather than the raycast fixture.
	agent.get_node("Perception").set("collision_mask", 0)
	var candidate_set: bool = bool(agent.call("set_candidate_target", player, "player"))
	var visible_before_tick: bool = bool(agent.get_node("Perception").call("update_visual_target", player))
	check.call(candidate_set and visible_before_tick, "open-lane guard has a visible hostile candidate")
	check.call(bool(agent.call("tick", 1.0 / 60.0)), "combat guard advances before the implant hack")
	check.call(String(agent.call("get_substate_name")).to_upper() == "ATTACK" and player.damage_calls == 1, "guard is actively attacking before DISRUPT_IMPLANT")
	var implant: StaticBody3D = implant_script.new() as StaticBody3D
	implant.name = "HackableImplant"
	implant.set("persistent_uuid", IMPLANT_UUID)
	implant.position = Vector3(0.0, 1.45, -0.3)
	agent.add_child(implant)
	await tree.physics_frame
	var state: HackingState = HackingState.new()
	state.configure(100.0, 0.0, 100.0)
	var service: HackingService = HackingService.new()
	service.configure(operator, state, service.get_default_definitions(), func(_from: Vector3, _to: Vector3) -> bool: return true)
	check.call(service.request_hack(implant, HackDefinition.Ability.DISRUPT_IMPLANT), "eligible live implant accepts DISRUPT_IMPLANT")
	var health: HealthState = agent.get("health_state") as HealthState
	check.call(health.current_hp == 72 and String(agent.call("get_substate_name")).to_upper() == "STUNNED", "implant hack applies configured damage and interrupts the active attack")
	check.call(not bool(agent.call("can_accept_implant_disruption")) and not bool(implant.call("apply_hack", _definition(service, HackDefinition.Ability.DISRUPT_IMPLANT), operator)), "already stunned implant cannot duplicate damage")
	var attacks_during_stun: int = player.damage_calls
	for _index: int in range(11):
		agent.call("tick", 0.25)
	agent.call("tick", 0.24)
	check.call(is_equal_approx(float(agent.call("get_stun_remaining_seconds")), 0.01) and player.damage_calls == attacks_during_stun, "guard cannot attack during the first 2.99 seconds of the stun")
	agent.call("tick", 0.02)
	check.call(is_zero_approx(float(agent.call("get_stun_remaining_seconds"))) and player.damage_calls == attacks_during_stun, "stun expires at three seconds without a repeated attack")
	var energy_after_first_hack: float = state.current_energy
	check.call(not service.request_hack(implant, HackDefinition.Ability.DISRUPT_IMPLANT) and is_equal_approx(state.current_energy, energy_after_first_hack), "implant cooldown blocks repeat requests without another damage event")
	health.apply_damage(health.current_hp, "test")
	check.call(not bool(agent.call("can_accept_implant_disruption")) and not service.request_hack(implant, HackDefinition.Ability.DISRUPT_IMPLANT), "dead or immune guard rejects implant disruption")
	tree.root.remove_child(root)
	root.free()
	await tree.process_frame


func _new_guard(scene: PackedScene, root: Node3D, factions: FactionState, node_name: String, at: Vector3) -> CharacterBody3D:
	var guard: CharacterBody3D = scene.instantiate() as CharacterBody3D
	guard.name = node_name
	guard.position = at
	guard.set_physics_process(false)
	guard.set("process_ai", false)
	guard.get_node("NavigationDriver").set("process_navigation", false)
	root.add_child(guard)
	guard.call("configure", factions, "gang_a")
	return guard


func _definition(service: HackingService, ability_id: int) -> HackDefinition:
	for definition: HackDefinition in service.get_default_definitions():
		if definition.ability_id == ability_id:
			return definition
	return null
