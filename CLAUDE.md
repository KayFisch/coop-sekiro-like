# CLAUDE.md

Shared context for everyone working on this repo with Claude. Two people work on it, each with
their own Claude sessions; this file, `TASKS.md` and `scribbles.md` are how we stay in sync.
Keep this file short and true: when something here goes stale, fix it in the same commit.

## Session start: pull, then tell what's new

A SessionStart hook (`.claude/settings.json` → `.claude/hooks/session-start.sh`) pulls
automatically and puts a "Session start" block into your context: pull result and the commits
since this clone's last session (tracked in `.git/claude-last-seen`, per clone). On a branch
other than `main` it also lists what's new on `main`, which the pull doesn't bring: mention
that too, and offer to merge `main` into the branch if it has fallen behind.

**Claude: at the start of every session, before anything else:**

1. Ask who you're working with (Nicho or Kay) if it isn't clear yet.
2. Read the hook's block. If it's missing (hook didn't run), do it by hand: note
   `git rev-parse HEAD`, `git pull`, compare. If the pull failed or was skipped (uncommitted
   changes), say so first.
3. If there are new commits, summarize for the person, in German, short (a few bullets):
   - what the *other* person changed: read the relevant diffs (`git diff <old>..HEAD`);
     describe what changed in the game (feel, mechanics, structure), not file by file
   - new or changed entries in `TASKS.md` (open questions, claimed tasks) and `scribbles.md`
   - anything that needs action from them (reopen the project, a claimed file to avoid, ...)
   On a first session in a clone, summarize the recent commits by the other person instead.
4. Handover notes below addressed to this person: pass them on, then delete them in your next
   commit.
5. Nothing new: one line saying so.

When you finish work that the other person should know about and that the commits don't
explain well (a moved folder, a changed convention, a decision), leave a handover note.

## Handover notes

Notes from one person to the other, under `### For <name>, from <name> (<date>)`.

### For Nicho, from Kay (2026-10-15)

- **`Beat`** (`core/beat.gd`) is a new autoload: one clock (150 BPM) that a level starts and
  everything in time asks, with a click (M) and a display (`ui/beat_display.gd`). It's meant for
  your beat-runner too: please use it rather than a second clock (`docs/level_kit.md`).
- `kay/coop-platformer` now has your slimmer players: the changes to `actors/player/` from
  70470c7 taken character for character (`git apply -3`), so they merge without conflicts.
  The gyms are adapted to 20 px bodies (chimneys 110 and 380 wide).
- A level kit for building coop rooms by hand in the Godot editor (`levels/kit/`, `KitRoom` and
  `Kit*` pieces, `docs/level_kit.md`); Kay builds Horologium with it. `Moves.override()` lets a
  room switch something on while it runs without saving it. `GymLevel` has a new option
  `checkpoint_needs_all` (off by default): a checkpoint takes only once every player is in it.

## The project

A 2D local co-op boss-fight game in Godot 4 (GDScript), inspired by Sekiro and Cuphead. The
core idea: players act *through* each other (parry relay: one player's perfect parry passes the
boss's attack to the partner). Full pitch and current moveset: `docs/concept.md`.

**Status: prototype, design under review.** Settled: it's a **2D side-scroller**. After the
first playtest (2026-09-29) other fundamental questions are open (see `TASKS.md` → "Offene
Grundsatzfragen"). Treat the existing bosses, attacks and moves as
experiments, not settled design. Nothing is sacred; don't preserve code for its own sake, and
don't build on a mechanic whose question is still open without asking.

## Repo layout

The repo root *is* the Godot project (`project.godot` sits here; `res://` = repo root).

```
CLAUDE.md  TASKS.md  scribbles.md    shared working files (see below)
docs/                                design docs: concept.md, boss_*.md (one per boss), level_*.md (one
                                     per level), parkour_gyms.md
core/                                autoloads: GameManager, Sfx, Moves, Pads, Beat
actors/player/                       player.gd (+ scene)
actors/bosses/                       base_boss.gd, base_attack.gd, one folder per boss with attacks/
levels/                              arena/ (fight 1), scales/ (fight 2), threshold/ (test boss),
                                     gym/ (movement test rooms), kit/ (level kit: rooms built in
                                     the editor), horologium/ (coop platformer level, kit rooms)
ui/                                  boss select, HUD, beat display
assets/                              empty for now: everything is procedural
```

Keep every `.gd.uid` next to its `.gd` and move them together (Godot references scripts by uid).
Move files with `git mv`, or in the Godot editor, never one without the other.

## Shared working files

- `TASKS.md`: what's being done, by whom, and the open questions. Read it at the start of a
  session. Claim a task (`@name`) before starting it, so we don't both edit the same files.
  Tick it off in the commit that finishes it.
- `TASKS.local.md` (gitignored, optional): a personal todo list, for things that only concern
  one person (learning Godot, reminders). Not shared; never put team tasks there.
- `scribbles.md`: unfinished ideas, playtest observations, "what if...". Append, don't polish.
  A decision moves to `docs/`; work moves to `TASKS.md`.

## Git workflow

- `git pull` before starting. `main` should always open and run in Godot.
- **Small changes** (tuning, fixes, docs): commit straight to `main`, pull, push.
- **Anything bigger or experimental** (new boss, a rework, a refactor touching many files):
  a branch `<name>/<topic>` (e.g. `kay/top-down-test`, `nicho/player-split`), merged into `main`
  once it runs. Delete it after merging.
- Don't have both people touching `player.gd` or the same `.tscn` at the same time (claim it in
  `TASKS.md`). Scene files merge badly; prefer building nodes in code, as the existing scripts do.
  Rooms built with the level kit are the exception: scenes by design, one person per room.
- Claude commits or pushes only when asked.

### Commit messages

`<type>: <what changed>`, English, imperative, lowercase, no period, ≤ 72 chars. Body optional,
for the *why*.

| type | for |
|---|---|
| `feat` | a new mechanic, attack, boss, level, UI |
| `tune` | changing numbers / feel only |
| `fix` | a bug |
| `refactor` | restructuring without changing behavior |
| `docs` | docs, CLAUDE.md, TASKS.md, scribbles.md |
| `chore` | project settings, gitignore, tooling |

Optional scope in parentheses: `feat(cubus): add grab follow-up`, `tune(player): shorter dash`.

## Checking a change (Claude)

Nobody can *play* the game but the humans, but Godot runs headless for a smoke test. Godot
4.7.2 on Nicho's machine: `C:/Program Files/Godot_v4.7.2-stable_win64_console.exe` (Kay's may
differ). From the repo root:

```bash
godot --headless --import     # reimport: shows parse errors, registers new class_names and .uid files
godot --headless --fixed-fps 60 --quit-after 600 res://levels/arena/arena.tscn   # 10 s of game time, at once
```

Any `SCRIPT ERROR` / `Parse Error` in the output means it's broken. A clean run only means it
loads; the feel still needs a human test.

To test behavior, drive a scene from a throwaway script outside the repo:
`godot --headless --script <file.gd>` with a script that `extends SceneTree`. From
`_initialize()` on the autoloads exist (reach them with `root.get_node("GameManager")`; their
names don't compile in such a script); `change_scene_to_file()` loads a level, and the
`physics_frame` signal runs before every node's `_physics_process`, so `Input.action_press()`
there is seen by the players that same frame. The player's timing windows (parry, dodge) read
the real clock, so anything pressing buttons has to run in real time, without `--fixed-fps`.
Leave the saved switches alone (`Moves.set_value()` writes `user://moves.cfg`); set what a test
needs in memory (`Moves._values[key] = ...`) once the scene has loaded, including
`swap_controls = false`: the saved file may have it on. Hold a pressed button a few frames
before releasing it: a press released on the next frame can reach the player without the
buttons held with it (e.g. down for a pogo).
Such a test script can't name a class whose script uses an autoload (`BeatStep`, `GymTarget`...):
it fails to compile. `load()` the script, or compare `get_script().resource_path`.

## Code map

- `core/` autoloads: `GameManager` (sync meter, game state, restart, scene switching;
  `SYNC_GAINS` maps boss `sync_event` kinds to sync), `Sfx` (all sound synthesized at startup,
  `Sfx.play("name")`), `Moves` (F1 panel toggling movement abilities, in tabs by theme, saved to
  `user://moves.cfg` with a `VERSION`: bump it when defaults change; code asks
  `Moves.on("pogo")`). The fight kit is on by default, the platforming kit is off. `Pads` gives
  each connected gamepad to one player (rebinding the `p1_*` / `p2_*` pad events per device).
  `Beat` is the one clock for everything in time (150 BPM; a level starts it, it's never reset
  inside one; signals `beat` / `bar`, `offset_to_downbeat()` etc.; click on M).
- `actors/player/player.gd`: one large script (~2000 lines) with all player logic: movement,
  walls/ledges, sword swings, partner clashes (launch, momentum relay, pogo clash, call),
  potions, defensive queries the boss uses (`is_perfect_parry()` etc.), and some boss-specific
  hooks (gather, tether, grab). Tuning constants at the top, grouped by feature. The sword's
  rules are under "THE SWORD" there: a swing commits (windup, cut, return; no block or parry
  until the blade is back at rest), and a swing an enemy blade parries recoils
  (`on_swing_parried()`, called by the boss). A boss that changes sides can hold the players'
  facing (`BaseBoss.holds_facing()`); the dash then goes the way the stick is held. A perfect
  parry landed mid-dash carries the player through the boss's body ("DASH-PARRY").
- `actors/bosses/`: `BaseBoss` runs the state machine
  `IDLE → TELEGRAPH → ATTACKING → RECOVER/STAGGER`; each attack is an `Attack` (`RefCounted`,
  `base_attack.gd`) with hooks `start / update_telegraph / execute / update / on_struck /
  cleanup` and `finish()` / `finish_with_stagger()`. A boss subclass supplies its attack pool,
  weights, pose and HP. Bosses: `cubus_maximus/`, `sphaera_pendula/` (needs the Scales level),
  and `columna_bifrons/`, a test boss for fighting from both sides, and with both players on
  one (`docs/boss_columna_bifrons.md`): each of his two swords fights one player wherever they
  are (`ward_of()`), and turns on the other one while its own is away (`_update_turns()`); all
  his attacks in one table (`ATTACKS`: a weight per situation, and either a list of strikes,
  run by `StrikePattern`, or a script of its own: `Sweep`, `Leap`, `Shove`); a guard that
  overrides `take_damage()` (a blade standing at its flank parries, `is_guarding()`; one that's
  swinging can't); his own movement (where he stands: `_place()` / `walk()`; a lunge with every
  strike: `lunge_goal()`; making room: `make_room()`; charging past a player, leaping between
  them, rushing one who's away); a reactive mode in which he strikes back at whoever attacked
  him (started from his own `_physics_process()`, outside BaseBoss's idle timer); and
  `stand_in.gd`, which plays one of the players for testing alone, by pressing that player's
  buttons.
- `levels/`: `GymLevel` (`gym/gym_level.gd`) is the base of the gyms and the platformer levels:
  it builds rooms from code (`solid()`, `ledge()`, `checkpoint()`, `measure()`, ...), spawns the
  players, respawns them at checkpoints (`checkpoint_needs_all`: only once both are there) and
  gives each player a physics layer of their own (`OWN_PLATFORM_LAYERS`). `kit/`: the level kit
  (`docs/level_kit.md`), `@tool` nodes placed by hand in the Godot editor: `KitRoom` (the scene's
  root: spawns the players, both start over when one dies, the goal loads `next_room`) and its
  pieces (`KitBlock`, `KitSpikes`, `KitSwitch` wired to `KitDoor`, `KitShaft`, ...); the ones on
  the clock extend `Clockwork` and work out their state from `Beat` alone (in the editor, from a
  stand-in clock at the room's BPM). `horologium/`: the coop platformer's rooms.

## Conventions

- Everything is procedural: shapes drawn in code, sound synthesized. No external assets yet.
- Tuning values are named `const`s with a comment saying what they mean in feel terms
  ("0 -> SPEED in ~0.06 s"), grouped under `# --- Feature ---` headers.
- New movement abilities get a `Moves` switch so they can be A/B tested.
- Attacks telegraph by color; each color means one player response (see the boss 2 doc).
- Input: two sets of actions, `p1_*` (keyboard) and `p2_*` (gamepad); the player reads
  `_action("jump")`. One pad: P1 keyboard, P2 pad. Two pads: one each (P1 keeps the keyboard too).
- Code, comments, docs and commit messages in English; `TASKS.md` / `scribbles.md` in any language.
