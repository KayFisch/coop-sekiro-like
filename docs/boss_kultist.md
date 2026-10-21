# The Kultist, in Bifrons's room (prototype)

A cultist of fire, lightning and demonic magic (a working name), built on 2026-10-21 (Kay, with
Claude; branch `kay/kultist`) from Kay's brief. A first playable version: placeholder shapes,
every number an export, two great attacks and his staff in between. Everything marked
**open** below is an assumption made to get it running, also in the code as `TODO(design)`.

Code: `actors/bosses/kultist/` (`kultist_body.gd`: his look, staff, guard and flight;
`kultist.gd`: the boss; `kultist_element.gd`: the elements' rule; `attacks/`; `magic/`: the fire,
the bolt and the spells), `levels/kultist/kultist_room.tscn`, `tests/test_kultist.gd`. Select
screen: entry 2.

---

## The arena: Bifrons's room, mirrored

The same room as Bifrons (`levels/threshold/threshold_stage.tscn`, which both fights instance)
on the mirrored screen (`ui/mirror_view.gd`), always on in his room: P1 in the dark half above,
P2 in the pale half below, one player per half.

He's built like Bifrons, an upright block, but **each half shows its own image of him, in that
half's colors** (light above, dark below, like the players: "colors mirrored at the axis",
**open**: that's how it's read). His body is one: where he stands and how high he flies is the
same in both halves.

## His staff, one in each half

Each half has **a staff in the color of its player, facing that player** wherever they are
(Kay, 2026-10-21). It strikes at them and **guards** against them:

- A staff **resting at his side** parries its player's sword hits (their blade knocked back,
  both lose posture) or blocks them (he loses posture), half and half (`staff_parry_chance`,
  **open**: or always?). A strip down his robe on that side shows the guard.
- A staff that's raised, striking, lying where it landed, thrown back by a parry or **casting**
  can't guard: hits land. Back at rest it guards again after `staff_return_time`.
- **Flying**, staggered or in chaos he has **no guard at all** (**open**: flying counts as
  "busy" like casting).
- Each staff only guards its own player. In one half he can strike while the other half's staff
  keeps its guard.

## The elements

One rule table, `KultistElement.RULES`: every blow names its element, and its colors and what
comes of it (`judge()`: parried, blocked, hit) follow from that.

| element | answer | parry | block | tell, cue |
|---|---|---|---|---|
| STAFF (his melee, **open**: an element of its own) | parry | yes | yes | yellow, red |
| LIGHTNING: fast | parry | yes | yes (**open**) | yellow crackle, red flash |
| FIRE: delayed, an area | dodge | no | no (**open**) | dark embers, orange flames |
| DEMONIC: hands, grabs | break free | no | no | purple |

**Demonic isn't built**: there's no grab or break-free system in the game (Cubus Maximus's grab,
escaped with a dash, went with him on 2026-10-18). No attack uses it; until there is one, a
demonic blow would be judged like fire.

## The flight

A state any attack can use (`fly_to()`, `land()`): he rises off the floor (`flight_height`,
`rise_time`), hovers with a small bob, and comes down (`descend_time`). Demonic **wings** open
(only a look), and a **beam** runs straight down from his feet to the floor; his reflection's
beam meets it there, so on screen it joins his two images through the axis. Only his height
changes it. Up to about 130 px he stays under the HUD's meters.

## His attacks

They come in a set order, `attack_order` (STAFF, FIRE_AND_LIGHTNING, STAFF, STAFF_AND_SPELLS,
round and round). **A placeholder**: boss attacks are meant to come in chains with a finale and a
breath (`docs/concept.md`, "Boss design principles").

### STAFF: his melee

`staff_strikes` strikes in a row, each by the staff of the half of the player it's for: the
nearer player first, then the other one if they're in reach too. Raised, yellow (the tell);
drops in `staff_fall_time`, red (the cue); as it drops he lunges at them. A parried staff is
thrown back.

### FIRE_AND_LIGHTNING

1. He flies to the middle of the room and up (the telegraph), wings open, staves held up level
   over his head, their heads glowing.
2. **Fire**: embers glow from the walls in to the edges of a safe place in the middle
   (`safe_width`), then it erupts at both walls and runs inward (`fire_speed`); each place burns
   `fire_burn_time`. Whoever is in it is hit, once (**open**), and thrown toward the middle.
3. As it reaches the safe place (**open**: while it still burns), **lightning** between his two
   images, through the axis: a yellow crackle down to the floor, its width (`bolt_width`) marked
   there, then a red flash, and it strikes everyone in it. Each has to **parry** it; a parrier's
   blade holds its energy for a moment (`absorb_time`: lit, crackling). **Both parry: it goes back
   up into him**, a heavy hit (`reflect_heavy`; **open**: no stagger, no sync for the players, as
   Bifrons's coop parry gives). Anyone in it who didn't parry is hit (blocked: chipped); a player
   outside it isn't hit, but can't parry it either, so it isn't sent back (**open**).
4. He hangs on a moment and comes down.

"Cross Parry" in the brief is read as this: both parrying the bolt at once (**open**: the code
has no cross parry by that name; the coop parry of Bifrons's two swords is the nearest).

### STAFF_AND_SPELLS

One player is **A** (at random, `spells_victim`; Kay, 2026-10-21), the other **B**. It comes in
its turn whenever both players are there (**open**: what sets it off).

- In **A's half** his staff fights A: `spells_strikes` strikes, STAFF's kind, and between them he
  walks after A. A's parries count as any parry (**open**: should they do more here?).
- In **B's half** he holds his staff up at B and casts: a **spell** every `spells_gap`, flying at
  B (`spell_tell_time`), then a red flash. **B parries or blocks it, and it's spent.** B isn't
  hurt by it either way (**open**).
- Not stopped, it **dives into the axis** at B's feet, runs along it to A (on the line, so both
  halves see it), **rises under A** flashing red, and strikes A from below. A can parry or block
  it too, as any lightning (`spell_victim_defends`, **open**: or only B can stop it?).

## Colors

The existing telegraphs (`docs/concept.md`, "Telegraphs"): yellow then red is a parry, as in
Bifrons's fight. New:

- **Orange** (fire, "get out of the way"). Collides with P2's orange (one-sided view only;
  mirrored, P2 is a shadow), the red cue, Bifrons's parry sparks and the HUD's low posture.
- **Purple** (demonic, unused). Collides with Kay's choice for "parry together" (scribble of
  2026-10-02), the beat-ring's violet shard and the pink of the sync energy.
- The lightning bolt wants both players' parries but is **yellow**, not Bifrons's green for
  "together": the element says what to do; that it's for both is seen by it running through both
  halves.
- **The spells** follow "Wer und Was getrennt" (Kay's scribble of 2026-10-02): a yellow crackle
  (*what*: parry), round a core in **A's color** (*whom*: it's for A), ringed in B's (to read on
  either ground).
- His staff turns yellow, then red, as a whole, as Bifrons's blades do (**open**: the scribble
  would keep it in its player's color with an aura round it).

## Trying him out

- **Start**: select screen entry 2, or open `levels/kultist/kultist_room.tscn` and F6.
- **One attack at a time**: the boss lab (F5) lists his attacks, FLIGHT too (the flight alone):
  Q / E pick, Z run, X loop, H his own attacks off, M his moving off, T slower, I invincible
  (`docs/dev_tools.md`).
- **Numbers**: the inspector of `actors/bosses/kultist/kultist.tscn`, in groups (Guard, Flight,
  Order, Moving, Blows, Staff strikes, Fire and lightning, Staff and spells). **Not on F2**, as
  every other fight's numbers are (**open**): the brief asked for exports; F2 would change them
  while playing. What a hit costs is the sync rules' (F2), normal or heavy per blow
  (`..._heavy`): an amount of their own per blow would need the sync rules to take one.
- **Tests**: `godot --headless --script res://tests/run.gd -- kultist`.

## Open, and not built

All of the above marked **open**, and:

- Moving between attacks is a placeholder: up to the nearer player, or the middle between two
  on either side; no drift, no making room as Bifrons has.
- A parry of his strike opens no window for the partner (Bifrons's rule 4).
- Nothing of his own for the players' sync mode (bound, they strike as against Bifrons).
- No stand-in to try him alone (`docs/dev_tools.md`, "A new boss", 5).
- His body blocks as Bifrons's does (TASKS.md: "Durchgang durch Bosse klären").
