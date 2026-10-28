extends RefCounted
class_name FactionRules
## Reads hostility/alliance directly from CORE-02; it keeps no standing snapshot.

var _faction_state: FactionState
var _configured: bool = false


func configure(faction_state: FactionState) -> bool:
	if _configured or faction_state == null:
		return false
	_faction_state = faction_state
	_configured = true
	return true


func evaluate_target_hostility(target_faction: String) -> bool:
	return _configured and _faction_state.is_hostile(target_faction)


func evaluate_target_alliance(target_faction: String) -> bool:
	return _configured and _faction_state.is_allied(target_faction)
