class_name PendulumSwing
extends Attack
## Yellow -> red. Sphaera Pendula draws back up its arc on the far side of the pit, then swings
## down through the pit and across the target's pan, skimming it. A perfect parry doesn't stop
## it, it adds energy: the sphere is batted back across the pit at the partner, a little faster
## each time, like pushing a swing (P1, P2, P1, P2). The last parry sends it over the top: it
## loops around the anchor, the chain wraps the beam, and it drops to hang tangled low over the
## pit, staggered.
## The swing always crosses the pit, so the relay needs one player on each pan: with the partner
## on the parrier's own side, the batted-back swing sails over empty space and the relay ends.
## The pans' heights are read when each swing starts; a pan that sinks after that (the partner
## jumped) can drop its player under the swing. Blocking takes chip damage, and jumping over
## the swing dodges it (no relay either).

signal swing_parried(player)
signal relay_completed

enum Phase { NONE, SWING, OVER_TOP }

# --- Tuning ---
# (The parry window is PARRY_TOLERANCE in player.gd, shared by every attack.)
const TELEGRAPH_TIME = 1.0
const RELAY_PARRIES = 4  # parries in a full relay, alternating targets
const RELAY_PARRIES_PHASE_TWO = 5
const FIRST_SWING_TIME = 0.8  # from the drawn-back point to the far turnaround
const SWING_TIME_DECAY = 0.85  # each batted-back swing takes this fraction of the one before
const OVERSHOOT = 130.0  # the arc turns around this far past the target, so it arrives fast
const END_RISE = 120.0  # how far the arc climbs toward its turnarounds
const PIT_DIP = 40.0  # how far it dips into the pit on the way through
const DRAW_BACK_QUIVER = 3.0  # px of trembling at the end of the draw-back
const DEFLECT_FLASH_TIME = 0.15  # yellow flash as a parry bats it back
const HIT_DAMAGE = 25.0
const BLOCKED_DAMAGE = 12.0
const HIT_KNOCKBACK = 380.0
# Relay completed: over the top, around the anchor, the chain wrapping the beam.
const OVER_TOP_TIME = 0.8
const OVER_TOP_LOOP_PART = 0.7  # of OVER_TOP_TIME: the loop; the rest is the drop to hang dazed
const WRAP_RADIUS = 70.0  # the loop tightens to this as the chain winds up
const OVER_TOP_SPIN = 18.0  # radians per second the body rolls through the loop
const WRAP_STAGGER_TIME = 2.0
const RECOVER_TIME = 0.5  # a hit, a block, a dodge or a broken relay

const COLOR = Color.YELLOW

var _target = null  # the player this swing is aimed at; null for an empty swing
var _live = true  # false once the relay is broken: the swing plays out, then it recovers
var _parries = 0
var _swing_time = FIRST_SWING_TIME
var _elapsed = 0.0
var _from = Vector2.ZERO
var _to_x = 0.0
var _reach = {}  # side -> distance from the center at which the arc starts rising on that side
var _steep_side = 0  # the first swing's start side, where the arc stays high (see _start_swing())
var _tops = {}  # side -> the pans' surfaces, read at the swing's start
var _resolved: Array = []  # players this swing has already dealt with
var _telegraph_from = Vector2.ZERO
var _loop_angle = 0.0
var _loop_radius = 0.0
var _loop_dir = 1.0
var _drop_from = Vector2.ZERO


func get_attack_name() -> String:
	return "PENDULUM_SWING"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_telegraph_from = boss_node.global_position
	_parries = 0
	_swing_time = FIRST_SWING_TIME
	_target = null


# Drawing back up the arc on the far side of the pit, trembling at the top.
func update_telegraph(progress: float):
	var quiver = DRAW_BACK_QUIVER * progress
	var goal = _draw_back_point(boss.target_player)
	boss.global_position = _telegraph_from.lerp(goal, ease(progress, 0.4)) \
		+ Vector2(randf_range(-quiver, quiver), 0.0)
	boss.set_glow(COLOR, 0.25)


func execute():
	phase = Phase.SWING
	_live = true
	_start_swing(boss.target_player, boss.global_position, true)


func update(delta: float):
	match phase:
		Phase.SWING:
			_update_swing(delta)
		Phase.OVER_TOP:
			_update_over_top(delta)


func get_marker(telegraphing: bool):
	if telegraphing:
		return {"who": boss.target_player}
	if phase == Phase.SWING and _live and _target:
		return {"who": _target}
	return null


# --- The swing ---

func _draw_back_point(target) -> Vector2:
	var side = boss.scales.side_of_x(target.global_position.x)
	var reach = absf(target.global_position.x - Scales.CENTER_X) + OVERSHOOT
	var x = clampf(Scales.CENTER_X - side * reach, boss.ARENA_LEFT + boss.RADIUS, boss.ARENA_RIGHT - boss.RADIUS)
	return Vector2(x, boss.skim_height(boss.scales.pan_top(-side)) - END_RISE)


# A swing from `from` across the pit, turning around OVERSHOOT past the target (or, for an
# empty swing, as far out as it came from).
func _start_swing(target, from: Vector2, first: bool):
	_target = target
	_from = from
	_elapsed = 0.0
	_resolved.clear()
	var here = boss.scales.side_of_x(from.x)
	var there = -here
	var target_reach = absf(target.global_position.x - Scales.CENTER_X) if target else absf(from.x - Scales.CENTER_X)
	_to_x = clampf(Scales.CENTER_X + there * (target_reach + OVERSHOOT),
		boss.ARENA_LEFT + boss.RADIUS, boss.ARENA_RIGHT - boss.RADIUS)
	# On the side it starts from, the arc begins rising right where it is. The first swing comes
	# down from its draw-back steeply instead, clearing that pan until the pit's edge: the partner
	# waiting there for the relay is never in its way.
	_steep_side = here if first else 0
	var start_reach = Scales.PIT_RIGHT - Scales.CENTER_X if first else absf(from.x - Scales.CENTER_X)
	_reach = {there: target_reach, here: start_reach}
	_tops = {Scales.LEFT: boss.scales.pan_top(Scales.LEFT), Scales.RIGHT: boss.scales.pan_top(Scales.RIGHT)}
	if target:
		boss.target_player = target
	Sfx.play("swing", -2.0)


# The arc: skimming the pans (at their heights when the swing started), dipping through the
# pit, and climbing toward the turnarounds.
func _path(x: float) -> Vector2:
	var y = boss.skim_at(x, PIT_DIP, _tops)
	var from_center = absf(x - Scales.CENTER_X)
	var side = boss.scales.side_of_x(x)
	var rise = clampf((from_center - _reach[side]) / OVERSHOOT, 0.0, 1.0)
	if side == _steep_side:
		rise = sqrt(rise)  # up and over the pan, not along it
	return Vector2(x, y - END_RISE * rise * rise)


func _update_swing(delta: float):
	_elapsed += delta
	var s = clampf(_elapsed / _swing_time, 0.0, 1.0)
	# Pendulum timing: slow off the top, fastest at the bottom, slowing toward the turnaround.
	var pos = _path(lerpf(_from.x, _to_x, (1.0 - cos(PI * s)) / 2.0))
	boss.body.rotation += (pos.x - boss.global_position.x) / boss.RADIUS  # rolling through the air
	boss.global_position = pos
	var flash = _parries > 0 and _elapsed < DEFLECT_FLASH_TIME
	boss.body.color = COLOR if flash else boss.COLOR_EXECUTE

	for p in players:
		if p in _resolved or p.is_grabbed or not boss.touches(p, pos, boss.RADIUS):
			continue
		_resolved.append(p)
		if p.is_perfect_parry():
			if _live and p == _target:
				_parried(p)
				return  # batted into the next swing, or over the top
			p.on_perfect_parry(false)  # a stray pass deflected: no harm, but no relay either
		else:
			boss.hit_player(p, HIT_DAMAGE, BLOCKED_DAMAGE, boss.knockback_for(p, HIT_KNOCKBACK))
			if p == _target:
				_live = false

	if s >= 1.0:
		finish(RECOVER_TIME)  # hit, blocked, dodged, or nobody left to relay to


func _parried(player):
	_parries += 1
	var needed = RELAY_PARRIES_PHASE_TWO if boss.phase_two else RELAY_PARRIES
	var final = _parries >= needed
	player.on_perfect_parry(final)
	parry_success.emit(player, "swing_final" if final else "swing")
	swing_parried.emit(player)
	boss.shake(4.0)
	boss.spawn_sparks(player.global_position, 10, COLOR)
	boss.set_glow(COLOR, 0.35)
	if final:
		_start_over_top()
		return
	# Batted back across the pit, faster; relayed if the partner is over there.
	_swing_time *= SWING_TIME_DECAY
	var partner = boss.partner_of(player)
	var here = boss.scales.side_of_x(boss.global_position.x)
	if partner == null or boss.scales.side_of_x(partner.global_position.x) == here:
		_live = false
		_start_swing(null, boss.global_position, false)
	else:
		_start_swing(partner, boss.global_position, false)
	_resolved.append(player)  # it's leaving the parrier behind, not hitting them


# --- Relay completed: over the top ---

func _start_over_top():
	phase = Phase.OVER_TOP
	timer = OVER_TOP_TIME
	var rel = boss.global_position - boss.ANCHOR
	_loop_angle = rel.angle()
	_loop_radius = rel.length()
	# Carried on across the pit and up the other side: moving right is a decreasing angle
	# (y points down), so it loops around the anchor the way it was going.
	var travel = -boss.scales.side_of_x(boss.global_position.x)
	_loop_dir = -travel
	relay_completed.emit()
	boss.body.color = COLOR
	boss.set_glow(COLOR, 0.45)
	boss.shake(8.0)
	Sfx.play("swing")


func _update_over_top(delta: float):
	timer -= delta
	var t = 1.0 - clampf(timer / OVER_TOP_TIME, 0.0, 1.0)
	if t < OVER_TOP_LOOP_PART:
		var u = t / OVER_TOP_LOOP_PART
		var angle = _loop_angle + _loop_dir * TAU * u
		boss.global_position = boss.ANCHOR + Vector2.from_angle(angle) * lerpf(_loop_radius, WRAP_RADIUS, u)
		_drop_from = boss.global_position
	else:
		var u = (t - OVER_TOP_LOOP_PART) / (1.0 - OVER_TOP_LOOP_PART)
		boss.global_position = _drop_from.lerp(boss.stagger_spot(), ease(u, 2.0))
	boss.body.rotation += OVER_TOP_SPIN * _loop_dir * delta
	if timer <= 0.0:
		boss.shake(6.0)
		boss.pop_body(Vector2(1.25, 0.8), 0.25)
		Sfx.play("chain")
		finish_with_stagger(WRAP_STAGGER_TIME)
