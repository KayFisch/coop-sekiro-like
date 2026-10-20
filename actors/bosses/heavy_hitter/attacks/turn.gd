class_name HitterTurn
extends Attack
## The Heavy Hitter turning round (docs/boss_heavy_hitter.md, "Turn"): in both layers his blade goes
## over to the other side, up over him, and the alignment stays. He does it in his breath, by himself
## (THE TURN in heavy_hitter.gd); this is it on its own, for the F5 lab.

enum Phase { NONE, TURNING }

var _name: String
var _time = 0.0


func _init(attack_name: String):
	_name = attack_name


func get_attack_name() -> String:
	return _name


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


func get_telegraph_duration() -> float:
	return 0.01


func execute():
	phase = Phase.TURNING
	_time = 0.0
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	boss.turn_round()


func update(delta: float):
	_time += delta
	boss.pose_weapon(boss.POSE_UP if _time < boss.TURN_TIME * boss.TURN_LIFT else boss.POSE_LEVEL)
	if _time >= boss.TURN_TIME:
		finish(0.2)


# Nothing to parry.
func time_to_strike(_player) -> float:
	return INF
