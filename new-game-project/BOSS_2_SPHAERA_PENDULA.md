# Boss 2 — Sphaera Pendula, in "The Scales"

Design document for the second boss fight. Part 1 analyzes the Cubus Maximus fight as it
exists in code today; part 2 designs the new fight, drawing on what the first one does well
and filling the gaps it leaves.

---

## Part 1 — Analysis of fight 1 (Cubus Maximus)

### What the fight is

A grounded, sword-wielding brawler (1000 HP) in a static box: floor at y 600, walls at the
sides, three one-way platforms (left and right at y 480, middle at y 370). Every attack runs
the same state machine (`IDLE → TELEGRAPH → ATTACKING → RECOVER/STAGGER`) and is announced by
a color. The main source of damage is the stagger: a stagger opens a window for free sword
hits, and counters deal bonus damage scaled by the sync multiplier.

| Attack | Color | Player verb | Co-op structure |
|---|---|---|---|
| Jump Attack | yellow | parry | **Sequential relay**: P1 → P2 → P1, and the last parry staggers him |
| Triple Stab | yellow | parry ×3 | **Tank and punish**: one player holds the clash, the partner strikes |
| Grand Slash | blue (center) | parry | **Simultaneous join**: the first parry holds him, the partner's parry overpowers him |
| Shockwave Slashes | red (center) | parry on a beat | **Parallel rhythm, shared payoff**: both counters landing together deal double and stagger |
| Grab | purple | dash | Solo test |
| Ground Slam | green | get airborne | Solo test |

### What works

- **A readable color language.** Each color stands for one response (yellow = parry,
  purple = dash, green = get off the floor, blue = parry together, red = rhythm). Two players
  can coordinate without talking.
- **Good anticipation and release.** Every attack uses squash-and-stretch with a slow,
  loaded build-up and then a sudden snap (`JUMP_FALL_POWER = 10`, `DIVE_ACCEL_GROWTH`). You
  can read the attacks without feeling cheated by them.
- **Several co-op structures.** Relay, join, parallel and tank-and-punish each test a
  different kind of timing between the players.
- **Rewards scale with coordination.** A single player's success gets a small reward, and
  both succeeding together gets the stagger or double damage.

### Gaps (what fight 2 should explore)

1. **Where the players stand relative to each other barely matters.** The fight tests
   timing only. Only the grand slash join cares about distance at all, and even there only
   as "get there in time". None of the attacks require the players to be apart, together, or
   a set distance apart.
2. **Two of six attacks leave the partner with nothing to do.** In the grab, the partner
   watches their friend get lifted and slammed, with no way to rescue them. That breaks the
   rule in CONCEPT.md: *"neither player is just watching while the other does something"*.
3. **Players never act *on each other*.** Every interaction between the players passes
   through the boss. The planned platforming verbs (dash into partner → upslash launch)
   don't exist in combat yet.
4. **The arena doesn't matter.** The platforms only matter for the ground slam, and nothing
   changes the geometry.
5. **Mostly one verb.** Four of the six attacks are answered with a perfect parry.
6. **No escalation.** Attack weights are flat for the whole fight, with no phase change at
   low HP.
7. *(Housekeeping)* `cubus_maximus.gd` currently ships with `TEST_ONLY_ATTACK = "GROUND_SLAM"`
   and `TEST_ONLY_TARGET = 2` set, which are test flags left on in the working tree.

Fight 2 keeps what works (the color language, the anticipation and release, stagger as the
reward) and puts its innovation into gaps 1–6.

---

## Part 2 — Sphaera Pendula

> **Status: implemented.** Pick it from the boss select screen (the game's main scene now).
> The code is in `actors/bosses/sphaera_pendula/` and `levels/scales/`. Every tuning value
> below is a constant at the top of its file, in the same style as Cubus's attacks.

### Identity

**Sphaera Pendula** (*"the hanging sphere"*) is a massive iron sphere on a chain, hung from
the fulcrum of a giant balance scale. Cubus Maximus is a cube with a sword who **walks,
leaps and cuts**. Sphaera Pendula **swings, drops and reels**. It never touches the ground
voluntarily. Every movement it makes follows an arc or a plumb line, driven by momentum
rather than footwork.

- **Silhouette:** a disc (radius 44) with a single slit eye that slides toward its target, on
  a chain of alternating links. It has no hands and no sword, and the chain is its weapon.
- **Movement:** pendulum timing throughout. It is slow at the ends of each swing and fastest
  at the bottom, which is the Sekiro read of "long wind-up, sudden snap" carried over into
  physics.
- **What the fight teaches:** fight 1 taught the players *when* to act together. Fight 2
  teaches them *where* to stand relative to each other, and how to act *on each other*.

### The arena — The Scales (`levels/scales/`)

```
 x:  24                             476       576      676                             1128
 y 16 ═══════════════════════════════════════╤═══════════════════════════════════════════
	  │  (pan chains)                   anchor (576, 50)                  (pan chains) │
	  │                                      │                                         │
	  │                                      ●  ← Sphaera Pendula (home: 576, 250)      │
 y 470 ██████████████████████████████        │         ██████████████████████████████████
	  │        LEFT PAN (452 px)     │  THE PIT (200)  │        RIGHT PAN (452 px)      │
											 ▼
								   fall below y 780 → damage + respawn
```

- **Two pans** (`AnimatableBody2D`, so the players standing on them ride along) on either side
  of a **central pit** with no floor.
- **Weight moves the pans.** A player standing on a pan weighs 1 and **a player in the air
  weighs 0**. Attacks can add weight (the sphere resting on a pan weighs 3) or push a pan
  down past its range. The heavier pan sinks `PAN_STEP` (45 px) per unit of difference, up to
  `PAN_MAX` (120), on a spring, so the motion lags a little and can be read.
  - Split (one player per pan): both pans level.
  - Both on the left: left sinks 90 px and right rises 90 px.
  - **Jumping moves your partner.** If you're split and you jump, your partner's pan sinks.
- **The pit:** falling below y 780 costs `PIT_DAMAGE` (15) and respawns you on the higher
  pan with a second of invulnerability. It should cost you position, not end the run.
- **No floating platforms.** Height can only be gained through the pans or through a partner
  (see *Launch* below).

### New player moves: dash-slash, upslash and the Launch (`player.gd`)

Every fight has these three, including the old one.

- **Dash-slash:** dash and attack at the same time, or attack a moment before the dash
  (`DASH_SLASH_LEAD` 0.1 s before, or `DASH_SLASH_LATE` 0.06 s after the dash starts). You
  dash with the sword thrust out level in front of you, drawn out to 1.5× its length and
  white-hot, leaving afterimages behind, and it hits the whole way (`DASH_SLASH_DAMAGE` 15,
  against 10 for a slash).
- **Upslash:** **attack while holding up** (P1 **↑ + Space**, P2 **stick up + X**). A rising
  cut from low in front to straight up, with a little **hop of a fifth of a jump's height**
  (`UPSLASH_HOP_HEIGHT`). The hop works once per trip into the air, like the dash, and the cut
  itself can be repeated. Pressing up at most `UPSLASH_LATE` (0.06 s) after the attack still
  counts. In the air it's an air upslash.
- **P1's keyboard is two-handed:** the left hand moves and jumps (WASD), and the right hand
  dashes (←/→) and looks up (↑). Moving and dashing no longer compete for the same fingers.
- **Launch:** when a dash-slash runs into the partner's upslash, the blades clash and the
  dash's momentum turns upward. The dashing player shoots up about 340 px (`LAUNCH_HEIGHT`,
  2.5× a jump), keeping a sliver of sideways speed (`LAUNCH_CARRY` = 15% of the dash, about
  150 px/s, kept until you steer). Their air jump, dash and hop are refreshed.
  - **Timing:** the upslash must come at most `LAUNCH_TOLERANCE` (0.15 s) before the blades
    meet, like a parry, or while the dash-slash is still passing through. The blades meet when
    the dasher is within `LAUNCH_REACH` (70 × 50 px, center to center) of the upslasher. In
    practice, the upslasher swings as the dasher arrives.
  - Worth `+5` sync, at most once every 5 s.

It is the only way to reach the ceiling beam and the easiest way from a sunken pan to a
raised one. Getting it into combat means the platforming levels later build on something the
players already know.

### Color language (extended)

The colors from fight 1 keep their meaning, and three new ones are added for the new verbs.

| Color | Meaning | Used by |
|---|---|---|
| Yellow | Perfect parry, relay | Pendulum Swing |
| Purple | Dash through it | Hook |
| Green | Be airborne | Undertow |
| Blue | Parry **together** | Shackle's catch |
| Red (center charge) | Rhythm | Coupled Pendulums |
| **Cyan** *(new)* | Shackled: move as a pair | Shackle |
| **Orange** *(new)* | Weight: land together | Counterweight |
| **White** *(new)* | Launch your partner | Zenith |

---

### Attacks (`actors/bosses/sphaera_pendula/attacks/`)

Seven attacks: six from the start and one unlocked in phase 2. Every attack gives both
players something to do.

#### 1. Pendulum Swing — yellow · relay with rising energy (`pendulum_swing.gd`)

**Telegraph (1.0 s):** it draws back up its arc on the far side of the pit from the target,
trembling at the top.

**Execution:** it swings down through the pit and across the target's pan, **skimming the
surface** (its bottom just clear of the pan). A perfect parry doesn't stop it. It **bats it
back** across the pit at the partner, **15% faster each time** (`SWING_TIME_DECAY`), like
pushing a swing. On the 4th parry (5th in phase 2) it **goes over the top**: it loops around
the anchor, the chain wraps the beam, and it drops to hang dazed low over the pit
(**2.0 s stagger**).

- **It requires one player on each pan.** The swing always crosses the pit. With the partner
  on the parrier's own side, the batted-back swing sails over empty space and the relay ends.
  The first swing comes down steeply on the partner's side, so it never hits the partner
  waiting there.
- **Weight affects your partner's contact.** The pan heights are read when each swing
  starts. If your partner jumps while the swing is on its way to you, your pan sinks under
  its path.
- **Jumping over it** dodges it: no damage, but no relay either. Blocking takes chip damage.

#### 2. Hook — purple · dodge, or be rescued (`hook.gd`)

**Telegraph (0.9 s):** it hangs still, pulsing purple, while the hook unfolds below it.

**Execution:** the hook shoots out on a chain and homes in on one player (1400 px/s, faster
than a dash). The dash timing is the same as Cubus's grab. A clean dodge pulls the hook back
empty and makes the sphere spin (**0.8 s tumble stagger**).

**If caught:** the chain yanks the player off into the pit, where they **dangle as a
pendulum** under the sphere while it reels itself up toward the beam over 1.8 s
(`REEL_TIME`). At the top, they're crushed (40 damage).
- **The partner** gets the flashing "your turn" marker and has to **hit the taut chain twice**
  (`RESCUE_HITS`) with any sword move (slash, upslash or dash-slash; one hit per swing).
  Cutting it drops the freed player with their air moves refreshed. The sphere recoils
  (**0.6 s stagger**).
- **The hooked player** swings the dangle with left and right toward the partner's pan edge,
  where the chain is easy to reach.

#### 3. Undertow — green · get airborne, but weight decides where (`undertow.gd`)

**Telegraph (1.1 s):** it drops into the pit and vanishes below, and its chain creaks.

**Execution:** three rams. Before each one, **the heavier pan shudders** (0.4 s warning).
Then the sphere rams up from under that pan and kicks it up. Anyone standing on it takes 22
damage and is thrown up, and anyone in the air is safe. The weight is read afresh for each
ram. **With someone standing on each pan and the weight balanced**, it can't pick a side:
it bursts up through the pit instead and **hangs exposed for 0.8 s**, in reach from both pan
edges (+10 sync).
- The first ram punishes wherever the players stand. Players who split up and **stay
  grounded** turn the rest into openings.
- Being thrown into the air by a ram doesn't count as balance. With nobody standing on
  either pan, it goes for the side most players are over.

#### 4. Counterweight — orange · land together (`counterweight.gd`)

**Telegraph (1.2 s):** the chain lets go and reels up empty. The sphere drifts over the
target's pan and follows them, while its orange shadow grows on the pan.

**Execution:** it drops onto the pan (25 damage to anyone right under it). Its weight of 3
slams that pan down and throws the other one up. Then the sunk pan **keeps sinking** toward
the pit over 3.5 s, with a bar over the sphere showing the time left. Anyone still on it when
it's gone falls into the pit.
- **The counter:** both players **land on the raised pan together**, after real jumps
  (at least 0.35 s in the air) and within `SYNC_LAND_WINDOW` (0.15 s) of each other. The
  seesaw throws the sphere into the beam (50 damage × sync multiplier), and it drops into the
  pit dazed (**2.2 s stagger**).
- **A single landing** lifts the sunk pan a little (0.4 s of sinking undone), which buys
  time but doesn't win.
- The target starts on the sinking pan and has a long climb up and across the pit. A
  partner's **Launch** makes it easy.

#### 5. Shackle — cyan, ending blue · a rope that becomes a net (`shackle.gd`)

**Telegraph (1.0 s):** two cyan cords snake out to both players.

**Execution:** the players are **shackled to each other** by a 300 px rope. Past its length,
it pulls the two together, moving whoever gives more: a player in the air swings freely, a
grounded one digs in, and **one blocking on the ground holds fast**, anchoring a partner who
fell into the pit.
1. **Two low sweeps (cyan):** it skims the pans wall to wall, one way and then back. Jump
   them. **What hits one shackled player hits both** (18 damage each).
2. **The catch (blue):** it climbs high on one side, turns blue, and swings down through the
   middle across the rope. If the rope is **taut** (within 40 px of its full length), it
   **catches the sphere like a net** and holds it for 0.6 s. Both players then **parry within
   0.25 s of each other** to **slingshot** it into the beam (60 damage × sync, **2.0 s
   stagger**). If the rope is slack, or the parries miss or come out of step, it tears through
   and hits both (30 each).

This is the first attack where the right answer is a **distance between the players** rather
than a moment in time.

#### 6. Zenith — white · launch your partner (`zenith.gd`)

**Telegraph (1.2 s):** it reels all the way up to the beam.

**Execution:** it spins there, winding its chain around the beam for 4 s, with a white bar
running down under it. When the bar is empty it drops as the **Grand Plumb**, and the impact
hits both players wherever they are (35 damage, unavoidable).
- **The only way to stop it** is to hit it at the beam. Its bottom sits just above the best a
  lone player can reach (jump, double jump and upslash hop), so **one player has to Launch the
  other**. A hit knocks it loose, and it falls to hang dazed over the pit (**2.5 s stagger**,
  the longest in the fight).
- While winding, it **drops chain links at the players on the ground**, taking turns between
  them. They can be parried or blocked, and a link that hits the launcher mid-setup can ruin
  the launch.
- Zenith is always the fight's **3rd attack**, so the players learn the Launch early.

#### 7. Coupled Pendulums — red center charge · your miss hurts your partner (phase 2; `coupled_pendulums.gd`)

**Telegraph (1.2 s, center charge):** it floats to the center, and on execution it shrinks to
a hub and **splits into two smaller spheres** on chains, one per player.

**Execution:** each half swings at its player on a shared metronome (`BEAT` 0.4 s; P1 on beats
1, 3 and 5, P2 on 2, 4 and 6) and bounces back off them. The counter above each player (0/3)
tracks their parries.
- A **perfect parry** keeps the energy in your own pendulum.
- A **block or a hit leaks energy into your partner's pendulum**. It gets visibly bigger and
  darker, and its swings deal **+50% damage per leak**, *on the same beat*.
- **All six parried:** the halves swing back in phase and collide under the hub (60 damage ×
  sync, **2.0 s stagger**).

---

### Fight structure (`sphaera_pendula.gd`)

**HP:** 1200. The fight is longer than Cubus's, but its staggers are longer and it can be hit
from both pans while it hangs dazed over the pit.

| Attack | Phase 1 weight | Phase 2 weight |
|---|---|---|
| PENDULUM_SWING (repeatable) | 1.5 | 1.5 |
| HOOK | 1.0 | 1.0 |
| UNDERTOW | 1.0 | 0.8 |
| COUNTERWEIGHT | 0.8 | 0.8 |
| SHACKLE | 0.8 | 0.8 |
| ZENITH (always the 3rd attack) | 0.6 | 0.6 |
| COUPLED_PENDULUMS | – | 1.2 |

**Phase 2 (at 50% HP):** the sphere cracks, its eye turns red, and there is a burst and a
screen shake. The pans get 1.4× more sensitive to weight, the relay needs 5 parries, and
Coupled Pendulums joins the pool. (The invulnerable transition spin from the first draft was
left out. It would only have delayed the fight.)

For testing, `TEST_ONLY_ATTACK` and `TEST_ONLY_TARGET` work as they do for Cubus.

### Sync meter gains (`game_manager.gd`, `SYNC_GAINS`)

| Event | Gain |
|---|---|
| Swing parried (each) | +6 |
| Swing relay completed (over the top) | +25 |
| Hook dodged | +15 |
| Partner rescued from the Hook | **+25** |
| Undertow exposed (balanced) | +10 |
| Counterweight catapult | +30 |
| Shackle: both sweeps cleared | +8 |
| Shackle: slingshot | +35 |
| Zenith interrupted | +25 |
| Launch (anywhere, at most once per 5 s) | +5 |
| Coupled: parried (each) | +6 |
| Coupled: collision | +30 |

A pit fall costs the same as a hit (−10).

---

### How the design answers the gaps

| Gap in fight 1 | Answered by |
|---|---|
| Positions relative to each other don't matter | The Scales' weight, Swing's pan split, Shackle's taut net, Undertow's balance |
| The partner watches during the grab | The Hook rescue (partner cuts the chain, hooked player swings the dangle) |
| Players never act on each other | The Launch, the rope, Counterweight's joint landing |
| The arena is static | Pans that move with every jump, and a pit |
| Mostly one verb (parry) | Positioning, joint landings, launching, striking the chain, jumping in pairs |
| No escalation | Phase 2: Coupled Pendulums, more sensitive pans, longer relay |

---

## Implementation notes

- **`BaseBoss` no longer knows about swords.** Cubus's sword and hands (and their constants)
  moved into `cubus_maximus.gd`. `BaseBoss` has pose hooks instead (`reset_pose()`,
  `tint_weapon()`, `_update_pose()`, `hover_point()`, and `_idle_motion()`,
  `_recover_motion()` and `_stagger_motion()`), plus `get_display_name()` for the HUD.
  `base_attack.gd` moved up to `actors/bosses/`, since both bosses use it.
- **Sync is generic.** Bosses emit `sync_event(kind)`, and `GameManager.SYNC_GAINS` maps each
  kind to its gain. Cubus's gains are unchanged.
- **Player additions:** dash-slash, upslash and Launch, and for the new fight
  `get_floor_body()`, `landed(player, air_time)`, `set_tether()`, `fall_into_pit()`,
  `active_sword_point()`/`swing_serial` (for striking the chain), `move_axis()` and
  `refresh_air_moves()`.
- **Boss select:** `ui/boss_select.tscn` is now the main scene (up/down + Enter, pad A, or
  1/2). Esc returns to it from a fight.
- **Verified** with a headless test run (not part of the project). It covered the pan weights,
  the upslash hop, the dash-slash and Launch windows, each attack's co-op success path (full
  relay, balanced Undertow, Counterweight catapult, Shackle slingshot, Hook rescue, and a real
  launch up to Zenith), phase 2, and every attack of both bosses under random input.

### Risks and open questions

- **Pans moving under you.** Your partner's jump can drop your pan mid-parry. That's intended
  as a coordination lesson, but if it feels unfair, soften `PAN_STIFFNESS` or lower
  `PAN_STEP`.
- **Rope feel.** It pulls by moving the players (`TETHER_MAX_CORRECTION` caps it at 40 px per
  frame). If it feels sticky, lower the pull or make the rope softer.
- **Launch tolerance.** 0.15 s from upslash to clash is about a parry's width. It still needs
  to be felt out on real hands.
- **Playing alone.** Counterweight, Shackle and Zenith can't be won by one player. That's
  intended for a co-op game, but worth deciding whether a downed partner can be revived.
