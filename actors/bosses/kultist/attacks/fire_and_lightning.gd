class_name KultistFireAndLightning
extends Attack
## Fire, then lightning. FIRE_AND_LIGHTNING, the Kultist's first great attack (kultist.gd, "Fire
## and lightning"):
## 1. He flies to the middle of the room and up (channel_rise_time: the telegraph), his wings
##    open, and channels: his staves held up over him, their heads glowing.
## 2. Fire (magic/fire_wave.gd): embers where it will burn, from the walls in to the safe place in
##    the middle (fire_tell_time), then it erupts at the walls and runs inward (fire_speed), each
##    place burning fire_burn_time. Get into the middle: fire can't be parried or blocked.
## 3. As it reaches the safe place, lightning (magic/lightning_bolt.gd) between his two images,
##    through the axis: it crackles yellow (bolt_tell_time), flashes red (bolt_cue_time), and
##    strikes everyone within its width (bolt_width) round the middle. Each has to parry it (the
##    LIGHTNING rule). A parrier's blade holds its energy for a moment (absorb_time). Parried by
##    both, it goes back up into him: a hit (reflect_heavy). Anyone in it who didn't parry is hit
##    (bolt_heavy), or chipped behind a block.
## 4. He stays up a moment (bolt_after_time), comes down (descend_time) and recovers (fire_recover).
## Up there he has no guard: whoever reaches him hits him.
## TODO(design): the lightning comes while the fire still burns, so both are held in the middle.
## "Cross Parry" is read as both parrying it at once (as the coop parry of Bifrons's two swords).
## Sent back, it's a hit on him and no more: no stagger, no sync for the players (Bifrons's coop
## parry wins them "coop_parry_gain").

enum Phase { NONE, EMBERS, BOLT, AFTER, DESCENDING }

const GLOW_ALPHA = 0.22  # his glow, channeling

var reflected = false  # this run's bolt went back into him (the tests read it)
var _time = 0.0  # s since the attack proper began (execute())
var _fire: KultistFire = null
var _bolt: KultistBolt = null
var _bolt_from = 0.0  # when the lightning begins to crackle (s, as _time)...
var _bolt_at = 0.0  # ...and when it strikes
var _cued = false
var _cut_short = false


func get_attack_name() -> String:
	return "FIRE_AND_LIGHTNING"


func fits(_boss_node) -> bool:
	return true


# Nobody needs to be near: he flies to the middle wherever they are.
func needs_reach() -> bool:
	return false


# The middle of the room: where he flies, the safe place and the bolt.
static func middle() -> float:
	return (BaseBoss.ARENA_LEFT + BaseBoss.ARENA_RIGHT) / 2.0


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	reflected = false
	_time = 0.0
	_fire = null
	_bolt = null
	_cued = false
	_cut_short = false
	boss.fly_to(Vector2(middle(), boss.home_position.y - boss.flight_height), boss.channel_rise_time)


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


func get_telegraph_duration() -> float:
	return boss.channel_rise_time


func update_telegraph(progress: float):
	_channel(KultistElement.tell(KultistElement.FIRE), progress)


func execute():
	phase = Phase.EMBERS
	_time = 0.0
	boss.body.color = boss.COLOR_IDLE
	_fire = KultistFire.light(boss, boss.get_parent())
	_bolt_from = _fire.reaches_safe_at()
	_bolt_at = _bolt_from + boss.bolt_tell_time + boss.bolt_cue_time
	Sfx.play("clash_grind", -10.0)  # the embers kindling
	_channel(KultistElement.cue(KultistElement.FIRE), 1.0)


func update(delta: float):
	_time += delta
	match phase:
		Phase.EMBERS:
			_channel(KultistElement.cue(KultistElement.FIRE), 1.0)
			if _time >= _bolt_from:
				phase = Phase.BOLT
				_bolt = KultistBolt.summon(boss, boss.get_parent())
				Sfx.play("clash_grind", -12.0)  # the lightning crackling
		Phase.BOLT:
			var cue_at = _bolt_at - boss.bolt_cue_time
			var lightning = KultistElement.tell(KultistElement.LIGHTNING)
			if _time < cue_at:
				_channel(lightning, 1.0)
				if is_instance_valid(_bolt):
					_bolt.tell((_time - _bolt_from) / maxf(cue_at - _bolt_from, 0.01))
			elif _time < _bolt_at:
				_channel(KultistElement.cue(KultistElement.LIGHTNING), 1.0)
				if not _cued:
					_cued = true
					Sfx.play("stab", -2.0)  # the cue
					if is_instance_valid(_bolt):
						_bolt.cue()
			else:
				_strike()
				if completed:
					return  # it went back into him and broke him, or killed him
				phase = Phase.AFTER
				timer = boss.bolt_after_time
		Phase.AFTER:
			timer -= delta
			_channel(KultistElement.tell(KultistElement.LIGHTNING), clampf(timer / maxf(boss.bolt_after_time, 0.01), 0.0, 1.0))
			if timer <= 0.0:
				boss.land(boss.descend_time)
				phase = Phase.DESCENDING
		Phase.DESCENDING:
			_channel(Color.WHITE, 0.0)
			if not boss.is_aloft():
				finish(boss.fire_recover)


# Seconds until the lightning strikes (on whoever is in it then); INF before the fire is lit and
# after it has struck.
func time_to_strike(_player) -> float:
	if phase in [Phase.EMBERS, Phase.BOLT] and _time < _bolt_at:
		return _bolt_at - _time
	return INF


# Until he's on his way down: a fire is coming or burning, the safe place is the one to be in.
func fire_coming() -> bool:
	return phase != Phase.DESCENDING


# The lightning strikes: on everyone within its width round him. Parried by every player, it
# goes back into him.
func _strike():
	var x = boss.global_position.x
	var everyone = boss.get_players()
	var under = everyone.filter(func(p): return absf(p.global_position.x - x) <= boss.bolt_width / 2.0)
	var parriers = []
	for p in under:
		if boss.land_on(p, KultistElement.LIGHTNING, boss.bolt_heavy, null, true) == KultistElement.PARRIED:
			parriers.append(p)
			# The parrier holds its energy for a moment: their blade lit, and crackling.
			p.cue_sync(boss.absorb_time, KultistElement.tell(KultistElement.LIGHTNING))
			if is_instance_valid(_bolt):
				_bolt.absorb(p, boss.absorb_time)
			parry_success.emit(p, "kultist_bolt")
	# TODO(design): a player outside it can't parry it, so it isn't sent back; it doesn't hit them.
	reflected = not everyone.is_empty() and parriers.size() == everyone.size()
	if is_instance_valid(_bolt):
		_bolt.strike(reflected)
	Sfx.play("grand_impact", -4.0)
	Dev.note("kultist_bolt", {"under": under.size(), "parried": parriers.size(), "reflected": reflected})
	if reflected:
		boss.spawn_sparks(boss.global_position + Vector2(0.0, boss.body.size.y / 2.0), 24, Color.WHITE)
		boss.take_reflection(boss.reflect_heavy)


# His staves held up over him, their heads glowing `color` (`alpha`), and he with them.
func _channel(color: Color, alpha: float):
	for layer in boss.LAYERS:
		boss.pose_staff(layer, boss.POSE_CHANNEL)
		boss.tint_staff(layer, null)
		boss.light_head(layer, color, alpha)
	boss.set_glow(color, GLOW_ALPHA * alpha)


func interrupt():
	_cut_short = true
	super()


# Finished, the fire burns out and the bolt fades by themselves; cut short (staggered, dead),
# they're put out.
func cleanup():
	if _cut_short:
		if is_instance_valid(_fire):
			_fire.fizzle()
		if is_instance_valid(_bolt):
			_bolt.fade()
	_fire = null
	_bolt = null
	_cut_short = false
