extends SceneTree
## Dependency-free runner. Register focused suites here; intentional failure is opt-in.

var _cases: int = 0
var _failures: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--suite":
		printerr("Usage: -- --suite <sample|all|registry|save_store|world_manifest|health|migrations|chunk_loader|player_controller|deliberate_failure>")
		quit(2)
		return
	var suite: String = args[1]
	match suite:
		"sample", "all":
			_check(2 + 2 == 4, "sample arithmetic")
			var original: Dictionary = {"flags": {"open": false}}
			var copied: Dictionary = original.duplicate(true)
			copied["flags"]["open"] = true
			_check(not original["flags"]["open"], "sample nested copy isolation")
			if suite == "all":
				var registry_test: RefCounted = load("res://tests/persistence/test_registry.gd").new()
				registry_test.run(_check)
				var health_test: RefCounted = load("res://tests/player/test_health.gd").new()
				health_test.run(_check)
				var save_test: RefCounted = load("res://tests/persistence/test_save_store.gd").new()
				save_test.run(_check)
				var world_test: RefCounted = load("res://tests/world/test_manifest.gd").new()
				world_test.run(_check)
				var migration_test: RefCounted = load("res://tests/persistence/test_migrations.gd").new()
				migration_test.run(_check)
				var loader_test: RefCounted = load("res://tests/world/test_chunk_loader.gd").new()
				await loader_test.run(_check)
		"registry":
			var registry_test: RefCounted = load("res://tests/persistence/test_registry.gd").new()
			registry_test.run(_check)
		"save_store":
			var save_test: RefCounted = load("res://tests/persistence/test_save_store.gd").new()
			save_test.run(_check)
		"world_manifest":
			var world_test: RefCounted = load("res://tests/world/test_manifest.gd").new()
			world_test.run(_check)
		"health":
			var health_test: RefCounted = load("res://tests/player/test_health.gd").new()
			health_test.run(_check)
		"migrations":
			var migration_test: RefCounted = load("res://tests/persistence/test_migrations.gd").new()
			migration_test.run(_check)
		"chunk_loader":
			var loader_test: RefCounted = load("res://tests/world/test_chunk_loader.gd").new()
			await loader_test.run(_check)
		"player_controller":
			var controller_test: RefCounted = load("res://tests/player/test_controller.gd").new()
			await controller_test.run(_check)
		"deliberate_failure":
			_check(false, "intentional failing fixture")
		_:
			printerr("Unknown suite: %s" % suite)
			quit(2)
			return
	print("Suite %s: %d cases, %d failures" % [suite, _cases, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	_cases += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		printerr("FAIL: %s" % description)
