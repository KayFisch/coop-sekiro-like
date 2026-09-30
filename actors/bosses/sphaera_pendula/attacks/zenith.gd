class_name Zenith
extends Attack
## White -> red. Sphaera Pendula reels itself all the way up to the beam and winds its chain
## around it, spinning, while a bar under it runs down. When the bar runs out it drops as the
## Grand Plumb, straight down into the pit, and the impact sprays chain shrapnel over both
## pans. That can't be avoided: the only way to stop it is to strike the sphere up at the beam,
## and nobody jumps that high alone. One player has to Launch the other (a dash-slash into the
## partner's upslash, see player.gd).
## While it winds, it drops chain links at the players on the ground (whoever is setting up the
## launch), to be parried or blocked.

signal interrupted

enum Phase { NONE, WIND, KNOCKED_LOOSE, PLUMB_DROP }

# --- Tuning ---
const TELEGRAPH_TIME = 1.2
# Its center while winding. Its bottom (TOP_Y + 44) stays above the best a lone player can reach
# (jump + double jump + upslash hop, blade up: y ~129 from a level pan); a launch reaches it.
const TOP_Y = 80.0
const WIND_TIME = 4.0  # the players' window to launch and strike it
const WIND_SPIN = 14.0  # radians per second, spinning as it winds
const BAR_WIDTH = 120.0
const LINK_DROP_INTERVAL = 0.7
const LINK_SPEED = 520.0
const LINK_SIZE = Vector2(10, 18)
const LINK_DAMAGE = 10.0
const LINK_BLOCKED_DAMAGE = 4.0
const LINK_KNOCKBACK = 180.0
const KNOCKED_FALL_TIME = 0.45  # struck loose: dropping to hang dazed over the pit
const INTERRUPT_STAGGER_TIME = 2.5
const PLUMB_DROP_TIME = 0.28  # from the beam to the pit
const PLUMB_POWER = 3.0  # the drop accelerates (1 = constant speed)
const PLUMB_DAMAGE = 35.0
const PLUMB_KNOCKBACK = Vector2(0.0, -420.0)
const RECOVER_TIME = 0.6

const COLOR = Color(0.95, 0.95, 1.0)
const COLOR_LINK = Color(0.7, 0.7, 0.76)

var _telegraph_from = Vector2.ZERO
var _from = Vector2.ZERO
var _link_timer = 0.0
var _link_turn = 0  # alternates the links between the grounded players
var _links: Array = []  # {node, dir}
var _bar: ColorRect


func get_attack_name() -> String:
	return "ZENITH"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_telegraph_from = boss_node.global_position


# Reeling itself up to the beam.
func update_telegraph(progress: float):
	boss.global_position = _telegraph_from.lerp(Vector2(Scales.CENTER_X, TOP_Y), ease(progress, 0.5))
	boss.body.rotation = WIND_SPIN * 0.3 * progress * progress
	boss.set_glow(COLOR, 0.2 + 0.3 * progress)


func execute():
	phase = Phase.WIND
	timer = WIND_TIME
	_link_timer = LINK_DROP_INTERVAL * 0.5
	_bar = ColorRect.new()
	_bar.top_level = true
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.color = COLOR
	boss.add_child(_bar)
	Sfx.play("grand_drone", -4.0)


func update(delta: float):
	timer -= delta
	_update_links(delta)
	match phase:
		Phase.WIND:
			var left = clampf(timer / WIND_TIME, 0.0, 1.0)
			boss.global_position = Vector2(Scales.CENTER_X, TOP_Y)
			boss.body.rotation += WIND_SPIN * delta
			# Winding tighter: the chain around the beam, brighter and faster toward the drop.
			boss.body.color = boss.COLOR_EXECUTE.lerp(COLOR, 0.5 + 0.5 * sin(boss.anim_time * lerpf(30.0, 8.0, left)))
			boss.set_glow(COLOR, 0.25 + 0.35 * (1.0 - left))
			var width = BAR_WIDTH * left
			_bar.size = Vector2(width, 6.0)
			_bar.global_position = Vector2(Scales.CENTER_X - width / 2.0, TOP_Y + boss.RADIUS + 12.0)
			_link_timer -= delta
			if _link_timer <= 0.0:
				_link_timer += LINK_DROP_INTERVAL
				_drop_link()
			if timer <= 0.0:
				_start_plumb()

		Phase.KNOCKED_LOOSE:
			var t = 1.0 - clampf(timer / KNOCKED_FALL_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(boss.stagger_spot(), ease(t, 2.0))
			boss.body.rotation += WIND_SPIN * (1.0 - t) * delta
			if timer <= 0.0:
				boss.pop_body(Vector2(1.25, 0.8), 0.25)
				finish_with_stagger(INTERRUPT_STAGGER_TIME)

		Phase.PLUMB_DROP:
			var t = pow(1.0 - clampf(timer / PLUMB_DROP_TIME, 0.0, 1.0), PLUMB_POWER)
			var bottom = boss.scales.mean_top()
			boss.global_position = Vector2(Scales.CENTER_X, lerpf(_from.y, bottom, t))
			if timer <= 0.0:
				_plumb_impact()


# Launched up and struck: knocked loose off the beam.
func on_struck(player):
	if phase != Phase.WIND:
		return
	interrupted.emit()
	parry_success.emit(player, "zenith")
	boss.shake(12.0)
	Sfx.play("counter_hit", 1.0)
	boss.spawn_sparks(boss.global_position, 24, COLOR)
	phase = Phase.KNOCKED_LOOSE
	timer = KNOCKED_FALL_TIME
	_from = boss.global_position
	_free_bar()


func cleanup():
	_free_bar()
	for link in _links:
		link.node.queue_free()
	_links.clear()


func _free_bar():
	if _bar:
		_bar.queue_free()
		_bar = null


# --- Falling links ---

# At a player on the ground, taking turns; anyone if nobody's on the ground.
func _drop_link():
	var grounded = players.filter(func(p): return p.is_on_floor())
	var pool = grounded if not grounded.is_empty() else players
	if pool.is_empty():
		return
	var target = pool[_link_turn % pool.size()]
	_link_turn += 1
	var from = boss.global_position + Vector2(0.0, boss.RADIUS)
	var node = ColorRect.new()
	node.top_level = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = LINK_SIZE
	node.pivot_offset = LINK_SIZE / 2.0
	node.color = COLOR_LINK
	boss.add_child(node)
	var dir = (target.global_position - from).normalized()
	node.rotation = dir.angle() - PI / 2.0
	node.global_position = from - LINK_SIZE / 2.0
	_links.append({"node": node, "dir": dir})
	Sfx.play("stab", -6.0)


func _update_links(delta: float):
	for link in _links.duplicate():
		var node = link.node
		node.global_position += link.dir * LINK_SPEED * delta
		var center = node.global_position + LINK_SIZE / 2.0
		var hit = null
		for p in players:
			if boss.touches(p, center, LINK_SIZE.y / 2.0):
				hit = p
				break
		if hit:
			if hit.is_perfect_parry():
				hit.on_perfect_parry(false)
				parry_success.emit(hit, "link")
			else:
				hit.take_damage(LINK_BLOCKED_DAMAGE if hit.is_blocking() else LINK_DAMAGE,
					boss.knockback_for(hit, LINK_KNOCKBACK) * (0.5 if hit.is_blocking() else 1.0),
					hit.is_blocking())
		if hit or center.y > Scales.PIT_KILL_Y or center.x < boss.ARENA_LEFT or center.x > boss.ARENA_RIGHT:
			_links.erase(link)
			node.queue_free()


# --- The Grand Plumb ---

func _start_plumb():
	phase = Phase.PLUMB_DROP
	timer = PLUMB_DROP_TIME
	_from = boss.global_position
	_free_bar()
	boss.body.color = boss.COLOR_EXECUTE
	boss.body.rotation = 0.0
	boss.pop_body(Vector2(0.8, 1.3), 0.3)


# Unavoidable: every player is hit, wherever they are and whatever they're doing.
func _plumb_impact():
	var center = boss.global_position
	boss.shake(14.0)
	Sfx.play("grand_impact", 2.0)
	boss.spawn_ring_burst(center, boss.COLOR_EXECUTE, 700.0, 0.45)
	boss.spawn_sparks(center, 30, COLOR_LINK)
	for p in players:
		if not p.is_grabbed:
			p.take_damage(PLUMB_DAMAGE, PLUMB_KNOCKBACK, false, true)
	finish(RECOVER_TIME)
