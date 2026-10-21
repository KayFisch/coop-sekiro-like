# Developer tools

For building and tuning fights by numbers rather than by feel, for every boss to come
(2026-10-18, branch `nicho/code-overhaul`). In the game the function keys open them; outside it,
tests and a performance probe run from the command line.

## In the game

| Key | What |
|---|---|
| F1 | Switches (`core/moves.gd`), in tabs: Q / E. Tab "Dev": write the fight log to a file. |
| F2 | Numbers (`core/tuning.gd`), laid out as F1: a page per system (Z / C: sync rules, Bifrons, runner, ring), its tabs (Q / E), its numbers (↑/↓ pick, ←/→ change, Shift: ten steps, Ctrl: a tenth of one; no number has a limit but 0). Opens on the page of the level it's in. |
| F3 | Overlay: frame time, the boss and the players right now, and this fight in numbers. |
| F4 | Hitboxes: every collision shape, and the boss's body block (red). |
| F5 | Boss lab: run one of his attacks, again and again, and set things up for it. |

### F3: the overlay

- **Frame time**: mean, 95th percentile and worst of the last 120 frames, nodes, draw calls, the
  game's speed. On Nicho's machine every level takes about 1 ms a frame.
- **The boss**: his state (IDLE, TELEGRAPH, ATTACKING, RECOVER, STAGGER), the attack running and
  its phase, his timer, whether the lab holds him; with sync as life his sync and posture
  (and whether it's coming back), the players' sync, chaos, the sync mode.
- **Each player**: what they're doing (ground, air, dash, wall ...), an open parry window,
  blocking, swinging, staggered, invincible, posture.
- **This fight**, per player, counted since the level started:
  - parried / blocked / hit;
  - "parry pressed 0.07 s before": how long before his blade landed the successful parries
    were pressed (median). The window is 0.133 s; near 0 is late, near 0.13 early;
  - missed "too early": hit although block was pressed, more than the window before (median:
    how long before); "late": block pressed after it landed, within 0.3 s (median: how late);
    "no press": hit with no try at all;
  - sync hits on the beat / after it, and how far into the window they came (median);
    windows nobody used;
  - the sync mode's strikes: let go together on the cue, or out of sync (median: how far off).

  That's what tuning by numbers starts from: if most misses are "late", the cue (his blade's
  drop, F2 Bifrons → tempo) or the parry window is too short; if the parries come at 0.12 s
  before, people press as early as they can, and so on.
- **The log**, with F1 → Dev "fight_log": the same events, one JSON line each, in
  `user://fight_log.jsonl` (on Windows `%APPDATA%/Godot/app_userdata/<project>/`), new for each
  fight. Each line has the fight time `t`, `kind` (parry, block, hit, late_press, sync_hit,
  window_missed, pair_release) and its details.

### F5: the boss lab

Shows his attacks (any boss: his attack pool). Its keys work while it's open, and are none of
the players'; while F1 or F2 is open (the game paused), theirs come first. Q / E pick, as they
pick the tab there. Letters go by what's on the key (Z is Z on a German keyboard too).

| Key | What |
|---|---|
| Q / E | pick an attack |
| Z | he starts it next (now, if he's free), in reach or not; then he fights on, or, held (H), does nothing more |
| X | he loops it: the same attack each time he's free again, held or not (X again: stop) |
| H | his own attacks off / on: he starts nothing of his own (the lab's attacks still come) |
| M | his moving off / on: he stays where he is between attacks (his attacks still move him) |
| T | the game's speed: 1, 0.5, 0.25 |
| I | the players can't lose (their hits still land, and are logged) |
| K / J / N | the players' sync full (sync mode) / half / empty (chaos) |
| B | his sync full · P everyone's posture full |
| ← / → / G | both players on his left / on his right / one on each side |

So one attack can be tried over and over, slowed down, with F3 counting the presses: "loop
TRIPLE, half speed, five tries, how late were the misses".

## Tests

```bash
godot --headless --script res://tests/run.gd                    # all of them (about a minute)
godot --headless --script res://tests/run.gd -- sync_rules ring  # just these files
```

Every `tests/test_*.gd` runs, each of its `test_*` methods in turn, in real time (the players'
timing windows read the real clock: no `--fixed-fps`). A test fails if a check fails or if the
engine reports any error while it runs. The output ends with "N passed, M failed".

What's there: the sync rules (what each landing costs whom, breaking, regen), the partner's
window, the sync mode (binding, the strike together, his hold-off, the dash-slash through him),
the ring's violet shard, the player's feel (speed, jump, dash, parry window, swing timing), the
dev tools, the Kultist (his elements, halves, guard, flight and attacks), and that every scene
loads and runs.

Writing one: a file `tests/test_<topic>.gd` that `extends "res://tests/test_case.gd"`, with
methods `test_<what>()`. From `test_case.gd`:

- `await load_scene(path)`: the level from scratch, as the select screen loads it;
- `set_move(key, value)`, `set_number(key, value)`: a switch or an F2 number for this test only
  (in memory, never saved, put back afterwards). Every test starts with all of them at their
  defaults, so what's saved on a machine doesn't change the result;
- `hold(player, "attack")`, `hold(player, "attack", false)`, `await tap(player, "block")`: press
  a player's buttons, as the stand-ins do;
- `await wait(seconds)`, `await frames(n)` (physics frames; a press is seen the frame after);
- `check(condition, "what")`, `near(got, want, tolerance, "what")`;
- the boss: `GameManager.boss.dev_hold = true` (he starts nothing of his own), `dev_next = "NAME"`
  (he starts that next), `dev_still = true` (he doesn't move between attacks),
  `set_physics_process(false)` (he doesn't move at all).

Add a test with every rule or mechanic you'd hate to break silently; run them all before a merge.

## Numbers on F2

A number someone may want to tune while playing goes on F2; one that's structure (a size that
other numbers are built on, an enum) stays a `const`. Each system declares its own, next to its
code:

```gdscript
# Its numbers on F2 (core/tuning.gd collects them).
static func tuning_entries() -> Array:
	return [
		{"page": "mine", "title": "MY BOSS", "scenes": ["levels/my_room/"], "header": "TEMPO", "tab": "tempo"},
		{"key": "mine_wait", "label": "between two attacks (s)", "default": 0.5, "step": 0.05},
		{"header": "...", "column": 1},  # the panel's second column
	]
```

and is listed in `Tuning.SOURCES`. A header's `page`, `title`, `scenes` and `tab` hold for the
entries after it until another header names its own. Code reads `Tuning.value("mine_wait")` each
time it needs it, so a change counts at once. Keys start with their system's name. Changing a
default: bump `Tuning.VERSION` only if old saves must be dropped (it drops every saved number).

## Measuring performance

```bash
godot --disable-vsync --script res://tools/perf_probe.gd                     # every level
godot --disable-vsync --script res://tools/perf_probe.gd -- res://levels/horologium/horologium1.tscn
```

In a window (it has to draw). For each level: the frame time (mean, 95th percentile, worst),
draw calls, nodes, and the scripts running every frame. On Nicho's machine (RTX 4060 laptop)
every level takes 0.7 to 1.0 ms a frame. In the game, F3 shows the same live.

Since 2026-10-18 the project renders with the Compatibility renderer (OpenGL), which is much
lighter for 2D than Forward+ (Direct3D 12), and the level kit's clockwork pieces redraw only 12
times a second in the editor (`Clockwork.EDITOR_FPS`).

## A new boss: what to do

1. `actors/bosses/<name>/<name>.gd`, extending `BaseBoss`; his attacks as `Attack`s in
   `attacks/` (see the code map in `CLAUDE.md`). A big one in layers, each file extending the
   one before, as Bifrons: his swords (`bifrons_swords.gd`), his moving (`bifrons_moves.gd`), the
   boss himself (`columna_bifrons.gd`).
2. His feel numbers on F2: `tuning_entries()`, listed in `Tuning.SOURCES`. Attack weights too,
   if they're to be tuned (see `ColumnaBifrons.weight_in()`).
3. The dev tools work for him by themselves: the lab lists his attack pool, `dev_hold`,
   `dev_next` and `dev_still` are `BaseBoss`'s (`dev_still` skips his `_idle_motion()` and
   `_recover_motion()`: move him there), the overlay reads his state, and the players' parries, blocks
   and hits are logged by the player. Anything that starts an attack outside `BaseBoss`'s idle
   timer (as Bifrons's shove and his strike back) has to respect `dev_hold`. Report what's his
   own to `Dev.note(kind, data)`.
4. Tests for his rules (`tests/test_<name>.gd`).
5. To test alone, a stand-in that presses a player's buttons (Bifrons's `stand_in.gd`).
6. `docs/boss_<name>.md`, and an entry in `ui/boss_select.gd`.
