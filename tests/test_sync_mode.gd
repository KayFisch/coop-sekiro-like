extends "res://tests/test_case.gd"
## The sync mode (core/sync_bond.gd): binding, one steering the pair (ONE STEERS), the pair's
## strike together on the big cue and out of sync, his hold-off while they draw back, and the
## dash-slash through him. P2 is the stand-in (it follows P1 perfectly in the sync mode); P1 is
## pressed from here.

var rules
var bond
var boss
var p1
var p2


func _setup(stand_in = "right"):
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
	set_move("sync_steer", "each")  # both move themselves: apart, they come unbound
	boss.set_physics_process(false)  # held where he is: his drift can push them apart
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
	check(bond.steerer() == null and p2.carried_by == null, "each: nobody carried")
	p1.global_position.x = boss.global_position.x - 300.0
	await wait(0.2)
	check(not bond.bound, "far apart again: unbound")


# Bound with one steering (the default, P1): side by side, the pair moved by the steering one's
# stick, the other's moving nothing; switched, the other way round.
func _bind_here():
	p1.global_position.x = boss.global_position.x - 140.0
	p2.global_position.x = boss.global_position.x - 115.0
	await wait(0.4 + Tuning.value("sync_merge_time"))


func test_one_steers():
	await _setup("off")
	boss.set_physics_process(false)
	await _bind_here()
	check(bond.bound and bond.steerer() == p1 and p2.carried_by == p1, "bound: the upper one (P1) steers, carrying P2")
	near(p2.global_position.x - p1.global_position.x, p1.CARRY_GAP, 0.5, "...at their side, the two halves one square")
	var x = p1.global_position.x
	hold(p2, "left")
	hold(p2, "dash")
	await wait(0.4)
	hold(p2, "left", false)
	hold(p2, "dash", false)
	near(p1.global_position.x, x, 1.0, "the carried one's stick and dash move nothing")
	near(p2.global_position.x - p1.global_position.x, p1.CARRY_GAP, 0.5, "...and they stay at their side")
	hold(p1, "left")
	await wait(0.4)
	hold(p1, "left", false)
	check(p1.global_position.x < x - 40.0, "the steering one walks...")
	near(p2.global_position.x - p1.global_position.x, p1.CARRY_GAP, 0.5, "...carrying the other along")
	hold(p2, "block")
	await frames(3)
	check(p2.is_blocking(), "carried, they still block for themselves")
	hold(p2, "block", false)
	set_move("sync_steer", "lower")
	await wait(0.1)
	check(bond.steerer() == p2 and p1.carried_by == p2 and p2.carried_by == null, "switched: the lower one (P2) steers")
	x = p2.global_position.x
	hold(p1, "right")
	await wait(0.3)
	hold(p1, "right", false)
	near(p2.global_position.x, x, 1.0, "...and P1's stick moves nothing")
	hold(p2, "right")
	await wait(0.3)
	hold(p2, "right", false)
	check(p2.global_position.x > x + 30.0, "...P2's moves the pair")
	near(p1.global_position.x - p2.global_position.x, -p1.CARRY_GAP, 0.5, "...P1 at their side")


func test_bound_until_the_sync_mode_ends():
	await _setup("off")
	boss.set_physics_process(false)
	await _bind_here()
	p1.global_position.x = boss.global_position.x - 400.0  # as far off as a throw could take them
	await wait(0.2)
	check(bond.bound, "one steering: they can't come apart, so the bond holds")
	near(p2.global_position.x - p1.global_position.x, p1.CARRY_GAP, 0.5, "...the carried one along")
	var x = p1.global_position.x
	p2.take_damage(Vector2(-400.0, 0.0))
	await wait(0.3)
	check(p1.global_position.x < x - 30.0, "a blow throwing the carried one throws the pair")
	near(p2.global_position.x - p1.global_position.x, p1.CARRY_GAP, 0.5, "...as one")
	rules._set_team(rules.team_max() * 0.5)
	await wait(0.2)
	check(not bond.bound and p2.carried_by == null and p1.carrying == null, "the sync mode over: unbound, nobody carried")
	var shape = p1.get_node("CollisionShape2D")
	check(shape.shape.size == p1.BODY_SIZE and shape.position.x == 0.0, "...and the steering one's body their own again")


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
		hold(p1, "right", false)
		# The charge: let go on a beat (the first charge starts the clock).
		var waited = 0.0
		while absf(Beat.offset_to_beat()) > 0.5 / Engine.physics_ticks_per_second and waited < 2.0:
			await get_tree().physics_frame
			waited += 1.0 / Engine.physics_ticks_per_second
		hold(p1, "attack", false)
		await wait(0.6)
		var through = p1.global_position.x > boss.global_position.x
		check(through == sync, "dash-slash at him, sync mode %s: %s" % [sync, "through" if sync else "stopped"])


# The colors (docs/concept.md): the sync mode is pink, the sync energy's color, in the HUD too.
func test_hud_pink_in_the_sync_mode():
	await _setup("off")
	var hud = get_tree().current_scene.get_node("HUD")
	await frames(2)
	check(hud._duel.team_fill.color == SyncWave.COLOR, "the sync mode: the players' meter pink")
	rules._set_team(rules.team_max() * 0.5)
	await frames(2)
	check(hud._duel.team_fill.color != SyncWave.COLOR, "...and not out of it")


# ONE BODY: bound all the way with one steering, P2 is gone into P1: one character, P1's, P2's
# hands on P1's sabre; the sabre drawn back a little by one alone, all the way by both.
func test_one_body():
	await _setup("off")
	boss.set_physics_process(false)
	await _bind_here()
	await wait(0.1)
	check(p2.merged_into() == p1 and p1.merged_into() == null, "bound all the way: P2 gone into P1")
	check(p1.body.visible and not p2.body.visible and not p2.sword_pivot.visible, "...one character to see, P1's, and one sabre")
	var grip = p1.sword_pivot.to_global(Vector2(p1.sword.position.x + p1.sword.size.x * p1.SHARED_HAND_GRIPS[0],
		p1.sword.position.y + p1.sword.size.y / 2.0))
	var hand = p2._hands[0]
	near((hand.global_position + hand.size / 2.0).distance_to(grip), 0.0, 1.0, "...P2's hands on P1's sabre")
	hold(p2, "attack")
	await wait(Tuning.value("sync_charge_time") + 0.1)
	near(p1.shared_draw(), p1.SHARED_DRAW_ALONE, 0.01, "P2 alone draws back: the shared sabre a little way")
	hold(p1, "attack")
	await wait(Tuning.value("sync_charge_time") + 0.05)
	near(p1.shared_draw(), 1.0, 0.01, "...both: all the way")
	hold(p1, "attack", false)
	hold(p2, "attack", false)
	rules._set_team(rules.team_max() * 0.5)
	await wait(0.2)
	check(p2.merged_into() == null and p2.body.visible and p2.sword_pivot.visible, "the sync mode over: P2 back")
