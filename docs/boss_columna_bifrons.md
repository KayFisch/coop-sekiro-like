# Columna Bifrons, in "The Threshold" (test boss)

> **Note (2026-10-19):** This doc describes the **try-out boss**: today's Columna Bifrons,
> kept as it is as a workbench for rules, systems and raw attack ideas. It needs a new name; the
> name Columna Bifrons goes to a new boss designed from scratch (`docs/boss_bifrons_warden.md`).
> Rules that now hold for all bosses (boss design principles, one parry per blade, stagger,
> knockback, the screen halves, the sync mode) are in `docs/concept.md`.

A small boss built to answer questions, not a finished fight:

1. **Does fighting from both sides at once feel like co-op?** (player - boss - player: "pep")
2. **Should a boss react to being attacked**, the way Genichiro does in Sekiro?
3. **Can one small set of rules cover every blade**, the players' and the bosses' alike?
4. **What happens when both players are on one side of him** (player - player - boss: "ppe"),
   and how does a fight get from one to the other and back?
5. **How should he move**, and what does he do when one player walks off?
6. **Can sync be life?** No health, no potions: one sync for both players, one for him, and a
   posture each, by the same rules on both sides ("Sync as life", below).

They come out of `scribbles.md` (2026-09-30 to 2026-10-02). The name is a working title.

Code: `actors/bosses/columna_bifrons/` (boss, `stand_in.gd`, `attacks/strike_pattern.gd`,
`attacks/sweep.gd`, `attacks/leap.gd`, `attacks/shove.gd`), `levels/threshold/`; the players'
half of the rules is in `actors/player/` ("THE SWORD" in `player_sword.gd`, "DASH-PARRY" in
`player_body.gd`). Select screen:
entry 1. Everything below that can be switched is on the F1 panel.

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
two swords can be told apart by their colors (**the crossguard and the cutting edge of a blade
have its player's color**, whatever color the blade itself turns) and by how they move:

- the one whose hand is on that flank is the **back** one: it stands upright against the flank,
  and **comes down from over his head**, as in pep;
- the other one **reaches across, in front** of him and of the first: it stands outside it,
  leaning out, and it strikes the same way, only **from lower**: laid back over his shoulder,
  it comes on a flatter arc.

A strike of both swords is both of those at once, in green (parry together), and it's the heavy
one: if it doesn't stagger him he makes room afterwards (a hop back, or the shove: see "How he
moves").

Three ways lead from one to the other. Two are his:

### The crossing: pep to ppe

A pattern of three. First **the push**: one sword upright, drawn in against him (white, 0.6 s),
then shoved out flat: its player is thrown back some 230 px. No damage, nothing to parry. Then
**the charge** at that player: the same sword lowered at them and drawn far back into him while
he rears back (yellow, 0.8 s), then thrust (red, 0.28 s), and as it comes he lunges after them
(up to 160 px). From that distance the thrust can be seen coming: its point isn't on the player
all through the windup, as it was when it came from close by (Nicho, 2026-10-16). It's parried
like any strike. 0.1 s after it lands he follows it through in 0.25 s, his body no obstacle
meanwhile, to 70 px past its player (230 px at least, 360 at most): even a player the thrust
hit, and threw back, is passed, and both players are now on one side of him. A player who
backs off further than that ahead of him isn't: he ends up on top of them, and they're pushed
out ahead of him.

Then, 1.2 s later, **both swords** (green) on wherever the players now are, and with them he
comes back at the players: a short step or a long one (see "the lunge"), right up to the nearer
one. The player who wasn't passed is some 300 px away at first; for the blades to reach them too
(and to stagger him together) they have to come over.

He charges toward the side that has room for it (150 px at least).

### The leap: ppe to pep

He crouches, both swords go up over his middle, points down (green); he jumps to above the spot
between the players, hangs there, turns red and comes down (0.28 s). **Where he comes down is
settled as he jumps**: he doesn't follow the players in the air. Each player within 80 px of
that spot as he lands has to parry the sword that's theirs; both do, and he's staggered. They're
thrown apart: whoever is under him is pushed out to their side, a player the swords hit is
knocked back 1.6 times as hard as by a strike, and one who parried is still pushed back a
little. Walking out from under him works too; players who both leave on the same side are still
on one side of him afterwards.

In ppe about one attack in four is the leap (weight 2.5 against the series' 6.5). He also leaps
when he's **cornered**: see "How he moves".

### The dash-parry: the players' own way

**A perfect parry that lands while you're dashing at him carries you through him**: the dash
starts over from there, and his body is no obstacle until it's done. A dash started up to 0.2 s
after the parry goes through him too. A dash that ends inside him puts you out on the side you
got closer to. It works at any of his strikes, in pep or ppe. (Moves "parry_pass"; it's a
player rule in `player_body.gd`, so it holds for any boss with a body.)

## How he moves

**Where he stands.** Where his blades reach the players, and not right up against one:

- **A player on each side**, close enough together for his blades to reach both (430 px apart
  at most): around the middle between them, off it by his drift (below), up to 60 px toward one
  of them as long as the other stays well in reach.
- **Otherwise** (both on one side, only one to fight, or too far apart) he goes by the nearer
  player: **closer than 62 px, he steps back** until they're 90 away; **out of his blades'
  reach (215), he walks up** until they're well in it (185); in between he drifts.
- **His drift** (Nicho, 2026-10-16: "less standing around"): the distance he keeps from the
  nearer player keeps changing, between 80 and 170 px, gliding toward one picked at random
  (0.6 of that span per second), and after a pause of up to 0.5 s toward the next. So he steps
  up to them and back from them, about as often.
- **Pushing through:** a player in his way doesn't stop him. Walking into one, he slows to half
  his pace and pushes them along; after 2 s of that he shoves them out of the way (the shove,
  on their side only).
- **With the players between him and a wall** he backs away from them toward the middle third
  of the room, as far as the nearer one stays well in reach (185): that gives them room, and
  draws them out. It's the only time he walks for the room's sake.

He walks (110 px/s) between his attacks, and at half that through their windups. **Sword hits
slow him** to a third for 0.6 s each, so a player can hold him back. **He starts an attack only
while a player is in his range** (375 px, see the lunge).

(Distances are between his center and a player's. Touching is 42; a player's sword reaches him
from 118; two players side by side (20 wide each) both reach him with the nearer one at 98.)

**The lunge.** With every cut he moves at the player it's for while the blade comes (the last
0.28 s): a short step (14 px), or as far as it takes to have the players on that side 105 px
away as it lands, 160 px at most. He never gets closer to anyone than 72 px that way. So a
strike reaches a player up to 375 px away, and stepping back out of a strike takes more than a
step. Then he stands until that blade moves again: that's when the players hit him.

**A long windup** (a single cut with a wait of 6 or more; with Nicho's current table, none)
brings him up to the player it's for: he walks at them all through it (70 px/s), into them if
they stand their ground (pushing them), and then lunges. Both players have to move with him.

**Making room.** When a player has stayed closer than 62 px for 0.7 s (at most every 4 s), and
after a strike of both swords that didn't stagger him, he wants room. With the players on one
side of him he makes it, one of two ways, so that it never drives him to the wall:

- **a hop back** (110 px), if that takes him toward the middle of the room;
- else **the shove**: both swords upright, drawn in against him (white, 0.5 s), then shoved out
  flat. It's no strike: no damage, nothing to parry. It throws back every player within 215 px
  on a side a blade is shoved to, about 230 px (a player who's dashing isn't moved). He only
  shoves while a player is within 150 px.

**Cornered** is when there's no room to keep his distance by walking: a player closer than
62 px on each side, or the players on one side and him in the outer fifth of the room, wall at
his back. Then his next attack is likely his way out: the leap, and with a player on each side
also the crossing (weight 6 each). He doesn't leap while there's no room for him between the
players (both in the 122 px between him and a wall): he backs away instead, above.

**Players always face him** (Moves "bifrons_face"), whichever way they walk, so nobody has their
back to him after he's passed them; the dash goes the way the stick is held. That's in
`player_body.gd` (`_face()`), for any boss that asks for it (`BaseBoss.holds_facing()`).

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
  happens as soon as they're within 300 px of him again (further than his blades reach: he
  turns to them as they come) and the sword is free.
- **The rush**: among his attacks while he's left alone (weight 2 against the series' 6.5).
  The away player's sword turns back to them, is raised (yellow, 1.4 s in all), and as it comes
  he dashes over to them, however far, in 0.45 s, his body no obstacle. It's parried like any
  strike. Then he's with them, and the other player is the one who's away.

## The players' sword

Changed for this boss, in `player_sword.gd`, so it holds in every fight (and needs Kay's yes):

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
cut is something next to him. The players' bodies are half as wide as they were (20 x 40 px
instead of 40 x 40, `Player.BODY_SIZE`): two side by side make a square, their swords and
hitboxes sit closer together, and the one behind in ppe gets nearer to him.

## Reading him

- **A crossguard and a blade's edge in your color:** that sword is yours to parry, and the one
  that parries you.
- **Blade up over his head, yellow, that half of him tinted yellow:** it strikes next. It's
  drawn further back and trembles as the drop gets close.
- **Blade turns red and comes** (0.28 s, with a whoosh): the cue. It lands at the end of that,
  and he steps (or dashes) at you with it.
- **Green instead of yellow, both swords:** both at once; parry together.
- **Blade laid back over his shoulder, lower than the other** (ppe): the sword that reaches
  across, in front; it comes the same way, on a flatter arc.
- **Blade lowered at you, drawn back into him, his body rearing back:** the charge.
- **Both blades upright, drawn in against him, white:** the shove. Nothing to parry; it throws you
  back.
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

Green meant "get off the floor" and purple "dash" with the first two bosses (Cubus and Sphaera,
removed 2026-10-18), and blue their "parry together". Blue was too close to P1's color here;
green is a stopgap, to be settled with the players' colors.

## The partner's hit: the window after a parry (F2, tab "sync hit")

When the guard breaks (rule 5) is the open question, so it's tunable (since 2026-10-17 on F2,
tab "sync hit", in place of the switch "bifrons_window", which chose between the two below):
the window **opens** "sync_window_delay" after the parry (0.18), is **on the beat** for its first
"sync_beat_time" (0.12) and stays open **off the beat** "sync_window_late" longer (0.18); a hit on
the beat wins 4 sync, one off it 2, a window left unused (the partner in reach) costs 1. The
parry's energy (SyncWave) arrives as it opens, and the partner's blade blazes for the beat. A
swing lands 0.08 s after its press from next to him (up to 0.17 s from the edge of its reach),
so the press has to come that much before the window. The two settings the switch had:

- **beat**: the guard breaks with the parry (delay 0), for 0.25 s. The attack press has to come
  between 0.08 s before the strike lands and 0.17 s after: with the partner's block press or
  just behind it ("clang, cut"). Nobody can know yet whether the parry will come, it's a bet on
  the partner; lost, the swing is parried and recoils.
- **after** (now the default): the guard breaks 0.18 s after the parry, for 0.3 s: the hitter answers the parry
  instead of betting on it. From next to him the press has to come 0.1 to 0.4 s after the
  strike landed. A swing started with the strike is parried, and its recoil outlasts the window.
  0.18 is as short as the delay can be for that: a swing lands 0.05 to 0.17 s after its press
  (sooner the closer you stand), so with less a press right on the strike gets through from
  further away, and it's partly a bet again. (Measured with real presses exactly as the strike lands:
  at 0.15 s 11 of 24 got through, at 0.18 s 3 of 17.)

Mashing gets through by luck, since nothing forbids it, and with the quicker swing it does so
often. Measured with bots that mash attack and stop only to parry the strikes that are theirs:
somewhere between 2 and 5 sync hits in 10 strikes, in either window (it varies a lot from run to
run). A timed press gets all of them. `TASKS.md` has the problem in detail.

**Whether the guard breaks at all ("bifrons_guard_break", on by default).** Off (Nicho,
2026-10-17), a parry no longer breaks his other sword's guard: the window stays, timed as above
and cued on the partner's sword, but in it his guard still parries or blocks. A hit in the
window is a sync hit only if it lands, so the partner has to find a moment that sword can't
parry: drawn back for its next strike, coming, or thrown back. Trying in the window counts as
using it (no sync lost for a missed window).

## The sweep (pep only)

One blade, held out to its side and drawn back (yellow, 0.9 s), comes down level (red, 0.28 s)
and sweeps through to the other side: it reaches its own player first and the other one
0.26 s later. Each has to perfect parry it as it reaches them. A sweep breaks no guard (rule 5 is for
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

All his attacks are entries of one table, `ColumnaBifrons.ATTACKS`: a weight (one number, or
one per situation: `pep`, `ppe`, `alone`, and `pep_cornered` / `ppe_cornered`), whether it may
come twice in a row, and what it is: a series of strikes, or the script of an attack of its own
(sweep, leap, shove). Adding or retuning one is one line. `TEST_ONLY_PATTERN` takes a list of
names to fight only those.

A series is a list of strikes, each `[wait, sword]` or `[wait, sword, kind]`. `wait` is the
time until the strike lands, counted from the series' start or the strike before, in units of
0.2 s (`StrikePattern.TIME_UNIT`): a rough 1-10 scale, 4 = 0.8 s, a quick follow-up; 9 = 1.8 s,
a long windup. Below 3 a strike can't be read any more. `sword` is which of his swords strikes
(left, right, both), at its own player; `kind` is `CUT` (the default), `CHARGE`, `RUSH` or
`PUSH` (a shove of that player, no strike: the crossing). The numbers are Nicho's of 2026-10-16.

| Name | What | Weight in pep | in ppe | left alone |
|---|---|---|---|---|
| SINGLE | 3 left | 0 | 0 | 0 |
| DOUBLE | 3 left, 3 right | 0.5 | 0.5 | 0.5 |
| TRIPLE | 4 right, 4 right, 2 left | 2 | 2 | 2 |
| QUAD | 4 left, 2 left, 2 right, 3 both | 1.5 | 1.5 | 1.5 |
| LONG | 5 right, 3 right, 3 left, 4 right, 3 right, 3 left, 4 both | 1 | 1 | 1 |
| BOTH | 4 both | 0.5 | 0.5 | 0.5 |
| CROSSING | 3 right (push), 4 right (charge), 4 both | 2 (cornered: 6) | - | - |
| RUSH | 5 right (rush) | - | - | 2 |
| SWEEP | the sweep, above | 1.5 | - | - |
| LEAP | the leap, above | - (cornered: 6) | 2.5 (cornered: 6) | - |
| SHOVE | the shove, above | when he wants room | when he wants room | when he wants room |

Each series is written once and also runs **mirrored**: whichever way keeps the number of
strikes even between his two swords, at random while they're even. So both players parry and
hit about equally often, and what's learned is the series' shape (A A B), not "right right
left". No series starts on a player who isn't there. SINGLE and TRIPLE may come twice in a row,
the others not.

### reactive

After Genichiro: an exchange that either side can start. It's the same fight, with the same
attacks; two things are different.

- **A hit he parries calls up his next attack, aimed at whoever attacked him.** He parries
  what hits his guard (rule 2), and that wears on his patience: 1 or 2 hits (picked afresh with
  every attack). Once it's gone and he's free, he strikes back at once: with one of the attacks
  above, turned so its first strike is the attacker's, and that strike lands within 0.8 s
  whatever the pattern's own windup. Then the series runs to its end, as ever. A hit he parries
  while he's attacking is answered as soon as that attack is over (0.6 s).
- **He leaves a little more room between his own attacks:** 0.5 to 0.9 s (after the usual
  0.6 s recovery) instead of 0.25 to 0.5 s. That's the players' moment to start instead.

So attacking him means being attacked, and that's the opening: you parry his answer, your
partner hits. Provoking is how a pair starts an exchange on its own beat. And greed is a trade:
a swing at him while he draws back the sword that's yours lands (rule 2), but it isn't over when
that sword comes.

## Sync as life

Nobody has health and there are no potions (`core/sync_rules.gd`). (Until 2026-10-18 a switch,
"bifrons_rules", could still run the fight the old way: health, potions, and a sync meter in
GameManager that multiplied the damage.)

**The meters.** At the top two meters meet in the middle: the players' shared sync on the left,
filling out to the left; his on the right, in a dimmer shade of the same, full at the start
and emptying toward the middle. The players start halfway. Each of the three has a posture, a
thin bar under the sync meters, full out to the end like them: P1's and P2's under the players'
meter, his under his (orange with a quarter left). Next to the posture bars, "regen" says how
fast posture comes back just now (dimmed while it doesn't). How many points each meter holds
is set on F2 (the players' sync 100, his 200; posture 100, his 200); the thresholds below are
shares of it. How posture should look in the end is for later.

**One set of rules for both sides** (Nicho, 2026-10-17: a fair exchange; what tips it is that
the players can win sync back and he can't, and that he has more of it: 200 to their 100).

Attacks are **normal or heavy**. His heavy ones are those of both swords (green: a strike of both,
at one player or at two, and the leap); his single-sword strikes are normal, the sweep too. The
players' attacks are normal; heavy only as the bound pair's strike let go together in their sync
mode (below).

**Posture** comes in three sizes. As there are two players to attack him, his sizes are set
apart from theirs on F2 (both 5, 15 and 30 by default):

| | small (5) | medium (15) | large (30) |
|---|---|---|---|
| a normal attack | you parry it or block it; yours is parried | it hits you | |
| a heavy attack | | you parry it or block it; yours is parried | it hits you |

So a parry costs both sides alike (the parrier and the one parried), and **a block only the one
who blocks: blocking does nothing to the attacker**. His posture goes when the players parry
him, when their hits land, and when they hit his guard (he blocks or parries by chance, half and
half; his parry costs them too). A parry never breaks the parrier's own posture; anything else
can break it.

**Sync** is lost only to a hit that lands: a heavy one costs 18, a normal one a third of that (6);
his and theirs are set apart too.
Blocked or parried, no sync. The players win sync back: a sync hit (through the guard their
partner's parry broke) 4 on the beat and 2 after it, a coop parry (both his swords at once, each
parried by its player) 6, and it staggers him for 1 s. A window nobody used, while someone other
than the parrier was in reach, costs them 1. He wins none back.

- **Posture comes back** only once nothing has landed on you (hit, blocked or parried) for 2 s,
  and, for a player, once you haven't swung for as long (F1 "swings_hold_posture", on); his own
  attacks never hold his back, as he attacks nearly all the time (Nicho, 2026-10-17). While it
  doesn't come back, its bar is dimmed. Holding block meanwhile doubles it. How fast follows sync, as in Sekiro: at full sync the full rate (players 20 per second, him
  30), at 75 % half of it, at 50 % and below hardly any (5 %); "regen" next to the posture bars
  says how much just now.
- **Broken:** staggered (players 0.8 s, him 2.5 s), all sync gone; posture comes back full.
- **No sync is chaos.** The players can't block (parries still work), and the next hit that
  isn't parried ends the fight. It's over, like a revive, once their sync is back to a quarter.
  He, split, has no guard, and the next hit that lands kills him; as he wins no sync back, it
  lasts: breaking his posture is the deathblow of Sekiro.
- **Full sync is the sync mode**, the players' second phase, until their sync falls below 70 %.
  The meter turns gold. What happens in it: "The sync mode", below.
- **The beat:** a parry's energy runs over to the partner (`actors/player/sync_wave.gd`): hot
  pink, from the parrier's sword down through them into the floor, along it (on the mirrored
  screen: along the line), and up the partner from their feet into their sword, arriving as the
  window opens (0.18 s on "after"; at once on "beat"). Then the partner's blade blazes for the
  beat (0.12 s) with a burst at its point: a hit landing in that time is on the beat. The sync
  hit passes the energy on into him (pink sparks, white ones on the beat). (Until 2026-10-17 the
  sword only turned violet, too easy to miss.)
- **Every number is on the F2 panel** (saved to `user://tuning.cfg`, reset on its last row).
  The numbers above are the defaults.
- Testing alone: the stand-in strikes through the guard your parries open for it, three times
  in four; the windows it leaves unused cost sync.

**What two stand-ins showed** (2026-10-17, his posture at 200): the fight is decided by his
posture. It broke after 19 to 40 s; by then his sync was still at 170 to 190 of 200. His posture
came back only 4 to 10 % of the time, as he attacks most of the time and his pauses are shorter
than 2 s; so how much sync he has hardly matters to it. The players' came back about half the
time. That's where his patterns and behavior have to change (pauses, or what counts as his
attacking), and the sizes and meters be tuned.

Before 2026-10-17 the rules were otherwise: posture lost only by the one hit, blocked or parried,
in amounts per action; a sync hit cost him more than another hit; the sync mode tripled the
players' hits; he won sync back from a coop parry of his own or one strike hitting both players;
posture came back 1 s after the last loss, its rate following sync to the power 2.

## The sync mode (bound)

Nicho, 2026-10-17 (`core/sync_bond.gd`; numbers on F2, tab "sync mode"). With their sync full:

- **The sign:** a pink ring pulses at both players' feet: they can join. Standing together (30 px
  apart or less, both on the floor) **binds** them: a pink flash, and each takes on some of the
  other's color from the feet up (a third of the body): white flows into black and black into
  white, across the floor line on the mirrored screen. A pink line runs along the floor between
  them. Apart again (past 90 px), or out of the sync mode, they're unbound. How they move bound
  is still open: for now each moves as ever.
- **Sabres:** bound, their swords become sabres: longer, curved, half light and half dark.
- **Getting together:** in the sync mode a dash-slash goes through his body (F1
  "dash_slash_pass": in the sync mode only, always, or never), as a dash-parry does, so the two
  can always reach each other, whatever he's doing. The stand-in does it too.
- **The pair's strike:** hold attack to draw the sabre back over the shoulder (0.45 s to full);
  fully drawn, a small cue (a pink ring at its point, a tick). Once both are, 0.15 s after the
  later one comes **the big cue** (bigger rings, a pink flash, the line along the floor lights
  up): both let go on it (within 0.1 s either side) and they **land a heavy strike together**,
  with a big blow (shake, pink and white sparks, a pink flash). His guard can't stop it: met by a
  guarding blade it still costs him a normal hit's sync (and a parried heavy one's posture) and he
  **reels** (0.8 s). Out of sync (too early, too late, alone) each strikes on their own, weakly (a
  grey puff; a normal attack, which his guard meets as ever), and they lose 5 sync. Bound, a
  swing deals no hit of its own: only the pair's strike does. A block press lets a drawn sabre go.
- **Parrying, bound:** his strikes of both swords take both parries; a lone parry is only a block.
- **Him, in their sync mode: on the defensive.** Every cut comes with both swords at once, he picks
  only his series of plain cuts (no crossing, sweep, leap or rush: nothing that throws the two
  apart), his waits and pauses are 1.4 times as long, and between two attacks he stays on guard
  2 s longer. While one of them draws back he holds off his next attack (up to 1.5 s in a row):
  the players are the ones attacking now. (Nicho, 2026-10-17: he struck so fast there was no
  time to draw back.)
- **Time** (F2 "sync_slow_speed", 1 by default: off): set lower (0.5: half), time runs slow while
  one of the bound draws back, the screen faintly pink. It slows everything, the players' own
  movement too, so it's there to compare with the defensive boss.
- **The mirrored screen** (F1 "sync_merge_view", off by default): bound, the two halves become one:
  the shadow comes up into the light half (outlined pale, to read on the dark) and the shadow
  half dims out of focus, almost as the screen was before the split.
- **The stand-in** plays it perfectly: it goes to its partner to bind, parries every strike, draws
  back when its partner does and lets go right on the big cue (or when the partner lets go early).
- Separate swings outside the bond are normal attacks in the sync mode too (before 2026-10-17 the
  sync mode made every hit heavy).

The sync mode's general model (the players' boss phase) is now in `docs/concept.md`; what is
described here is the first prototype.

## Testing alone ("bifrons_stand_in")

A stand-in plays the player who starts on the left, or on the right, by pressing that player's
own buttons, so everything that happens to them is the game's own (`stand_in.gd`):

- it **keeps its distance** to him (95 px, give or take 20), wherever he goes;
- each of his strikes at it is **perfect parried three times in four, only blocked 15 times in
  a hundred, and hits the rest** (`PARRY_CHANCE`, `BLOCK_CHANCE`), decided as the strike comes
  up, so the other player has to watch whether the parry really came before hitting;
- **when your parry opens his guard on its side, it strikes through, three times in four**
  (`SYNC_HIT_CHANCE`), after a reaction of up to 0.08 s, so some of its sync hits are on the
  beat and some after it; it doesn't attack otherwise.

## The mirrored screen ("mirror_view")

An alternative picture of the same fight, after the mirror scene in *Gris*: the screen split at
the floor line. Above it the room with P1, in light (white); below it the room's reflection,
upside down, with P2, in shadow (black on pale ground). He is in both halves, mirrored whole: he
can't move his light and his shadow apart, the players can. Each half leaves out the other
player, so they never cover each other, and they pass through each other (there's nobody to bump
into in a half of your own). Everything else is the same fight: one floor, the same rules, the
same distances.

Decided 2026-10-19: the halves are to become two connected sides instead of a pure mirror, each
showing the blades aimed at its own player (`docs/concept.md`, "The two screen halves"). Not
built yet.

- Switch it in F1 (off by default); it goes on and off at once, mid-fight too.
- The room is drawn at 0.85 so his leap stays inside a half (`MirrorView.ZOOM`). Colors, the
  pale ground, the outline in the shadow half: constants at the top of `ui/mirror_view.gd`.
- A body that's nearly white flashes black when hit, instead of white (`FLASH_DARK_ABOVE`).
- To find out: whether playing upside down (the bottom player's jump goes down the screen) is
  bearable; whether not seeing the partner next to you costs more than the space gained; what
  becomes of sync and the partner clashes when the two only meet at the line.

## Tuning

| What | Where | Now |
|---|---|---|
| Tempo of everything | `StrikePattern.TIME_UNIT` | 0.2 s |
| How long the drop takes (the reaction time) | F2 "bifrons_fall_time" (`StrikePattern.fall_time()`) | 0.28 s |
| How the drop accelerates (and his lunge) | `StrikePattern.FALL_POWER` | 1.7 |
| His blade after a strike: lying / thrown back by a parry | `STICK_TIME`, `RECOIL_TIME` | 0.12 / 0.35 s |
| Hit window, "beat": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0 / 0.25 s |
| Hit window, "after": delay / length | `BREAK_DELAY`, `BREAK_TIME` | 0.18 / 0.3 s |
| Stagger length | `StrikePattern.BOTH_STAGGER_TIME`, `Sweep.STAGGER_TIME`, `Leap.STAGGER_TIME` | 2.2 s |
| Sweep: until it reaches the first player / on to the second | `Sweep.WINDUP_UNITS`, `TRAVEL_TIME` | 5 (1.0 s) / 0.26 s |
| Sweep: blade away / propped / swinging back | `Sweep.AWAY_TIME`, `PROP_TIME`, `RETURN_TIME` | 1.4 / 1.4 / 0.3 s |
| How often each attack comes, and where | the weights in `ColumnaBifrons.ATTACKS` | see the table above |
| Charge: how far (at least / past its player / at most), how long after the thrust, how fast | `CHARGE_DISTANCE`, `CHARGE_BEYOND`, `CHARGE_MOST`, `CHARGE_DELAY`, `CHARGE_TIME` | 230 / 70 / 360 px, 0.1 s, 0.25 s |
| Charge: how far he rears back | `StrikePattern.CHARGE_LEAN`, `POSE_LANCE_BACK` | 24 px, hand 18 px behind his middle |
| The sword that reaches across: where it strikes from, and lands | `POSE_SLASH_RAISED`, `_COILED`, `_DOWN` | over his shoulder |
| A blade's edge in its player's color | `EDGE_WIDTH` | 4 px of 12 |
| Leap: until he lands / rising / hanging | `Leap.WINDUP_UNITS`, `RISE_TIME`, `HANG_TIME` | 6 (1.2 s) / 0.22 / 0.2 s |
| Leap: how close to where he lands a player is hit | `Leap.REACH` | 80 px |
| Leap: knockback of a hit / push on a parry | `Leap.KNOCKBACK`, `PARRIED_PUSH` | x1.6 / 220 px/s |
| Where he stands: steps back from / to; walks up from / to | `CROWD_DISTANCE`, `FIT_DISTANCE`; `BLADE_REACH`, `REACH_MARGIN` | 62 / 90; 215 / 185 px |
| His drift: distances to the nearer player / speed / pause; off the middle between two | `DRIFT_NEAR`, `DRIFT_FAR`, `DRIFT_SPEED`, `DRIFT_PAUSE`; `PEP_DRIFT` | 80 / 170 px, 0.6 of that per s, 0.5 s; 60 px |
| Pushing through: touching / his pace / how long before he shoves | `TOUCH_DISTANCE`, `PUSH_PACE`, `PUSH_PATIENCE` | 50 px / half / 2 s |
| Walking: between attacks / during them | `WALK_SPEED`, `ATTACK_PACE` | 110 px/s / x0.5 |
| Walking: slowed by a sword hit | `SLOWED_FACTOR`, `SLOWED_TIME` | x0.3 for 0.6 s |
| Lunge: short / long / where the players are when it lands / never closer than | `LUNGE_SHORT`, `LUNGE_LONG`, `STRIKE_DISTANCE`, `CLOSEST` | 14 / 160 / 105 / 72 px |
| Long windup: from which wait, how fast he walks | `LONG_WINDUP`, `ADVANCE_SPEED` | 6 / 70 px/s |
| Making room: after how long crowded, how often | `CROWD_PATIENCE`, `ROOM_COOLDOWN` | 0.7 s / 4 s |
| Making room, the hop back: how far, how fast | `BACK_OFF_DISTANCE`, `BACK_OFF_TIME` | 110 px / 0.2 s |
| Making room, the shove: windup / how hard / whom it reaches / how close a player has to be | `Shove.WINDUP_TIME`, `PUSH`, `REACH`, `NEAR` | 0.5 s / 1050 px/s (230 px) / 215 px / 150 px |
| Left alone: until a sword turns / how near its player has to be for it to turn back | `TURN_TIME`, `RETURN_DISTANCE` | 1.5 s / 300 px |
| Left alone: the rush's dash | `RUSH_TIME` | 0.45 s |
| Heavy strike (both swords on one player): knockback | `StrikePattern.HEAVY_KNOCKBACK` | x1.5 |
| Room he leaves at the walls | `WALL_ROOM` | 90 px |
| How close a player has to be for a blade to reach them | `BLADE_REACH` | 215 px |
| Reactive: his wait | `REACTIVE_WAIT_MIN`, `_MAX` | 0.5 - 0.9 s |
| Reactive: parried hits before he strikes back | `PATIENCE` | 1, 1 or 2 |
| Reactive: his answer's first strike lands within | `ANSWER_WAIT` | 4 (0.8 s) |
| Stand-in: parried / blocked (the rest hits) | `BifronsStandIn.PARRY_CHANCE`, `BLOCK_CHANCE` | 0.75 / 0.15 |
| Stand-in: where it stands | `DISTANCE` | 95 px |
| Player: slash windup / cut / return | `ATTACK_WINDUP_TIME`, `_ACTIVE_`, `_RETURN_` (player_sword.gd) | 0.05 / 0.12 / 0.24 s |
| Player: recoil after being parried | `PARRIED_RECOIL` (player_sword.gd) | 0.45 s |
| Player: an early attack press still counts | `ATTACK_BUFFER_TIME` (player_sword.gd) | 0.15 s |
| Player: a dash this soon after a parry goes through him | `PASS_WINDOW` (player_body.gd) | 0.2 s |

For testing: `TEST_ONLY_PATTERN`, a list of attack names (e.g. `["CROSSING", "LEAP"]`): he
uses only those, each where it would come anyway; if none of them comes in the situation he's
in, he uses them all the same.

## What to look for in the playtest

- Does "you parry, I hit" feel like one action done together, or like two people each doing
  their own thing next to a metronome? **beat** (a bet on the partner) or **after** (watching the
  partner): which reads as co-op, and in which does it matter that the hitter reacted?
- **Ppe:** can you tell which sword is yours when both are on your side (the edge's color; over
  his head, or over his shoulder)? With the dash-parry, is changing sides now something you
  choose? If you leave it to him, ppe lasts about 10 to 15 s with bots.
- **The crossing:** is being passed something you can choose (stay, step in, back off)? Is the
  charge's windup right now, and the strike of both swords after it, with him coming back at
  you?
- **His moving:** does he keep a distance that feels right (he steps back from 62 px, to 90)?
  Is the lunge with every strike felt, and is having to follow him when he lunges at your
  partner good or a nuisance? Do you ever feel he walks when he should stand? (It needs more
  tuning in general: `TASKS.md`.)
- **Making room:** the hop back and the shove: does he stay around the middle of the room now,
  and does the shove read as "no strike"?
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
  problem depends on how it feels with people; the knobs are `PARRIED_RECOIL` and the tempo of
  his strikes. (Measured on the old health rules, with `SYNC_HIT_FACTOR` 2.5.)
- **Reactive:** does it flow, one exchange into the next? Is being struck back at once a fair
  answer, and does provoking feel like leading the fight?
- **The sweep:** can the second player read their moment (0.26 s after the first)? Do the four
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
