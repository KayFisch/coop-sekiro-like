# Untitled Co-op Action Game — Concept Document

## What is this?

A 2D co-op action game built in Godot 4. Two players fight bosses together, but unlike most co-op games where cooperation just means two people doing the same thing side by side, the core mechanic here requires players to act *through* each other. The game is built around the idea of learning a duet — two players developing a shared combat language over time.

This is currently a **prototype**. The codebase contains one boss fight arena with placeholder visuals. The goal of the prototype is to prove that the core mechanic feels good before building anything else.

---

## Core mechanic — the parry relay

Combat is sword-based. Players attack with their sword, and holding block reduces incoming damage. But the skill expression is in the **perfect parry**: pressing block at the exact moment the boss sword makes contact deals no damage and triggers a relay.

A relay means the boss's attack is redirected to the second player, who now has their own parry window. If the second player also perfect parries, the boss staggers and both players get a free window to deal damage. Nail the chain and you deal significantly more damage. Break it and you both pay for it.

Not every attack is parriable. The boss has a vocabulary of attacks that require different responses:
- **Sword relay** — parry chain between both players
- **Grab** — dodge by dashing at the exact moment of contact
- **Ground slam** — get airborne before it lands
- **Grand slash** — a top-to-bottom arena-wide shockwave, both players must parry near-simultaneously or both take full damage
- **Shockwave slashes** — a rhythm-based attack where each player must parry three projectiles in a fixed metronome beat; gather all three and you can fire a counterattack back at the boss

Each attack is telegraphed by color so players can read what's coming and coordinate their response without needing to talk.

---

## The sync meter

Successful relays and coordinated responses build a shared **sync meter**. Taking damage or failing parries drops it. High sync increases damage output — up to 2x at maximum. The better you play together, the faster the fight ends. It rewards mastery without gating players behind it.

---

## Beyond the boss fight — platforming levels

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
