# The Acrobat (working title)

Status: designed (v1, 2026-10-25), to be built next (phase 1 first). Name and myth open. General
rules: `docs/concept.md` ("The mirror rule", "Boss design principles", "Blade rules"). The why,
and what was dropped: `scribbles.md`, 2026-10-25.

## Identity

Light, quick, never long in one place (towards Lady Butterfly in Sekiro); a **juggler**.
Signature: **he moves himself all the time**: he dashes rather than walks, flips over the players,
clings to the walls, dives through the mirror line. The formation shifts because the players chase
him. In the mirror rule's terms he keeps it in phase 1 (stage 0) and breaks it with his body in
phase 2 (stage 2: point-mirrored). Small, and his leaps aren't high. Myth candidates from Kay's
list: the Gandabherunda (a two-headed bird) or the Amphisbaena (a serpent with a head at each end:
point-symmetric, like his phase 2).

## His weapon: four rings, two in each hand

- In each hand **a pair of rings held as one**: it looks like one (thick) ring, and in close combat
  it is **one blade** (one parry per blade). Each hand fights one player, as Bifrons's swords do.
- He **throws one ring of a pair** and still holds the other: he strikes on while one is in the
  air, and catches it back onto the pair, juggling. At most one ring per hand in the air; only the
  rally (a finale) throws all four.
- **Small blades on his feet**, for the kick in a salto.
- A ring is in the color of the player it's for, and stands out in that player's half (as the
  blades do with "mirror_blades" on "color").

## His rule: the arc and the strike back

- **The throw:** a ring drawn back over his shoulder, yellow; red as it leaves his hand. Where it
  will arrive is marked before (as on the beat ring). From a stand, out of a backward dash, or out
  of a salto. Only the player it's for can answer it (it's in their layer).
- **Every ring flies back to him in an arc**, and he catches it.
  - **Blocked or hit:** the arc runs in the layer it came in. Nobody can strike it.
  - **Parried:** the ring goes **through the mirror line** into the partner's layer (it takes the
    partner's color) and flies **the same arc** back to him there. **The partner can strike it**
    where it passes them, standing or jumping. Struck, it doesn't fly on but goes **straight at
    him: a strike back**, a hit on him; in the partner's sync-hit window (opened by the parry), a
    **sync hit**. Not struck, he catches it.
  - The arc starts slow at chest height where the ring was parried, so a partner beside the
    parrier can reach it in the window. Standing together, the strike back is easy; standing apart,
    the partner has to come over: one more reason to chase him.
- **A strike back always hits him** (he catches the ring, but it hurts). It **staggers him only at
  the end of a finale**: the rally's last throw, and the throw from his backflip after a plunge
  parried together.

## Verbs (each with one tell, the same everywhere)

Colors as with the other bosses: yellow = yours to parry, green = together, red = it comes.

1. **Strike:** a ring as a blade, drawn straight back, yellow, then red. On the ground, from a jump
   (catching his ring), out of the mirror line (an upward cut): the same tell.
2. **Feint (a delayed strike):** instead of drawing straight back, **he turns the ring once round
   its axis as he winds up** (the tell, before anyone parries). Where a strike would come, he
   **twitches** (the ring whirls in his hand), and a moment later (F2; start: half a beat) the real
   strike comes, red only then.
3. **Throw** (above).
4. **Salto** (moving, with an attack; the branch point, below):
   - **forward over a player, with a kick:** legs drawn in, the foot blade flashes yellow as he
     takes off; a normal strike at the one he flips over. pep becomes ppe and back, unless the
     players follow.
   - **backward, away from the players, with a throw:** the ring drawn back as he takes off.
   - **into the mirror line:** the dive.
5. **Plunge** (from a wall): crouched, hands crossed; he throws himself at the players.
6. **Dive** (through the mirror line): the tell: he **throws a ring at the line and cuts it open**,
   then dives in head first after it (if the cut doesn't read: his blade held out in front as he
   dives). In the line he's faint in both halves (low contrast) and moves along under the floor;
   where he'll come up ripples a moment before. In phase 1 one body, the same in both layers
   (stage 0: only how visible he is changes).

Moving without an attack's tell: the **dash** (his basic way of moving, rather than walking), the
jump to catch a ring, clinging to a wall.

## Motifs (longer phrases; a chain plays one or two, each ends in a salto)

- **The throwing chain:** [if a player is close: a backward dash] → **throw** (from a stand, out of
  the dash, or out of the salto before) → the ring comes back in its arc, or struck back → he
  **jumps to meet it, catches it** and uses the jump for a **jump strike** → **strike → strike**
  (quick, each hand at its player) → **salto**.
  - A reaction, on a detail: **a strike back draws him to whoever struck it** (he jumps at the
    ring sooner, and the jump strike is theirs); otherwise the jump strike goes to the nearer one.
    Striking back wins sync, and brings him to you.
- **The whirl:** **dash in → strike → strike → feint → strike → salto.** Each hand at its player;
  the feint always third.
- **Readable though long:** each motif can be told by its first link (the throwing chain:
  distance, a backward dash or a throw; the whirl: a dash in), the order inside is fixed, and he
  decides only at the salto. About 5 to 6 links, 4 to 5 s.
- Which motif: at random (as the principles allow), weighted by distance (far: rather the
  throwing chain). A chain is one or two motifs (at random), then a finale; sooner if his posture
  is low.

## The salto: where he lands says what comes

Every motif ends in a salto, whichever motif it is; its direction follows from what comes next:

- **forward over the nearer one, with a kick:** the whirl comes next, or the wall behind the
  players;
- **backward, with a throw:** the throwing chain comes next (its throw is the salto's), or the wall
  behind him;
- **into the mirror line:** the dive.

And where he lands: **on the floor**, the chain goes on (the next motif); **on a wall**, a wall
finale, told apart by how he hangs there (a ring ready to throw: the rally; crouched, hands
crossed: the plunge); **in the mirror line**, the dive.

## Finales (which: by what he sees, never by chance)

1. The players struck a ring back in this chain: **the rally** (he takes up the challenge).
2. Else, both on one side of him (ppe): **the dive** (he parts them).
3. Else (pep): **the plunge**.

The same finale at most twice in a row (`docs/concept.md`, "The boss reacts to what happens"): if
these rules pick it a third time, the next one in this list comes.

- **The rally:** from the wall, three throws, by turns at each player, each faster; each parried
  ring flies its arc in the partner's layer and can be struck back (it hits him; he catches it and
  throws on). Then he **throws all four rings, a pair at each** (parry together); a strike back from
  this last throw, and he can't catch them all: he falls off the wall, **staggered**. A player who
  doesn't parry is hit; the rally goes on.
- **The plunge:** from the wall at the players. Apart, he lands between them (one hand each side);
  together, in front of the front one with both hands (heavy). **Parried together:** he **stands on
  their blades** for a moment, then **flips back off them, throwing a ring** in the salto; struck
  back, it **staggers** him (he lands off balance). Not parried together: he lands, and **dashes
  away** from the players.
- **The dive:** the cut, then into the mirror line, faint under the floor, the ripple where he'll
  come up: **under the front one** (or the nearer one). His upward cut throws them over him to his
  other side (the formation flips), then a strike with both hands at where they are (one each side,
  or both at one place): parried together, a **stagger**.

Every stagger: 0.5 s and 0.2 s per blade parried in the chain, the finale included (the general
rule, "Stagger after a finale").

## His breath

- **Always moving:** dashes, salti, along a wall, a moment clinging to one (at a height a jump
  reaches).
- **Guarded means he evades:** a hit in his breath meets nothing; he's gone, and his next chain
  starts at the attacker.
- **He can be hit** on the ground in a chain (he doesn't guard while he attacks), on a wall with a
  jump attack (outside his breath), by strikes back, and in a stagger. His parried strikes open the
  partner's window, as anyone's do.

## His posture and phase 2 (point-mirrored, stage 2)

- **The first break looks like a kill:** he lies on the floor, a moment of quiet, then he rams his
  rings into the line under him, cuts once through himself, and the halves part. His sync stays.
  After that, a break is what it always is (the deathblow, "Sync as life").
- **Two bodies, one rhythm:** in each layer he stands at the place mirrored through the room's
  middle (the light one at x, the shadow one at the room's width minus x). Both play the same chain
  on the same beat. Each player fights the body of their layer.
- **Together or apart depends on where he is:** near the middle, his two bodies are close; the
  players can stand together, attacked from opposite sides. At a wall, his other body is at the
  other wall: following yours takes you away from your partner. His close motifs keep the players
  together, his wall finales pull them across the room (a rally from wall to wall, the ring through
  the mirror over the whole room). Where he goes is the lever on the sync mode, which needs the
  players side by side.
- **A strike back** hits the body in the partner's layer.
- **Heavy** means: both bodies strike at the same moment (in unison, as with the Heavy Hitter):
  parry together.
- **A smarter plunge:** parried together, he doesn't throw from his backflip; it ends in a dive
  into the mirror line, and the dive finale follows. Not parried together, he glides into the line
  after the plunge, and the dive follows too. The stagger then comes at the dive's end.

## Size and room

Small (about a player's size, or a little more), and his leaps aren't high. Bifrons's room (the
Threshold's stage) on the mirrored screen. The HUD sits in the screen's middle, so the walls are
free; he clings to a wall at a height a jump reaches.

## In the players' sync mode

Open, as for every boss (his own sync-mode pattern).

## Open

- Whether the cut reads as the dive's tell (else the blade held out in front).
- The arc: how high and how long (in reach of a jump; slow at its start).
- The order of sides in the whirl; whether a parried kick throws him off balance; a feint in a
  throw.
- Diving in phase 2 (in in one layer, out in the other?).
- A third motif (e.g. running along a wall), if two are too few.
- His tempo and numbers; his sync-mode pattern; name and myth; the one-sided view.
- Beside the Kultist (to settle with Kay): the Kultist's magic goes through the axis when it's
  *not* stopped (a punishment), the Acrobat's ring when it's *parried* (a reward); the Acrobat goes
  through the line himself, the Kultist only his magic.

## Dropped (2026-10-23/25)

- A feint's tell at the moment of the strike (it comes when the players already parry).
- "Out of reach above" (he's small enough, and the HUD is in the middle), and with it "out of
  reach, the sync hit becomes the strike back".
- Throwing from inside the mirror.
- The hail (throw, throw, double throw from the wall) as a motif; the double throw lives on in the
  rally.
- An arc that always passes the partner (as the beat ring's violet shard): it's the same arc, so
  the partner has to come over.
- The beat ring as one of his phases, as it is.
