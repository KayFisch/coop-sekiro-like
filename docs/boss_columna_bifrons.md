# Columna Bifrons, in "The Threshold" (test boss)

A small boss built to answer questions, not a finished fight:

1. **Does fighting from both sides at once feel like co-op?**
2. **Should a boss react to being attacked**, the way Genichiro does in Sekiro?
3. **Can one small set of rules cover every blade**, the players' and the bosses' alike?

All three come out of `scribbles.md` (2026-09-30 and 2026-10-01). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `attacks/strike_pattern.gd`, `attacks/sweep.gd`),
`levels/threshold/`; the players' half of the rules is in `actors/player/player.gd` ("THE
SWORD"). Select screen: entry 5. Everything below that can be switched is on the F1 panel, under
"Bifrons".

---

## The rules

The players stand on opposite sides of him, and each one's parry is what lets the *other* hit.
There are five rules, and they're the same for his blades and the players':

1. **A blade guards or swings, never both.** While his blade on a side stands at its flank it
   parries every sword hit on that side. While it's up for a strike, dropping, lying where it
   landed, thrown back, or away on the other side, there's nothing to parry with: hits on that
   side land (plain damage), as many as fit. The plate down each flank shows the guard.
   For a player it's the same: from the attack press until the blade is back at rest, block does
   nothing and nothing can be parried.
2. **A strike has to be perfect parried** by whoever stands under it (block pressed at most
   0.133 s before it lands). Just blocking softens the hit and opens nothing.
3. **A parried swing recoils.** The blade that was parried is knocked back and takes longer to
   come back: a player's 0.5 s (instead of the 0.28 s a swing has left once it has hit), his
   0.35 s before it moves again (instead of 0.12 s).
4. **A parried strike breaks his guard on the other side** for a moment: the plate is gone, that
   half of him flashes, his sword there is knocked aside. The partner's hit there is a **sync
   hit** (2.5x damage, sync). The roles swap whenever he strikes the other side.
5. **Both blades parried at once stagger him** (2.2 s): no guard on either side.

Standing on the same side doesn't work: the side that opens is the one nobody is on. His body
blocks the way across (Moves "boss_body"), as Cubus's does.

There's nothing else: no cap on hits, no lock against mashing. What used to be extra rules now
follows from these five:

- **Hitting his windup.** The player about to be struck can cut at the raised blade's side
  (rule 1), as often as fits, but a swing takes 0.45 s and has to be over before the parry.
  Greed isn't forbidden, it gets hit.
- **After your own parry** his blade on your side is thrown back (rule 3): for about 0.45 s
  your own side is open too. One swing fits, if it's started at once.
- **Mashing at his guard.** Every swing is parried and costs 0.67 s (0.17 s until it lands,
  0.5 s recoil), with no block meanwhile.

## The players' sword

Changed for this boss, in `player.gd`, so it holds in every fight (and needs Kay's yes):

- **Rest:** held diagonally, up and forward. **Block:** diagonally down in front. Letting go
  swings it back up; a perfect parry beats it up past its rest. That upswing *is* the parry.
- **The slash is a real swing:** drawn back (0.1 s), cut down (0.15 s; it reaches him about
  0.17 s after the press), brought back (0.2 s). 0.45 s in all, and until the blade is back
  nothing else goes: no block, no parry, no second swing. No cooldown beyond that.
- **Parried, it's knocked back** over the shoulder: 0.5 s until it's at rest again.
- The upslash dips for 0.05 s first, from the new rest pose; the downslash and the dash-slash
  are as they were.

## Reading him

- **Blade up over his head, yellow, that half of him tinted yellow:** this side is struck next.
  It's drawn further back and trembles as the drop gets close.
- **Blade turns red and drops** (0.28 s, with a whoosh): the cue. It lands when it's down at
  head height.
- **Both blades up, crossed:** both sides at once; both parry.
- **Blade held out to the side, low, drawn back:** the sweep (below). It comes down level and
  goes through to the other side.
- **A guard blade flashing white and flicking outward, orange sparks:** he parried your hit.
- **A flank flashing pale yellow, no plate, its blade knocked outward:** hit here, now.
- **A blade planted out to the side, his shoulder on it:** he's propping himself up. No guard
  there.
- **A dark blade lying on the far side:** knocked off its course. No sword on the side it
  came from.
- **Blades lying on the floor, body flashing grey:** staggered.
- **His body warming to rust (reactive mode):** his patience is running out.

## The partner's hit: on the beat, or after it ("bifrons_window")

When the guard breaks (rule 4) is the open question, so it's a switch. A swing lands 0.17 s
after its press, so the press has to come that much before the window:

- **beat** (default): the guard breaks with the parry, for 0.25 s. The attack press has to come
  between 0.17 s before the strike lands and 0.08 s after: together with the partner's block
  press. Nobody can know yet whether the parry will come, it's a bet on the partner; lost, the
  swing is parried and recoils.
- **after**: the guard breaks 0.3 s after the parry, for 0.35 s. The press has to come 0.13 to
  0.48 s after the strike landed: the hitter has to see or hear the parry first. A swing started
  with the strike is parried, and its recoil outlasts the window.

Mashing gets through by luck now and then, since nothing forbids it. Measured with bots that
mash attack and stop only to parry the strikes on their own side: about 1 sync hit in 10 strikes
on "beat", about 1 in 3 on "after" (the longer window). A timed press gets all of them.

## The sweep

One blade, held out to its side and drawn back (yellow, 0.9 s), comes down level (red, 0.28 s)
and sweeps through to the other side: it reaches the player on its own side first and the one
on the far side 0.4 s later. Each has to perfect parry it as it reaches them. A sweep breaks no
guard (rule 4 is for strikes); what a parry wins is where his swords end up, by rule 1:

| Parried by | What it leaves him with |
|---|---|
| nobody | The blade swings back at once (0.3 s). Guarded on both sides again. |
| the first player only | Knocked off its course, the blade ends up lying on the far side for 1.4 s: **no sword on the side it came from**. His other sword still guards its own side. |
| the second player only | Stopped dead, he has to **prop himself up on his other sword** for 1.4 s, and it guards nothing meanwhile. The swept blade swings back and guards its own side. |
| both | Both at once: the blade lies where it was stopped and he leans on the other. No guard on either side: **staggered**, 2.2 s. |

It comes among the patterns (weight 1.5) and from either side, like them.

## Two modes ("bifrons_mode")

### patterns (default)

He runs one attack after another, a second or so apart. The players answer.

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
| SWEEP | the sweep, above | 1.5 |
| SWAP *(off)* | 5 left, 4 right | 0 |
| BOTH *(off)* | 6 both | 0 |

They live in `ColumnaBifrons.PATTERNS`; adding one is one line. Each is written once and also
runs **mirrored**: whichever way keeps the number of strikes even between the two sides, at
random while they're even. So both players parry and hit about equally often, and what's learned
is the pattern's shape (A A B), not "right right left". SINGLE and TRIPLE may come twice in a
row, the long ones not.

### reactive

After Genichiro: an exchange that either side can start.

- **He waits** between his attacks: 1.5 to 4 s (after the usual 0.6 s recovery) before he
  starts one of his own. That's the room for the players to start something.
- **He parries** whatever hits his guard (rule 1), and every hit he parries, at any time, wears
  on his **patience**: 1, 2 or 3 hits (usually 2, picked afresh with every attack). His body
  warms as it runs out.
- Once it's gone and he's free, **he strikes back at the player who attacked him** (the one
  whose hit he parried last): with a quick counter, or one time in four with a whole pattern or
  the sweep, starting on that player's side.

  | Counter | Strikes | Weight |
  |---|---|---|
  | RIPOSTE | 4 same | 3 |
  | RIPOSTE_TWICE | 4 same, 4 same | 1 |
  | RIPOSTE_CROSS | 4 same, 4 other | only when both attacked him |

  "Same" is the attacker's side, "other" their partner's (`ColumnaBifrons.COUNTERS`).
- **If both players attacked him**, he answers the last one first and then the other
  (RIPOSTE_CROSS), never both at once: two players can't call up a strike on both sides, and
  with it the stagger, by mashing.

So attacking him means being attacked, and that's the opening: you parry his answer, your
partner hits. Provoking is how a pair starts an exchange on its own beat. And greed is a trade:
a swing into the blade he's raising against you lands (rule 1), but it isn't over when the blade
comes down.

Everything else is as in "patterns": the windows, the stagger, the patterns themselves.

## Testing alone ("bifrons_stand_in")

A stand-in on the left or the right: blades landing on that side count as parried, three times
in four (`STAND_IN_PARRY_CHANCE`; nobody on that side is hurt). When it parries there's a clang
and sparks there. So one person, on the other side, gets to practice both parts, and has to
watch whether the parry really came before hitting. The stand-in never attacks.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | `StrikePattern.FALL_TIME` | 0.28 s |
| How the drop accelerates | `StrikePattern.FALL_POWER` | 1.7 |
| His blade after a strike: lying / thrown back by a parry | `STICK_TIME`, `RECOIL_TIME` | 0.12 / 0.35 s |
| Hit window, "beat": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0 / 0.25 s |
| Hit window, "after": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0.3 / 0.35 s |
| Sync hit damage | `ColumnaBifrons.SYNC_HIT_FACTOR` | x2.5 |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME`, `Sweep.STAGGER_TIME` | 2.2 s |
| Sweep: until it reaches the first player / on to the second | `Sweep.WINDUP_UNITS`, `TRAVEL_TIME` | 6 (1.2 s) / 0.4 s |
| Sweep: blade away / propped / swinging back | `Sweep.AWAY_TIME`, `PROP_TIME`, `RETURN_TIME` | 1.4 / 1.4 / 0.3 s |
| Damage to players (hit / blocked) | `BLADE_DAMAGE`, `BLOCKED_DAMAGE` | 12 / 4 |
| His health | `ColumnaBifrons.MAX_HP` | 1600 |
| Reactive: his wait | `REACTIVE_WAIT_MIN`, `_MAX` | 1.5 - 4 s |
| Reactive: parried hits before he strikes back | `PATIENCE` | 1, 2, 2 or 3 |
| Reactive: a pattern instead of a counter | `PATTERN_ANSWER_CHANCE` | 0.25 |
| Player: slash windup / cut / return | `ATTACK_WINDUP_TIME`, `_ACTIVE_`, `_RETURN_` (player.gd) | 0.1 / 0.15 / 0.2 s |
| Player: recoil after being parried | `PARRIED_RECOIL` (player.gd) | 0.5 s |
| Sync gained (parry / sync hit / both parried) | `GameManager.SYNC_GAINS` | 3 / 6 / 25 |

For testing: `TEST_ONLY_PATTERN` (one attack only, e.g. `"SWEEP"`).

## What to look for in the playtest

- Does "you parry, I hit" feel like one action done together, or like two people each doing
  their own thing next to a metronome? **beat** (a bet on the partner) or **after** (watching the
  partner): which reads as co-op, and in which does it matter that the hitter reacted?
- **The swing:** does 0.45 s feel like swinging a sword, and can you tell when you can block
  again? Is the recoil (0.5 s) enough of a price for a swing he parries, or too much for the
  reactive mode, where being parried is how an exchange starts?
- **Windup hits are worth a lot.** Uncapped, two fit into a first strike's windup: 20 damage,
  against 25 for the sync hit. Bots that only parry their own strikes and mash otherwise kill him
  in 64 s; bots that play it as meant (one parries, the other hits, no windup hits) in 46 s. If
  the sync hit is meant to be the point, it has to be worth more (`SYNC_HIT_FACTOR`).
- **Reactive:** is being struck back for attacking a fair answer? Does provoking feel like
  leading the fight?
- **The sweep:** can the second player read their moment (0.4 s after the first)? Do the four
  outcomes read from where the swords are, without knowing the table?
- Is the drop readable from the *other* side? Is 0.8 s between strikes the right tempo?

## Not in here yet (from the scribbles)

- A heavy strike on one side that takes both players to stop.
- Him moving: walking up to a player who backs off, charging through to swap sides.
- Joining up ("together mode"); blocking (not parrying) holding his sword for a moment.
- Sync that drains over time and when a moment for both is missed; the finisher at full sync.
- A smaller boss, with blades closer to the players' in size.
- Any theme: two-sided beings, one-armed players, yin and yang.
