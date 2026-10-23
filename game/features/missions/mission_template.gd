extends Resource
class_name MissionTemplate
## Authored, bounded retrieval mission data. Contains no runtime state or Nodes.

const MAX_TEMPLATE_ID_LENGTH: int = 32
const MAX_REWARD_CREDITS: int = 1000
const MAX_TEXT_LENGTH: int = 240
const TEMPLATE_ID_PATTERN: String = "^[a-z][a-z0-9_-]{0,31}$"
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

@export var template_id: String = ""
@export var target_uuid: String = ""
@export var faction_id: String = ""
@export_range(-100, 100, 1) var minimum_standing: int = -100
@export_range(0, MAX_REWARD_CREDITS, 1) var reward_credits: int = 0
@export var target_label: String = ""
@export var authored_fallback_offer: String = ""

var _template_id_regex: RegEx = RegEx.new()
var _uuid_regex: RegEx = RegEx.new()


func _init() -> void:
	_template_id_regex.compile(TEMPLATE_ID_PATTERN)
	_uuid_regex.compile(UUID_PATTERN)


func is_valid() -> bool:
	if template_id.length() > MAX_TEMPLATE_ID_LENGTH or _template_id_regex.search(template_id) == null:
		return false
	if _uuid_regex.search(target_uuid) == null or not _is_valid_faction_id(faction_id):
		return false
	if minimum_standing < -100 or minimum_standing > 100:
		return false
	if reward_credits < 0 or reward_credits > MAX_REWARD_CREDITS:
		return false
	if target_label.strip_edges().is_empty() or target_label.length() > MAX_TEXT_LENGTH:
		return false
	return not authored_fallback_offer.strip_edges().is_empty() and authored_fallback_offer.length() <= MAX_TEXT_LENGTH


func _is_valid_faction_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value != value.to_lower():
		return false
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if index == 0 and not (codepoint >= 97 and codepoint <= 122):
			return false
		if not (codepoint >= 97 and codepoint <= 122 or codepoint >= 48 and codepoint <= 57 or codepoint == 95):
			return false
	return true
