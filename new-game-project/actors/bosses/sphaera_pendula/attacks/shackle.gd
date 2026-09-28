class_name Shackle
extends Attack
## Cyan -> red, ending blue. Two cords snake out of Sphaera Pendula and shackle the players to
## each other: a rope of TETHER_LENGTH (see set_tether() in player.gd). Past its length it pulls
## the two together. A player who falls into the pit dangles from their partner, who holds
## fast by blocking on the ground. Then:
##  1. Two low sweeps skim the pans, alternating direction: jump them. Shackled, what hits one
##     player hits both: they're dragged down together.
##  2. The catch (blue): it climbs high on one side and swings down through the middle, across
##     the rope between the players. If the rope is pulled taut, with the players on opposite
##     sides of it far apart, the rope catches the sphere like a net and holds it; then both
##     players parry within JOIN_WINDOW of each other to slingshot it into the beam, where it
##     tangles, staggered. If the rope is slack, it tears straight through and whips both.

signal sweeps_cleared
signal slingshot

enum Phase { NONE, BIND, SWEEP, RISE, CATCH_SWING, HOLD, FLUNG, FALL }

# --- Tuning ---
const TELEGRAPH_TIME = 1.0
const TETHER_LENGTH = 300.0  # longer than the pit is wide (200), so a taut rope can span it
const TAUT_TOLERANCE = 40.0  # the rope counts as taut within this of its full length
const BIND_TIME = 0.4  # the cuffs snapping shut, the sphere moving to the start of the sweeps
const SWEEPS = 2
const SWEEP_TIME = 1.0  # wall to wall
const SWEEP_DAMAGE = 18.0
const SWEEP_KNOCKBACK = Vector2(0.0, -300.0)
const SWEEP_DIP = 60.0  # dipping into the pit between the pans
const RISE_TIME = 0.8  # climbing to the catch swing's start, turning blue
const CATCH_HIGH_Y = 140.0  # the catch swing's ends
const CATCH_LOW_OFFSET = 30.0  # its lowest point, above the pans' mean surface: at chest height
const CATCH_SWING_TIME = 0.8  # end to end
const HOLD_TIME = 0.6  # held in the net: both players must parry in this time...
const JOIN_WINDOW = 0.25  # ...within this of each other
const SLINGSHOT_DAMAGE = 60.0  # the sphere hitting the beam (x the sync multiplier)
const FLING_TIME = 0.3
const FALL_TIME = 0.4
const SLINGSHOT_STAGGER_TIME = 2.0
const TEAR_DAMAGE = 30.0  # both players: a slack rope, or a hold nobody answered
const TEAR_KNOCKBACK = 350.0
const RECOVER_TIME = 0.5

const COLOR = Color(0.2, 0.95, 1.0)  # cyan: shackled, move as a pair
const COLOR_CATCH = Color(0.25, 0.45, 1.0)  # blue: parry together

var _pair: Array = []  # the two shackled players
var _sweep = 0
var _sweep_from = 0.0
var _sweep_to = 0.0
var _swept_into = false  # a sweep already hit the pair
var _any_sweep_hit = false
var _from = Vector2.ZERO
var _catch_from_x = 0.0
var _caught = false  # the catch swing has reached the rope (one way or the other)
var _hold_start = 0.0  # wall-clock seconds, like the players' parry_press_time
var _presses = {}  # player -> parry_press_time during the hold


func get_attack_name() -> String:
	return "SHACKLE"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_pair = player_nodes.duplicate()
	_pair.sort_custom(func(a, b): return a.player_id < b.player_id)


# The cords snaking out toward both players.
func update_telegraph(progress: float):
	boss.set_glow(COLOR, 0.2 + 0.3 * progress)
	for p in _pair:
		var reach = boss.global_position.lerp(p.global_position, ease(progress, 0.6))
		boss.draw_chain(boss.global_position, reach, COLOR)


func execute():
	if _pair.size() < 2:
		finish(RECOVER_TIME)  # nobody to shackle together
		return
	_pair[0].set_tether(_pair[1], TETHER_LENGTH)
	_pair[1].set_tether(_pair[0], TETHER_LENGTH)
	boss.shake(4.0)
	Sfx.play("chain")
	phase = Phase.BIND
	timer = BIND_TIME
	_from = boss.global_position
	_sweep = 0
	_any_sweep_hit = false
	# Sweep from the wall nearer to it first.
	var side = boss.scales.side_of_x(boss.global_position.x)
	_sweep_from = _wall_x(side)
	_sweep_to = _wall_x(-side)


func update(delta: float):
	timer -= delta
	if phase != Phase.HOLD:
		_draw_rope()
	match phase:
		Phase.BIND:
			var t = 1.0 - clampf(timer / BIND_TIME, 0.0, 1.0)
			var start_point = Vector2(_sweep_from, boss.skim_at(_sweep_from))
			boss.global_position = _from.lerp(start_point, ease(t, 0.5))
			if timer <= 0.0:
				_start_sweep()

		Phase.SWEEP:
			var s = 1.0 - clampf(timer / SWEEP_TIME, 0.0, 1.0)
			var x = lerpf(_sweep_from, _sweep_to, (1.0 - cos(PI * s)) / 2.0)
			var pos = Vector2(x, boss.skim_at(x, SWEEP_DIP))
			boss.body.rotation += (pos.x - boss.global_position.x) / boss.RADIUS
			boss.global_position = pos
			if not _swept_into:
				for p in _pair:
					if boss.touches(p, pos, boss.RADIUS):
						_sweep_hits_pair()
						break
			if timer <= 0.0:
				_sweep += 1
				if _sweep < SWEEPS:
					var back = _sweep_from
					_sweep_from = _sweep_to
					_sweep_to = back
					_start_sweep()
				else:
					if not _any_sweep_hit:
						sweeps_cleared.emit()
					_start_rise()

		Phase.RISE:
			var t = 1.0 - clampf(timer / RISE_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(Vector2(_catch_from_x, CATCH_HIGH_Y), ease(t, 0.5))
			var pulse = 0.5 + 0.5 * sin(boss.anim_time * 16.0)
			boss.body.color = COLOR_CATCH.lerp(Color.WHITE, 0.3 * pulse)
			boss.set_glow(COLOR_CATCH, 0.3 + 0.3 * pulse)
			if timer <= 0.0:
				phase = Phase.CATCH_SWING
				timer = CATCH_SWING_TIME
				_caught = false
				boss.body.color = COLOR_CATCH
				Sfx.play("swing")

		Phase.CATCH_SWING:
			var s = 1.0 - clampf(timer / CATCH_SWING_TIME, 0.0, 1.0)
			var x = lerpf(_catch_from_x, 2.0 * Scales.CENTER_X - _catch_from_x, (1.0 - cos(PI * s)) / 2.0)
			boss.global_position = Vector2(x, _catch_y(x))
			if not _caught and _rope_touched():
				_caught = true
				if _rope_taut():
					_start_hold()
					return
				_tear("slack")
			if timer <= 0.0:
				finish(RECOVER_TIME)

		Phase.HOLD:
			_update_hold()

		Phase.FLUNG:
			var t = 1.0 - clampf(timer / FLING_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(Vector2(Scales.CENTER_X, boss.ANCHOR.y + boss.RADIUS), ease(t, 0.4))
			boss.body.rotation += 25.0 * delta
			if timer <= 0.0:
				_hit_beam()

		Phase.FALL:
			var t = 1.0 - clampf(timer / FALL_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(boss.stagger_spot(), ease(t, 2.0))
			if timer <= 0.0:
				finish_with_stagger(SLINGSHOT_STAGGER_TIME)


func cleanup():
	for p in _pair:
		if is_instance_valid(p):
			p.set_tether(null)


func _wall_x(side: int) -> float:
	return (boss.ARENA_LEFT + boss.RADIUS + 4.0) if side == Scales.LEFT else (boss.ARENA_RIGHT - boss.RADIUS - 4.0)


# --- Shackled: the rope, and the sweeps ---

func _draw_rope():
	if _pair.size() == 2 and phase != Phase.NONE:
		boss.draw_chain(_pair[0].global_position, _pair[1].global_position, COLOR)


func _start_sweep():
	phase = Phase.SWEEP
	timer = SWEEP_TIME
	_swept_into = false
	boss.body.color = boss.COLOR_EXECUTE
	Sfx.play("swing", -2.0)


# Shackled, they go down together.
func _sweep_hits_pair():
	_swept_into = true
	_any_sweep_hit = true
	for p in _pair:
		p.take_damage(SWEEP_DAMAGE, SWEEP_KNOCKBACK, false, true)
	boss.shake(6.0)


# --- The catch ---

func _start_rise():
	phase = Phase.RISE
	timer = RISE_TIME
	_from = boss.global_position
	_catch_from_x = _sweep_to
	Sfx.play("chain", -2.0)


# A deep U: high at both ends, at chest height over the middle of the pit.
func _catch_y(x: float) -> float:
	var low = boss.scales.mean_top() - CATCH_LOW_OFFSET
	var span = absf(_catch_from_x - Scales.CENTER_X)
	var u = (x - Scales.CENTER_X) / maxf(span, 1.0)
	return low - (low - CATCH_HIGH_Y) * u * u


# The sphere meets the rope somewhere between the players (right by one of them, it's the
# player it would meet, not the rope).
func _rope_touched() -> bool:
	var a = _pair[0].global_position
	var b = _pair[1].global_position
	var x = boss.global_position.x
	if x < minf(a.x, b.x) + boss.RADIUS or x > maxf(a.x, b.x) - boss.RADIUS:
		return false
	var closest = Geometry2D.get_closest_point_to_segment(boss.global_position, a, b)
	return closest.distance_to(boss.global_position) <= boss.RADIUS


# Pulled out to (nearly) its full length.
func _rope_taut() -> bool:
	return _pair[0].global_position.distance_to(_pair[1].global_position) >= TETHER_LENGTH - TAUT_TOLERANCE


func _start_hold():
	phase = Phase.HOLD
	timer = HOLD_TIME
	_hold_start = Time.get_ticks_msec() / 1000.0
	_presses.clear()
	boss.shake(7.0)
	Sfx.play("clash_grind", -2.0)
	boss.spawn_sparks(boss.global_position, 14, COLOR_CATCH)


# Caught in the net: the rope bends around it, and both players must parry together.
func _update_hold():
	var flash = fmod(boss.anim_time, 0.1) < 0.05
	boss.body.color = COLOR_CATCH if flash else Color.WHITE
	boss.set_glow(COLOR_CATCH, 0.4 + 0.3 * (1.0 - timer / HOLD_TIME))
	for p in _pair:
		boss.draw_chain(p.global_position, boss.global_position + Vector2(0.0, boss.RADIUS * 0.5), COLOR)
	for p in _pair:
		if not _presses.has(p) and p.parry_press_time >= _hold_start:
			_presses[p] = p.parry_press_time
	if _presses.size() == 2:
		var times = _presses.values()
		if absf(times[0] - times[1]) <= JOIN_WINDOW:
			_slingshot()
		else:
			_tear("out of step")
		return
	if timer <= 0.0:
		_tear("too late")


func _slingshot():
	for p in _pair:
		p.on_perfect_parry(true)
		parry_success.emit(p, "slingshot")
	slingshot.emit()
	boss.body.color = COLOR_CATCH
	boss.shake(10.0)
	Sfx.play("counter_fire")
	phase = Phase.FLUNG
	timer = FLING_TIME
	_from = boss.global_position


func _hit_beam():
	var damage = SLINGSHOT_DAMAGE * GameManager.damage_multiplier()
	boss.shake(14.0)
	Sfx.play("counter_hit", 2.0)
	boss.spawn_sparks(boss.global_position + Vector2(0.0, -boss.RADIUS), 24, COLOR_CATCH)
	boss.take_damage(damage)
	if boss.hp <= 0.0:
		return
	phase = Phase.FALL
	timer = FALL_TIME
	_from = boss.global_position


# It tears through the rope: both players are whipped by it.
func _tear(_why: String):
	for p in _pair:
		p.take_damage(TEAR_DAMAGE, boss.knockback_for(p, TEAR_KNOCKBACK), false, true)
	boss.shake(9.0)
	Sfx.play("chain")
	boss.body.color = boss.COLOR_EXECUTE
	if phase == Phase.HOLD:
		finish(RECOVER_TIME)
