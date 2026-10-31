extends "res://tests/test_case.gd"
## The mirrored screen in the sync mode (ui/mirror_view.gd, MERGED; Moves "sync_merge_view"): bound,
## the halves merge in one movement with the pair's (SyncBond.flow()), nobody is shown twice, and
## every boss shows himself by the one rule (MirrorView.half_bit()), in all four fights.

const FIGHTS = {
	"try-out boss": "res://levels/threshold/threshold.tscn",
	"hitter": "res://levels/heavy_hitter/hitter_room.tscn",
	"kultist": "res://levels/kultist/kultist_room.tscn",
	"acrobat": "res://levels/acrobat/acrobat_room.tscn",
}

var rules
var bond
var boss
var view
var p1
var p2


func _setup(path: String, merge = true):
	set_move("bifrons_stand_in", "off")
	set_move("mirror_view", true)
	set_move("sync_merge_view", merge)
	await load_scene(path)
	rules = GameManager.rules
	bond = rules.bond
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	view =get_tree().get_first_node_in_group("mirror_view")
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	p1.invincible = true
	p2.invincible = true
	rules._set_team(rules.team_max())


# Both side by side, away from him: bound.
func _bind():
	p1.global_position.x = 200.0
	p2.global_position.x = 220.0
	var waited = 0.0
	while not bond.bound and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


# Where a player is drawn: each half's view, and the two bands of the flow (merging).
func _shown(p) -> Array:
	var shown = []
	var places = [
		["top", view._halves[0].viewport, true],
		["bottom", view._halves[1].viewport, true],
		["rising", view._flow, view._rise.visible],
		["draining", view._flow, view._drain.visible],
	]
	for place in places:
		if place[2] and p.visibility_layer & place[1].canvas_cull_mask:
			shown.append(place[0])
	return shown


# Every one of the boss's visible parts that is drawn on a player's half only (his sync rules,
# drawing the players' signs, aside).
func _half_parts(node: Node, found = []) -> Array:
	if node == rules:
		return found
	if node is CanvasItem and node.is_visible_in_tree() and node.visibility_layer != MirrorView.WORLD:
		found.append(node.name)
	for child in node.get_children():
		_half_parts(child, found)
	return found


func test_nobody_twice():
	for fight in FIGHTS:
		for merge in [false, true]:
			await _setup(FIGHTS[fight], merge)
			await _bind()
			check(bond.bound, "%s: bound" % fight)
			await wait(Tuning.value("sync_merge_time") + 0.2)
			check(_shown(p1) == ["top"], "%s, merge %s: P1 only in the light half (%s)" % [fight, merge, _shown(p1)])
			var p2_at = ["rising"] if merge else ["bottom"]
			check(_shown(p2) == p2_at, "%s, merge %s: P2 shown once, %s (%s)" % [fight, merge, p2_at, _shown(p2)])


func test_merge_and_back():
	await _setup(FIGHTS["try-out boss"])
	var screen = view.get_viewport().get_visible_rect().size
	var strip = Tuning.value("sync_merge_strip")
	near(view._line.position.y + MirrorView.LINE_WIDTH / 2.0, screen.y / 2.0, 0.5, "apart: the line in the middle")
	await _bind()
	# In step with the pair: the line where the bond's flow says, the carried one too.
	var off = 0.0
	var samples = 0
	while bond.flow() < 1.0 and samples < 120:
		await get_tree().process_frame
		var line = view._line.position.y + MirrorView.LINE_WIDTH / 2.0
		off = maxf(off, absf(line - lerpf(screen.y / 2.0, screen.y - strip, view._merge)))
		off = maxf(off, absf(view._merge - bond.flow()))
		samples += 1
	check(off < 1.0, "merging: the line and the flow one movement (off by %.2f)" % off)
	check(samples > 5, "...taking a while (%d frames)" % samples)
	await get_tree().process_frame
	near(view._line.position.y + MirrorView.LINE_WIDTH / 2.0, screen.y - strip, 0.5, "merged: the line down to the strip")
	check(not view._drain.visible and view._rise.visible, "merged: P2 in the light half, nothing of them in the strip")
	near(absf(p2.global_position.x - p1.global_position.x), p1.CARRY_GAP, 0.5, "merged: the carried one at the other's side")
	rules._set_team(rules.team_max() * 0.5)  # the sync mode over: apart again
	await wait(Tuning.value("sync_merge_time") + 0.2)
	check(not bond.bound, "the sync mode over: unbound")
	near(view._line.position.y + MirrorView.LINE_WIDTH / 2.0, screen.y / 2.0, 0.5, "...and the line back in the middle")
	check(_shown(p2) == ["bottom"], "...P2 back in the shadow half (%s)" % [_shown(p2)])


func test_one_rule_for_every_boss():
	for fight in FIGHTS:
		await _setup(FIGHTS[fight])
		check(MirrorView.is_split() and MirrorView.half_bit(2) == MirrorView.SHADOW, "%s, apart: the halves two" % fight)
		await _bind()
		await wait(Tuning.value("sync_merge_time") + 0.2)
		check(not MirrorView.is_split() and MirrorView.half_bit(1) == MirrorView.WORLD, "%s, merged: one" % fight)
		var parts = _half_parts(boss)
		check(parts.is_empty(), "%s, merged: nothing of him in one half only, as on the one-sided screen (%s)" % [fight, parts])
