extends RefCounted
class_name LLMResponse
## Validated dialogue data only. Proposed actions are inert and require later dispatch policy.

var dialogue_text: String = ""
var proposed_action: Variant = null


func configure(text: String, action: Variant) -> bool:
	if text.is_empty() or text.length() > 1200:
		return false
	if action != null and typeof(action) != TYPE_DICTIONARY:
		return false
	dialogue_text = text
	proposed_action = action.duplicate(true) if action is Dictionary else null
	return true


func to_dictionary() -> Dictionary:
	return {
		"dialogue_text": dialogue_text,
		"proposed_action": proposed_action.duplicate(true) if proposed_action is Dictionary else null,
	}
