class_name HitterSwings
extends Attack
## The Heavy Hitter's attack (docs/boss_heavy_hitter.md): a run of links, each one of his verbs
## landing on its time. As a chain (his own attack, THE CHAINS in heavy_hitter.gd) it lays out the
## motif of the field the players are in, and as each repetition's last link lands, decides: the
## motif once more (the new field's, if the field has changed), or, once the chain has its
## repetitions, the finale, by what he sees. A head provoked meanwhile (phase 2, PROVOKING in
## heavy_hitter.gd) has its flip first, and the decision comes once it's through. Run with links of
## its own instead (the F5 lab: a motif once, a finale, a verb), it lands those and is over. The rage
## is one too, its own way (attacks/rage.gd).
## The verbs, each with one telegraph, the same everywhere (green: parry it together; yellow: yours
## alone; red: it comes). Each head goes for its own player (THE RULES in heavy_hitter.gd): a verb
## moves the weapon only in the layers it's for (_layers()), the other layer's holds meanwhile.
##   BLADE   raised high over him (green in both layers: heavy, together; yellow in one: yours
##           alone), drawn back, and down (red): a blade strike (HeavyHitter.land_blade()).
##   POMMEL  pulled back toward the blade's side (yellow), thrust out the other way (red), quick: a
##           jab at the players at the pommel, in their layers (HeavyHitter.land_jab()).
##   HAMMER  the great hammer: a blade strike drawn back further, after a long windup.
##   STOMP   the stomp leap: he crouches, the weapon raised, jumps, turns round on the way up, hangs,
##           and comes down as a blade strike on the side that was behind him. In the air his body
##           blocks nobody: walk under him.
##   FLIP    (phase 2) the heads' quarrel: they lean toward each other, the one on the pommel's side
##           red (it grabs the blade), the weapon held out level (yellow: yours alone), and it sweeps
##           flat through him to the other side (red), in its layers only (a link's `flip`): the
##           alignment changes. It meets the player of that layer wherever the blade passes them
##           (HitterWeapon.sweep_share()): a normal strike (HeavyHitter.land_sweep()), no crack.
## A link may also turn layers round as its windup begins (`turn`: the rage, from side to side), and
## come down in both layers whoever is where (`both`: the rage, every strike heavy).
## A finale parried together staggers him, the longer the more of the chain was parried
## (HeavyHitter.chain_stagger()). He walks slowly through his windups (not in the rage), and stands
## while a blade comes down and lies.

enum Phase { NONE, SWINGING }

const BLADE = 0
const POMMEL = 1
const HAMMER = 2
const STOMP = 3
const FLIP = 4
const VERBS = ["blade", "pommel", "hammer", "stomp", "flip"]  # their names, for the log

# --- Tuning ---
# A link's `wait` is in beats (HeavyHitter.beat(), F2 "hitter_beat"), from the link before (the
# first: from the start, or the roar's end); or the name of an F2 number of beats. A blade's drop
# takes F2 "hitter_drop_time", a jab's thrust "hitter_jab_time", a flip's sweep "hitter_flip_time":
# the cue to parry. A link that follows too closely for it drops faster.
const STICK_TIME = 0.2  # a blade that came down lies there this long (it's heavy)...
const RECOIL_TIME = 0.35  # ...or, parried, is thrown back up for this long
const JAB_HOLD = 0.12  # a jab held out after it lands
const FLIP_HOLD = 0.15  # a flip swept through, held out on the other side
const FLIP_TREMBLE = 2.0  # px the weapon held out for a flip shakes by, just before it comes
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
# repetition, 0, 1..., or -1 for the finale), turn (the layers that turn round as its windup begins)
# and turned (they have), both (in both layers, whoever is where), flip (a FLIP's layers) and met
# (the layers whose player its sweep has passed), and once it has landed: layers (the layers it came
# down in), parried (the layers whose parry of it counted)}.
var _links: Array = []
var _lead = 0.0  # s before the first link's windup: the rage's roar
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
	_lead = 0.0
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


# Links as written ([wait, verb] each), laid out after the last one; `mark`: their repetition, or -1
# for the finale; `extra`: more of a link's fields, for each.
func _append(links: Array, mark: int, extra = {}):
	for link in links:
		_add(link[0], link[1], mark, extra)


# One link after the last one, `wait` beats on (or an F2 number of them, by its name). A flip that
# isn't told its layers flips the one of the player nearer to him (HeavyHitter.nearer_layer()).
func _add(wait, verb: int, mark: int, extra = {}):
	var beats: float = Tuning.value(wait) if wait is String else wait
	var at = _links.back().at if not _links.is_empty() else _lead
	var link = {"verb": verb, "wait": beats, "at": at + beats * boss.beat(), "mark": mark, "turn": [], "turned": false,
		"both": false, "flip": [], "met": [], "layers": [], "parried": []}
	link.merge(extra.duplicate(true), true)
	if verb == FLIP and link.flip.is_empty():
		link.flip = [boss.nearer_layer()]
	_links.append(link)


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
	_meet_sweep()
	if completed:
		return  # cut short as it met someone (his posture broken: the rage)
	while _next < _links.size() and _time >= _links[_next].at:
		_land(_next)
		if completed:
			return  # staggered: a finale parried together (or cut short)
		_next += 1
	if _next >= _links.size() and _time >= _links.back().at + _rest(_links.back()):
		_end_run()
		return
	_animate(delta)


# All its links landed and at rest: he recovers (the rage: he's exhausted instead).
func _end_run():
	finish(Tuning.value("hitter_recover_time"))


# Seconds until this run's next link lands on that player; INF if it isn't for them.
func time_to_strike(player) -> float:
	if _next >= _links.size():
		return INF
	var link = _links[_next]
	var layer = player.player_id
	if not layer in _layers(link):
		return INF
	if link.verb == FLIP:
		# The sweep meets them where it passes them.
		var share = boss.sweep_share(player, layer)
		if share == INF or layer in link.met:
			return INF
		var drop = _drop_time(_next)
		return link.at - drop * (1.0 - share) - _time
	var jab = link.verb == POMMEL
	if _at_blade_then(player, link) == jab or boss.distance_to(player) > (boss.POMMEL_REACH if jab else boss.BLADE_REACH):
		return INF
	return link.at - _time


# Whether that player will be in front of the blade as the link lands: after the turn round of the
# stomp leap's jump, or the one its windup begins with, if they're still to come.
func _at_blade_then(player, link: Dictionary) -> bool:
	var turning = (link.verb == STOMP and not _jumped) != (player.player_id in link.turn and not link.turned)
	return boss.at_blade(player) != turning


# The layers a link comes down in, just now: a jab's, the players' at the pommel; a blade's, the
# players' at the blade (the stomp leap's before its jump: as they'll be once he has turned); the
# rage's, both; a flip's, its own.
func _layers(link: Dictionary) -> Array:
	if link.both:
		return boss.LAYERS.duplicate()
	match link.verb:
		POMMEL:
			return boss.pommel_layers()
		FLIP:
			return link.flip
	return boss.blade_layers(link.verb == STOMP and not _jumped)


func cleanup():
	boss.stop_sweeps()  # a flip cut short: its blade back where it was
	boss.lean_heads(0.0)
	if boss.airborne:
		boss.airborne = false
		boss.global_position.y = boss.home_position.y
		boss.ghost(0.0)


# --- The links landing ---

func _land(index: int):
	var link = _links[index]
	_turn(link)
	link.layers = _layers(link)
	var parriers = []
	match link.verb:
		POMMEL:
			parriers = boss.land_jab(link.layers)
		FLIP:
			# Through: whoever it passed only now is met, and the blade points the other way.
			for layer in link.flip:
				var p = boss.player_of(layer)
				if p != null and not layer in link.met and boss.sweep_share(p, layer) <= 1.0:
					_meet(link, layer)
				if completed:
					return  # cut short (the rage): it never got through
				boss.end_flip(layer)
		STOMP:
			boss.global_position.y = boss.home_position.y
			boss.airborne = false
			boss.ghost(0.0)  # he's down: whoever is under him is pushed out to their side
			boss.pop_body(Vector2(1.25, 0.8), 0.25)
			parriers = boss.land_blade(link.layers)
		_:
			parriers = boss.land_blade(link.layers, link.verb == HAMMER)
	if completed:
		return  # cut short as it landed (his posture broken: the rage)
	for p in parriers:
		parry_success.emit(p, "hitter_" + VERBS[link.verb])
		link.parried.append(p.player_id)
	_blades += parriers.size()
	if link.mark < 0 and link.verb in [BLADE, HAMMER, STOMP] and parriers.size() >= 2:
		# A finale parried together: staggered, the longer the more of the chain was parried.
		finish_with_stagger(boss.chain_stagger(_blades))
		return
	if _chain and link.mark >= 0 and index == _links.size() - 1:
		_end_repetition()


# The flip's sweep passing that layer's player: a normal strike.
func _meet(link: Dictionary, layer: int):
	link.met.append(layer)
	var p = boss.land_sweep(layer)
	if p != null and not completed:
		link.parried.append(layer)
		_blades += 1
		parry_success.emit(p, "hitter_flip")


# The next link a flip sweeping through just now: the player of each of its layers met as the blade
# passes them.
func _meet_sweep():
	if _next >= _links.size() or _links[_next].verb != FLIP:
		return
	var link = _links[_next]
	var drop = _drop_time(_next)
	var share = (_time - (link.at - drop)) / drop
	for layer in link.flip:
		var p = boss.player_of(layer)
		if p != null and not layer in link.met and share >= boss.sweep_share(p, layer):
			_meet(link, layer)
			if completed:
				return


# A link's windup begins: the layers it turns round go over to the other side (once).
func _turn(link: Dictionary):
	if link.turned:
		return
	link.turned = true
	for layer in link.turn:
		boss.turn_layer(layer)


# A repetition's last link has landed: the motif again (the field's, as it is now), or the finale.
# First, though, a head provoked meanwhile flips its layer toward its provoker (phase 2), and the
# decision waits till that has landed.
func _end_repetition():
	var provoked = boss.provoked_layers()
	if not provoked.is_empty():
		_append([boss.PROVOKED_FLIP], _reps_done, {"flip": provoked})
		return
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
	var parried = not link.parried.is_empty()
	match link.verb:
		POMMEL:
			return RECOIL_TIME if parried else JAB_HOLD
		STOMP:
			return maxf(STOMP_REST, RECOIL_TIME if parried else STICK_TIME)
		FLIP:
			return FLIP_HOLD
	return RECOIL_TIME if parried else STICK_TIME


# How long link `index`'s drop takes (its cue): a blade's, a jab's or a flip's sweep, less if the
# link before leaves no room for it.
func _drop_time(index: int) -> float:
	var link = _links[index]
	var drop = Tuning.value({POMMEL: "hitter_jab_time", FLIP: "hitter_flip_time"}.get(link.verb, "hitter_drop_time"))
	var gap = link.at - (_links[index - 1].at if index > 0 else 0.0)
	return minf(drop, gap * 0.6)


# --- His weapon and body, as a function of the time into the run ---

func _animate(delta: float):
	boss.lean_heads(0.0)
	var last = _links[_next - 1] if _next > 0 else null
	if _next >= _links.size():
		for layer in boss.LAYERS:
			_pose_after(layer, last)
		return
	var link = _links[_next]
	var drop = _drop_time(_next)
	var drop_at = link.at - drop
	var free_at = minf(last.at + _rest(last) if last != null else _lead, drop_at - RAISE_ROOM)  # drawn back from here
	if _time >= free_at:
		_turn(link)
	var layers = _layers(link)
	if link.verb == STOMP:
		_stomp(link, layers, drop_at, drop, last, free_at)
		return
	if link.verb == FLIP:
		_sweep(link, layers, drop_at, drop, last, free_at)
		return
	if _time >= drop_at:
		_sound(link)
	# Green: both heads at once, parry it together; yellow: one head, yours alone.
	var color = COLOR_TOGETHER if link.verb != POMMEL and layers.size() >= 2 else COLOR_ALONE
	var drawing = false
	for layer in boss.LAYERS:
		if not layer in layers or (_time < free_at and _time < drop_at):
			_pose_after(layer, last)  # this head isn't striking (yet): where it was, then level
			continue
		if _time >= drop_at:
			# The drop: it comes, red.
			var fall = pow(clampf((_time - drop_at) / drop, 0.0, 1.0), FALL_POWER)
			if link.verb == POMMEL:
				boss.pose_layer(layer, boss.POSE_JAB_BACK.lerp(boss.POSE_JAB, fall), true)
			else:
				var coiled = boss.POSE_HAMMER if link.verb == HAMMER else boss.POSE_COILED
				boss.pose_layer(layer, coiled.lerp(boss.POSE_DOWN, fall), true)
			boss.tint_layer(layer, boss.COLOR_EXECUTE, link.verb == POMMEL)
			continue
		# Drawn back for it, the further the closer the drop, trembling.
		drawing = true
		var tension = clampf((_time - free_at) / maxf(drop_at - free_at, 0.01), 0.0, 1.0)
		var pose: Vector3
		match link.verb:
			POMMEL:
				pose = boss.POSE_LEVEL.lerp(boss.POSE_JAB_BACK, smoothstep(0.0, 0.6, tension))
			HAMMER:
				pose = boss.POSE_RAISED.lerp(boss.POSE_HAMMER, ease(tension, 2.0))
			_:
				pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension * (2.0 if link.verb == HAMMER else 1.0)
		boss.pose_layer(layer, pose)
		boss.tint_layer(layer, boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension), link.verb == POMMEL)
	if drawing and not link.both:
		boss.walk(delta, boss.ATTACK_PACE)  # slowly, through his windups (not in the rage: he stands)


# A layer's weapon where a link left it: a blade lying (thrown back up, if its player parried), a
# jab held out (or knocked back); once that's over, or if the link wasn't in this layer, level.
func _pose_after(layer: int, link):
	if link == null or not layer in link.layers or _time >= link.at + _rest(link):
		boss.pose_layer(layer, boss.POSE_LEVEL)
		boss.tint_layer(layer, boss.COLOR_SWORD)
		return
	var parried = layer in link.parried
	match link.verb:
		POMMEL:
			boss.pose_layer(layer, boss.POSE_JAB_BACK if parried else boss.POSE_JAB)
		FLIP:
			boss.pose_layer(layer, boss.POSE_SWEEP)
			boss.tint_layer(layer, boss.COLOR_SWORD)
			return
		_:
			boss.pose_layer(layer, boss.POSE_RECOIL if parried else boss.POSE_DOWN)
	boss.tint_layer(layer, boss.COLOR_SWORD if parried else boss.COLOR_EXECUTE, link.verb == POMMEL)


# THE STOMP LEAP: crouching, the weapon raised (in both layers: it's his whole body); up, turning
# round on the way; hanging; and down as a blade strike, on the side that was behind him, in the
# layers it's for (the other layer's weapon comes down level).
func _stomp(link: Dictionary, layers: Array, drop_at: float, drop: float, last, free_at: float):
	var jump_at = drop_at - HANG_TIME - RISE_TIME
	var floor_y = boss.home_position.y
	var color = COLOR_TOGETHER if layers.size() >= 2 else COLOR_ALONE
	if _time < jump_at:
		var from = minf(free_at, jump_at - RAISE_ROOM)
		if _time < from:
			for layer in boss.LAYERS:
				_pose_after(layer, last)
			return
		var tension = clampf((_time - from) / maxf(jump_at - from, 0.01), 0.0, 1.0)
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(tension, 0.5)))
		var pose = boss.POSE_LEVEL.lerp(boss.POSE_RAISED, smoothstep(0.0, 0.8, tension))
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension
		boss.pose_weapon(pose)
		for layer in boss.LAYERS:
			boss.tint_layer(layer, boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension) if layer in layers else boss.COLOR_SWORD)
		return
	if not _jumped:
		_jumped = true
		boss.airborne = true
		boss.ghost(link.at - _time + 0.05)
		boss.turn_round(true)  # round in the air: the blade comes down on the side behind him
		boss.pop_body(Vector2(0.85, 1.2), 0.25)
		Sfx.play("launch", -4.0)
		layers = _layers(link)
		color = COLOR_TOGETHER if layers.size() >= 2 else COLOR_ALONE
	if _time < drop_at:
		var rise = clampf((_time - jump_at) / RISE_TIME, 0.0, 1.0)
		boss.global_position.y = floor_y - STOMP_HEIGHT * (1.0 - (1.0 - rise) * (1.0 - rise))
		boss.pose_weapon(boss.POSE_COILED)
		for layer in boss.LAYERS:
			boss.tint_layer(layer, color if layer in layers else boss.COLOR_SWORD)
		return
	var fall = pow(clampf((_time - drop_at) / drop, 0.0, 1.0), FALL_POWER)
	boss.global_position.y = floor_y - STOMP_HEIGHT * (1.0 - fall)
	for layer in boss.LAYERS:
		if layer in layers:
			boss.pose_layer(layer, boss.POSE_COILED.lerp(boss.POSE_DOWN, fall), true)
			boss.tint_layer(layer, boss.COLOR_EXECUTE)
		else:
			boss.pose_layer(layer, boss.POSE_LEVEL)
			boss.tint_layer(layer, boss.COLOR_SWORD)
	_sound(link)


# THE FLIP: the heads lean toward each other, the one on the pommel's side of each flipping layer red
# (it grabs the blade); the weapon held out level, yellow and shaking; then it sweeps flat through him
# to the other side, red. The other layer's weapon holds.
func _sweep(link: Dictionary, layers: Array, drop_at: float, drop: float, last, free_at: float):
	if _time >= free_at:
		boss.lean_heads(1.0 if _time >= drop_at else smoothstep(0.0, 1.0, (_time - free_at) / maxf(drop_at - free_at, 0.01)))
	for layer in boss.LAYERS:
		if not layer in layers or _time < free_at:
			_pose_after(layer, last)
			continue
		if _time >= drop_at:
			_sound(link)
			boss.pose_layer(layer, boss.POSE_SWEEP, true)
			boss.sweep_layer(layer, (_time - drop_at) / drop)
			boss.tint_layer(layer, boss.COLOR_EXECUTE)
			continue
		var tension = clampf((_time - free_at) / maxf(drop_at - free_at, 0.01), 0.0, 1.0)
		var pose = boss.POSE_LEVEL.lerp(boss.POSE_SWEEP, smoothstep(0.0, 0.6, tension))
		pose.y += randf_range(-FLIP_TREMBLE, FLIP_TREMBLE) * tension
		boss.pose_layer(layer, pose)
		boss.tint_layer(layer, boss.COLOR_SWORD.lerp(COLOR_ALONE, 0.4 + 0.6 * tension))
		boss.anger_head(-boss.way_in(layer))


# A link's drop starting: its sound, once.
func _sound(link: Dictionary):
	if link.at > _sounded:
		_sounded = link.at
		Sfx.play("stab" if link.verb == POMMEL else "swing", -3.0)
