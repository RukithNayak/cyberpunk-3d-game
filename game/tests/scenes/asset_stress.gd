extends Node3D
## Profiles the two existing reference assets as a small sampled street segment.

const WALL_VISUAL: PackedScene = preload("res://assets/reference/wall_doorway.glb")
const WALL_COLLISION: PackedScene = preload("res://assets/reference/wall_doorway_collision.glb")
const PROP_VISUAL: PackedScene = preload("res://assets/reference/mechanical_prop.glb")
const PROP_COLLISION: PackedScene = preload("res://assets/reference/mechanical_prop_collision.glb")
const CASES: Array[Dictionary] = [
	{"name": "isolated_reference", "walls": 1, "props": 1},
	{"name": "small_block", "walls": 5, "props": 2},
	{"name": "street_segment", "walls": 20, "props": 8},
]
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 240
const WALL_TRIANGLES := 1428
const PROP_TRIANGLES := 4600
const WALL_MESHES := 13
const PROP_MESHES := 30
const WALL_COLLISION_SHAPES := 4
const PROP_COLLISION_SHAPES := 2

@onready var _assets_root: Node3D = $Assets

var _case_index := -1
var _warmup_remaining := 0
var _sample_remaining := 0
var _is_sampling := false
var _sample_frame_ms: Array[float] = []
var _sample_process_ms: Array[float] = []
var _sample_draw_calls: Array[float] = []
var _sample_primitives: Array[float] = []
var _sample_static_memory: Array[float] = []
var _sample_video_memory: Array[float] = []
var _results: Array[Dictionary] = []


func _ready() -> void:
	if DisplayServer.get_name() in ["headless", "dummy"]:
		print("ASSET_STRESS_SKIPPED dummy renderer cannot measure draw calls or video memory")
		get_tree().quit()
		return
	var camera := $Camera3D as Camera3D
	camera.position = Vector3(0.0, 11.0, 26.0)
	camera.look_at(Vector3(0.0, 0.0, -8.0))
	_advance_case()


func _process(delta: float) -> void:
	if not _is_sampling:
		if _warmup_remaining > 0:
			_warmup_remaining -= 1
			if _warmup_remaining == 0:
				_is_sampling = true
				_sample_remaining = SAMPLE_FRAMES
		return

	_sample_frame_ms.append(delta * 1000.0)
	_sample_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_sample_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_sample_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_sample_static_memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	_sample_video_memory.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	_sample_remaining -= 1
	if _sample_remaining == 0:
		_finish_case()


func _advance_case() -> void:
	_case_index += 1
	if _case_index >= CASES.size():
		_finish_benchmark()
		return

	for child in _assets_root.get_children():
		child.queue_free()
	await get_tree().process_frame
	_sample_frame_ms.clear()
	_sample_process_ms.clear()
	_sample_draw_calls.clear()
	_sample_primitives.clear()
	_sample_static_memory.clear()
	_sample_video_memory.clear()
	var scenario: Dictionary = CASES[_case_index]
	_build_instances(int(scenario["walls"]), int(scenario["props"]))
	await get_tree().physics_frame
	_warmup_remaining = WARMUP_FRAMES
	_is_sampling = false


func _build_instances(wall_count: int, prop_count: int) -> void:
	var wall_columns := 5
	for index in range(wall_count):
		var column := index % wall_columns
		var row := floori(float(index) / float(wall_columns))
		var placement := Vector3((column - 2) * 4.3, 0.0, -row * 4.3)
		_add_asset_pair(WALL_VISUAL, WALL_COLLISION, placement, "Wall_%02d" % index)
	var prop_columns := 4
	for index in range(prop_count):
		var column := index % prop_columns
		var row := floori(float(index) / float(prop_columns))
		var placement := Vector3((column - 1) * 6.2, 0.0, 3.2 - row * 4.1)
		_add_asset_pair(PROP_VISUAL, PROP_COLLISION, placement, "Prop_%02d" % index)


func _add_asset_pair(visual_scene: PackedScene, collision_scene: PackedScene,
		placement: Vector3, label: String) -> void:
	var visual := visual_scene.instantiate() as Node3D
	visual.name = label + "_Visual"
	visual.position = placement
	_assets_root.add_child(visual)
	var collision := collision_scene.instantiate() as Node3D
	collision.name = label + "_Collision"
	collision.position = placement
	_assets_root.add_child(collision)


func _finish_case() -> void:
	_is_sampling = false
	var scenario: Dictionary = CASES[_case_index]
	var wall_count := int(scenario["walls"])
	var prop_count := int(scenario["props"])
	var materials := _unique_resource_count("StandardMaterial3D")
	var textures := _unique_texture_count()
	var bodies := _assets_root.find_children("*", "StaticBody3D", true, false).size()
	var shapes := _assets_root.find_children("*", "CollisionShape3D", true, false).size()
	assert(bodies == wall_count * WALL_COLLISION_SHAPES + prop_count * PROP_COLLISION_SHAPES,
		"Collision body count does not match the authored proxies")
	assert(shapes == bodies, "Every authored static body should have one collision shape")
	_results.append({
		"name": scenario["name"],
		"wall_instances": wall_count,
		"prop_instances": prop_count,
		"render_triangles_reference_sum": wall_count * WALL_TRIANGLES + prop_count * PROP_TRIANGLES,
		"mesh_instances_reference_sum": wall_count * WALL_MESHES + prop_count * PROP_MESHES,
		"collision_triangles_reference_sum": wall_count * 48 + prop_count * 24,
		"static_bodies": bodies,
		"collision_shapes": shapes,
		"unique_standard_materials": materials,
		"unique_textures": textures,
		"draw_calls": _summary(_sample_draw_calls),
		"render_primitives": _summary(_sample_primitives),
		"frame_interval_ms": _summary(_sample_frame_ms),
		"engine_process_ms": _summary(_sample_process_ms),
		"static_memory_bytes": _summary(_sample_static_memory),
		"video_memory_bytes": _summary(_sample_video_memory),
		"samples": _sample_frame_ms.size(),
	})
	print("ASSET_STRESS_CASE ", JSON.stringify(_results.back()))
	call_deferred("_advance_case")


func _finish_benchmark() -> void:
	var output_dir := ProjectSettings.globalize_path("res://../benchmarks/assets")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var payload := {
		"benchmark": "ASSET-04 reference asset repetition",
		"date": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "default"),
		"window_mode": DisplayServer.window_get_mode(),
		"screen_size": DisplayServer.screen_get_size(),
		"window_size": DisplayServer.window_get_size(),
		"viewport_size": get_viewport().get_visible_rect().size,
		"debug_build": OS.is_debug_build(),
		"frame_cap": Engine.max_fps,
		"target_fps_reference_only": 60,
		"asset_data": {
			"wall_triangles": WALL_TRIANGLES,
			"wall_render_meshes": WALL_MESHES,
			"wall_collision_triangles": 48,
			"wall_collision_boxes": WALL_COLLISION_SHAPES,
			"prop_triangles": PROP_TRIANGLES,
			"prop_render_meshes": PROP_MESHES,
			"prop_collision_triangles": 24,
			"prop_collision_boxes": PROP_COLLISION_SHAPES,
			"import_lods_enabled": true,
			"textures_per_asset": 2,
			"texture_resolution": [1024, 1024],
		},
		"sampling": {"warmup_frames_per_case": WARMUP_FRAMES,
			"sample_frames_per_case": SAMPLE_FRAMES},
		"cases": _results,
		"notes": ["Fullscreen/current renderer only; no alternate resolution run.",
			"Reference street-segment counts are measurement samples, not production city limits.",
			"Performance monitors are debug-run, display-dependent measurements; WORLD-06 must select final budgets."],
	}
	var json_path := output_dir.path_join("asset_stress.json")
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	assert(file != null, "Could not write benchmark JSON: %s" % json_path)
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
	print("ASSET_STRESS_RESULT ", JSON.stringify({"file": json_path, "cases": _results.size()}))
	await get_tree().create_timer(0.5).timeout
	var screenshot_error := get_viewport().get_texture().get_image().save_png(
		output_dir.path_join("asset_stress.png"))
	assert(screenshot_error == OK, "Could not save stress fixture screenshot")
	print("ASSET_STRESS_CAPTURE ", output_dir.path_join("asset_stress.png"))
	get_tree().quit()


func _summary(values: Array[float]) -> Dictionary:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {
		"mean": total / maxf(float(values.size()), 1.0),
		"median": sorted_values[int((sorted_values.size() - 1) * 0.5)],
		"p95": sorted_values[int((sorted_values.size() - 1) * 0.95)],
		"max": sorted_values.back(),
	}


func _unique_resource_count(class_filter: String) -> int:
	var unique_ids: Dictionary = {}
	for mesh_node in _assets_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var resource := mesh_instance.get_active_material(surface_index)
			if resource != null and resource.get_class() == class_filter:
				unique_ids[resource.get_instance_id()] = true
	return unique_ids.size()


func _unique_texture_count() -> int:
	var unique_ids: Dictionary = {}
	for mesh_node in _assets_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			for texture in [material.albedo_texture, material.roughness_texture, material.metallic_texture]:
				if texture != null:
					unique_ids[texture.get_instance_id()] = true
	return unique_ids.size()
