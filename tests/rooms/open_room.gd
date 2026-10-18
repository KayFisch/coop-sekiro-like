extends GymLevel
## An empty room for the tests (tests/test_moves.gd): a long floor and both players, nothing
## else. A test builds what it needs with the gym's helpers (solid(), ledge(), spikes()...).


func room_name() -> String:
	return "TEST ROOM"


func player_count() -> int:
	return 2


func _build():
	bounds = Rect2(0, -800, 2400, 1520)
	ground(0, bounds.end.x)
	respawn_point = Vector2(200, GROUND_Y - PLAYER_HALF)
