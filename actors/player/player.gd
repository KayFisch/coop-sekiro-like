extends PlayerPartner
## A player, part 5 of 5: the player itself, the script the scene (player.tscn) and everyone else
## use. What a boss does to a player (parried, hit, staggered, blades locked), the pair's strike in
## sync mode, the look, and the frame, _physics_process(), which runs the parts in order.
## Parts 1 to 4, each extending the one before: player_body.gd, player_sword.gd, player_walls.gd,
## player_partner.gd.

signal damaged(player)
signal blocked(player)
signal died(player)
signal repainted  # new colors (paint()): a boss's swords that carry them follow

const HIT_INVULN_TIME = 0.6  # untouchable this long after a hit...
const CHIP_INVULN_TIME = 0.2  # ...or a blocked one
const HURT_FLASH_TIME = 0.5  # three 0.1s white flashes with 0.1s gaps...
const FLASH_DARK_ABOVE = 0.8  # ...black ones on a body this light (luminance), or they'd vanish
const IDLE_BOB_HEIGHT = 3.0
const IDLE_BOB_HZ = 0.6
# Hands: same proportions as the boss's (square, a fifth of the body's height, gripping the hilt).
const HAND_SIZE_RATIO = 0.2
const HAND_GRIPS = [0.075, 0.275]  # where each hand holds the sword, as a fraction of its length
const HAND_DARKEN = 0.25
# The sword's look, a little less of a needle than the scene's plain rect (its hitbox is the
# scene's, unchanged): a broader blade, a crossguard just past the hands, and a point.
const SWORD_WIDTH = 8.0  # px thick (the scene's rect: 6)
const SWORD_POINT = 7.0  # px at its end tapering to the point
const CROSSGUARD_AT = 0.36  # where the crossguard sits, as a fraction of the sword's length
const CROSSGUARD_SIZE = Vector2(4, 16)
# THE PAIR'S STRIKE (sync mode, core/sync_bond.gd): while the two are bound (`bond` set), attack
# is held to draw the sword back (fully in Tuning "sync_charge_time") and let go to strike; the
# bond times the two strikes and deals the hit, the swing itself deals none. A block press lets
# the drawn sword go, unstruck. Bound, the sword is a sabre: longer, curved, half light, half dark.
const DRAW_ANGLE = -2.5  # drawn back all the way: over the shoulder
const SABRE_LENGTH = 1.3  # the sabre: this much longer than the sword...
const SABRE_WIDTH = 11.0  # ...this broad at the hilt (px)...
const SABRE_CURVE = 12.0  # ...its point curving back by this much (px)
const SABRE_LIGHT = Color(0.95, 0.94, 0.9)
const SABRE_DARK = Color(0.07, 0.07, 0.09)

var is_clashing = false  # blades locked with a boss's or an obstacle's, held in place
var invincible = false  # testing: hits still land (flash, knockback) but cost nothing (see SyncRules)
var _invuln_timer = 0.0
var _hurt_flash = 0.0
var _bob_time = 0.0
var _body_rest = Vector2.ZERO
var _is_dead = false
var _cue_timer = 0.0  # cue_sync()
var _cue_color = Color.WHITE
var _hands: Array = []  # [ColorRect, ColorRect]
var _sword_tip: Polygon2D  # the blade's point (see SWORD_POINT)
var _crossguard: ColorRect
var bond = null  # core/sync_bond.gd while the two are bound in sync mode (THE PAIR'S STRIKE)
var _drawing = false  # attack held, the sword drawing back
var _draw_time = 0.0
var _sabre: Node2D  # the sword's look while bound (set_sabre())


# --- Setup and the frame -------------------------------------------------------------

func _ready():
	super()
	_body_rest = body.position
	_setup_sword()
	_setup_hands()
	GameManager.register_player(self)


# New colors for the body and the sword (the mirrored screen makes the players light and shadow).
func paint(new_body: Color, new_sword: Color):
	player_color = new_body
	sword_color = new_sword
	body_color = new_body
	_sword_color = new_sword
	repainted.emit()


func _physics_process(delta):
	_tick_timers(delta)
	if is_clashing:
		velocity = Vector2.ZERO  # braced, holding the other blade back
	elif is_held():
		_process_hold(delta)
	elif _ledge:
		_process_ledge(delta)
	elif is_staggered():
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
	elif _windup_timer > 0.0:
		_process_windup(delta)
		move_and_slide()
	else:
		_process_movement(delta)
		_process_actions()
		_check_pogo(delta)
		move_and_slide()
		if not _check_clashes():
			_check_chimney()
	_keep_out_of_boss(delta)
	_track_landing()
	_process_attack()
	_update_visuals()


func _tick_timers(delta):
	super(delta)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)


# --- Defensive queries used by the boss at the moment its hitbox connects ---

# Killed by a fight's rules (take_damage()): out until the fight starts over.
func is_dead() -> bool:
	return _is_dead


# --- What a boss does to a player: parried, hit, staggered, held in a clash ---

func on_perfect_parry(strong: bool):
	Dev.defended(self, "parry", _since(parry_press_time))
	if GameManager.rules:
		GameManager.rules.player_parried(self)
	parry_press_time = -100.0  # one press parries one hit
	last_block_press = -100.0  # a landed parry isn't mashing: the next press may parry at once
	_sword_flash = SWORD_FLASH_TIME
	_parry_flick = PARRY_FLICK_TIME
	Sfx.play("parry_strong" if strong else "parry")
	Fx.shake(self, 7.0 if strong else 4.0)
	if Moves.on("parry_pass"):
		_pass_timer = PASS_WINDOW
		if _dash_timer > 0.0 and not _dash_slash and _boss_ahead():
			# A dash-parry: the dash starts over from here, and goes through him.
			_dash_timer = DASH_TIME
			_passing = true
			_pass_timer = 0.0


# The sword lit in `color` for `duration`: the moment to strike (a sync hit's beat).
func cue_sync(duration: float, color: Color):
	_cue_timer = duration
	_cue_color = color


# A blow lands (`chip`: on a block): thrown back by `knockback`, briefly untouchable. What it
# costs is the fight's: on sync as life (core/sync_rules.gd) a hit costs the pair's sync and a
# block this one's posture, and in chaos a hit is the end. Elsewhere it costs nothing.
func take_damage(knockback = Vector2.ZERO, chip = false):
	if _is_dead or _invuln_timer > 0.0:
		return
	Dev.defended(self, "block" if chip else "hit", _since(last_block_press))
	var lethal = false
	if GameManager.rules:
		var rules = GameManager.rules
		lethal = rules.player_blocked(self) if chip else rules.player_hit(self)
	_invuln_timer = CHIP_INVULN_TIME if chip else HIT_INVULN_TIME
	interrupt_movement()
	_hurt_flash = HURT_FLASH_TIME
	velocity = knockback
	if chip:
		Sfx.play("chip")
	else:
		Sfx.play("hurt")
	if knockback != Vector2.ZERO:
		_knockback_timer = KNOCKBACK_TIME
		if not chip:
			Sfx.play_delayed("knockback", 0.06, -4.0)  # thrown back, just behind the impact
	if chip:
		blocked.emit(self)
	else:
		damaged.emit(self)
	if lethal:
		_is_dead = true
		died.emit(self)


# Reeling from a hit: can't move, block, parry or act until it wears off.
func stagger(duration: float):
	_stagger_timer = maxf(_stagger_timer, duration)
	velocity.x = 0.0
	interrupt_movement()
	_attack_timer = 0.0


# Blades locked with another (an obstacle's, a boss's): held in place, sword level against it.
func set_clashing(clashing: bool):
	is_clashing = clashing
	velocity = Vector2.ZERO
	interrupt_movement()
	_attack_timer = 0.0


# --- The look: the sword's angle, colors, flashes, effects, hands -----------------

# The blade's angle: flat against a blade it's locked with, drawn back for the pair's strike,
# else the sword's own (player_sword.gd).
func _sword_angle() -> float:
	if is_clashing or is_held():
		return 0.0  # held flat against the other blade
	if _drawing:
		return lerpf(SWORD_REST_ANGLE, DRAW_ANGLE, ease(draw_share(), 0.6))  # drawing back
	return super()


func _blade_taken() -> bool:
	return _drawing or is_clashing or is_held()


func _update_visuals():
	_update_tell(get_physics_process_delta_time())
	_update_beat_ring()
	# Idle bob while standing still on the ground; ease back to rest otherwise.
	var bob = 0.0
	if is_on_floor() and absf(velocity.x) < 1.0:
		_bob_time += get_physics_process_delta_time()
		# Rises from rest and back, never dipping into the floor.
		bob = -IDLE_BOB_HEIGHT * (0.5 - 0.5 * cos(_bob_time * TAU * IDLE_BOB_HZ))
	else:
		_bob_time = 0.0
	body.position.y = lerpf(body.position.y, _body_rest.y + bob, 0.3)
	# Straining to hold the boss back, or locked with the partner's blade: tremble.
	var straining = is_clashing or is_held()
	body.position.x = _body_rest.x + (randf_range(-2.0, 2.0) if straining else 0.0)
	# Aiming a relay: the arrow shows the way the boost will go.
	_relay_arrow.visible = _hold_kind == Hold.RELAY_DASHER
	if _relay_arrow.visible:
		_relay_arrow.rotation = _relay_dir.angle()
		_relay_arrow.color = body_color.lightened(0.6)

	# Guard pose: sword held diagonally down in front of the chest while blocking; in a clash,
	# level against the other blade; thrust forward through a dash-slash; otherwise held at the
	# side, diagonally up.
	_update_sword_idle(get_physics_process_delta_time())
	var sword_offset = Vector2(0.0, body.position.y - _body_rest.y)
	if is_clashing:
		sword_offset = Vector2(0.0, -4.0)
	elif _dash_slash and _dash_timer > 0.0:
		sword_offset = Vector2(DASH_SLASH_THRUST * facing, 0.0)
	elif _windup_timer > 0.0:
		sword_offset = Vector2(-DASH_SLASH_WINDUP_DRAW * facing, 0.0)
	elif is_blocking() and _attack_timer <= 0.0:
		sword_offset = Vector2(GUARD_OFFSET.x * facing, GUARD_OFFSET.y)
	sword_pivot.position = sword_pivot.position.lerp(sword_offset, 0.4)
	var dash_slashing = _dash_slash and _dash_timer > 0.0
	# A dash-slash draws the blade out long and white-hot (its hitbox scales along with it).
	sword_pivot.scale = Vector2(facing * (DASH_SLASH_REACH if dash_slashing else 1.0), 1.0)
	sword_pivot.rotation = _sword_angle() * facing
	_cue_timer = maxf(_cue_timer - get_physics_process_delta_time(), 0.0)
	if _sword_flash > 0.0:
		sword.color = Color.WHITE
	elif _cue_timer > 0.0:
		sword.color = _cue_color
	elif dash_slashing:
		sword.color = _sword_color.lerp(Color.WHITE, DASH_SLASH_GLOW)
	elif _windup_timer > 0.0:
		sword.color = _sword_color.lerp(Color.WHITE, _windup_progress())  # heating up: the cue to parry
	else:
		sword.color = _sword_color
	_sword_tip.color = sword.color
	if dash_slashing:
		_trail_timer -= get_physics_process_delta_time()
		if _trail_timer <= 0.0:
			_trail_timer += DASH_SLASH_TRAIL_INTERVAL
			_spawn_afterimage()

	var color = body_color
	if _hurt_flash > 0.0 and fmod(HURT_FLASH_TIME - _hurt_flash, 0.2) < 0.1:
		color = Color.WHITE if body_color.get_luminance() < FLASH_DARK_ABOVE else Color.BLACK
	elif _dash_timer > 0.0:
		color = body_color.lightened(0.5)
	elif _windup_timer > 0.0:
		color = body_color.lightened(0.5 * _windup_progress())
	elif _launch_timer > 0.0:
		color = body_color.lerp(Color.WHITE, 0.3)
	elif straining:
		color = body_color.lerp(Color(1.0, 0.8, 0.3), 0.35 + 0.25 * sin(now() * 30.0))
	elif _boost_timer > 0.0:
		color = body_color.lightened(0.5)
	elif is_staggered():
		color = body_color.lerp(Color(0.6, 0.6, 0.6), 0.6)
	elif is_blocking():
		color = body_color.darkened(0.3)
	body.color = color
	_update_hands()


# 0 -> 1 through a dash-slash's windup; charging, a flare on every beat of the clock.
func _windup_progress() -> float:
	if _charging:
		return maxf(0.0, 1.0 - Beat.phase() * Beat.beat_length() / RHYTHM_CHARGE_FLARE)
	return 1.0 - _windup_timer / _windup_length


# A fading copy of the body and the long blade, left behind along a dash-slash.
func _spawn_afterimage():
	var ghost = ColorRect.new()
	ghost.top_level = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = body.size
	ghost.color = Color(body_color.lightened(0.3), 0.45)
	add_child(ghost)
	ghost.global_position = body.global_position
	var blade = ColorRect.new()
	blade.top_level = true
	blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blade.size = Vector2(sword.size.x * DASH_SLASH_REACH, sword.size.y)
	blade.color = Color(_sword_color.lerp(Color.WHITE, DASH_SLASH_GLOW), 0.5)
	add_child(blade)
	var tip_side = sword.global_position.x if facing > 0.0 else sword.global_position.x - blade.size.x
	blade.global_position = Vector2(tip_side, sword.global_position.y)
	for node in [ghost, blade]:
		var tween = node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, DASH_SLASH_TRAIL_FADE)
		tween.tween_callback(node.queue_free)


# The blade a little broader, with a point at its end and a crossguard just past the hands (see
# SWORD_WIDTH). Both are the sword pivot's, so they swing and stretch with the blade.
func _setup_sword():
	var middle = sword.position.y + sword.size.y / 2.0
	var length = sword.size.x
	sword.size = Vector2(length - SWORD_POINT, SWORD_WIDTH)
	sword.position.y = middle - SWORD_WIDTH / 2.0
	var end = sword.position.x + sword.size.x
	_sword_tip = Polygon2D.new()
	_sword_tip.polygon = PackedVector2Array([Vector2(end, middle - SWORD_WIDTH / 2.0),
		Vector2(end + SWORD_POINT, middle), Vector2(end, middle + SWORD_WIDTH / 2.0)])
	sword_pivot.add_child(_sword_tip)
	_crossguard = ColorRect.new()
	_crossguard.size = CROSSGUARD_SIZE
	_crossguard.position = Vector2(sword.position.x + length * CROSSGUARD_AT, middle) - CROSSGUARD_SIZE / 2.0
	_crossguard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword_pivot.add_child(_crossguard)


# A point on the blade, from where it starts at the hilt (0) to its point (1), in global
# coordinates (the sync wave runs along it).
func blade_point(along: float) -> Vector2:
	var length = sword.size.x + SWORD_POINT
	var middle = sword.position.y + sword.size.y / 2.0
	if sabre_on():
		return sword_pivot.to_global(Vector2(sword.position.x + length * SABRE_LENGTH * along, middle - SABRE_CURVE * along * along))
	return sword_pivot.to_global(Vector2(sword.position.x + length * along, middle))


# --- The pair's strike (see THE PAIR'S STRIKE) ---

# Bound in sync mode, attack draws the sabre instead of swinging.
func _process_attack_buttons():
	if bond != null:
		_process_draw()
	else:
		super()


# Bound: attack held draws the sword back, let go it strikes and the bond hears of it. A block
# press or a stagger lets it go unstruck.
func _process_draw():
	if _drawing:
		if _pressed("block") or is_staggered():
			_drawing = false
			return
		if _held("attack"):
			_draw_time += get_physics_process_delta_time()
			return
		var drawn = _sword_angle()
		var share = draw_share()
		_drawing = false
		_start_swing(Swing.SLASH)
		_swing_from_angle = drawn
		_attack_landed = true  # the bond deals the pair's hit, not this swing
		Sfx.play("slash", -2.0)
		bond.released(self, share)
	elif _pressed("attack") and not is_swinging() and not is_staggered():
		_drawing = true
		_draw_time = 0.0
		parry_press_time = -100.0


func is_drawing() -> bool:
	return _drawing


# How far the sword is drawn back: 0 to 1 (fully, after Tuning "sync_charge_time").
func draw_share() -> float:
	return clampf(_draw_time / Tuning.value("sync_charge_time"), 0.0, 1.0) if _drawing else 0.0


func sabre_on() -> bool:
	return _sabre != null and _sabre.visible


# Bound in sync mode the sword is a sabre (longer, curved, half light and half dark); unbound, the
# sword again. The hitbox stays the same.
func set_sabre(on: bool):
	if on and _sabre == null:
		_sabre = Node2D.new()
		var hilt = sword.position.x
		var middle = sword.position.y + sword.size.y / 2.0
		var length = (sword.size.x + SWORD_POINT) * SABRE_LENGTH
		var top = PackedVector2Array()
		var bottom = PackedVector2Array()
		var spine = PackedVector2Array()
		var steps = 14
		for i in steps + 1:
			var t = float(i) / steps
			var x = hilt + length * t
			var y = middle - SABRE_CURVE * t * t
			var half = SABRE_WIDTH / 2.0 * (1.0 - 0.3 * t) * (1.0 if t < 0.85 else (1.0 - t) / 0.15)
			top.append(Vector2(x, y - half))
			bottom.append(Vector2(x, y + half))
			spine.append(Vector2(x, y))
		var light = Polygon2D.new()
		var points = top.duplicate()
		var back = spine.duplicate()
		back.reverse()
		points.append_array(back)
		light.polygon = points
		light.color = SABRE_LIGHT
		var dark = Polygon2D.new()
		points = spine.duplicate()
		back = bottom.duplicate()
		back.reverse()
		points.append_array(back)
		dark.polygon = points
		dark.color = SABRE_DARK
		_sabre.add_child(light)
		_sabre.add_child(dark)
		sword_pivot.add_child(_sabre)
	if _sabre != null:
		_sabre.visible = on
	sword.visible = not on
	_sword_tip.visible = not on
	if not on:
		_drawing = false


func _setup_hands():
	for i in 2:
		var hand = ColorRect.new()
		hand.size = Vector2.ONE * body.size.y * HAND_SIZE_RATIO
		hand.pivot_offset = hand.size / 2
		hand.top_level = true
		hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hand)
		_hands.append(hand)
	_update_hands()


# The hands grip the hilt and follow every swing and guard.
func _update_hands():
	var hilt = sword.position.x
	var length = sword.size.x
	var blade_y = sword.position.y + sword.size.y / 2
	for i in _hands.size():
		var hand = _hands[i]
		var grip = sword_pivot.to_global(Vector2(hilt + length * HAND_GRIPS[i], blade_y))
		hand.global_position = grip - hand.size / 2
		hand.rotation = sword_pivot.rotation
		hand.color = body.color.darkened(HAND_DARKEN)
	_crossguard.color = body.color.darkened(HAND_DARKEN)
