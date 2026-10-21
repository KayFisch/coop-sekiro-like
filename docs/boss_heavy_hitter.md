# The Heavy Hitter, the Ettin (working title)

Status: designed (v0, 2026-10-19); phase 1 built (2026-10-20, branch `nicho/heavy-hitter`: see
"Built (phase 1)" at the end), reworked after Nicho's first test (2026-10-21: "First test"); the rage
and phase 2 built (Kay, 2026-10-21: "Built (rage and phase 2)"), waiting for the two of us to test it
together. Name and myth open (Kay's list of two-headed
creatures; the working idea is the Ettin, a two-headed giant). General rules: `docs/concept.md`
("Boss design principles", "Blade rules"). The why, and what was dropped: `scribbles.md`,
2026-10-19 ("Heavy Hitter, der Ettin").

## Identity

Two heads, one weapon. Slower than the Warden, heavy, and only interested in landing his blows:
he attacks **whatever is in front of his nose**, and his two heads **quarrel over who gets the
blade**. The reverse of the Warden: **open while he attacks**, guarded only in his breath.
Signature: **he forces movement**; how the formation changes is up to the players.

## The weapon in two layers

One weapon, held level, a **halberd** (or a mace: not a plain sword): a **blade** (an axe head; heavy,
slow) at one end, a **pommel** (an iron butt; normal, fast) at the other. On the mirrored screen the light half shows P1's layer and the shadow half P2's, and **the
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
- **split** (one at the blade, one at the pommel): each head goes for its own player, by turns: the
  blade at the one, the pommel at the other, **normal strikes**, each parried alone, and each parry
  opens the partner's window. The white weapon and the black one do different things: one strikes
  with the blade while the other holds, then jabs while the first holds. Going over to the partner
  (over the weapon, or under his stomp leap) makes it together; provoking the pommel side (phase 2)
  too.
- **both at the pommel:** jabs at both; he turns round in his next breath.

He turns the alignment (the heads' quarrel), the players turn the formation (moving) or provoke.
This table is the basis for building his patterns and for reading the fight.

## The rules (v0)

1. **Each head goes for its own player** (Nicho, 2026-10-21). Both at the blade: the heads put
   their strength into **one hit**, in both layers at once, and each layer's blade is parried by
   that layer's player. Both parry: a **co-op parry** (both get a sync-hit window, and it counts
   twice toward the stagger). Only one parries: the parry only has the **effect of a block** (one
   parry per blade). One at the blade and one at the pommel: the blade at the one, the pommel at the
   other, by turns, each a **normal strike** in its own layer only: a lone parry is a parry.
   (Phase 2: once the heads have torn the weapon apart, each can put its blade at its own player.)
2. **The crack:** a blade that nothing stopped goes into the floor, the mirror line, and the mirror
   **breaks through into the other half** there, as a phone's screen cracks from the corner it fell
   on: still, not running anywhere, in the color of the half it comes from (the light half's dark
   into the pale shadow, the shadow's pale into the dark light). As it breaks open it hurts the
   other half's player if they're on the floor near it: jump it. **Stopped** is parried, or blocked
   while the other layer's blade was parried (the parry holds it). So: parried together, or a parry
   and a block, nothing cracks; a parry and a hit, the hit one's side cracks into the parrier's
   half; no parry at all (blocked or hit), both sides crack.
3. **The pommel:** jabs at whoever stands in front of it, in their layer. Normal strikes: a lone
   parry is a parry (it opens the partner's window). The pommel side is **open and provokable** (see
   "Provoking").
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

- **Blade strike:** raised high over him, then down; red as it comes. In both layers (both at the
  blade): green while it's drawn, heavy, parry together. In one: yellow, yours alone.
- **Pommel jab:** a pull back, yellow (yours alone), red as it comes; fast.
- **Flip (the heads' quarrel):** the heads turn to each other; one grabs the blade, and the weapon
  swings 180° in **one** layer (the old sweep): parallel ↔ diagonal. Parriable where it reaches a
  player as it swings through. As his finale it turns together into split; provoked, it turns
  split into together (see "Provoking"). Phase 2.
- **Turn:** he turns right round (both layers), so that the blade is in front of the players. Only
  in his breath, never in rage.
- **Stomp leap:** he crouches, jumps, and lands as a blade strike (as any, the crack too).
  While he's in the air the players can pass under him to switch sides.
- (Maybe later: a **charge**, the weapon held level across the room; jump over it.)

Tempo: half the Warden's, counted in beats of `Beat` (150 BPM: a beat is 0.4 s).

## Motifs (chosen by what's in front of his nose, never by chance)

- **together** (both at the blade): blade (2 beats) – blade (2) – blade (3, held longer). All
  parried together: simultaneous sync hits.
- **split** (one at the blade, one at the pommel): the seesaw, blade (2) – pommel (1) – blade (2)
  – pommel (1).
- (Both at the pommel: jabs only, two beats apart, then the turn in his next breath.)

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
- **Every blade strike in rage comes down in both layers and heavy** (both heads put their rage into
  every strike; he doesn't go by where the players are), so a lone parry has a block's effect, and
  where nothing stopped a blade the mirror cracks into the other half (rules 1 and 2). Between two
  strikes the weapon goes over him to the other side in both layers. (Set after the rework of
  2026-10-21, by Claude in the handover, to be checked in the joint test.)
- **Two patterns:**

  | Pattern | ppe (both on one side) | pep (one each side) |
  |---|---|---|
  | **Pendulum** (parallel: the same in both halves; the blade left, right, left...) | On your side: parry together. On the other side: both blades into nothing, the cracks break through on the empty side (harmless). **Easy.** | The one on the struck side parries alone (a block's effect); the partner's blade goes into nothing and breaks through right under them: jump after the parry. The next one: the other way round. **Hard.** |
  | **Cross** (diagonal: across; swapping each strike) | By turns one parries alone (a block's effect); the other blade breaks through on the empty side (harmless). No sync, hardly any stagger. **Hard.** | Both at the blade: parry together. Then both blades into nothing: each breaks through under the partner, both jump. **Easy.** |
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

## Built (phase 1, 2026-10-20; reworked 2026-10-21)

Branch `nicho/heavy-hitter`. Code: `actors/bosses/heavy_hitter/`: `hitter_weapon.gd` (the weapon in
two layers, his heads, his guard, the windows), `heavy_hitter.gd` (the boss: the fields, his chains,
his breath, the strikes landing, the sync rules' hooks, where he stands), `attacks/swings.gd` (a chain
and its verbs), `attacks/turn.gd`, `crack.gd`, `hitter_stand_in.gd`. His room:
`levels/heavy_hitter/hitter_room.tscn` (the Threshold's geometry), entry 2 on the select screen.
Tests: `tests/test_heavy_hitter.gd`. Phase 1 only, as built then: the weapon always parallel, no flip,
no provoking flips, no rage (a broken posture: a long stagger in its place). The rage and phase 2
came next: "Built (rage and phase 2)".

What's built, and how; where the design left it open, the choice made:

- **The weapon in two layers: a halberd.** An axe head with a spear point at the blade's end, an iron
  butt at the pommel's. In each layer it points left or right (P1's layer is the light half, P2's the
  shadow half), and each layer's weapon has a pose of its own: they move together for a strike of
  both heads, apart when each goes for its own player. Each half shows only its own; one-sided, both
  are drawn, a little apart. Two heads sit on top of him; in each layer a band across the head on
  the blade's side, in that player's color. A hit on his pommel side turns that head red a moment.
- **Its colors** say whom each end is aimed at, the same in both halves: the axe head in the color of
  the player at the blade (both there: half in each one's: parry together), the butt in the color of
  the player at the pommel, steel where nobody is. The telegraph (green, yellow, red) is on the axe's
  edge and the spear point, and on the butt's face for a jab.
- **In front of the blade** (or the pommel) is the side a player is on, in their own layer: that
  decides the field, and which layers a strike comes down in. Whether it reaches them is its reach:
  the blade 200 px from his center, the pommel 140. Someone on the blade's side but further off: the
  blade goes into the floor.
- **Each head for its own player, the crack, the pommel, open while he attacks:** as in "The rules
  (v0)". A blade strike comes down in the layers whose player is at the blade (nobody there: both,
  into nothing), a jab in those whose player is at the pommel.
- **The crack:** still, a starburst of cracks from where the blade went in, spreading in the other
  half over 0.3 s; as it breaks open, the other half's player on the floor within 70 px of it is hit
  (block doesn't help: jump it). It costs a normal hit (a third of his heavy hit's sync). With a
  sound of glass.
- **His guard:** between his chains, once the weapon is level again (the recovery after a chain
  included); not while he turns. It parries or blocks by chance, as Bifrons's (F2 sync page,
  "boss_parry_chance").
- **The motifs** (beats of 0.4 s): together = blade 2, blade 2, blade 3; split = blade 2, pommel 1,
  blade 2, pommel 1; both at the pommel = pommel 2, 2, 2. Chosen as a chain starts and as each
  repetition ends (1 to 3 of them, at random).
- **The finales:** in the together field the great hammer (a 4-beat windup); in it for 2 of his chains
  in a row, the stomp leap; split or both at the pommel, the stomp leap. Any finale parried together
  staggers him 0.5 s, and 0.2 s per blade parried in the chain (a co-op parry counts two, a lone
  parry of a normal strike one, a lone parry with a block's effect nothing).
- **The stomp leap: on the spot, turning round in the air** (Nicho: fine). He crouches (the weapon
  raised), jumps (his feet 110 px up, about 0.7 s in the air, his body no obstacle meanwhile), turns
  round on the way up (the raised blade shows the side it comes down on) and lands where he took off,
  as a blade strike on the side that was behind him. In the split field the one at his blade can go
  under him to the partner: together, and parried together, staggered; nobody moving: split again,
  the roles turned round. From the together field both have to go under him, or both are at his
  pommel. Both at the pommel: he lands facing them.
- **The breath** (2.5 to 3.5 s, after a 0.8 s recovery): he walks slowly (60 px/s) and, as it begins,
  turns round if that brings more of the players in front of the blade; with one on each side, to
  whoever hit his pommel side last since his last turn, else round anyway. A hit at his guard
  meanwhile is answered at once by the next chain; an attacker at his pommel gets a jab first.
- **His pommel side:** hits there (landed or guarded) and parried jabs cost him twice the posture.
- **His posture** is his own number (F2, 200 as Bifrons's). It breaks much more easily anyway, as his
  blade strikes together are heavy: a co-op parry costs him 2 x 15, its two sync hits 2 x 15, so a
  together repetition played cleanly costs him about 180 (one of Bifrons's about 60). Broken: a 3 s
  stagger for now, his sync stays. (Now the rage: "Built (rage and phase 2)".)
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
  strikes at it, jumps the mirror breaking open under it, strikes in its window, and plays the sync
  mode along.

His numbers on F2 (his own page, "Heavy Hitter"; it opens there in his room):

| What | F2 | Now |
|---|---|---|
| A beat of his / a blade's drop / a jab's thrust | "hitter_beat", "hitter_drop_time", "hitter_jab_time" | 0.4 / 0.3 / 0.18 s |
| After a chain, recovering / walking | "hitter_recover_time", "hitter_walk_speed" | 0.8 s / 60 px/s |
| Repetitions / together chains before the stomp leap | "hitter_reps_min", "_max" / "hitter_together_stale" | 1 - 3 / 2 |
| The breath | "hitter_breath_min", "_max" | 2.5 - 3.5 s |
| His posture / his pommel side | "hitter_posture_max", "hitter_pommel_posture" | 200 / x2 |
| A finale parried together: stagger / per blade | "hitter_stagger_least", "_per_parry" | 0.5 / 0.2 s |
| The crack: breaks open after / hits this near / its cost | "hitter_crack_delay", "_reach", "_share" | 0.3 s / 70 px / 0.33 of a heavy hit |
| The stand-in: parries / blocks | "hitter_stand_in_parry", "_block" | 0.75 / 0.15 |

In code, as structure: the halberd's shape, poses and colors and the reaches (`hitter_weapon.gd`),
the crack's look (`crack.gd`), the stomp leap's height and timing (`attacks/swings.gd`), the motifs
and finales (`MOTIFS`, `FINALES` in `heavy_hitter.gd`). His sync, the windows and what a hit costs
are the sync page's, shared with Bifrons.

### First test (Nicho, 2026-10-21) and what changed

- Parry together or it's a block: understandable. The stomp leap and the single pommel jab: fine.
- The weapon was a plain sword: now a halberd (a mace would do too).
- The crack looked like an electric shock running along the floor: now the mirror breaks through
  into the other half where the blade went in, still, in the color of the side it comes from; when
  it does, by the table in the rules, 2.
- The jab series (both at the pommel) was hard and weird to parry: two beats between the jabs now,
  so each is pulled back longer.
- Being at the pommel felt wrong, as the partner at the blade could only ever block: one each side,
  each head now goes for its own player (normal strikes, by turns), and only both at the blade makes
  one heavy hit.
- To see the difference: each end colored by whom it's aimed at (see "Its colors").

To look for in the next test:

- One each side: do the blade at one and the jab at the other read as two normal strikes, the white
  and the black weapon doing different things? Is the seesaw (blade, jab, blade, jab) good now?
- Do the colors of the ends (the axe in one color, or in both) tell you at a glance whether you parry
  alone or together?
- The crack: does it read as the mirror breaking, and is "your partner's miss cracks into your half"
  fair? Can you jump it in time (F2 "hitter_crack_delay")?
- The jab series with more room: better?
- His posture breaks about once a chain when you play the together field well: too often, now that
  the rage will be a whole chain (step 2)?

## Built (rage and phase 2, Kay, 2026-10-21)

Straight on `nicho/heavy-hitter` (Kay's call, not on a branch of its own). Code: `attacks/rage.gd`
(new: the rage), `attacks/swings.gd` (the flip; links that turn round before their windup, or come
down in both layers), `heavy_hitter.gd` (the rage starting, phase 2, provoking, the flip as his
finale, the last rage), `hitter_weapon.gd` (one layer turning, the sweep, the heads leaning),
`hitter_stand_in.gd` (re-forming). Shared, backwards compatible: `BaseBoss.holds_posture()` (false
by default), asked by `SyncRules` before a boss loses posture; the sound "roar"; an F1 tab "Hitter".
Tests: `tests/test_heavy_hitter.gd`.

What's built, and the choices made where the design left it open:

- **The rage starts at once** when his posture breaks, whatever he's doing (a chain broken off, a
  stagger cut short). The roar (F2 "hitter_roar_time", 1.6 s): both heads red, the weapon raised
  high and shaking, a red glow, a roar from two throats. He picks the pattern as it begins: apart
  (pep) the pendulum, together (ppe) the cross, and the weapon shows it at once: if it's in the other
  alignment, **the layer of the player nearer to him goes over** (up over him).
- **Then 6 strikes** (F2 "hitter_rage_strikes"), 3 of his beats apart (F2 "hitter_rage_beats"), the
  first 3 beats after the roar: each a blade strike in both layers, heavy (green as it's drawn, red as
  it comes), and between two the weapon goes up over him to the other side in both layers. He stands
  still: no walking, no turning. The table under "Rage" is what comes out.
- **Exhausted** after it: staggered 0.5 s plus 0.2 s per blade parried in it (the finale's numbers,
  "hitter_stagger_least" and "_per_parry"). Every strike is heavy, so only co-op parries count, two
  blades each.
- **His posture holds** from the break to the end of the exhaustion (it broke as the rage began, so
  it's full after it). His sync stays at the break; hits in the rage cost it as always. The alignment
  stays as the pattern left it.
- **While F5 holds his attacks** (`dev_hold`), a broken posture is only full again: no rage. The F5
  lab starts one: RAGE_PENDULUM, RAGE_CROSS, LAST_RAGE.
- **Phase 2 begins as his first rage does** (F1 "Hitter", "Start in phase 2": from the start). The
  fields follow the table under "The weapon in two layers", diagonal too once a rage or a flip has
  left it so; the motifs and rules are phase 1's.
- **The flip:** the heads lean toward each other, the one on the pommel's side of the flipping layer
  red (it grabs the blade), that layer's weapon held out level at chest height, yellow, shaking; then
  it sweeps flat through him to the other side (drawn turning in depth: shorter, through him, longer
  again on the other side; F2 "hitter_flip_time", 0.3 s), red. It meets that layer's player where the
  blade passes them, on either side within its reach (200 px): a normal strike (a lone parry is a
  parry, opens the partner's window, and counts one blade toward a finale's stagger), and no crack.
  The other layer's weapon holds.
- **The flip as his finale** (phase 2: the together field for "hitter_together_stale" of his chains,
  in the stomp leap's place) flips the **nearer player's layer** (together turns split, and that one
  has to go over to the partner), then a blade strike 5 beats on (F2 "hitter_flip_windup", 2.0 s).
  Re-formed and parried together: staggered as after the great hammer.
- **Provoking** (phase 2) is **only a hit that lands** on his pommel side: one his guard meets in his
  breath calls up his answer, as before, and provokes nothing. That head turns red at once and stays
  red. As the repetition under way ends, his chain flips that layer toward the hitter (2 beats), and
  only then decides: the next repetition (the new field's motif) or the finale. If the blade points
  at them by then anyway, it doesn't. A provocation waits past a chain's end for the next one; the
  rage forgets it, and none comes in the rage.
- **The last rage** (F1 "Hitter", off): once, in place of his next chain, when his sync has fallen
  below "hitter_last_rage_at" (0.25): the pattern that's hard for their formation, then the nearer
  one's layer over and the other pattern, then the great hammer in both layers; then exhausted.
- **The stand-in:** in the roar, if the pattern is the hard one for their formation, it goes over him
  to his other side (F2 "hitter_stand_in_reform": 0.7 of the time); the same after a flip that leaves
  it at his pommel (the flip finale's long windup). It jumps the rage's cracks as any.

New numbers on his F2 page (tab "rage"; the stand-in's in its tab):

| What | F2 | Now |
|---|---|---|
| The roar / strikes / beats between them | "hitter_roar_time", "hitter_rage_strikes", "hitter_rage_beats" | 1.6 s / 6 / 3 |
| The last rage: his sync below | "hitter_last_rage_at" | 0.25 |
| The flip's sweep / the flip finale's strike after it | "hitter_flip_time", "hitter_flip_windup" | 0.3 s / 5 beats |
| The stand-in re-forms | "hitter_stand_in_reform" | 0.7 |

Gone: "hitter_break_stagger" (the placeholder for the rage).

**How often the rage comes** (measured 2026-10-21: two stand-ins, one per player, everything at
its default, their sync held at half so the fight goes on): parrying 75 % of his strikes each, his
posture broke after one or two chains (2 rages in 55 s, about every 27 s); at 90 %, after about
every chain (4 rages in 77 s, about every 19 s, until his sync was gone). It nearly always broke in
the together field's second or third repetition, before its finale. A rage lasts about 9 s (the
roar and 6 strikes), so with good players about half the fight is rage. Not decided here (Nicho:
measure and say); the knobs are under "To look for". (With two stand-ins both re-forming in the roar
they often just swap sides, so the exhaustion measured, 0.5 to 1.7 s, says little.)

To look for in the joint test:

- Is the roar long enough to re-form, and do you see at a glance which pattern comes (the two halves
  the same, or across)?
- The hard ones, the pendulum apart (parry, then jump your partner's crack) and the cross together
  (no sync, hardly any stagger): too punishing, or right? Is "every rage strike heavy in both layers"
  (Claude's setting in the handover) the right reading?
- How often it comes (above): knobs "hitter_posture_max", "hitter_pommel_posture",
  "hitter_rage_strikes".
- The flip: does the sweep through him read, and is it fair to parry (the moment it passes you)? In
  the flip finale, is it right that the nearer one has to go over?
- Provoking: do you notice the head staying red, and the flip coming only as the repetition ends?
