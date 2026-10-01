# Columna Bifrons, in "The Threshold" (test boss)

A small boss built to answer questions, not a finished fight. The first one: **does fighting
from both sides at once feel like co-op?** The second, since the first playtest: **should a boss
react to being attacked, the way Genichiro does in Sekiro?** Both come out of `scribbles.md`
(2026-09-30 and 2026-10-01). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `attacks/strike_pattern.gd`),
`levels/threshold/`. Select screen: entry 5. Everything below that can be switched is on the F1
panel, under "Bifrons".

---

## The rules

The players stand on opposite sides of him, and each one's parry is what lets the *other* hit:

1. **He's guarded on both sides.** A sword hit on his guard is parried: it bounces off, and
   that player's hits can't get through for 0.45 s. The plate down each flank is the guard.
2. **He strikes left, right, or both**, on a beat. Whoever stands under the falling blade has
   to perfect parry it (block pressed at most 0.133 s before it lands). Just blocking takes the
   edge off the hit and opens nothing.
3. **A parried strike breaks his guard on the other side** for a moment: the plate is gone,
   that half of him flashes, his sword there is knocked aside. The partner's hit there is a
   **sync hit** (2.5x damage, sync). The roles swap whenever he strikes the other side.
4. **Both blades parried at once stagger him** (2.2 s): open on both sides, hit freely.

Standing on the same side doesn't work: the side that opens is the one nobody is on. His body
blocks the way across (Moves "boss_body"), as Cubus's does.

A swing commits (this is in `player.gd`, for every fight): from the attack press until the blade
is back, block does nothing. So nobody hits and parries at once, and a hit thrown at the wrong
moment costs the parry.

## Reading him

- **Blade up over his head, yellow, that half of him tinted yellow:** this side is struck next.
  It's drawn further back and trembles as the drop gets close.
- **Blade turns red and drops** (0.28 s, with a whoosh): the cue. It lands when it's down at
  head height.
- **Both blades up, crossed:** both sides at once; both parry.
- **A guard blade flashing white and flicking outward, orange sparks:** he parried your hit.
- **A guard blade knocked outward:** the strike on the other side was parried; this guard is
  about to break.
- **A flank flashing pale yellow, no plate:** hit here, now.
- **Blades lying on the floor, body flashing grey:** staggered.

## The partner's hit: on the beat, or after it ("bifrons_window")

- **beat** (default): parry and hit are pressed together. A hit that lands up to 0.133 s
  *before* the strike is held and counts if the strike is then parried; after the parry the guard
  stays broken for 0.2 s. So the attack press has to come between about 0.14 s before and 0.15 s
  after the strike lands. Nobody can know yet whether the partner will parry: it's a bet on them.
- **after**: the hit answers the parry. The guard breaks 0.15 s after the parry and stays
  broken for 0.45 s; nothing is held, so a hit pressed on the strike itself bounces (and then
  costs the window, see rule 1). The hitter has to *see* the parry first: the knocked-aside
  blade, then the flash.

**Mashing doesn't work** in either: one timed press gets through, a stream of presses never does.

## Two modes ("bifrons_mode")

### patterns (default)

He runs one pattern after another, a second or so apart. The players answer.

A pattern is a list of strikes, each `[wait, side]`. `wait` is the time until the strike lands,
counted from the pattern's start or the strike before, in units of 0.2 s
(`StrikePattern.TIME_UNIT`): a rough 1-10 scale, 4 = 0.8 s, a quick follow-up; 9 = 1.8 s, a long
windup. Below 3 a strike can't be read any more.

| Name | Strikes | Weight |
|---|---|---|
| SINGLE | 5 left | 1 |
| TRIPLE | 5 right, 4 right, 4 left | 3 |
| QUAD | 7 left, 4 left, 4 right, 4 both | 2 |
| LONG | 9 right, 4 right, 4 left, 4 right, 4 right, 4 left, 4 both | 1 |
| SWAP *(off)* | 5 left, 4 right | 0 |
| BOTH *(off)* | 6 both | 0 |

They live in `ColumnaBifrons.PATTERNS`; adding one is one line. Each is written once and also
runs **mirrored**: whichever way keeps the number of strikes even between the two sides, at
random while they're even. So both players parry and hit about equally often, and what's learned
is the pattern's shape (A A B), not "right right left". SINGLE and TRIPLE may come twice in a
row, the long ones not.

### reactive

After Genichiro: an exchange that either side can start.

- **He waits** between his series of strikes: 1.5 to 4 s (after the usual 0.6 s recovery)
  before he starts a pattern of his own. That's the room for the players to start something.
- **He parries** whatever they throw at his guard meanwhile, with the blade on that side.
- **He runs out of patience** after 1, 2 or 3 parried hits (usually 2, picked afresh after every
  series) and **answers**: with a quick **counter**, or one time in four with one of his patterns.
- A counter is aimed relative to the player who provoked it:

  | Counter | Strikes | Weight |
  |---|---|---|
  | CROSS | 4 other | 3 |
  | CROSS_BACK | 4 other, 4 same | 2 |
  | CROSS_BOTH | 4 other, 4 both | 1 |
  | RIPOSTE | 3 same | 2 |
  | RIPOSTE_CROSS | 3 same, 4 other | 1 |

  "Other" is the provoker's partner. So mostly: *you* strike him, he strikes *your partner*,
  they parry, and the guard that breaks is on *your* side. Provoking is a way to set up your own
  sync hit, on your partner's parry. (`ColumnaBifrons.COUNTERS`)
- **A committed blade can't parry.** From 0.45 s before a strike lands, the plate on that side
  is gone and one sword hit there lands (plain damage, no bonus). But the swing leaves hardly
  any time to parry the strike: it's a trade, his health against yours, and he has more.

Everything else is as in "patterns": the windows, the stagger, the patterns themselves.

## Testing alone ("bifrons_stand_in")

A stand-in on the left or the right: strikes on that side count as parried, three times in four
(`STAND_IN_PARRY_CHANCE`; nobody on that side is hurt). When it parries there's a clang and
sparks there. So one person, on the other side, gets to practice both parts, and has to watch
whether the parry really came before hitting. The stand-in never attacks.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | `StrikePattern.FALL_TIME` | 0.28 s |
| How the drop accelerates | `StrikePattern.FALL_POWER` | 1.7 |
| Hit window, "beat": before / after the strike | `HIT_EARLY`, `BREAK_TIME` | 0.133 / 0.2 s |
| Hit window, "after": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0.15 / 0.45 s |
| Anti-mash lock | `ColumnaBifrons.HIT_SPAM_LOCK` | 0.45 s |
| Sync hit damage | `ColumnaBifrons.SYNC_HIT_FACTOR` | x2.5 |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME` | 2.2 s |
| Damage to players (hit / blocked) | `STRIKE_DAMAGE`, `BLOCKED_DAMAGE` | 12 / 4 |
| His health | `ColumnaBifrons.MAX_HP` | 1600 |
| Reactive: his wait | `REACTIVE_WAIT_MIN`, `_MAX` | 1.5 - 4 s |
| Reactive: parried hits before he answers | `PATIENCE` | 1, 2, 2 or 3 |
| Reactive: a pattern instead of a counter | `PATTERN_ANSWER_CHANCE` | 0.25 |
| Reactive: how long a blade is committed | `StrikePattern.COMMIT_TIME` | 0.45 s (0: never open) |
| Sync gained (parry / sync hit / both parried) | `GameManager.SYNC_GAINS` | 3 / 6 / 25 |

For testing: `TEST_ONLY_PATTERN` (one pattern only).

## What to look for in the playtest

- Does "you parry, I hit" feel like one action done together, or like two people each doing
  their own thing next to a metronome? **beat** (a bet on the partner) or **after** (watching the
  partner): which reads as co-op?
- Reactive: does provoking feel like leading the fight? Is "I strike, *you* get attacked" a
  good thing between two players, or an annoying one? Does he still feel like one opponent when
  each side can start something on its own?
- Is the trade on a committed blade worth having, or does it just pull players away from the
  parry?
- Is the drop readable from the *other* side? Is 0.8 s between strikes the right tempo?

## Not in here yet (from the scribbles)

- Special moves: a sweep from one player through to the other; a heavy strike on one side that
  takes both players; joining up ("together mode").
- Blocking (not parrying) holding his sword for a moment, so the partner can cross over.
- Sync that drains over time and when a moment for both is missed; the finisher at full sync.
- Any theme: two-sided beings, one-armed players, yin and yang.
