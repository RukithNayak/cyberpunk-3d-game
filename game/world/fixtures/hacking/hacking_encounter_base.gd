extends Node3D
class_name HackingEncounterBase
## Reusable authoring scaffold; each encounter script owns its route and dressing.

@export var encounter_id: String = ""
@export var palette_primary: Color = Color("00e5ff")
@export var palette_secondary: Color = Color("ff2da6")
@export var security_ability: int = HackDefinition.Ability.DISABLE_CAMERA
@export var include_door: bool = false
@export var include_turret: bool = false
@export var include_guard: bool = false

var operator: CharacterBody3D
var camera_target: HackableCamera
var door_target: HackableDoor
var turret_target: HackableTurret
var distraction_target: HackableDistraction
var implant_target: HackableImplant
var guard: TacticalAgent
var hacking_service: HackingService
var hack_snapshot: HackSnapshot
var entity_registry: EntityRegistry
var world_manager: WorldManager
var entity_hydrator: EntityHydrator
var faction_state: FactionState
var fixture_ready: bool = false
var approach_marker: Marker3D
var objective_marker: Marker3D

const MARKET_CAMERA_UUID := "81000000-0000-4000-8000-000000000001"
const MARKET_DOOR_UUID := "81000000-0000-4000-8000-000000000002"
const TRANSIT_CAMERA_UUID := "82000000-0000-4000-8000-000000000001"
const TRANSIT_TURRET_UUID := "82000000-0000-4000-8000-000000000003"
const TRANSIT_DISTRACTION_UUID := "82000000-0000-4000-8000-000000000004"
const TRANSIT_IMPLANT_UUID := "82000000-0000-4000-8000-000000000005"
const GUARD_SCENE: PackedScene = preload("res://features/npcs/goon.tscn")
const ARCH_ASSET: PackedScene = preload("res://assets/reference/wall_doorway.glb")
const JUNCTION_ASSET: PackedScene = preload("res://assets/reference/mechanical_prop.glb")


func _ready() -> void:
	_build_common()
	_build_encounter()
	_finish_setup.call_deferred()


func _build_encounter() -> void:
	# Implemented by each fixture with its spatial route and district dressing.
	pass


func _finish_setup() -> void:
	await get_tree().process_frame
	var scene_path: String = scene_file_path
	var entities: Array[Dictionary] = []
	if include_door:
		entities.append({"uuid": MARKET_DOOR_UUID, "node_path": "ServiceDoor", "initial_state": {"locked": true, "open": false}})
	var manifest: ChunkManifest = ChunkManifest.new()
	if not manifest.configure([{"id": encounter_id, "bounds": AABB(Vector3(-16,-4,-22), Vector3(32,12,44)), "scene_path": scene_path, "adjacent": [], "entities": entities}]):
		push_error("Hacking fixture manifest failed: " + encounter_id)
		return
	world_manager = WorldManager.new()
	if not world_manager.configure(manifest, 0.0, 0.0):
		push_error("Hacking fixture world manager failed: " + encounter_id)
		return
	world_manager.update_player_position(Vector3.ZERO)
	var generation: int = world_manager.get_lifecycle_generation(encounter_id)
	entity_registry = EntityRegistry.new()
	entity_hydrator = EntityHydrator.new()
	if not entity_hydrator.configure(entity_registry, manifest, world_manager):
		push_error("Hacking fixture hydrator failed: " + encounter_id)
		return
	hack_snapshot = HackSnapshot.new()
	if not hack_snapshot.configure(world_manager):
		push_error("Hacking fixture effect clock failed: " + encounter_id)
		return
	if include_door:
		if not door_target.configure_lifecycle(entity_hydrator, generation):
			push_error("Hacking fixture door lifecycle failed: " + encounter_id)
			return
		if not entity_hydrator.prepare_chunk(encounter_id, generation, self):
			push_error("Hacking fixture door hydration failed: " + encounter_id)
			return
	if not world_manager.acknowledge_activated(encounter_id, generation):
		push_error("Hacking fixture activation failed: " + encounter_id)
		return
	if include_door and not entity_hydrator.activate_chunk(encounter_id, generation, self):
		push_error("Hacking fixture door activation failed: " + encounter_id)
		return
	if camera_target != null:
		camera_target.set_external_hack_clock(true)
		if not hack_snapshot.register_target(camera_target, encounter_id):
			push_error("Hacking fixture camera registration failed: " + encounter_id)
			return
	if turret_target != null:
		turret_target.set_external_hack_clock(true)
		if not faction_state is FactionState:
			return
		if not turret_target.configure(faction_state) or not hack_snapshot.register_target(turret_target, encounter_id):
			push_error("Hacking fixture turret setup failed: " + encounter_id)
			return
	if guard != null:
		var goon_driver: Node = guard.get_node_or_null("NavigationDriver")
		if goon_driver != null:
			goon_driver.set("process_navigation", false)
		if not guard.configure(faction_state, "security", []):
			push_error("Hacking fixture guard setup failed: " + encounter_id)
			return
		if implant_target != null:
			implant_target.set_external_hack_clock(true)
			if not hack_snapshot.register_target(implant_target, encounter_id):
				push_error("Hacking fixture implant registration failed: " + encounter_id)
				return
		if distraction_target != null:
			distraction_target.source_faction_id = "player"
	operator.global_position = approach_marker.global_position
	if distraction_target != null:
		distraction_target.collision_layer = 1
	if implant_target != null:
		implant_target.collision_layer = 1
	var state: HackingState = HackingState.new()
	state.configure(100.0, 8.0, 100.0)
	hacking_service = HackingService.new()
	if not hacking_service.configure(operator, state, hacking_service.get_default_definitions(), Callable(), hack_snapshot):
		push_error("Hacking fixture service setup failed: " + encounter_id)
		return
	fixture_ready = true


func _build_common() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("35404c")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	key_light.light_energy = 0.55
	add_child(key_light)
	operator = CharacterBody3D.new()
	operator.name = "ApproachOperator"
	operator.position = Vector3(0.0, 0.9, 9.0)
	var operator_shape: CollisionShape3D = CollisionShape3D.new()
	var operator_capsule: CapsuleShape3D = CapsuleShape3D.new()
	operator_capsule.radius = 0.3
	operator_capsule.height = 1.7
	operator_shape.shape = operator_capsule
	operator.add_child(operator_shape)
	add_child(operator)
	approach_marker = Marker3D.new()
	approach_marker.name = "NaturalApproach"
	approach_marker.position = Vector3(0.0, 1.0, 9.0)
	add_child(approach_marker)
	objective_marker = Marker3D.new()
	objective_marker.name = "Objective"
	objective_marker.position = Vector3(0.0, 1.0, -8.0)
	add_child(objective_marker)
	_add_box("WetPavement", Vector3(0.0, -0.25, -2.0), Vector3(26.0, 0.5, 28.0), Color("18222d"), true)
	_add_box("LeftFacade", Vector3(-13.0, 9.0, -2.0), Vector3(1.0, 18.0, 28.0), Color("202839"), true)
	_add_box("RightFacade", Vector3(13.0, 9.0, -2.0), Vector3(1.0, 18.0, 28.0), Color("202839"), true)
	_add_box("DistantFacade", Vector3(0.0, 9.0, -16.0), Vector3(26.0, 18.0, 1.0), Color("25273a"), true)
	_add_neon("DistrictSignPrimary", Vector3(-8.5, 5.0, -4.5), Vector3(4.0, 1.4, 0.18), palette_primary)
	_add_neon("DistrictSignSecondary", Vector3(8.5, 6.2, -10.0), Vector3(3.2, 0.8, 0.16), palette_secondary)
	_add_light("PrimaryNeon", Vector3(-8.0, 4.0, -5.0), palette_primary, 2.8)
	_add_light("SecondaryNeon", Vector3(8.0, 4.0, -10.0), palette_secondary, 2.2)
	_add_city_windows()
	_add_box("DrainageChannel", Vector3(0.0, 0.015, -2.0), Vector3(0.18, 0.025, 26.0), Color("08a5b7"), false)
	_add_box("CrosswalkMarkingA", Vector3(-4.2, 0.02, 5.5), Vector3(0.75, 0.025, 3.0), Color("4d5965"), false)
	_add_box("CrosswalkMarkingB", Vector3(4.2, 0.02, 5.5), Vector3(0.75, 0.025, 3.0), Color("4d5965"), false)
	_add_reference_dressing()
	var camera: Camera3D = Camera3D.new()
	camera.name = "EncounterPreviewCamera"
	camera.position = Vector3(0.0, 3.2, 15.5)
	camera.fov = 72.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, -9.0), Vector3.UP)
	camera.current = true
	camera_target = _make_camera(MARKET_CAMERA_UUID if include_door else TRANSIT_CAMERA_UUID, Vector3(0.0, 4.8, -3.0), Vector3(0.0, 2.0, 9.0))
	add_child(camera_target)
	if include_door:
		door_target = _make_door(MARKET_DOOR_UUID)
		add_child(door_target)
	faction_state = FactionState.new(["player", "security", "gang"])
	faction_state.set_faction_standing("security", -100)
	if include_turret:
		turret_target = _make_turret(TRANSIT_TURRET_UUID, Vector3(0.0, 2.0, -7.0))
		add_child(turret_target)
	if include_guard:
		var guard_instance: Node = GUARD_SCENE.instantiate()
		guard_instance.name = "SecurityGuard"
		guard = guard_instance as TacticalAgent
		guard.position = Vector3(5.0, 0.0, -8.0)
		add_child(guard)
		implant_target = _make_implant()
		implant_target.position = Vector3(-0.3, 1.1, 1.8)
		guard.add_child(implant_target)
		distraction_target = _make_distraction(Vector3(6.5, 1.0, -3.5))
		add_child(distraction_target)


func _add_box(label: String, at: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var parent: Node3D
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = label
		parent = body
	else:
		parent = Node3D.new()
		parent.name = label
	parent.position = at
	add_child(parent)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	parent.add_child(mesh_instance)
	if solid:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		parent.add_child(collision)
	return parent


func _add_neon(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var panel: Node3D = _add_box(label, at, size, color, false)
	var mesh: MeshInstance3D = panel.get_child(0) as MeshInstance3D
	var material: StandardMaterial3D = (mesh.mesh as BoxMesh).material as StandardMaterial3D
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	var sign_text: Label3D = Label3D.new()
	sign_text.name = "DistrictSignText"
	sign_text.text = "NIGHT MARKET / 07" if encounter_id == "neon_market_alley" else "TRANSIT / SECURE"
	sign_text.position = Vector3(0.0, 0.0, 0.16)
	sign_text.font_size = 42
	sign_text.outline_size = 5
	sign_text.modulate = Color("fff4d3")
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel.add_child(sign_text)


func _add_light(label: String, at: Vector3, color: Color, power: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = power
	light.omni_range = 13.0
	add_child(light)


func _add_city_windows() -> void:
	var window_colors: Array[Color] = [palette_primary, Color("e6ad5b"), palette_secondary]
	for side: int in [-1, 1]:
		for floor_index: int in range(5):
			var window_y: float = 3.0 + float(floor_index) * 3.1
			var window_z: float = -11.5 + float((floor_index % 2) * 1.2)
			var window_color: Color = window_colors[floor_index % window_colors.size()]
			var window: Node3D = _add_box("FacadeWindow_%d_%d" % [side, floor_index], Vector3(float(side) * 12.42, window_y, window_z), Vector3(0.08, 1.25, 2.1), Color("172932"), false)
			var mesh_instance: MeshInstance3D = window.get_child(0) as MeshInstance3D
			var box_mesh: BoxMesh = mesh_instance.mesh as BoxMesh
			var material: StandardMaterial3D = box_mesh.material as StandardMaterial3D
			material.emission_enabled = true
			material.emission = window_color
			material.emission_energy_multiplier = 0.9
			_add_light("FacadeGlow_%d_%d" % [side, floor_index], Vector3(float(side) * 11.6, window_y, window_z), window_color, 0.55)


func _add_reference_dressing() -> void:
	var arch: Node3D = ARCH_ASSET.instantiate() as Node3D
	arch.name = "ASSET03ServiceArch"
	arch.position = Vector3(0.0, 0.0, -13.2)
	arch.scale = Vector3(3.0, 3.0, 3.0)
	add_child(arch)
	var junction_positions: Array[Vector3] = [Vector3(-11.7, 0.15, 2.0), Vector3(11.7, 0.15, -7.0)]
	for index: int in range(junction_positions.size()):
		var junction: Node3D = JUNCTION_ASSET.instantiate() as Node3D
		junction.name = "ASSET03UtilityJunction_%02d" % (index + 1)
		junction.position = junction_positions[index]
		junction.scale = Vector3(1.35, 1.35, 1.35)
		add_child(junction)


func _make_camera(uuid: String, at: Vector3, look_at_point: Vector3) -> HackableCamera:
	var target: HackableCamera = HackableCamera.new()
	target.name = "SurveillanceCamera"
	target.persistent_uuid = uuid
	target.chunk_id = encounter_id
	target.position = at
	target.basis = Basis.looking_at(look_at_point - at, Vector3.UP)
	target.detection_range = 18.0
	target.field_of_view_degrees = 90.0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.28
	shape.shape = sphere
	target.add_child(shape)
	return target


func _make_door(uuid: String) -> HackableDoor:
	var target: HackableDoor = HackableDoor.new()
	target.name = "ServiceDoor"
	target.persistent_uuid = uuid
	target.position = Vector3(0.0, 1.1, -6.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(3.0, 2.2, 0.25)
	shape.shape = box
	target.add_child(shape)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(3.0, 2.2, 0.18)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("b6475e")
	material.emission_enabled = true
	material.emission = palette_secondary
	material.emission_energy_multiplier = 0.8
	mesh.material = material
	visual.mesh = mesh
	target.add_child(visual)
	return target


func _make_turret(uuid: String, at: Vector3) -> HackableTurret:
	var target: HackableTurret = HackableTurret.new()
	target.name = "SecurityTurret"
	target.persistent_uuid = uuid
	target.chunk_id = encounter_id
	target.faction_id = "security"
	target.player_faction_id = "player"
	target.temporary_override_mode = HackableTurret.TemporaryOverrideMode.FRIENDLY
	target.position = at
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 1.2, 0.8)
	shape.shape = box
	target.add_child(shape)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.9, 1.2, 0.9)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("792b45")
	material.emission_enabled = true
	material.emission = palette_secondary
	material.emission_energy_multiplier = 0.8
	mesh.material = material
	visual.mesh = mesh
	target.add_child(visual)
	return target


func _make_distraction(at: Vector3) -> HackableDistraction:
	var target: HackableDistraction = HackableDistraction.new()
	target.name = "HoloAdDistraction"
	target.persistent_uuid = TRANSIT_DISTRACTION_UUID
	target.position = at
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	target.add_child(shape)
	return target


func _make_implant() -> HackableImplant:
	var target: HackableImplant = HackableImplant.new()
	target.name = "NeuralImplant"
	target.persistent_uuid = TRANSIT_IMPLANT_UUID
	target.chunk_id = encounter_id
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	target.add_child(shape)
	return target
