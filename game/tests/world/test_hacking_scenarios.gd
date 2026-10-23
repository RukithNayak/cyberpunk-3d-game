extends RefCounted

const SCENARIOS: Array[String] = [
	"res://world/fixtures/hacking/stealth_route.tscn",
	"res://world/fixtures/hacking/security_corridor.tscn",
]


func run(check: Callable) -> void:
	var stealth: HackingEncounterBase = await _load_fixture(SCENARIOS[0], check)
	if stealth != null:
		await _test_stealth_route(stealth, check)
		stealth.queue_free()
		await Engine.get_main_loop().process_frame
	var corridor: HackingEncounterBase = await _load_fixture(SCENARIOS[1], check)
	if corridor != null:
		await _test_security_corridor(corridor, check)
		corridor.queue_free()
		await Engine.get_main_loop().process_frame


func _load_fixture(path: String, check: Callable) -> HackingEncounterBase:
	var packed: PackedScene = load(path) as PackedScene
	check.call(packed != null, "%s scene resource loads" % path.get_file())
	if packed == null:
		return null
	var fixture: HackingEncounterBase = packed.instantiate() as HackingEncounterBase
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(fixture)
	for _frame: int in range(4):
		await tree.process_frame
	check.call(fixture.fixture_ready, "%s composes hydration and hacking services" % fixture.encounter_id)
	check.call(fixture.operator != null and fixture.approach_marker != null and fixture.objective_marker != null, "%s exposes natural approach and objective markers" % fixture.encounter_id)
	check.call(fixture.camera_target != null and fixture.camera_target.is_in_group(&"hackable_camera"), "%s authors a stable surveillance target" % fixture.encounter_id)
	return fixture


func _test_stealth_route(fixture: HackingEncounterBase, check: Callable) -> void:
	check.call(fixture.door_target != null and fixture.door_target.persistent_uuid == HackingEncounterBase.MARKET_DOOR_UUID, "neon market has a durable locked shortcut with canonical identity")
	check.call(fixture.operator.global_position.distance_to(fixture.camera_target.global_position) <= 18.0, "market surveillance target is within natural approach hacking range")
	check.call(fixture.camera_target.can_detect_target(fixture.operator), "market camera covers the natural approach before hacking")
	var hacked_camera: bool = fixture.hacking_service.request_hack(fixture.camera_target, HackDefinition.Ability.DISABLE_CAMERA)
	check.call(hacked_camera and not fixture.camera_target.detection_enabled, "disabling market camera removes surveillance during the shortcut approach")
	fixture.hacking_service.tick_energy_regen(8.1)
	check.call(fixture.camera_target.detection_enabled, "market camera resumes after its authored timed hack effect")
	var door_hacked: bool = fixture.hacking_service.request_hack(fixture.door_target, HackDefinition.Ability.UNLOCK_DOOR)
	check.call(door_hacked and fixture.entity_registry.get_entity_state(fixture.door_target.persistent_uuid) == {"locked": false, "open": true}, "service shortcut opens through the durable entity registry")
	await Engine.get_main_loop().physics_frame
	var bypass_probe: CharacterBody3D = _make_route_probe(Vector3(7.0, 0.9, 5.0))
	fixture.add_child(bypass_probe)
	await Engine.get_main_loop().physics_frame
	var bypass_clear: bool = not bypass_probe.test_move(bypass_probe.global_transform, Vector3(0.0, 0.0, -20.0))
	check.call(bypass_clear, "maintenance bypass remains traversable without hacking or opening the gate")
	bypass_probe.queue_free()


func _test_security_corridor(fixture: HackingEncounterBase, check: Callable) -> void:
	check.call(fixture.turret_target != null and fixture.turret_target.is_hostile_to_player(), "corporate transit corridor starts with a hostile turret")
	check.call(fixture.operator.global_position.distance_to(fixture.turret_target.global_position) <= 18.0, "turret is in range from the corridor approach")
	var turret_hacked: bool = fixture.hacking_service.request_hack(fixture.turret_target, HackDefinition.Ability.DISABLE_TURRET)
	check.call(turret_hacked and fixture.turret_target.override_active and not fixture.turret_target.is_hostile_to_player(), "friendly turret override creates a safe crossing window")
	fixture.hacking_service.tick_energy_regen(10.1)
	check.call(not fixture.turret_target.override_active and fixture.turret_target.is_hostile_to_player(), "turret resumes hostile coverage after the timed effect")
	check.call(fixture.guard != null and fixture.distraction_target != null and fixture.implant_target != null, "guard presents both a distraction device and implant target")
	if fixture.guard == null or fixture.distraction_target == null or fixture.implant_target == null:
		return
	var perception: NpcPerception = fixture.guard.get_node("Perception") as NpcPerception
	check.call(perception != null, "security guard owns the accepted perception component")
	var before: int = perception.data.heard_events.size()
	var distracted: bool = fixture.hacking_service.request_hack(fixture.distraction_target, HackDefinition.Ability.TRIGGER_DISTRACTION)
	check.call(distracted and perception.data.heard_events.size() == before + 1, "distraction pulls the guard toward the holo-ad source")
	fixture.hacking_service.tick_energy_regen(6.1)
	var health_before: int = fixture.guard.health_state.current_hp
	var disrupted: bool = fixture.hacking_service.request_hack(fixture.implant_target, HackDefinition.Ability.DISRUPT_IMPLANT)
	check.call(disrupted and fixture.guard.substate == TacticalAgent.Substate.STUNNED and fixture.guard.health_state.current_hp < health_before, "implant hack interrupts and damages the guard accepted=" + str(disrupted) + " hp=" + str(fixture.guard.health_state.current_hp) + "/" + str(health_before) + " substate=" + str(fixture.guard.substate) + " rejection=" + str(fixture.hacking_service.get_last_rejection_reason()))
	await Engine.get_main_loop().physics_frame
	var flank_probe: CharacterBody3D = _make_route_probe(Vector3(10.5, 0.9, 5.0))
	fixture.add_child(flank_probe)
	await Engine.get_main_loop().physics_frame
	check.call(not flank_probe.test_move(flank_probe.global_transform, Vector3(0.0, 0.0, -20.0)), "side maintenance flank remains traversable with hacks unavailable")
	flank_probe.queue_free()


func _make_route_probe(at: Vector3) -> CharacterBody3D:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.position = at
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collision.shape = capsule
	body.add_child(collision)
	return body
