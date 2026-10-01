# Columna Bifrons, in "The Threshold" (test boss)

A small boss built to answer one question, not a finished fight: **does fighting from both
sides at once feel like co-op?** It comes out of the scribbles of 2026-09-30 / 10-01
(`scribbles.md`: player - boss - player, a two-sided boss). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `attacks/strike_pattern.gd`),
`levels/threshold/`. Select screen: entry 5.

---

## What it tests

In the two fights so far both players usually stand on the same side of the boss. Here they
stand on opposite sides, and each one's parry is what lets the *other* one hit:

1. **He's guarded on both sides.** A sword hit bounces off (dull clang, grey sparks, you're
   pushed back a little). The plate down each flank is the guard.
2. **He strikes left, right, or both**, on a beat. Whoever stands under the falling blade has
   to perfect parry it (the usual parry: block pressed at most 0.133 s before it lands).
3. **A parried strike breaks his guard on the other side** for a moment: the plate is gone,
   that half of him flashes, his sword there is knocked aside. The partner's hit there is a
   **sync hit** (2.5x damage, sync). So one player parries while the other hits, on the same
   strike, and the roles swap whenever he strikes the other side.
4. **Both blades parried at once stagger him** (2.2 s): open on both sides, hit freely.

Nothing else hurts him. Standing on the same side doesn't work: the side that opens is the one
nobody is on. His body blocks the way across (Moves "boss_body"), as Cubus's does.

## Reading him

- **Blade up over his head, yellow, that half of him tinted yellow:** this side is struck next.
  It's drawn further back and trembles as the drop gets close.
- **Blade turns red and drops** (0.28 s, with a whoosh): the cue. It lands when it's down at
  head height; both players time their press to that moment, the one under it with block, the
  other with attack.
- **Both blades up, crossed:** both sides at once; both parry.
- **A flank flashing pale yellow, no plate:** hit here, now.
- **Blades lying on the floor, body flashing grey:** staggered.

## The partner's hit: on the beat, or after it

Moves "bifrons_window" (F1):

- **beat** (default, "mode 1, no delay"): parry and hit are pressed together. A hit that
  lands up to 0.133 s *before* the strike is held and counts if the strike is then parried; after
  the parry the guard stays broken for 0.2 s. In practice the attack press has to come between
  about 0.14 s before and 0.15 s after the strike lands.
- **after**: the guard stays broken for 0.5 s, long enough to answer the parry (call and
  response). With strikes 0.8 s apart this is tight; it wants patterns with longer gaps.

**Mashing doesn't work:** a hit that bounces keeps that player's hits bouncing for 0.45 s, even
through a broken guard. One timed press gets through; a stream of presses never does.

Moves "bifrons_guard" off removes the guard: every hit does its normal damage and a hit in the
window is still a sync hit. That's the lenient variant, for comparison (mashing wins it).

## Patterns

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
random while they're even. So over a fight both players parry and hit about equally often, and
what's learned is the pattern's shape (A A B), not "right right left". `MIRROR_PATTERNS = false`
turns that off. SINGLE and TRIPLE may come twice in a row, the long ones not.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | `StrikePattern.FALL_TIME` | 0.28 s |
| How the drop accelerates | `StrikePattern.FALL_POWER` | 1.7 |
| Hit window before / after the strike | `HIT_EARLY`, `BREAK_TIME` | 0.133 / 0.2 s |
| Anti-mash lock | `ColumnaBifrons.HIT_SPAM_LOCK` | 0.45 s |
| Sync hit damage | `ColumnaBifrons.SYNC_HIT_FACTOR` | x2.5 |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME` | 2.2 s |
| Damage to players (hit / blocked) | `STRIKE_DAMAGE`, `BLOCKED_DAMAGE` | 12 / 4 |
| His health | `ColumnaBifrons.MAX_HP` | 1600 |
| Sync gained (parry / sync hit / both parried) | `GameManager.SYNC_GAINS` | 3 / 6 / 25 |

For testing: `TEST_ONLY_PATTERN` (one pattern only) and `TEST_PARRY_SIDE` (every strike on that
side counts as parried, so one person alone can practice the hits from the other side).

## What to look for in the playtest

- Does "you parry, I hit, on the same strike" feel like one action done together, or like two
  people each doing their own thing next to a metronome?
- Is the hitter's job too easy (just press on the beat) next to the parrier's (get hit if you miss)?
  If so: should a bounced hit cost more?
- **beat** or **after**: which reads as co-op? Is 0.8 s between strikes the right tempo?
- Is the drop readable from the *other* side, i.e. can the hitter time off a blade that isn't
  aimed at them?
- The long pattern: a duet, or just long?

## Not in here yet (from the scribbles)

- The heavy strike on one side that takes both players, and joining up / "together mode".
- Blocking (not parrying) holding his sword for a moment, so the partner can cross over.
- Sync as the thing that lets the two stay joined; the finisher at full sync.
- Any theme: two-sided beings, one-armed players, yin and yang.
