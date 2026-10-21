class_name KultistFire
extends Node2D
## The fire of FIRE_AND_LIGHTNING (attacks/fire_and_lightning.gd), on the floor, in both halves.
## First embers glow from the walls in to the edges of the safe place in the middle, brighter and
## brighter (the tell, `tell_time`). Then it erupts at both walls and runs inward at `speed`, and
## each place burns `burn_time` from the moment it's reached; nothing burns in the safe place.
## A player standing in a burning place is hit, once, and thrown toward the middle (the FIRE rule,
## kultist_element.gd: no parry, no block: get out of it). It frees itself once burnt out.
## TODO(design): once per fire, however long they stay in it (a hit's 0.6 s untouchable would
## otherwise make it a hit every 0.6 s); thrown toward the safe place, not away from him.

const FLAME_HEIGHT = 64.0  # px: how high the flames lick (drawn)...
const FLAME_REACH = 48.0  # ...and how high they hit: a player whose feet are above this is over them
const TONGUE = 12.0  # px: one tongue of flame
const EMBER_SPACING = 9.0  # px between two embers
const FADE_TIME = 0.25  # s a burnt-out place takes to fade; the fire's end, too
const EDGE_WIDTH = 2.0  # the safe place's edges, marked while the embers glow

var boss  # the Kultist: his blows land through him (Kultist.land_on())
var tell_time = 1.4
var speed = 700.0
var burn_time = 2.2
var left = 24.0  # the room's walls...
var right = 1128.0
var safe_left = 486.0  # ...and the safe place between these
var safe_right = 666.0
var floor_y = 600.0
var _age = 0.0
var _hit = []  # players it has hit
var _out_at = -1.0  # put out (fizzle()) at this age: fading, harmless


# Lights a fire under `parent` (the room) for the Kultist `kultist`, with his numbers.
static func light(kultist, parent: Node) -> KultistFire:
	var fire = KultistFire.new()
	fire.boss = kultist
	fire.tell_time = kultist.fire_tell_time
	fire.speed = maxf(kultist.fire_speed, 1.0)
	fire.burn_time = kultist.fire_burn_time
	fire.left = BaseBoss.ARENA_LEFT
	fire.right = BaseBoss.ARENA_RIGHT
	var middle = (BaseBoss.ARENA_LEFT + BaseBoss.ARENA_RIGHT) / 2.0
	fire.safe_left = middle - kultist.safe_width / 2.0
	fire.safe_right = middle + kultist.safe_width / 2.0
	fire.floor_y = BaseBoss.ARENA_FLOOR_Y
	parent.add_child(fire)
	return fire


func _ready():
	top_level = true
	global_position = Vector2.ZERO
	z_index = 5


# When the eruption reaches the edges of the safe place (s from its lighting).
func reaches_safe_at() -> float:
	return tell_time + maxf(safe_left - left, right - safe_right) / speed


# How long it burns in all (s from its lighting).
func lifetime() -> float:
	return reaches_safe_at() + burn_time


func is_erupted() -> bool:
	return _age >= tell_time


# True while place `x` burns.
func burning(x: float) -> bool:
	if _out_at >= 0.0 or x <= left or x >= right or (x > safe_left and x < safe_right):
		return false
	var since = _age - _reached_at(x)
	return since >= 0.0 and since < burn_time


# Puts it out: whatever glows or burns fades, and it hits nobody any more.
func fizzle():
	if _out_at < 0.0:
		_out_at = _age


# When the eruption reaches place `x` (s from its lighting).
func _reached_at(x: float) -> float:
	var from_wall = x - left if x <= safe_left else right - x
	return tell_time + from_wall / speed


func _physics_process(delta):
	var was = _age
	_age += delta
	var out = _out_at >= 0.0
	if was < tell_time and _age >= tell_time and not out:
		Sfx.play("counter_hit", -8.0)  # it erupts
		Fx.shake(self, 5.0)
	if not out and is_instance_valid(boss):
		for p in boss.get_players():
			if p in _hit or not burning(p.global_position.x):
				continue
			var feet = p.global_position.y + p.body.size.y / 2.0
			if feet < floor_y - FLAME_REACH:
				continue  # over the flames
			_hit.append(p)
			var middle = (safe_left + safe_right) / 2.0
			var way = signf(middle - p.global_position.x)
			boss.land_on(p, KultistElement.FIRE, boss.fire_heavy, Vector2(way * boss.fire_knockback, -boss.fire_knockback * 0.6))
	if _age > lifetime() + FADE_TIME or (out and _age > _out_at + FADE_TIME):
		queue_free()
		return
	modulate.a = clampf(1.0 - (_age - _out_at) / FADE_TIME, 0.0, 1.0) if out else 1.0
	queue_redraw()


func _draw():
	var tell = KultistElement.tell(KultistElement.FIRE)
	var flame = KultistElement.cue(KultistElement.FIRE)
	if _age < tell_time:
		# The tell: embers where it will burn, brighter as it nears; the safe place's edges.
		var glow = clampf(_age / maxf(tell_time, 0.01), 0.0, 1.0)
		var x = left + EMBER_SPACING / 2.0
		while x < right:
			if x <= safe_left or x >= safe_right:
				var flicker = 0.5 + 0.5 * sin(x * 0.37 + _age * 11.0)
				var size = 2.0 + 3.0 * glow * flicker
				draw_rect(Rect2(x - size / 2.0, floor_y - size, size, size), Color(tell.lerp(flame, glow * flicker), 0.35 + 0.65 * glow))
			x += EMBER_SPACING
		for edge in [safe_left, safe_right]:
			draw_rect(Rect2(edge - EDGE_WIDTH / 2.0, floor_y - FLAME_HEIGHT * glow, EDGE_WIDTH, FLAME_HEIGHT * glow), Color(flame, 0.5 * glow))
		return
	# Erupted: a tongue of flame on every burning place, tall while it's fresh, low as it dies.
	var x = left + TONGUE / 2.0
	while x < right:
		if x <= safe_left or x >= safe_right:
			var since = _age - _reached_at(x)
			if since >= 0.0 and since < burn_time + FADE_TIME:
				var life = 1.0 - clampf((since - burn_time) / FADE_TIME, 0.0, 1.0)
				var fresh = clampf(since / 0.12, 0.0, 1.0)
				var lick = 0.65 + 0.35 * sin(x * 0.51 + _age * 17.0) * sin(x * 0.13 - _age * 7.0)
				var height = FLAME_HEIGHT * fresh * lick * lerpf(0.55, 1.0, life)
				var base = Rect2(x - TONGUE / 2.0, floor_y - height, TONGUE, height)
				draw_rect(base, Color(tell.lerp(flame, 0.6), 0.85 * life))
				var core = Rect2(x - TONGUE / 4.0, floor_y - height * 0.6, TONGUE / 2.0, height * 0.6)
				draw_rect(core, Color(Color(1.0, 0.9, 0.45), 0.9 * life))
		x += TONGUE
