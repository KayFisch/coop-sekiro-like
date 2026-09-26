extends Camera2D

const SHAKE_RETURN_TIME = 0.2

var _shake_tween: Tween


func _ready():
	# Let the last shake settle even if the hit that caused it paused the game.
	process_mode = Node.PROCESS_MODE_ALWAYS


func shake(strength = 5.0):
	if _shake_tween:
		_shake_tween.kill()
	offset = Vector2.from_angle(randf() * TAU) * strength
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, SHAKE_RETURN_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
