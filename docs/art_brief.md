# Art brief: generating sprites and animation frames

What an image model (or a person) needs to know to draw for this game: what the figures are,
how big, which colors, which poses. Paste the block below into the prompt and fill in `<STYLE>`.

Nothing here is decided art direction. Today everything is rectangles drawn in code; the sizes,
colors and poses below are read from that code (`actors/player/player.gd`,
`actors/bosses/columna_bifrons/columna_bifrons.gd`, `levels/threshold/threshold.tscn`). When
those change, change them here too. Only Columna Bifrons is covered; Cubus and Sphaera aren't.

## Bodies and swords are separate

In the game a body and its sword are separate parts, and the code turns the sword: its poses and
timings are constants that get tuned all the time. Frames with the swing drawn in would freeze
that timing. So generate **body frames without a sword** and **one sword sprite per figure**.
The pose lists are there as a reference, and for the case that whole frames are wanted after
all.

## The brief

```text
PROJECT
2D side-view local co-op boss-fight game (Sekiro/Cuphead-inspired), 1152x648 px screen.
Two players fight one boss with swords; fights are rhythmic (strike, parry, counter on a beat).
Everything is strictly side view, flat, no perspective. Currently all shapes are plain rectangles.

STYLE: <STYLE - e.g. flat minimalist vector / pixel art 4x / ink silhouettes>
Background in game: near-black vertical gradient (#050509 to #1F1F24), platforms #303036.
Characters must read clearly against dark. Idea under consideration: players black and white,
red as the accent color.

OUTPUT RULES FOR SPRITES
- Sprite sheet, frames in one row, equal cell size, same scale and baseline in every frame.
- Solid flat background (#FF00FF) for keying, no shadows, no ground, no text.
- Character faces right (the game mirrors it). Consistent proportions and colors across frames.
- Body WITHOUT sword unless stated; the sword is a separate sprite, drawn horizontally,
  grip at the left end, tip to the right.

PLAYERS (two, identical shape, different color)
- Body: small, compact, about 40x40 px in game (square proportions), two small hands.
- P1 blue #4080FF, sword #9ECCFF. P2 orange #FF8C26, sword #FFCC8C.
- Sword: 76 px long, 6 px thick: almost twice the body height.
- Sword poses (angle of the blade; 0 = level forward, negative = up):
  rest: diagonal up-forward (-40 deg)
  block: diagonal down in front of the chest (+32 deg)
  perfect parry: blade beaten upward past rest (-75 deg), flash, yellow sparks #FFD966
  slash: drawn back nearly upright (-80 deg) -> cut down to +34 deg -> back to rest
         (0.05 s / 0.12 s / 0.24 s)
  recoil (own swing was parried): thrown back over the shoulder (-137 deg)
  dash: body stretched (1.3 wide, 0.7 high), afterimages; dash-slash: blade thrust forward,
        glowing toward white
- Body states needed: idle, run, jump, fall, dash, hurt, drink potion.

BOSS: COLUMNA BIFRONS ("two-faced column")
- A tall narrow column, 64x150 px in game, dark grey #45454D, left/right symmetric: two fronts,
  no back. Janus-like. Stands between the two players.
- Two huge swords, one per hand: 170 px long (longer than he is tall), 12 px thick,
  silver #CCD1DB, crossguard 6x32 px, hands 16 px.
- Each sword fights one player: its crossguard and cutting edge (4 px) carry that player's color.
- A guard plate (6 px, #9EA3B3) runs down each flank a sword is guarding.
- Sword poses (hand position relative to his center, blade angle):
  guard: upright at the flank, hand at hip height
  raised / coiled: over his head, blade tilted back behind him (windup; trembles before the drop)
  strike landed: out from the flank, tip on the floor, almost level
  his own parry: guard blade flicked outward, orange sparks #FFB24D
  recoil: thrown back up by a player's parry
  guard broken: blade knocked outward, flank flashing pale yellow #FFF299 ("hit here, now")
  staggered: both blades limp on the floor, dark #73737F, body flashing grey #8C8C9E
  sweep: blade held low out to the side, then cutting level at head height through to the far side
  charge: blade lowered and drawn far back level, body rearing back, then thrust out
  leap: both blades held high over his middle pointing straight down, body crouching
  shove: both blades vertical, pushing with the flat side (no cut)
  both swords on one side: the far hand's sword reaches across in front of him, laid back over
    the shoulder, and cuts on a flatter, lower arc than the other
- Color language of his blades: yellow = this blade strikes next; red = it is coming now (0.28 s);
  green #40FF73 = both blades at once, parry together; white = shove.
- Body states needed: idle, walk, lunge (short step or long dash with each cut), crouch, leap,
  land, rear back, stagger, death.
```

The shove is described as it's meant to become (a push with the flat side, swords vertical; the
task is in `TASKS.md`). In the code it's still a thrust.

## Working with an image model

- **Consistency:** get one reference image per figure first and pass it along with every later
  request. Without it, proportions and colors drift from sheet to sheet.
- **Key poses only:** ask for 3 to 5 poses per movement, not smooth in-betweens. Godot does the
  in-between.
- **The boss's symmetry:** he has to look the same from the left and from the right, or
  mirroring his swords won't work. Image models like to ignore that, so say it every time.
