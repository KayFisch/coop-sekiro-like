class_name Clockwork
extends Node2D
## Base for the obstacles that go on the Beat clock (core/beat.gd): hammers, beat steps,
## pendulums. None of them counts time itself; each works out where it is from Beat alone, so
## all of them stay in time together and nothing drifts. Add them with GymLevel.obstacle(),
## which puts whoever they `hit` back at the checkpoint.

signal hit(player)  # touched it: back to the checkpoint

const Player = preload("res://actors/player/player.gd")
const HEAR_RADIUS = 1100.0  # px from the camera's center: further away, an obstacle is silent...
const HEAR_FALLOFF = 14.0  # ...and this many dB quieter at the edge of that


func players() -> Array:
	return get_tree().get_nodes_in_group("players")


# The player's body as a box, for touching things.
func player_box(p) -> Rect2:
	return Rect2(p.global_position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)


# Plays a sound if this is near the camera, quieter further off: a room full of hammers sounds
# like the ones you're at.
func play_near(sound: String, volume_db = 0.0):
	var cam = get_viewport().get_camera_2d()
	var d = 0.0 if cam == null else cam.get_screen_center_position().distance_to(global_position)
	if d <= HEAR_RADIUS:
		Sfx.play(sound, volume_db - HEAR_FALLOFF * d / HEAR_RADIUS)
