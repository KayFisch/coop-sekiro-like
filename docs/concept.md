# Untitled Co-op Action Game — Concept Document

## What is this?

A 2D co-op action game built in Godot 4. Two players fight bosses together, but unlike most co-op games where cooperation just means two people doing the same thing side by side, the core mechanic here requires players to act *through* each other. The game is built around the idea of learning a duet — two players developing a shared combat language over time.

This is currently a **prototype**: one test boss (Columna Bifrons) with placeholder visuals, movement gyms, a coop platformer level built with the level kit, and two prototypes for what comes between the bosses. The goal of the prototype is to prove that the core mechanic feels good before building anything else.

---

## Core mechanic — the parry relay

Combat is sword-based. Players attack with their sword, and holding block reduces incoming damage. But the skill expression is in the **perfect parry**: pressing block at the exact moment the boss sword makes contact deals no damage and triggers a relay.

A relay means the boss's attack is redirected to the second player, who now has their own parry window. If the second player also perfect parries, the boss staggers and both players get a free window to deal damage. Nail the chain and you deal significantly more damage. Break it and you both pay for it.

Not every attack is parriable: each boss has a vocabulary of attacks that ask for different responses (the current one's: `docs/boss_columna_bifrons.md`; the first two bosses, Cubus Maximus and Sphaera Pendula, were dropped on 2026-10-18).

Each attack is telegraphed by color so players can read what's coming and coordinate their response without needing to talk.

---

## Blade rules: additions (2026-10-19)

### One parry per blade

A **heavy** attack is one where **two blades fall on the same place**. There it takes two to
parry: a player can still parry it, but unless the partner parries too, the parry only has the
effect of a block. The boss aims where his blades can reach someone:
if one player is out of reach, both blades go to the other.

- Both swords in **ppe** (both players on one side): must be parried together.
- Both swords in **pep**: one blade on each player, i.e. two normal parries at the same time.
  Both parry: stagger. Only one parries: it still counts as a parry (not downgraded to a block).

### Knockback depends on the outcome

A strike that throws a player back: **parried → no or half knockback; blocked or hit → full
knockback.**

### Stagger after a finale

Co-op parrying a finale staggers him for **0.5 s plus 0.2 s for every successful parry in the
chain, finale included** (starting values). Not tied to his posture: a long stagger on top of
high posture damage would snowball.

### The partner's sync hit: after, not on the beat

The sync hit comes **after** the partner's parry, not at the same moment (in Bifrons's fight
"after" is already the default: `docs/boss_columna_bifrons.md`, "The partner's hit"). Exactly how
late, and what it depends on (a fixed delay, per attack in note values, the boss's tempo), is
open.

---

## Sync as life

Nobody has health. The two players share one **sync**, the boss has his own, and each of the three has a posture, by the same rules on both sides. Playing together (a hit through the guard the partner's parry opened, parrying both his swords at once) wins the players sync back; the boss can't win his back. At full sync the players are in the sync mode (see "The sync mode" below); at none, in chaos, the next hit ends it. Details: `docs/boss_columna_bifrons.md` ("Sync as life"), `core/sync_rules.gd`.

---

## The sync mode (all bosses)

**Intent:** a tangible reward, like a deathblow in Sekiro (perfect play ends the fight early,
with a cool animation), but more gameplay than one button: anything from a few inputs to free
fighting, and **not a quicktime event**. It asks for the same kind of sync actions as before
(parry together, strike together) without overwhelming.

**Model: the players' boss phase.**
- It **ends the fight by default**, but feels like a phase of its own.
- Short: **half a minute to a minute**, depending on the boss's remaining sync.
- The boss answers with **his own sync-mode reaction pattern** (one or two per boss), made for
  the sync mode (giving enough time); per boss with parrying, striking, maybe more.
- **How the players land their hits is up to them.**
- It ends when **his sync is empty** (finisher: deathblow animation) or **the players' sync
  falls below the sync-mode threshold** (back to the normal fight).
- **Pair strikes deal a lot**; how many are needed follows from his remaining sync. No cap:
  players who reach the sync mode early (more boss sync left) are rewarded by burning it down
  much faster than they could without.
- Per boss: the windows for pair strikes, and how the bound pair moves.
- No deliberate unbinding for now.

**Moving while bound** (candidates, chosen per boss): one moves the pair and the other starts
the cue, both strike on the cue's end; or the verbs are split (one walks, the other jumps /
dashes). Ruled out: steering together (frustrating and unresponsive; parrying and striking
together is enough sync), steps on the beat / a quicktime event (dull, no sense of control),
free movement with an elastic tether, switching roles after every pair strike (chaotic). When
roles switch is open.

---

## The two screen halves

The mirrored screen is the **foundation for the boss fights** (Nicho and Kay). Players can
choose between the mirrored and the one-sided view and switch freely: mirrored, they never
block each other (good for fights); one-sided, they interact directly (good for Kay's co-op
platformer). Whether the mirrored view runs through the whole game is open.

**The halves are not a pure mirror but two connected sides** that needn't be identical (the
players act independently most of the time). **Each half shows the boss from its player's point
of view:** the blades aimed at that player stand out; a blade not aimed at them keeps its guard,
as usual. One blade aimed at you: you're on your own. **Two blades in your half: heavy, you need
your partner.**

Why: today, when he strikes one player, the sword moves in the other half too and slashes the
air there (in ppe as well). That's sword chaos, and it doesn't show what makes a heavy attack
different.

Open, to be tested (F1 "mirror_blades", `docs/boss_columna_bifrons.md`): how the foreign blade
steps back in your half:
- **a. it doesn't move** there;
- **b. it moves, but with low contrast** against the half's background; a heavy attack makes it
  stand out in both halves ("he manifests his second sword in the wrong layer"). Claude's
  recommendation: b (one body, one motion; you still see the strike on your partner and can
  time your sync hit; the heavy tell comes for free).

In the sync mode the halves merge: the lower player flows into the upper one, and the focus
moves to the shared part (the upper half).

---

## Boss design principles

Decided 2026-10-19. These hold for every boss from now on; the try-out boss (today's Columna
Bifrons, see "Bosses") stays as it is.

### Sekiro, not Hollow Knight

Bosses don't throw single attacks to dodge with a gap to hit back in between. Like Sekiro's,
they build a rhythm that can hold for a long time. Strikes never stand alone: they come in
chains that extend fluidly (Genichiro). Big moves are combos that make sense in themselves.

### Chains, not patterns

A boss doesn't pick from a table of fixed patterns. It builds **chains** from a small grammar:
**strikes** (the rhythm) and **one finale**. A chain repeats a short **motif** (e.g. R R L)
until something happens (e.g. his posture is low), then ends with a finale, then a pause. Each
boss has only a few motifs (2 to 3) and a few finales. (To try the grammar before any boss has
its own motifs: the try-out boss's chains mode, `docs/boss_columna_bifrons.md`, "chains".)

### Phrase, then breath

Every chain is a phrase. After it comes a **pause in which the boss's posture can come back**,
if the players let it. The pause belongs to the players: pressing him keeps his posture down,
but costs them posture on his parries and draws his answer (the next chain, starting at the
attacker); backing off lets both sides recover. The old "patterns" and "reactive" modes become
one: chains are his initiative, pauses are theirs. **He doesn't stand still in the pause; he
moves** (repositions, turns).

Why: today's Columna Bifrons attacks almost nonstop, his posture comes back only 4 to 10 % of
the time, and his sync barely matters. The old reactive mode felt empty because he was slow
between attacks and didn't move.

### The boss reacts to what happens

The fight shouldn't feel like a fixed sequence. Model: the sweep, whose outcome depends on
which sides were parried. But:

- **Few reactions**, and not everything gets one. There are **recognizable moments** where the
  reaction matters.
- **Reactions change details, not the sequence:** roughly the same happens, but who is attacked
  next or how far someone is thrown changes. A single player action (e.g. a co-op parry at the
  start of a combo) never cancels the rest of it.
- At most 2 to 3 outcomes per finale.
- A consequence is **a chain start with a given first link** (e.g. "the next chain starts on
  the player who missed"), so reactions reuse the same building blocks instead of needing an
  animation each.

Things a boss may react to: how well the chain was parried; which strike was (not) parried;
whether a pushed-away player comes back or stays away; whether his attempt to change the
formation failed.

### Readable, not controllable

Players should recognize patterns and see what he does, when and why, without being able to
steer him.

1. **One motif per chain**, visibly repeated. Within a chain you learn the motif; over the fight
   you learn his 2 to 3 motifs.
2. **Decisions only at fixed points:** the end of a motif repetition. Players know *when* a
   branch can come, not *which*.
3. **Every decision hangs on something visible:** his posture, distance, formation, the outcome
   of the last link.
4. **Same situation, (mostly) same reaction.** Randomness only in which motif and how many
   repetitions, never in reactions to what the players did.
5. **Every finale has its own clear telegraph.**

### Telegraphs

Finales are told apart by what they are. The weak spot is motifs made only of normal strikes:
today they differ only in the length of the first windup. **Each motif needs a visual tell
before it** (e.g. one sword held briefly at a certain angle; a small step back).
Windup and hold already exist; **the strike itself must be fast and hard**, so it's clear when
the blade can be parried (today the sweep and the crossing thrust come too slowly).

### Few attacks, a distinct boss

Each boss has a **distinct vibe**, a signature mechanic and **few attacks**, each clearly
telegraphed (like bosses in Sekiro or Hollow Knight, even where some tells look alike). Bosses
are designed from their identity, not picked from "everything we've built". Attacks that fit no
boss go to the attack pool (`docs/attack_pool.md`) with a note on who they might suit.

### Formation: who controls it

Switching sides is a basic verb of every fight (pep / ppe and the dash-parry are player
rules). What sets the bosses apart is **who controls the formation**:

- **Columna Bifrons, the Warden:** he *sets* it; the players react (good players can resist).
- **The Heavy Hitter:** he *forces* it to change; *how* is up to the players.
- **The Acrobat:** he *moves himself* all the time; the formation shifts because the players
  chase him.

---

## Bosses

- **Try-out boss** (today's Columna Bifrons; stays as it is, needs a new name): the workbench
  for rules and systems and raw attack ideas. `docs/boss_columna_bifrons.md`.
- **Columna Bifrons, the Warden of the Threshold:** new, designed from scratch.
  `docs/boss_bifrons_warden.md`.
- **The Heavy Hitter** (working title): next to be designed. `docs/boss_heavy_hitter.md`.
- **The Acrobat** (towards Lady Butterfly): later; one of his phases is the beat ring
  (`docs/beat_ring.md`).
- Cubus Maximus and Sphaera Pendula, the first two, were dropped on 2026-10-18.

Open: **passing through a boss.** Idea: only weapons stop a dash, not the body (the Warden's
long vertical swords are walls; the Heavy Hitter's level weapon can be jumped over, and when he
jumps you can pass under him). Alternative: only Bifrons can't be dashed through.

---

## Moveset

The fight kit is built for the parry duet: each player's freedom is small, and the big moves take both of you. The platforming kit (walls, ledges, the relay, the chimney clash) is on everywhere too, with no room switching anything: every move is always there. F1 in game shows every switch, to switch one off and compare.

**Alone**
- **Run, jump** (136 px), drop through one-way platforms (down).
- **Dash**: the way you face (hold a direction and press dash on the same frame to dash that way). 140 px, no invulnerability, 0.6 s cooldown, one per trip into the air. Only landing or a Launch gives it back.
- **Slash, upslash** (up + attack), **downslash** (down + attack in the air). A downslash never hurts the boss or bounces off him.
- **Block / perfect parry**: press block at most 0.133 s before contact.
- **Dash-slash** (dash + attack): held to charge (the blade flares on every beat of the clock), let go on a beat: a quick thrust through the dash that meets the next beat. Let go off the beat, the blade fumbles. It stops at his body, but the blade still lands.

**Together**
- **Launch**: a dash-slash into the partner's upslash throws the dasher 340 px up.
- **Relay**: what the partner can make of a dash-slash, as a bar of the clock: let go on 1, the partner parries it as it meets them on 2, then strikes on 3 and throws the dasher the way they aim (4 ways), who hangs at the top on 4.
- **Pogo clash**: a downslash onto the partner's upslash bounces the falling player 110 px. Nothing else bounces a downslash in a fight; outside them, pogo points do (a gym's lanterns).
- **The tell**: a dash-slash headed at the partner puts a ring in the dasher's color around them. It closes 0.08 s before the blades meet, which is the moment to press (block for a relay, upslash for a launch).
- **Standing on each other**: players collide.

**A boss's body**: nobody walks, dashes or jumps through it, and nobody stands on it: landing on top slides you off the side you came from. A perfect parry landed mid-dash carries you through it (the dash-parry).

| Switch | Default |
|---|---|
| dash, dash_slash, launch, players_collide | on |
| pogo (the pogo clash, and pogo points) | on |
| boss_body, parry_pass (the dash-parry) | on |
| relay | on |
| wall_jump, ledge_grab, chimney_clash | on |
| wall | slide (off / slide) |
| wall_rhythm | on |
| pogo_refresh_dash (a pogo point gives the dash back) | off |
| swap_controls | off |

Settings are saved in `user://moves.cfg` with a version. When the defaults change, the version goes up, and an older save is reset to the new defaults once.

---

## Beyond the boss fight — platforming levels

*Parked for now: the fight comes first. Its moves are in the moveset everywhere (see above); the gyms and the kit rooms try them out.*

The second pillar of the game is cooperative platforming. Like the combat, the platforming is built around timing interactions *between* players rather than just having two people traverse the same level. Planned mechanics include:

- One player dashes into the other, who times an upslash to launch them vertically
- Both players airborne, one dashes into the other and both attack in a window that acts as a mutual parry, transferring momentum horizontally
- Synchronized wall jumps in alternating rhythm to climb a shaft
- One player acts as a moving platform or anchor point for the other

The throughline is the same as combat: **neither player is just watching while the other does something**.

---

## Inspirations

- **Sekiro: Shadows Die Twice** — the parry as the primary combat verb, rhythm-based sword clashes
- **Cuphead** — boss as a shared mechanical puzzle for two players, readable attack patterns, both players occupying the same small arena
- The concept sits in a design space neither of these games occupies: cooperative deflection where one player's action creates the precondition for the other's

---

## Current prototype scope

- One test boss: **Columna Bifrons**, fought from both sides at once, in his room, the Threshold (`docs/boss_columna_bifrons.md`)
- Movement gyms (`docs/parkour_gyms.md`), a coop platformer level built with the level kit (Horologium, `docs/level_kit.md`), and two prototypes for between the bosses (`docs/beat_runner.md`, `docs/beat_ring.md`)
- Two players: keyboard and gamepads (one pad each)
- Systems in place: parry relay, sync as life (a shared sync, posture, the sync mode), one clock for everything in time with music (`Beat`), screen shake, procedural audio
- Not yet built: more bosses (planned: see "Bosses"), art, online multiplayer

---

## Tech

- Engine: Godot 4 (GDScript)
- Version control: GitHub
- No external assets in the prototype — all visuals are procedural shapes, all audio is synthesized via AudioStreamGenerator
