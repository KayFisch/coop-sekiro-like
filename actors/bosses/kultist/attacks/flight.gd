class_name KultistFlight
extends Attack
## FLIGHT: the Kultist's flight alone, to try it in the lab (F5); not in his attack order (it can
## be put there). He rises where he stands to flight_height in rise_time (the telegraph), hovers
## flight_hover_time and comes down in descend_time (kultist_body.gd, "THE FLIGHT"), his staves
## held up level over his head. Up there he has no guard.

enum Phase { NONE, HOVERING, LANDING }

const RECOVER_TIME = 0.3


func get_attack_name() -> String:
	return "FLIGHT"


func fits(_boss_node) -> bool:
	return true


func needs_reach() -> bool:
	return false


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	boss.fly_to(Vector2(boss.global_position.x, boss.home_position.y - boss.flight_height), boss.rise_time)


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


func get_telegraph_duration() -> float:
	return boss.rise_time


func update_telegraph(_progress: float):
	_hold_up()


func execute():
	phase = Phase.HOVERING
	timer = boss.flight_hover_time
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)


func _hold_up():
	for layer in boss.LAYERS:
		boss.pose_staff(layer, boss.POSE_CHANNEL)


func update(delta: float):
	_hold_up()
	timer -= delta
	match phase:
		Phase.HOVERING:
			if timer <= 0.0:
				boss.land(boss.descend_time)
				phase = Phase.LANDING
		Phase.LANDING:
			if not boss.is_aloft():
				finish(RECOVER_TIME)
