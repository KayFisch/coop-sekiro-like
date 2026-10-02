# Columna Bifrons, in "The Threshold" (test boss)

A small boss built to answer questions, not a finished fight:

1. **Does fighting from both sides at once feel like co-op?** (player - boss - player: "pep")
2. **Should a boss react to being attacked**, the way Genichiro does in Sekiro?
3. **Can one small set of rules cover every blade**, the players' and the bosses' alike?
4. **What happens when both players are on one side of him** (player - player - boss: "ppe"),
   and how does a fight get from one to the other and back?
5. **How should he move**, and what does he do when one player walks off?

They come out of `scribbles.md` (2026-09-30 to 2026-10-02). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `stand_in.gd`, `attacks/strike_pattern.gd`,
`attacks/sweep.gd`, `attacks/leap.gd`), `levels/threshold/`; the players' half of the rules is in
`actors/player/player.gd` ("THE SWORD", "DASH-PARRY"). Select screen: entry 5. Everything below
that can be switched is on the F1 panel.

---

## The rules

Each player's parry is what lets the *other* one hit. There are six rules, and they're the same
for his blades and the players':

1. **Each of his swords fights one player.** It points at them, strikes at them and guards
   against them, on whichever side of him they are; its crossguard has that player's color. A
   player on each side: a sword on each side. Both players on one side: both swords there. A
   sword whose own player has walked off turns on the other one until they're back ("Left
   alone", below).
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
6. **Both swords parried at once, by both players, stagger him** (2.2 s): no guard at all.

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

- the one whose hand is on that flank is the **back** one: it stands upright against the flank,
  and **comes down from over his head**, as in pep;
- the other one **reaches across, in front** of him and of the first: it stands outside it,
  leaning out, and it **cuts lower, on a slant**: drawn back at shoulder height on its own
  (far) flank, around his front, and down.

A strike of both swords is both of those at once, in green (parry together), and it's the heavy
one: if it doesn't stagger him he hops back from the players (110 px).

Three ways lead from one to the other. Two are his:

### The crossing: pep to ppe

A pattern of two strikes. First **the charge**: one sword is lowered, the point on its player,
and drawn far back into him, quickly, while he rears back (yellow, 1 s in all); then it's thrust
(red, 0.28 s). It's parried like any strike. 0.1 s after it lands he follows it through, 230 px
in 0.25 s, his body no obstacle meanwhile:

- a player next to him is passed, and both players are now on one side of him;
- a player who backs off ahead of him isn't, nor one who stood further away than about 150 px:
  he ends up on top of them, and they're pushed out ahead of him. Stepping toward him is what
  gets such a player past.

Then, 1.2 s later, **both swords** (green) on wherever the players now are, and with them he
comes back at the players: a short step or a long one (see "the lunge"), right up to the nearer
one. The player who wasn't passed is some 300 px away at first; for the blades to reach them too
(and to stagger him together) they have to come over.

He charges toward the side that has room for it (150 px at least).

### The leap: ppe to pep

He crouches, both swords go up over his middle, points down (green); he jumps, hangs over the
players (following them), turns red and comes down (0.28 s) between them. Each player within
80 px of where he lands has to parry the sword that's theirs; both do, and he's staggered.
Either way he's between them now, and they're thrown apart: whoever is under him is pushed out
to their side, a player the swords hit is knocked back 1.6 times as hard as by a strike, and
one who parried is still pushed back a little. Walking out from under him works too.

In ppe one attack in three is the leap (`LEAP_WEIGHT` 3.5 against the patterns' 7). He also
leaps when he's **cornered**: see "How he moves".

### The dash-parry: the players' own way

**A perfect parry that lands while you're dashing at him carries you through him**: the dash
starts over from there, and his body is no obstacle until it's done. A dash started up to 0.2 s
after the parry goes through him too. A dash that ends inside him puts you out on the side you
got closer to. It works at any of his strikes, in pep or ppe. (Moves "parry_pass"; it's a
player rule in `player.gd`, so it holds for Cubus too.)

## How he moves

**Where he stands.** Where his blades reach the players, and not right up against one:

- **A player on each side**, close enough together for his blades to reach both (430 px apart
  at most): in the middle between them. He walks there once he's 28 px off it.
- **Otherwise** (both on one side, only one to fight, or too far apart) he goes by the nearer
  player: **closer than 62 px, he steps back** until they're 90 away; **out of his blades'
  reach (215), he walks up** until they're well in it (185); in between he stays where he is.
- **With the players between him and a wall** he backs away from them toward the middle third
  of the room, as far as the nearer one stays well in reach (185): that gives them room, and
  draws them out. It's the only time he walks for the room's sake: he never walks into a player
  to get to the middle.

He walks (110 px/s) between his attacks, and at half that through their windups. **Sword hits
slow him** to a third for 0.6 s each, so a player can hold him back. **He starts an attack only
while a player is in his range** (375 px, see the lunge).

(Distances are between his center and a player's. Touching is 52; a player's sword reaches him
from 118; two players side by side both reach him with the nearer one at 78.)

**The lunge.** With every cut he moves at the player it's for while the blade comes (the last
0.28 s): a short step (14 px), or as far as it takes to have the players on that side 105 px
away as it lands, 160 px at most. He never gets closer to anyone than 72 px that way. So a
strike reaches a player up to 375 px away, and stepping back out of a strike takes more than a
step. Then he stands until that blade moves again: that's when the players hit him.

**A long windup** (a single cut with a wait of 6 or more: the first strike of QUAD and LONG)
brings him up to the player it's for: he walks at them all through it (70 px/s) until he has
reached them, and then lunges. Both players have to move with him.

**Crowded and cornered.** A player who stays closer than 62 px for 0.7 s makes him **hop back**
(110 px, at most every 4 s), if the players are on one side of him and the wall isn't right
behind him. **Cornered** is when there's no room for that: a player that close on each side, or
the players on one side and him in the outer fifth of the room, wall at his back. Then his next
attack is likely his way out: the leap, and with a player on each side also the crossing (weight
6 each). He doesn't leap while there's no room for him between the players (both in the 122 px
between him and a wall): he backs away instead, above.

**Players always face him** (Moves "bifrons_face"), whichever way they walk, so nobody has their
back to him after he's passed them; the dash goes the way the stick is held. That's in
`player.gd`, for any boss that asks for it (`BaseBoss.holds_facing()`).

## Left alone

What he does when one player walks off (to drink, say):

- **A strike whose player is out of his range** (375 px) when it becomes the next one **is left
  out**, and the rest of the pattern follows that much sooner. Of a strike of both swords only
  the sword whose player is there comes. A player just out of reach still gets the strike, with
  a lunge.
- **A sword whose own player has been out of range for 1.5 s turns on the other player.** It
  crosses over to them and takes their color: both swords on one player, as in ppe. Every strike
  is theirs to parry. A strike of both swords is one **heavy strike**: double damage, one parry
  meets it, and it doesn't stagger him (rule 6: that takes both players).
- The player he's fighting can't open him alone: after their own parry the other sword's guard
  is broken, but their own hit through it is a plain hit (one fits, rule 4). A sync hit is
  the partner's.
- **Nothing guards against the player who's away.** If they come back, their hits land (plain,
  or sync hits right after the partner's parry), until their sword has turned back: that
  happens as soon as they're in his blades' reach again and the sword is free.
- **The rush**: among his attacks while he's left alone (weight 3 against the patterns' 7).
  The away player's sword turns back to them, is raised (yellow, 1.4 s in all), and as it comes
  he dashes over to them, however far, in 0.45 s, his body no obstacle. It's parried like any
  strike. Then he's with them, and the other player is the one who's away.

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
- **The dash-parry**, above.

He is smaller than he was (64 x 150 px, swords 170 px; it was 80 x 200 and 230), so a player's
cut is something next to him. The players' bodies are the size they were.

## Reading him

- **A crossguard in your color:** that sword is yours to parry, and the one that parries you.
- **Blade up over his head, yellow, that half of him tinted yellow:** it strikes next. It's
  drawn further back and trembles as the drop gets close.
- **Blade turns red and comes** (0.28 s, with a whoosh): the cue. It lands at the end of that,
  and he steps (or dashes) at you with it.
- **Green instead of yellow, both swords:** both at once; parry together.
- **Blade held out on his far side, at shoulder height** (ppe): the sword that reaches across;
  it comes around his front and down on a slant.
- **Blade lowered at you, drawn back into him, his body rearing back:** the charge.
- **Both blades up over his middle, pointing down, his body crouching:** the leap.
- **Blade held out to the side, low, drawn back** (pep): the sweep. It comes down level and goes
  through to the other side.
- **A guard blade flashing white and flicking outward, orange sparks:** he parried your hit.
- **A flank flashing pale yellow, a plate gone, its blade knocked outward:** hit here, now.
- **A blade planted out to the side, his shoulder on it:** he's propping himself up. No guard
  from that sword.
- **A dark blade lying on the far side:** knocked off its course. No guard from that sword.
- **Blades lying on the floor, body flashing grey:** staggered.
- **Both crossguards in one color:** the other player is away, and both swords are on that one.
- **His body warming to rust (reactive mode):** his patience is running out.

Green means "get off the floor" and purple "dash" with Cubus and Sphaera, and blue is their
"parry together". Blue was too close to P1's color here; green is a stopgap, to be settled with
the players' colors.

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

He stands still for it.

## Two modes ("bifrons_mode")

### patterns (default)

He runs one attack after another, a second or so apart. The players answer.

A pattern is a list of strikes, each `[wait, sword]` or `[wait, sword, kind]`. `wait` is the
time until the strike lands, counted from the pattern's start or the strike before, in units of
0.2 s (`StrikePattern.TIME_UNIT`): a rough 1-10 scale, 4 = 0.8 s, a quick follow-up; 9 = 1.8 s,
a long windup. Below 3 a strike can't be read any more. `sword` is which of his swords strikes
(left, right, both), at its own player; `kind` is `CUT` (the default), `CHARGE` or `RUSH`.

| Name | Strikes | Weight in pep | in ppe | left alone |
|---|---|---|---|---|
| SINGLE | 5 left | 1 | 1 | 1 |
| TRIPLE | 5 right, 4 right, 4 left | 3 | 3 | 3 |
| QUAD | 7 left, 4 left, 4 right, 4 both | 2 | 2 | 2 |
| LONG | 9 right, 4 right, 4 left, 4 right, 4 right, 4 left, 4 both | 1 | 1 | 1 |
| CROSSING | 5 right (charge), 6 both | 1.5 (cornered: 6) | - | - |
| SWEEP | the sweep, above | 1.5 | - | - |
| LEAP | the leap, above | - (cornered: 6) | 3.5 (cornered: 6) | - |
| RUSH | 7 right (rush) | - | - | 3 |
| SWAP *(off)* | 5 left, 4 right | 0 | 0 | 0 |
| BOTH *(off)* | 6 both | 0 | 0 | 0 |

They live in `ColumnaBifrons.PATTERNS`; adding one is one line. Each is written once and also
runs **mirrored**: whichever way keeps the number of strikes even between his two swords, at
random while they're even. So both players parry and hit about equally often, and what's learned
is the pattern's shape (A A B), not "right right left". No pattern starts on a player who isn't
there. SINGLE and TRIPLE may come twice in a row, the long ones not.

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

A stand-in plays the player who starts on the left, or on the right, by pressing that player's
own buttons, so everything that happens to them is the game's own (`stand_in.gd`):

- it **keeps its distance** to him (95 px, give or take 20), wherever he goes;
- each of his strikes at it is **perfect parried three times in four, only blocked 15 times in
  a hundred, and hits the rest** (`PARRY_CHANCE`, `BLOCK_CHANCE`), decided as the strike comes
  up, so the other player has to watch whether the parry really came before hitting;
- it gets hurt, and **below 20 health, with a potion left, it runs away from him** (480 px, or
  to the wall) **and drinks**, then comes back: his strikes at it are left out, its sword turns
  on you, he may rush it ("Left alone");
- it never attacks.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | `StrikePattern.FALL_TIME` | 0.28 s |
| How the drop accelerates (and his lunge) | `StrikePattern.FALL_POWER` | 1.7 |
| His blade after a strike: lying / thrown back by a parry | `STICK_TIME`, `RECOIL_TIME` | 0.12 / 0.35 s |
| Hit window, "beat": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0 / 0.25 s |
| Hit window, "after": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0.25 / 0.3 s |
| Sync hit damage | `ColumnaBifrons.SYNC_HIT_FACTOR` | x2.5 |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME`, `Sweep.STAGGER_TIME`, `Leap.STAGGER_TIME` | 2.2 s |
| Sweep: until it reaches the first player / on to the second | `Sweep.WINDUP_UNITS`, `TRAVEL_TIME` | 6 (1.2 s) / 0.4 s |
| Sweep: blade away / propped / swinging back | `Sweep.AWAY_TIME`, `PROP_TIME`, `RETURN_TIME` | 1.4 / 1.4 / 0.3 s |
| How often he crosses over (pep) / leaps back (ppe) / either, cornered | `PATTERNS.CROSSING.weight`, `LEAP_WEIGHT`, `CORNERED_WEIGHT` | 1.5 / 3.5 / 6 |
| Charge: how far, how long after the thrust, how fast | `CHARGE_DISTANCE`, `CHARGE_DELAY`, `CHARGE_TIME` | 230 px / 0.1 / 0.25 s |
| Charge: how far he rears back | `StrikePattern.CHARGE_LEAN`, `POSE_LANCE_BACK` | 24 px, hand 18 px behind his middle |
| The sword that reaches across: around his front by / coming down from | `StrikePattern.SLASH_AROUND`, `SLASH_DOWN` | 0.55 / 0.35 of its drop |
| Leap: until he lands / rising / hanging | `Leap.WINDUP_UNITS`, `RISE_TIME`, `HANG_TIME` | 7 (1.4 s) / 0.3 / 0.3 s |
| Leap: how close to where he lands a player is hit | `Leap.REACH` | 80 px |
| Leap: knockback of a hit / push on a parry | `Leap.KNOCKBACK`, `PARRIED_PUSH` | x1.6 / 220 px/s |
| Where he stands: steps back from / to; walks up from / to | `CROWD_DISTANCE`, `FIT_DISTANCE`; `BLADE_REACH`, `REACH_MARGIN` | 62 / 90; 215 / 185 px |
| Where he stands: how far off the middle before he walks | `PLACE_SLACK` | 28 px |
| Walking: between attacks / during them | `WALK_SPEED`, `ATTACK_PACE` | 110 px/s / x0.5 |
| Walking: slowed by a sword hit | `SLOWED_FACTOR`, `SLOWED_TIME` | x0.3 for 0.6 s |
| Lunge: short / long / where the players are when it lands / never closer than | `LUNGE_SHORT`, `LUNGE_LONG`, `STRIKE_DISTANCE`, `CLOSEST` | 14 / 160 / 105 / 72 px |
| Long windup: from which wait, how fast he walks | `LONG_WINDUP`, `ADVANCE_SPEED` | 6 / 70 px/s |
| Hopping back: how far, after how long crowded, how often | `BACK_OFF_DISTANCE`, `CROWD_PATIENCE`, `HOP_COOLDOWN` | 110 px / 0.7 s / 4 s |
| Left alone: until a sword turns / the rush's dash | `TURN_TIME`, `RUSH_TIME` | 1.5 / 0.45 s |
| Left alone: how often he rushes | `PATTERNS.RUSH.weight` | 3 |
| Heavy strike (both swords on one player): damage / knockback | `StrikePattern.HEAVY_DAMAGE`, `HEAVY_KNOCKBACK` | x2 / x1.5 |
| Room he leaves at the walls | `WALL_ROOM` | 90 px |
| Damage to players (hit / blocked) | `BLADE_DAMAGE`, `BLOCKED_DAMAGE` | 12 / 4 |
| His health | `ColumnaBifrons.MAX_HP` | 1600 |
| How close a player has to be for a blade to reach them | `BLADE_REACH` | 215 px |
| Reactive: his wait | `REACTIVE_WAIT_MIN`, `_MAX` | 0.5 - 1.2 s |
| Reactive: parried hits before he strikes back | `PATIENCE` | 1, 1 or 2 |
| Reactive: his answer's first strike lands within | `ANSWER_WAIT` | 4 (0.8 s) |
| Stand-in: parried / blocked (the rest hits) | `BifronsStandIn.PARRY_CHANCE`, `BLOCK_CHANCE` | 0.75 / 0.15 |
| Stand-in: where it stands / when it flees / how far | `DISTANCE`, `FLEE_HP`, `FLEE_DISTANCE` | 95 px / 20 / 480 px |
| Player: slash windup / cut / return | `ATTACK_WINDUP_TIME`, `_ACTIVE_`, `_RETURN_` (player.gd) | 0.05 / 0.12 / 0.24 s |
| Player: recoil after being parried | `PARRIED_RECOIL` (player.gd) | 0.45 s |
| Player: an early attack press still counts | `ATTACK_BUFFER_TIME` (player.gd) | 0.15 s |
| Player: a dash this soon after a parry goes through him | `PASS_WINDOW` (player.gd) | 0.2 s |
| Sync gained (parry / sync hit / both parried) | `GameManager.SYNC_GAINS` | 3 / 6 / 25 |

For testing: `TEST_ONLY_PATTERN` (one attack only, e.g. `"CROSSING"`, `"LEAP"`, `"SWEEP"`).

## What to look for in the playtest

- Does "you parry, I hit" feel like one action done together, or like two people each doing
  their own thing next to a metronome? **beat** (a bet on the partner) or **after** (watching the
  partner): which reads as co-op, and in which does it matter that the hitter reacted?
- **Ppe:** can you tell which sword is yours when both are on your side (color; over his head,
  or around his front)? With the dash-parry, is changing sides now something you choose? If you
  leave it to him, ppe lasts about 10 to 20 s with bots.
- **The crossing:** is being passed something you can choose (stay, step in, back off)? Is the
  charge's windup right now, and the strike of both swords after it, with him coming back at
  you?
- **His moving:** does he keep a distance that feels right (he steps back from 62 px, to 90)?
  Is the lunge with every strike felt, and is having to follow him when he lunges at your
  partner good or a nuisance? The hop back? Do you ever feel he walks when he should stand?
- **The room:** he walks toward the middle of the room only when that takes him away from the
  players; with the wall at his own back he leaps out instead. Does the fight get stuck at a
  wall?
- **Left alone:** does walking off to drink feel like it has a price (the partner gets both
  swords, he may rush you), and does coming back in behind him feel like a chance? Is the rush
  readable?
- **The dash-parry:** does it come off, with the buttons as they are? Should it need less
  precision (it's the parry's 0.133 s, and the dash has to be under way or follow within
  0.2 s)?
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
- Just jumping away over a player when he's cornered, without a strike.
- Players slower while they swing.
- A stand-in that attacks.
- Joining up in ppe ("sync mode": one body, one big sword, the players as the attackers);
  blocking (not parrying) holding his sword for a moment.
- Sync that drains over time and when a moment for both is missed; the finisher at full sync.
- Bigger players, or players as two halves of one square; players in black and white. That
  changes every level.
- Any theme: two-sided beings, one-armed players, yin and yang.
