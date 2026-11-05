extends Node2D
## The tutorial (docs/tutorial.md): first a little moving, then a guided fight against a training
## dummy, step by step, on the mirrored screen as every fight. The dummy is the try-out boss in a
## dummy's look (dummy_look.gd), standing still between his attacks; the tutorial picks each one
## (dev_next, as the F5 lab's loop does), and none while the lab holds him (dev_hold). Its switches
## are held while it's here (Moves.fix(), as the Warden's room does), whatever F1 says.
##
## THE STEPS, a sentence or two each (the principle, no numbers), on until what each asks is met
## (how many: F2, page "tutorial"):
##   MOVE: walk and jump to the marks in your half (he waits). DASH: dash.
##   PARRY: a strike at each, in turn. Each parries and blocks. Posture said with it (the HUD's
##      bars pulse): blocking wears yours down, a parry his too; broken, a hit takes all your sync.
##   COLORS: yellow, it's for you; red, now. Each parries.
##   HALVES: in your half your blade stands out, your partner's hardly. Each parries.
##   DASH PARRY: a parry mid-dash takes you through him. Each once.
##   SYNC HIT: a parry sends its energy to the partner (pink), their hit then is a sync hit, worth
##      more right on the beat. Each lands some, one on the beat: both ways. Each half tells its
##      player what to do: parry, or wait and strike.
##   SYNC LIFE: their sync low; a hit costs it, sync hits win it back (the HUD's meter pulses), and
##      chaos is said with it. Filled up to half.
##   TOGETHER: green, two blades on one place: parried together, he reels, and it wins sync.
##      Apart (pep), his crossing brings them to one side first.
##   SYNC MODE: their sync full; together they bind, one steers, both draw back and let go on the
##      big cue. Pair strikes landed.
## Then "done": Enter / pad A on to the first boss, Esc the select screen.
##
## NO DEFEAT: the sync rules spare everyone (SyncRules.spared: no chaos, no posture broken), and a
## hit that gets through starts the step's count over (its words stay: the progress under them shows
## it). Out of the sync mode in its step, it starts over too, the sync full again. Before then
## their sync stays short of full (no sync mode yet).
## SKIP: Tab on the keyboard or Start on a pad, held a moment. ALONE: the stand-in (F1 Fights
## "Stand-in") plays the partner and gets through every step (BifronsStandIn.perfect); what it
## can't do (the marks, the dash, the dash-parry) counts as done for it.

enum Step { MOVE, DASH, PARRY, COLORS, HALVES, DASH_PARRY, SYNC_HIT, SYNC_LIFE, TOGETHER, SYNC_MODE, DONE }

const NEXT_SCENE = "res://levels/warden/warden.tscn"  # the first boss
const BELOW_FULL = 0.9  # before the sync mode's step, their sync kept at most this share of full
const SWITCHES = {
	"bifrons_mode": "patterns",  # his attacks one by one, as the tutorial picks them
	"bifrons_guard_break": "on",  # a parry opens his other side: the partner's hit gets through
	"bifrons_coop_windows": true,
	"bifrons_blade_parries": true,  # two blades on one place: parried together, else a block
	"bifrons_throw_by_outcome": true,
	"bifrons_chain_stagger": true,
	"bifrons_face": true,
	"mirror_view": true,  # the mirrored screen, as in every fight
	"mirror_blades": "color",
	"sync_merge_view": true,
	"sync_steer": "upper",
}
# Each step's words, read by both, said once: [in the light half, in the shadow half]. A short one
# only above; a longer one goes on below (merged, all of it above: tutorial_text.gd).
const TEXTS = {
	Step.MOVE: ["Walk and jump: reach both marks in your half.", ""],
	Step.DASH: ["Dash: a quick burst, the way you hold (or face).", ""],
	Step.PARRY: ["He strikes at each of you in turn. Hold block to take a blow; press block just as it lands to parry it.",
		"Blocking wears down your posture (the bar under the sync), a parry his too. Broken, you reel: a hit then takes all your sync."],
	Step.COLORS: ["Yellow: this one is for you. Red: now.", ""],
	Step.HALVES: ["Your half shows the blades aimed at you; your partner's you hardly see.", ""],
	Step.DASH_PARRY: ["Dash at him and parry as his blow lands: you go through him, to his other side.", ""],
	Step.SYNC_HIT: ["A parry sends its energy to your partner, in pink: when it reaches them, their hit is a sync hit.",
		"Right on the beat (the tip lights up) it's worth more."],
	Step.SYNC_LIFE: ["The meter at the top is your shared sync: your life. His hits cost it, sync hits win it back.",
		"Empty, it's chaos: no blocking, and the next hit ends it. Fill it up to half."],
	Step.TOGETHER: ["Green: two blades on one place. Parry them together: he reels, and it wins you sync.", ""],
	Step.SYNC_MODE: ["Your sync is full. Stand together to bind: the upper one steers.",
		"Both hold attack, and let go on the big cue. Below the mark, the sync mode is over."],
	Step.DONE: ["Done. Enter or A: on to the first boss.   Esc: back to the select screen.", ""],
}
const PARRY_NOW = "Parry him."  # SYNC HIT: in the half he's about to strike...
const STRIKE_ON_PINK = "Wait for the pink, then strike."  # ...and in the other one
const GET_TOGETHER = "He'll bring you both to one side of him."  # TOGETHER, apart (pep)
const SKIP_HINT = "Hold Tab or pad Start: skip this step"
const PULSES = {Step.PARRY: "posture", Step.SYNC_LIFE: "team"}  # the HUD's meter each points out
# MOVE: each player's marks, in their half, away from him: [x on the floor, x up in the air].
const MARKS = {1: [110.0, 300.0], 2: [1042.0, 852.0]}
const MARK_HEIGHT = 110.0  # px over the floor the one in the air is: a jump reaches it
const MARK_REACH = 30.0  # px from a player's middle that counts as reaching it
const MARK_RADIUS = 12.0
const MARK_COLOR = Color(1.0, 1.0, 1.0, 0.8)
const SPARED_LOW = 0.2  # SYNC LIFE: their sync may fall this low (a hit has to show)
const KINDS = {"parry": "parry", "block": "block", "sync_hit": "sync hit", "on_beat": "on the beat",
	"through": "through him", "mark": "marks", "dash": "dashes", "stagger": "he reeled",
	"pair_strike": "pair strikes", "sync": "sync %"}

var step = Step.MOVE
var boss
var rules
var _text  # tutorial_text.gd
var _counts = {}  # this step's: "<kind>:<player_id>" (0: theirs together) -> how many
var _wait = 0.0  # s before he's sent his next attack (counted while he's idle)
var _skip_held = 0.0
var _staggered = false
var _next_halves = "TRIPLE"
var _marks = {}  # MOVE: player_id -> {"node": Node2D, "reached": [bool, bool]}
var _dashing = {}  # DASH: player_id -> dashing last frame
var _sides = {}  # DASH PARRY: player_id -> their side of him last frame


# Its numbers on F2 (core/tuning.gd collects them).
static func tuning_entries() -> Array:
	return [
		{"page": "tutorial", "title": "Tutorial", "scenes": ["levels/tutorial/"], "header": "WHAT EACH STEP ASKS", "tab": "steps"},
		{"key": "tutorial_dashes", "label": "dash: each of you dashes (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_parries", "label": "parry: each of you parries (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_blocks", "label": "...and blocks (times)", "default": 1.0, "step": 1.0},
		{"key": "tutorial_colors", "label": "yellow then red: each parries (times)", "default": 3.0, "step": 1.0},
		{"key": "tutorial_halves", "label": "the halves: each parries (times)", "default": 3.0, "step": 1.0},
		{"key": "tutorial_through", "label": "dash-parry: each through him (times)", "default": 1.0, "step": 1.0},
		{"key": "tutorial_sync_hits", "label": "the sync hit: each lands (times)...", "default": 2.0, "step": 1.0},
		{"key": "tutorial_on_beat", "label": "...of them right on the beat", "default": 1.0, "step": 1.0},
		{"key": "tutorial_life_from", "label": "sync is life: their sync from (%)...", "default": 30.0, "step": 5.0},
		{"key": "tutorial_life_to", "label": "...filled up to (%)", "default": 50.0, "step": 5.0},
		{"key": "tutorial_staggers", "label": "green: parried together, he reels (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_pair_strikes", "label": "the sync mode: pair strikes landed (times)", "default": 2.0, "step": 1.0},
		{"header": "PACE", "column": 1},
		{"key": "tutorial_read_time", "label": "a step's words alone before his first attack (s)", "default": 2.5, "step": 0.25},
		{"key": "tutorial_pause", "label": "between two of his attacks (s)", "default": 0.9, "step": 0.1},
		{"key": "tutorial_skip_hold", "label": "Tab / pad Start held this long skips a step (s)", "default": 1.0, "step": 0.1},
	]


func _enter_tree():
	Moves.fix(SWITCHES)  # before he and the players are ready


func _exit_tree():
	Moves.unfix()


func _ready():
	boss = GameManager.boss
	rules = GameManager.rules
	rules.spared = true
	boss.dev_still = true  # a dummy: he stands where he is between his attacks
	var look = preload("res://levels/tutorial/dummy_look.gd").new()
	look.body = boss.body
	boss.body.add_child(look)
	boss.body.move_child(look, 0)  # under the halves that light up as he winds up
	_text = preload("res://levels/tutorial/tutorial_text.gd").new()
	add_child(_text)
	_text.show_hint(SKIP_HINT)
	for id in MARKS:
		var node = Node2D.new()
		node.z_index = 5
		node.draw.connect(_draw_marks.bind(node, id))
		add_child(node)
		_marks[id] = {"node": node, "reached": [false, false]}
	Dev.noted.connect(_on_noted)
	_begin(Step.MOVE)


# The stand-ins playing here (his child, and any a test adds): perfect, to get through every step.
func stand_ins() -> Array:
	return boss.get_children().filter(func(n): return n is BifronsStandIn)


func _begin(next: int):
	step = next
	_counts.clear()
	_wait = Tuning.value("tutorial_read_time")
	_staggered = false
	for id in _marks:
		_marks[id].reached = [false, false]
	_sides.clear()
	for stand_in in stand_ins():
		stand_in.perfect = true
		stand_in.block_next = int(Tuning.value("tutorial_blocks")) if step == Step.PARRY else 0
	rules.spared_team = SPARED_LOW if step == Step.SYNC_LIFE else SyncRules.SPARED_TEAM
	if step == Step.SYNC_LIFE:
		rules._set_team(rules.team_max() * Tuning.value("tutorial_life_from") / 100.0)
	if step == Step.SYNC_MODE:
		rules._set_team(rules.team_max())
	elif step != Step.DONE:
		Sfx.play("call_go", -4.0)
	_hud_pulse(PULSES.get(step, ""))
	_show()


func _hud_pulse(part: String):
	var hud = get_node_or_null("HUD")
	if hud != null and hud.has_method("pulse"):
		hud.pulse(part)


func _physics_process(delta):
	if not is_instance_valid(boss) or not is_instance_valid(rules):
		return
	if step < Step.SYNC_MODE and rules.team > rules.team_max() * BELOW_FULL:
		rules._set_team(rules.team_max() * BELOW_FULL)  # no sync mode before its step
	if step == Step.SYNC_MODE and not rules.sync_mode:
		_fail()
		rules._set_team(rules.team_max())
	var stagger = boss.state == BaseBoss.State.STAGGER
	if stagger and not _staggered and step == Step.TOGETHER:
		_count("stagger", 0)
	_staggered = stagger
	_watch_moves()
	_skip(delta)
	if _done():
		_begin(step + 1)
	_drive(delta)
	_show()


# MOVE, DASH, DASH PARRY: each player's marks reached, dashes and passes through him.
func _watch_moves():
	for p in GameManager.players:
		if not is_instance_valid(p):
			continue
		var id = p.player_id
		match step:
			Step.MOVE:
				var reached = _marks[id].reached
				for i in 2:
					if not reached[i] and p.global_position.distance_to(mark_point(id, i)) <= MARK_REACH:
						reached[i] = true
						_count("mark", id)
						Sfx.play("call_tick", -6.0)
			Step.DASH:
				var dashing = p.is_dashing()
				if dashing and not _dashing.get(id, false):
					_count("dash", id)
				_dashing[id] = dashing
			Step.DASH_PARRY:
				var side = signf(p.global_position.x - boss.global_position.x)
				if _sides.has(id) and side != 0.0 and side != _sides[id]:
					_count("through", id)
				if side != 0.0:
					_sides[id] = side
	for id in _marks:
		_marks[id].node.visibility_layer = MirrorView.half_bit(id)
		_marks[id].node.queue_redraw()


# Where a player's mark is: 0 on the floor, 1 up in the air (at a standing player's middle).
func mark_point(id: int, i: int) -> Vector2:
	var middle = BaseBoss.ARENA_FLOOR_Y - 20.0  # a player is 40 high
	return Vector2(MARKS[id][i], middle - (MARK_HEIGHT if i == 1 else 0.0))


func _draw_marks(node: Node2D, id: int):
	if step != Step.MOVE:
		return
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU)
	for i in 2:
		if _marks[id].reached[i]:
			continue
		var at = mark_point(id, i)
		node.draw_circle(at, MARK_RADIUS * (0.8 + 0.2 * pulse), Color(MARK_COLOR, 0.3 + 0.3 * pulse))
		node.draw_arc(at, MARK_RADIUS + 4.0, 0.0, TAU, 24, MARK_COLOR, 2.0, true)


# His next attack, as the step wants it; none while the lab holds him, while they move, in the
# sync mode's step (there he fights as he does in their sync mode) or once it's done.
func _drive(delta: float):
	if boss.state != BaseBoss.State.IDLE:
		return
	if step == Step.SYNC_MODE:
		return
	if boss.dev_next == "" and boss.timer < 0.1:
		boss.timer = 0.1  # none of his own: only what's sent
	var attack = _attack()
	if boss.dev_hold or attack == "":
		return
	_wait -= delta
	if _wait > 0.0 or boss.dev_next != "":
		return
	boss.dev_next = attack
	boss.timer = 0.0
	_wait = Tuning.value("tutorial_pause")


# The step's attack, or "" for none.
func _attack() -> String:
	match step:
		Step.MOVE, Step.DASH, Step.DONE:
			return ""
		Step.HALVES:
			_next_halves = "DOUBLE" if _next_halves == "TRIPLE" else "TRIPLE"
			return _next_halves
		Step.COLORS:
			return "TRIPLE"
		Step.SYNC_LIFE:
			return "DOUBLE"  # a chance at a sync hit for each
		Step.TOGETHER:
			return "BOTH" if boss.is_ppe() else "CROSSING"
	return "SINGLE"


# Each event of the fight's log (Dev.noted): counted for the step it serves.
func _on_noted(kind: String, data: Dictionary):
	var id = data.get("player", 0)
	match kind:
		"parry", "block":
			_count(kind, id)
		"sync_hit":
			_count(kind, id)
			if data.get("on_beat", false):
				_count("on_beat", id)
		"pair_strike":
			_count(kind, 0)
		"hit":
			if step != Step.DONE:
				_fail()


func _count(kind: String, id: int):
	var key = "%s:%d" % [kind, id]
	_counts[key] = _counts.get(key, 0) + 1


func count(kind: String, id: int) -> int:
	return _counts.get("%s:%d" % [kind, id], 0)


# What's there of what the step asks: the count; their sync in % (SYNC LIFE); for a player the
# stand-in plays, all of what it can't do.
func _have(kind: String, id: int) -> int:
	if kind == "sync":
		return int(round(rules.team_share() * 100.0))
	if kind in ["mark", "dash", "through"] and _stand_in_plays(id):
		return 99
	return count(kind, id)


func _stand_in_plays(id: int) -> bool:
	return stand_ins().any(func(s): return s.playing() != null and s.playing().player_id == id)


# A hit got through (or the sync mode was lost): the step's count starts over.
func _fail():
	_counts.clear()


# What the step asks: [kind, player_id (0: together), how many (a number on F2, or a count)].
func _asks() -> Array:
	match step:
		Step.MOVE:
			return [["mark", 1, 2], ["mark", 2, 2]]
		Step.DASH:
			return [["dash", 1, "tutorial_dashes"], ["dash", 2, "tutorial_dashes"]]
		Step.PARRY:
			return [["parry", 1, "tutorial_parries"], ["parry", 2, "tutorial_parries"],
				["block", 1, "tutorial_blocks"], ["block", 2, "tutorial_blocks"]]
		Step.COLORS:
			return [["parry", 1, "tutorial_colors"], ["parry", 2, "tutorial_colors"]]
		Step.HALVES:
			return [["parry", 1, "tutorial_halves"], ["parry", 2, "tutorial_halves"]]
		Step.DASH_PARRY:
			return [["through", 1, "tutorial_through"], ["through", 2, "tutorial_through"]]
		Step.SYNC_HIT:
			return [["sync_hit", 1, "tutorial_sync_hits"], ["sync_hit", 2, "tutorial_sync_hits"],
				["on_beat", 1, "tutorial_on_beat"], ["on_beat", 2, "tutorial_on_beat"]]
		Step.SYNC_LIFE:
			return [["sync", 0, "tutorial_life_to"]]
		Step.TOGETHER:
			return [["stagger", 0, "tutorial_staggers"]]
		Step.SYNC_MODE:
			return [["pair_strike", 0, "tutorial_pair_strikes"]]
	return []


func _wanted(ask: Array) -> int:
	return int(Tuning.value(ask[2])) if ask[2] is String else ask[2]


func _done() -> bool:
	if step == Step.DONE:
		return false
	return _asks().all(func(a): return _have(a[0], a[1]) >= _wanted(a))


# SKIP: Tab, or Start on any pad, held a moment.
func _skip(delta: float):
	var held = Input.is_key_pressed(KEY_TAB)
	for pad in Input.get_connected_joypads():
		held = held or Input.is_joy_button_pressed(pad, JOY_BUTTON_START)
	_skip_held = _skip_held + delta if held and step != Step.DONE else 0.0
	if _skip_held >= Tuning.value("tutorial_skip_hold"):
		_skip_held = 0.0
		skip()


func skip():
	if step != Step.DONE:
		_begin(step + 1)


# Done: on to the first boss.
func _unhandled_input(event):
	if step != Step.DONE:
		return
	var key = event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	var pad = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A
	if key or pad:
		get_viewport().set_input_as_handled()
		GameManager.start_fight(NEXT_SCENE)


# The words, each said once (TEXTS: above, and below if it's longer), what one player is to do in
# their own half, and how far each has got in theirs (what's theirs together, above).
func _show():
	var texts = {1: TEXTS[step][0], 2: TEXTS[step][1]}
	var progress = {}
	for id in [1, 2]:
		progress[id] = _progress_of(id)
	if step == Step.SYNC_HIT:
		for p in GameManager.players:
			if is_instance_valid(p) and p.partner() != null:
				var at_them = boss.time_to_strike(p) != INF
				texts[p.player_id] = _lines(texts[p.player_id], PARRY_NOW if at_them else STRIKE_ON_PINK)
	if step == Step.TOGETHER and not boss.is_ppe():
		texts[2] = _lines(texts[2], GET_TOGETHER)
	_text.show_lines(texts, progress)
	_text.show_hint("" if step == Step.DONE else SKIP_HINT)


func _lines(first: String, then: String) -> String:
	return then if first == "" else first + "\n" + then


func _progress_of(id: int) -> String:
	var parts = []
	for a in _asks():
		if a[1] == id or (a[1] == 0 and id == 1):
			parts.append("%s %d/%d" % [KINDS[a[0]], mini(_have(a[0], a[1]), _wanted(a)), _wanted(a)])
	return "   ".join(parts)
