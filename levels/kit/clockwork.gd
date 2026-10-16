@tool
class_name Clockwork
extends Node2D
## Base for the kit's pieces that go on the Beat clock (core/beat.gd): hammer, pendulum, beat
## step. None of them counts time itself; each works out where it is from the clock alone, so
## all of them stay in time together and nothing drifts. In the Godot editor they run on a
## stand-in clock at their room's BPM, so you see them move while you build.
## A rhythm is a `pattern` of counts over `bars` bars (1-4 in one bar, 1-8 in two, ...),
## shifted `offset` beats later. The editor draws it as a ruler under the piece.

signal hit(player)  # touched it: the room starts over (KitRoom.kill())

const Player = preload("res://actors/player/player.gd")
const EDITOR_BPM = 150.0  # the editor's clock, outside a KitRoom
const HEAR_RADIUS = 1100.0  # px from the camera's center: further away, a piece is silent...
const HEAR_FALLOFF = 14.0  # ...and this many dB quieter at the edge of that
const RULER_CELL = 9.0  # the editor's rhythm ruler: one square a beat
const COLOR_RULER_ON = Color(1.0, 0.8, 0.35)
const COLOR_RULER_OFF = Color(1, 1, 1, 0.18)


# Whether a pattern of counts plays on beat n: counts 1.. over `bars` bars, shifted `offset`
# beats later ([1, 3] with offset 1 plays on the 2 and the 4).
static func plays(n: int, pattern: Array, offset: int, bars: int) -> bool:
	return pattern.has(posmod(n - offset, 4 * maxi(bars, 1)) + 1)


func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()  # the editor's clock moves


func in_editor() -> bool:
	return Engine.is_editor_hint()


# The clock is running (always in the editor).
func clock_running() -> bool:
	return in_editor() or Beat.running


# The beat count now, with the fraction past it (2.5: halfway from beat 2 to 3).
func beats_now() -> float:
	if in_editor():
		return Time.get_ticks_msec() / 1000.0 / beat_length()
	return Beat.beats_at(Beat.time()) if Beat.running else 0.0


func beat_length() -> float:
	return 60.0 / _editor_bpm() if in_editor() else Beat.beat_length()


func _editor_bpm() -> float:
	var n = get_parent()
	while n:
		if n.has_method("start_over"):  # the KitRoom
			return n.bpm
		n = n.get_parent()
	return EDITOR_BPM


func players() -> Array:
	return get_tree().get_nodes_in_group("players")


# The player's body as a box, for touching things.
func player_box(p) -> Rect2:
	return Rect2(p.global_position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)


# Plays a sound if this is near the camera, quieter further off.
func play_near(sound: String, volume_db = 0.0):
	if in_editor():
		return
	var cam = get_viewport().get_camera_2d()
	var d = 0.0 if cam == null else cam.get_screen_center_position().distance_to(global_position)
	if d <= HEAR_RADIUS:
		Sfx.play(sound, volume_db - HEAR_FALLOFF * d / HEAR_RADIUS)


# The editor's ruler: a square per beat of the cycle, lit where the pattern plays, the current
# beat outlined. Nothing in the game.
func draw_ruler(at: Vector2, pattern: Array, offset: int, bars: int):
	if not in_editor():
		return
	var cycle = 4 * maxi(bars, 1)
	var now = posmod(floori(beats_now()), cycle)
	for i in cycle:
		var cell = Rect2(at + Vector2(i * (RULER_CELL + 2.0) + (i / 4) * 4.0, 0), Vector2.ONE * RULER_CELL)
		draw_rect(cell, COLOR_RULER_ON if plays(i, pattern, offset, bars) else COLOR_RULER_OFF)
		if i == now:
			draw_rect(cell.grow(2.0), Color.WHITE, false, 1.0)
