# The Heavy Hitter, the Ettin (working title)

Status: designed (v0, 2026-10-19); phase 1 built (2026-10-20, branch `nicho/heavy-hitter`: see
"Built (phase 1)" at the end), the rage and phase 2 next. Name and myth open (Kay's list of two-headed
creatures; the working idea is the Ettin, a two-headed giant). General rules: `docs/concept.md`
("Boss design principles", "Blade rules"). The why, and what was dropped: `scribbles.md`,
2026-10-19 ("Heavy Hitter, der Ettin").

## Identity

Two heads, one weapon. Slower than the Warden, heavy, and only interested in landing his blows:
he attacks **whatever is in front of his nose**, and his two heads **quarrel over who gets the
blade**. The reverse of the Warden: **open while he attacks**, guarded only in his breath.
Signature: **he forces movement**; how the formation changes is up to the players.

## The weapon in two layers

One weapon, held level: a **blade** (heavy, slow) at one end, a **pommel** (normal, fast) at the
other. On the mirrored screen the light half shows P1's layer and the shadow half P2's, and **the
weapon can point differently in the two layers**:

- **parallel:** the blade points the same way in both layers (one head has won it);
- **diagonal:** it points one way in the light layer and the other way in the shadow layer (each
  head has it in one layer: the mirror makes the compromise possible).

Alignment × formation decides who stands in front of what (in their own layer, each player is in
front of the blade or of the pommel):

| | ppe (together) | pep (apart) |
|---|---|---|
| **parallel** | both in front of the same end | one at the blade, one at the pommel |
| **diagonal** | one at the blade, one at the pommel | both in front of the same end |

Three fields come out of it:

- **together** (both at the blade): every blade strike is parried together. The rewarding field,
  and the dangerous one.
- **split** (one at the blade, one at the pommel): the one at the blade can only block (see the
  rules, 1), the one at the pommel takes fast jabs and jumps cracks, and is safe. **Both ways out
  are the safe player's:** go over to the partner (over the weapon, or dash-parrying a pommel jab
  through him), or provoke the pommel side (phase 2).
- **both at the pommel:** fast jabs at both; he turns round in his next breath.

He turns the alignment (the heads' quarrel), the players turn the formation (moving) or provoke.
This table is the basis for building his patterns and for reading the fight.

## The rules (v0)

1. **Unisono:** every blade strike happens **in both layers at once**, and each layer's blade is
   parried by that layer's player. Both parry: a **co-op parry** (both get a sync-hit window, and
   it counts twice toward the stagger). Only one parries: the parry only has the **effect of a
   block** (one parry per blade).
2. **The crack:** a blade that lands where nobody of its layer stands in front of it crashes into
   the mirror: a **crack** runs from the impact both ways along the floor line, under him and out
   toward the wall, like breaking glass. It only hurts that layer's player, on the floor: jump it.
3. **The pommel:** fast single jabs at whoever stands in front of it, in each layer. Normal
   strikes: a lone parry is a parry (it opens the partner's window). The pommel side is **open and
   provokable** (see "Provoking").
4. **Open while he attacks:** from a chain's first windup to its end, hits land. **Guarded only in
   his breath** (the weapon held level guards both sides, as the Warden's swords do).
5. **Normal mode: he adapts to the players.** In his breath he turns, to bring the blade in front
   of them. He only turns: the alignment changes only when the heads quarrel (the flip) and in
   rage.
6. **Posture is his rage meter.** It breaks easier and regularly (he hardly parries). Broken:
   **rage**, not the deathblow; his sync stays.
7. **The first rage unlocks phase 2:** the flip, so diagonal in the normal mode too, and
   provoking flips.
8. **Progress is sync damage:** every hit that lands costs his sync, sync hits (simultaneous ones
   after co-op parries) win the players theirs, and the sync mode ends it. Posture damage is less
   progress.

## Verbs (each with one telegraph, the same everywhere)

Colors as with the try-out boss ("Reading him"): green = parry together, yellow = yours alone,
red = it comes.

- **Blade strike:** raised high over him in both layers, then down; green while it's drawn (it
  takes both), red as it comes. Unisono, heavy.
- **Pommel jab:** a short pull back, yellow (yours alone), red as it comes; fast.
- **Flip (the heads' quarrel):** the heads turn to each other; one grabs the blade, and the weapon
  swings 180° in **one** layer (the old sweep): parallel ↔ diagonal. Parriable where it reaches a
  player as it swings through. As his finale it turns together into split; provoked, it turns
  split into together (see "Provoking"). Phase 2.
- **Turn:** he turns right round (both layers), so that the blade is in front of the players. Only
  in his breath, never in rage.
- **Stomp leap:** he crouches, jumps, and lands as a blade strike (unisono, the crack as ever).
  While he's in the air the players can pass under him to switch sides.
- (Maybe later: a **charge**, the weapon held level across the room; jump over it.)

Tempo: half the Warden's, counted in beats of `Beat` (150 BPM: a beat is 0.4 s).

## Motifs (chosen by what's in front of his nose, never by chance)

- **together** (both at the blade): blade (2 beats) – blade (2) – blade (3, held longer). All
  parried together: simultaneous sync hits.
- **split** (one at the blade, one at the pommel): the seesaw, blade (2) – pommel (1) – blade (2)
  – pommel (1).
- (Both at the pommel: jabs only, then the turn in his next breath.)

As with the Warden, a chain repeats its motif and decides only at the end of a repetition. If the
field has changed by then, the next repetition is the new field's motif.

## Finales (each ends in a blade strike that can be parried together)

- **Great hammer:** a long windup, heavy. Parried together: a stagger (0.5 s plus 0.2 s per blade
  parried in the chain). The field stays.
- **Flip:** the heads quarrel and one layer flips, together → split; then a blade strike in the
  new alignment, with a windup long enough for the players to re-form (one goes over to the other
  side), so they can still parry it together. Phase 2.
- **Stomp leap:** changes the formation if the players use it (passing under him); it lands as a
  blade strike.

Which finale comes is his to say, by what he sees (as with the Warden), never chance. Starting
rules for the prototype: in the together field the great hammer; if the together field has lasted
too long, the stomp leap (phase 1) or the flip (phase 2); in the split field, and with both at the
pommel, the stomp leap. Turning split into together is never his finale: that's the players'
(moving, or provoking from phase 2).

## Provoking (his pommel side)

- **Posture:** hits on his pommel side, and parried pommel jabs, cost him much more posture
  (rage sooner).
- **Phase 1:** that's all. The way out of the split field is moving.
- **From phase 2:** a **hit** on his pommel side makes that head grab the blade **in the
  hitter's layer**: that layer flips toward them (split → together). The head turns angry at once
  (you see it); the flip comes at the next end of a repetition (decisions only at fixed points).

## Rage

- **Posture broken → rage**, one chain long. Telegraph: both heads red, a roar, long enough (about
  1.5 to 2 s) for the players to rearrange; it shows which pattern comes.
- In rage he **doesn't turn**: he strikes a fixed pattern from side to side, wherever the players
  stand. Heavy strikes gather them, cracks scatter them; they read whether to parry together or
  to jump.
- **Two patterns:**
  - **Pendulum** (parallel): blade strikes alternating left and right. In ppe: parry together,
    then jump the crack together. In pep: by turns, one parries (a block's effect only) while the
    other jumps.
  - **Cross** (diagonal): alternating. In pep: parry together, then jump together. In ppe: by
    turns.
- **Which one:** the one that's **hard for the formation they're in** as it starts ("he strikes
  where it hurts"): pep → pendulum, ppe → cross. During the telegraph they can switch formation and
  make it the easy one. Not monotonous: the right answer depends on where they stand.
- **Then exhaustion:** a stagger of 0.5 s plus 0.2 s per blade parried in the rage (a co-op parry
  0.4 s; a lone parry that's only a block counts nothing), and the sync of those parries. Good
  players trigger rage on purpose (his pommel side) and profit; less reliable ones are hit more
  than they gain and get a short stagger, so they shouldn't trigger it more often than it comes
  anyway.
- His posture comes back full, and the alignment stays as the pattern left it (pendulum:
  parallel, cross: diagonal). The first rage starts phase 2.
- Maybe a **last rage**, if his sync is worn down slowly (with a quick end through the sync mode it
  won't come): pendulum and cross by turns, ending in the great hammer.

## The sync mode

Many co-op parries bring the players into the sync mode often; heavy sync-mode strikes on the
Hitter should feel especially good. His sync-mode pattern is open (an idea: the heads finally
agree, parallel, the blade at the bound pair). Balance: the sync won by co-op parries against his
heavy strikes (an imperfect parry costs both); his sync and the co-op parry's gain are the knobs.

## Size

A bit smaller than the Warden: players can jump over his level weapon and over him, and pass under
him when he jumps.

## Open

- **Two motifs may be too few** (Nicho): try it out first, then add motifs or change verbs.
- Where the stomp leap takes him, and which way he faces as he lands: built on the spot, turning
  round in the air ("Built (phase 1)"); to be felt out in play.
- His sync-mode pattern.
- The one-sided view: the diagonal weapon and the cracks in one picture (prototype: both layers'
  weapons drawn at once, each in its player's color).
- Whether there's a last rage.
- Name and myth.
- Numbers: tempo, his sync and posture, what a pommel hit costs, the crack's speed and damage, the
  rage telegraph.

## Dropped or narrowed (2026-10-19)

- "Heavy strikes gather, shockwaves scatter" as the basic rule: only in rage.
- "The end of the grip guards the other side": only in his breath.
- The bell ringer (half tempo) and the colossus at the passage (jumping over the level weapon):
  only as elements.
- The sweep: becomes the flip.
- Debris from above: at most as glass shards from the cracks.

## Built (phase 1, 2026-10-20)

Branch `nicho/heavy-hitter`. Code: `actors/bosses/heavy_hitter/`: `hitter_weapon.gd` (the weapon in
two layers, his heads, his guard, the windows), `heavy_hitter.gd` (the boss: the fields, his chains,
his breath, the sync rules' hooks, where he stands), `attacks/swings.gd` (a chain and its verbs),
`attacks/turn.gd`, `crack.gd`, `hitter_stand_in.gd`. His room: `levels/heavy_hitter/hitter_room.tscn`
(the Threshold's geometry), entry 2 on the select screen. Tests: `tests/test_heavy_hitter.gd`. Phase 1
only: the weapon always parallel, no flip, no provoking flips, no rage (a broken posture: a long
stagger in its place, and his sync stays).

What's built, and how; where the design left it open, the choice made:

- **The weapon in two layers.** In each layer the blade points left or right (P1's layer is the light
  half, P2's the shadow half), and it moves the same in both. Each half shows only its own; one-sided,
  both are drawn, a little apart, each with its player's color on the edge and crossguard. Two heads
  sit on top of him; in each layer a band across the head on the blade's side, in that player's
  color. A hit on his pommel side turns that head red for a moment.
- **In front of the blade** (or the pommel) is the side a player is on, in their own layer: that
  decides the field. Whether a strike reaches them is its reach: the blade 200 px from his center,
  the pommel 140. A player on the blade's side but further off gets the crack.
- **Unisono, the pommel, open while he attacks:** as in "The rules (v0)". In the split field the one
  at the blade can only block (a lone parry), so the blade strike there never opens a window; the
  pommel jab parried does, for the partner.
- **The crack:** a front running both ways along the floor line from where the blade came down (500
  px/s, 520 px each way, or to a wall). It hits its layer's player if they're on the floor as it
  passes, whatever they hold (block doesn't help: jump it), and never the other player. It costs a
  normal hit (a third of his heavy hit's sync). Glass-white in the halves, the player's color
  one-sided, with a sound of glass.
- **His guard:** between his chains, once the weapon is level again (the recovery after a chain
  included); not while he turns. It parries or blocks by chance, as Bifrons's (F2 sync page,
  "boss_parry_chance").
- **The motifs** (beats of 0.4 s): together = blade 2, blade 2, blade 3; split = blade 2, pommel 1,
  blade 2, pommel 1; both at the pommel = pommel 2, 1, 1. Chosen as a chain starts and as each
  repetition ends (1 to 3 of them, at random).
- **The finales:** in the together field the great hammer (a 4-beat windup); in it for 2 of his chains
  in a row, the stomp leap; split or both at the pommel, the stomp leap. Any finale parried together
  staggers him 0.5 s, and 0.2 s per blade parried in the chain (a co-op parry counts two, a parried
  jab one, a lone parry with a block's effect nothing).
- **The stomp leap: on the spot, turning round in the air.** He crouches (the weapon raised, green),
  jumps (his feet 110 px up, about 0.7 s in the air, his body no obstacle meanwhile), turns round on the
  way up (the raised blade shows the side it comes down on) and lands where he took off, as a blade
  strike on the side that was behind him. In the split field the one at his blade can go under him
  to the partner: together, and parried together, staggered; nobody moving: split again, the roles
  turned round. From the together field both have to go under him, or both are at his pommel (two
  cracks). Both at the pommel: he lands facing them. Why: he only says where the blade comes; where
  they go is the players' (as with Bifrons's leap), and his place stays predictable.
- **The breath** (2.5 to 3.5 s, after a 0.8 s recovery): he walks slowly (60 px/s) and, as it begins,
  turns round if that brings more of the players in front of the blade; with one on each side, to
  whoever hit his pommel side last since his last turn, else round anyway. A hit at his guard
  meanwhile is answered at once by the next chain; an attacker at his pommel gets a jab first.
- **His pommel side:** hits there (landed or guarded) and parried jabs cost him twice the posture.
- **His posture** is his own number (F2, 200 as Bifrons's). It breaks much more easily anyway, as
  every blade strike is heavy: a co-op parry costs him 2 x 15, its two sync hits 2 x 15, so a together
  repetition played cleanly costs him about 180 (one of Bifrons's about 60). Broken: a 3 s stagger for
  now, his sync stays.
- **Where he stands:** a player on each side: in the middle between them. Else he keeps the nearer one
  in his blade's reach (steps back under 70 px, walks up past 200). He starts a chain only while
  someone is within 300 px.
- **In the players' sync mode** (a placeholder): the together motif only, and the great hammer; his
  beats and breath 1.4 times as long; he holds off his next chain while one of them draws back. The
  pair's strike through his guard (in his breath) costs him a normal hit's sync and he reels; while
  he attacks it lands heavy.
- **The F5 lab:** CHAIN (his own attack), TOGETHER, SPLIT, JABS (each motif once), HAMMER, STOMP (each
  finale), BLADE, POMMEL (one verb), TURN.
- **The stand-in** (F1 "bifrons_stand_in": left = P1, right = P2): goes in front of the blade of its
  layer (over him between his chains, under him in a stomp leap), parries (75 %) or blocks (15 %) his
  strikes at it, jumps the cracks of its layer, strikes in its window, and plays the sync mode along.

His numbers on F2 (his own page, "Heavy Hitter"; it opens there in his room):

| What | F2 | Now |
|---|---|---|
| A beat of his / a blade's drop / a jab's thrust | "hitter_beat", "hitter_drop_time", "hitter_jab_time" | 0.4 / 0.3 / 0.18 s |
| After a chain, recovering / walking | "hitter_recover_time", "hitter_walk_speed" | 0.8 s / 60 px/s |
| Repetitions / together chains before the stomp leap | "hitter_reps_min", "_max" / "hitter_together_stale" | 1 - 3 / 2 |
| The breath | "hitter_breath_min", "_max" | 2.5 - 3.5 s |
| His posture / his pommel side / broken: staggered | "hitter_posture_max", "hitter_pommel_posture", "hitter_break_stagger" | 200 / x2 / 3 s |
| A finale parried together: stagger / per blade | "hitter_stagger_least", "_per_parry" | 0.5 / 0.2 s |
| The crack: speed / length each way / its cost | "hitter_crack_speed", "_length", "_share" | 500 px/s / 520 px / 0.33 of a heavy hit |
| The stand-in: parries / blocks | "hitter_stand_in_parry", "_block" | 0.75 / 0.15 |

In code, as structure: the weapon's size and poses and the reaches (`hitter_weapon.gd`), the stomp
leap's height and timing (`attacks/swings.gd`), the motifs and finales (`MOTIFS`, `FINALES` in
`heavy_hitter.gd`). His sync, the windows and what a hit costs are the sync page's, shared with
Bifrons.

To look for in the first playtest:

- Do the fields read: does each of you see whether you're at the blade or the pommel, in your own half?
  And one-sided, with both weapons drawn?
- Unisono: is "parry together, or it's only a block" clear from the green and the motif?
- The split field: does the one at the pommel (a jab, then the crack) have enough to do, and is going
  over to the partner (over him, or under his stomp leap) a choice you make?
- The crack: does it read as glass breaking, and can you jump it (F2 speed)?
- The stomp leap: do you see where the blade will come down in time to go under him?
- His posture breaks about once a chain when you play well: too often, now that the rage will be a
  whole chain (step 2)?
- The jab's yellow is very short (a beat after a blade strike): enough to read?
