# The Acrobat (working title)

Status: designed (v1, 2026-10-25); phase 1 built (2026-10-26, branch `nicho/acrobat`: see "Built
(phase 1)" at the end), waiting for Nicho's first test; phase 2 next. Name and myth open. General
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

## Built (phase 1, 2026-10-26)

Branch `nicho/acrobat` (from `nicho/heavy-hitter`, with `kay/kultist` merged in for the Threshold's
stage as a scene). Code: `actors/bosses/acrobat/`: `acrobat_body.gd` (his body and how it moves, his
hands and rings, the windows), `acrobat.gd` (the boss: his rule, the chains, the finales, his breath,
the rules' hooks), `attacks/phrase.gd` (a chain and its verbs), `ring.gd` (a thrown ring),
`acrobat_stand_in.gd`. His room: `levels/acrobat/acrobat_room.tscn` (the Threshold's stage, the
mirrored screen by F1 "mirror_view" as Bifrons's and the Hitter's), entry 4 on the select screen.
Tests: `tests/test_acrobat.gd`. Phase 1 only: one body (stage 0); his first broken posture is a long
stagger for now, and his sync stays.

What's built, and the choices made where the design left them open:

- **His body:** 28 x 56 px (a player is 20 x 40), drawn the same in both halves. He never walks: he
  dashes along the floor (0.15 s), jumps and saltos (turning over), clings to a wall (his feet 70 px
  up, in reach of a jump attack), and glides in the mirror line, flat and faint in both halves. Only
  on the floor does his body block players.
- **His rings:** each hand is its player's (the hand on that player's side), with a pair of rings
  drawn as one thick ring, in that player's color (on the mirrored screen: light for P1, dark for P2,
  so yours stands out on the ground of your half, as the blades with "mirror_blades" on "color"). The
  telegraph is a ring round them. A hand with one ring out draws one ring. Small blades on his feet.
- **Code of his own:** the chains are his (`attacks/phrase.gd`), not shared with Bifrons's `chain.gd`
  or the Hitter's `swings.gd`: his steps run one after the other, since a step's time can hang on a
  ring coming back; the Hitter's run on a fixed time line. Worth pulling out once the Warden is the
  third boss with chains. No finale three times in a row is a small static function
  (`Acrobat.fresh_finale()`), to lift into `BaseBoss` for the Hitter and the try-out boss
  (`TASKS.md`). The partner's window is copied from the Hitter's (`acrobat_body.gd`); the ring's
  stages and look are modelled on the Kultist's spell, its strike back on the beat ring's shard
  (`Player.active_sword_point()`); none of their code is used.
- **A throw:** the ring drawn back over his shoulder, yellow; a yellow circle marks the player's
  chest, following them until he lets go; red as it flies (0.35 s), straight to that mark. Whoever
  has moved out of the mark (44 px) isn't met: it missed, and comes back like a blocked one.
- **The arc:** back to his hand (wherever he has gone meanwhile) in 1.2 s, up 90 px over the straight
  way, slow at first ("acrobat_arc_ease"). Parried, the line flashes under it and it's in the
  partner's color, and their swing within 48 px of it strikes it back (each swing tries once): at
  him in 0.15 s, a normal hit; in their window, a sync hit. Blocked, hit or missed, it's drawn
  fainter: nobody can strike it.
- **Strikes:** reach 100 px from his center (110 up or down: a kick from over their head). Out of
  reach, he dashes in as he winds up (up to 260 px). A strike at someone not there goes into nothing.
- **The whirl:** the nearer one first, then by turns (near, far, near: the feint, far). Answering a
  hit in his breath: the attacker first.
- **The throwing chain:** the throw at the farther one (together, the partner is on the ring's way back
  anyway; apart, they have to come over). After the jump strike, a quick strike at the nearer one and
  one at the other. Answering: the throw at the attacker.
- **The salto:** forward over the nearer one, landing 90 px past them, the kick as he's over them;
  backward 170 px away from the nearer one, the throw at its top; to the nearer wall (forward with the
  kick if the nearer player is on that side, else backward with a throw; up to 1.2 s for a long way);
  into the line, 80 px toward the front one, head first.
- **The finales:** the rally from the wall: throws at 5, 4 and 3 of his beats, by turns (the first at
  whoever the last throw wasn't at), then, once his rings are back (at most 1.5 s), the volley: a
  pair at each, one heavy throw (both parry: both go through; one: a block's effect). The plunge: a
  4-beat tell, then 0.3 s down at them; apart, he lands between them and each hand reaches 150 px.
  Parried together: 0.4 s on their blades, a backward salto with a throw at the farther one, and he
  waits for it. Not: he dashes away. The dive: under the floor 1.0 s, under the front one until the
  last 0.5 s (the ripple), then up; whoever is within 60 px is thrown over him, whatever they did:
  away from the partner if they were together, toward them if apart; both hands 4 beats later.
- **The stagger:** at a finale's end only, 0.5 s and 0.2 s per blade parried in the run (a strike, a
  ring, a co-op parry's two). Struck back while he's on the wall, he falls off it first.
- **His breath:** 2 to 3 s; every 0.5 to 0.9 s a move: a dash to 150 to 220 px from the nearer one on
  his side, now and then (20 %) a salto over them, or (15 %, a wall within 180 px) onto the wall and
  off it again with the next move. A hit then: he dashes 150 px away, and once he's on the floor and
  still, his next chain starts at the attacker (not while F5 holds him). A strike back always lands.
  The bound pair's strike in his breath: as at the Hitter's guard (a normal hit's sync, he reels).
- **In the players' sync mode** (a placeholder): the whirl only, then the plunge (to the wall without
  a throw); parried together, staggered at once. His beats and breath 1.4 times as long, and he holds
  off while one of them draws back.
- **The F5 lab:** CHAIN; WHIRL, THROWING (each with the kick salto after); RALLY, PLUNGE, DIVE (each
  with the salto into it); STRIKE, FEINT, THROW, SALTO_KICK, SALTO_THROW.
- **The stand-in** (F1 "bifrons_stand_in"): keeps 70 px from him, parries (75 %) or blocks (15 %)
  his blows at it, strikes in its window, and strikes back a ring its partner parried (70 %), walking
  to meet it; binds in the sync mode.

His numbers on F2 (his own page, "Acrobat"; it opens there in his room):

| What | F2 | Now |
|---|---|---|
| A beat of his / a strike's drop / the feint's delay | "acrobat_beat", "acrobat_strike_time", "acrobat_feint_delay" | 0.2 / 0.15 / 0.2 s |
| After a chain / his breath | "acrobat_recover_time", "acrobat_breath_min", "_max" | 0.4 s / 2 - 3 s |
| Motifs per chain / his posture low below | "acrobat_motifs_min", "_max" / "acrobat_chain_posture" | 1 - 2 / 30 % |
| Rather the throwing chain: the nearer one farther than / by | "acrobat_far", "acrobat_far_weight" | 220 px / 3 to 1 |
| A throw's flight / the arc / its height / its start | "acrobat_throw_flight", "acrobat_arc_time", "_height", "_ease" | 0.35 s / 1.2 s / 90 px / 2 |
| The strike back's reach | "acrobat_strike_back_reach" | 48 px |
| On their blades / under the floor / the ripple | "acrobat_plunge_stand", "acrobat_line_time", "acrobat_ripple_time" | 0.4 / 1.0 / 0.5 s |
| The stagger / per blade | "acrobat_stagger_least", "_per_parry" | 0.5 / 0.2 s |
| His posture / broken: staggered | "acrobat_posture_max", "acrobat_break_stagger" | 200 / 3 s |
| The stand-in: parries / blocks / strikes back | "acrobat_stand_in_parry", "_block", "_strike_back" | 0.75 / 0.15 / 0.7 |

His steps' waits (in his beats) are in `acrobat.gd` (`motif_steps()`, `finale_steps()`), the distances
and times of his moves at the top of `attacks/phrase.gd`. F1, tab "Acrobat": "acrobat_dive_tell", the
dive's tell: the cut (default) or his blades held out in front.

To look for in the first test:

- Do the rings read: whose is whose, the yellow mark where a throw arrives, the ring going through the
  mirror when parried, and which ones you can strike back (the faint ones you can't)?
- The strike back: can the partner reach the ring in the window, standing beside the parrier
  ("acrobat_arc_ease", "acrobat_arc_time", the sync page's window)? Coming over when apart: too hard,
  too easy?
- A throw goes where you were as he let go: moving off the mark dodges it. Right, or should it follow?
- The feint: do you see the ring turn as he winds up, and is the delay right?
- The salto: can you tell from it what comes (a kick: the whirl; a throw: the throwing chain; the wall;
  the line)?
- The dive: does the cut read as its tell (else F1 "blade")? Is being thrown over him fair?
- Is he too fast (his beat), too slippery in his breath, too small to see?
