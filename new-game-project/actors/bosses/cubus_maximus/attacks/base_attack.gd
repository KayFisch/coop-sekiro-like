class_name Attack
extends RefCounted
## One boss attack: its telegraph, its execution and its cleanup.
##
## The boss owns the state machine (idle -> telegraph -> attacking -> recover/stagger) and
## calls into the active attack. The attack keeps its own phase and timer, and reports back
## by setting `completed`, along with how the boss should come out of it (recover, or stagger).
## Attack instances are reused: start() resets them for each new use.

signal parry_success(player, kind)

var boss = null  # the BaseBoss running this attack
var players: Array = []
var completed = false
var phase = 0  # each attack's own Phase enum, where 0 is always NONE
var timer = 0.0  # counts down within the current phase

# How the boss leaves the attack once it's completed.
var recover_time = 0.8
var stagger_time = 0.0  # > 0: stagger instead of recovering
var stagger_tumble = false
var stagger_knock = Vector2.ZERO


# Called when the boss commits to this attack, before its telegraph.
func start(boss_node, player_nodes: Array):
	boss = boss_node
	players = player_nodes
	completed = false
	phase = 0
	timer = 0.0
	recover_time = 0.8
	stagger_time = 0.0
	stagger_tumble = false
	stagger_knock = Vector2.ZERO


# Called every physics frame while the attack is executing (after its telegraph).
func update(_delta: float):
	pass


# Stops the attack early (e.g. the boss died mid-attack).
func interrupt():
	cleanup()
	completed = true
	phase = 0


func get_telegraph_color() -> Color:
	return Color.WHITE


# --- Further hooks used by BaseBoss ---

func get_attack_name() -> String:
	return ""


func get_telegraph_duration() -> float:
	return 1.0


# True for attacks telegraphed by the boss flying to the arena's center and charging there.
func uses_center_charge() -> bool:
	return false


# Called every telegraph frame; progress runs 0 -> 1 over the telegraph.
func update_telegraph(_progress: float):
	pass


# Called once when the telegraph ends and the attack proper begins.
func execute():
	pass


# The player the boss's target marker should point at, as {"who": player, "color": Color};
# "color" is optional (defaults to the boss's body color). null for no marker.
func get_marker(_telegraphing: bool):
	return null


# Removes anything the attack left in the arena and releases anything it holds.
func cleanup():
	pass


# --- Helpers for subclasses ---

func finish(recover: float):
	recover_time = recover
	completed = true
	phase = 0


func finish_with_stagger(duration: float, tumble = false, knock = Vector2.ZERO):
	stagger_time = duration
	stagger_tumble = tumble
	stagger_knock = knock
	completed = true
	phase = 0
