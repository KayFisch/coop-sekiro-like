# The Heavy Hitter, the Ettin (working title)

Status: designed (v0, 2026-10-19), to be built next. Name and myth open (Kay's list of two-headed
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
- Where the stomp leap takes him, and which way he faces as he lands.
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
