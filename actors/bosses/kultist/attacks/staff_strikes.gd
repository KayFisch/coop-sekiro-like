class_name KultistStaffStrikes
extends Attack
## Yellow staff -> red. STAFF, the Kultist's melee (kultist.gd, "Staff strikes"): staff_strikes
## strikes in a row, each at one player, by the staff in that player's half; the other staff keeps
## its guard meanwhile. The first goes at the nearer player, each after it at the other one if
## they're in reach too, else at the same.
## A strike's staff is raised and drawn back, turning yellow (the tell), drops in staff_fall_time,
## red (the cue: parry now), and lands: parried, blocked or hit, by the STAFF rule
## (kultist_element.gd). As it drops he lunges at its player. A parried staff is thrown back
## (staff_recoil_time), a landed one lies where it fell (staff_rest_time); while a staff is up,
## coming or down, its player's hits land (KultistBody.is_guarding()).
## STAFF_AND_SPELLS (staff_and_spells.gd) strikes the same way, through the hooks below
## (_schedule(), _first_target(), _pick_next(), _approach(), _done(), ...).
## TODO(design): the whole staff turns yellow, then red, as Bifrons's blades do; Kay's scribble
## of 2026-10-02 ("Wer und Was getrennt") would keep it in its player's color (whose) with an
## aura round it (what to do), as his spells have.

enum Phase { NONE, STRIKING }

const FALL_POWER = 1.7  # the drop starts slow and lands fast; his lunge too
const TREMBLE = 0.05  # radians the drawn-back staff shakes by, just before the drop
# A staff is drawn back for its strike at least this long before its drop, whatever it was doing
# (lying where its last strike landed, or thrown back): it has to be there when the drop starts.
const RAISE_ROOM = 0.3

var _time = 0.0  # s since the attack began
var _contacts = []  # when each strike lands (s)...
var _targets = []  # ...and at whom: each picked as it becomes the next (_pick_next())
var _next = 0  # the strike that lands next
var _drawn_from = 0.0  # when the next strike's turn began (the one before landed)
var _lunge = null  # {from, to}: the next strike's lunge, once it's under way
var _landed = {}  # layer -> {at, parried}: that staff's last strike


func get_attack_name() -> String:
	return "STAFF"


# It can come whenever it's its turn...
func fits(_boss_node) -> bool:
	return true


# ...once someone is in his staff's reach (Kultist.in_reach()).
func needs_reach() -> bool:
	return true


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_time = 0.0
	_next = 0
	_drawn_from = 0.0
	_lunge = null
	_landed = {}
	_contacts = _schedule()
	_targets = [_first_target()]


# His body keeps its color: the staff tells.
func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is the first strike's windup, up to its drop.
func get_telegraph_duration() -> float:
	return maxf(_contacts[0] - _fall_time(0), 0.01)


func update_telegraph(progress: float):
	_time = progress * get_telegraph_duration()
	_animate(boss.get_physics_process_delta_time())


func execute():
	phase = Phase.STRIKING
	_time = get_telegraph_duration()
	boss.body.color = boss.COLOR_IDLE  # not the usual all-red: the falling staff carries it
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_animate(0.0)


func update(delta: float):
	_time += delta
	while _next < _contacts.size() and _time >= _contacts[_next]:
		_land(_next)
		_next += 1
		_lunge = null
		_drawn_from = _time
		if _next < _contacts.size():
			_targets.append(_pick_next())
	if _done():
		finish(_recover_time())
		return
	_animate(delta)


# Seconds until its next strike lands on that player; INF if the next one isn't theirs (the
# stand-in times its defence by it).
func time_to_strike(player) -> float:
	if _next >= _contacts.size() or _next >= _targets.size() or _targets[_next] != player:
		return INF
	return _contacts[_next] - _time


# --- What the attacks built on this one make their own ---

# When each strike lands (s from the attack's start).
func _schedule() -> Array:
	var contacts = []
	for i in maxi(boss.staff_strikes, 1):
		contacts.append(boss.staff_windup + i * boss.staff_gap)
	return contacts


# The first strike's player: the nearer one.
func _first_target():
	return boss.nearest_player()


# Every strike is in, and the last staff is done lying where it landed.
func _done() -> bool:
	if _next < _contacts.size():
		return false
	var last = _landed.values().reduce(func(a, b): return a if a.at > b.at else b) if not _landed.is_empty() else null
	return last == null or _time >= last.at + _rest_time(last)


func _recover_time() -> float:
	return boss.staff_recover


# Between two drops: he stands (the lunge takes him to its player).
func _approach(_player, _delta: float):
	pass


# The next strike's player: the other one, if they're in reach too; else the one struck last, if
# they're still there; else whoever is nearest.
func _pick_next():
	var last = _targets.back()
	var others = boss.get_players().filter(func(p): return p != last and boss.in_reach(p))
	if not others.is_empty():
		return others[0]
	if last != null and is_instance_valid(last):
		return last
	return boss.nearest_player()


func _land(index: int):
	if _lunge != null:
		boss.global_position.x = _lunge.to  # he's there as the staff lands
	var p = _targets[index]
	if p == null or not is_instance_valid(p):
		return
	var parried = false
	if boss.distance_to(p) <= boss.staff_reach:
		parried = boss.land_on(p, KultistElement.STAFF, boss.staff_heavy) == KultistElement.PARRIED
		if parried:
			parry_success.emit(p, "kultist_staff")
	if not parried:
		Sfx.play("thunk", -6.0)  # the staff on the floor
	_landed[boss.layer_of(p)] = {"at": _contacts[index], "parried": parried}


# How long strike `index`'s drop takes: staff_fall_time, less if the strike before leaves no room.
func _fall_time(index: int) -> float:
	var gap = _contacts[index] - (_contacts[index - 1] if index > 0 else 0.0)
	return minf(boss.staff_fall_time, gap * 0.6)


# How long a staff stays where its strike left it: thrown back by a parry, or lying.
func _rest_time(landed: Dictionary) -> float:
	return boss.staff_recoil_time if landed.parried else boss.staff_rest_time


# --- His feet and his staves, as a function of the time into the attack ---

func _animate(delta: float):
	if _next < _contacts.size():
		_move(delta)
	for layer in boss.LAYERS:
		_pose(layer)


# As the staff drops he lunges at its player: to strike_distance from them, staying on his side
# of them, by staff_lunge at most. Before that, _approach().
func _move(delta: float):
	var p = _targets[_next]
	if p == null or not is_instance_valid(p):
		return
	var fall = _fall_time(_next)
	var since = _time - (_contacts[_next] - fall)
	if since < 0.0:
		_approach(p, delta)
		return
	if _lunge == null:
		var from = boss.global_position.x
		var goal = p.global_position.x - boss.side_of(p) * boss.strike_distance
		goal = clampf(goal, from - boss.staff_lunge, from + boss.staff_lunge)
		_lunge = {"from": from, "to": boss.clamp_x(goal)}
		Sfx.play("swing", -3.0)  # the drop starting
	boss.global_position.x = lerpf(_lunge.from, _lunge.to, pow(clampf(since / fall, 0.0, 1.0), FALL_POWER))


func _pose(layer: int):
	var landed = _landed.get(layer)
	var rest_end = landed.at + _rest_time(landed) if landed != null else -1.0
	var p = _targets[_next] if _next < _targets.size() else null
	if p != null and is_instance_valid(p) and boss.layer_of(p) == layer:
		# This staff strikes next.
		var fall = _fall_time(_next)
		var fall_start = _contacts[_next] - fall
		if _time >= fall_start:
			var drop = pow(clampf((_time - fall_start) / fall, 0.0, 1.0), FALL_POWER)
			boss.pose_staff(layer, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), true)
			boss.tint_staff(layer, KultistElement.cue(KultistElement.STAFF))
			return
		# Drawn back once it's done lying where its last strike left it; in time for its drop,
		# whatever else.
		var draw_from = minf(maxf(_drawn_from, rest_end), fall_start - RAISE_ROOM)
		if _time >= draw_from:
			var tension = clampf((_time - draw_from) / maxf(fall_start - draw_from, 0.01), 0.0, 1.0)
			var pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
			pose.z += randf_range(-TREMBLE, TREMBLE) * tension
			boss.pose_staff(layer, pose)
			# Yellow from the start, even on the shadow half's dark staff, and fuller as it nears.
			boss.tint_staff(layer, boss.half_color(layer).lerp(KultistElement.tell(KultistElement.STAFF), 0.7 + 0.3 * tension))
			return
	if landed != null and _time < rest_end:
		# Just landed: lying where it came down, red; or thrown back by the parry.
		boss.pose_staff(layer, boss.POSE_RECOIL if landed.parried else boss.POSE_DOWN)
		boss.tint_staff(layer, null if landed.parried else KultistElement.cue(KultistElement.STAFF))
		return
	boss.pose_staff(layer, boss.POSE_REST)  # guarding (once it's back: staff_return_time)
	boss.tint_staff(layer, null)
