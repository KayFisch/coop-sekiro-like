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

## Sync as life

Nobody has health. The two players share one **sync**, the boss has his own, and each of the three has a posture, by the same rules on both sides. Playing together (a hit through the guard the partner's parry opened, parrying both his swords at once) wins the players sync back; the boss can't win his back. At full sync the players are in the sync mode, where they bind and strike together; at none, in chaos, the next hit ends it. Details: `docs/boss_columna_bifrons.md` ("Sync as life"), `core/sync_rules.gd`.

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
- Not yet built: more bosses, art, online multiplayer

---

## Tech

- Engine: Godot 4 (GDScript)
- Version control: GitHub
- No external assets in the prototype — all visuals are procedural shapes, all audio is synthesized via AudioStreamGenerator
