# The level kit: building coop rooms in the Godot editor

Rooms for the coop platformer are built by hand in the Godot editor, from the pieces in
`levels/kit/`. A room works like one of Celeste's: a passage you get through **together**. When
either of you dies, **both** start over at your spawns; the room's switches and doors start over
with you. Both in the goal: done, and the next room loads.

Every piece is a node with its settings in the Inspector, and draws itself in the editor (the
pieces on the clock even move there, at the room's BPM). Nothing needs code.

## Getting started

1. **A new room**: in the FileSystem dock, right-click `levels/kit/room_template.tscn` →
   *Duplicate*, save it e.g. as `levels/horologium/room_02.tscn`, open it. (The first room of
   Horologium, `levels/horologium/horologium1.tscn`, is what the menu starts.)
2. **Snapping**: in the 2D view's toolbar, switch on *Use Grid Snap* (the magnet with the grid)
   and, under the three dots → *Configure Snap*, set the grid step to 16 × 16 (or 32 × 32). The
   room draws its own 32 px grid, a brighter line every 160 px counted up from its bottom.
3. **Add a piece**: select the room (`Room`), *Add Child Node* (Ctrl+A), type `Kit`, pick one.
   Move it with the mouse (W), set its settings in the Inspector.
4. **Play it**: F6 plays the open scene (F5 would start the menu). Esc goes to the menu, R starts
   the room over, F1 the movement switches, M the click.
5. **Chain rooms**: the room's `next_room` is the scene loaded when both reach the goal.
6. Add a room to the menu in `ui/boss_select.gd` (one line), or ask Claude.

Positions and sizes are in px. A room is one screen (1152 × 648) unless you make it
bigger (`size`); bigger rooms scroll, the camera keeping both players in view.

## The pieces

| Piece | What it is | Settings |
|---|---|---|
| **KitRoom** | The room itself (the scene's root). | `title`, `bpm` (the tempo: everything on the clock and every shaft's width follows it), `size` (from its top-left corner), `next_room`, `moves_on` (F1 switches the room needs, e.g. `double_jump`; on while it runs, back as they were after). |
| **KitSpawn** | Where a player starts, and starts over. Position: on the floor, at the feet. | `player`: P1 or P2. One of each. |
| **KitBlock** | Wall, floor, ceiling; or a one-way platform (jump up through it, down to drop). Position: top-left. | `size`; `one_way`; `owner_id` (one-way only): Both, P1 (carries only P1, blue) or P2 (only P2, orange); `look`: PLAIN, BRICK, DARK (a wall behind things); `edges`: which sides get a bright surface line (top by default, tick none for a plain wall). |
| **KitSpikes** | Touch them and you both start over. Position: one end of the base. With `timed`, they're out only on their beats, and down (harmless) in between; their tips show in the half beat before. | `length`, `facing` (up, down, left, right); `timed`: `pattern`, `bars`, `offset` (see *Rhythms*), `out_beats` (how long they stay out). |
| **KitSwitch** | A switch wired to doors. Position: a plate's on the floor; a struck one's or a target's at its middle. | `trigger`: STRIKE (hit it with the blade), PLATE (stand on it) or BALL (a target: only a KitCannon's ball counts). `who`: anyone, P1 or P2 (a target: who parried the ball last). `mode`: TOGGLE, ONCE, TIMED (`timed_bars`), HOLD (plate: while stood on). `on_the_one`: a strike only counts on the 1 (±0.1 s); off it, it's out of tune until after the next 1. `targets`: the doors (*Add Element*, then *Assign* and pick the door). The editor draws the wires. |
| **KitDoor** | What a switch opens. Position: top-left. | `size`; `kind`: SOLID (switched: opens) or PLATFORM (switched: appears, one-way); `owner_id` (a platform's); `needs`: any switch, or all of them (two plates far apart, one each); `inverted` (open until switched: it shuts). A door shutting on a player kills. |
| **KitHammer** | A hammer slamming down from the ceiling on its beats; deadly while falling, down, and rising until it clears your head. Can't be jumped over. Position: on the floor, in its middle; put a KitBlock as the ceiling `clearance` above. | `pattern`, `bars`, `offset` (see *Rhythms*), `width`, `clearance`, `hold_beats` (how long it lies down), `rise_beats`. |
| **KitPendulum** | A blade on a rod swinging with the clock (bottom on the 1 and the 3, turning points on the 2 and the 4). Rod and blade kill. A perfect parry locks it and holds the parrier for one swing; a block knocks you away. Position: the pivot. | `length`, `amplitude_deg`, `bars` (per swing: 2 is half as fast), `offset` (2: starts the other way). |
| **KitCannon** | Fires a ball on its beats, in a straight line, no gravity. A perfect parry sends it back off you like a billiard ball off the cushion (angle in = angle out: across turns round, up or down stays), so it zigzags on between the two of you, rising or falling, until it reaches a BALL target. Holding block shatters it; neither, and it kills. Walls, floors and shut doors shatter it; it flies through one-way platforms. Position: the pivot; the editor draws its aim, a tick per beat of flight. | `angle_deg` (0 right, 90 up, -30 down to the right), `speed` (px per beat), `pattern`, `bars`, `offset`. |
| **KitBeatStep** | A one-way platform that's there only on its beats; blinks in its last beat. Position: top-left. | `pattern`, `bars`, `offset`, `owner_id`, `width`. |
| **KitShaft** | Two facing walls for wall jumps, as wide as the tempo says. Position: the left wall's top-left; the walls stand `height` tall on a floor there. | `kind`: WIDE (a beat's flight: hold toward the far wall), NARROW (half a beat: no steering), COOP (two wide ones: too wide alone, a chimney clash in the middle). `height`; `left_drop` / `right_drop` (that wall's top this much lower: walls of different heights); `wall_thickness`; `entrance`: none, left or right (a way in under that wall, `entrance_height` tall); `caps`: none, left, right or both (one-way ledges on the tops, reaching outward, `cap_length` long); `top_edges` (the surface line on the tops); `rhythm` (F1 wall rhythm). A room with a shaft switches on what wall jumps need while it runs, and ticks a metronome at its BPM. |
| **KitElevator** | A platform that rises on a rhythm you play together. Both of you on it: it starts on the next 1, one step a beat; strike (attack) on the beat as the step says, and it goes up a stage. A miss (nobody, the wrong one, a strike off the beat): down two stages and two steps back, and a bar off before it goes on at the 1. The last step: it's at the top and stays. Its doors shut at both ends while it runs (no getting off on the way up) and open at the top. Off it (no doors): it stops, and starts again on the next 1 once you're both back on. Its front shows the steps (blue P1, orange P2, green both; gold once it's at the top), the one to play outlined. Position: the platform's top-left, at the bottom; the editor draws its track up to the top. | `sequence`: one digit a step, 1 P1, 2 P2, 3 both (`1-2-1-2-1-1-2-2-3`; dashes or spaces between are ignored); `width`; `stage_height` (how far a step lifts it: the top is steps × this); `doors`, `door_height` (taller than a jump, 136, or you can jump out). |
| **KitText** | A note on the wall: a hint, a title. Position: the first line's top-left (its middle with `align` center). | `text` (several lines), `font_size`, `color` (its alpha: how faint), `width` (wraps longer lines; 0: only where you break them), `align`. |
| **KitGoal** | Both in it: the room is done. Position: top-left. | `size`; `label` (written in it instead of GOAL); `next_room` (loaded instead of the room's: a room with several ways out). |

### Rhythms

A piece on the clock plays on the counts in its `pattern`, over `bars` bars, shifted `offset`
beats later. In the editor a ruler under it shows the cycle, a square a beat, lit where it plays.

| pattern | bars | offset | plays |
|---|---|---|---|
| `[1]` | 1 | 0 | on the 1 of every bar |
| `[1, 3]` | 1 | 0 | on the 1 and the 3 |
| `[1]` | 1 | 1, 2, 3 | on the 2, the 3, the 4: four hammers with offsets 0-3 make a wave |
| `[1, 2]` / `[3, 4]` | 1 | 0 | two sets of steps taking turns |
| `[1, 4, 7]` | 2 | 0 | on 1, 4 and 7 of eight counts: a 3-3-2 rhythm over two bars |

### The shafts and the tempo

A shaft's gap is a player's body (20 px wide since the slimmer players) plus how far a wall jump
flies sideways (`WALL_JUMP_PUSH`, 360 px/s) in its beats at the room's BPM:

| BPM | WIDE (1 beat) | NARROW (½ beat) | COOP (2 × wide) |
|---|---|---|---|
| 120 | 200 | 110 | 400 |
| 150 | 164 | 92 | 328 |

Change the room's `bpm` and every shaft in it changes width, in the editor too (the shaft writes
its width and tempo on itself). Leave room for that when you build around them.

## The clock: `Beat` (core/beat.gd)

An autoload, the one clock for everything that goes in time. No piece counts time itself: each
works out where it is from the clock alone, so they all stay in time with each other.

- The room starts it at its `bpm` (150 by default: 0.4 s a beat, already the game's hidden
  pulse: the call countdown ticks every 0.4 s, Sphaera's pendulums swing on 0.4, a slash comes
  back in 0.41 s, a jump rises for 0.39 s). 4 beats a bar.
- It's never reset inside a room, not when you die, not on R: what you learn about the room's
  rhythm holds from try to try.
- It pauses with F1 and stops with the room. A click on every beat, brighter on the 1 (M).
- Asking it in code: signals `beat(index)` and `bar(index)`; `time()`, `beat_length()`,
  `beat_in_bar()`, `phase()`, `beats_at(t)`, `offset_to_beat(t)` / `offset_to_downbeat(t)`.
- `BeatDisplay` (`ui/beat_display.gd`) shows it: four dots, the current one lit, the 1 larger.

The wall gym's `Metronome` (`levels/metronome.gd`) is a separate, older clock the wall rhythm
uses; a room with a shaft runs one at its BPM next to `Beat`.

## Examples

`levels/kit/showcase/` (menu: "Kit: showcase"): one small room per piece, entered from a
selection room (`hub.tscn`) with a goal for each, on a shelf: jump up into one together. Each
room's goal brings you back to the selection room. A new piece gets a room there and a goal in
the hub.

- `spikes` (plain and timed), `hammer`, `switch` (a struck lamp, timed), `plates` (one for each of you, the door
  needs both), `pendulum`, `beat_step`.
- `shafts`: WIDE, NARROW and COOP side by side, the goal on top of the coop one. Change the
  room's BPM and watch them change.
- `cannon`: P2 parries the ball on the right ledge, P1 on the left one, into the target that
  opens the door to the goal.
- `elevator`: up to the goal's ledge on `1-2-1-2-1-1-2-2-3`.
- `walls`: the blocks' looks and edges, and KitText.
