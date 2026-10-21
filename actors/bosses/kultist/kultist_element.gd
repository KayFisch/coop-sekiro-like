class_name KultistElement
## The Kultist's elements: one rule each for what a player does about a blow of his, and the
## colors that say so (docs/boss_kultist.md, "The elements"). Every blow of his names its element,
## and how it's telegraphed and what comes of it (judge()) follow from that, whatever the attack.
##
##   STAFF      his staff, in melee: yellow as it's raised, red as it drops (the cue). Parry it; a
##              block takes it too.
##   LIGHTNING  fast: a short yellow crackle, then a red flash (the cue). Parry it; a block takes it.
##   FIRE       delayed, an area: embers where it will burn, then it erupts. Get out of it: it can't
##              be parried or blocked.
##   DEMONIC    hands, grabs: break free. No attack of his uses it yet.

enum { STAFF, LIGHTNING, FIRE, DEMONIC }
enum Answer { PARRY, DODGE, BREAK_FREE }

# What a blow came to (judge()).
const PARRIED = "parried"
const BLOCKED = "blocked"
const HIT = "hit"

# One rule per element: the player's answer, whether a perfect parry or a block meets it, and its
# colors: "tell" while it's coming, "cue" for the moment to answer (a parry: just before it lands).
# The colors follow the telegraph rule (docs/concept.md, "Telegraphs"): yellow then red is a
# parry, as in Bifrons's fight.
const RULES = {
	STAFF: {"name": "staff", "answer": Answer.PARRY, "parries": true, "blocks": true,
		"tell": Color(1.0, 1.0, 0.0), "cue": Color(1.0, 0.0, 0.0)},
	LIGHTNING: {"name": "lightning", "answer": Answer.PARRY, "parries": true, "blocks": true,
		"tell": Color(1.0, 0.93, 0.35), "cue": Color(1.0, 0.0, 0.0)},
	# TODO(design): orange is new, the color of "get out of the way". It's close to P2's orange
	# (one-sided view only; mirrored, P2 is a shadow), to the red cue, Bifrons's parry sparks and
	# the HUD's low posture.
	FIRE: {"name": "fire", "answer": Answer.DODGE, "parries": false, "blocks": false,
		"tell": Color(0.55, 0.16, 0.04), "cue": Color(1.0, 0.5, 0.1)},
	# TODO(design): there's no grab and no breaking free in the game since Cubus Maximus went
	# (2026-10-18; his grab was escaped with a dash). Until there is, a demonic blow is judged like
	# fire (nothing meets it), and no attack of his uses it. Purple was the grab's color; it's close
	# to the violet shard of the beat-ring and the pink of the sync energy.
	DEMONIC: {"name": "demonic", "answer": Answer.BREAK_FREE, "parries": false, "blocks": false,
		"tell": Color(0.62, 0.2, 0.95), "cue": Color(0.85, 0.45, 1.0)},
}


# What a blow of that element comes to on player `p`, as it lands: PARRIED (a perfect parry, if the
# element takes one), BLOCKED (block held, if it takes that) or HIT.
static func judge(element: int, p) -> String:
	var rule = RULES[element]
	if rule.parries and p.is_perfect_parry():
		return PARRIED
	if rule.blocks and p.is_blocking():
		return BLOCKED
	return HIT


static func tell(element: int) -> Color:
	return RULES[element].tell


static func cue(element: int) -> Color:
	return RULES[element].cue


static func name_of(element: int) -> String:
	return RULES[element].name
