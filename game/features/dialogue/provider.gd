extends RefCounted
class_name DialogueProvider
## Transport contract only. Providers return untrusted JSON; they never mutate game state.

signal response_completed(npc_id: String, conversation_id: String, request_generation: int, response_json: String)


func submit_dialogue_request(_npc_id: String, _conversation_id: String, _request_generation: int, _context_payload: Dictionary) -> bool:
	return false
