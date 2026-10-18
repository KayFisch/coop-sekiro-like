extends "res://tests/test_case.gd"
## The developer tools (core/dev.gd): the boss lab runs, loops and holds an attack, and the log
## counts a parry, a hit pressed too early, and one pressed late, with their timing.

var boss
var p1


func _setup():
	set_move("bifrons_stand_in", "off")
	await load_scene("res://levels/threshold/threshold.tscn")
	boss = GameManager.boss
	boss.dev_hold = true
	p1 = GameManager.players[0]
	await wait(0.2)


func test_lab_runs_and_loops():
	await _setup()
	await wait(1.0)
	check(boss.state == BaseBoss.State.IDLE, "held: he starts nothing of his own")
	Dev.run_attack("TRIPLE")
	await wait(0.3)
	check(boss.current_attack != null and boss.current_attack.get_attack_name() == "TRIPLE", "run: he starts TRIPLE")
	Dev._loop = "BOTH"
	var seen = 0
	var last = null
	for i in 400:
		await get_tree().physics_frame
		var attack = boss.current_attack
		if attack != last and attack != null and attack.get_attack_name() == "BOTH":
			seen += 1
		last = attack
		if seen >= 2:
			break
	check(seen >= 2, "loop: BOTH again and again")
	Dev._loop = ""


func test_log_counts_presses():
	await _setup()
	var judged = {"blade": -1, "under": [p1], "parriers": [p1], "parried": true}
	await wait(p1.PARRY_SPAM_LOCK)
	await tap(p1, "block")
	await wait(0.05)
	p1._invuln_timer = 0.0
	boss.land(judged)
	var s = Dev._stats_of(p1)
	check(s.parry == 1, "a parry counted")
	check(not s.parry_press.is_empty() and s.parry_press[0] > 0.0 and s.parry_press[0] < 0.2,
		"...with how long before the landing it was pressed")
	await wait(0.4)
	p1._invuln_timer = 0.0
	await tap(p1, "block")
	await wait(0.3)
	judged = {"blade": -1, "under": [p1], "parriers": [], "parried": false}
	boss.land(judged)
	check(s.hit == 1 and s.early.size() == 1, "a hit pressed too early counted as early")
	await wait(0.7)
	p1._invuln_timer = 0.0
	boss.land(judged)
	await wait(0.1)
	await tap(p1, "block")
	await wait(0.1)
	check(s.hit == 2 and s.late.size() == 1, "a hit pressed after it landed counted as late")
	check(Dev._overlay_text().contains("P1: parried 1"), "the overlay shows it")
