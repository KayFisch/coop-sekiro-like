# Untitled Co-op Action Game — Concept Document

## What is this?

A 2D co-op action game built in Godot 4. Two players fight bosses together, but unlike most co-op games where cooperation just means two people doing the same thing side by side, the core mechanic here requires players to act *through* each other. The game is built around the idea of learning a duet — two players developing a shared combat language over time.

This is currently a **prototype**. The codebase contains one boss fight arena with placeholder visuals. The goal of the prototype is to prove that the core mechanic feels good before building anything else.

---

## Core mechanic — the parry relay

Combat is sword-based. Players attack with their sword, and holding block reduces incoming damage. But the skill expression is in the **perfect parry**: pressing block at the exact moment the boss sword makes contact deals no damage and triggers a relay.

A relay means the boss's attack is redirected to the second player, who now has their own parry window. If the second player also perfect parries, the boss staggers and both players get a free window to deal damage. Nail the chain and you deal significantly more damage. Break it and you both pay for it.

Not every attack is parriable. The boss has a vocabulary of attacks that require different responses:
- **Jump attack** — leaping slash; each parry deflects him into another leap at the other player (P1, P2, P1), and the third parry knocks him into the arena's middle, staggered
- **Grab** — he charges at you and his hands scoop in from both sides; dash exactly as they reach you to slip out of his grasp. Caught: lifted overhead as he jumps, then slammed into the floor
- **Ground slam** — get airborne before it lands
- **Grand slash** — a top-to-bottom arena-wide shockwave, both players must parry near-simultaneously or both take full damage
- **Shockwave slashes** — a rhythm-based attack where each player must parry three projectiles in a fixed metronome beat; gather all three and you can fire a counterattack back at the boss

Each attack is telegraphed by color so players can read what's coming and coordinate their response without needing to talk.

---

## The sync meter

Successful relays and coordinated responses build a shared **sync meter**. Taking damage or failing parries drops it. High sync increases damage output — up to 2x at maximum. The better you play together, the faster the fight ends. It rewards mastery without gating players behind it.

---

## Moveset

The fight kit is built for the parry duet: each player's freedom is small, and the big moves take both of you. The platforming kit (double jump, walls, ledges, fast fall, environment pogo) is parked behind switches that are off by default. F1 in game shows every switch.

**Alone**
- **Run, jump** (136 px), drop through one-way platforms (down).
- **Dash**: the way you face (hold a direction and press dash on the same frame to dash that way). 140 px, no invulnerability, 0.6 s cooldown, one per trip into the air. Only landing or a Launch gives it back. Pressed as the grab's hands close, it slips out of them whichever way you face, even into his body.
- **Slash, upslash** (up + attack), **downslash** (down + attack in the air). A downslash never hurts the boss or bounces off him.
- **Block / perfect parry**: press block at most 0.133 s before contact.
- **Dash-slash** (dash + attack): a 0.2 s windup with the blade heating to white, then a long thrust through the whole dash. It stops at his body, but the blade still lands.

**Together**
- **Launch**: a dash-slash into the partner's upslash throws the dasher 340 px up.
- **Momentum relay**: a dash-slash into the partner's parry locks the blades. The dasher aims sideways or upward (5 ways) and is boosted that way.
- **Pogo clash**: a downslash onto the partner's upslash bounces the falling player 110 px. Nothing else bounces a downslash in a fight.
- **The tell**: a dash-slash headed at the partner puts a ring in the dasher's color around them. It closes 0.08 s before the blades meet, which is the moment to press (block for a relay, upslash for a launch). A short sound ends on the close.
- **Standing on each other**: players collide.
- **Call** (P1 Enter, P2 LB): a 3, 2, 1, GO countdown over the caller's head on a 0.4 s beat, with both players pulsing. Pressing again cancels your own, and a partner's call replaces it.
- Launch, relay and pogo clash each give +5 sync, at most once per 5 s between them.

**His body**: Cubus Maximus blocks players from his bottom up to 170 px, above a running jump and far below a launch. The zone moves with him, so you can walk under him while he's in the air. Nobody stands on him: landing on top slides you off the side you came from. Getting past him takes your partner (a launch or a relay). Both players start on the same side of him.

| Switch | Default |
|---|---|
| dash, dash_slash, launch, momentum_relay, players_collide | on |
| pogo (the pogo clash) | on |
| boss_body (Cubus only) | on |
| call | on |
| double_jump, upslash_hop, fast_fall, wall_jump, ledge_grab, chimney_clash | off |
| wall | off (slide / cling) |
| wall_refresh, relay_refresh_dash | off |
| pogo_environment (targets, spikes, lanterns: the gyms), pogo_refresh_air_jump, pogo_refresh_dash | off |
| swap_controls | off |

Settings are saved in `user://moves.cfg` with a version. When the defaults change, the version goes up, and an older save is reset to the new defaults once.

---

## Beyond the boss fight — platforming levels

*Parked for now: the fight comes first. The gyms and the platforming switches above remain for experimenting.*

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

- One boss: **Cubus Maximus** — a sword-wielding boss with five distinct attacks
- One arena: bounded rectangle with floor, walls, and three floating one-way platforms
- Two players: keyboard (WASD) and Xbox controller
- Systems in place: parry relay, sync meter, individual health bars, shared death condition, potion system, screen shake, procedural audio
- Not yet built: platforming levels, additional bosses, art, music, online multiplayer

---

## Tech

- Engine: Godot 4 (GDScript)
- Version control: GitHub
- No external assets in the prototype — all visuals are procedural shapes, all audio is synthesized via AudioStreamGenerator
