extends Node
## Autoload singleton: the overall game state, restart logic and switching between fights.

signal state_changed(new_state)

enum GameState { PLAYING, GAME_OVER, VICTORY }

const SELECT_SCENE = "res://ui/boss_select.tscn"

var state = GameState.PLAYING
var elapsed_time = 0.0
var players: Array = []
var boss = null
# Sync as life (core/sync_rules.gd), when the fight runs by it (Bifrons's does): the players' and
# the boss's sync and posture.
var rules: SyncRules = null


func _ready():
	# Keep running while the tree is paused so R can restart from the end screens.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta):
	if state == GameState.PLAYING:
		elapsed_time += delta
	elif Input.is_action_just_pressed("restart"):
		restart()
	if Input.is_action_just_pressed("menu") and not Moves.panel_open and not Tuning.panel_open \
			and get_tree().current_scene \
			and get_tree().current_scene.scene_file_path != SELECT_SCENE:
		start_fight(SELECT_SCENE)


func register_player(player):
	players.append(player)
	player.tree_exiting.connect(func(): players.erase(player))
	player.died.connect(_on_player_died)


func register_boss(new_boss):
	boss = new_boss
	boss.defeated.connect(_end_game.bind(GameState.VICTORY))


func restart():
	_reset()
	get_tree().reload_current_scene()
	state_changed.emit(state)


# Loads a fight (or the boss select screen) from scratch.
func start_fight(scene_path: String):
	_reset()
	get_tree().change_scene_to_file(scene_path)
	state_changed.emit(state)


func _reset():
	get_tree().paused = false
	players.clear()
	boss = null
	rules = null
	elapsed_time = 0.0
	state = GameState.PLAYING


func _end_game(new_state):
	if state != GameState.PLAYING:
		return
	state = new_state
	get_tree().paused = true
	Sfx.play("victory" if state == GameState.VICTORY else "game_over")
	state_changed.emit(state)


func _on_player_died(_player):
	_end_game(GameState.GAME_OVER)
