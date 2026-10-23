extends RefCounted
class_name ResponseValidator
## Validates untrusted provider JSON into inert dialogue/proposal data.

const MAX_RESPONSE_BYTES: int = 8192
const MAX_DIALOGUE_LENGTH: int = 1200
const IDENTIFIER_PATTERN: String = "^[a-z0-9][a-z0-9_.-]{0,79}$"
const ACTION_PARAMETERS: Dictionary = {
	"offer_mission": "template_id",
	"initiate_trade": "inventory_id",
	"accept_into_faction": "faction_id",
	"begin_fight": "",
	"disclose_fact": "fact_id",
	"give_item": "item_id",
}

var _identifier_regex: RegEx = RegEx.new()


func _init() -> void:
	_identifier_regex.compile(IDENTIFIER_PATTERN)


func validate_json(response_json: String) -> Dictionary:
	if response_json.to_utf8_buffer().size() > MAX_RESPONSE_BYTES:
		return _failure("response_too_large")
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(response_json)
	if parse_error != OK:
		return _failure("malformed_json")
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("invalid_json_object")
	var root: Dictionary = parsed
	if root.size() != 2 or not root.has("dialogue_text") or not root.has("proposed_action"):
		return _failure("invalid_root_keys")
	var text_value: Variant = root["dialogue_text"]
	if typeof(text_value) != TYPE_STRING:
		return _failure("invalid_dialogue_type")
	var dialogue_text: String = text_value
	if dialogue_text.strip_edges().is_empty() or dialogue_text.length() > MAX_DIALOGUE_LENGTH:
		return _failure("invalid_dialogue_length")
	var action_result: Dictionary = _validate_action(root["proposed_action"])
	if not action_result.get("ok", false):
		return action_result
	var response: LLMResponse = LLMResponse.new()
	if not response.configure(dialogue_text, action_result.get("action")):
		return _failure("invalid_response")
	return {"ok": true, "response": response, "error": ""}


func _validate_action(raw_action: Variant) -> Dictionary:
	if raw_action == null:
		return {"ok": true, "action": null, "error": ""}
	if typeof(raw_action) != TYPE_DICTIONARY:
		return _failure("invalid_action_type")
	var action_object: Dictionary = raw_action
	if action_object.size() != 2 or not action_object.has("action") or not action_object.has("parameters"):
		return _failure("invalid_action_keys")
	if typeof(action_object["action"]) != TYPE_STRING or typeof(action_object["parameters"]) != TYPE_DICTIONARY:
		return _failure("invalid_action_field_types")
	var action_name: String = action_object["action"]
	if not ACTION_PARAMETERS.has(action_name):
		return _failure("unknown_action")
	var parameters: Dictionary = action_object["parameters"]
	var required_parameter: String = ACTION_PARAMETERS[action_name]
	if required_parameter.is_empty():
		if not parameters.is_empty():
			return _failure("unexpected_action_parameters")
	else:
		if parameters.size() != 1 or not parameters.has(required_parameter):
			return _failure("invalid_action_parameters")
		var parameter_value: Variant = parameters[required_parameter]
		if typeof(parameter_value) != TYPE_STRING or _identifier_regex.search(parameter_value) == null:
			return _failure("invalid_action_identifier")
	var validated_action: Dictionary = {"action": action_name, "parameters": parameters.duplicate(true)}
	return {"ok": true, "action": validated_action, "error": ""}


func _failure(reason: String) -> Dictionary:
	return {"ok": false, "response": null, "action": null, "error": reason}


func get_json_schema() -> Dictionary:
	var action_variants: Array[Dictionary] = [{"type": "null"}]
	for action_name: String in ACTION_PARAMETERS:
		var required_parameter: String = ACTION_PARAMETERS[action_name]
		var parameter_properties: Dictionary = {}
		var required_parameters: Array[String] = []
		if not required_parameter.is_empty():
			parameter_properties[required_parameter] = {"type": "string", "pattern": IDENTIFIER_PATTERN, "maxLength": ContextSnapshot.MAX_IDENTIFIER_LENGTH}
			required_parameters.append(required_parameter)
		action_variants.append({
			"type": "object",
			"additionalProperties": false,
			"required": ["action", "parameters"],
			"properties": {
				"action": {"type": "string", "enum": [action_name]},
				"parameters": {
					"type": "object",
					"additionalProperties": false,
					"required": required_parameters,
					"properties": parameter_properties,
				},
			},
		})
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["dialogue_text", "proposed_action"],
		"properties": {
			"dialogue_text": {"type": "string", "minLength": 1, "maxLength": MAX_DIALOGUE_LENGTH},
			"proposed_action": {"oneOf": action_variants},
		},
	}
