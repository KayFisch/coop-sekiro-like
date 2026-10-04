extends Node
## Autoload singleton: owns the shared sync meter, the overall game state, restart logic and
## switching between fights.

signal sync_changed(value, multiplier)
signal state_changed(new_state)

enum GameState { PLAYING, GAME_OVER, VICTORY }

const SELECT_SCENE = "res://ui/boss_select.tscn"

const SYNC_MAX = 100.0
const SYNC_START = 0.0
# Sync gained per boss sync_event, by kind.
const SYNC_GAINS = {
	# Cubus Maximus
	"relay_completed": 25.0,
	"grab_dodged": 15.0,
	"grand_slash_parried": 40.0,
	"shockwave_parried": 8.0,
	"double_counter": 30.0,
	"single_counter": 15.0,
	"stab_parried": 8.0,
	"triple_clash": 10.0,  # on top of the three stab parries
	"clash_countered": 20.0,
	# Sphaera Pendula
	"swing_parried": 6.0,
	"swing_relay_completed": 25.0,
	"hook_dodged": 15.0,
	"hook_rescued": 25.0,  # worth more than a dodge: it took both of you
	"undertow_exposed": 10.0,
	"counterweight_catapult": 30.0,
	"shackle_sweeps_cleared": 8.0,
	"shackle_slingshot": 35.0,
	"zenith_interrupted": 25.0,
	"coupled_parried": 6.0,
	"coupled_collision": 30.0,
	# Columna Bifrons
	"bifrons_parried": 3.0,
	"bifrons_sync_hit": 6.0,  # the partner's hit on the same strike: it took both of you
	"bifrons_both_parried": 25.0,
}
const SYNC_LAUNCH_GAIN = 5.0  # a Launch, relay or pogo clash (see player.gd), in any fight...
const SYNC_LAUNCH_COOLDOWN = 5.0  # ...at most once per this many seconds
const SYNC_BLOCK_LOSS = 5.0
const SYNC_HIT_LOSS = 10.0

var sync_value = SYNC_START
var state = GameState.PLAYING
var elapsed_time = 0.0
var players: Array = []
var boss = null

var _last_launch_sync = -100.0


func _ready():
	# Keep running while the tree is paused so R can restart from the end screens.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta):
	if state == GameState.PLAYING:
		elapsed_time += delta
	elif Input.is_action_just_pressed("restart"):
		restart()
	if Input.is_action_just_pressed("menu") and not Moves.panel_open and get_tree().current_scene \
			and get_tree().current_scene.scene_file_path != SELECT_SCENE:
		start_fight(SELECT_SCENE)


func damage_multiplier() -> float:
	if sync_value > 95.0:
		return 2.0
	if sync_value > 75.0:
		return 1.5
	return 1.0


func change_sync(amount):
	sync_value = clampf(sync_value + amount, 0.0, SYNC_MAX)
	sync_changed.emit(sync_value, damage_multiplier())


func register_player(player):
	players.append(player)
	player.tree_exiting.connect(func(): players.erase(player))
	player.damaged.connect(_on_player_damaged)
	player.blocked.connect(_on_player_blocked)
	player.died.connect(_on_player_died)
	player.launched.connect(_on_player_launched)
	player.relayed.connect(_on_player_launched)  # a momentum relay counts like a launch
	player.pogo_clashed.connect(_on_player_launched)  # and so does a pogo clash


func register_boss(new_boss):
	boss = new_boss
	boss.sync_event.connect(_on_sync_event)
	boss.defeated.connect(_end_game.bind(GameState.VICTORY))


func restart():
	_reset()
	get_tree().reload_current_scene()
	state_changed.emit(state)
	sync_changed.emit(sync_value, damage_multiplier())


# Loads a fight (or the boss select screen) from scratch.
func start_fight(scene_path: String):
	_reset()
	get_tree().change_scene_to_file(scene_path)
	state_changed.emit(state)
	sync_changed.emit(sync_value, damage_multiplier())


func _reset():
	get_tree().paused = false
	players.clear()
	boss = null
	sync_value = SYNC_START
	elapsed_time = 0.0
	_last_launch_sync = -100.0
	state = GameState.PLAYING


func _end_game(new_state):
	if state != GameState.PLAYING:
		return
	state = new_state
	get_tree().paused = true
	Sfx.play("victory" if state == GameState.VICTORY else "game_over")
	state_changed.emit(state)


func _on_sync_event(kind: String):
	if not SYNC_GAINS.has(kind):
		push_warning("GameManager: no sync gain for \"%s\"" % kind)
		return
	change_sync(SYNC_GAINS[kind])


# A failed parry is just a hit taken, so it costs the same.
func _on_player_damaged(_player):
	change_sync(-SYNC_HIT_LOSS)


func _on_player_blocked(_player):
	change_sync(-SYNC_BLOCK_LOSS)


func _on_player_launched(_player):
	if elapsed_time - _last_launch_sync >= SYNC_LAUNCH_COOLDOWN:
		_last_launch_sync = elapsed_time
		change_sync(SYNC_LAUNCH_GAIN)


func _on_player_died(_player):
	_end_game(GameState.GAME_OVER)
