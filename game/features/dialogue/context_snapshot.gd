extends RefCounted
class_name ContextSnapshot
## Bounded, JSON-safe context projection. It stores no Nodes and executes no model output.

const MAX_IDENTIFIER_LENGTH: int = 80
const MAX_DISPLAY_NAME_LENGTH: int = 80
const MAX_FACTS: int = 32
const MAX_FACT_LENGTH: int = 240
const MAX_MEMORY_LENGTH: int = 1200
const MAX_MISSION_TEMPLATES: int = 32
const MAX_JSON_BYTES: int = 8192
const IDENTIFIER_PATTERN: String = "^[a-z0-9][a-z0-9_.-]{0,79}$"

var npc_identity: Dictionary = {}
var scoped_facts: Array[String] = []
var memory_summary: String = ""
var eligible_mission_templates: Array[String] = []
var faction_standing: int = 0

var _identifier_regex: RegEx = RegEx.new()
var _configured: bool = false


func _init() -> void:
	_identifier_regex.compile(IDENTIFIER_PATTERN)


func configure(npc_id: String, display_name: String, faction_id: String, facts: Array[String], memory: String, eligible_templates: Array[String], standing: int) -> bool:
	if _configured:
		return false
	if not _is_identifier(npc_id) or not _is_identifier(faction_id):
		return false
	if display_name.strip_edges().is_empty() or display_name.length() > MAX_DISPLAY_NAME_LENGTH:
		return false
	if facts.size() > MAX_FACTS or eligible_templates.size() > MAX_MISSION_TEMPLATES:
		return false
	if memory.length() > MAX_MEMORY_LENGTH or standing < -100 or standing > 100:
		return false
	var unique_facts: Dictionary = {}
	var copied_facts: Array[String] = []
	for fact: String in facts:
		if fact.strip_edges().is_empty() or fact.length() > MAX_FACT_LENGTH:
			return false
		if unique_facts.has(fact):
			return false
		unique_facts[fact] = true
		copied_facts.append(fact)
	var unique_templates: Dictionary = {}
	var copied_templates: Array[String] = []
	for template_id: String in eligible_templates:
		if not _is_identifier(template_id) or unique_templates.has(template_id):
			return false
		unique_templates[template_id] = true
		copied_templates.append(template_id)
	npc_identity = {"npc_id": npc_id, "display_name": display_name.strip_edges(), "faction_id": faction_id}
	scoped_facts = copied_facts
	memory_summary = memory
	eligible_mission_templates = copied_templates
	faction_standing = standing
	if JSON.stringify(to_payload()).to_utf8_buffer().size() > MAX_JSON_BYTES:
		_clear()
		return false
	_configured = true
	return true


func to_payload() -> Dictionary:
	if not _configured and npc_identity.is_empty():
		return {}
	return {
		"npc_identity": npc_identity.duplicate(true),
		"scoped_facts": scoped_facts.duplicate(),
		"memory_summary": memory_summary,
		"eligible_mission_templates": eligible_mission_templates.duplicate(),
		"faction_standing": faction_standing,
	}


func to_json_string() -> String:
	if not _configured:
		return ""
	return JSON.stringify(to_payload())


func is_configured() -> bool:
	return _configured


func _is_identifier(value: String) -> bool:
	return value.length() <= MAX_IDENTIFIER_LENGTH and _identifier_regex.search(value) != null


func _clear() -> void:
	npc_identity.clear()
	scoped_facts.clear()
	memory_summary = ""
	eligible_mission_templates.clear()
	faction_standing = 0
	_configured = false
