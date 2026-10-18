extends "res://tests/test_case.gd"
## The beat-ring's violet shard (levels/ring/ring.gd): it meets the partner's side of the circle
## exactly on its beat, the boss fight's partner hit, and comes there at ring_relay_slow, both the
## short way (the two on two sides) and the long way (on one side).


func test_violet_shard_pace():
	set_number("sync_window_delay", 0.18)
	set_number("sync_beat_time", 0.12)
	set_number("ring_relay_slow", 600.0)
	set_number("ring_relay_brake", 140.0)
	set_move("bifrons_stand_in", "off")
	await load_scene("res://levels/ring/ring.tscn")
	var ring = get_tree().current_scene
	var r = ring.radius()
	var a = ring.chest_angle()
	near(ring.relay_delay(), 0.24, 0.0001, "due 0.24 s after the parry (the middle of the beat)")
	for way in ["short", "long"]:
		var shard = ring.Orb.new()
		shard.ring = ring
		shard.side = -1.0
		shard.meet = 1.0 if way == "short" else -1.0
		shard.meet_u = PI if way == "short" else TAU - 2.0 * a
		shard.end_u = TAU - a
		shard.born = 0.0
		shard.beat = ring.relay_delay()
		ring._pace_relay(shard)
		near(shard.travelled(shard.beat), shard.meet_u, 0.0001, way + " way: at the spot on its beat")
		var speed = (shard.travelled(shard.beat + 0.0005) - shard.travelled(shard.beat - 0.0005)) / 0.001 * r
		near(speed, 600.0, 15.0, way + " way: at ring_relay_slow there")
		var fast = (shard.travelled(0.011) - shard.travelled(0.009)) / 0.002 * r
		check(fast > 1500.0, way + " way: very fast at first (%.0f px/s)" % fast)
		shard.free()
