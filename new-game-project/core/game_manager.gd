extends Node
## Autoload singleton: owns the shared sync meter, the overall game state,
## and restart logic.

signal sync_changed(value, multiplier)
signal state_changed(new_state)

enum GameState { PLAYING, GAME_OVER, VICTORY }

const SYNC_MAX = 100.0
const SYNC_START = 0.0
const SYNC_RELAY_GAIN = 25.0
const SYNC_GRAB_DODGE_GAIN = 15.0
const SYNC_GRAND_SLASH_GAIN = 40.0
const SYNC_SHOCKWAVE_PARRY_GAIN = 8.0
const SYNC_DOUBLE_COUNTER_GAIN = 30.0
const SYNC_SINGLE_COUNTER_GAIN = 15.0
const SYNC_BLOCK_LOSS = 5.0
const SYNC_HIT_LOSS = 10.0

var sync_value = SYNC_START
var state = GameState.PLAYING
var elapsed_time = 0.0
var players: Array = []
var boss = null


func _ready():
	# Keep running while the tree is paused so R can restart from the end screens.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta):
	if state == GameState.PLAYING:
		elapsed_time += delta
	elif Input.is_action_just_pressed("restart"):
		restart()


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


func register_boss(new_boss):
	boss = new_boss
	boss.relay_completed.connect(change_sync.bind(SYNC_RELAY_GAIN))
	boss.grab_dodged.connect(change_sync.bind(SYNC_GRAB_DODGE_GAIN))
	boss.grand_slash_parried.connect(change_sync.bind(SYNC_GRAND_SLASH_GAIN))
	boss.shockwave_parried.connect(_on_shockwave_parried)
	boss.counterattack_landed.connect(_on_counterattack_landed)
	boss.defeated.connect(_end_game.bind(GameState.VICTORY))


func restart():
	get_tree().paused = false
	players.clear()
	boss = null
	sync_value = SYNC_START
	elapsed_time = 0.0
	state = GameState.PLAYING
	get_tree().reload_current_scene()
	state_changed.emit(state)
	sync_changed.emit(sync_value, damage_multiplier())


func _end_game(new_state):
	if state != GameState.PLAYING:
		return
	state = new_state
	get_tree().paused = true
	Sfx.play("victory" if state == GameState.VICTORY else "game_over")
	state_changed.emit(state)


# A failed parry is just a hit taken, so it costs the same.
func _on_player_damaged(_player):
	change_sync(-SYNC_HIT_LOSS)


func _on_player_blocked(_player):
	change_sync(-SYNC_BLOCK_LOSS)


func _on_shockwave_parried(_player):
	change_sync(SYNC_SHOCKWAVE_PARRY_GAIN)


func _on_counterattack_landed(both_players):
	change_sync(SYNC_DOUBLE_COUNTER_GAIN if both_players else SYNC_SINGLE_COUNTER_GAIN)


func _on_player_died(_player):
	_end_game(GameState.GAME_OVER)
