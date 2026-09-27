class_name CubusMaximus
extends BaseBoss
## Cubus Maximus: the sword-wielding cube. Everything here is specific to him: his health,
## his sword, and which attacks he uses and how often. The state machine lives in BaseBoss;
## each attack's logic and its tuning values (damage, timings, ...) live in attacks/.

# Re-emitted from his attacks, for the GameManager (sync meter) and anyone else listening.
signal relay_completed
signal grab_dodged
signal grand_slash_parried
signal shockwave_parried(player)
signal counterattack_landed(both_players)
signal stab_parried(player)
signal triple_clash_started
signal triple_clash_countered

# --- Tuning ---
const MAX_HP = 1000.0

# How often each attack is picked, relative to the others: 2 is twice as likely as 1, and
# 0 (or leaving an attack out) disables it.
const ATTACK_WEIGHTS = {
	"SWORD_RELAY": 2.0,
	"GRAB": 1.0,
	"GROUND_SLAM": 1.0,
	"GRAND_SLASH": 1.0,
	"SHOCKWAVE_SLASHES": 1.0,
	"TRIPLE_SLASH": 1.0,
}
# Attacks that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_ATTACKS = ["SWORD_RELAY"]
# For testing: set to an attack's name (e.g. "TRIPLE_SLASH") to use only that attack.
const TEST_ONLY_ATTACK = ""

const SWORD_REACH = 110.0  # blade tip distance from the pivot at scale 1 (see the scene)

@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var grab_area: Area2D = $GrabArea


func get_max_hp() -> float:
	return MAX_HP


func get_attack_pool() -> Array:
	var relay = SwordRelay.new()
	relay.relay_completed.connect(relay_completed.emit)
	var grab = Grab.new()
	grab.grab_dodged.connect(grab_dodged.emit)
	var slam = GroundSlam.new()
	var grand = GrandSlash.new()
	grand.grand_slash_parried.connect(grand_slash_parried.emit)
	var volley = ShockwaveSlashes.new()
	volley.shockwave_parried.connect(shockwave_parried.emit)
	volley.counterattack_landed.connect(counterattack_landed.emit)
	var triple = TripleSlash.new()
	triple.stab_parried.connect(stab_parried.emit)
	triple.clash_started.connect(triple_clash_started.emit)
	triple.clash_countered.connect(triple_clash_countered.emit)
	return [relay, grab, slam, grand, volley, triple]


func get_attack_weights() -> Dictionary:
	if TEST_ONLY_ATTACK != "":
		return {TEST_ONLY_ATTACK: 1.0}
	return ATTACK_WEIGHTS


func get_repeatable_attacks() -> Array:
	return REPEATABLE_ATTACKS
