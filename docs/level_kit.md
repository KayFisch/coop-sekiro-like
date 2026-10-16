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
   Horologium, `levels/horologium/horologium.tscn`, is already there, empty, and is what the menu
   starts.)
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
| **KitBlock** | Wall, floor, ceiling; or a one-way platform (jump up through it, down to drop). Position: top-left. | `size`; `one_way`; `owner_id` (one-way only): Both, P1 (carries only P1, blue) or P2 (only P2, orange). |
| **KitSpikes** | Touch them and you both start over. Position: one end of the base. | `length`, `facing` (up, down, left, right). |
| **KitSwitch** | A switch wired to doors. Position: a plate's on the floor; a struck one's at its middle. | `trigger`: STRIKE (hit it with the blade) or PLATE (stand on it). `who`: anyone, P1 or P2. `mode`: TOGGLE, ONCE, TIMED (`timed_bars`), HOLD (plate: while stood on). `on_the_one`: a strike only counts on the 1 (±0.1 s); off it, it's out of tune until after the next 1. `targets`: the doors (*Add Element*, then *Assign* and pick the door). The editor draws the wires. |
| **KitDoor** | What a switch opens. Position: top-left. | `size`; `kind`: SOLID (switched: opens) or PLATFORM (switched: appears, one-way); `owner_id` (a platform's); `needs`: any switch, or all of them (two plates far apart, one each); `inverted` (open until switched: it shuts). A door shutting on a player kills. |
| **KitHammer** | A hammer slamming down from the ceiling on its beats; deadly while falling, down, and rising until it clears your head. Can't be jumped over. Position: on the floor, in its middle; put a KitBlock as the ceiling `clearance` above. | `pattern`, `bars`, `offset` (see *Rhythms*), `width`, `clearance`, `hold_beats` (how long it lies down), `rise_beats`. |
| **KitPendulum** | A blade on a rod swinging with the clock (bottom on the 1 and the 3, turning points on the 2 and the 4). Rod and blade kill. A perfect parry locks it and holds the parrier for one swing; a block knocks you away. Position: the pivot. | `length`, `amplitude_deg`, `bars` (per swing: 2 is half as fast), `offset` (2: starts the other way). |
| **KitBeatStep** | A one-way platform that's there only on its beats; blinks in its last beat. Position: top-left. | `pattern`, `bars`, `offset`, `owner_id`, `width`. |
| **KitShaft** | Two facing walls for wall jumps, as wide as the tempo says. Position: the left wall's top-left; the walls stand `height` tall on a floor there. | `kind`: WIDE (a beat's flight: hold toward the far wall), NARROW (half a beat: no steering), COOP (two wide ones: too wide alone, a chimney clash in the middle). `height`, `entrance` (a way in under the left wall), `caps` (ledges on top), `rhythm` (F1 wall rhythm). A room with a shaft switches on what wall jumps need while it runs, and ticks a metronome at its BPM. |
| **KitGoal** | Both in it: the room is done. Position: top-left. | `size`. |

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

- `levels/kit/kit_showcase.tscn` (menu: "Kit: showcase"): every piece once, in a row.
- `levels/kit/kit_shafts.tscn` (menu: "Kit: shafts"): WIDE, NARROW and COOP side by side, the
  goal on top of the coop one. Change the room's BPM and watch them change.
