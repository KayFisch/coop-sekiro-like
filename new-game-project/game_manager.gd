extends Node
## Autoload singleton: owns the shared sync meter, the overall game state,
## revival wiring between players, and restart logic.

signal sync_changed(value, multiplier)
signal state_changed(new_state)
signal revival_triggered(player)

enum GameState { PLAYING, GAME_OVER, VICTORY }

const SYNC_MAX = 100.0
const SYNC_START = 0.0
const SYNC_RELAY_GAIN = 25.0
const SYNC_GRAB_BREAK_GAIN = 10.0
const SYNC_FAILED_PARRY_LOSS = 10.0
const SYNC_DAMAGE_LOSS = 8.0

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
	player.player_downed.connect(_on_player_downed)
	player.bled_out.connect(_on_player_bled_out)


func register_boss(new_boss):
	boss = new_boss
	boss.parry_success.connect(_on_parry_success)
	boss.parry_failed.connect(_on_parry_failed)
	boss.relay_completed.connect(change_sync.bind(SYNC_RELAY_GAIN))
	boss.grab_broken.connect(change_sync.bind(SYNC_GRAB_BREAK_GAIN))
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
	state_changed.emit(state)


func _on_parry_success(player, _kind):
	# Any successful parry by the survivor pulls a bleeding-out partner back up.
	for other in players:
		if other != player and other.is_downed:
			other.revive()
			revival_triggered.emit(other)


func _on_parry_failed(_player):
	change_sync(-SYNC_FAILED_PARRY_LOSS)


func _on_player_damaged(_player):
	change_sync(-SYNC_DAMAGE_LOSS)


func _on_player_downed(player):
	for other in players:
		if other != player and other.is_downed:
			_end_game(GameState.GAME_OVER)
			return


func _on_player_bled_out(_player):
	_end_game(GameState.GAME_OVER)
