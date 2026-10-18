extends "res://tests/test_case.gd"
## The sync mode (core/sync_bond.gd): binding, the pair's strike together on the big cue and out
## of sync, his hold-off while they draw back, and the dash-slash through him. P2 is the stand-in
## (it follows P1 perfectly in the sync mode); P1 is pressed from here.

var rules
var bond
var boss
var p1
var p2


func _setup(stand_in = "right"):
	set_move("bifrons_rules", "sync")
	set_move("bifrons_stand_in", stand_in)
	set_move("dash_slash_pass", "sync")
	set_number("sync_connect_distance", 30.0)
	set_number("sync_break_distance", 90.0)
	set_number("sync_charge_time", 0.4)
	set_number("sync_cue_delay", 0.15)
	set_number("sync_release_window", 0.1)
	set_number("sync_strike_reach", 150.0)
	set_number("pair_miss_loss", 5.0)
	set_number("sync_slow_speed", 1.0)
	set_number("sync_mode_exit", 70.0)
	set_number("chaos_exit", 25.0)
	set_number("team_sync_max", 100.0)
	await load_scene("res://levels/threshold/threshold.tscn")
	rules = GameManager.rules
	bond = rules.bond
	boss = GameManager.boss
	boss.dev_hold = true
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	p1.invincible = true
	p2.invincible = true
	rules._set_team(rules.team_max())


func test_binding():
	await _setup("off")
	check(rules.sync_mode, "full sync: the sync mode")
	p1.global_position.x = boss.global_position.x - 120.0
	p2.global_position.x = boss.global_position.x + 120.0
	await wait(0.3)
	check(not bond.bound, "apart: not bound")
	p1.global_position.x = boss.global_position.x - 100.0
	p2.global_position.x = boss.global_position.x - 80.0
	await wait(0.4)
	check(bond.bound, "together: bound")
	check(p1.sabre_on() and p2.sabre_on(), "...with sabres")
	p1.global_position.x = boss.global_position.x - 300.0
	await wait(0.2)
	check(not bond.bound, "far apart again: unbound")


func test_strike_together_and_out_of_sync():
	await _setup()
	p1.global_position.x = boss.global_position.x - 100.0
	p2.global_position.x = boss.global_position.x - 80.0
	boss.set_physics_process(false)  # held where he is: no drifting out of reach
	await wait(0.4)
	check(bond.bound, "bound")
	var his = rules.boss_sync
	hold(p1, "attack")
	var waited = 0.0
	while (bond.cue_at < 0.0 or bond.now() < bond.cue_at) and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	hold(p1, "attack", false)
	check(waited < 3.0, "the big cue comes once both are drawn back")
	await wait(0.4)
	check(rules.boss_sync < his, "let go together on the cue: it costs him sync (his guard can't stop it)")
	await wait(0.6)
	var ours = rules.team
	hold(p1, "attack")
	await wait(0.1)
	hold(p1, "attack", false)
	await wait(0.5)
	near(ours - rules.team, 5.0, 0.01, "let go out of sync: pair_miss_loss, once")


func test_he_holds_off_while_they_draw():
	await _setup()
	set_number("sync_hold_off", 1.0)
	set_number("sync_guard_pause", 0.0)
	p1.global_position.x = boss.global_position.x - 100.0
	p2.global_position.x = boss.global_position.x - 80.0
	await wait(0.4)
	boss.dev_hold = false
	boss.state = BaseBoss.State.IDLE
	boss.timer = 0.05
	hold(p1, "attack")
	await wait(0.6)
	check(boss.state == BaseBoss.State.IDLE, "while they draw back he holds off")
	await wait(0.9)
	check(boss.state != BaseBoss.State.IDLE, "...but not past sync_hold_off")
	hold(p1, "attack", false)


func test_dash_slash_through_him():
	await _setup("off")
	boss.set_physics_process(false)  # held where he is
	for sync in [false, true]:
		rules._set_team(rules.team_max() if sync else rules.team_max() * 0.5)
		p2.global_position.x = boss.global_position.x + 300.0
		p1.global_position.x = boss.global_position.x - 70.0
		p1.velocity = Vector2.ZERO
		await wait(0.3)
		hold(p1, "right")
		hold(p1, "dash")
		hold(p1, "attack")
		await wait(0.05)
		hold(p1, "dash", false)
		hold(p1, "attack", false)
		hold(p1, "right", false)
		await wait(0.6)
		var through = p1.global_position.x > boss.global_position.x
		check(through == sync, "dash-slash at him, sync mode %s: %s" % [sync, "through" if sync else "stopped"])
