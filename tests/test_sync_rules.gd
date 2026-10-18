extends "res://tests/test_case.gd"
## Sync as life (core/sync_rules.gd) in Bifrons's room: what each kind of landing costs whom,
## breaking, and when and how fast posture comes back. His own attacks are held off
## (BaseBoss.dev_hold); his strikes land through ColumnaBifrons.land(), as in the fight. The
## numbers are set here, so the players' saved F2 values don't matter.

const NUMBERS = {
	"posture_small": 5.0, "posture_medium": 15.0, "posture_large": 30.0,
	"boss_posture_small": 4.0, "boss_posture_medium": 12.0, "boss_posture_large": 24.0,
	"his_heavy_damage": 18.0, "his_normal_share": 0.33,
	"their_heavy_damage": 12.0, "their_normal_share": 0.5,
	"team_sync_max": 100.0, "boss_sync_max": 200.0, "team_sync_start": 50.0,
	"player_posture_max": 100.0, "boss_posture_max": 200.0,
	"posture_quiet_time": 1.0, "player_posture_regen": 20.0, "boss_posture_regen": 30.0,
	"block_regen_factor": 2.0, "posture_regen_none_at": 50.0, "posture_regen_least": 0.05,
	"chaos_exit": 25.0, "sync_mode_exit": 70.0,
}

var rules
var boss
var p1
var p2


func _setup():
	set_move("bifrons_stand_in", "off")
	set_move("swings_hold_posture", true)
	for key in NUMBERS:
		set_number(key, NUMBERS[key])
	await load_scene("res://levels/threshold/threshold.tscn")
	rules = GameManager.rules
	boss = GameManager.boss
	boss.dev_hold = true
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]


# Full meters, no chaos, nothing recent.
func _fresh():
	rules.team = rules.team_max() * 0.5
	rules.boss_sync = rules.boss_max()
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false
	for actor in [p1, p2, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0
	for p in [p1, p2]:
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	boss.state = BaseBoss.State.IDLE


# One of his strikes lands on `p`: hit, blocked or parried.
func _strike(p, heavy: bool, how: String):
	p._invuln_timer = 0.0
	if how == "block":
		hold(p, "block")
	var judged = {"blade": -1, "under": [p], "parriers": [p] if how == "parry" else [], "parried": how == "parry"}
	boss.land(judged, false, 1.0, heavy)
	hold(p, "block", false)


func _lost(actor) -> float:
	return rules.posture_max(actor) - rules.posture_of(actor)


func test_his_strikes():
	await _setup()
	for heavy in [false, true]:
		for how in ["hit", "block", "parry"]:
			_fresh()
			_strike(p1, heavy, how)
			var tag = ("heavy " if heavy else "normal ") + how
			var size = {"hit": "large" if heavy else "medium", "block": "medium" if heavy else "small",
				"parry": "medium" if heavy else "small"}[how]
			near(_lost(p1), NUMBERS["posture_" + size], 0.01, tag + ": the player's posture")
			var his = NUMBERS["boss_posture_" + ("medium" if heavy else "small")] if how == "parry" else 0.0
			near(_lost(boss), his, 0.01, tag + ": his posture (a parry costs him, a block doesn't)")
			var sync = 0.0
			if how == "hit":
				sync = NUMBERS.his_heavy_damage * (1.0 if heavy else NUMBERS.his_normal_share)
			near(rules.team_max() * 0.5 - rules.team, sync, 0.01, tag + ": the players' sync")


func test_their_hits():
	await _setup()
	for heavy in [false, true]:
		for how in ["lands", "blocked", "parried"]:
			_fresh()
			match how:
				"lands":
					rules.boss_struck(heavy)
				"blocked":
					rules.boss_blocked(heavy)
				"parried":
					rules.boss_parried(p1, heavy)
			var tag = ("heavy " if heavy else "normal ") + how
			var size = {"lands": "large" if heavy else "medium", "blocked": "medium" if heavy else "small",
				"parried": "medium" if heavy else "small"}[how]
			near(_lost(boss), NUMBERS["boss_posture_" + size], 0.01, tag + ": his posture")
			var theirs = NUMBERS["posture_" + ("medium" if heavy else "small")] if how == "parried" else 0.0
			near(_lost(p1), theirs, 0.01, tag + ": the player's posture")
			var sync = 0.0
			if how == "lands":
				sync = NUMBERS.their_heavy_damage * (1.0 if heavy else NUMBERS.their_normal_share)
			near(rules.boss_max() - rules.boss_sync, sync, 0.01, tag + ": his sync")


func test_breaking():
	await _setup()
	_fresh()
	rules._posture[p1] = 1.0
	_strike(p1, false, "parry")
	near(rules.posture_of(p1), 0.0, 0.01, "a parry never breaks the parrier: posture at 0")
	near(rules.team, 50.0, 0.01, "...and no sync lost")
	_fresh()
	rules._posture[p1] = 1.0
	_strike(p1, false, "block")
	near(rules.team, 0.0, 0.01, "a block breaks: all sync gone")
	check(rules.team_chaos, "...and chaos")
	_fresh()
	rules._posture[boss] = 1.0
	_strike(p1, false, "parry")
	near(rules.boss_sync, 0.0, 0.01, "his strike parried can break him: his sync gone")
	check(rules.boss_chaos, "...his chaos")
	check(boss.state == BaseBoss.State.STAGGER, "...and he's staggered")
	_fresh()
	rules._set_team(0.0)
	check(rules.team_chaos, "no sync: chaos")
	check(not rules.can_block(), "...no blocking")
	rules._set_team(24.0)
	check(rules.team_chaos, "chaos holds below chaos_exit")
	rules._set_team(25.0)
	check(not rules.team_chaos, "...and ends at it")
	rules._set_team(100.0)
	check(rules.sync_mode, "full sync: sync mode")
	rules._set_team(69.0)
	check(not rules.sync_mode, "...over below sync_mode_exit")


func test_regen_curve():
	await _setup()
	var shares = {1.0: 1.0, 0.75: 0.525, 0.5: 0.05, 0.25: 0.05}
	for share in shares:
		rules.team = rules.team_max() * share
		near(rules.regen_share(p1), shares[share], 0.001, "regen at %d %% sync" % (share * 100))


func test_regen_waits_and_block_doubles():
	await _setup()
	_fresh()
	rules.team = rules.team_max()
	rules._posture[p1] = 20.0
	rules._posture[p2] = 20.0
	rules._busy_at[p1] = rules._time
	rules._busy_at[p2] = rules._time
	await wait(NUMBERS.posture_quiet_time - 0.25)
	near(rules.posture_of(p1), 20.0, 0.01, "nothing comes back within the quiet time")
	await wait(0.4)
	hold(p2, "block")
	var before = [rules.posture_of(p1), rules.posture_of(p2), rules._time]
	await wait(0.5)
	var seconds = rules._time - before[2]
	near((rules.posture_of(p1) - before[0]) / seconds, NUMBERS.player_posture_regen, 0.8, "regen per second at full sync")
	near((rules.posture_of(p2) - before[1]) / seconds, NUMBERS.player_posture_regen * NUMBERS.block_regen_factor, 1.6,
		"regen per second holding block")


func test_what_holds_regen_back():
	await _setup()
	_fresh()
	for p in [p1, p2]:
		p.invincible = true
	boss.dev_next = "TRIPLE"
	boss.timer = 0.0
	await wait(0.6)
	check(boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING], "he attacks (TRIPLE)")
	check(rules.regenerating(boss), "his own attacks don't hold his posture back")
	rules._busy_at[p1] = -100.0
	await tap(p1, "attack")
	await frames(2)
	check(not rules.regenerating(p1), "a player's swing does (swings_hold_posture on)")
	set_move("swings_hold_posture", false)
	await wait(0.6)
	rules._busy_at[p1] = -100.0
	await tap(p1, "attack")
	await frames(2)
	check(rules.regenerating(p1), "...and doesn't with it off")
