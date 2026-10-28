extends RefCounted
class_name NpcMemory
## Data-only NPC knowledge and dialogue history. It never stores Nodes or runs actions.

const SNAPSHOT_VERSION: int = 1
const MAX_NPCS: int = 64
const MAX_FACTS_PER_NPC: int = 32
const MAX_HISTORY_LINES: int = 32
const MAX_LINE_LENGTH: int = 500
const MAX_SUMMARY_LENGTH: int = 1200
const IDENTIFIER_PATTERN: String = "^[a-z0-9][a-z0-9_.-]{0,79}$"
const FACT_SOURCES: Array[String] = ["witnessed", "disclosed"]
const SPEAKERS: Array[String] = ["player", "npc", "system"]

var _fact_catalog: Dictionary = {}
var _authorize_fact_evidence: Callable
var _npcs: Dictionary = {}
var _identifier_regex: RegEx = RegEx.new()
var _configured: bool = false


func _init() -> void:
	_identifier_regex.compile(IDENTIFIER_PATTERN)


func configure(fact_catalog: Dictionary, authorize_fact_evidence: Callable) -> bool:
	if _configured or fact_catalog.is_empty() or fact_catalog.size() > 1024 or not authorize_fact_evidence.is_valid():
		return false
	var catalog_copy: Dictionary = {}
	for fact_id_variant: Variant in fact_catalog:
		if typeof(fact_id_variant) != TYPE_STRING or typeof(fact_catalog[fact_id_variant]) != TYPE_STRING:
			return false
		var fact_id: String = fact_id_variant
		var text: String = fact_catalog[fact_id]
		if not _valid_identifier(fact_id) or text.strip_edges().is_empty() or text.length() > ContextSnapshot.MAX_FACT_LENGTH:
			return false
		catalog_copy[fact_id] = text
	_fact_catalog = catalog_copy
	_authorize_fact_evidence = authorize_fact_evidence
	_configured = true
	return true


func record_fact(npc_id: String, fact_id: String, source: String, evidence_id: String) -> bool:
	if not _configured or not _valid_identifier(npc_id) or not _fact_catalog.has(fact_id) or not FACT_SOURCES.has(source) or not _valid_identifier(evidence_id):
		return false
	var authorization: Variant = _authorize_fact_evidence.call(npc_id, fact_id, source, evidence_id)
	if typeof(authorization) != TYPE_BOOL or not authorization:
		return false
	var facts: Array[Dictionary] = _get_fact_records(npc_id)
	for fact: Dictionary in facts:
		if fact["fact_id"] == fact_id:
			return fact["source"] == source and fact["evidence_id"] == evidence_id
	if facts.size() >= MAX_FACTS_PER_NPC or not _ensure_npc(npc_id):
		return false
	facts.append({"fact_id": fact_id, "source": source, "evidence_id": evidence_id})
	(_npcs[npc_id] as Dictionary)["facts"] = facts
	return true


func record_dialogue_line(npc_id: String, conversation_id: String, speaker: String, text: String) -> bool:
	if not _configured or not _valid_identifier(npc_id) or not _valid_identifier(conversation_id) or not SPEAKERS.has(speaker):
		return false
	if text.strip_edges().is_empty() or text.length() > MAX_LINE_LENGTH or not _ensure_npc(npc_id):
		return false
	var record: Dictionary = _npcs[npc_id]
	var history: Array[Dictionary] = []
	for line_variant: Variant in record["history"]:
		history.append((line_variant as Dictionary).duplicate(true))
	history.append({"conversation_id": conversation_id, "speaker": speaker, "text": text})
	while history.size() > MAX_HISTORY_LINES:
		history.pop_front()
	record["history"] = history
	_npcs[npc_id] = record
	return true


func set_derived_summary(npc_id: String, summary: String) -> bool:
	if not _configured or not _valid_identifier(npc_id) or summary.length() > MAX_SUMMARY_LENGTH or not _ensure_npc(npc_id):
		return false
	var record: Dictionary = _npcs[npc_id]
	record["summary"] = summary
	_npcs[npc_id] = record
	return true


func get_fact_texts(npc_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _configured or not _npcs.has(npc_id):
		return result
	var facts: Array = _npcs[npc_id]["facts"]
	for fact_variant: Variant in facts:
		var fact: Dictionary = fact_variant
		if _fact_catalog.has(fact["fact_id"]):
			result.append(String(_fact_catalog[fact["fact_id"]]))
	return result


func get_fact_records(npc_id: String) -> Array[Dictionary]:
	return _get_fact_records(npc_id)


func get_history(npc_id: String) -> Array[Dictionary]:
	if not _npcs.has(npc_id):
		return []
	return (_npcs[npc_id]["history"] as Array[Dictionary]).duplicate(true)


func get_summary(npc_id: String) -> String:
	return String(_npcs.get(npc_id, {}).get("summary", ""))


func capture_snapshot() -> Dictionary:
	if not _configured:
		return {}
	var records: Array[Dictionary] = []
	var npc_ids: Array = _npcs.keys()
	npc_ids.sort()
	for npc_id_variant: Variant in npc_ids:
		var record: Dictionary = (_npcs[npc_id_variant] as Dictionary).duplicate(true)
		record["npc_id"] = String(npc_id_variant)
		records.append(record)
	return {"version": SNAPSHOT_VERSION, "npcs": records}


func validate_snapshot(candidate: Variant) -> bool:
	return bool(prepare_snapshot(candidate).get("ok", false))


func prepare_snapshot(candidate: Variant) -> Dictionary:
	if not _configured or typeof(candidate) != TYPE_DICTIONARY or candidate.size() != 2:
		return {"ok": false}
	if typeof(candidate.get("version")) != TYPE_INT or candidate["version"] != SNAPSHOT_VERSION or typeof(candidate.get("npcs")) != TYPE_ARRAY or candidate["npcs"].size() > MAX_NPCS:
		return {"ok": false}
	var prepared_npcs: Dictionary = {}
	for record_variant: Variant in candidate["npcs"]:
		if typeof(record_variant) != TYPE_DICTIONARY:
			return {"ok": false}
		var record: Dictionary = record_variant
		if not _valid_npc_record(record) or prepared_npcs.has(record["npc_id"]):
			return {"ok": false}
		var copy: Dictionary = record.duplicate(true)
		var npc_id: String = String(copy["npc_id"])
		copy.erase("npc_id")
		prepared_npcs[npc_id] = copy
	return {"ok": true, "prepared": {"npcs": prepared_npcs}}


func commit_prepared_snapshot(prepared: Dictionary) -> void:
	_npcs = (prepared["npcs"] as Dictionary).duplicate(true)


func _valid_npc_record(record: Dictionary) -> bool:
	const REQUIRED_KEYS: Array[String] = ["npc_id", "facts", "history", "summary"]
	if record.size() != REQUIRED_KEYS.size():
		return false
	for key: String in REQUIRED_KEYS:
		if not record.has(key):
			return false
	if typeof(record["npc_id"]) != TYPE_STRING or not _valid_identifier(record["npc_id"]):
		return false
	if typeof(record["facts"]) != TYPE_ARRAY or record["facts"].size() > MAX_FACTS_PER_NPC:
		return false
	if typeof(record["history"]) != TYPE_ARRAY or record["history"].size() > MAX_HISTORY_LINES:
		return false
	if typeof(record["summary"]) != TYPE_STRING or record["summary"].length() > MAX_SUMMARY_LENGTH:
		return false
	var seen_fact_ids: Dictionary = {}
	for fact_variant: Variant in record["facts"]:
		if typeof(fact_variant) != TYPE_DICTIONARY:
			return false
		var fact: Dictionary = fact_variant
		if fact.size() != 3 or typeof(fact.get("fact_id")) != TYPE_STRING or typeof(fact.get("source")) != TYPE_STRING or typeof(fact.get("evidence_id")) != TYPE_STRING:
			return false
		var fact_id: String = fact["fact_id"]
		if not _fact_catalog.has(fact_id) or not FACT_SOURCES.has(fact["source"]) or not _valid_identifier(fact["evidence_id"]) or seen_fact_ids.has(fact_id):
			return false
		seen_fact_ids[fact_id] = true
	for line_variant: Variant in record["history"]:
		if typeof(line_variant) != TYPE_DICTIONARY:
			return false
		var line: Dictionary = line_variant
		if line.size() != 3 or typeof(line.get("conversation_id")) != TYPE_STRING or typeof(line.get("speaker")) != TYPE_STRING or typeof(line.get("text")) != TYPE_STRING:
			return false
		if not _valid_identifier(line["conversation_id"]) or not SPEAKERS.has(line["speaker"]) or line["text"].strip_edges().is_empty() or line["text"].length() > MAX_LINE_LENGTH:
			return false
	return true


func _ensure_npc(npc_id: String) -> bool:
	if _npcs.has(npc_id):
		return true
	if _npcs.size() >= MAX_NPCS:
		return false
	var facts: Array[Dictionary] = []
	var history: Array[Dictionary] = []
	_npcs[npc_id] = {"facts": facts, "history": history, "summary": ""}
	return true


func _get_fact_records(npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _npcs.has(npc_id):
		return result
	for record_variant: Variant in _npcs[npc_id]["facts"]:
		result.append((record_variant as Dictionary).duplicate(true))
	return result


func _valid_identifier(value: String) -> bool:
	return value.length() <= ContextSnapshot.MAX_IDENTIFIER_LENGTH and _identifier_regex.search(value) != null
