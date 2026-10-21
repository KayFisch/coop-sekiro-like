class_name KultistSpell
extends Node2D
## A spell of STAFF_AND_SPELLS (attacks/staff_and_spells.gd): lightning the Kultist casts at B, in
## B's half, that strikes A across the axis. Its colors say what to do and whom it's for, apart
## (Kay's scribble of 2026-10-02, "Wer und Was getrennt"): a yellow crackle round it, as all his
## lightning (parry it), round a core in A's color (it's for A), ringed in B's (to read on either
## ground).
## It flies from his staff at B (tell_time) and flashes red (cue_time). Then B parries it or blocks
## it (the LIGHTNING rule) and it's spent; B isn't hurt either way. Not stopped, it dives into the
## axis at B's feet and runs along it to A (cross_time; on the line, so both halves see it), rises
## under A flashing red (rise_time), and strikes A from below: A may parry or block it as any
## lightning (Kultist.spell_victim_defends), else it lands.
## TODO(design): B isn't hurt by a spell they let through, and their parry of it is only a parry
## (no energy held, as with the bolt).

signal resolved(what)  # STOPPED by B; on A: KultistElement.PARRIED, BLOCKED or HIT; or MISSED, FIZZLED

enum Stage { FLYING, CUE, CROSSING, RISING, DONE }

const STOPPED = "stopped"
const MISSED = "missed"  # A wasn't there any more
const FIZZLED = "fizzled"  # his attack was cut short
const CORE = 6.0  # px: its core's radius...
const RING = 9.0  # ...its ring's...
const AURA = 16.0  # ...and its crackle's
const DIVE_SHARE = 0.25  # of cross_time: diving from where B met it down to the floor
const TRAIL = 90.0  # px of the axis behind it, lit as it runs
const FADE_TIME = 0.25  # s its burst takes, once it's done
const CHEST = Vector2(0.0, -6.0)  # where it flies at, from a player's center

var boss  # the Kultist: its blows land through him
var caster_target  # B, whom it flies at
var victim  # A, whom it's for
var tell_time = 0.6
var cue_time = 0.16
var cross_time = 0.45
var rise_time = 0.22
var heavy = false
var victim_defends = true
var outcome = ""  # what came of it, once it's done (see resolved)
var _stage = Stage.FLYING
var _age = 0.0  # s into this stage
var _from = Vector2.ZERO  # where this stage began
var _at = Vector2.ZERO  # where it is
var _floor_y = 600.0
var _parts = {}  # "b", "axis", "a" -> Node2D: the part drawn in B's half, on the line, in A's half


# A spell cast by `kultist` at `b`, for `a`, from `from` (his staff's head), under `parent` (the
# room), with his numbers.
static func cast(kultist, b, a, from: Vector2, parent: Node) -> KultistSpell:
	var spell = KultistSpell.new()
	spell.boss = kultist
	spell.caster_target = b
	spell.victim = a
	spell.tell_time = maxf(kultist.spell_tell_time, 0.01)
	spell.cue_time = maxf(kultist.spell_cue_time, 0.01)
	spell.cross_time = maxf(kultist.spell_cross_time, 0.01)
	spell.rise_time = maxf(kultist.spell_rise_time, 0.01)
	spell.heavy = kultist.spell_heavy
	spell.victim_defends = kultist.spell_victim_defends
	spell._from = from
	spell._at = from
	spell._floor_y = BaseBoss.ARENA_FLOOR_Y
	parent.add_child(spell)
	return spell


func _ready():
	top_level = true
	global_position = Vector2.ZERO
	z_index = 7
	for key in ["b", "axis", "a"]:
		var part = Node2D.new()
		part.draw.connect(_draw_part.bind(part, key))
		add_child(part)
		_parts[key] = part


# His attack was cut short: it's gone, harmless.
func fizzle():
	if _stage != Stage.DONE:
		_resolve(FIZZLED)


func _physics_process(delta):
	_age += delta
	match _stage:
		Stage.FLYING:
			if not is_instance_valid(caster_target):
				_pass_b()
			else:
				_at = _from.lerp(caster_target.global_position + CHEST, ease(clampf(_age / tell_time, 0.0, 1.0), 0.6))
				if _age >= tell_time:
					_next(Stage.CUE)
					Sfx.play("stab", -5.0)  # B's cue
		Stage.CUE:
			if is_instance_valid(caster_target):
				_at = caster_target.global_position + CHEST
			if _age >= cue_time:
				_meet_b()
		Stage.CROSSING:
			var dive = cross_time * DIVE_SHARE
			if _age < dive:
				_at = _from.lerp(Vector2(_from.x, _floor_y), _age / dive)
			else:
				var to_x = victim.global_position.x if is_instance_valid(victim) else _from.x
				var run = smoothstep(0.0, 1.0, clampf((_age - dive) / (cross_time - dive), 0.0, 1.0))
				_at = Vector2(lerpf(_from.x, to_x, run), _floor_y)
			if _age >= cross_time:
				_next(Stage.RISING)
				Sfx.play("stab", -2.0)  # A's cue
		Stage.RISING:
			if not is_instance_valid(victim):
				_resolve(MISSED)
			else:
				var chest = victim.global_position + CHEST
				_at = Vector2(chest.x, lerpf(_floor_y, chest.y, clampf(_age / rise_time, 0.0, 1.0)))
				if _age >= rise_time:
					_strike_a()
		Stage.DONE:
			if _age >= FADE_TIME:
				queue_free()
				return
	_parts["b"].visibility_layer = caster_target.visibility_layer if is_instance_valid(caster_target) else MirrorView.WORLD
	_parts["a"].visibility_layer = victim.visibility_layer if is_instance_valid(victim) else MirrorView.WORLD
	for part in _parts.values():
		part.queue_redraw()


func _next(stage: int):
	_stage = stage
	_age = 0.0
	_from = _at


# B's moment: a parry or a block stops it; else it goes on, past B, to A.
func _meet_b():
	if is_instance_valid(caster_target) and boss.meets(caster_target, KultistElement.LIGHTNING, heavy) != KultistElement.HIT:
		_resolve(STOPPED)
		return
	_pass_b()


func _pass_b():
	Sfx.play("launch", -7.0)  # into the axis
	_next(Stage.CROSSING)


func _strike_a():
	_resolve(boss.land_on(victim, KultistElement.LIGHTNING, heavy, null, false, victim_defends))


func _resolve(what: String):
	outcome = what
	_next(Stage.DONE)
	Dev.note("kultist_spell", {"outcome": what})
	resolved.emit(what)


# --- Drawn: in B's half flying at B, on the line running to A, in A's half rising under A ---

func _draw_part(part: Node2D, key: String):
	var tell = KultistElement.tell(KultistElement.LIGHTNING)
	var cue = KultistElement.cue(KultistElement.LIGHTNING)
	var who = victim.player_color if is_instance_valid(victim) else Color.WHITE
	var ring = caster_target.player_color if is_instance_valid(caster_target) else Color.BLACK
	match key:
		"b":
			if _stage in [Stage.FLYING, Stage.CUE]:
				_orb(part, _at, cue if _stage == Stage.CUE else tell, who, ring)
			elif _stage == Stage.DONE and outcome == STOPPED:
				_burst(part, tell)
		"axis":
			if _stage == Stage.CROSSING:
				var back = Vector2(clampf(_at.x - signf(_at.x - _from.x) * TRAIL, minf(_from.x, _at.x), maxf(_from.x, _at.x)), _at.y)
				if back.distance_to(_at) > 1.0:
					part.draw_line(back, _at, Color(tell, 0.6), 4.0, true)
				_orb(part, _at, tell, who, ring)
		"a":
			if _stage == Stage.RISING:
				part.draw_line(Vector2(_at.x, _floor_y), _at, Color(cue, 0.8), 4.0, true)
				_orb(part, _at, cue, who, ring)
			elif _stage == Stage.DONE and outcome in [KultistElement.PARRIED, KultistElement.BLOCKED, KultistElement.HIT]:
				_burst(part, tell)


# The spell itself: a crackle of `aura` round a `core` (A's color), ringed in `ring` (B's).
func _orb(part: Node2D, at: Vector2, aura: Color, core: Color, ring: Color):
	var points = PackedVector2Array()
	for i in 12:
		var radius = AURA * (0.7 if i % 2 == 0 else 1.0) * randf_range(0.85, 1.15)
		points.append(at + Vector2.from_angle(TAU * i / 12.0) * radius)
	part.draw_colored_polygon(points, Color(aura, 0.85))
	part.draw_circle(at, RING, ring)
	part.draw_circle(at, CORE, core)


# Spent: a ring spreading and fading where it is.
func _burst(part: Node2D, color: Color):
	var k = clampf(_age / FADE_TIME, 0.0, 1.0)
	part.draw_arc(_at, lerpf(AURA * 0.5, AURA * 2.5, k), 0.0, TAU, 24, Color(color, 1.0 - k), 3.0, true)
