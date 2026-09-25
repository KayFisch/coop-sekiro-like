extends CharacterBody2D

const SPEED = 500.0
@export var player_id: int = 1  # set to 1 or 2 in the inspector

func _physics_process(delta):
	var direction = Vector2.ZERO
	
	if player_id == 1:
		if Input.is_action_pressed("p1_right"): direction.x += 1
		if Input.is_action_pressed("p1_left"):  direction.x -= 1
		if Input.is_action_pressed("p1_down"):  direction.y += 1
		if Input.is_action_pressed("p1_up"):    direction.y -= 1
	elif player_id == 2:
		if Input.is_action_pressed("p2_right"): direction.x += 1
		if Input.is_action_pressed("p2_left"):  direction.x -= 1
		if Input.is_action_pressed("p2_down"):  direction.y += 1
		if Input.is_action_pressed("p2_up"):    direction.y -= 1

	velocity = direction.normalized() * SPEED
	move_and_slide()
