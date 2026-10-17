# Beat-Ring (prototype 2, between the bosses)

Nicho's second idea for between the bosses (2026-10-17), after the beat-runner
(`docs/beat_runner.md`) felt "meh" in principle. The runner is left as it was; this is a level
of its own: `levels/ring/` (`ring.gd`, `ring.tscn`), entry 7 on the select screen, branch
`nicho/beat-runner`.

## What it is

- **Bifrons's room without him, split as in the mirrored boss fight** (always on): P1 in light
  above the floor line, P2 in shadow in the reflection below. **The players move freely**: walk,
  jump, dash, as in a fight.
- **A circle around the middle of the floor line**, only to look at (the floor halves it, the
  mirror makes it whole). It lights up on every beat (0.6 s). Where a thing meets it is where,
  and when, it's best answered: its beat. A second before, each thing marks that spot.
- **Things come level from the left and the right, at chest height**, each for one player and
  seen only in their half:
  - **a yellow arrowhead: parry it** when it's at your guard (within 46 px of you);
  - **a violet shard: hit it** with the sword; the line across it is where it's cut;
  - **green arrowheads, one each at once: parry together.**
- **The sweep, rarely: a green arrow** comes slanting down at one player, goes on through the
  middle into the other's half and rises to meet the circle on its other side, at chest height
  again: it reaches one of you and then the other, as Bifrons's sweep does. Each parries it as it
  reaches them (it flies on either way); both parried is a bonus. It's the only thing that goes
  through the line; one that comes from the middle is met from outside the circle.
- **On the circle (its beat, ±0.07 s) is "perfect", near it (±0.16 s) "good"**; taken anywhere
  else it still counts a little. A level thing nobody takes flies across the circle and out:
  lost. One that reaches you unanswered hits you, wherever you stand on its way.
- **Bars from the sides**, rarely (3 % a beat) and slowly (300 px/s), along the floor: a low one
  to jump, a high one (60 px up) not to jump into.
- **The sync meter is the run's life** (of 100, from 50). Empty: the run is over (R runs again);
  the end shows the best combo, the perfect answers and the sweeps parried by both.
- **Testing alone:** the stand-in switch (F1, as in the other levels: "left" plays P1, "right"
  P2) walks to just past where its next thing meets the circle, the way the thing flies, and
  parries or hits it on the beat, 85 % of the time; jumps low bars and stays down under high
  ones.

Switches (F1, "Ring: ..."): sweeps, green pairs, bars, endless. Numbers (F2, the ring's page):
the beat, how often things come and which, the circle's radius, speeds (arrowheads and shards
380 px/s, the sweep 520, bars 300), the perfect and good windows, and the meter.

## Colors

Green is "it takes both of you": a pair at once, or the sweep one after the other (Bifrons's
sweep itself had no color of its own: it came yellow, like any single strike). The shapes tell
the two apart: arrowheads for the pair, a long arrow for the sweep.

## Round 2 (Nicho, 2026-10-17, after trying round 1)

Round 1 was "far too chaotic": things came from any angle, and any one nobody took went through
the line to the partner, catchable only perfectly. Now: level from the sides by default; from
another angle only as something special that needs more reaction (for now just the sweep); going
through the line only for the sweep, with the normal windows; bars rarer and slower; parry orbs
are arrowheads, shards show their cut.

## Assessment (Claude, round 1)

What speaks for it:
- **Movement is back.** In the runner the players only pressed buttons on the spot; here they
  position themselves, as in the boss fight, and "be there on the beat" is the task: where and
  when, like Beat Saber.
- **It's closer to the boss fight**: the same answers (parry, hit, parry together), the same
  moving body, and a reason to jump and to stay down.
- **The mirror line means something** when a thing goes through it (now the sweep).

What to watch:
- **Reading**: still two directions and your own movement; the marks on the circle help.
- **Camping**: with things only from the sides, players may stand at the circle's foot and wait.
  The specials (the sweep, more to come) and the bars are what work against that.
- **It may stand next to the boss fight rather than lead into it**: a rhythm arena of its own.
  Whether that's good is the question for the playtest.
