class_name CoupledPendulums
extends Attack
## Red center charge -> red. Phase 2 only. Sphaera Pendula splits in two: two smaller spheres
## on chains from the same hub, one per player, each swinging at its player on a shared
## metronome (P1 on beats 1, 3 and 5, P2 on 2, 4 and 6) and bouncing back off them. Each
## contact must be perfect parried.
## The pendulums are coupled: a parry keeps your pendulum's energy in it, but a block or a hit
## leaks it into your partner's, whose next swings arrive heavier (bigger, and
## LEAK_DAMAGE_BONUS more damage per leak). The beat never moves, so the timing stays fair while
## the stakes rise: your miss is mostly your partner's problem.
## Parry all of them and the two halves swing back in phase and collide at the center: damage
## and a stagger.

signal pendulum_parried(player)
signal collided

enum Phase { NONE, SWINGING, COLLIDE, MERGE }

# --- Tuning ---
const TELEGRAPH_TIME = 1.2  # the center charge
const SPLIT_TIME = 0.5  # the halves separating and winding back before the first beat's swing
const BEAT = 0.4  # the metronome: seconds between contacts, alternating players
const SWINGS_EACH = 3
const WIND_BACK = 1.0  # radians each half swings back up from its player between its beats
const WIND_SHORTEN = 0.3  # and how much its chain shortens at the top of that swing back
const MINI_DIAMETER = 52.0
const HEAVY_GROWTH = 12.0  # px of diameter per leaked swing
const SWING_DAMAGE = 18.0
const BLOCKED_DAMAGE = 8.0
const LEAK_DAMAGE_BONUS = 0.5  # +50% damage per leak, stacking
const KNOCKBACK = 300.0
const HUB_SCALE = 0.6  # the body shrinks to a hub while split
const COLLIDE_TIME = 0.4
const COLLIDE_DROP = 140.0  # the halves meet this far below the hub
const COLLIDE_DAMAGE = 60.0  # x the sync multiplier
const COLLIDE_STAGGER_TIME = 2.0
const MERGE_TIME = 0.35
const RECOVER_TIME = 0.5

const COLOR = Color(1.0, 0.15, 0.15)

var _order: Array = []  # players, by id; beat k is _order[k % size]
var _minis: Array = []  # ColorRect per player
var _heavy: Array = []  # leaks each half has taken in
var _clock = 0.0
var _next_beat = 0
var _from: Array = []  # halves' positions when the collide/merge began


func get_attack_name() -> String:
	return "COUPLED_PENDULUMS"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func uses_center_charge() -> bool:
	return true


func execute():
	_order = players.duplicate()
	_order.sort_custom(func(a, b): return a.player_id < b.player_id)
	_minis.clear()
	_heavy.clear()
	for p in _order:
		_minis.append(boss.make_disc(MINI_DIAMETER, COLOR))
		_heavy.append(0)
		p.start_gather(SWINGS_EACH)
	_clock = 0.0
	_next_beat = 0
	phase = Phase.SWINGING
	boss.shake(5.0)
	Sfx.play("chain")


func update(delta: float):
	_clock += delta
	boss.hover()
	boss.body.scale = boss.body.scale.lerp(Vector2.ONE * HUB_SCALE, 0.2)
	match phase:
		Phase.SWINGING:
			var total = SWINGS_EACH * _order.size()
			while _next_beat < total and _clock >= _beat_time(_next_beat):
				_contact(_next_beat)
				_next_beat += 1
			for i in _order.size():
				_place_mini(i, _mini_position(i))
			if _clock >= _beat_time(total - 1) + BEAT:
				_end_volley()

		Phase.COLLIDE:
			timer -= delta
			var t = 1.0 - clampf(timer / COLLIDE_TIME, 0.0, 1.0)
			var meet = boss.global_position + Vector2(0.0, COLLIDE_DROP)
			for i in _minis.size():
				_place_mini(i, _from[i].lerp(meet, ease(t, 2.2)))
			if timer <= 0.0:
				_collide(meet)

		Phase.MERGE:
			timer -= delta
			var t = 1.0 - clampf(timer / MERGE_TIME, 0.0, 1.0)
			for i in _minis.size():
				_place_mini(i, _from[i].lerp(boss.global_position, ease(t, 2.0)))
			if timer <= 0.0:
				finish(RECOVER_TIME)


func get_marker(_telegraphing: bool):
	if phase == Phase.SWINGING and _next_beat < SWINGS_EACH * _order.size():
		return {"who": _order[_next_beat % _order.size()]}  # next on the metronome
	return null


func cleanup():
	for mini in _minis:
		mini.queue_free()
	_minis.clear()
	for p in _order:
		if is_instance_valid(p):
			p.end_gather()
	boss.body.scale = Vector2.ONE


# --- The metronome ---

func _beat_time(k: int) -> float:
	return SPLIT_TIME + BEAT * (k + 1)


# Where half i is: bouncing off its player on its beats, swung back up between them.
func _mini_position(i: int) -> Vector2:
	var p = _order[i]
	var hub = boss.global_position
	var n = _order.size()
	var period = BEAT * n
	var first = _beat_time(i)
	var last = _beat_time(i + n * (SWINGS_EACH - 1))
	var u: float  # 0 at a contact, 0.5 wound back up, 1 at the next contact
	if _clock < first - period / 2.0:
		u = 0.5  # split off, waiting wound up
	elif _clock < first:
		u = 1.0 - (first - _clock) / period  # swinging in for the first beat
	elif _clock < last:
		u = fmod(_clock - first, period) / period
	else:
		u = minf((_clock - last) / period, 0.5)  # bounced off the last one, winding back
	var back = sin(PI * u)  # fast off the contact, hanging at the top, fast back in
	var to_player = p.global_position - hub
	var side = 1.0 if p.global_position.x < hub.x else -1.0  # which way is "up and back"
	var angle = to_player.angle() + side * WIND_BACK * back
	var length = to_player.length() * (1.0 - WIND_SHORTEN * back)
	var emerge = clampf(_clock / SPLIT_TIME, 0.0, 1.0)  # growing out of the hub at first
	return hub + Vector2.from_angle(angle) * length * ease(emerge, 0.5)


func _place_mini(i: int, center: Vector2):
	var mini: ColorRect = _minis[i]
	var diameter = MINI_DIAMETER + HEAVY_GROWTH * _heavy[i]
	mini.size = Vector2.ONE * diameter
	mini.global_position = center - mini.size / 2.0
	mini.color = COLOR.darkened(minf(0.15 * _heavy[i], 0.5))
	boss.draw_chain(boss.global_position, center, boss.COLOR_CHAIN)


func _contact(k: int):
	var i = k % _order.size()
	var p = _order[i]
	var last_beat = k == SWINGS_EACH * _order.size() - 1
	if p.is_perfect_parry():
		p.on_perfect_parry(last_beat)
		p.add_gather()
		parry_success.emit(p, "coupled")
		pendulum_parried.emit(p)
		boss.spawn_sparks(p.global_position, 8, COLOR)
		return
	p.fail_gather()
	var bonus = 1.0 + LEAK_DAMAGE_BONUS * _heavy[i]
	boss.hit_player(p, SWING_DAMAGE * bonus, BLOCKED_DAMAGE * bonus, boss.knockback_for(p, KNOCKBACK), true)
	# The energy leaks into the partner's pendulum.
	if _order.size() > 1:
		_heavy[(i + 1) % _order.size()] += 1


func _end_volley():
	_from.clear()
	for mini in _minis:
		_from.append(mini.global_position + mini.size / 2.0)
	var all_parried = _order.all(func(p): return p.has_full_gather())
	for p in _order:
		p.end_gather()
	if all_parried and _order.size() > 1:
		phase = Phase.COLLIDE
		timer = COLLIDE_TIME
		Sfx.play("counter_fire")
	else:
		phase = Phase.MERGE
		timer = MERGE_TIME


func _collide(point: Vector2):
	var damage = COLLIDE_DAMAGE * GameManager.damage_multiplier()
	collided.emit()
	boss.shake(14.0)
	Sfx.play("counter_hit", 2.0)
	boss.spawn_sparks(point, 30, COLOR)
	boss.spawn_ring_burst(point, COLOR, 220.0, 0.35)
	for mini in _minis:
		mini.visible = false
	boss.take_damage(damage)
	if boss.hp > 0.0:
		finish_with_stagger(COLLIDE_STAGGER_TIME)
