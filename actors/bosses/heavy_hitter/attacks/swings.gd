class_name HitterSwings
extends Attack
## The Heavy Hitter's attack (docs/boss_heavy_hitter.md): a run of links, each one of his verbs
## landing on its time. As a chain (his own attack, THE CHAINS in heavy_hitter.gd) it lays out the
## motif of the field the players are in, and as each repetition's last link lands, decides: the
## motif once more (the new field's, if the field has changed), or, once the chain has its
## repetitions, the finale, by what he sees. Run with links of its own instead (the F5 lab: a motif
## once, a finale, a verb), it lands those and is over.
## The verbs, each with one telegraph, the same everywhere (green: parry it together; yellow: yours
## alone; red: it comes):
##   BLADE   raised high over him in both layers (green), drawn back, and down (red): a blade
##           strike, unisono (HeavyHitter.land_blade()).
##   POMMEL  pulled back toward the blade's side (yellow), thrust out the other way (red), quick: a
##           jab at whoever is in front of the pommel, in each layer (HeavyHitter.land_jab()).
##   HAMMER  the great hammer: a blade strike drawn back further, after a long windup.
##   STOMP   the stomp leap: he crouches, the weapon raised (green), jumps, turns round on the way up,
##           hangs, and comes down as a blade strike on the side that was behind him. In the air his
##           body blocks nobody: walk under him.
## A finale parried together staggers him, the longer the more of the chain was parried
## (HeavyHitter.chain_stagger()). He walks slowly through his windups, and stands while a blade comes
## down and lies.

enum Phase { NONE, SWINGING }

const BLADE = 0
const POMMEL = 1
const HAMMER = 2
const STOMP = 3
const VERBS = ["blade", "pommel", "hammer", "stomp"]  # their names, for the log

# --- Tuning ---
# A link's `wait` is in beats (HeavyHitter.beat(), F2 "hitter_beat"), from the link before (the
# first: from the start). A blade's drop takes F2 "hitter_drop_time", a jab's thrust
# "hitter_jab_time": the cue to parry. A link that follows too closely for it drops faster.
const STICK_TIME = 0.2  # a blade that came down lies there this long (it's heavy)...
const RECOIL_TIME = 0.35  # ...or, parried, is thrown back up for this long
const JAB_HOLD = 0.12  # a jab held out after it lands
const STOMP_REST = 0.3  # down from the stomp leap: getting up
const RAISE_ROOM = 0.3  # it's drawn back at least this long before a drop, whatever it was doing
const TREMBLE = 0.05  # radians the drawn-back weapon shakes by, just before it comes
const FALL_POWER = 1.7  # a drop starts slow and lands fast
# THE STOMP LEAP: up in RISE_TIME to STOMP_HEIGHT (turning round on the way), hanging HANG_TIME, then
# the drop; crouching before it, for whatever is left of its wait.
const RISE_TIME = 0.25
const HANG_TIME = 0.15
const STOMP_HEIGHT = 110.0  # px his feet get off the floor: anyone walks under him
const CROUCH = Vector2(1.12, 0.8)  # his body, loaded for the jump
const COLOR_TOGETHER = Color(0.25, 1.0, 0.45)  # a blade strike: parry it together (as Bifrons's green)
const COLOR_ALONE = Color.YELLOW  # a jab: yours alone

var _name: String
var _written: Array  # the links it runs as written ([wait, verb] each), when it isn't a chain
var _chain = false  # his own attack: the motif by the field, repeated, and the finale
var _is_finale = false  # (not a chain) its links are a finale: parried together, it staggers him
# This run's links, one each: {verb, wait (beats), at (s from the start: when it lands), mark (its
# repetition, 0, 1..., or -1 for the finale), parried (how many parries of it counted)}.
var _links: Array = []
var _time = 0.0  # s into the run
var _next = 0  # the link that lands next
var _reps_done = 0
var _reps_max = 1  # this chain's repetitions, picked as it starts
var _motifs: Array = []  # each repetition's motif (the log)
var _blades = 0  # blades parried in this run so far: the stagger (a co-op parry two, a jab one)
var _jumped = false  # the stomp leap under way has left the floor
var _sounded = -1.0  # the landing time of the last link whose drop has made its sound


func _init(attack_name: String, links: Array, chain = false, finale = false):
	_name = attack_name
	_written = links
	_chain = chain
	_is_finale = finale


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_links = []
	_time = 0.0
	_next = 0
	_reps_done = 0
	_motifs = []
	_blades = 0
	_jumped = false
	_sounded = -1.0
	if _chain:
		var least = int(Tuning.value("hitter_reps_min"))
		_reps_max = randi_range(maxi(least, 1), maxi(int(Tuning.value("hitter_reps_max")), least))
		var answer = boss.answer_link()  # answering a hit at his guard: a jab first, maybe
		if not answer.is_empty():
			_append([answer], 0)
		_append_motif()
	else:
		_append(_written, -1 if _is_finale else 0)


# The next repetition: the motif of the field the players are in now.
func _append_motif():
	var motif = boss.chain_motif()
	_motifs.append(motif)
	_append(boss.MOTIFS[motif], _reps_done)


# Links as written, laid out after the last one; `mark`: their repetition, or -1 for the finale.
func _append(links: Array, mark: int):
	var at = _links.back().at if not _links.is_empty() else 0.0
	for link in links:
		at += link[0] * boss.beat()
		_links.append({"verb": link[1], "wait": link[0], "at": at, "mark": mark, "parried": 0})


# His body keeps its own color: the weapon says what's coming.
func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is the first link's windup, up to its drop.
func get_telegraph_duration() -> float:
	if _links.is_empty():
		return 0.01
	return maxf(_links[0].at - _drop_time(0), 0.01)


func update_telegraph(progress: float):
	_time = progress * get_telegraph_duration()
	_animate(boss.get_physics_process_delta_time())


func execute():
	phase = Phase.SWINGING
	_time = get_telegraph_duration()
	boss.body.color = boss.COLOR_IDLE  # not the usual all-red: the weapon carries it
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_animate(0.0)


func update(delta: float):
	if _links.is_empty():
		finish(0.1)
		return
	_time += delta
	while _next < _links.size() and _time >= _links[_next].at:
		_land(_next)
		if completed:
			return  # staggered: a finale parried together
		_next += 1
	if _next >= _links.size() and _time >= _links.back().at + _rest(_links.back()):
		finish(Tuning.value("hitter_recover_time"))
		return
	_animate(delta)


# Seconds until this run's next link lands on that player; INF if it isn't for them.
func time_to_strike(player) -> float:
	if _next >= _links.size():
		return INF
	var link = _links[_next]
	var at_blade = boss.at_blade(player)
	if link.verb == STOMP and not _jumped:
		at_blade = not at_blade  # he'll have turned round by then
	var jab = link.verb == POMMEL
	if at_blade == jab or boss.distance_to(player) > (boss.POMMEL_REACH if jab else boss.BLADE_REACH):
		return INF
	return link.at - _time


func cleanup():
	if boss.airborne:
		boss.airborne = false
		boss.global_position.y = boss.home_position.y
		boss.ghost(0.0)


# --- The links landing ---

func _land(index: int):
	var link = _links[index]
	var parriers = []
	match link.verb:
		POMMEL:
			parriers = boss.land_jab()
		STOMP:
			boss.global_position.y = boss.home_position.y
			boss.airborne = false
			boss.ghost(0.0)  # he's down: whoever is under him is pushed out to their side
			boss.pop_body(Vector2(1.25, 0.8), 0.25)
			parriers = boss.land_blade()
		_:
			parriers = boss.land_blade(link.verb == HAMMER)
	for p in parriers:
		parry_success.emit(p, "hitter_" + VERBS[link.verb])
	link.parried = parriers.size()
	_blades += parriers.size()
	if link.mark < 0 and link.verb != POMMEL and parriers.size() >= 2:
		# A finale parried together: staggered, the longer the more of the chain was parried.
		finish_with_stagger(boss.chain_stagger(_blades))
		return
	if _chain and link.mark >= 0 and index == _links.size() - 1:
		_end_repetition()


# A repetition's last link has landed: the motif again (the field's, as it is now), or the finale.
func _end_repetition():
	_reps_done += 1
	if _reps_done < _reps_max:
		_append_motif()
		return
	var finale = boss.chain_finale()
	Dev.note("chain", {"motifs": _motifs.duplicate(), "repetitions": _reps_done, "finale": finale, "why": boss.finale_reason})
	_append(boss.FINALES[finale], -1)


# How long a link's weapon stays where it landed: a blade lying, or thrown back up by a parry; a
# jab held out, or knocked back.
func _rest(link: Dictionary) -> float:
	match link.verb:
		POMMEL:
			return RECOIL_TIME if link.parried > 0 else JAB_HOLD
		STOMP:
			return maxf(STOMP_REST, RECOIL_TIME if link.parried > 0 else STICK_TIME)
	return RECOIL_TIME if link.parried > 0 else STICK_TIME


# How long link `index`'s drop takes (its cue): a blade's or a jab's, less if the link before leaves
# no room for it.
func _drop_time(index: int) -> float:
	var link = _links[index]
	var drop = Tuning.value("hitter_jab_time" if link.verb == POMMEL else "hitter_drop_time")
	var gap = link.at - (_links[index - 1].at if index > 0 else 0.0)
	return minf(drop, gap * 0.6)


# --- His weapon and body, as a function of the time into the run ---

func _animate(delta: float):
	if _next >= _links.size():
		_pose_after(_links.back() if not _links.is_empty() else null)
		return
	var link = _links[_next]
	var drop = _drop_time(_next)
	var drop_at = link.at - drop
	var last = _links[_next - 1] if _next > 0 else null
	var free_at = minf(last.at + _rest(last) if last != null else 0.0, drop_at - RAISE_ROOM)  # drawn back from here
	if link.verb == STOMP:
		_stomp(link, drop_at, drop, last, free_at)
		return
	if _time >= drop_at:
		# The drop: it comes, red.
		var fall = pow(clampf((_time - drop_at) / drop, 0.0, 1.0), FALL_POWER)
		if link.verb == POMMEL:
			boss.pose_weapon(boss.POSE_JAB_BACK.lerp(boss.POSE_JAB, fall), true)
		else:
			var coiled = boss.POSE_HAMMER if link.verb == HAMMER else boss.POSE_COILED
			boss.pose_weapon(coiled.lerp(boss.POSE_DOWN, fall), true)
		boss.tint_steel(boss.COLOR_EXECUTE)
		_sound(link)
		return
	if _time < free_at:
		_pose_after(last)  # still where the last one landed
		return
	# Drawn back for it, the further the closer the drop, trembling; walking slowly meanwhile.
	var tension = clampf((_time - free_at) / maxf(drop_at - free_at, 0.01), 0.0, 1.0)
	var pose: Vector3
	var color = COLOR_TOGETHER
	match link.verb:
		POMMEL:
			pose = boss.POSE_LEVEL.lerp(boss.POSE_JAB_BACK, smoothstep(0.0, 0.7, tension))
			color = COLOR_ALONE
		HAMMER:
			pose = boss.POSE_RAISED.lerp(boss.POSE_HAMMER, ease(tension, 2.0))
		_:
			pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
	pose.z += randf_range(-TREMBLE, TREMBLE) * tension * (2.0 if link.verb == HAMMER else 1.0)
	boss.pose_weapon(pose)
	boss.tint_steel(boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension))
	boss.walk(delta, boss.ATTACK_PACE)


# The weapon where a link left it: a blade lying (thrown back up, if parried), a jab held out (or
# knocked back); once that's over, level again.
func _pose_after(link):
	if link == null or _time >= link.at + _rest(link):
		boss.pose_weapon(boss.POSE_LEVEL)
		boss.tint_steel(boss.COLOR_SWORD)
		return
	var parried = link.parried > 0
	if link.verb == POMMEL:
		boss.pose_weapon(boss.POSE_JAB_BACK if parried else boss.POSE_JAB)
	else:
		boss.pose_weapon(boss.POSE_RECOIL if parried else boss.POSE_DOWN)
	boss.tint_steel(boss.COLOR_SWORD if parried else boss.COLOR_EXECUTE)


# THE STOMP LEAP: crouching, the weapon raised; up, turning round on the way; hanging; and down as
# a blade strike, on the side that was behind him.
func _stomp(link: Dictionary, drop_at: float, drop: float, last, free_at: float):
	var jump_at = drop_at - HANG_TIME - RISE_TIME
	var floor_y = boss.home_position.y
	if _time < jump_at:
		if _time < minf(free_at, jump_at - RAISE_ROOM):
			_pose_after(last)
			return
		var from = minf(free_at, jump_at - RAISE_ROOM)
		var tension = clampf((_time - from) / maxf(jump_at - from, 0.01), 0.0, 1.0)
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(tension, 0.5)))
		var pose = boss.POSE_LEVEL.lerp(boss.POSE_RAISED, smoothstep(0.0, 0.8, tension))
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension
		boss.pose_weapon(pose)
		boss.tint_steel(boss.COLOR_SWORD.lerp(COLOR_TOGETHER, 0.4 + 0.6 * tension))
		return
	if not _jumped:
		_jumped = true
		boss.airborne = true
		boss.ghost(link.at - _time + 0.05)
		boss.turn_round(true)  # round in the air: the blade comes down on the side behind him
		boss.pop_body(Vector2(0.85, 1.2), 0.25)
		Sfx.play("launch", -4.0)
	if _time < drop_at:
		var rise = clampf((_time - jump_at) / RISE_TIME, 0.0, 1.0)
		boss.global_position.y = floor_y - STOMP_HEIGHT * (1.0 - (1.0 - rise) * (1.0 - rise))
		boss.pose_weapon(boss.POSE_COILED)
		boss.tint_steel(COLOR_TOGETHER)
		return
	var fall = pow(clampf((_time - drop_at) / drop, 0.0, 1.0), FALL_POWER)
	boss.global_position.y = floor_y - STOMP_HEIGHT * (1.0 - fall)
	boss.pose_weapon(boss.POSE_COILED.lerp(boss.POSE_DOWN, fall), true)
	boss.tint_steel(boss.COLOR_EXECUTE)
	_sound(link)


# A link's drop starting: its sound, once.
func _sound(link: Dictionary):
	if link.at > _sounded:
		_sounded = link.at
		Sfx.play("stab" if link.verb == POMMEL else "swing", -3.0)
