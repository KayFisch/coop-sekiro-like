extends "res://tests/test_case.gd"
## The screen halves (Moves "mirror_view", "mirror_blades"; "THE SCREEN HALVES" in
## bifrons_swords.gd): each of Columna Bifrons's blades is drawn in the half of the player it
## fights, its echo in the other: the same (mirror), back on guard (hold) or faint (fade); a
## strike of both swords on one side of him stands out in both halves.

const LEFT = -1
const RIGHT = 1

var boss
var p1
var p2


func _setup(mode: String, mirrored = true):
	set_move("bifrons_stand_in", "off")
	set_move("mirror_view", mirrored)
	set_move("mirror_blades", mode)
	await load_scene("res://levels/threshold/threshold.tscn")
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	for p in [p1, p2]:
		p.invincible = true
	await wait(0.3)


# The half a player is drawn in.
func _half_of(p) -> int:
	return MirrorView.LIGHT if p.player_id == 1 else MirrorView.SHADOW


func test_each_blade_in_its_players_half():
	await _setup("fade")
	for blade in [LEFT, RIGHT]:
		var ward = boss.ward_of(blade)
		var own = _half_of(ward)
		var other = MirrorView.SHADOW if own == MirrorView.LIGHT else MirrorView.LIGHT
		var pivot = boss._pivots[blade]
		var echo = boss._echoes[blade]
		check(pivot.visibility_layer == own and pivot.get_child(0).visibility_layer == own,
			"blade %d: drawn in its player's half" % blade)
		check(echo.visible and echo.visibility_layer == other, "blade %d: its echo in the other" % blade)
		near(echo.modulate.a, Tuning.value("bifrons_fade_alpha"), 0.01, "fade: the echo is faint")
		check(echo.transform.is_equal_approx(pivot.transform), "fade: the echo moves as its blade")


func test_mirror_and_off_are_as_before():
	for mirrored in [true, false]:
		await _setup("mirror" if mirrored else "fade", mirrored)
		for blade in [LEFT, RIGHT]:
			check(boss._pivots[blade].visibility_layer == MirrorView.WORLD,
				"%s: blade %d in both halves" % ["mirror" if mirrored else "mirror_view off", blade])
			check(not boss._echoes[blade].visible, "...and no echo")


func test_hold_keeps_the_echo_on_guard():
	await _setup("hold")
	boss.dev_next = "TRIPLE"
	boss.timer = 0.0
	var striking = 0
	for i in 120:
		await get_tree().physics_frame
		for blade in [LEFT, RIGHT]:
			if boss._targets[blade] != boss.POSE_GUARD and boss._poses[blade].z < -1.75:
				striking = blade  # drawn back over his head
		if striking != 0:
			break
	check(striking != 0, "TRIPLE: a blade draws back")
	if striking != 0:
		var pivot = boss._pivots[striking]
		var echo = boss._echoes[striking]
		check(absf(pivot.rotation - echo.rotation) > 0.1, "hold: its echo doesn't follow it...")
		near(boss._echo_poses[striking].z, boss.POSE_GUARD.z, 0.2, "...it stays on guard")
		near(echo.modulate.a, 1.0, 0.01, "hold: the echo is drawn in full")


func test_heavy_stands_out_in_both_halves():
	await _setup("fade")
	# Both players on his left: ppe, each sword still on its own player.
	p2.global_position.x = boss.global_position.x - 120.0
	p1.global_position.x = boss.global_position.x - 160.0
	await wait(0.4)
	check(boss.is_ppe(), "both on one side: ppe")
	boss.dev_next = "BOTH"
	boss.timer = 0.0
	var full = false
	for i in 90:
		await get_tree().physics_frame
		if boss._echoes[LEFT].modulate.a > 0.99 and boss._echoes[RIGHT].modulate.a > 0.99:
			full = true
			break
	check(full, "a strike of both swords in ppe: both echoes in full, before it lands")
	await wait(1.5)
	near(boss._echoes[LEFT].modulate.a, Tuning.value("bifrons_fade_alpha"), 0.01, "after it: faint again")


func test_color_keeps_each_blade_in_its_players_color():
	await _setup("color")
	for blade in [LEFT, RIGHT]:
		var ward = boss.ward_of(blade)
		var echo = boss._echoes[blade]
		check(boss._blades[blade].color.is_equal_approx(ward.player_color), "color: blade %d in its player's color" % blade)
		check(echo.get_child(0).color.is_equal_approx(ward.player_color), "...its echo too")
		near(echo.modulate.a, 1.0, 0.01, "...not faint: its color does it")
		check(echo.get_child(0).get_child(0).color.is_equal_approx(boss.COLOR_SWORD), "...a silver edge")
	# A heavy strike (ppe): both look as ever, alike in both halves.
	p2.global_position.x = boss.global_position.x - 120.0
	p1.global_position.x = boss.global_position.x - 160.0
	await wait(0.4)
	boss.dev_next = "BOTH"
	boss.timer = 0.0
	var alike = false
	for i in 90:
		await get_tree().physics_frame
		if boss._heavy_shown[LEFT] >= 1.0 and boss._heavy_shown[RIGHT] >= 1.0:
			alike = [LEFT, RIGHT].all(func(b): return boss._blades[b].color.is_equal_approx(boss._tints[b]) \
				and boss._echoes[b].get_child(0).color.is_equal_approx(boss._tints[b]))
			break
	check(alike, "color, a heavy strike: both blades in the strike's colors, in both halves")
