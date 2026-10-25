class_name AcrobatRing
extends Node2D
## A ring the Acrobat throws (docs/boss_acrobat.md, "His rule: the arc and the strike back").
## Aimed, it marks where it will arrive: the chest of the player it's for, followed until he lets
## go. Let go, it flies there, red (the cue: F2 "acrobat_throw_flight"), and the player it's for
## meets it there (Acrobat.ring_arrived(): a parry, a block, a hit, or nobody there). Then it flies
## back to him in an arc (F2 "acrobat_arc_time", "acrobat_arc_height"), starting slow at chest
## height, and he catches it (Acrobat.catch_ring()):
## - blocked, hit or missed: in the layer it came in, and nobody can strike it;
## - parried: through the mirror line into the partner's layer (it takes their color, the line
##   lit under it a moment) and the same arc. The partner can strike it there, where it passes
##   them, standing or jumping (their blade within F2 "acrobat_strike_back_reach" of it): then it
##   goes straight at him, a strike back (Acrobat.ring_struck_back()).
## The dive's cut is one too, thrown at the line instead of a player: it sticks there, spinning,
## until he dives in after it (pick_up()).
## Drawn in both halves (the mirror rule, stage 0), in the color of the player whose layer it's in.

enum Stage { AIMING, FLYING, ARC, STRUCK, STUCK, DONE }

const PARRIED = "parried"
const BLOCKED = "blocked"
const HIT = "hit"
const MISSED = "missed"

const CHEST = Vector2(0.0, -8.0)  # where it flies at, from a player's center
const STRUCK_TIME = 0.15  # struck back: at him in this long
const SPIN_SPEED = 14.0  # radians/s it turns round its own axis in the air
const MARK_RADIUS = 18.0  # the arrival's mark: a circle closing in on it
const FLASH_TIME = 0.2  # through the mirror: the line lit under it this long
const FLASH_WIDTH = 30.0
const FADE_TIME = 0.2
const COLOR_MARK = Color.YELLOW  # yours to parry
const COLOR_CUE = Color.RED  # it comes

var boss  # the Acrobat
var hand = 1  # the hand that threw it, and catches it
var target = null  # the player it's thrown at (null: the line, the dive's cut)
var layer = 1  # whose it is just now: the color it's in, and whose blade can strike it
var pair = false  # two rings thrown as one (the rally's last throw)
var volley: Array = []  # the rings thrown with it as one heavy throw: both have to be parried
var finale_end = false  # struck back, it staggers him: the end of a finale
var strikable = false  # through the mirror: the partner can strike it back
var outcome = ""  # PARRIED, BLOCKED, HIT or MISSED, once it has arrived
var struck_by = null  # the player who struck it back
var serial = -1  # the partner's swing that last tried it
var stage = Stage.AIMING
var _age = 0.0  # s into this stage
var _from = Vector2.ZERO  # where this stage began
var _at = Vector2.ZERO  # where it is
var _to = Vector2.ZERO  # where it's flying
var _flight = 0.35
var _flash_x = 0.0
var _flash = 0.0


# A ring of `hand`'s, aimed at `target` (null: at the line, at `line_x`).
static func aim(acrobat, from_hand: int, at_player, line_x = 0.0) -> AcrobatRing:
	var ring = AcrobatRing.new()
	ring.boss = acrobat
	ring.hand = from_hand
	ring.target = at_player
	ring.layer = at_player.player_id if at_player != null else from_hand
	ring._to = Vector2(line_x, BaseBoss.ARENA_FLOOR_Y)
	acrobat.get_parent().add_child(ring)
	ring._follow_target()
	return ring


func _ready():
	add_to_group("acrobat_rings")
	top_level = true
	global_position = Vector2.ZERO
	z_index = 6


# Let go: it flies from his hand to where it's aimed, in `flight` s.
func release(flight: float):
	_from = boss.hand_point(hand)
	_at = _from
	_flight = maxf(flight, 0.01)
	_next(Stage.FLYING)


# Where it is just now.
func point() -> Vector2:
	return _at


func is_flying() -> bool:
	return stage in [Stage.AIMING, Stage.FLYING]


func is_back() -> bool:
	return stage == Stage.DONE


# Seconds until it meets that player (INF if it won't): flying at them.
func time_to_strike(player) -> float:
	if stage == Stage.FLYING and player == target:
		return _flight - _age
	return INF


# Seconds until it's back in his hand (or, struck back, at him); INF while it's still going out.
func eta() -> float:
	match stage:
		Stage.ARC:
			return maxf(Tuning.value("acrobat_arc_time") - _age, 0.0)
		Stage.STRUCK:
			return maxf(STRUCK_TIME - _age, 0.0)
		Stage.DONE:
			return 0.0
	return INF


# How it was met (Acrobat.ring_arrived()): parried, it goes through the mirror into the partner's
# layer, where they can strike it; else it stays in its own. Either way back to him in an arc.
func resolve(what: String):
	outcome = what
	if what == PARRIED and target != null and target.partner() != null:
		layer = target.partner().player_id
		strikable = true
		_flash = FLASH_TIME
		_flash_x = _at.x
	_next(Stage.ARC)


# True if that player's blade can strike it back now: parried, in their layer, on its way back.
func can_strike(player) -> bool:
	return stage == Stage.ARC and strikable and player != null and player.player_id == layer


# Struck back by `player`: straight at him.
func strike_back(player):
	struck_by = player
	_next(Stage.STRUCK)
	Sfx.play("counter_fire", -4.0)


# The dive's cut: he dives in after it, and has it back.
func pick_up():
	if stage != Stage.DONE:
		_back()


# His attack cut short: it's gone, back in his hand.
func fizzle():
	if stage != Stage.DONE:
		_back()


func _back():
	boss.give_ring(hand, 2 if pair else 1)
	_next(Stage.DONE)


func _next(new_stage: int):
	stage = new_stage
	_age = 0.0
	_from = _at


func _follow_target():
	if target != null and is_instance_valid(target):
		_to = target.global_position + CHEST
	_at = boss.hand_point(hand)


func _physics_process(delta):
	_age += delta
	_flash = maxf(_flash - delta, 0.0)
	match stage:
		Stage.AIMING:
			_follow_target()
		Stage.FLYING:
			_at = _from.lerp(_to, clampf(_age / _flight, 0.0, 1.0))
			if _age >= _flight:
				if target == null:
					_next(Stage.STUCK)
				else:
					boss.ring_arrived(self)
		Stage.ARC:
			var time = maxf(Tuning.value("acrobat_arc_time"), 0.01)
			var u = pow(clampf(_age / time, 0.0, 1.0), Tuning.value("acrobat_arc_ease"))
			var end = boss.hand_point(hand)
			var bend = (_from + end) / 2.0 - Vector2(0.0, Tuning.value("acrobat_arc_height"))
			_at = _from.lerp(bend, u).lerp(bend.lerp(end, u), u)
			if strikable:
				_try_strike(boss.player_of(layer))
			if stage == Stage.ARC and _age >= time:
				boss.catch_ring(self)
				if stage != Stage.DONE:
					_back()
		Stage.STRUCK:
			_at = _from.lerp(boss.global_position, clampf(_age / STRUCK_TIME, 0.0, 1.0))
			if _age >= STRUCK_TIME:
				boss.ring_struck_back(self, struck_by)
				if stage != Stage.DONE:
					_back()  # he catches it, but it hurt
		Stage.STUCK:
			pass
		Stage.DONE:
			if _age >= FADE_TIME:
				queue_free()
				return
	queue_redraw()


# The partner's blade, swinging, within reach of it: struck back (each swing tries once).
func _try_strike(p):
	if not can_strike(p) or p.is_dead():
		return
	var point = p.active_sword_point()
	if point == null or p.swing_serial == serial:
		return
	if point.distance_to(_at) > Tuning.value("acrobat_strike_back_reach"):
		return
	serial = p.swing_serial
	strike_back(p)


# --- Drawn: the mark where it arrives, the ring (a pair: two), the line lit as it goes through ---

func _draw():
	if stage == Stage.DONE:
		return
	if stage in [Stage.AIMING, Stage.FLYING] and target != null:
		var closing = 1.0 if stage == Stage.AIMING else 1.0 - clampf(_age / _flight, 0.0, 1.0)
		draw_arc(_to, MARK_RADIUS * (0.6 + 0.4 * closing), 0.0, TAU, 24, Color(COLOR_MARK, 0.7), 2.0, true)
	if stage == Stage.AIMING:
		return  # still in his hand: the hand draws it
	var color: Color = boss.ring_color(layer)
	if stage == Stage.ARC and not strikable:
		color = Color(color, 0.6)  # nobody can strike it: it goes home
	var spin = absf(cos(boss.anim_time * SPIN_SPEED))
	var count = 2 if pair else 1
	for i in count:
		_ellipse(_at + Vector2(0.0, 3.0 * (i - (count - 1) / 2.0)), boss.RING_RADIUS * maxf(spin, 0.1), boss.RING_RADIUS, color, boss.RING_WIDTH)
	if stage == Stage.FLYING:
		_ellipse(_at, boss.RING_RADIUS * maxf(spin, 0.1) + 3.0, boss.RING_RADIUS + 3.0, COLOR_CUE, 2.0)
	if _flash > 0.0:
		var k = _flash / FLASH_TIME
		draw_line(Vector2(_flash_x - FLASH_WIDTH, BaseBoss.ARENA_FLOOR_Y), Vector2(_flash_x + FLASH_WIDTH, BaseBoss.ARENA_FLOOR_Y),
			Color(Color.WHITE, k), 4.0, true)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float):
	var points = PackedVector2Array()
	for i in 21:
		var a = TAU * i / 20.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width, true)
