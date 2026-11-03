extends Node2D
## The tutorial (docs/tutorial.md): a guided fight against a training dummy, step by step, on the
## mirrored screen as every fight. The dummy is the try-out boss in a dummy's look
## (dummy_look.gd), standing still between his attacks; the tutorial picks each one (dev_next, as
## the F5 lab's loop does), and none while the lab holds him (dev_hold). Its switches are held
## while it's here (Moves.fix(), as the Warden's room does), whatever F1 says.
##
## THE STEPS, each one sentence (the principle, no numbers), on until its condition is met (how
## many: F2, page "tutorial"):
##   1. PARRY: a strike at each, in turn. Each parries and blocks.
##   2. COLORS: yellow, it's for you; red, now. Each parries.
##   3. HALVES: in your half your blade stands out, your partner's hardly. Each parries.
##   4. SYNC HIT: a parry sends its energy to the partner (pink), their hit then is a sync hit. Each
##      lands some: both ways. Each half tells its player what to do: parry, or wait and strike.
##   5. TOGETHER: green, two blades on one place: parried together, he reels. Apart (pep), his
##      crossing brings them to one side first.
##   6. SYNC MODE: their sync full; together they bind, one steers, both draw back and let go on
##      the big cue. Pair strikes landed.
## Then "done": Enter / pad A on to the first boss, Esc the select screen.
##
## NO DEFEAT: the sync rules spare everyone (SyncRules.spared: no chaos, no posture broken), and a
## hit that gets through starts the step's count over. Out of the sync mode in step 6, it starts
## over too, the sync full again. Before step 6 their sync stays short of full (no sync mode yet).
## SKIP: Tab on the keyboard or Start on a pad, held a moment. ALONE: the stand-in (F1 Fights
## "Stand-in") plays the partner, and here it gets through every step (BifronsStandIn.perfect).

enum Step { PARRY, COLORS, HALVES, SYNC_HIT, TOGETHER, SYNC_MODE, DONE }

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
const TEXTS = {
	Step.PARRY: "He strikes at each of you in turn. Hold block to take a blow; press block just as it lands to parry it.",
	Step.COLORS: "Yellow: this one is for you. Red: now.",
	Step.HALVES: "Your half shows the blades aimed at you; your partner's you hardly see.",
	Step.SYNC_HIT: "A parry sends its energy to your partner, in pink: when it reaches them, their hit is a sync hit.",
	Step.TOGETHER: "Green: two blades on one place. Parry them together, and he reels.",
	Step.SYNC_MODE: "Your sync is full. Stand together to bind: the upper one steers. Both hold attack, and let go on the big cue.",
	Step.DONE: "Done. Enter or A: on to the first boss.   Esc: back to the select screen.",
}
const PARRY_NOW = "Parry him."  # SYNC HIT: in the half he's about to strike...
const STRIKE_ON_PINK = "Wait for the pink, then strike."  # ...and in the other one
const GET_TOGETHER = "He'll bring you both to one side of him."  # TOGETHER, apart (pep)
const AGAIN = "Hit: once more."
const SKIP_HINT = "Hold Tab or pad Start: skip this step"

var step = Step.PARRY
var boss
var rules
var _text  # tutorial_text.gd
var _counts = {}  # this step's: "<kind>:<player_id>" (0: theirs together) -> how many
var _wait = 0.0  # s before he's sent his next attack (counted while he's idle)
var _skip_held = 0.0
var _again = 0.0  # s "once more" is still shown
var _staggered = false
var _next_halves = "TRIPLE"


# Its numbers on F2 (core/tuning.gd collects them).
static func tuning_entries() -> Array:
	return [
		{"page": "tutorial", "title": "Tutorial", "scenes": ["levels/tutorial/"], "header": "WHAT EACH STEP ASKS", "tab": "steps"},
		{"key": "tutorial_parries", "label": "1, parry: each of you parries (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_blocks", "label": "...and blocks (times)", "default": 1.0, "step": 1.0},
		{"key": "tutorial_colors", "label": "2, yellow then red: each parries (times)", "default": 3.0, "step": 1.0},
		{"key": "tutorial_halves", "label": "3, the halves: each parries (times)", "default": 3.0, "step": 1.0},
		{"key": "tutorial_sync_hits", "label": "4, the sync hit: each lands (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_staggers", "label": "5, green: parried together, he reels (times)", "default": 2.0, "step": 1.0},
		{"key": "tutorial_pair_strikes", "label": "6, the sync mode: pair strikes landed (times)", "default": 2.0, "step": 1.0},
		{"header": "PACE", "column": 1},
		{"key": "tutorial_read_time", "label": "a step's words alone before his first attack (s)", "default": 2.5, "step": 0.25},
		{"key": "tutorial_pause", "label": "between two of his attacks (s)", "default": 0.9, "step": 0.1},
		{"key": "tutorial_again_time", "label": "a hit got through: \"once more\" shown (s)", "default": 1.5, "step": 0.1},
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
	Dev.noted.connect(_on_noted)
	_begin(Step.PARRY)


# The stand-ins playing here (his child, and any a test adds): perfect, to get through every step.
func stand_ins() -> Array:
	return boss.get_children().filter(func(n): return n is BifronsStandIn)


func _begin(next: int):
	step = next
	_counts.clear()
	_wait = Tuning.value("tutorial_read_time")
	_staggered = false
	for stand_in in stand_ins():
		stand_in.perfect = true
		stand_in.block_next = int(Tuning.value("tutorial_blocks")) if step == Step.PARRY else 0
	if step == Step.SYNC_MODE:
		rules._set_team(rules.team_max())
	elif step != Step.DONE:
		Sfx.play("call_go", -4.0)
	_show()


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
	_again = maxf(_again - delta, 0.0)
	_skip(delta)
	if _done():
		_begin(step + 1)
	_drive(delta)
	_show()


# His next attack, as the step wants it; none while the lab holds him, or in the sync mode's step
# (there he fights as he does in their sync mode) or once it's done.
func _drive(delta: float):
	if boss.state != BaseBoss.State.IDLE:
		return
	if step == Step.SYNC_MODE:
		return
	if boss.dev_next == "" and boss.timer < 0.1:
		boss.timer = 0.1  # none of his own: only what's sent
	if boss.dev_hold or step == Step.DONE:
		return
	_wait -= delta
	if _wait > 0.0 or boss.dev_next != "":
		return
	boss.dev_next = _attack()
	boss.timer = 0.0
	_wait = Tuning.value("tutorial_pause")


func _attack() -> String:
	match step:
		Step.HALVES:
			_next_halves = "DOUBLE" if _next_halves == "TRIPLE" else "TRIPLE"
			return _next_halves
		Step.COLORS:
			return "TRIPLE"
		Step.TOGETHER:
			return "BOTH" if boss.is_ppe() else "CROSSING"
	return "SINGLE"


# Each event of the fight's log (Dev.noted): counted for the step it serves.
func _on_noted(kind: String, data: Dictionary):
	var id = data.get("player", 0)
	match kind:
		"parry", "block", "sync_hit", "pair_strike":
			_count(kind, 0 if kind == "pair_strike" else id)
		"hit":
			if step != Step.DONE:
				_fail()


func _count(kind: String, id: int):
	var key = "%s:%d" % [kind, id]
	_counts[key] = _counts.get(key, 0) + 1


func count(kind: String, id: int) -> int:
	return _counts.get("%s:%d" % [kind, id], 0)


# A hit got through (or the sync mode was lost): the step's count starts over.
func _fail():
	_counts.clear()
	_again = Tuning.value("tutorial_again_time")


# What the step asks, and whether it's there: [kind, player_id (0: together), how many].
func _asks() -> Array:
	match step:
		Step.PARRY:
			return [["parry", 1, "tutorial_parries"], ["parry", 2, "tutorial_parries"],
				["block", 1, "tutorial_blocks"], ["block", 2, "tutorial_blocks"]]
		Step.COLORS:
			return [["parry", 1, "tutorial_colors"], ["parry", 2, "tutorial_colors"]]
		Step.HALVES:
			return [["parry", 1, "tutorial_halves"], ["parry", 2, "tutorial_halves"]]
		Step.SYNC_HIT:
			return [["sync_hit", 1, "tutorial_sync_hits"], ["sync_hit", 2, "tutorial_sync_hits"]]
		Step.TOGETHER:
			return [["stagger", 0, "tutorial_staggers"]]
		Step.SYNC_MODE:
			return [["pair_strike", 0, "tutorial_pair_strikes"]]
	return []


func _done() -> bool:
	if step == Step.DONE:
		return false
	return _asks().all(func(a): return count(a[0], a[1]) >= int(Tuning.value(a[2])))


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


# The words in each half, and how far each player has got.
func _show():
	var texts = {}
	var progress = {}
	for id in [1, 2]:
		texts[id] = AGAIN if _again > 0.0 else TEXTS[step]
		progress[id] = _progress_of(id)
	if _again <= 0.0 and step == Step.SYNC_HIT:
		for p in GameManager.players:
			if is_instance_valid(p) and p.partner() != null:
				var at_them = boss.time_to_strike(p) != INF
				texts[p.player_id] = TEXTS[step] + "\n" + (PARRY_NOW if at_them else STRIKE_ON_PINK)
	if _again <= 0.0 and step == Step.TOGETHER and not boss.is_ppe():
		for id in [1, 2]:
			texts[id] = TEXTS[step] + "\n" + GET_TOGETHER
	_text.show_lines(texts, progress, _again > 0.0)
	_text.show_hint("" if step == Step.DONE else SKIP_HINT)


func _progress_of(id: int) -> String:
	var parts = []
	for a in _asks():
		if a[1] == id or a[1] == 0:
			parts.append("%s %d/%d" % [a[0].replace("_", " "), count(a[0], a[1]), int(Tuning.value(a[2]))])
	return "   ".join(parts)
