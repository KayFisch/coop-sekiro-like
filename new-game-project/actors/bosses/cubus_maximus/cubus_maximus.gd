class_name CubusMaximus
extends BaseBoss
## Cubus Maximus: the sword-wielding cube. Everything here is specific to him: his health,
## damage values and sword, and which attacks he uses and how often. The state machine lives
## in BaseBoss and each attack's logic in attacks/.

# Re-emitted from his attacks, for the GameManager (sync meter) and anyone else listening.
signal relay_completed
signal grab_dodged
signal grand_slash_parried
signal shockwave_parried(player)
signal counterattack_landed(both_players)

const MAX_HP = 1000.0

const SWORD_DAMAGE = 25.0
const CHIP_DAMAGE = 12.0  # a blocked sword hit; also a blocked grand slash lunge
const GRAB_DAMAGE = 40.0
const SLAM_DAMAGE = 25.0
const GRAND_DAMAGE = 35.0  # the grand slash lunge unparried, and its failure shockwave
const GRAND_COUNTER_DAMAGE = 80.0  # taken when both players overpower the grand slash
const SHOCKWAVE_DAMAGE = 20.0  # halved when blocked
const COUNTER_DAMAGE = 40.0  # per shockwave counterattack; both together deal double

const SWORD_REACH = 110.0  # blade tip distance from the pivot at scale 1 (see the scene)
const GRAND_SWORD_SCALE = 1.5  # sword size at the end of the grand slash wind-up

@export var telegraph_time = 1  # seconds of warning (sword relay)
@export var attack_speed = 2000.0  # grab lunge speed

var _last_attack: Attack = null

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
	return [relay, grab, slam, grand, volley]


# The sword relay is twice as likely as anything else; nothing but the relay repeats back to back.
func pick_attack() -> Attack:
	var relay = attack_pool[0]
	var options = [relay, relay] + attack_pool.slice(1)
	if _last_attack != relay:
		options.erase(_last_attack)
	_last_attack = options.pick_random()
	return _last_attack
