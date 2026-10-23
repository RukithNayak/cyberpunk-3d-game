extends RefCounted

const RETRIEVAL_TARGET_UUID: String = "00000000-0000-4000-8000-000000000032"

var _save_director: MissionDirector
var _save_player: Dictionary = {"fixture": "npc03"}
var _mission_signal_count: int = 0
var _last_mission_signal: Array = []


func run(check: Callable) -> void:
	_test_lifecycle_signals(check)
	_test_offer_eligibility(check)
	_test_lifecycle_and_reward_idempotence(check)
	_test_failed_objective(check)
	_test_persisted_states_and_unload(check)
	_test_snapshot_validation(check)
	_test_save_store_domain_round_trip(check)


func _test_lifecycle_signals(check: Callable) -> void:
	var fixture: Dictionary = _fixture(true, 0, true)
	var director: MissionDirector = fixture["director"]
	_mission_signal_count = 0
	_last_mission_signal.clear()
	director.mission_changed.connect(_on_mission_changed)
	var offer: Dictionary = director.offer_mission("retrieve_signal_cache")
	var mission_id: String = String(offer.get("mission_id", ""))
	check.call(_mission_signal_count == 1 and _last_mission_signal == [mission_id, "offered", 0], "new mission offer publishes one lifecycle event after commit")
	director.offer_mission("retrieve_signal_cache")
	check.call(_mission_signal_count == 1, "idempotent repeated offer publishes no duplicate lifecycle event")
	director.accept_mission(mission_id)
	director.accept_mission(mission_id)
	director.activate_mission(mission_id)
	check.call(_mission_signal_count == 3 and _last_mission_signal == [mission_id, "active", 0], "mission emits only actual accepted and active transitions")
	(fixture["registry"] as EntityRegistry).try_commit_state_delta(RETRIEVAL_TARGET_UUID, {"collected": true})
	director.complete_mission(mission_id)
	check.call(_mission_signal_count == 4 and _last_mission_signal == [mission_id, "completed", 125], "completion event includes credits committed with the reward")
	var restored: MissionDirector = MissionDirector.new()
	restored.configure([fixture["template"]], fixture["registry"], fixture["factions"], func(_uuid: String) -> bool: return true)
	_mission_signal_count = 0
	restored.commit_prepared_snapshot(restored.prepare_snapshot(director.capture_snapshot())["prepared"])
	check.call(_mission_signal_count == 0, "snapshot hydration emits no user-facing lifecycle notifications")


func _on_mission_changed(mission_id: String, state: String, credits: int) -> void:
	_mission_signal_count += 1
	_last_mission_signal = [mission_id, state, credits]


func _test_offer_eligibility(check: Callable) -> void:
	var authored_template: MissionTemplate = load("res://features/missions/retrieve_signal_cache.tres") as MissionTemplate
	check.call(authored_template != null and authored_template.is_valid() and authored_template.target_uuid == RETRIEVAL_TARGET_UUID, "shipped retrieval resource binds the existing stable loot target and authored fallback")
	var missing: Dictionary = _fixture(true, 0, false)
	var missing_result: Dictionary = (missing["director"] as MissionDirector).offer_mission("retrieve_signal_cache")
	check.call(not missing_result["ok"] and missing_result["reason"] == "target_missing", "offer rejects a target absent from the persistent world registry")

	var unreachable: Dictionary = _fixture(false, 0, true)
	var unreachable_result: Dictionary = (unreachable["director"] as MissionDirector).offer_mission("retrieve_signal_cache")
	check.call(not unreachable_result["ok"] and unreachable_result["reason"] == "target_unreachable", "offer rejects an existing but unreachable retrieval fixture")

	var hostile: Dictionary = _fixture(true, -50, true)
	var hostile_result: Dictionary = (hostile["director"] as MissionDirector).offer_mission("retrieve_signal_cache")
	check.call(not hostile_result["ok"] and hostile_result["reason"] == "faction_ineligible", "hostile issuer faction cannot offer the mission")

	var low_standing: Dictionary = _fixture(true, -10, true)
	var low_template: MissionTemplate = low_standing["template"]
	low_template.minimum_standing = 10
	var low_reconfigured: Dictionary = _fixture_with_template(true, -10, low_template)
	var low_result: Dictionary = (low_reconfigured["director"] as MissionDirector).offer_mission("retrieve_signal_cache")
	check.call(not low_result["ok"] and low_result["reason"] == "faction_ineligible", "issuer standing must meet the authored template requirement")
	var stale_offer: Dictionary = _fixture(true, 0, true)
	var stale_director: MissionDirector = stale_offer["director"]
	var stale_mission_id: String = stale_director.offer_mission("retrieve_signal_cache")["mission_id"]
	(stale_offer["factions"] as FactionState).set_faction_standing("night_market", -50)
	check.call(not stale_director.accept_mission(stale_mission_id) and stale_director.get_mission(stale_mission_id)["state"] == "offered", "stale offer rechecks current faction authority before acceptance")
	check.call((low_reconfigured["director"] as MissionDirector).get_authored_offer_text("retrieve_signal_cache") == low_template.authored_fallback_offer, "authored fallback offer is available without a model response")

	var invalid_template: MissionTemplate = _template()
	invalid_template.reward_credits = MissionTemplate.MAX_REWARD_CREDITS + 1
	var invalid_templates: Array[MissionTemplate] = [invalid_template]
	var invalid_director: MissionDirector = MissionDirector.new()
	check.call(not invalid_director.configure(invalid_templates, EntityRegistry.new(), FactionState.new(["night_market"]), func(_uuid: String) -> bool: return true), "invalid reward bounds reject mission-template configuration")


func _test_lifecycle_and_reward_idempotence(check: Callable) -> void:
	var fixture: Dictionary = _fixture(true, 0, true)
	var director: MissionDirector = fixture["director"]
	var offer: Dictionary = director.offer_mission("retrieve_signal_cache")
	var mission_id: String = offer.get("mission_id", "")
	check.call(offer["ok"] and not mission_id.is_empty(), "eligible retrieval template creates a deterministic mission offer")
	check.call(offer["fallback_text"] == (fixture["template"] as MissionTemplate).authored_fallback_offer, "offer carries authored text for provider-failure fallback")
	var repeat_offer: Dictionary = director.offer_mission("retrieve_signal_cache")
	check.call(repeat_offer["ok"] and repeat_offer["existing"] and repeat_offer["mission_id"] == mission_id, "repeated offer returns the same mission instead of duplicating it")
	check.call(String(offer["mission"]["target_uuid"]) == RETRIEVAL_TARGET_UUID and String(offer["mission"]["reward_transaction_id"]).begins_with("reward_"), "target and reward transaction identities are stable and authored")
	check.call(director.accept_mission(mission_id) and director.accept_mission(mission_id), "offered job accepts idempotently")
	check.call(director.activate_mission(mission_id) and director.activate_mission(mission_id), "accepted job becomes active idempotently")
	check.call(not director.complete_mission(mission_id) and director.get_mission(mission_id)["state"] == "active" and director.get_credits() == 0, "model claims cannot complete an objective before code-owned retrieval state")
	var registry: EntityRegistry = fixture["registry"]
	check.call(registry.try_commit_state_delta(RETRIEVAL_TARGET_UUID, {"collected": true}), "retrieval fixture records collection in authoritative world state")
	check.call(director.complete_mission(mission_id), "active retrieval completes after the registered target is collected")
	check.call(director.get_mission(mission_id)["reward_claimed"] and director.get_credits() == 125, "completion commits the bounded credit reward once")
	check.call(director.complete_mission(mission_id) and director.get_credits() == 125, "replayed completion cannot duplicate the reward")
	check.call(not director.fail_mission(mission_id, "target_lost"), "completed mission cannot transition to failed")


func _test_failed_objective(check: Callable) -> void:
	var fixture: Dictionary = _fixture(true, 0, true)
	var director: MissionDirector = fixture["director"]
	var offer: Dictionary = director.offer_mission("retrieve_signal_cache")
	var mission_id: String = offer["mission_id"]
	check.call(not director.fail_mission(mission_id, "model_says_failed"), "unrecognized failure reasons are rejected")
	check.call(director.accept_mission(mission_id) and director.activate_mission(mission_id), "failure fixture reaches active state")
	check.call(director.fail_mission(mission_id, "target_lost") and director.fail_mission(mission_id, "target_lost"), "objective failure is authoritative and idempotent")
	check.call(director.get_mission(mission_id)["state"] == "failed" and director.get_credits() == 0, "failed objective remains terminal and grants no reward")
	check.call(not director.complete_mission(mission_id), "failed mission cannot be completed by a later claim")


func _test_persisted_states_and_unload(check: Callable) -> void:
	for expected_state: String in ["offered", "accepted", "active", "completed", "failed"]:
		var fixture: Dictionary = _fixture(true, 0, true)
		var director: MissionDirector = fixture["director"]
		var mission_id: String = director.offer_mission("retrieve_signal_cache")["mission_id"]
		if expected_state in ["accepted", "active", "completed", "failed"]:
			director.accept_mission(mission_id)
		if expected_state in ["active", "completed", "failed"]:
			director.activate_mission(mission_id)
		if expected_state == "completed":
			(fixture["registry"] as EntityRegistry).try_commit_state_delta(RETRIEVAL_TARGET_UUID, {"collected": true})
			director.complete_mission(mission_id)
		elif expected_state == "failed":
			director.fail_mission(mission_id, "target_lost")
		var snapshot: Dictionary = director.capture_snapshot()
		(fixture["target_active"] as Dictionary)["reachable"] = false
		var restored: MissionDirector = MissionDirector.new()
		var configured: bool = restored.configure([fixture["template"]], fixture["registry"], fixture["factions"], func(_uuid: String) -> bool: return bool(fixture["target_active"]["reachable"]))
		var prepared: Dictionary = restored.prepare_snapshot(snapshot)
		var committed: bool = bool(prepared.get("ok", false))
		if committed:
			restored.commit_prepared_snapshot(prepared["prepared"])
		check.call(configured and committed and restored.get_mission(mission_id)["state"] == expected_state, "CORE-04 data snapshot restores %s state after fixture unload" % expected_state)
		check.call(restored.capture_snapshot() == snapshot, "restored %s state recaptures deterministically" % expected_state)


func _test_snapshot_validation(check: Callable) -> void:
	var fixture: Dictionary = _fixture(true, 0, true)
	var director: MissionDirector = fixture["director"]
	var original: Dictionary = director.capture_snapshot()
	var invalid_version: Dictionary = original.duplicate(true)
	invalid_version["version"] = 99
	check.call(not director.prepare_snapshot(invalid_version).get("ok", false) and director.capture_snapshot() == original, "unsupported mission snapshot version rejects without mutating live state")
	var invented_credit: Dictionary = original.duplicate(true)
	invented_credit["credits"] = 500
	check.call(not director.prepare_snapshot(invented_credit).get("ok", false), "credits without a completed authored reward reject during restore")
	var offer: Dictionary = director.offer_mission("retrieve_signal_cache")
	var forged: Dictionary = director.capture_snapshot()
	forged["missions"][0]["reward_credits"] = MissionTemplate.MAX_REWARD_CREDITS + 1
	check.call(not director.prepare_snapshot(forged).get("ok", false) and director.get_mission(offer["mission_id"])["state"] == "offered", "out-of-bound reward snapshot rejects without altering mission state")
	var wrong_type: Dictionary = director.capture_snapshot()
	director.offer_mission("retrieve_signal_cache")
	wrong_type = director.capture_snapshot()
	wrong_type["missions"][0]["reward_credits"] = 125.0
	check.call(not director.prepare_snapshot(wrong_type).get("ok", false), "mission snapshot preserves integer reward types instead of accepting float substitution")


func _test_save_store_domain_round_trip(check: Callable) -> void:
	var fixture: Dictionary = _fixture(true, 0, true)
	_save_director = fixture["director"]
	var mission_id: String = _save_director.offer_mission("retrieve_signal_cache")["mission_id"]
	_save_director.accept_mission(mission_id)
	_save_director.activate_mission(mission_id)
	var registry: EntityRegistry = fixture["registry"]
	var factions: FactionState = fixture["factions"]
	var adapters: SnapshotAdapters = SnapshotAdapters.new(
		registry, factions,
		Callable(self, "_capture_save_player"), Callable(self, "_prepare_save_player"), Callable(self, "_commit_save_player"),
		Callable(self, "_capture_save_domains"), Callable(self, "_prepare_save_domains"), Callable(self, "_commit_save_domains"))
	var directory: String = "user://npc03_save_tests_%d" % OS.get_process_id()
	var store: SaveStore = SaveStore.new(directory, adapters.capture_snapshot, adapters.validate_snapshot, adapters.apply_snapshot)
	var save_result: Error = store.save_to_disk(0)
	var restored: MissionDirector = MissionDirector.new()
	var templates: Array[MissionTemplate] = [fixture["template"]]
	var restored_ok: bool = restored.configure(templates, registry, factions, func(_uuid: String) -> bool: return false)
	_save_director = restored
	var load_result: Error = store.load_from_disk(0)
	var restored_state: Dictionary = restored.get_mission(mission_id)
	check.call(save_result == OK and restored_ok and load_result == OK and restored_state.get("state") == "active", "SaveStore restores an accepted mission after its target fixture unloads")
	check.call(restored.capture_snapshot()["missions"][0]["target_uuid"] == RETRIEVAL_TARGET_UUID, "disk round trip preserves stable target identity without storing scene Nodes")
	var save_path: String = ProjectSettings.globalize_path(directory.path_join("slot_00.save"))
	for path: String in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _capture_save_player() -> Dictionary:
	return _save_player.duplicate(true)


func _prepare_save_player(candidate: Dictionary) -> Dictionary:
	return {"ok": true, "prepared": candidate.duplicate(true)}


func _commit_save_player(candidate: Dictionary) -> void:
	_save_player = candidate.duplicate(true)


func _capture_save_domains() -> Dictionary:
	return {"missions": _save_director.capture_snapshot()}


func _prepare_save_domains(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 1 or not candidate.has("missions"):
		return {"ok": false}
	return _save_director.prepare_snapshot(candidate["missions"])


func _commit_save_domains(prepared: Dictionary) -> void:
	_save_director.commit_prepared_snapshot(prepared)


func _fixture(target_reachable: bool, standing: int, include_target: bool) -> Dictionary:
	var template: MissionTemplate = _template()
	return _fixture_with_template(target_reachable, standing, template, include_target)


func _fixture_with_template(target_reachable: bool, standing: int, template: MissionTemplate, include_target: bool = true) -> Dictionary:
	var registry: EntityRegistry = EntityRegistry.new()
	if include_target:
		registry.register_entity(RETRIEVAL_TARGET_UUID, {"collected": false})
	var factions: FactionState = FactionState.new(["night_market"])
	factions.set_faction_standing("night_market", standing)
	var target_active: Dictionary = {"reachable": target_reachable}
	var templates: Array[MissionTemplate] = [template]
	var director: MissionDirector = MissionDirector.new()
	director.configure(templates, registry, factions, func(_uuid: String) -> bool: return bool(target_active["reachable"]))
	return {"director": director, "registry": registry, "factions": factions, "template": template, "target_active": target_active}


func _template() -> MissionTemplate:
	var template: MissionTemplate = MissionTemplate.new()
	template.template_id = "retrieve_signal_cache"
	template.target_uuid = RETRIEVAL_TARGET_UUID
	template.faction_id = "night_market"
	template.minimum_standing = 0
	template.reward_credits = 125
	template.target_label = "Signal cache"
	template.authored_fallback_offer = "Recover the signal cache from the transit underpass."
	return template
