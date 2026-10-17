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

### For Kay, from Nicho (2026-10-16)

- On `nicho/pep-test`, Bifrons's fight now runs on **sync as life** by default (F1,
  "bifrons_rules": "sync"; "hp" is the old way): no health and no potions, the two of you share
  one sync meter and the boss has his own, everyone has a posture (a bar under the meters),
  and the same rules hold for players and boss. No sync is "chaos" (no blocking, one more hit
  ends it), full sync is the sync mode. Nicho's decisions are in the scribble of 2026-10-16, the
  rules in `docs/boss_columna_bifrons.md` ("Sync as life"). Cubus and Sphaera are untouched.
- New on the branch: an **F2 panel** to tune numbers while playing (`core/tuning.gd`, a new
  autoload, saved to `user://tuning.cfg`), for now holding the sync rules. It could take numbers
  of yours too.
- `player.gd` on the branch got small hooks for it (`take_damage()`, `is_blocking()`,
  `on_perfect_parry()`, a sword cue): they do nothing unless a fight sets `GameManager.rules`.
- 2026-10-17, on `nicho/posture-rules` (it holds `nicho/pep-test` and `nicho/beat-runner`):
  the rules got simpler. Attacks are normal or heavy (his heavy ones: both swords; yours: in
  sync mode); posture is lost in three sizes, by parrying (both sides alike), blocking (only
  the one who blocks) or being hit; sync only by a hit; posture comes back 2 s after the last
  attack. Nicho's scribble of 2026-10-17 has it all.
- Also on `nicho/posture-rules`, in `player.gd`: the swords are a little broader (8 px), with a
  crossguard and a point (`_setup_sword()`, hitbox unchanged), and `blade_point()` for the new
  sync energy (`actors/player/sync_wave.gd`): a parry's energy runs visibly to the partner's sword.

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
docs/                                design docs: concept.md, boss_*.md (one per boss), parkour_gyms.md,
                                     art_brief.md (sizes, colors, poses: for generating sprites),
                                     beat_runner.md, beat_ring.md
core/                                autoloads: GameManager, Sfx, Moves, Pads, Tuning;
                                     sync_rules.gd (sync as life, Bifrons), sync_bond.gd (sync mode)
actors/player/                       player.gd (+ scene), sync_wave.gd (the parry's energy to the partner)
actors/bosses/                       base_boss.gd, base_attack.gd, one folder per boss with attacks/
levels/                              arena/ (fight 1), scales/ (fight 2), threshold/ (test boss),
                                     gym/ (movement test rooms), runner/ and ring/ (between the
                                     bosses, prototypes)
ui/                                  boss select, HUD, the mirrored screen (mirror_view.gd)
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
Leave the saved switches alone (`Moves.set_value()` writes `user://moves.cfg`).

## Code map

- `core/` autoloads: `GameManager` (sync meter, game state, restart, scene switching;
  `SYNC_GAINS` maps boss `sync_event` kinds to sync), `Sfx` (all sound synthesized at startup,
  `Sfx.play("name")`), `Moves` (F1 panel toggling movement abilities, saved to
  `user://moves.cfg` with a `VERSION`: bump it when defaults change; code asks
  `Moves.on("pogo")`). The fight kit is on by default, the platforming kit is off. `Pads` gives
  each connected gamepad to one player (rebinding the `p1_*` / `p2_*` pad events per device).
  `Tuning` (F2 panel of numbers to tune while playing, saved to `user://tuning.cfg`; code asks
  `Tuning.value("his_heavy_damage")` each time it needs one; a page per level: the runner's and the
  ring's in theirs, the sync rules elsewhere). Both panels show one tab at a time (Q / E): an
  entry's "tab" (F1), a header's "tab" (F2).
- `core/sync_rules.gd` (`SyncRules`): sync as life, for now only in Bifrons's fight (Moves
  "bifrons_rules"): no health, no potions, a shared sync for the players and one for the boss,
  a posture each, chaos at no sync, sync mode at full. Attacks are normal or heavy (his: both
  swords; theirs: in sync mode); posture is lost in three sizes, by parrying (both sides),
  blocking (the blocker only) or being hit, and comes back 2 s after the last attack in or out.
  The boss creates it and hands it to `GameManager.rules`; while that's set,
  `Player.take_damage()` and the boss's hits go through it (`ColumnaBifrons.land()` says whether
  a strike is heavy: `landing_heavy`), and the HUD shows the two meters instead of health.
- `core/sync_bond.gd` (`SyncBond`, the rules' `bond`): the sync mode itself. Players standing
  together bind (`Player.bond`, sabres via `set_sabre()`), hold attack to draw back
  (`Player._process_charge()`), let go together on the big cue for a heavy strike
  (`ColumnaBifrons.take_pair_strike()`); he slows down and strikes with both swords
  (`in_sync_mode()`, `time_unit()`).
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
- `levels/runner/runner.gd` (`BeatRunner`, `docs/beat_runner.md`): a prototype for between the
  bosses. The mirrored screen, players running on the spot (`Player.running_on`), and things
  coming at them on a beat (orbs to parry, shards to hit, blocks to jump), planned from
  `ColumnaBifrons.ATTACKS`; a parry relays a shard to the partner. Its own sync meter and UI.
- `levels/ring/ring.gd` (`BeatRing`, `docs/beat_ring.md`): the second prototype for between
  the bosses: Bifrons's fight without him. The mirrored screen in his room, players moving
  freely, a circle around the middle marking each thing's beat; his patterns (his table, weights
  and tempo) come level at the players from their sides, diagonally, until his crossing puts both
  on one side and his leap (a sweep) parts them again; a parry sends the partner a violet shard
  along the circle, timed like the boss fight's partner hit.
- `ui/mirror_view.gd` (`MirrorView`, in Bifrons's room, Moves "mirror_view"): an alternative
  picture of the fight, the screen split at the floor, P1 above, P2 in the reflection below.
  Two SubViewports on the level's World2D; what each half draws is chosen by visibility layers
  (`Viewport.canvas_cull_mask`), so the game itself doesn't change.

## Conventions

- Everything is procedural: shapes drawn in code, sound synthesized. No external assets yet.
- Tuning values are named `const`s with a comment saying what they mean in feel terms
  ("0 -> SPEED in ~0.06 s"), grouped under `# --- Feature ---` headers.
- New movement abilities get a `Moves` switch so they can be A/B tested.
- Attacks telegraph by color; each color means one player response (see the boss 2 doc).
- Input: two sets of actions, `p1_*` (keyboard) and `p2_*` (gamepad); the player reads
  `_action("jump")`. One pad: P1 keyboard, P2 pad. Two pads: one each (P1 keeps the keyboard too).
- Code, comments, docs and commit messages in English; `TASKS.md` / `scribbles.md` in any language.
