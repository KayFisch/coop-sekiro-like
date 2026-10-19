class_name Chain
extends StrikePattern
## A chain (docs/concept.md, "Boss design principles": chains, not patterns): one motif of
## strikes, visibly repeated, then one finale. Columna Bifrons's attack in the chains mode (Moves
## "bifrons_mode"), a try-out of the grammar before the Warden's own motifs exist (his motifs here
## are placeholders: the CHAIN_ entries of ColumnaBifrons.ATTACKS).
## It runs as a series of strikes does (the same cuts, lunges, parries and windows), but it
## lengthens itself. Before its first strike he holds the motif's stance a moment (STANCES): each
## motif has its own, so they can be told apart. Then, only as the last strike of a repetition
## lands, he decides (ColumnaBifrons.chain_finale()):
##   - his posture under F2 "bifrons_chain_posture": the finale, now;
##   - the repetitions this chain was to have (at random, F2 "bifrons_chain_reps_min" to "_max"):
##     the finale;
##   - else the motif once more, the same way round.
## A finale of strikes (the double strike, the crossing) is part of the chain; a leap is an attack
## of its own, which he starts as the chain is over (ColumnaBifrons.hand_over()), and its parries
## count toward the chain's stagger. Only the motif and the number of repetitions are chance.
## With Moves "bifrons_guard_break" on "motif_end", only the last parry of a repetition all of whose
## strikes were parried breaks his other guard (the partner's sync hit goes through); any other
## parry only opens the window. The chain goes on either way.

# --- Tuning ---
const STANCE_TIME = 0.45  # s he holds the motif's stance before its first strike is drawn
# The stances: where the sword of the motif's first strike ("lead") or both swords are held, as
# the POSE_s in bifrons_swords.gd (for a sword on its player's side).
const STANCES = {
	"level": {"lead": Vector3(56.0, 12.0, 0.0)},  # held out level at its player, like a fencer's
	"high": {"lead": Vector3(10.0, -96.0, -1.571)},  # straight up over his head
	"cross": {"both": Vector3(-6.0, 20.0, -2.2)},  # both crossed in front of him
}
const COLOR_STANCE = Color(0.95, 0.95, 1.0)  # a blade held in a stance: brighter than its silver

var _motif: Array  # as written: [wait, sword] each
var _stance: String
var _marks: Array = []  # per strike of this run: its repetition (0, 1, ...), or -1 for the finale's
var _reps_done = 0
var _reps_max = 2  # this chain's repetitions, picked as it starts
var _rep_clean = true  # every strike of this repetition so far was parried
var _stance_until = 0.0  # s into the chain
var _finale = ""  # once chosen: an entry of ColumnaBifrons.ATTACKS
var _handover = ""  # a finale of its own, started as the chain is over


func _init(chain_name: String, motif: Array, stance: String):
	super(chain_name, motif)
	_motif = motif
	_stance = stance


func start(boss_node, player_nodes: Array):
	_marks = _motif.map(func(_strike): return 0)  # before the strikes are laid out: some may be left out
	_reps_done = 0
	_rep_clean = true
	_finale = ""
	_handover = ""
	super(boss_node, player_nodes)
	var least = int(Tuning.value("bifrons_chain_reps_min"))
	_reps_max = randi_range(maxi(least, 1), maxi(int(Tuning.value("bifrons_chain_reps_max")), least))
	_stance_until = 0.0
	if not _contacts.is_empty() and STANCES.has(_stance):
		_stance_until = STANCE_TIME
		_waits[0] += STANCE_TIME / boss.time_unit()
		_schedule(0)


func _lists() -> Array:
	return super() + [_marks]


func _land(index: int):
	var mark = _marks[index]
	var sword = _swords[index]
	super(index)
	if completed or mark < 0:
		return
	if sword == BOTH or not _parried[sword]:
		_rep_clean = false
	if index == _contacts.size() - 1:
		_end_repetition()


# "motif_end": only the last parry of a repetition that was parried all through breaks the guard.
func _breaks_guard(index: int):
	if Moves.value("bifrons_guard_break") != "motif_end":
		return super(index)
	return _marks[index] >= 0 and index == _contacts.size() - 1 and _rep_clean


# The repetition's last strike has landed: the motif again, or the finale.
func _end_repetition():
	_reps_done += 1
	_rep_clean = true
	var rules = boss.rules
	var low = rules != null and rules.posture_share(boss) * 100.0 < Tuning.value("bifrons_chain_posture")
	if not low and _reps_done < _reps_max:
		_append(_motif, _reps_done, _way)
		return
	_finale = boss.chain_finale(low)
	Dev.note("chain", {"motif": _name, "repetitions": _reps_done, "finale": _finale, "posture_low": low})
	var strikes = boss.ATTACKS[_finale].get("strikes", [])
	if strikes.is_empty():
		_handover = _finale
	else:
		_append(strikes, -1, boss.finale_way(_finale))


# Strikes as written, laid out after the last one, `way` round.
func _append(strikes: Array, mark: int, way: int):
	var from = _contacts.size()
	for strike in strikes:
		_waits.append(strike[0])
		_swords.append(strike[1] * way)
		_kinds.append(strike[2] if strike.size() > 2 else CUT)
		_contacts.append(0.0)
		_marks.append(mark)
	_schedule(from)


# Over: a finale of its own comes at once, with no recovery between.
func finish(recover: float):
	if _handover != "":
		boss.hand_over(_handover)
		_handover = ""
		recover = 0.0
	super(recover)


# Holding the stance: he stands.
func _move(delta: float):
	if _next == 0 and _time < _stance_until:
		return
	super(delta)


func _pose_blade(blade: int):
	if _next == 0 and _time < _stance_until and not _swords.is_empty():
		var stance: Dictionary = STANCES[_stance]
		var pose = stance.get("both", stance.get("lead") if blade == _swords[0] else null)
		if pose != null:
			boss.pose_sword(blade, pose)
			boss.tint_sword(blade, COLOR_STANCE)
			boss.tint_side(blade, COLOR, 0.0)
			return
	super(blade)
