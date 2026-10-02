# Columna Bifrons, in "The Threshold" (test boss)

A small boss built to answer questions, not a finished fight:

1. **Does fighting from both sides at once feel like co-op?** (player - boss - player: "pep")
2. **Should a boss react to being attacked**, the way Genichiro does in Sekiro?
3. **Can one small set of rules cover every blade**, the players' and the bosses' alike?
4. **What happens when both players are on one side of him** (player - player - boss: "ppe"),
   and how does a fight get from one to the other and back?

They come out of `scribbles.md` (2026-09-30 to 2026-10-02). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `attacks/strike_pattern.gd`, `attacks/sweep.gd`,
`attacks/leap.gd`), `levels/threshold/`; the players' half of the rules is in
`actors/player/player.gd` ("THE SWORD"). Select screen: entry 5. Everything below that can be
switched is on the F1 panel, under "Bifrons".

---

## The rules

Each player's parry is what lets the *other* one hit. There are six rules, and they're the same
for his blades and the players':

1. **Each of his swords fights one player.** It points at them, strikes at them and guards
   against them, on whichever side of him they are; its crossguard has that player's color. A
   player on each side: a sword on each side. Both players on one side: both swords there.
2. **A blade guards or swings, never both.** While a sword stands at its flank it parries every
   sword hit of its player. While it's drawn back for a strike, coming, lying where it landed,
   thrown back, or away, there's nothing to parry with: that player's hits land (plain damage),
   as many as fit. A plate down the flank shows a guard.
   For a player it's the same: from the attack press until the blade is back at rest, block does
   nothing and nothing can be parried.
3. **A strike has to be perfect parried by the player it's for** (block pressed at most 0.133 s
   before it lands). Just blocking softens the hit and opens nothing. The other player isn't
   touched by it, and can't parry it for them.
4. **A parried swing recoils.** The blade that was parried is knocked back and takes longer to
   come back: a player's 0.45 s (instead of the 0.33 s a swing has left once it has hit), his
   0.35 s before it moves again (instead of 0.12 s).
5. **A parried strike breaks the guard of his other sword** for a moment: the plate is gone,
   that half of him flashes, the sword is knocked aside. The other player's hit is a **sync
   hit** (2.5x damage, sync). The roles swap whenever his other sword strikes.
6. **Both swords parried at once stagger him** (2.2 s): no guard at all.

There's nothing else: no cap on hits, no lock against mashing. What used to be extra rules now
follows from these:

- **Hitting his windup.** The player about to be struck can cut at him while that sword is
  drawn back (rule 2), as often as fits, but a swing takes 0.41 s and has to be over before the
  parry. Greed isn't forbidden, it gets hit. How many fit is a matter of how fast his strikes
  come.
- **After your own parry** the sword that struck you is thrown back (rule 4): for about 0.45 s
  your own hits land too. One swing fits, if it's started at once.
- **Mashing at his guard.** Every swing is parried and costs 0.53 s (0.08 s until it lands,
  0.45 s recoil), with no block meanwhile.

## Pep and ppe

**Pep** is where the fight starts: a player on each side, a sword on each side.

**Ppe** is both players on one side. Both his swords are there then, and by rule 1 everything
works as before: each sword strikes its own player, the other player hits when it's parried. The
two swords can be told apart, by their colors and by how they move:

- the one whose hand is on that flank stands upright against it, and **comes down from above**;
- the other one **reaches across**: it stands outside the first, leaning out, and it **cuts
  level**, drawn back behind him and coming around.

A strike of both swords is both of those at once, in blue (parry together), and it's the heavy
one: if it doesn't stagger him he backs off from the players (110 px).

The sweep doesn't come in ppe, the leap only there:

### The crossing: pep to ppe

A pattern of two strikes. First **the charge**: one sword is lowered, the point on its player,
and drawn back into him while he rears back (yellow); then it's thrust (red, 0.28 s). It's
parried like any strike. 0.1 s after it lands he follows it through, 190 px in 0.25 s, his body
no obstacle meanwhile:

- a player next to him is passed, and both players are now on one side of him;
- a player who backs off ahead of him isn't, nor one who stood further away than about 140 px:
  he ends up on top of them, and they're pushed out ahead of him. Stepping toward him is what
  gets such a player past.

Then, 1.2 s later, **both swords** (blue) on wherever the players now are. The player who wasn't
passed is 250 px away at first, out of his reach: to parry it together they have to come over.

He charges toward the side that has room for it (130 px at least).

### The leap: ppe to pep

He crouches, the swords go up beside his head, points down (blue); he jumps, hangs over the
players (following them), turns red and comes down (0.28 s) between them, a sword stabbing down
on each. Each player within 80 px of where he lands has to parry their own; both do, and he's
staggered. Either way he's between them now: whoever is under him is pushed out to their side.

How long ppe lasts is `LEAP_WEIGHT`: at 7 every other attack there is the leap.

## How he moves

Between his attacks, never during one:

- **After a player who has got away:** more than 40 px beyond his blades' reach (215 px), or out
  of reach with nobody else in it. He walks (110 px/s) until they're well in reach again.
  **Sword hits slow him** to a third for 0.6 s each, so the partner can hold him back.
- **Else toward the middle third of the room** (55 px/s, 110 from the outer fifths), as far as
  he can go without leaving a player out of reach. A player in his way is pushed along.
- **He starts an attack only while a player is in reach.**

And with his attacks:

- **A long windup** (a single strike with a wait of 6 or more) brings him up to the player it's
  for, if they aren't next to him (120 px/s).
- The charge, the leap and backing off, above.

**Players always face him** (Moves "bifrons_face"), whichever way they walk, so nobody has their
back to him after he's passed them; the dash goes the way the stick is held. That's in
`player.gd`, for any boss that asks for it (`BaseBoss.holds_facing()`).

## The players' sword

Changed for this boss, in `player.gd`, so it holds in every fight (and needs Kay's yes):

- **Rest:** held diagonally, up and forward. **Block:** diagonally down in front. Letting go
  swings it back up; a perfect parry beats it up past its rest. That upswing *is* the parry.
- **The slash is a real swing:** drawn back (0.05 s, short: the cut has to follow the press),
  cut down (0.12 s; it reaches him about 0.08 s after the press), brought back (0.24 s). 0.41 s
  in all, and until the blade is back nothing else goes: no block, no parry, no second swing.
  No cooldown beyond that, and an attack pressed up to 0.15 s too early comes as soon as the
  blade is back.
- **Parried, it's knocked back** over the shoulder: 0.45 s until it's at rest again.
- **The sword is bigger:** 76 px long and 6 thick (it was 48 by 3), so the swing can be seen.
  Its reach grew with it.
- The upslash dips for 0.05 s first, from the new rest pose; the downslash and the dash-slash
  keep their timing.

He is smaller than he was (64 x 150 px, swords 170 px; it was 80 x 200 and 230), so a player's
cut is something next to him. The players' bodies are the size they were.

## Reading him

- **A crossguard in your color:** that sword is yours to parry, and the one that parries you.
- **Blade up over his head, yellow, that half of him tinted yellow:** it strikes next. It's
  drawn further back and trembles as the drop gets close.
- **Blade turns red and comes** (0.28 s, with a whoosh): the cue. It lands at the end of that.
- **Blue instead of yellow, both swords:** both at once; parry together.
- **Blade held out behind him, drawn back** (ppe): the sword that reaches across; it comes
  around level.
- **Blade lowered at you, drawn back into him, his body rearing back:** the charge.
- **Both blades up beside his head, pointing down, his body crouching:** the leap.
- **Blade held out to the side, low, drawn back** (pep): the sweep. It comes down level and goes
  through to the other side.
- **A guard blade flashing white and flicking outward, orange sparks:** he parried your hit.
- **A flank flashing pale yellow, a plate gone, its blade knocked outward:** hit here, now.
- **A blade planted out to the side, his shoulder on it:** he's propping himself up. No guard
  from that sword.
- **A dark blade lying on the far side:** knocked off its course. No guard from that sword.
- **Blades lying on the floor, body flashing grey:** staggered.
- **His body warming to rust (reactive mode):** his patience is running out.

## The partner's hit: on the beat, or after it ("bifrons_window")

When the guard breaks (rule 5) is the open question, so it's a switch. A swing lands 0.08 s
after its press, so the press has to come that much before the window:

- **beat** (default): the guard breaks with the parry, for 0.25 s. The attack press has to come
  between 0.08 s before the strike lands and 0.17 s after: with the partner's block press or
  just behind it ("clang, cut"). Nobody can know yet whether the parry will come, it's a bet on
  the partner; lost, the swing is parried and recoils.
- **after**: the guard breaks 0.25 s after the parry, for 0.3 s. The press has to come 0.17 to
  0.47 s after the strike landed: the hitter has to see or hear the parry first. A swing started
  with the strike is parried, and its recoil outlasts the window.

Mashing gets through by luck, since nothing forbids it, and with the quicker swing it does so
often. Measured with bots that mash attack and stop only to parry the strikes that are theirs:
somewhere between 2 and 5 sync hits in 10 strikes, in either window (it varies a lot from run to
run). A timed press gets all of them. `TASKS.md` has the problem in detail.

## The sweep (pep only)

One blade, held out to its side and drawn back (yellow, 0.9 s), comes down level (red, 0.28 s)
and sweeps through to the other side: it reaches its own player first and the other one 0.4 s
later. Each has to perfect parry it as it reaches them. A sweep breaks no guard (rule 5 is for
strikes); what a parry wins is where his swords end up, by rule 2:

| Parried by | What it leaves him with |
|---|---|
| nobody | The blade swings back at once (0.3 s). Guarded against both again. |
| the first player only | Knocked off its course, the blade ends up lying on the far side for 1.4 s: **no sword against the first player**. His other sword still guards. |
| the second player only | Stopped dead, he has to **prop himself up on his other sword** for 1.4 s, and it guards nothing meanwhile. The swept blade swings back and guards again. |
| both | Both at once: the blade lies where it was stopped and he leans on the other. No guard at all: **staggered**, 2.2 s. |

## Two modes ("bifrons_mode")

### patterns (default)

He runs one attack after another, a second or so apart. The players answer.

A pattern is a list of strikes, each `[wait, sword]` or `[wait, sword, kind]`. `wait` is the
time until the strike lands, counted from the pattern's start or the strike before, in units of
0.2 s (`StrikePattern.TIME_UNIT`): a rough 1-10 scale, 4 = 0.8 s, a quick follow-up; 9 = 1.8 s,
a long windup. Below 3 a strike can't be read any more. `sword` is which of his swords strikes
(left, right, both), at its own player; `kind` is `CUT` (the default) or `CHARGE`.

| Name | Strikes | Weight in pep | in ppe |
|---|---|---|---|
| SINGLE | 5 left | 1 | 1 |
| TRIPLE | 5 right, 4 right, 4 left | 3 | 3 |
| QUAD | 7 left, 4 left, 4 right, 4 both | 2 | 2 |
| LONG | 9 right, 4 right, 4 left, 4 right, 4 right, 4 left, 4 both | 1 | 1 |
| CROSSING | 6 right (charge), 6 both | 1.5 | - |
| SWEEP | the sweep, above | 1.5 | - |
| LEAP | the leap, above | - | 7 |
| SWAP *(off)* | 5 left, 4 right | 0 | 0 |
| BOTH *(off)* | 6 both | 0 | 0 |

They live in `ColumnaBifrons.PATTERNS`; adding one is one line. Each is written once and also
runs **mirrored**: whichever way keeps the number of strikes even between his two swords, at
random while they're even. So both players parry and hit about equally often, and what's learned
is the pattern's shape (A A B), not "right right left". SINGLE and TRIPLE may come twice in a
row, the long ones not.

### reactive

After Genichiro: an exchange that either side can start. It's the same fight, with the same
attacks; two things are different.

- **A hit he parries calls up his next attack, aimed at whoever attacked him.** He parries
  what hits his guard (rule 2), and that wears on his patience: 1 or 2 hits (picked afresh with
  every attack). Once it's gone and he's free, he strikes back at once: with one of the attacks
  above, turned so its first strike is the attacker's, and that strike lands within 0.8 s
  whatever the pattern's own windup. Then the series runs to its end, as ever. A hit he parries
  while he's attacking is answered as soon as that attack is over (0.6 s).
- **He leaves a little more room between his own attacks:** 0.5 to 1.2 s (after the usual
  0.6 s recovery) instead of 0.25 to 0.5 s. That's the players' moment to start instead.

So attacking him means being attacked, and that's the opening: you parry his answer, your
partner hits. Provoking is how a pair starts an exchange on its own beat. And greed is a trade:
a swing at him while he draws back the sword that's yours lands (rule 2), but it isn't over when
that sword comes.

## Testing alone ("bifrons_stand_in")

A stand-in plays the player who starts on the left, or on the right: that player's sword counts
as parried three times in four (`STAND_IN_PARRY_CHANCE`), and that player is never hurt, nor
walked up to. When the stand-in parries there's a clang and sparks. So one person, playing the
other player, gets to practice both parts, and has to watch whether the parry really came before
hitting. The stand-in never attacks, and the player it plays stays where they are: after a
charge it's you he has passed, or them.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | `StrikePattern.FALL_TIME` | 0.28 s |
| How the drop accelerates | `StrikePattern.FALL_POWER` | 1.7 |
| His blade after a strike: lying / thrown back by a parry | `STICK_TIME`, `RECOIL_TIME` | 0.12 / 0.35 s |
| Hit window, "beat": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0 / 0.25 s |
| Hit window, "after": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0.25 / 0.3 s |
| Sync hit damage | `ColumnaBifrons.SYNC_HIT_FACTOR` | x2.5 |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME`, `Sweep.STAGGER_TIME`, `Leap.STAGGER_TIME` | 2.2 s |
| Sweep: until it reaches the first player / on to the second | `Sweep.WINDUP_UNITS`, `TRAVEL_TIME` | 6 (1.2 s) / 0.4 s |
| Sweep: blade away / propped / swinging back | `Sweep.AWAY_TIME`, `PROP_TIME`, `RETURN_TIME` | 1.4 / 1.4 / 0.3 s |
| How often he crosses over (pep) / leaps back (ppe) | `PATTERNS.CROSSING.weight`, `LEAP_WEIGHT` | 1.5 / 7 |
| Charge: how far, how long after the thrust, how fast | `CHARGE_DISTANCE`, `CHARGE_DELAY`, `CHARGE_TIME` | 190 px / 0.1 / 0.25 s |
| Leap: until he lands / rising / hanging | `Leap.WINDUP_UNITS`, `RISE_TIME`, `HANG_TIME` | 7 (1.4 s) / 0.3 / 0.3 s |
| Leap: how close to where he lands a player is hit | `Leap.REACH` | 80 px |
| Backing off after both swords (ppe) | `BACK_OFF_DISTANCE`, `BACK_OFF_TIME` | 110 px / 0.2 s |
| Walking: after a player / to the middle / from the outer fifths | `WALK_SPEED`, `RECENTER_SPEED`, `RECENTER_SPEED_OUTER` | 110 / 55 / 110 px/s |
| Walking: slowed by a sword hit | `SLOWED_FACTOR`, `SLOWED_TIME` | x0.3 for 0.6 s |
| Walking: when he goes after a player, and how close he gets | `CHASE_SLACK`, `REACH_MARGIN` | reach + 40 / reach - 30 px |
| Stepping up during a long windup | `LONG_WINDUP`, `STEP_SPEED` | wait 6 or more / 120 px/s |
| Room he leaves at the walls | `WALL_ROOM` | 90 px |
| Damage to players (hit / blocked) | `BLADE_DAMAGE`, `BLOCKED_DAMAGE` | 12 / 4 |
| His health | `ColumnaBifrons.MAX_HP` | 1600 |
| How close a player has to be for him to attack, and for a blade to reach them | `BLADE_REACH` | 215 px |
| Reactive: his wait | `REACTIVE_WAIT_MIN`, `_MAX` | 0.5 - 1.2 s |
| Reactive: parried hits before he strikes back | `PATIENCE` | 1, 1 or 2 |
| Reactive: his answer's first strike lands within | `ANSWER_WAIT` | 4 (0.8 s) |
| Player: slash windup / cut / return | `ATTACK_WINDUP_TIME`, `_ACTIVE_`, `_RETURN_` (player.gd) | 0.05 / 0.12 / 0.24 s |
| Player: recoil after being parried | `PARRIED_RECOIL` (player.gd) | 0.45 s |
| Player: an early attack press still counts | `ATTACK_BUFFER_TIME` (player.gd) | 0.15 s |
| Sync gained (parry / sync hit / both parried) | `GameManager.SYNC_GAINS` | 3 / 6 / 25 |

For testing: `TEST_ONLY_PATTERN` (one attack only, e.g. `"CROSSING"`, `"LEAP"`, `"SWEEP"`).

## What to look for in the playtest

- Does "you parry, I hit" feel like one action done together, or like two people each doing
  their own thing next to a metronome? **beat** (a bet on the partner) or **after** (watching the
  partner): which reads as co-op, and in which does it matter that the hitter reacted?
- **Ppe:** can you tell which sword is yours when both are on your side (color, above or
  around)? Should ppe play like pep, as it does now, or be only a moment for one heavy strike
  (raise `LEAP_WEIGHT`, or take the patterns out of it)? With bots it's about 40% of the fight
  now, 9 to 15 s at a time.
- **The crossing:** is being passed something you can choose (stay, step in, back off), and is
  1.2 s enough for the partner to come over for the strike of both swords?
- **The leap:** readable? It puts him between you even if both parry it (staggered, then).
  Should a double parry leave you side by side instead?
- **His walking:** does it make the fight move, or is it just in the way? Is being pushed along
  by him all right?
- **The swing:** does it follow the press now, and does it still feel like swinging a sword?
  Can you tell when you can block again?
- **Mashing pays.** Windup hits are uncapped (two or three fit into a first strike's windup:
  20 to 30 damage, against 25 for the sync hit), and a masher's swings find the broken guard
  often. Bots that only parry their own strikes and mash otherwise kill him in 35 to 55 s; bots
  that play it as meant (one parries, the other hits, no windup hits) in 45 s. Whether that's a
  problem depends on how it feels with people; the knobs are `SYNC_HIT_FACTOR`, `PARRIED_RECOIL`
  and the tempo of his strikes.
- **Reactive:** does it flow, one exchange into the next? Is being struck back at once a fair
  answer, and does provoking feel like leading the fight?
- **The sweep:** can the second player read their moment (0.4 s after the first)? Do the four
  outcomes read from where the swords are, without knowing the table?

## Not in here yet (from the scribbles)

- The other way to cross over: a cut from below that throws the player up, and he charges
  through underneath.
- A heavy strike on one side that takes both players to stop.
- Joining up in ppe ("sync mode": one body, one big sword, the players as the attackers);
  blocking (not parrying) holding his sword for a moment.
- Sync that drains over time and when a moment for both is missed; the finisher at full sync.
- Bigger players, or players as two halves of one square. That changes every level.
- Any theme: two-sided beings, one-armed players, yin and yang.
