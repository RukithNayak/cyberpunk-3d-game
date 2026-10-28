extends RefCounted
class_name DialogueSnapshot
## Coordinates NPC-memory and mission SaveStore domains and builds live dialogue context.

const MEMORY_DOMAIN: String = "npc_memory"
const MISSION_DOMAIN: String = "missions"

var _memory: NpcMemory
var _missions: MissionDirector
var _factions: FactionState
var _opaque_domains: Dictionary = {}
var _configured: bool = false


func configure(memory: NpcMemory, missions: MissionDirector, factions: FactionState) -> bool:
	if _configured or memory == null or missions == null or factions == null:
		return false
	if memory.capture_snapshot().is_empty() or missions.capture_snapshot().is_empty():
		return false
	_memory = memory
	_missions = missions
	_factions = factions
	_configured = true
	return true


func build_context(npc_id: String, display_name: String, faction_id: String, eligible_templates: Array[String]) -> ContextSnapshot:
	if not _configured:
		return null
	var standings: Dictionary = _factions.snapshot_standings()
	if not standings.has(faction_id):
		return null
	var context: ContextSnapshot = ContextSnapshot.new()
	if not context.configure(npc_id, display_name, faction_id, _memory.get_fact_texts(npc_id), _memory.get_summary(npc_id), eligible_templates, int(standings[faction_id])):
		return null
	return context


func capture_domains() -> Dictionary:
	if not _configured:
		return {}
	var domains: Dictionary = _opaque_domains.duplicate(true)
	if domains.has(MEMORY_DOMAIN) or domains.has(MISSION_DOMAIN):
		return {}
	var memory_snapshot: Dictionary = _memory.capture_snapshot()
	var mission_snapshot: Dictionary = _missions.capture_snapshot()
	if memory_snapshot.is_empty() or mission_snapshot.is_empty():
		return {}
	domains[MEMORY_DOMAIN] = memory_snapshot
	domains[MISSION_DOMAIN] = mission_snapshot
	return domains


func prepare_domains(candidate: Variant) -> Dictionary:
	if not _configured or typeof(candidate) != TYPE_DICTIONARY:
		return {"ok": false}
	var domains: Dictionary = candidate
	if not domains.has(MEMORY_DOMAIN) or not domains.has(MISSION_DOMAIN):
		return {"ok": false}
	var memory_result: Dictionary = _memory.prepare_snapshot(domains[MEMORY_DOMAIN])
	var mission_result: Dictionary = _missions.prepare_snapshot(domains[MISSION_DOMAIN])
	if not memory_result.get("ok", false) or not mission_result.get("ok", false):
		return {"ok": false}
	var opaque: Dictionary = {}
	for key_variant: Variant in domains:
		var key: Variant = key_variant
		if key == MEMORY_DOMAIN or key == MISSION_DOMAIN:
			continue
		var value: Variant = domains[key]
		opaque[key] = value.duplicate(true) if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY else value
	return {
		"ok": true,
		"prepared": {
			"memory": memory_result["prepared"],
			"missions": mission_result["prepared"],
			"opaque_domains": opaque,
		},
	}


func commit_prepared_domains(prepared: Dictionary) -> void:
	_memory.commit_prepared_snapshot(prepared["memory"])
	_missions.commit_prepared_snapshot(prepared["missions"])
	_opaque_domains = (prepared["opaque_domains"] as Dictionary).duplicate(true)
