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
  and when, it's best answered: its beat.
- **Things come from anywhere above the floor at the middle**, each for one player and seen only
  in their half; a second before its beat each marks where it'll meet the circle:
  - **a yellow orb: parry it** when it's at your guard (within 46 px of you);
  - **a violet shard: hit it** with the sword;
  - **green orbs, one each at once: parry together.**
- **On the circle (its beat, ±0.07 s) is "perfect", near it (±0.16 s) "good"**; taken anywhere
  else it still counts a little. So the players run to where things will meet the circle, jump
  for the ones that meet it high up, and can also go out and catch one early.
- **Through the line** (switch, on): a thing nobody took flies through the middle into the
  partner's half and meets the circle once more on its way out. The partner can still take it
  there, but only perfectly on that beat ("CAUGHT!", worth the most). There it can't hurt anyone.
- **Bars from the sides**, now and then, along the floor: a low one to jump, a high one (60 px up)
  not to jump into.
- **The sync meter is the run's life** (of 100, from 50). Empty: the run is over (R runs again);
  the end shows the best combo, the perfect answers and the catches through the line.
- **Testing alone:** the stand-in switch (F1, as in the other levels: "left" plays P1, "right"
  P2) walks to where its next thing meets the circle, jumps to be at that height on its beat,
  parries or hits it, 85 % of the time; jumps low bars and stays down under high ones.

Switches (F1, "Ring: ..."): through the line, green pairs, bars, endless. Numbers (F2, the ring's
page): the beat, how often things come and which, the circle's radius, speeds, the perfect and
good windows, and the meter.

## Assessment (Claude, 2026-10-17)

What speaks for it:
- **Movement is back.** In the runner the players only pressed buttons on the spot; here they
  position themselves, as in the boss fight, and "be there on the beat" is the task: where and
  when, like Beat Saber.
- **It's closer to the boss fight**: the same answers (parry, hit, parry together), the same
  moving body, and a reason to jump and to stay down.
- **"Through the line" is real co-op**: your miss becomes your partner's harder chance. It can
  be used on purpose ("leave it, I'll take it"), and it makes the mirror line mean something.

What to watch:
- **Reading**: things from 180 degrees plus your own movement is a lot. The marks on the circle
  help; if it's still too much, narrow the angles (`ANGLES`) or lower the density.
- **High meeting points** need a jump timed to the beat: demanding. Shards can be hit with an
  upslash from below; orbs need you up there.
- **Camping**: the circle could make players stand at its foot and wait. Things from high up
  and the bars work against that.
- **"Perfect only" through the line** is strict (±0.07 s). That's the point, but tune it
  (`ring_perfect`) if catches never happen.
- **It may stand next to the boss fight rather than lead into it**: a rhythm arena of its own.
  Whether that's good is the question for the playtest.
