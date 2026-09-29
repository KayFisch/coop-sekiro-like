extends CanvasLayer
## The gyms' HUD: the room's name and keys, and a live readout per player (Tab toggles it) for
## feeling out and tuning the movement: current speed, and for the last jump its peak (feet,
## above take-off), air time and distance, the last dash's length and the last launch's height,
## plus which air moves are still available.

const READOUT_COLOR = Color(1, 1, 1, 0.85)

var room_name = ""
var players: Array = []

var _readouts: Array = []  # Label per player
var _tracks: Array = []  # Dictionary per player, see _track()
var _readout_box: VBoxContainer


func _ready():
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var title = _label(root, Vector2(16, 10), room_name, 20)
	title.modulate = Color(1, 1, 1, 0.9)
	_label(root, Vector2(16, 38), "R: back to the checkpoint · Tab: readout · F1: movement switches · Esc: menu", 12).modulate = Color(1, 1, 1, 0.55)

	_readout_box = VBoxContainer.new()
	# Along the bottom, over the floor, where it covers the least.
	_readout_box.anchor_top = 1.0
	_readout_box.anchor_bottom = 1.0
	_readout_box.offset_left = 16.0
	_readout_box.offset_top = -78.0 - 20.0 * players.size()
	_readout_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_readout_box)
	for p in players:
		var l = Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.modulate = p.body_color.lerp(Color.WHITE, 0.55)
		_readout_box.add_child(l)
		_readouts.append(l)
		_tracks.append({"grounded": true, "takeoff": p.global_position, "top": p.global_position.y,
			"air": 0.0, "peak": 0.0, "air_time": 0.0, "distance": 0.0,
			"dashing": false, "dash_from": 0.0, "dash": 0.0,
			"launching": false, "launch_from": 0.0, "launch": 0.0})

	var hint = Label.new()
	hint.text = "P1: A/D move · W jump · ←/→ dash · Space attack · ↑ + Space upslash · L-Ctrl block · S drop" \
		+ "\nP2 (pad): stick move · A jump · LB/RB dash · X attack · stick up + X upslash · RT block · stick down drop" \
		+ "\nIn the air: hold down to fast fall, down + attack to pogo · Into a wall: slide / cling, jump off it · Up or toward on a ledge: climb" \
		+ "\nDash-slash into your partner's upslash: launch · into their block: relay (hold a direction) · Wall jumps meeting: chimney clash"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16.0
	hint.offset_top = -74.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_readout_box.visible = not _readout_box.visible


func _physics_process(delta):
	for i in players.size():
		var p = players[i]
		if is_instance_valid(p):
			_track(p, _tracks[i], delta)
			_readouts[i].text = _describe(p, _tracks[i])


# Watches one player's movement, recording each finished jump, dash and launch.
func _track(p, t: Dictionary, delta: float):
	var pos = p.global_position
	var grounded = p.is_on_floor()
	if t.grounded and not grounded:
		t.takeoff = pos
		t.top = pos.y
		t.air = 0.0
	if not grounded:
		t.air += delta
		t.top = minf(t.top, pos.y)
	if grounded and not t.grounded:
		t.peak = t.takeoff.y - t.top
		t.air_time = t.air
		t.distance = absf(pos.x - t.takeoff.x)
	t.grounded = grounded

	var dashing = p._dash_timer > 0.0
	if dashing and not t.dashing:
		t.dash_from = pos.x
	if t.dashing and not dashing:
		t.dash = absf(pos.x - t.dash_from)
	t.dashing = dashing

	var launching = p.is_launching()
	if launching and not t.launching:
		t.launch_from = pos.y
	if t.launching and not launching:
		t.launch = t.launch_from - pos.y  # the launch's rise ends at its top
	t.launching = launching


func _describe(p, t: Dictionary) -> String:
	var v = p.velocity
	var moves = "air jump %s · dash %s · hop %s" % [
		"✓" if p._air_jumps > 0 else "–",
		"✓" if p._dash_ready and p._dash_cooldown <= 0.0 else "–",
		"✓" if p._upslash_hop_ready else "–"]
	return "P%d  %-11s  speed %4d  fall %5d  |  last jump: peak %3d px, %.2f s, %3d px across  |  dash %3d px  |  launch %3d px  |  %s" % [
		p.player_id, p.movement_state(), roundi(absf(v.x)), roundi(v.y), roundi(t.peak), t.air_time,
		roundi(t.distance), roundi(t.dash), roundi(t.launch), moves]


func _label(parent, pos: Vector2, text: String, font_size: int) -> Label:
	var l = Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
