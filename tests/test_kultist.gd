extends "res://tests/test_case.gd"
## The Kultist (actors/bosses/kultist/, docs/boss_kultist.md) in his room: his elements' rule, an
## image and a staff in each half, his staff's guard, his flight, fire and lightning (a parry by
## both sends the bolt back into him; the fire hits whoever stays out in it), staff and spells
## (what B doesn't stop strikes A), and the order of his attacks. His own attacks are held off
## (BaseBoss.dev_hold) and run one at a time (dev_next), faster than in the fight.

const ROOM = "res://levels/kultist/kultist_room.tscn"

var rules
var boss
var p1
var p2


# A player as KultistElement.judge() sees one.
class Stub:
	var parry = false
	var block = false

	func is_perfect_parry() -> bool:
		return parry

	func is_blocking() -> bool:
		return block


func _setup():
	await load_scene(ROOM)
	rules = GameManager.rules
	boss = GameManager.boss
	boss.dev_hold = true
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	# His attacks, quicker: the same steps in less time.
	boss.channel_rise_time = 0.5
	boss.fire_tell_time = 0.6
	boss.fire_speed = 1400.0
	boss.fire_burn_time = 1.0
	boss.bolt_tell_time = 0.4
	boss.bolt_after_time = 0.2
	boss.descend_time = 0.3
	boss.spells_turn_time = 0.5
	boss.spells_strikes = 2
	boss.spells_count = 2
	boss.spells_gap = 1.0
	await wait(0.4)


# Runs one of his attacks and waits until he's done with it, calling `each_frame` every physics
# frame meanwhile with the attack. Returns the attack.
func _run(attack_name: String, each_frame = null, longest = 12.0):
	var attack = boss.find_attack(attack_name)
	boss.dev_next = attack_name
	boss.timer = 0.0
	var frame = 0
	while boss.current_attack != attack and frame < 60:
		await get_tree().physics_frame
		frame += 1
	check(boss.current_attack == attack, attack_name + " starts")
	var waited = 0.0
	while boss.current_attack == attack and waited < longest:
		if each_frame != null:
			each_frame.call(attack)
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(waited < longest, attack_name + " ends")
	return attack


func _place(left_x: float, right_x: float):
	p1.global_position.x = left_x
	p2.global_position.x = right_x
	for p in [p1, p2]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0


func test_elements():
	var stub = Stub.new()
	var expect = {
		KultistElement.STAFF: ["parried", "blocked", "hit"],
		KultistElement.LIGHTNING: ["parried", "blocked", "hit"],
		KultistElement.FIRE: ["hit", "hit", "hit"],
		KultistElement.DEMONIC: ["hit", "hit", "hit"],
	}
	for element in expect:
		var got = []
		for state in [[true, false], [false, true], [false, false]]:
			stub.parry = state[0]
			stub.block = state[1]
			got.append(KultistElement.judge(element, stub))
		check(got == expect[element], "%s: parry, block, nothing -> %s (got %s)" % [KultistElement.name_of(element), expect[element], got])
	check(KultistElement.RULES[KultistElement.FIRE].answer == KultistElement.Answer.DODGE, "fire: dodge it")
	check(KultistElement.RULES[KultistElement.DEMONIC].answer == KultistElement.Answer.BREAK_FREE, "demonic: break free")


func test_a_look_and_a_staff_in_each_half():
	await _setup()
	check(boss.get_script().resource_path.ends_with("kultist.gd"), "the Kultist is the room's boss")
	check(rules != null and rules.boss == boss, "his fight runs on the sync rules")
	check(p1.visibility_layer == MirrorView.LIGHT and p2.visibility_layer == MirrorView.SHADOW, "the screen is mirrored")
	check(boss._bits[1] == MirrorView.LIGHT and boss._bits[2] == MirrorView.SHADOW, "each half's image of him is drawn in its half")
	check(boss._skins[1].color.get_luminance() > 0.5 and boss._skins[2].color.get_luminance() < 0.3,
		"light in the light half, dark in the shadow half")
	_place(boss.global_position.x - 120.0, boss.global_position.x + 120.0)
	await wait(0.4)
	check(boss._sides[1] < 0.0 and boss._sides[2] > 0.0, "each staff on its player's side")
	_place(boss.global_position.x + 100.0, boss.global_position.x + 140.0)
	await wait(0.4)
	check(boss._sides[1] > 0.0, "a staff swings round to its player when they pass him")


func test_guard():
	await _setup()
	_place(boss.global_position.x - 100.0, boss.global_position.x + 140.0)
	await wait(0.4)
	check(boss.is_guarding(p1) and boss.is_guarding(p2), "his staves resting: he guards against both")
	boss.staff_parry_chance = 1.0
	var sync = rules.boss_sync
	boss.take_damage(10.0, p1)
	check(rules.boss_sync == sync and p1._recoil_timer > 0.0, "a hit on a resting staff is parried: their blade knocked back, no sync lost")
	boss.staff_parry_chance = 0.0
	await wait(0.5)
	boss.take_damage(10.0, p2)
	check(rules.boss_sync == sync and p2._recoil_timer <= 0.0, "...or blocked")
	# A strike at P1: their staff busy, the other one still guarding.
	boss.staff_windup = 1.2
	boss.dev_next = "STAFF"
	boss.timer = 0.0
	await wait(0.6)
	check(not boss.is_guarding(p1) and boss.is_guarding(p2), "striking at P1: open to P1, guarded against P2")
	boss.take_damage(10.0, p1)
	check(rules.boss_sync < sync, "...and P1's hit lands")


func test_flight():
	await _setup()
	var home = boss.home_position.y
	var seen = {"top": home, "guarded": false, "beam": false}  # (a lambda can't assign the test's locals)
	await _run("FLIGHT", func(_a):
		seen.top = minf(seen.top, boss.global_position.y)
		if boss.is_aloft() and boss.global_position.y < home - 50.0:
			seen.guarded = seen.guarded or boss.is_guarding(p1)
			seen.beam = seen.beam or boss._beams[1][1].visible)
	near(seen.top, home - boss.flight_height, boss.hover_bob + 1.0, "he rises flight_height")
	check(not seen.guarded, "no guard while he flies")
	check(seen.beam, "the beam joins him to his reflection while he's up")
	near(boss.global_position.y, home, 0.5, "and he's back on the floor")
	check(not boss.is_aloft(), "...landed")


func test_lightning_parried_by_both_goes_back_into_him():
	await _setup()
	var middle = KultistFireAndLightning.middle()
	_place(middle - 20.0, middle + 20.0)
	var sync = rules.boss_sync
	var team = rules.team
	var pressed = [false]
	var attack = await _run("FIRE_AND_LIGHTNING", func(a):
		if a.phase == KultistFireAndLightning.Phase.BOLT and not pressed[0] and a._bolt_at - a._time <= 0.07:
			pressed[0] = true
			hold(p1, "block")
			hold(p2, "block"))
	hold(p1, "block", false)
	hold(p2, "block", false)
	check(attack.reflected, "both parried: the bolt goes back into him")
	near(sync - rules.boss_sync, Tuning.value("their_heavy_damage"), 0.01, "...a heavy hit on him")
	near(rules.team, team, 0.01, "...and the players lose no sync")


func test_fire_hits_who_stays_out_and_lightning_who_doesnt_parry():
	await _setup()
	var middle = KultistFireAndLightning.middle()
	_place(middle, BaseBoss.ARENA_LEFT + 100.0)  # P1 in the middle, P2 out by the wall
	var team = rules.team
	var attack = await _run("FIRE_AND_LIGHTNING")
	check(not attack.reflected, "not parried: nothing goes back")
	near(team - rules.team, 2.0 * Tuning.value("his_heavy_damage") * Tuning.value("his_normal_share"), 0.01,
		"two normal hits: the fire on P2, the bolt on P1")
	check(p2.global_position.x > BaseBoss.ARENA_LEFT + 100.0, "the fire throws its player toward the middle")


func test_spells_stopped_by_b_or_striking_a():
	await _setup()
	for p in [p1, p2]:
		p.invincible = true  # their hits land, and cost nothing: nobody dies in between
	boss.spells_victim = boss.Victim.P1
	_place(boss.global_position.x - 150.0, boss.global_position.x + 150.0)
	var pressed = {}  # spell -> frames B's block has been held for it
	var attack = await _run("STAFF_AND_SPELLS", func(a):
		for spell in a._spells:
			if is_instance_valid(spell) and spell._stage == KultistSpell.Stage.CUE and not pressed.has(spell) \
					and spell.cue_time - spell._age <= 0.07:
				pressed[spell] = 0
				hold(p2, "block")
		for spell in pressed:
			pressed[spell] += 1
			if pressed[spell] == 4:
				hold(p2, "block", false))
	hold(p2, "block", false)
	check(attack.victim == p1 and attack.caster_target == p2, "A is P1 (spells_victim), B P2")
	check(attack.stopped == boss.spells_count and attack.through == 0, "B parried each spell: none gets to A (stopped %d, through %d)" % [attack.stopped, attack.through])
	_place(boss.global_position.x - 150.0, boss.global_position.x + 150.0)
	await wait(0.8)
	attack = await _run("STAFF_AND_SPELLS")
	check(attack.through == boss.spells_count and attack.stopped == 0, "B did nothing: each spell runs through the axis to A (through %d)" % attack.through)


func test_his_order():
	await _setup()
	var names = []
	for i in 5:
		names.append(boss.pick_attack().get_attack_name())
	check(names == ["STAFF", "FIRE_AND_LIGHTNING", "STAFF", "STAFF_AND_SPELLS", "STAFF"], "his attacks come in attack_order, round and round (got %s)" % [names])
	boss.dev_next = "FLIGHT"
	check(boss.pick_attack().get_attack_name() == "FLIGHT", "the lab's pick comes first")
	check(boss.pick_attack().get_attack_name() == "FIRE_AND_LIGHTNING", "...and the order goes on where it was")
