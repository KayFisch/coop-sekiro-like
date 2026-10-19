# Columna Bifrons, the Warden of the Threshold

Status: design in progress (2026-10-19). Replaces today's Columna Bifrons, which stays as the
try-out boss (`docs/boss_columna_bifrons.md`). Designed from scratch, so he has no attacks that
don't fit him. General rules: `docs/concept.md` ("Boss design principles", "Blade rules").

## Identity

Janus ("Bifrons", two-faced), god of doors and passages, guards the threshold. A duellist with
**two long, vertical swords**. Signature: **he sets the formation** (who stands on which side).
Players can resist (e.g. by dashing through his crossing thrust).

## How he fights

- **Chains, not patterns:** a motif of strikes, repeated, then one finale, then a pause in which
  he moves.
- **2 to 3 motifs** (e.g. R R L), each announced by its own stance.
- Chains are not too short and extend fluidly.
- **Links:** a *strike* on R or L (each blade fights its player); a *push* of one player (thrown
  back, has to come back).
- **Finales:** double strike, crossing, gate leap. **Each one gives a co-op parry chance with a
  stagger.** All of them work in pep and in ppe.
- A chain starts on his own initiative, or as an answer when the players hit his guard in the
  pause (it then starts on the attacker).

### Double strike

Always the end of a chain, never on its own. Both swords: R + L in pep, R + R or L + L in ppe
(see "One parry per blade").

### Crossing

Push one player, follow with a dash thrust, then a heavy strike; the other player has to dash
after them to co-op parry it together. It doesn't have to change the formation: it isn't easy,
but players can dash through him during the thrust.
Telegraph: it starts with pushing a player; he draws the sword on the side of the dash direction,
then thrusts.

### Gate leap (replaces the leap)

Forces ppe into pep (with the old leap, players could pick their formation). A = the front player
(he vaults over A), B = the back one.

0. **Telegraph:** he raises the sword on the side away from the leap's direction and points it
   forward (he's about to ram it into the ground). Easy to tell from the crossing, which starts
   with a push and draws the sword on the side of the dash direction.
1. At the end of an aggressive run of strikes he **rams sword 1 into the ground between the
   two players**, as a thrust. **Parriable.** Light knockback for both by default, so the sword
   clearly stands between them and he has room to land.
2. He **vaults over A** on it and lands between the two.
3. Still landing, **sword 2 strikes B.**
4. He **rips sword 1 out of the ground** as an upward cut on A that **throws A back**
   (parried: no or half knockback; blocked or hit: full).
5. **Heavy finish:** the upward cut's motion becomes the windup for a heavy attack with both
   swords:
   - **A is close enough:** it comes down on **both sides**; both parry → **stagger**.
   - **A is too far away:** **both swords go to B**. B can parry, but unless A parries too,
     B's parry only has the effect of a block (one parry per blade).

The finish is the gate leap's only reaction; no extra reactions to steps 1, 3 or 4. While sword 1
is in the ground it is a wall.

**Tried out on the try-out boss** (2026-10-19, F5: GATE_LEAP; `docs/boss_columna_bifrons.md`,
"The gate leap"). Where the build had to settle what's open here:
- Sword 1 is **A's sword** (the one that fights A), not "the sword on the side away from the leap's
  direction": so each screen half still shows the blades aimed at its player, and the sword
  rammed between them, aimed at both, stands out in both.
- "Close enough" in step 5 = in his blades' reach (215 px) as the swords **start down**, after the
  lift (F2). Parried, the rip throws A about 65 px (A stays in reach), blocked or hit about 180
  (out of it).
- A parried strike in steps 3 and 4 breaks the other sword's guard (the partner's sync hit), as
  any strike's parry does; no other reaction.
- Found: a block and a hit throw A just as far, and the throw doesn't stop a dash. So a lift long
  enough for a blocking A to come back lets a hit A back too.

## Where he stands

- **He wants the middle himself** (he doesn't try to keep the players there). The warden stands
  in the doorway; from the middle he reaches both sides alike, in pep the players have room on
  both sides, and in ppe he presses them toward the wall.
- **The pause is movement:** he repositions (steps toward the middle, turns to the other side;
  Janus looks both ways).
- If he's been off-centre too long, he vaults over the players into the middle (like the gate
  leap).

## Open

- **The three motifs:** sequence, tempo, where a push fits, and their stances.
- **What decides at the branch points.** Ideas: posture low → finale; a player far away → push
  or crossing; formation → which finale.
- **Guard opening at a motif's end** (Nicho's idea): if all strikes of a repetition were
  parried, the last parry briefly opens his other side, so at most one real sync hit per
  repetition. (Tried out since 2026-10-19: the try-out boss's chains mode with
  "bifrons_guard_break" on motif_end, `docs/boss_columna_bifrons.md`, "chains".)
  In the try-out boss this is the switch "bifrons_guard_break" (on: every parry opens
  the other side; off: the window stays, but his guard still parries). Nicho plays with it off,
  because sync damage came too fast with it on. Claude's suggestions: "enough" = all strikes of
  that repetition; the sync hit doesn't break the chain; the opening gets its own short tell.
- **Gate leap, step 5** (proposal): make the windup long enough that an A who only *blocked*
  step 4 can dash back in time; only an A who was *hit* leaves B alone. (In the try-out a hit and
  a block throw A equally far: that needs something else that sets a hit A apart, see above.)
- **Telegraph ideas** (proposal): a stance per motif; "Janus eyes" (a face on each side, the lit
  one shows who the next strike is for).
- **His sync-mode reaction pattern.**
