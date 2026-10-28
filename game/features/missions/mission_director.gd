extends RefCounted
class_name MissionDirector
## Owns deterministic mission lifecycle and its data-only CORE-04 domain snapshot.

signal mission_changed(mission_id: String, state: String, credits: int)

const SNAPSHOT_VERSION: int = 1
const MAX_MISSIONS: int = 128
const MAX_CREDITS: int = 100000
const FAILURE_REASONS: Array[String] = ["target_lost", "deadline_elapsed", "objective_invalidated"]
const STATES: Array[String] = ["offered", "accepted", "active", "completed", "failed"]

var _templates: Dictionary = {}
var _registry: EntityRegistry
var _factions: FactionState
var _target_reachable: Callable
var _missions: Dictionary = {}
var _credits: int = 0
var _starting_credits: int = 0
var _configured: bool = false


func configure(templates: Array[MissionTemplate], registry: EntityRegistry, factions: FactionState, target_reachable: Callable, starting_credits: int = 0) -> bool:
	if _configured or registry == null or factions == null or not target_reachable.is_valid() or templates.is_empty() or starting_credits < 0 or starting_credits > MAX_CREDITS:
		return false
	var candidate: Dictionary = {}
	for template: MissionTemplate in templates:
		if template == null or not template.is_valid() or candidate.has(template.template_id):
			return false
		candidate[template.template_id] = template.duplicate(true) as MissionTemplate
	_templates = candidate
	_registry = registry
	_factions = factions
	_target_reachable = target_reachable
	_starting_credits = starting_credits
	_credits = starting_credits
	_configured = true
	return true


func offer_mission(template_id: String) -> Dictionary:
	if not _configured or not _templates.has(template_id):
		return _failure("unknown_template")
	var template: MissionTemplate = _templates[template_id]
	var mission_id: String = _mission_id(template)
	if _missions.has(mission_id):
		return {"ok": true, "mission_id": mission_id, "fallback_text": template.authored_fallback_offer, "mission": get_mission(mission_id), "existing": true}
	if _missions.size() >= MAX_MISSIONS:
		return _failure("mission_limit")
	if not _template_faction_eligible(template):
		var faction_error: String = "unknown_faction" if not _factions.snapshot_standings().has(template.faction_id) else "faction_ineligible"
		return _failure(faction_error)
	if not _registry.has_entity(template.target_uuid):
		return _failure("target_missing")
	var target_state: Dictionary = _registry.get_entity_state(template.target_uuid)
	if typeof(target_state.get("collected")) != TYPE_BOOL or target_state["collected"]:
		return _failure("target_unavailable")
	var reachability_result: Variant = _target_reachable.call(template.target_uuid)
	if typeof(reachability_result) != TYPE_BOOL or not reachability_result:
		return _failure("target_unreachable")
	var reward_transaction_id: String = _reward_transaction_id(template)
	var mission: Dictionary = {
		"mission_id": mission_id,
		"template_id": template.template_id,
		"target_uuid": template.target_uuid,
		"state": "offered",
		"reward_credits": template.reward_credits,
		"reward_transaction_id": reward_transaction_id,
		"reward_claimed": false,
		"failed_reason": "",
	}
	_missions[mission_id] = mission
	mission_changed.emit(mission_id, "offered", _credits)
	return {"ok": true, "mission_id": mission_id, "fallback_text": template.authored_fallback_offer, "mission": mission.duplicate(true), "existing": false}


func get_authored_offer_text(template_id: String) -> String:
	if not _configured or not _templates.has(template_id):
		return ""
	return (_templates[template_id] as MissionTemplate).authored_fallback_offer


func accept_mission(mission_id: String) -> bool:
	if not _missions.has(mission_id):
		return false
	var mission: Dictionary = _missions[mission_id]
	if mission["state"] == "offered":
		var template: MissionTemplate = _templates[mission["template_id"]]
		if not _template_faction_eligible(template):
			return false
		mission["state"] = "accepted"
		_missions[mission_id] = mission
		mission_changed.emit(mission_id, "accepted", _credits)
		return true
	return mission["state"] == "accepted" or mission["state"] == "active" or mission["state"] == "completed"


func activate_mission(mission_id: String) -> bool:
	if not _missions.has(mission_id):
		return false
	var mission: Dictionary = _missions[mission_id]
	if mission["state"] == "accepted":
		var template: MissionTemplate = _templates[mission["template_id"]]
		if not _template_faction_eligible(template):
			return false
		mission["state"] = "active"
		_missions[mission_id] = mission
		mission_changed.emit(mission_id, "active", _credits)
		return true
	return mission["state"] == "active"


func complete_mission(mission_id: String) -> bool:
	if not _missions.has(mission_id):
		return false
	var mission: Dictionary = _missions[mission_id]
	if mission["state"] == "completed":
		return true
	if mission["state"] != "active" or not _registry.has_entity(String(mission["target_uuid"])):
		return false
	var target_state: Dictionary = _registry.get_entity_state(String(mission["target_uuid"]))
	if typeof(target_state.get("collected")) != TYPE_BOOL or not target_state["collected"]:
		return false
	var reward: int = int(mission["reward_credits"])
	if reward < 0 or reward > MissionTemplate.MAX_REWARD_CREDITS or _credits > MAX_CREDITS - reward:
		return false
	_credits += reward
	mission["state"] = "completed"
	mission["reward_claimed"] = true
	_missions[mission_id] = mission
	mission_changed.emit(mission_id, "completed", _credits)
	return true


func fail_mission(mission_id: String, reason: String) -> bool:
	if not _missions.has(mission_id) or not FAILURE_REASONS.has(reason):
		return false
	var mission: Dictionary = _missions[mission_id]
	if mission["state"] == "failed":
		return mission["failed_reason"] == reason
	if mission["state"] != "active":
		return false
	mission["state"] = "failed"
	mission["failed_reason"] = reason
	_missions[mission_id] = mission
	mission_changed.emit(mission_id, "failed", _credits)
	return true


func get_mission(mission_id: String) -> Dictionary:
	return (_missions[mission_id] as Dictionary).duplicate(true) if _missions.has(mission_id) else {}


func get_credits() -> int:
	return _credits


## Deterministic vendor debit, bounded by the same authoritative wallet as rewards.
func spend_credits(amount: int) -> bool:
	if not _configured or amount <= 0 or amount > _credits:
		return false
	_credits -= amount
	mission_changed.emit("", "credits_spent", _credits)
	return true


func capture_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	var mission_ids: Array = _missions.keys()
	mission_ids.sort()
	for mission_id_variant: Variant in mission_ids:
		rows.append((_missions[mission_id_variant] as Dictionary).duplicate(true))
	return {"version": SNAPSHOT_VERSION, "credits": _credits, "missions": rows}


func prepare_snapshot(candidate: Variant) -> Dictionary:
	if not _configured or typeof(candidate) != TYPE_DICTIONARY or candidate.size() != 3:
		return {"ok": false}
	if typeof(candidate.get("version")) != TYPE_INT or candidate["version"] != SNAPSHOT_VERSION:
		return {"ok": false}
	if typeof(candidate.get("credits")) != TYPE_INT or candidate["credits"] < 0 or candidate["credits"] > MAX_CREDITS:
		return {"ok": false}
	if typeof(candidate.get("missions")) != TYPE_ARRAY or candidate["missions"].size() > MAX_MISSIONS:
		return {"ok": false}
	var replacement: Dictionary = {}
	var earned_credits: int = 0
	for row_variant: Variant in candidate["missions"]:
		if typeof(row_variant) != TYPE_DICTIONARY or not _valid_mission_record(row_variant):
			return {"ok": false}
		var row: Dictionary = row_variant
		var mission_id: String = row["mission_id"]
		if replacement.has(mission_id):
			return {"ok": false}
		replacement[mission_id] = row.duplicate(true)
		if row["reward_claimed"]:
			earned_credits += int(row["reward_credits"])
	# Spending lowers the balance; it cannot exceed the authored start plus rewards.
	if int(candidate["credits"]) > _starting_credits + earned_credits:
		return {"ok": false}
	return {"ok": true, "prepared": {"credits": int(candidate["credits"]), "missions": replacement}}


func commit_prepared_snapshot(prepared: Dictionary) -> void:
	_credits = int(prepared["credits"])
	_missions = (prepared["missions"] as Dictionary).duplicate(true)


func _valid_mission_record(row: Dictionary) -> bool:
	const REQUIRED_KEYS: Array[String] = ["mission_id", "template_id", "target_uuid", "state", "reward_credits", "reward_transaction_id", "reward_claimed", "failed_reason"]
	if row.size() != REQUIRED_KEYS.size():
		return false
	for key: String in REQUIRED_KEYS:
		if not row.has(key):
			return false
	for key: String in ["mission_id", "template_id", "target_uuid", "reward_transaction_id", "state", "failed_reason"]:
		if typeof(row[key]) != TYPE_STRING:
			return false
	if typeof(row["reward_credits"]) != TYPE_INT:
		return false
	if typeof(row["template_id"]) != TYPE_STRING or not _templates.has(row["template_id"]):
		return false
	var template: MissionTemplate = _templates[row["template_id"]]
	if row["mission_id"] != _mission_id(template) or row["target_uuid"] != template.target_uuid:
		return false
	if row["reward_transaction_id"] != _reward_transaction_id(template) or row["reward_credits"] != template.reward_credits:
		return false
	if typeof(row["state"]) != TYPE_STRING or not STATES.has(row["state"]):
		return false
	if typeof(row["reward_claimed"]) != TYPE_BOOL or typeof(row["failed_reason"]) != TYPE_STRING:
		return false
	if row["reward_claimed"] != (row["state"] == "completed"):
		return false
	if row["state"] == "failed":
		return FAILURE_REASONS.has(row["failed_reason"])
	return row["failed_reason"].is_empty()


func _mission_id(template: MissionTemplate) -> String:
	return "mission_%s_%s" % [template.template_id, template.target_uuid.replace("-", "")]


func _reward_transaction_id(template: MissionTemplate) -> String:
	return "reward_%s" % _mission_id(template)


func _template_faction_eligible(template: MissionTemplate) -> bool:
	return _factions.snapshot_standings().has(template.faction_id) \
		and not _factions.is_hostile(template.faction_id) \
		and _factions.get_faction_standing(template.faction_id) >= template.minimum_standing


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "fallback_text": ""}
