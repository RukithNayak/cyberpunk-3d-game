extends Node3D
## Regression fixture: scene entry may synchronously invalidate a load generation.

func _ready() -> void:
	var redirect: Callable = get_parent().get_meta("redirect_on_ready")
	redirect.call()
