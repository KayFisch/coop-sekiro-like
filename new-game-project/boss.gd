extends CharacterBody2D

enum State { IDLE, TELEGRAPH, ATTACK, RECOVER }

var state = State.IDLE
var timer = 0.0
var target_player = null
@onready var body = $ColorRect


@export var telegraph_time = 1  # seconds of warning
@export var attack_speed = 2000.0

func _physics_process(delta):
	timer -= delta
	
	match state:
		State.IDLE:
			if timer <= 0.0:
				_choose_target()
				state = State.TELEGRAPH
				timer = telegraph_time
				body.color = Color.YELLOW  # flash yellow as warning
		
		State.TELEGRAPH:
			if timer <= 0.0:
				state = State.ATTACK
				timer = 0.1
				body.color = Color.RED
		
		State.ATTACK:
			if target_player:
				var direction = (target_player.global_position - global_position).normalized()
				velocity = direction * attack_speed
				move_and_slide()
			if timer <= 0.0:
				state = State.RECOVER
				timer = 1.0
				velocity = Vector2.ZERO
				body.color = Color.WHITE
		
		State.RECOVER:
			var center = get_viewport_rect().size / 2
			global_position = global_position.lerp(center, 0.05)
			if timer <= 0.0:
				state = State.IDLE
				timer = 1.5  # pause before next attack
				

func _choose_target():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		target_player = players[randi() % players.size()]
