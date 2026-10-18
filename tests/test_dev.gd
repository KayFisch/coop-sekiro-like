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


func test_lab_keys():
	await _setup()
	boss.dev_hold = false
	Dev.lab_on = true
	var click = Beat.click_on
	await _key(KEY_M)
	check(boss.dev_still, "M: his moving off")
	check(Beat.click_on == click, "...and the click doesn't hear it while the lab is open")
	var x = boss.global_position.x
	p1.global_position.x = x - 260.0  # far: he'd walk up to them
	boss.dev_hold = true
	await wait(0.6)
	near(boss.global_position.x, x, 1.0, "still: he stays where he is")
	var pick = Dev._pick
	await _key(KEY_E)
	check(Dev._pick != pick, "E: the next attack")
	Tuning._set_panel(true)
	pick = Dev._pick
	await _key(KEY_E)
	check(Dev._pick == pick, "with F2 open its keys come first")
	Tuning._set_panel(false)
	await _key(KEY_M)
	check(not boss.dev_still, "M again: he moves")
	Dev.lab_on = false


# A key pressed and let go, as from the keyboard: `code` where it sits (US layout), `label` what
# it says on it (a German keyboard's Z sits where the US Y does).
func _key(code: int, label = KEY_NONE, ctrl = false):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = label
		event.ctrl_pressed = ctrl
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)


# Z on a German keyboard: his next attack is that one. Held (H): that one, and then nothing; not
# held: that one, and then he fights on.
func test_lab_runs_one_next():
	await _setup()
	Dev.lab_on = true
	Dev._pick = Dev._attack_names().find("TRIPLE")
	p1.global_position.x = boss.global_position.x - 120.0
	await _key(KEY_Y, KEY_Z)
	await wait(0.3)
	check(boss.current_attack != null and boss.current_attack.get_attack_name() == "TRIPLE", "held, Z: TRIPLE")
	await _until_idle()
	await wait(2.0)
	check(boss.state == BaseBoss.State.IDLE, "...and then nothing")
	boss.dev_hold = false
	set_number("bifrons_pause_min", 0.2)
	set_number("bifrons_pause_max", 0.2)
	await _key(KEY_Y, KEY_Z)
	await wait(0.3)
	check(boss.current_attack != null and boss.current_attack.get_attack_name() == "TRIPLE", "not held, Z: TRIPLE")
	await _until_idle()
	var fights_on = false
	for i in 240:
		await get_tree().physics_frame
		if boss.state != BaseBoss.State.IDLE:
			fights_on = true
			break
	check(fights_on, "...and then he fights on")
	Dev.lab_on = false


func _until_idle():
	for i in 600:
		if boss.state == BaseBoss.State.IDLE:
			return
		await get_tree().physics_frame


# F2: Ctrl changes by a tenth of a step; nothing goes below 0, nothing has a top.
func test_tuning_steps():
	await _setup()
	Tuning.saving = false  # the panel's keys save; not this test's numbers
	Tuning._set_panel(true)
	var key = "his_heavy_damage"
	var row = Tuning._rows().find_custom(func(e): return e != null and e.key == key)
	if row < 0:
		Tuning._tab = Tuning._tabs().find_custom(func(t): return t[0] == "sync" and t[1] == "damage")
		row = Tuning._rows().find_custom(func(e): return e != null and e.key == key)
	Tuning._selected = row
	set_number(key, 18.0)
	await _key(KEY_RIGHT, KEY_RIGHT, true)
	near(Tuning.value(key), 18.1, 0.001, "Ctrl: a tenth of a step")
	set_number(key, 5000.0)
	await _key(KEY_RIGHT)
	near(Tuning.value(key), 5001.0, 0.001, "no top")
	set_number(key, 0.5)
	await _key(KEY_LEFT)
	near(Tuning.value(key), 0.0, 0.001, "never below 0")
	Tuning._set_panel(false)
	Tuning.saving = true
