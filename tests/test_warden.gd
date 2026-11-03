extends "res://tests/test_case.gd"
## The Warden's room (levels/warden/: the try-out boss set up as the Warden, Moves.fix()) and the
## select screen showing and hiding the try-out boss and the test rooms (Moves "select_all").

const WARDEN = "res://levels/warden/warden.tscn"
const SELECT = "res://ui/boss_select.tscn"
const BossSelect = preload("res://ui/boss_select.gd")


func test_the_warden_holds_his_switches():
	# F1 set otherwise: none of it reaches him.
	set_move("bifrons_stand_in", "off")
	set_move("bifrons_mode", "patterns")
	set_move("bifrons_guard_break", "on")
	set_move("bifrons_coop_windows", false)
	await load_scene(WARDEN)
	var boss = GameManager.boss
	check(boss != null and boss.is_chains(), "in his room: the try-out boss in chains")
	check(Moves.value("bifrons_guard_break") == "motif_end" and not boss.guard_breaks(), "...his guard breaking only at a motif's end")
	check(Moves.on("bifrons_coop_windows"), "...a co-op parry's windows on, whatever F1 says")
	for key in load("res://levels/warden/warden.gd").SWITCHES:
		check(Moves.is_fixed(key), key + ": fixed in his room")
	check(Moves._values["bifrons_mode"] == "patterns", "what F1 holds is left as it was")
	Moves._selected = 0
	Moves._tab = Moves.TABS.find("Bifrons")
	var row = Moves._tab_entries().find(Moves.ENTRIES.filter(func(e): return e.key == "bifrons_mode")[0])
	Moves._selected = row
	Moves._change(1)
	check(Moves.value("bifrons_mode") == "chains" and Moves._values["bifrons_mode"] == "patterns", "F1 can't change it there")
	await load_scene("res://levels/threshold/threshold.tscn")
	check(not Moves.is_fixed("bifrons_mode") and Moves.value("bifrons_mode") == "patterns", "out of his room: F1's again")


func test_the_select_screen_shows_and_hides():
	var hidden = BossSelect.FIGHTS.filter(func(f): return f.get("test", false))
	check(not hidden.is_empty(), "some entries are test rooms")
	var select = load(SELECT).instantiate()
	add_child(select)
	await frames(1)
	var names = select._levels.map(func(b): return b.text)
	check(select._levels.size() == BossSelect.FIGHTS.size() - hidden.size(), "select_all off: the test rooms hidden (%d shown)" % select._levels.size())
	check(names[0].contains("Tutorial"), "...first the tutorial")
	check(names[1].contains("Columna Bifrons") and BossSelect.shown()[1].scene == WARDEN, "...then the Warden, as Columna Bifrons")
	check(not names.any(func(n): return n.contains("Try-out boss")), "...the try-out boss not among them")
	# A hidden one's number starts nothing.
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1 + select._levels.size()  # the first number past the shown ones
	var scene = get_tree().current_scene
	select._unhandled_input(key)
	await frames(2)
	check(get_tree().current_scene == scene, "a hidden one can't be started by its number")
	set_move("select_all", true)
	await frames(1)
	check(select._levels.size() == BossSelect.FIGHTS.size(), "select_all on: all of them, at once (%d)" % select._levels.size())
	set_move("select_all", false)
	await frames(1)
	check(select._levels.size() == BossSelect.FIGHTS.size() - hidden.size(), "...and off again: hidden again")
	select.queue_free()
