class_name SyncRules
extends Node
## Sync is life (Moves "bifrons_rules" on "sync"; for now only in Bifrons's fight). Nobody has
## health and there are no potions: the two players share one sync, he has his own, and each of
## the three has a posture. The same rules hold on both sides.
##
## A hit coming in: unblocked, it costs sync; blocked, posture; parried, a little posture (a parry
## never breaks it). A coop parry (both his swords at once, parried by both players) wins sync.
## A hit going out: in sync (through the guard the partner's parry broke) it wins sync, more on
## the beat than off it; out of sync it only costs the one it lands on. A window the partner's
## parry opened that nobody used, while someone could have, costs sync.
##
## Posture comes back with time, the faster the more sync. Broken (by a block): staggered, and all
## sync is gone. No sync is chaos: no blocking, and the next hit that isn't parried kills. It's
## over once sync is back to "chaos_exit" (a revive). Full sync is the sync mode, the players'
## second phase: their hits do "sync_mode_power" times as much until their sync falls below
## "sync_mode_exit". He starts with full sync and wins any back only the way the players do: a
## coop parry of his own (both their hits parried at once) or one strike hitting them both.
##
## Every number is in Tuning (F2).

const MAX = 100.0
const POSTURE_MAX = 100.0
# What a hit's amount is measured against: Bifrons's strike and its chip behind a block, and a
# player's slash. A heavy strike (twice the damage) costs twice as much.
const STRIKE_DAMAGE = 12.0
const CHIP_DAMAGE = 4.0
const SLASH_DAMAGE = 10.0
const TOGETHER_TIME = 0.15  # two hits (or parries) this close are one beat, on both players

var team = 50.0  # the players' sync, 0..MAX
var boss_sync = MAX
var team_chaos = false
var boss_chaos = false
var sync_mode = false
var boss  # the boss whose fight this is

var _posture = {}  # player or boss -> 0..POSTURE_MAX
var _posture_lost_at = {}
var _hit_at = {}  # player -> when one of his blades last hit them unblocked
var _parried_at = {}  # player -> when he last parried their hit
var _time = 0.0


func _ready():
	team = Tuning.value("team_sync_start")


func _process(delta):
	_time += delta
	for actor in _actors():
		if not _posture.has(actor):
			_meet(actor)
		_regen(actor, delta)


# --- What the fight asks ---

func posture_of(actor) -> float:
	return _posture.get(actor, POSTURE_MAX)


func can_block() -> bool:
	return not team_chaos


func boss_guards() -> bool:
	return not boss_chaos


func coop_stagger() -> float:
	return Tuning.value("coop_parry_stagger")


# --- The players, hit by him ---

# Unblocked. Returns true if it kills: in chaos.
func player_hit(p, amount: float) -> bool:
	if p.invincible:
		return false
	_hit_at[p] = _time
	if _together(_hit_at):
		_set_boss(boss_sync + Tuning.value("boss_sync_hit_gain"))
	if team_chaos:
		return true
	_set_team(team - Tuning.value("hit_sync_loss") * amount / STRIKE_DAMAGE)
	return false


func player_blocked(p, amount: float) -> bool:
	if not p.invincible:
		_lose_posture(p, Tuning.value("block_posture_loss") * amount / CHIP_DAMAGE, true)
	return false


func player_parried(p):
	if not p.invincible:
		_lose_posture(p, Tuning.value("parry_posture_loss"), false)


func coop_parried():
	_set_team(team + Tuning.value("coop_parry_gain"))


# --- The players, hitting him ---

func sync_hit(on_beat: bool):
	_set_team(team + Tuning.value("sync_hit_gain" if on_beat else "sync_hit_late_gain"))


func missed_window():
	_set_team(team - Tuning.value("missed_window_loss"))


# A hit lands on him, unblocked. Returns true if it kills: in chaos.
func boss_struck(amount: float) -> bool:
	if boss_chaos:
		return true
	_set_boss(boss_sync - Tuning.value("boss_hit_loss") * amount / SLASH_DAMAGE * _power())
	return false


func boss_blocked(amount: float):
	_lose_posture(boss, Tuning.value("boss_block_posture_loss") * amount / SLASH_DAMAGE * _power(), true)


func boss_parried(p):
	_lose_posture(boss, Tuning.value("boss_parry_posture_loss") * _power(), false)
	_parried_at[p] = _time
	if _together(_parried_at):
		_set_boss(boss_sync + Tuning.value("boss_coop_parry_gain"))


# --- Inside ---

func _actors() -> Array:
	var actors = GameManager.players.filter(func(p): return is_instance_valid(p))
	if is_instance_valid(boss):
		actors.append(boss)
	return actors


# The first time an actor is seen: full posture, and for a player no potions.
func _meet(actor):
	_posture[actor] = POSTURE_MAX
	if actor != boss:
		actor.potions = 0


func _power() -> float:
	return Tuning.value("sync_mode_power") if sync_mode else 1.0


# True once every player has an entry within TOGETHER_TIME of now; the entries are used up.
func _together(times: Dictionary) -> bool:
	var players = GameManager.players
	if players.size() < 2:
		return false
	for p in players:
		if _time - times.get(p, -100.0) > TOGETHER_TIME:
			return false
	times.clear()
	return true


func _regen(actor, delta: float):
	if _time - _posture_lost_at.get(actor, -100.0) < Tuning.value("posture_regen_delay"):
		return
	var sync = boss_sync if actor == boss else team
	var full = Tuning.value("boss_posture_regen" if actor == boss else "player_posture_regen")
	var rate = full * lerpf(Tuning.value("posture_regen_floor"), 1.0, sync / MAX)
	_posture[actor] = minf(_posture[actor] + rate * delta, POSTURE_MAX)


func _lose_posture(actor, amount: float, can_break: bool):
	if not _posture.has(actor):
		_meet(actor)
	_posture_lost_at[actor] = _time
	var left = _posture[actor] - amount
	if left <= 0.0 and can_break:
		_break(actor)
	else:
		_posture[actor] = maxf(left, 0.0)


# Posture broken: staggered, all sync gone. It comes back full.
func _break(actor):
	_posture[actor] = POSTURE_MAX
	Sfx.play("posture_break")
	if actor == boss:
		boss.stagger_now(Tuning.value("boss_break_stagger"))
		_set_boss(0.0)
	else:
		actor.stagger(Tuning.value("player_break_stagger"))
		_set_team(0.0)


func _set_team(v: float):
	team = clampf(v, 0.0, MAX)
	if team <= 0.0 and not team_chaos:
		team_chaos = true
		sync_mode = false
		Sfx.play("chaos")
	elif team_chaos and team >= Tuning.value("chaos_exit"):
		team_chaos = false
		Sfx.play("call_go", -4.0)
	if team >= MAX and not sync_mode and not team_chaos:
		sync_mode = true
		Sfx.play("sync_mode")
	elif sync_mode and team < Tuning.value("sync_mode_exit"):
		sync_mode = false


func _set_boss(v: float):
	boss_sync = clampf(v, 0.0, MAX)
	if boss_sync <= 0.0 and not boss_chaos:
		boss_chaos = true
		Sfx.play("chaos")
	elif boss_chaos and boss_sync >= Tuning.value("chaos_exit"):
		boss_chaos = false

