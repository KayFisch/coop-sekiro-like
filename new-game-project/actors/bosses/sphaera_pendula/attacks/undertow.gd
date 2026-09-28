class_name Undertow
extends Attack
## Green -> red. Sphaera Pendula drops into the pit and vanishes below it, then rams up from
## underneath RAMS times. Each ram strikes under the heavier pan, which shudders as a warning,
## and kicks it up: anyone standing on it is hit, and anyone in the air is safe. The weight is
## read afresh for every ram. With the pans balanced (someone standing on each) it can't pick
## a side and bursts up through the pit instead, hanging exposed there for a moment.
## So the first ram punishes wherever the players stand, and players who split up and stay on
## their feet turn the rest into openings. Jumping takes your weight off your pan, which can
## make your partner's pan the heavier one.

signal exposed

enum Phase { NONE, WARN, RAM, SINK, BURST, EXPOSED }

# --- Tuning ---
const TELEGRAPH_TIME = 1.1
const DIVE_PART = 0.55  # of the telegraph: dropping into the pit; then it lurks there
const RAMS = 3
const HIDDEN_Y = 740.0  # its center while lurking under the pit (off screen)
const RAM_WARNING = 0.4  # the chosen pan shudders this long before the ram
const RAM_RISE_TIME = 0.12
const RAM_POKE = 10.0  # px of the sphere showing above a pan's underside as it strikes
const RAM_SINK_TIME = 0.3
const KICK_SPEED = 750.0  # the struck pan's upward jolt, px/s
const RAM_DAMAGE = 22.0
const RAM_KNOCKBACK = Vector2(0.0, -650.0)
const BURST_RISE_TIME = 0.18  # balanced: up through the pit...
const EXPOSED_TIME = 0.8  # ...and hanging there, open to hits from both pans' edges
const RECOVER_TIME = 0.5

const COLOR = Color(0.2, 0.9, 0.3)

var _ram = 0
var _side = 0  # the pan being rammed; 0 for the balanced burst through the pit
var _from = Vector2.ZERO
var _telegraph_from = Vector2.ZERO


func get_attack_name() -> String:
	return "UNDERTOW"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_telegraph_from = boss_node.global_position


# Dropping into the pit (a short hitch up first), then lurking below it, the chain swaying.
func update_telegraph(progress: float):
	boss.set_glow(COLOR, 0.35 + 0.25 * sin(boss.anim_time * 14.0))
	if progress < DIVE_PART:
		var t = progress / DIVE_PART
		var hitch = -30.0 * sin(PI * minf(t * 2.0, 1.0)) * (1.0 - t)
		boss.global_position = Vector2(
			lerpf(_telegraph_from.x, Scales.CENTER_X, ease(t, 0.5)),
			lerpf(_telegraph_from.y, HIDDEN_Y, ease(t, 2.4)) + hitch)
	else:
		boss.global_position = Vector2(Scales.CENTER_X + 20.0 * sin(boss.anim_time * 5.0), HIDDEN_Y)


func execute():
	_ram = 0
	_start_warning()


func update(delta: float):
	timer -= delta
	var t = 1.0 - clampf(timer / maxf(_phase_time(), 0.001), 0.0, 1.0)
	match phase:
		Phase.WARN:
			# Sliding under its mark while the pan shudders.
			boss.global_position = _from.lerp(Vector2(_ram_x(), HIDDEN_Y), ease(t, 0.5))
			if timer <= 0.0:
				_from = boss.global_position
				if _side == 0:
					phase = Phase.BURST
					timer = BURST_RISE_TIME
				else:
					phase = Phase.RAM
					timer = RAM_RISE_TIME

		Phase.RAM:
			var strike_y = boss.scales.pan_top(_side) + Scales.PAN_THICKNESS + boss.RADIUS - RAM_POKE
			boss.global_position.y = lerpf(_from.y, strike_y, ease(t, 2.0))
			if timer <= 0.0:
				_strike_pan()

		Phase.BURST:
			boss.global_position = _from.lerp(boss.stagger_spot(), ease(t, 0.4))
			if timer <= 0.0:
				phase = Phase.EXPOSED
				timer = EXPOSED_TIME
				exposed.emit()
				boss.shake(4.0)
				Sfx.play("chain")

		Phase.EXPOSED:
			boss.global_position = boss.stagger_spot()
			var flash = fmod(boss.anim_time, 0.16) < 0.08
			boss.body.color = COLOR if flash else boss.COLOR_STAGGER
			if timer <= 0.0:
				_start_sink()

		Phase.SINK:
			boss.global_position.y = lerpf(_from.y, HIDDEN_Y, ease(t, 2.0))
			if timer <= 0.0:
				_ram += 1
				if _ram < RAMS:
					_start_warning()
				else:
					finish(RECOVER_TIME)


func cleanup():
	for side in [Scales.LEFT, Scales.RIGHT]:
		boss.scales.set_highlight(side, COLOR, 0.0)


func _phase_time() -> float:
	match phase:
		Phase.WARN:
			return RAM_WARNING
		Phase.RAM:
			return RAM_RISE_TIME
		Phase.SINK:
			return RAM_SINK_TIME
		Phase.BURST:
			return BURST_RISE_TIME
		Phase.EXPOSED:
			return EXPOSED_TIME
	return 1.0


# The heavier pan. It's only fooled into the pit (0) by real balance, both pans weighed down:
# with nobody standing anywhere (e.g. everyone thrown up by the last ram), it goes for the side
# most players are over, or the target's.
func _pick_side() -> int:
	var side = boss.scales.heavier_side()
	if side != 0 or boss.scales.weight(Scales.LEFT) > 0.0:
		return side
	var lean = 0
	for p in players:
		lean += boss.scales.side_of_x(p.global_position.x)
	if lean != 0:
		return signi(lean)
	return boss.scales.side_of_x(boss.target_player.global_position.x)


# Under the middle of the chosen pan, or of the pit.
func _ram_x() -> float:
	return Scales.RESPAWN_X[_side] if _side != 0 else Scales.CENTER_X


func _start_warning():
	phase = Phase.WARN
	timer = RAM_WARNING
	_from = boss.global_position
	_side = _pick_side()
	boss.body.color = boss.COLOR_EXECUTE
	if _side != 0:
		boss.scales.shudder(_side, RAM_WARNING)
		boss.scales.set_highlight(_side, COLOR, 0.8)
	Sfx.play("chain", -4.0)


func _strike_pan():
	boss.scales.kick(_side, KICK_SPEED)
	boss.scales.set_highlight(_side, COLOR, 0.0)
	for p in players:
		if boss.scales.is_standing_on(p, _side):
			p.take_damage(RAM_DAMAGE, RAM_KNOCKBACK)
	boss.shake(9.0)
	Sfx.play("thunk")
	_start_sink()


func _start_sink():
	phase = Phase.SINK
	timer = RAM_SINK_TIME
	_from = boss.global_position
	boss.body.color = boss.COLOR_EXECUTE
