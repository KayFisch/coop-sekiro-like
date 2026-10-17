# Beat-Runner (prototype, between the bosses)

A first answer to "what is between the bosses?" (`TASKS.md`), after Nicho's idea of 2026-10-17
and the scribbles of 2026-10-02 ("Was ist der Rest des Spiels?") and 2026-10-15 ("Beat-Dash-Level
gespiegelt"). A warm-up that plays like the boss fight without a boss: the same answers (parry,
hit, the partner's hit after your parry, parrying together), on the same tempo.

Code: `levels/runner/` (`runner.gd`, `runner.tscn`). Select screen: entry 6. Branch
`nicho/beat-runner` (it needs the mirrored screen from `nicho/pep-test`).

## What it is

- **The screen is split as in the mirrored boss fight** (`ui/mirror_view.gd`, always on here):
  P1 in light above the floor line, P2 in shadow in the reflection below.
- **Nobody walks.** Both run on the spot (the stick does nothing, `Player.running_on`), facing
  right; the world goes by (posts scrolling left). Jump, parry, block and the sword work as ever.
- **Things come at them on a beat**, each for one of them and seen only in their own half:
  - **a yellow orb: parry it.** Blocked, it costs a little; taken, more.
  - **a violet shard: hit it** before it reaches you; it splits. A hit on its beat (within
    0.07 s) is worth more.
  - **green orbs, one for each of you at once: parry together.** Both parried: a bonus.
  - **a grey block on the floor**, now and then: jump it.
- **The relay** (switch, on): a parried orb goes on to the partner. It arcs out of your half and
  comes down at them as a violet shard, 2 units (0.4 s) later: the boss fight's "your parry,
  their hit" as something you can see travel. It's only sent when the partner has room to hit
  it (nothing of theirs to parry or jump right after), and missing it only costs a little.
- **What comes when:** Columna Bifrons's own patterns (`ColumnaBifrons.ATTACKS`, by their
  weight in pep): each strike an orb for that sword's player, at his tempo (a unit is 0.2 s);
  both swords at once are a green pair; the crossing's push is a block. Mirrored at random.
  With "mixed", between two patterns now and then a lone shard or a block.
- **The sync meter is the run's life** (of 100, starting at 50): parries and hits fill it,
  what gets through empties it. Empty: the run is over (R runs again). A combo counts the
  answers in a row.

## Switches (F1, "Runner: ...")

| Switch | Default | What |
|---|---|---|
| `runner_patterns` | mixed | "bifrons": his patterns only; "mixed": shards and blocks between them |
| `runner_relay` | on | a parried orb goes on to the partner as a shard |
| `runner_rally` | off | ...and hitting that shard sends an orb back to the parrier (up to 4 times) |
| `runner_blocks` | on | blocks to jump between patterns |
| `runner_speedup` | off | the tempo rises as the run goes on (5 % every 20 s) |
| `runner_metronome` | off | a tick every 4 units |
| `runner_endless` | off | an empty meter doesn't end the run (practice) |

## Numbers (F2, the runner's page)

Tempo (seconds per unit, units between patterns, the relay's delay, the speed-up), speeds
(orbs 420 px/s, shards 650, the world 300), the meter (what each answer gains or costs), and how
often something comes between two patterns. F2 in this level shows only these.

## To find out together

- Does it feel like the boss fight (same rhythm, same answers), or like a different game?
- Is the relay readable: does the partner see their shard coming from your parry?
- Split screen: can each of you read your own half fast enough, and do you still play together?
- Bifrons's patterns are dense: in quick alternation (3 units) the partner has no room for a
  relayed shard, so relays come mostly at a pattern's end. Patterns written for the runner
  would place them on purpose.
- What else fits (ideas, not built): switching halves (from the beat-dash scribble), both on one
  half for a stretch (ppe), a heavy thing that needs both, the meter carried into the boss fight
  (capped), Kay's rhythmic obstacles (`scribbles.md`, 2026-10-15).
