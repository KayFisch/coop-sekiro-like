extends Node
## Autoload "Dev": tools for building and tuning fights, for any boss (docs/dev_tools.md).
##   F3  overlay: frame time, the boss's state and attack, each player's state, and this fight's
##       log in numbers: parries, blocks, hits, how early or late the presses came, sync hits.
##   F4  hitboxes: every collision shape, and the boss's body block.
##   F5  boss lab: run one of his attacks, loop it, hold him off, slow the game, fill or empty the
##       meters, make the players invincible, put them on his sides. Its keys work while it's open
##       and are none of the players' (see LAB_KEYS).
## The log: each fight's events, counted for the overlay and, with F1 → Dev "fight_log", written
## to user://fight_log.jsonl (one JSON line per event; the file starts over with each fight).
## Code tells it what happened: defended() from the player, note() and the others below from a
## boss or the sync rules.

const LOG_PATH = "user://fight_log.jsonl"
const NO_PRESS = 0.6  # s: a block press longer ago than this when a strike lands is no try at it
const LATE_WATCH = 0.3  # s after a strike landed in which a block press counts as late
const SPEEDS = [1.0, 0.5, 0.25]  # the lab's game speeds (T)
const FRAME_SAMPLES = 120
const FONT_SIZE = 13
const COLOR_TEXT = Color(0.85, 1.0, 0.85)
const COLOR_BLOCK = Color(1.0, 0.3, 0.3, 0.8)
const COLOR_BACK = Color(0.0, 0.0, 0.0, 0.62)
const PANEL_TOP = 104.0  # under the HUD's meters
const PANEL_MARGIN = 12.0
# The lab's keys: none of them is a player's (P1: A D W S Space Shift F Enter Up Down, R, Esc, M).
const LAB_KEYS = """PgUp/PgDn pick · Home run it · End loop it · H hold him · T speed
I invincible · K/J/N your sync full/half/none · B his sync full · P posture full
←/→ both on his left/right · G one on each side"""

var speed = 1.0  # the lab's game speed; Engine.time_scale is this times anything slowing it more (SyncBond)
var overlay_on = false
var hitboxes_on = false
var lab_on = false
var invincible = false

var _layer: CanvasLayer
var _overlay: Label
var _lab: Label
var _world: Node2D  # draws the boss's body block over the world (F4)
var _frames = []  # real ms per frame, the last FRAME_SAMPLES
var _last_tick = 0
var _pick = 0
var _loop = ""
var _log = []  # this fight's events
var _stats = {}  # player id -> counters and lists (see _stats_of())
var _watch = {}  # player -> [real time a strike landed on them, their last block press then]
var _scene = null  # the scene the log is for
var _file: FileAccess


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 90  # over the game and its HUD, under the F1 / F2 panels (100)
	add_child(_layer)
	_overlay = _label()
	_lab = _label()
	_world = Node2D.new()
	_world.top_level = true
	_world.z_index = 100
	_world.draw.connect(_draw_world)
	add_child(_world)
	_refresh_visibility()


func _label() -> Label:
	var label = Label.new()
	var back = StyleBoxFlat.new()
	back.bg_color = COLOR_BACK
	back.set_content_margin_all(6.0)
	label.add_theme_stylebox_override("normal", back)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_layer.add_child(label)
	return label


func _process(_delta):
	var now = Time.get_ticks_usec()
	if _last_tick > 0:
		_frames.append((now - _last_tick) / 1000.0)
		if _frames.size() > FRAME_SAMPLES:
			_frames.pop_front()
	_last_tick = now
	if get_tree().current_scene != _scene:
		_new_fight()
	_watch_late()
	_run_loop()
	for p in GameManager.players:
		if is_instance_valid(p) and invincible:
			p.invincible = true
	if overlay_on:
		_overlay.text = _overlay_text()
		_overlay.size = Vector2.ZERO  # shrinks to the text
		_overlay.position = Vector2(PANEL_MARGIN, PANEL_TOP)
	if lab_on:
		_lab.text = _lab_text()
		_lab.size = Vector2.ZERO
		var width = _layer.get_viewport().get_visible_rect().size.x
		_lab.position = Vector2(width - _lab.size.x - PANEL_MARGIN, PANEL_TOP)
	if hitboxes_on:
		_world.queue_redraw()


# --- Keys ---

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if Moves.panel_open or Tuning.panel_open:
		return
	match event.physical_keycode:
		KEY_F3:
			overlay_on = not overlay_on
		KEY_F4:
			_set_hitboxes(not hitboxes_on)
		KEY_F5:
			lab_on = not lab_on
		_:
			if not lab_on or not _lab_key(event.physical_keycode):
				return
	_refresh_visibility()
	get_viewport().set_input_as_handled()


# The lab's keys (LAB_KEYS); true if it was one.
func _lab_key(key: int) -> bool:
	var boss = _boss()
	var names = _attack_names()
	match key:
		KEY_PAGEUP, KEY_PAGEDOWN:
			if not names.is_empty():
				_pick = posmod(_pick + (-1 if key == KEY_PAGEUP else 1), names.size())
		KEY_HOME:
			if boss and not names.is_empty():
				run_attack(names[_pick])
		KEY_END:
			_loop = "" if _loop != "" or names.is_empty() else names[_pick]
		KEY_H:
			if boss:
				boss.dev_hold = not boss.dev_hold
		KEY_T:
			set_speed(SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()])
		KEY_I:
			invincible = not invincible
			for p in GameManager.players:
				if is_instance_valid(p):
					p.invincible = invincible
		KEY_K, KEY_J, KEY_N:
			_set_team({KEY_K: 1.0, KEY_J: 0.5, KEY_N: 0.0}[key])
		KEY_B:
			if GameManager.rules != null:
				GameManager.rules.boss_sync = GameManager.rules.boss_max()
				GameManager.rules.boss_chaos = false
		KEY_P:
			if GameManager.rules != null:
				for actor in GameManager.rules._posture:
					GameManager.rules._posture[actor] = GameManager.rules.posture_max(actor)
		KEY_LEFT, KEY_RIGHT, KEY_G:
			_place_players(key)
		_:
			return false
	return true


# --- The lab ---

func _boss():
	return GameManager.boss if is_instance_valid(GameManager.boss) else null


func _attack_names() -> Array:
	var boss = _boss()
	return boss.attack_pool.map(func(a): return a.get_attack_name()) if boss else []


# He starts that attack as soon as he's free (at once if he's idle).
func run_attack(attack_name: String):
	var boss = _boss()
	if boss == null:
		return
	boss.dev_next = attack_name
	if boss.state == BaseBoss.State.IDLE:
		boss.timer = 0.0


# The loop: each time he's idle again, the same attack once more.
func _run_loop():
	var boss = _boss()
	if _loop == "" or boss == null:
		return
	if boss.state == BaseBoss.State.IDLE and boss.dev_next == "":
		boss.dev_next = _loop


func set_speed(value: float):
	speed = value
	Engine.time_scale = speed


func _set_team(share: float):
	var rules = GameManager.rules
	if rules == null:
		return
	rules._set_team(rules.team_max() * share)


# Both players on his left, on his right, or one on each side (G), a little apart from him.
func _place_players(key: int):
	var boss = _boss()
	var players = GameManager.players.filter(func(p): return is_instance_valid(p))
	if boss == null or players.size() < 2:
		return
	var x = boss.global_position.x
	var spots = {KEY_LEFT: [x - 130.0, x - 100.0], KEY_RIGHT: [x + 100.0, x + 130.0], KEY_G: [x - 120.0, x + 120.0]}[key]
	for i in 2:
		players[i].global_position.x = clampf(spots[i], BaseBoss.ARENA_LEFT + 20.0, BaseBoss.ARENA_RIGHT - 20.0)
		players[i].velocity = Vector2.ZERO


# --- Hitboxes ---

func _set_hitboxes(on: bool):
	hitboxes_on = on
	get_tree().debug_collisions_hint = on
	var scene = get_tree().current_scene
	if scene:
		_redraw_shapes(scene)
	_world.queue_redraw()


func _redraw_shapes(node: Node):
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.queue_redraw()
	for child in node.get_children():
		_redraw_shapes(child)


func _draw_world():
	var boss = _boss()
	if not hitboxes_on or boss == null:
		return
	var block: Rect2 = boss.body_block()
	if block.size != Vector2.ZERO:
		_world.draw_rect(block, COLOR_BLOCK, false, 2.0)


# --- The log ---

# A strike landed on a player (Player.on_perfect_parry(), take_damage()): "parry", "block" or
# "hit", and how long before the landing their last block press came (s; large: none).
func defended(p, how: String, since_press: float):
	var s = _stats_of(p)
	s[how] += 1
	if how == "parry":
		s.parry_press.append(since_press)
	elif how == "hit":
		if since_press < NO_PRESS:
			s.early.append(since_press)
		else:
			_watch[p] = [p._now(), p._last_block_press]
	note(how, {"player": p.player_id, "since_press": snappedf(since_press, 0.001)})


# A hit through the partner's window (ColumnaBifrons): this long after it opened, on the beat or not.
func sync_hit(p, after_open: float, on_beat: bool):
	var s = _stats_of(p)
	s.sync_beat += 1 if on_beat else 0
	s.sync_after += 0 if on_beat else 1
	s.window_offsets.append(after_open)
	note("sync_hit", {"player": p.player_id, "after_open": snappedf(after_open, 0.001), "on_beat": on_beat})


# A window nobody used while someone could have.
func window_missed():
	_stats_of(null).windows_missed += 1
	note("window_missed", {})


# The bound pair's strike (SyncBond): a player let go this far off the big cue (s; negative:
# before), in time or not.
func pair_release(p, off_cue: float, in_time: bool):
	var s = _stats_of(p)
	s.together += 1 if in_time else 0
	s.apart += 0 if in_time else 1
	if off_cue > -10.0:
		s.release_offsets.append(off_cue)
	note("pair_release", {"player": p.player_id, "off_cue": snappedf(off_cue, 0.001), "in_time": in_time})


func note(kind: String, data = {}):
	var entry = {"t": snappedf(GameManager.elapsed_time, 0.001), "kind": kind}
	entry.merge(data)
	_log.append(entry)
	if _file:
		_file.store_line(JSON.stringify(entry))
		_file.flush()


func _stats_of(p) -> Dictionary:
	var id = p.player_id if p != null else 0
	if not _stats.has(id):
		_stats[id] = {"parry": 0, "block": 0, "hit": 0, "parry_press": [], "early": [], "late": [],
			"sync_beat": 0, "sync_after": 0, "window_offsets": [], "windows_missed": 0,
			"together": 0, "apart": 0, "release_offsets": []}
	return _stats[id]


# A new scene: a new log.
func _new_fight():
	_scene = get_tree().current_scene
	_log.clear()
	_stats.clear()
	_watch.clear()
	_file = null
	if Moves.on("fight_log") and _scene != null:
		_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		note("start", {"scene": _scene.scene_file_path})
	if hitboxes_on:
		_set_hitboxes.call_deferred(true)  # the new scene's shapes too


# A block press that came just after a strike landed (and missed it): late, by how much.
func _watch_late():
	for p in _watch.keys():
		if not is_instance_valid(p):
			_watch.erase(p)
			continue
		var landed = _watch[p][0]
		if p._last_block_press > _watch[p][1] and p._last_block_press - landed <= LATE_WATCH:
			_stats_of(p).late.append(p._last_block_press - landed)
			note("late_press", {"player": p.player_id, "late_by": snappedf(p._last_block_press - landed, 0.001)})
			_watch.erase(p)
		elif p._now() - landed > LATE_WATCH:
			_watch.erase(p)


# --- Text ---

func _refresh_visibility():
	_overlay.visible = overlay_on
	_lab.visible = lab_on


func _overlay_text() -> String:
	var lines = ["DEV   F3 overlay · F4 hitboxes · F5 boss lab"]
	var sorted = _frames.duplicate()
	sorted.sort()
	var mean = 0.0
	for ms in _frames:
		mean += ms
	mean /= maxf(_frames.size(), 1)
	lines.append("%.0f fps · %.2f ms a frame (95%%: %.1f, worst %.1f) · %d nodes · %d draw calls · speed x%.2f" % [
		1000.0 / maxf(mean, 0.001), mean, _percentile(sorted, 0.95), sorted.back() if not sorted.is_empty() else 0.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.time_scale])
	var boss = _boss()
	var rules = GameManager.rules
	if boss:
		var attack = boss.current_attack
		var doing = ""
		if attack:
			doing = "  %s (phase %d, %.2f s)" % [attack.get_attack_name(), attack.phase, attack.timer]
		lines.append("%s: %s%s · timer %.2f%s%s" % [boss.get_display_name(), BaseBoss.State.keys()[boss.state], doing,
			boss.timer, " · HELD" if boss.dev_hold else "", " · loop " + _loop if _loop != "" else ""])
		if rules != null:
			lines.append("  his sync %.1f/%.0f%s · posture %.1f/%.0f (%s) · yours %.1f/%.0f%s" % [
				rules.boss_sync, rules.boss_max(), " SPLIT" if rules.boss_chaos else "",
				rules.posture_of(boss), rules.posture_max(boss),
				"coming back %.0f%%" % (100.0 * rules.regen_share(boss)) if rules.regenerating(boss) else "held",
				rules.team, rules.team_max(), " CHAOS" if rules.team_chaos else (" SYNC MODE" if rules.sync_mode else "")])
		else:
			lines.append("  health %.0f/%.0f" % [boss.hp, boss.get_max_hp()])
	for p in GameManager.players:
		if not is_instance_valid(p):
			continue
		var parts = [p.movement_state()]
		if p.is_perfect_parry():
			parts.append("PARRY WINDOW")
		elif p.is_blocking():
			parts.append("blocking")
		if p._is_swinging():
			parts.append("swinging")
		if p.is_staggered():
			parts.append("staggered")
		if p.invincible:
			parts.append("invincible")
		if rules != null:
			parts.append("posture %.0f%s" % [rules.posture_of(p), "" if rules.regenerating(p) else " (held)"])
		lines.append("P%d: %s" % [p.player_id, " · ".join(parts)])
	lines.append("")
	lines.append("THIS FIGHT, %.0f s%s" % [GameManager.elapsed_time, " (logging to user://fight_log.jsonl)" if _file else ""])
	var ids = _stats.keys()
	ids.sort()
	for id in ids:
		var s = _stats[id]
		if id == 0:
			lines.append("  windows nobody used: %d" % s.windows_missed)
			continue
		lines.append("  P%d: parried %d · blocked %d · hit %d · parry pressed %s before · missed: too early %d%s, late %d%s, no press %d" % [
			id, s.parry, s.block, s.hit, _median(s.parry_press), s.early.size(), _median_in(s.early),
			s.late.size(), _median_in(s.late), s.hit - s.early.size() - s.late.size()])
		if s.sync_beat + s.sync_after + s.together + s.apart > 0:
			lines.append("      sync hits: %d on the beat, %d after (%s into the window) · together on the cue %d, out of sync %d (%s off)" % [
				s.sync_beat, s.sync_after, _median(s.window_offsets), s.together, s.apart, _median(s.release_offsets)])
	return "\n".join(lines)


func _lab_text() -> String:
	var boss = _boss()
	if boss == null:
		return "BOSS LAB (F5): no boss here"
	var lines = ["BOSS LAB (F5): %s" % boss.get_display_name(), LAB_KEYS, ""]
	var names = _attack_names()
	_pick = clampi(_pick, 0, maxi(names.size() - 1, 0))
	for i in names.size():
		var tags = []
		if names[i] == _loop:
			tags.append("looping")
		if boss.current_attack and boss.current_attack.get_attack_name() == names[i]:
			tags.append("now")
		lines.append("%s %s %s" % ["▶" if i == _pick else " ", names[i], "(" + ", ".join(tags) + ")" if tags else ""])
	lines.append("")
	lines.append("him held: %s · speed x%.2f · invincible: %s" % ["ON" if boss.dev_hold else "off", speed, "ON" if invincible else "off"])
	return "\n".join(lines)


func _median(values: Array) -> String:
	if values.is_empty():
		return "-"
	var sorted = values.duplicate()
	sorted.sort()
	return "%.2f s" % sorted[sorted.size() / 2]


func _median_in(values: Array) -> String:
	return "" if values.is_empty() else " (%s)" % _median(values)


func _percentile(sorted: Array, share: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(int(sorted.size() * share), sorted.size() - 1)]
