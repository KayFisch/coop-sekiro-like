# Parkour gyms: two movement test rooms

Two playable rooms for feeling out the movement before designing real platforming levels:
the **Movement Gym** (1 player) and the **Duo Gym** (2 players). Pick them from the select
screen (3 and 4).

They aren't levels to beat. Each station puts one move against measured distances, so you can
find out what the movement *does*, where it's strongest, and which directions are worth
building levels around. Nothing hurts: falling out puts you back at the last checkpoint flag,
and **R** does the same on demand.

Every surface sits on a **32 px grid** (with a brighter line every 160 px, counted up from the
floor). Distances are drawn as blue dimension lines, and the key heights (jump, double jump,
launch) as dashed lines. The numbers are read from `player.gd`'s tuning constants, so they stay
right when you retune.

**The readout** (Tab toggles it) shows, per player: what they're doing (ground, air, wall slide,
ledge, clash, relay boost...), current speed, and for the last jump its peak height, air time and
distance, the last dash's length, the last launch's height, and which air moves are still
available.

## Movement switches (F1, anywhere)

**F1** opens a panel that turns movement abilities on and off; the game pauses while it's open.
Use ↑/↓ to pick a switch, ←/→ or Enter to change it, and F1 to close. The switches are saved in
`user://moves.cfg` and apply in the fights too. They live in `core/moves.gd` (the `Moves`
autoload); code asks `Moves.on("pogo")`.

| Switch | Default |
|---|---|
| Double jump, dash, dash-slash, upslash hop, fast fall | on |
| **Wall:** off / **slide** / cling | slide |
| Wall jump · wall/ledge contact refreshes the dash (never the air jump) · ledge grab | on |
| Pogo · pogo refreshes the air jump · pogo refreshes the dash · pogo off your partner | on |
| Launch · momentum relay · relay refreshes the dash · chimney clash · players collide | on |

## The new moves (`player.gd`, each with its tuning block)

- **Fast fall:** hold down in the air while falling. You fall with 2.2× the gravity, up to
  1900 px/s instead of 1300.
- **Walls:** in the air, press into a wall (or fly into it fast) and you stick to it, facing
  away.
  - **Slide:** you slip down at 140 px/s.
  - **Cling:** you hang still for 1.2 s, then slide.
  - Press away, or land, to let go.
  - **Wall jump:** jump off a wall you're on or touching, up and away. For 0.15 s you can't
    steer back, so it carries you clear of the wall. The wall you jumped off is then spent
    until you land, catch a ledge or reach another wall: you can't stick to it, jump off it,
    or get refreshed by it again. One wall alone can't be climbed; two facing walls (a
    chimney) can. Your partner doesn't count as a wall. A wall you're only touching counts
    if you're moving into it. For 0.26 s after a wall jump (about 94 px) you're "in flight":
    holding back toward the wall you left doesn't steer, and the wall you reach catches you,
    so you can chain up a chimney holding one direction and just timing the jumps.
- **Players collide:** players bump into each other and can stand on each other (a switch).
  Standing on your partner on a weighed pan counts as standing on the pan.
- **Ledge grab:** press into a wall whose top edge is between a little above your head and
  your middle, and you catch the edge and hang. Up (or holding toward it) climbs, jump jumps,
  and down or away lets go.
- **Pogo:** down (S or ↓ on the keyboard) + attack in the air slashes below you, Hollow Knight
  style. Hitting a target, a boss, spikes or (if switched on) your partner bounces you up
  110 px however fast you were falling. What it refreshes is up to the switches.
- **Chimney clash:** two players who both just wall-jumped, flying at each other, clash in
  mid-air. After a short hold (0.1 s) both are thrown back toward the walls they came from,
  160 px up. That's higher than a wall jump, so a chimney too wide to climb alone becomes a
  climb for two. Bumping into each other counts too, as long as you jumped off opposite walls.
- **Dash-slash windup:** a dash-slash first holds still for 0.15 s with the blade drawn back
  and heating to white, then dashes. That's the partner's cue to parry.
- **Momentum relay:** dash-slash into your partner and have them **parry** it: their block
  press must come at most 0.2 s before the blades meet. Just holding block (or pressing too
  early) only stops the dash with a dull clang and bounces the dasher off. On a parry the
  blades lock for 0.25 s, and during that time the dasher holds a direction: 8 ways (move,
  up/jump, down), or nothing to keep the dash's direction. Then the dasher boosts about 220 px
  that way with gravity off, keeping 45% of the speed afterwards, and the partner is pushed
  back the other way. It refreshes the dash but never the air jump.

## Movement Gym (1 player): `levels/gym/movement_gym.gd`

| # | Station | What's there | Questions it asks |
|---|---|---|---|
| 1 | **Run** | Flat track, ticks every 100 px | Does 360 px/s with near-instant start and stop feel right, or too stiff? |
| 2 | **Height** | Pillars at 96 / 136 (= jump) / 180 / 243 (= double jump) / 270 (= + upslash hop) / 310 | Is exact-max height landable, or does it need a margin? Does the upslash hop feel like a real extension, or a trick? |
| 3 | **Distance** | Gaps of 160 / 280 / 400 / 520 / 640 over pits, a checkpoint on each ledge | Which combination of jump, double jump and dash crosses each? Is the order of moves expressive? Is 640 possible? |
| 4 | **Dash** | Low tunnel (64 px clearance, no jumping) over holes of 100 / 140 / 180 | Is a gravity-free dash of exactly 140 px readable? Should the dash carry momentum out of a hole? |
| 5 | **Climb** | One-way ledges 110 apart (one jump each) and 220 apart (double jumps), drop-through | Is vertical play fun with this jump arc? Is dropping through (S) useful? |
| 6 | **Sword** | Dummies on the ground, 150 up and 260 up | How do slash, upslash and dash-slash feel as movement tools? Targets name what hit them. |
| 7 | **Walls** | A 130-wide chimney (90 px of travel for a 40 px body, just inside the 94 px wall-jump flight; walk in under its left wall), and a tall wall beside the walkway at the top | Wall-jumping up a chimney alone. Slide or cling: which feels better? |
| 8 | **Ledges** | Pillars of 180 / 200 / 280 / 330, with marks for "jump + grab" (206) and "double jump + grab" (313) | Does the grab reach feel generous or sloppy? Should climbing be automatic? |
| 9 | **Pogo** | A 900 spike pit with lanterns every 180 px, then a 700 pit with only spikes | Does the pogo feel natural? Try it with and without the refreshes (F1). |
| 10 | **Fall** | Lantern stairs up to a perch, then a 420 px drop onto a 60 px safe spot among spikes | Does fast fall help you aim a landing, or only speed it up? |

## Duo Gym (2 players): `levels/gym/coop_gym.gd`

| # | Station | What's there | Questions it asks |
|---|---|---|---|
| 1 | **Launch** | Bells at 200 / 280 / 340 / 400 / 460 up | How reliably can you time it? How high do you really get, and what can you do at the top (dash, double jump, strike)? |
| 2 | **Cliff** | A 330 px wall: out of solo reach, in launch reach. A **switch** on top opens a staircase | The first "one opens the way for the other" pattern. Does it feel like teamwork or waiting? |
| 3 | **Weight** | Free pans (twice as strong as the Scales': 90 px per player, max 100) and a ledge 330 up between them | Can weight alone get someone up there? Jumping takes your weight off, so timing matters. Is weight a good co-op verb outside the boss fight? |
| 4 | **Rope** | Stand on the cyan pad together to be tied (Shackle's 300 px rope). Leapfrog a 560 px pit over one island. The far pad unties you | Does anchoring (block on the ground) and swinging feel good? The rope is brighter when taut. |
| 5 | **Sync** | Two plates: land on them together | Shows how far apart the landings were, against Counterweight's 0.15 s window. Is that window fair? |
| 6 | **Targets** | Dummies 60 / 240 / 380 up | Strikes out of a launch. What attack flows out of the rise? |
| 7 | **Chimney** | 420 wide (a bell marks the top): too wide to wall-jump up alone, since you fall back before reaching the other wall | Is jumping off together easy to read? Is the clash's height and push-back right? |
| 8 | **Relay** | Bells to aim at (straight up, up and across), a 640 pit (beyond solo reach), and a high ledge over a lantern field for relaying straight down into a pogo chain | Is 0.25 s long enough to aim, short enough to flow? Which directions get used? |
| 9 | **Partner pogo** | A 700 spike pit with a pillar in the middle for the partner to stand on | Does bouncing off a partner feel like teamwork? |

## How it's built

- **`gym_level.gd`:** the base class. A room overrides `_build()` and places everything
  with helpers:
  - geometry: `ground()`, `solid()`, `pillar()`, `ledge()`
  - markings: `label()`, `station()`, `measure()`, `height_mark()`
  - `checkpoint()`, `target()`, and `spikes()` (a hazard that puts you back, and pogo-able)

  It also spawns the players, the camera and the HUD, and handles respawning. A new test room
  is a script plus a one-node scene.
- **`gym_camera.gd`:** follows the players and zooms out (down to 0.55) to keep two players who
  drift apart on screen. It shakes like the fight camera.
- **`gym_hud.gd`:** the readout. **`target.gd`:** dummies, bells, switches and pogo lanterns.
  **`weighed_pans.gd`:** free-standing weighted pans.
- **Controls:** the same as in the fights. Esc returns to the select screen.

## Ideas not built yet

The concept doc's platforming plans that still need new mechanics:

- **Mutual air parry:** both players in the air, one dashes into the other, and a timed clash
  transfers the momentum sideways. The momentum relay covers part of this.

Left out on purpose for now: crouch slide, hyper dashes, charged dash, grapple.

The gyms' results (which heights, distances and timings feel good) should decide which of these
come next.
