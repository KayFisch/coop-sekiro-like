class_name SyncRules
extends Node
## Sync is life (Moves "bifrons_rules" on "sync"; for now only in Bifrons's fight). Nobody has
## health and there are no potions: the two players share one sync, he has his own, and each of
## the three has a posture. The same rules hold on both sides: a fair exchange. What tips it is
## that the players can win sync back and he can't, and that he has more of it.
##
## Attacks are normal or heavy. His heavy ones are those of both swords (green: a strike of both,
## the leap); the players' attacks are normal, and heavy only as the bound pair's strike let go
## together in their sync mode (core/sync_bond.gd, `bond`).
##
## POSTURE comes in three sizes (each side's own: "posture_*" for the players, "boss_posture_*"
## for him, as there are two of them to attack him), lost by whoever...
##   - parries or blocks a normal attack, or has a normal attack of their own parried: small;
##   - is hit by a normal attack, parries or blocks a heavy one, or has a heavy one of their own
##     parried: medium;
##   - is hit by a heavy attack: large.
## So a parry costs both sides alike, and a block only the one who blocks: blocking does nothing
## to the attacker. A parry never breaks the parrier's own posture.
## SYNC: a hit that lands costs the one it lands on sync: a heavy one "his_heavy_damage" (on the
## players) or "their_heavy_damage" (on him), a normal one a share of that ("his_normal_share",
## "their_normal_share": a third).
## Blocked or parried, it costs no sync. The players win sync back: a sync hit (through the guard
## the partner's parry broke), more on the beat than off it, and a coop parry (both his swords at
## once, parried by both). A window the partner's parry opened that nobody used, while someone
## other than the parrier could have, costs them sync.
##
## Posture comes back only once nothing has landed on that one (hit, blocked or parried) for
## "posture_quiet_time", and, for a player (Moves "swings_hold_posture"), once they haven't swung
## for as long; his own attacks never hold it back, as he attacks nearly all the time. A player
## holding block meanwhile gets it back
## "block_regen_factor" times as fast. How fast follows sync, as in Sekiro: at full sync its full
## rate, at 75 % half of it, at "posture_regen_none_at" (50 %) and below hardly any
## ("posture_regen_least"). Broken: staggered, and all sync is gone. No sync is chaos: no blocking
## (for him: no guard), and the next hit that isn't parried kills. The players get out of it once
## their sync is back to "chaos_exit" (a revive); he can't, as he wins no sync back. Full sync is
## the players' sync mode, their second phase, until their sync falls below "sync_mode_exit": they
## can bind and strike together (core/sync_bond.gd), and he slows down ("sync_mode_tempo") and
## strikes with both swords at once.
##
## Every number is in Tuning (F2).

const POSTURE_SIZES = ["posture_small", "posture_medium", "posture_large"]  # the players'
const BOSS_POSTURE_SIZES = ["boss_posture_small", "boss_posture_medium", "boss_posture_large"]
const SMALL = 0
const MEDIUM = 1
const LARGE = 2

var team = 0.0  # the players' sync, 0..team_max()
var boss_sync = 0.0  # his, 0..boss_max()
var team_chaos = false
var boss_chaos = false
var sync_mode = false
var boss  # the boss whose fight this is
# Whether the strike of his landing just now is a heavy one: he sets it while it lands
# (ColumnaBifrons.land()), and the players' hooks (Player.take_damage(), on_perfect_parry()) lead
# here meanwhile.
var landing_heavy = false

var _posture = {}  # player or boss -> 0..posture_max()
var _busy_at = {}  # player or boss -> when something last landed on them, or they last attacked
var _swings = {}  # player -> their swing_serial when last seen: a new one is a new attack
var _time = 0.0
var bond  # SyncBond: the sync mode itself: the two bound, and their strike together


func _ready():
	team = team_max() * Tuning.value("team_sync_start") / 100.0
	boss_sync = boss_max()
	bond = preload("res://core/sync_bond.gd").new()
	bond.rules = self
	add_child(bond)


func _process(delta):
	_time += delta
	team = minf(team, team_max())  # a meter made smaller in F2
	boss_sync = minf(boss_sync, boss_max())
	for actor in _actors():
		if not _posture.has(actor):
			_meet(actor)
		if _attacking(actor):
			_busy_at[actor] = _time
		_regen(actor, delta)


# --- What the fight asks ---

func team_max() -> float:
	return Tuning.value("team_sync_max")


func boss_max() -> float:
	return Tuning.value("boss_sync_max")


func posture_max(actor) -> float:
	return Tuning.value("boss_posture_max" if actor == boss else "player_posture_max")


func team_share() -> float:
	return team / team_max()


func boss_share() -> float:
	return boss_sync / boss_max()


func posture_of(actor) -> float:
	return minf(_posture.get(actor, INF), posture_max(actor))


func posture_share(actor) -> float:
	return posture_of(actor) / posture_max(actor)


# How fast that side's posture comes back, once it does, as a share of its full rate: all of it at
# full sync, falling in a straight line to the floor at posture_regen_none_at.
func regen_share(actor) -> float:
	var sync = boss_share() if actor == boss else team_share()
	var none_at = Tuning.value("posture_regen_none_at") / 100.0
	return lerpf(Tuning.value("posture_regen_least"), 1.0, clampf((sync - none_at) / (1.0 - none_at), 0.0, 1.0))


# True while that one's posture comes back: nothing has landed on them (and a player hasn't
# swung, see _attacking()) for posture_quiet_time.
func regenerating(actor) -> bool:
	return _time - _busy_at.get(actor, -100.0) >= Tuning.value("posture_quiet_time")


func can_block() -> bool:
	return not team_chaos


func boss_guards() -> bool:
	return not boss_chaos


func coop_stagger() -> float:
	return Tuning.value("coop_parry_stagger")


# --- His strikes landing on the players (landing_heavy: which kind) ---

# Unblocked. (amount: the old rules' number; what counts here is landing_heavy.) Returns true if
# it kills: in chaos.
func player_hit(p, _amount: float) -> bool:
	if p.invincible:
		return false
	_busy_at[p] = _time
	if team_chaos:
		return true
	_set_team(team - _damage("his", landing_heavy))
	_lose_posture(p, LARGE if landing_heavy else MEDIUM, true)
	return false


# Blocked: it costs the one who blocks, not him.
func player_blocked(p, _amount: float) -> bool:
	if not p.invincible:
		_busy_at[p] = _time
		_lose_posture(p, MEDIUM if landing_heavy else SMALL, true)
	return false


# Parried: it costs both alike, and can break his posture, not theirs.
func player_parried(p):
	var size = MEDIUM if landing_heavy else SMALL
	if not p.invincible:
		_busy_at[p] = _time
		_lose_posture(p, size, false)
	_lose_posture(boss, size, true)


func coop_parried():
	_set_team(team + Tuning.value("coop_parry_gain"))


# --- The players' hits landing on him (heavy: the bound pair's strike together) ---

func sync_hit(on_beat: bool):
	_set_team(team + Tuning.value("sync_hit_gain" if on_beat else "sync_hit_late_gain"))


func missed_window():
	_set_team(team - Tuning.value("missed_window_loss"))


# Unblocked. Returns true if it kills: in chaos.
func boss_struck(heavy = false) -> bool:
	_busy_at[boss] = _time
	if boss_chaos:
		return true
	_set_boss(boss_sync - _damage("their", heavy))
	_lose_posture(boss, LARGE if heavy else MEDIUM, true)
	return false


# He blocks it: it costs him, not them.
func boss_blocked(heavy = false):
	_busy_at[boss] = _time
	_lose_posture(boss, MEDIUM if heavy else SMALL, true)


# He parries it: it costs both alike, and can break their posture, not his.
func boss_parried(p, heavy = false):
	var size = MEDIUM if heavy else SMALL
	_busy_at[boss] = _time
	_lose_posture(boss, size, false)
	if not p.invincible:
		_lose_posture(p, size, true)


# The bound pair's strike together, met by his guard: it goes through all the same, costing him a
# normal hit's sync and a parried heavy one's posture. Returns true if it kills: in chaos.
func pair_strike_parried() -> bool:
	_busy_at[boss] = _time
	if boss_chaos:
		return true
	_set_boss(boss_sync - _damage("their", false))
	_lose_posture(boss, MEDIUM, true)
	return false


# The bound pair let go out of sync.
func pair_missed():
	_set_team(team - Tuning.value("pair_miss_loss"))


# --- Inside ---

func _actors() -> Array:
	var actors = GameManager.players.filter(func(p): return is_instance_valid(p))
	if is_instance_valid(boss):
		actors.append(boss)
	return actors


# The first time an actor is seen: full posture, and for a player no potions.
func _meet(actor):
	_posture[actor] = posture_max(actor)
	if actor != boss:
		actor.potions = 0
		_swings[actor] = actor.swing_serial


# True when a player has just begun a swing that holds their posture back (Moves
# "swings_hold_posture"). His own attacks never do: he attacks nearly all the time.
func _attacking(actor) -> bool:
	if actor == boss:
		return false
	var began = actor.swing_serial != _swings.get(actor, actor.swing_serial)
	_swings[actor] = actor.swing_serial
	return began and Moves.on("swings_hold_posture")


# What a hit that lands costs in sync, by whose it is ("his" or "their"): the heavy amount, or
# the normal share of it.
func _damage(whose: String, heavy: bool) -> float:
	return Tuning.value(whose + "_heavy_damage") * (1.0 if heavy else Tuning.value(whose + "_normal_share"))


func _regen(actor, delta: float):
	if not regenerating(actor):
		return
	var rate = Tuning.value("boss_posture_regen" if actor == boss else "player_posture_regen") * regen_share(actor)
	if actor != boss and actor.is_blocking():
		rate *= Tuning.value("block_regen_factor")
	_posture[actor] = minf(_posture[actor] + rate * delta, posture_max(actor))


func _lose_posture(actor, size: int, can_break: bool):
	if not _posture.has(actor):
		_meet(actor)
	var sizes = BOSS_POSTURE_SIZES if actor == boss else POSTURE_SIZES
	var left = minf(_posture[actor], posture_max(actor)) - Tuning.value(sizes[size])
	if left <= 0.0 and can_break:
		_break(actor)
	else:
		_posture[actor] = maxf(left, 0.0)


# Posture broken: staggered, all sync gone. It comes back full.
func _break(actor):
	_posture[actor] = posture_max(actor)
	Sfx.play("posture_break")
	if actor == boss:
		boss.stagger_now(Tuning.value("boss_break_stagger"))
		_set_boss(0.0)
	else:
		actor.stagger(Tuning.value("player_break_stagger"))
		_set_team(0.0)


func _set_team(v: float):
	team = clampf(v, 0.0, team_max())
	if team <= 0.0 and not team_chaos:
		team_chaos = true
		sync_mode = false
		Sfx.play("chaos")
	elif team_chaos and team_share() * 100.0 >= Tuning.value("chaos_exit"):
		team_chaos = false
		Sfx.play("call_go", -4.0)
	if team >= team_max() and not sync_mode and not team_chaos:
		sync_mode = true
		Sfx.play("sync_mode")
	elif sync_mode and team_share() * 100.0 < Tuning.value("sync_mode_exit"):
		sync_mode = false


# He only ever loses sync: once it's gone, his chaos lasts.
func _set_boss(v: float):
	boss_sync = clampf(v, 0.0, boss_max())
	if boss_sync <= 0.0 and not boss_chaos:
		boss_chaos = true
		Sfx.play("chaos")
