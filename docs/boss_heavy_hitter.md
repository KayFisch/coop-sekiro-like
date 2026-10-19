# The Heavy Hitter (working title)

Status: the next boss to design (2026-10-19). Name and myth open (Kay's list of two-headed
creatures, e.g. the Ettin). General rules: `docs/concept.md`.

## Identity

Slower, a heavy hitter with **one weapon** (like the False Knight or the Watcher Knights in
Hollow Knight); charge, environment and area attacks. Signature: **he forces movement**; how the
formation changes is up to the players.

## Basics (decided)

- **One weapon, held more or less level in front of him;** the end of the grip guards the other
  side.
- **Blade and pommel are the two ends of one weapon:** the blade is heavy and slow, the pommel
  normal and fast. Two-sided like Bifrons, with one weapon.
- **Open while winding up.** His attacks are mostly heavy strikes that both have to parry, so
  the players must switch sides to answer them (pep → ppe).
- **Shockwaves arrive in the other screen half** (light ↔ shadow) and drive the players from
  ppe to pep.
- So he pulls the formation **both ways**: heavy strikes gather the players, shockwaves drive
  them apart. That is the fight's engine of movement.
- **A bit smaller** than Bifrons: players can jump over him or his level weapon, and pass under
  him when he jumps.
- The **sweep** is his (one blade reaches one player, then the other; the outcome depends on
  which sides parried). The try-out boss has one to learn from (`attacks/sweep.gd`).
- The two connected screen halves work well for him too.

## Building blocks (draft, not discussed yet)

Must follow the chain grammar and the outcome principle (combos, not single attacks).

1. **Blade strike:** heavy, long windup, on the blade side; both have to parry (gathers them).
   Makes the shockwave in the other half.
2. **Pommel jab:** normal, fast, on the pommel side; often the lead-in to the blade strike, and
   the chance to dash-parry through him.
3. **Sweep:** the blade goes through level, one player first, then the other; parry or jump
   over; the outcome depends on which sides parried.
4. **Stomp leap:** he jumps and lands with a shockwave; passing under him switches sides, the
   wave drives the players apart.
5. **Charge:** weapon held level, across the room, slowly announced; jump over it.
6. Maybe **environment:** after heavy strikes, debris falls from above (like the False Knight).

## Open

- Why his single blade needs two parries under "one parry per blade". With variant b of the
  screen halves: his blade manifests in both layers at once on heavy strikes.
- What the shockwave is in the one-sided view (there is no second half).
- His sync-mode reaction pattern.
