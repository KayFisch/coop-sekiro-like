# Beat-Ring (prototype 2, between the bosses)

Nicho's second idea for between the bosses (2026-10-17), after the beat-runner
(`docs/beat_runner.md`) felt "meh" in principle. The runner is left as it was; this is a level
of its own: `levels/ring/` (`ring.gd`, `ring.tscn`), entry 7 on the select screen, branch
`nicho/beat-runner`. Since round 4 it's **Columna Bifrons's fight without him**: his patterns,
his tempo, his sides, his partner's hit.

## What it is

- **His room, split as in the mirrored boss fight** (always on): P1 in light above the floor
  line, P2 in shadow in the reflection below. **The players move freely**: walk, jump, dash.
- **A circle around the middle of the floor line**, only to look at (the floor halves it, the
  mirror makes it whole). Where a thing meets it is where, and when, it's best answered: its
  beat. The circle lights up as something meets it; a second before, each thing marks its spot.
- **His patterns** (`ColumnaBifrons.ATTACKS`, chosen by his weights, at his tempo: a unit is
  0.2 s): each strike comes as a thing flying level at chest height at the player its sword
  fights, from that player's side of the circle, seen only in their half:
  - **a yellow arrowhead: parry it** when it's at your guard (within 46 px of you), or it hits
    you;
  - **his strikes with both swords: green arrowheads, one each at once: parry together.**
  - Between patterns, now and then **a grey shard: hit it** on your own (the line across it is
    where it's cut), or a bar.
- **The partner's hit after a parry: a violet shard** (switch, on). When you parry a yellow
  arrowhead, it comes up where your parry was and runs along the circle: over your half, through
  the line, and on along your partner's half, until it's hit or reaches the line again. It meets
  your partner's side of the circle **as long after your parry as a sync hit on the beat comes in
  the boss fight**: with Bifrons on "after" (`bifrons_window`), 0.24 s (his guard opens 0.18 s
  after the parry, and "on the beat" is the 0.12 s after that, `sync_beat_time`); it can be hit
  until his guard would close again (0.48 s). On "beat" it's 0.06 s: you hit with the parry.
  With the two on two sides that's half the circle (about 1800 px/s); on one side, the long way
  round (337 degrees, about 3400 px/s). It leaves a trail so it can be followed.
- **Sides, as with him: diagonal by default**, one of you on each side of the circle: P1's things
  come from P1's side, P2's from the other. Changing sides only comes with his moves for it:
  - **his crossing** (pep to ppe): a long green arrow, level, for one of you, then a heavy green
    pair (bigger, costs twice taken) for both, on the other one's side: the one the arrow was
    for has to get over (dash). From then on both stand on one side and everything comes from
    there.
  - **his leap** (ppe to pep), as **a sweep**: a green arrow slanting down at one of you, through
    the middle into the other's half and up to the circle's other side; the other has to get
    over there. His sweep (in pep) comes the same way and keeps you on two sides.
  Each parries a sweep as it reaches them (it flies on either way); only on its way down can it
  hit, not through the line (it would come from behind).
- **Shards never hit anyone**: they're targets, not attacks.
- **On the circle (its beat, ±0.07 s) is "perfect", near it (±0.16 s) "good"**; taken anywhere
  else it still counts a little. A level thing nobody takes flies across the circle and out:
  lost.
- **Bars**, rarely, slowly (300 px/s), along the floor: a low one to jump, a high one (60 px up)
  not to jump into.
- **The sync meter is the run's life** (of 100, from 50). Empty: the run is over (R runs again);
  the end shows the best combo, the perfect answers and the sync hits.
- **Testing alone:** the stand-in switch (F1, as in the other levels: "left" plays P1, "right"
  P2) goes to where its next thing meets the circle, or else to its side, and parries or hits on
  the beat, 85 % of the time; jumps low bars and stays down under high ones.

Switches (F1, "Ring: ..."): violet shards from parries, his side changes (crossing, sweep,
leap), his both-sword strikes as green pairs, bars, endless. Numbers (F2, the ring's page): his
tempo and the gap between patterns, how often a grey shard or a bar comes between them, the
circle's radius, speeds, the perfect and good windows, the meter. The violet shard's timing comes
from Bifrons's own switches and numbers (`bifrons_window`, F2 `sync_beat_time`), so the two
fights keep the same rhythm. Bifrons's weights decide how often the crossing and the leap come
(as in his fight: a crossing in about one pattern of five).

## Colors

Green is "it takes both of you": a pair at once, the crossing's arrow and heavy pair, or the
sweep one after the other (Bifrons's sweep itself came yellow, like any single strike). Grey is
yours alone, violet is your partner's gift, yellow is yours to parry.

## Rounds

- **Round 4** (Nicho, 2026-10-17): violet shards appear where the parry was and visibly run
  along the circle (the long way when both are on one side, so faster), timed like the boss
  fight's partner hit. Things come as in the boss fight: diagonal by default, P1 on one side and
  P2 on the other; sides change only with his crossing (green arrow, then a heavy strike for
  both on one side) and back with his leap. Claude: the patterns are now his own (his table,
  his weights, his tempo).
- **Round 3**: shards don't hit the player, the sweep can't once it's through the line. Shards
  are grey when they just come, violet when a partner's parry sends one.
- **Round 2**: round 1 was "far too chaotic" (things from any angle, any miss going through to
  the partner, catchable only perfectly). Now level from the sides; from another angle only the
  sweep; bars rarer and slower; arrowheads for parrying, shards with their cut.

## Assessment (Claude, round 1)

What speaks for it:
- **Movement is back.** In the runner the players only pressed buttons on the spot; here they
  position themselves, as in the boss fight, and "be there on the beat" is the task: where and
  when, like Beat Saber.
- **It's closer to the boss fight**: the same answers (parry, hit, parry together), the same
  moving body, and a reason to jump and to stay down.
- **The mirror line means something** when a thing goes through it (now the sweep and the
  violet shard).

What to watch:
- **Reading**: two directions and your own movement; the marks on the circle help.
- **Camping**: with things only from the sides, players may stand at the circle's foot and wait.
  The side changes and the bars are what work against that.
- **It may stand next to the boss fight rather than lead into it**: a rhythm arena of its own.
  Since round 4 it's the boss fight without the boss, which makes it a warm-up for him: whether
  it feels like that is the question for the playtest.
