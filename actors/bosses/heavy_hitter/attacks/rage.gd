class_name HitterRage
extends HitterSwings
## The Heavy Hitter's rage (docs/boss_heavy_hitter.md, "Rage"): his posture broken (THE RAGE in
## heavy_hitter.gd; or the F5 lab), he roars, both heads red, and then strikes a fixed pattern from
## side to side, wherever the players stand. Every strike is a blade strike in both layers, so heavy
## (THE RULES, 1: a lone parry has a block's effect), the mirror cracking where nothing stopped it (2);
## between two strikes the weapon goes up over him to the other side in both layers. He doesn't turn
## to them and doesn't walk.
##   pendulum  parallel (the same in both halves): the blade on one side in both layers, then the
##             other. Hard apart (pep): one parries alone, the partner's blade breaks through under
##             them. Easy together (ppe): parried together, or into nothing on the empty side.
##   cross     diagonal (across): one way in one layer, the other way in the other, swapping each
##             strike. Hard together: each parries alone by turns. Easy apart: parried together, then
##             both blades into nothing, each breaking through under the partner.
##   last      the last rage (F1 "hitter_last_rage"): the one that's hard for their formation, then one
##             layer over (the other alignment) and the other one, and the great hammer to end it.
## As the roar begins he takes the pattern that's hard for their formation (HeavyHitter.rage_pattern(),
## for "last"; the lab names its own), and the weapon shows it at once: if it's in the other alignment,
## the nearer player's layer goes over (HeavyHitter.nearer_layer()). They may re-form during the roar
## and make it the easy one. Then he's exhausted: staggered "hitter_stagger_least", and
## "hitter_stagger_per_parry" more for each blade parried in it (a co-op parry: two; a lone one, only a
## block's effect: none). His sync stays, his posture holds all through and is full after
## (HeavyHitter.holds_posture()), and the alignment stays as the pattern left it.

var _pattern: String
var _cross = false  # the first (or only) pattern is the cross
var _aligned = false  # the roar has put the weapon in its pattern's alignment


func _init(attack_name: String, pattern: String):
	super(attack_name, [])
	_pattern = pattern


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_cross = (boss.rage_pattern() if _pattern == "last" else _pattern) == "cross"
	_aligned = false
	boss.begin_rage(_cross)
	_lead = Tuning.value("hitter_roar_time")
	_strikes([])
	if _pattern == "last":
		_strikes([boss.nearer_layer()])  # one layer over: the other alignment, the other pattern
		_add(boss.FINALES.HAMMER[0][0], HAMMER, 0, {"both": true, "turn": boss.LAYERS.duplicate()})


# One pattern's strikes, each in both layers, and before each the weapon over to the other side in
# both, but before the first: `first_turn`'s layers only.
func _strikes(first_turn: Array):
	for i in int(Tuning.value("hitter_rage_strikes")):
		_add("hitter_rage_beats", BLADE, 0, {"both": true, "turn": first_turn if i == 0 else boss.LAYERS.duplicate()})


func update_telegraph(progress: float):
	if not _aligned:
		# The roar's first frame (not as he's started: a strike of the run he broke off may still be
		# landing then): the weapon in the pattern's alignment.
		_aligned = true
		if boss.is_diagonal() != _cross:
			boss.turn_layer(boss.nearer_layer())
	super(progress)
	var roaring = _time < _lead
	boss.set_glow(boss.COLOR_ANGRY, 0.2 + 0.12 * sin(_time * 30.0) if roaring else 0.0)


# The roar, before the first windup: the weapon raised high and shaking, in both layers.
func _pose_after(layer: int, link):
	if link == null and _time < _lead:
		var risen = smoothstep(0.0, 0.25, _time / _lead)
		var pose = boss.POSE_LEVEL.lerp(boss.POSE_RAISED, risen)
		pose.z += randf_range(-TREMBLE, TREMBLE) * 2.0 * risen
		boss.pose_layer(layer, pose)
		boss.tint_layer(layer, boss.COLOR_SWORD)
		return
	super(layer, link)


# Through it all: exhausted.
func _end_run():
	boss.end_rage()
	finish_with_stagger(boss.chain_stagger(_blades))


func cleanup():
	super()
	boss.set_glow(boss.COLOR_ANGRY, 0.0)
	if boss.rage == "raging":
		boss.rage = ""  # cut short
