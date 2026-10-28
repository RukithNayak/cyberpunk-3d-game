extends RefCounted

const REGISTRY_PATH: String = "res://persistence/entity_registry.gd"
const FACTION_PATH: String = "res://persistence/faction_state.gd"
const VALID_ENTITY_ID: String = "123e4567-e89b-42d3-a456-426614174000"


func _test_checked_delta(check: Callable, registry_script: Script) -> void:
	var registry: Object = registry_script.new()
	check.call(registry.has_method("try_commit_state_delta"), "registry reports authority commit acceptance for projection consumers")
	if not registry.has_method("try_commit_state_delta"):
		return
	registry.call("register_entity", VALID_ENTITY_ID, {"flags": {"locked": true}, "opaque": 7})
	check.call(registry.call("try_commit_state_delta", VALID_ENTITY_ID, {"flags": {"locked": false}}) and registry.call("get_entity_state", VALID_ENTITY_ID) == {"flags": {"locked": false}, "opaque": 7}, "checked delta commits through the registry merge and preserves unrelated data")
	check.call(registry.call("try_commit_state_delta", VALID_ENTITY_ID, {}), "checked valid no-op is an accepted commit")
	check.call(not registry.call("try_commit_state_delta", "123e4567-e89b-42d3-a456-426614174099", {}), "checked commit rejects unknown identity")
	var node: Node = Node.new()
	check.call(not registry.call("try_commit_state_delta", VALID_ENTITY_ID, {"unsafe": node}) and registry.call("get_entity_state", VALID_ENTITY_ID) == {"flags": {"locked": false}, "opaque": 7}, "checked unsafe delta rejects without changing truth")
	node.free()


func run(check: Callable) -> void:
	var registry_script: Script = load(REGISTRY_PATH) as Script
	check.call(registry_script != null, "entity registry script is available")
	if registry_script == null:
		return
	var registry: Object = registry_script.new()
	_test_checked_delta(check, registry_script)
	check.call(registry.has_method("register_entity"), "registry exposes registration")
	check.call(registry.has_method("commit_state_delta"), "registry exposes state deltas")
	check.call(registry.has_method("get_entity_state"), "registry exposes copied state lookup")
	if not registry.has_method("register_entity") or not registry.has_method("commit_state_delta") or not registry.has_method("get_entity_state"):
		return

	registry.call("register_entity", VALID_ENTITY_ID, {"flags": {"open": false}, "count": 1})
	registry.call("commit_state_delta", VALID_ENTITY_ID, {"flags": {"locked": true}, "count": 2, "items": ["old"]})
	registry.call("commit_state_delta", VALID_ENTITY_ID, {"items": ["new", "replacement"]})
	var state: Dictionary = registry.call("get_entity_state", VALID_ENTITY_ID)
	check.call(state.get("count") == 2, "delta replaces scalar values")
	check.call(state.get("flags", {}).get("open") == false and state.get("flags", {}).get("locked") == true, "delta recursively merges nested dictionaries")
	check.call(state.get("items") == ["new", "replacement"], "delta replaces arrays as complete values")
	registry.call("register_entity", VALID_ENTITY_ID, {"flags": {"open": true}})
	state = registry.call("get_entity_state", VALID_ENTITY_ID)
	check.call(state.get("count") == 2 and state.get("items") == ["new", "replacement"] and state.get("flags", {}).get("open") == false, "duplicate registration preserves modified state")
	state["flags"]["open"] = true
	check.call(registry.call("get_entity_state", VALID_ENTITY_ID).get("flags", {}).get("open") == false, "returned state is deeply isolated from registry truth")

	registry.call("register_entity", "invalid-id", {"ok": true})
	registry.call("register_entity", "123E4567-E89B-42D3-A456-426614174000", {"ok": true})
	check.call(registry.call("get_entity_state", "invalid-id").is_empty(), "invalid UUID registration is rejected")
	check.call(registry.call("get_entity_state", "123E4567-E89B-42D3-A456-426614174000").is_empty(), "UUIDs must use canonical lowercase form")
	var forbidden_node: Node = Node.new()
	registry.call("register_entity", "123e4567-e89b-42d3-a456-426614174001", {"bad": forbidden_node})
	forbidden_node.free()
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174001").is_empty(), "Node values are rejected from persistent state")
	var too_deep: Dictionary = {"leaf": true}
	for depth: int in range(17):
		too_deep = {"nested": too_deep}
	registry.call("register_entity", "123e4567-e89b-42d3-a456-426614174002", too_deep)
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174002").is_empty(), "over-depth records are rejected")
	registry.call("register_entity", "123e4567-e89b-42d3-a456-426614174003", {"ok": true})
	var forbidden_delta_node: Node = Node.new()
	registry.call("commit_state_delta", "123e4567-e89b-42d3-a456-426614174003", {"bad": forbidden_delta_node})
	forbidden_delta_node.free()
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174003") == {"ok": true}, "invalid delta is rejected atomically")
	registry.call("commit_state_delta", "123e4567-e89b-42d3-a456-426614174003", {"infinite": INF})
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174003") == {"ok": true}, "non-finite numeric delta is rejected")
	var bounded_record: Dictionary = {}
	var overflowing_delta: Dictionary = {}
	for index: int in range(1024):
		bounded_record["base_%d" % index] = index
		overflowing_delta["delta_%d" % index] = index
	registry.call("register_entity", "123e4567-e89b-42d3-a456-426614174004", bounded_record)
	registry.call("commit_state_delta", "123e4567-e89b-42d3-a456-426614174004", overflowing_delta)
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174004").size() == 1024, "merged state exceeding container bounds is rejected atomically")
	registry.call("commit_state_delta", "123e4567-e89b-42d3-a456-426614174099", {"ok": true})
	check.call(registry.call("get_entity_state", "123e4567-e89b-42d3-a456-426614174099").is_empty(), "unknown entity delta does not create a record")

	var faction_script: Script = load(FACTION_PATH) as Script
	check.call(faction_script != null, "faction state script is available")
	if faction_script == null:
		return
	var faction_ids: Array[String] = ["corpos", "nomads", "civilians"]
	var factions: Object = faction_script.new(faction_ids)
	check.call(factions.has_method("get_faction_standing"), "faction standing lookup is available")
	check.call(factions.has_method("set_faction_standing") and factions.has_method("adjust_faction_standing"), "faction mutation contracts are available")
	check.call(factions.has_method("is_hostile") and factions.has_method("is_allied"), "threshold queries are available")
	if not factions.has_method("get_faction_standing") or not factions.has_method("set_faction_standing") or not factions.has_method("adjust_faction_standing") or not factions.has_method("is_hostile") or not factions.has_method("is_allied"):
		return
	factions.call("set_faction_standing", "corpos", -1000)
	check.call(factions.call("get_faction_standing", "corpos") == -100, "standing clamps to -100")
	check.call(factions.call("is_hostile", "corpos"), "hostility threshold classifies lower bound as hostile")
	factions.call("set_faction_standing", "corpos", 1000)
	check.call(factions.call("get_faction_standing", "corpos") == 100, "standing clamps to 100")
	check.call(factions.call("is_allied", "corpos"), "alliance threshold classifies upper bound as allied")
	factions.call("set_faction_standing", "nomads", -50)
	check.call(factions.call("is_hostile", "nomads"), "hostility threshold is inclusive")
	factions.call("set_faction_standing", "civilians", 50)
	check.call(factions.call("is_allied", "civilians"), "alliance threshold is inclusive")
	check.call(not factions.call("is_hostile", "civilians") and not factions.call("is_allied", "nomads"), "standing on opposite sides does not cross faction thresholds")
	check.call(factions.call("get_faction_standing", "unknown") == 0, "unknown faction lookup returns neutral zero")
	check.call(not factions.call("adjust_faction_standing", "unknown", 1), "unknown faction mutation is rejected")
	check.call(not factions.call("set_faction_standing", "unknown", 10), "unknown faction assignment is rejected")
	check.call(factions.call("adjust_faction_standing", "corpos", 1), "known faction accepts bounded integer adjustment")
	check.call(factions.call("get_faction_standing", "corpos") == 100, "adjustment preserves standing bounds")
	factions.call("set_faction_standing", "corpos", 100)
	factions.call("adjust_faction_standing", "corpos", 9223372036854775807)
	check.call(factions.call("get_faction_standing", "corpos") == 100, "maximum integer adjustment clamps without overflow")
	factions.call("set_faction_standing", "corpos", -100)
	factions.call("adjust_faction_standing", "corpos", -9223372036854775807 - 1)
	check.call(factions.call("get_faction_standing", "corpos") == -100, "minimum integer adjustment clamps without overflow")
	check.call(factions.call("configure_thresholds", -25, 60), "valid configurable faction thresholds are accepted")
	check.call(not factions.call("configure_thresholds", 60, -25), "overlapping faction thresholds are rejected")
	factions.call("set_faction_standing", "corpos", -25)
	check.call(factions.call("is_hostile", "corpos"), "configured hostile threshold is applied")
	factions.call("set_faction_standing", "corpos", 60)
	check.call(factions.call("is_allied", "corpos"), "configured allied threshold is applied")
