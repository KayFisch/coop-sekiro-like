# Horologium: a clock tower for two

The first level of the coop platformer (TASKS.md, "Prototyp Koop-Jump'n'Run"). A clock tower in
which everything strikes on **one shared clock**. Pick it from the select screen ("Horologium",
2 players). Idea: Kay's scribble of 2026-10-15, "Jump'n'Run-Hindernisse mit Rhythmus".

The ground rule: **no new movement abilities**. The level adds things to the world that the
verbs we already have act on (jump, dash, slash, parry, block), in time. It's built for the
**default kit** (F1 defaults: no double jump, no walls, no ledge grab), and every size is
computed from the player's constants and labeled in the room (blue lines, dashed heights).

A checkpoint takes only once **both** players stand at it (`GymLevel.checkpoint_needs_all`):
otherwise one could die on purpose, start over at the partner's flag and skip a coop obstacle.
Touching an obstacle or falling out puts you back at the last checkpoint; **R** does that on
demand. Nothing else hurts.

## The clock: `Beat` (core/beat.gd)

An autoload, the one clock for everything that goes in time. No obstacle counts time itself:
each one works out where it is from `Beat` alone, so they all stay in time with each other.

- **150 BPM, 4 beats a bar** (0.4 s a beat, 1.6 s a bar). That's already the game's hidden
  pulse: the call countdown ticks every 0.4 s, Sphaera's coupled pendulums swing on 0.4, Cubus's
  shockwave slashes on 0.2, a slash comes back in 0.41 s, a jump rises for 0.39 s.
- The level starts it (`Beat.start(bpm, level)`); it stops when the level leaves the tree. It
  runs on physics frames and carries the remainder from beat to beat, so nothing drifts. It
  pauses with the game (F1). **Within a level it's never reset or shifted**, not on a respawn,
  not on R: every obstacle stays in time with every other.
- A **click** on every beat, brighter on the 1; **M** switches it off and on.
  `AUDIO_LATENCY` (0 for now) moves judging later, if every hit reads late.
- Asking it: signals `beat(index)` and `bar(index)`; `time()`, `beat_length()`,
  `beat_in_bar()` (1-4), `phase()` / `bar_phase()` (0..1), `beats_at(t)`,
  `offset_to_beat(t)` / `offset_to_downbeat(t)` (signed, < 0 early), and
  `plays_on(n, pattern, offset)` for obstacles that describe themselves in beats.
- The tempo is constant here. The clock keeps where its tempo began (`_origin_beat`,
  `_origin_time`), so a tempo change on a bar's 1 can come later without moving earlier beats.
- **BeatDisplay** (`ui/beat_display.gd`): four dots, the current one lit, the 1 larger, and
  the BPM. Reusable anywhere (e.g. the beat-runner).
- In the background a great clock pendulum swings out to one side on every beat.

`Metronome` (levels/metronome.gd, the wall gym's) is a separate, older clock: 120 BPM, on the
real clock, started by a wall jump. It stays as it is for now (see TASKS.md).

## The obstacles (levels/obstacles/)

All four extend `Clockwork` (or, the bell, `GymTarget`), build their nodes in code, and have a
sound of their own on their beat. `GymLevel.obstacle()` adds one and puts whoever it `hit`s
back at the checkpoint.

### Hammer (`beat_hammer.gd`)

A block as wide as its head, reaching down from the ceiling, that slams into the floor
**exactly on its beats** (`pattern`, e.g. `[1]` or `[1, 3]`, and `offset` for waves).

| Phase | When | Tuning |
|---|---|---|
| draws up a little and glows | the beat before the hit | `DRAW_UP` 14 px |
| falls | the last 0.07 s before the beat | `FALL_TIME` |
| lies on the floor | half a beat after the hit | `HOLD_BEATS` 0.5 |
| rises back | over a beat; clears a player's head about a third of the way | `RISE_BEATS` 1 |

Once down it fills the corridor's height, so it can't be jumped over. Touching it anywhere
off its resting place (falling, down, rising) puts you back. Measured: a hammer on the 1 is
deadly from the hit until 0.88 beats after it, so the way under is open from the 2 to just
before the next 1.

### Beat step (`beat_step.gd`)

A one-way platform (jump up through it, down to drop) that is there only on some beats. Off: a
faint outline you fall through. On: filled. In its last beat before it goes, it blinks.

- **Clock mode**: on during its counts, e.g. two sets taking turns, `[1, 2]` and `[3, 4]`.
- **Call mode**: off until a bell calls it, then on until the time the bell says.
- **Owner**: both, P1 or P2. A P1 or P2 step carries only its player: it lives on that player's
  own physics layer (5 or 6, `GymLevel.OWN_PLATFORM_LAYERS`), which the level puts into that
  player's collision mask after spawning them, so `player.gd` doesn't know about it. Dropping
  through (down) lets go of these too. It has its player's color: player colors only ever say
  *who* (Kay's color scribble of 2026-10-02).

### Beat bell (`beat_bell.gd`)

A `GymTarget` struck with the blade. **What counts is the moment the blade hits it**, against
the nearest 1, not the button press.

- Within `BELL_WINDOW` (±0.1 s): a bright ring and a glow.
- Otherwise a dull clack, and the bell is **out of tune until after the next 1** (that 1 and
  its window included): mashing gets nothing (cf. Bifrons's mash problem).
- Either way it floats how far off the hit was, in ms, for tuning.
- **The rule in the shaft**: a bell struck on the 1 calls, for one bar, the steps of the
  striker's **partner**, never the striker's own, and only the ones of the sections that begin
  or end at its landing. They stay until the next 1 (plus the window, so a late but good strike
  on that 1 keeps them without a gap). Whoever keeps striking on every 1 keeps them there.

### Pendulum (`beat_pendulum.gd`)

A rod from a pivot in the ceiling with a heavy blade. It swings with the clock: through the
bottom on the 1 and the 3, at its turning points on the 2 and the 4, once there and back each
bar. Rod and blade both hit you, so it's a sweeping wall: no jumping over it.

- **Perfect parry** (block pressed in time, `is_perfect_parry()` as against the bosses): the
  blades lock. The pendulum stops and holds the parrier (`set_clashing()`, as in Cubus's
  grand slash) for **exactly one bar**. A bar is one swing, so it then goes on in time, away
  from the parrier, who is free again and ignored for 0.35 s so it can't hit them at once.
  A ring around the blade runs down while it holds.
- **Only blocked**: knocked away (`apply_knockback()`), nothing locks.
- The point: a held pendulum clears the way for the partner, but whoever holds it can't pass.

## The rooms (levels/horologium/)

The numbers below are for the current constants (jump 136, run 360 px/s, dash 140, launch
340, body 20 × 40); the code computes them.

| Room | What | Sizes |
|---|---|---|
| **0 Antechamber** | Flat. The click; a practice bell: strike it on the 1 and see how far off you were. Sign: "Everything here beats in the same time." | |
| **1 Hammerworks** | A low corridor. **a)** one hammer on the 1: go under it on the 2 to 4. **b)** a wave: four hammers on 1, 2, 3, 4, spaced so you follow it at an easy run. **c)** a canon: two wide hammers on the 1 and the 3 with a gap for one player between them (players collide). One goes through on the 2 into the gap and out on the 4, the other a turn later. | Clearance 120. Wave spacing 108 (¾ of a run per beat). Canon hammers 100 wide, gap 60 (3 bodies). Tested: a run plus a dash never gets through both in one window (all 16 start times hit); through on the 2, waiting in the gap, out on the 4 works. |
| **2 Bell shaft** | **a)** warm-up: four steps in two sets taking turns every two beats; jump on the change, up to the shaft floor L0. **b)** the climb: landings L0 to L3, each with a bell, and between them a P1 step and a P2 step at different places. "I ring, you climb, you ring, I climb." Falling lands you on a lower landing; nobody dies. | Warm-up steps 96 apart. Sections 232 (two jumps of 116), each crossed in about two jumps inside a bar. Out of reach without steps, also standing on the partner (40 + 136 = 176). Tested: every step and landing is reachable from where it should be; P1 falls through P2's steps. |
| **3 Pendulums** | Two pendulums. Under each, the sweep is too wide to cross alone between two passes, even with a dash. A balcony a jump up at each turning point, where the blade arrives on the 2 and the 4; under a blade held there is room to run. A parries from the left balcony and holds, B runs under and climbs the right balcony, B parries the pendulum coming back and holds, A runs under. | Hall 640, rod 600, balconies 120 up, 15 px outside the turning points (the blade reaches a player at the balcony's edge ~0.2 beat before the 2 / the 4). Swept 455 wide; a run plus a dash in the 2 beats between passes covers 378. Tested: alone, all 16 start times hit; held, the partner runs through. |
| **4 Belfry** | The great bell. Both strike it on the same 1: it tolls, the level is done (time and resets shown); Esc goes back to the menu. | |

A checkpoint at the start of every room and section.

## What to look for

- Does **150 BPM** suit platforming? Too hurried, too slow?
- Does the **click** help or get on your nerves (M)? Is the background pendulum enough without it?
- **Bell**: is ±0.1 s fair? Does judging the **blade's hit** rather than the press feel right,
  given the swing's windup? Is losing the next 1 after a miss too harsh?
- **Shaft**: teamwork or waiting? Is striking on the beat fun, or a chore while the other climbs?
  Is a bar enough for a section?
- **Launch skips a section**: a launch (340) is higher than a section (232). One player can be
  launched up to the next landing without the bells; the one left below still needs the
  other's bell. Fine as a second coop answer, or does it gut the shaft?
- **Pendulum**: is a bar of holding too long or too short? Is the parry on the 2 and the 4
  readable, when the blade reaches you just before the beat?
- **Canon**: does it work as a round? Is the gap (60) too tight to stop in?
- **Hammers**: is the rising hammer being deadly (until it clears your head) readable?

## Next, not built

- **Glockenspiel gate** (Simon says): a gate plays a sequence, the players play it back, split
  between both ("me, you, me, me, you"); a slash is a drum, a parry a bell.
- **Bell pull** (the rowing lift): a strike on the beat lifts it a step, off the beat it sinks;
  taking turns lifts it twice as fast.
- **Guardian statue**: guards a gap with exactly one attack in a fixed rhythm, in the bosses'
  color language; the trick is to use the attack (a parried blade as a pogo surface, a blow as
  a launch).
- **Tempo change**: only on a bar's 1, and announced (the great pendulum, the click, the
  display). The clock is ready for it (see above).
