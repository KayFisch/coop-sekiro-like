# CLAUDE.md

Shared context for everyone working on this repo with Claude. Two people work on it, each with
their own Claude sessions; this file, `TASKS.md` and `scribbles.md` are how we stay in sync.
Keep this file short and true: when something here goes stale, fix it in the same commit.

## Handover notes

A note from one person to the other. **Claude: at the start of a session, if a note here is
addressed to the person you're working with, tell them about it (in German, briefly) before
anything else, then delete the note in your next commit.**

### For Kay, from Nick (2026-09-30)

- The repo was restructured: the Godot project moved from `new-game-project/` to the **repo
  root**, and the design docs moved to `docs/` (`concept.md`, `boss_sphaera_pendula.md`,
  `parkour_gyms.md`). Your "basics revamp" is included unchanged.
- In Godot: open the project again via `coop-sekiro-like/project.godot` and remove the old
  "new-game-project" entry. Delete the leftover local `new-game-project/` folder (it only holds
  the old `.godot` cache).
- New shared files: this `CLAUDE.md` (please read "Git workflow": commit format
  `type: message`, branches `name/topic` for bigger things), `TASKS.md` (claim tasks with
  `@name`; open design questions at the top, side-scroller vs. top-down first) and
  `scribbles.md` (dump unfinished ideas there).
- Cleanup of the `.gd` files is planned in `TASKS.md`: part 1 can start now, but splitting
  `player.gd` waits until side-scroller vs. top-down is decided.

## The project

A 2D local co-op boss-fight game in Godot 4 (GDScript), inspired by Sekiro and Cuphead. The
core idea: players act *through* each other (parry relay: one player's perfect parry passes the
boss's attack to the partner). Full pitch and current moveset: `docs/concept.md`.

**Status: prototype, design under review.** After the first playtest (2026-09-29) some
fundamental questions are open, the biggest being **side-scroller vs. top-down** (see
`TASKS.md` → "Offene Grundsatzfragen"). Treat the existing bosses, attacks and moves as
experiments, not settled design. Nothing is sacred; don't preserve code for its own sake, and
don't build on a mechanic whose question is still open without asking.

## Repo layout

The repo root *is* the Godot project (`project.godot` sits here; `res://` = repo root).

```
CLAUDE.md  TASKS.md  scribbles.md    shared working files (see below)
docs/                                design docs: concept.md, boss_sphaera_pendula.md, parkour_gyms.md
core/                                autoloads: GameManager, Sfx, Moves
actors/player/                       player.gd (+ scene)
actors/bosses/                       base_boss.gd, base_attack.gd, one folder per boss with attacks/
levels/                              arena/ (fight 1), scales/ (fight 2), gym/ (movement test rooms)
ui/                                  boss select, HUD
assets/                              empty for now: everything is procedural
```

Keep every `.gd.uid` next to its `.gd` and move them together (Godot references scripts by uid).
Move files with `git mv`, or in the Godot editor, never one without the other.

## Shared working files

- `TASKS.md`: what's being done, by whom, and the open questions. Read it at the start of a
  session. Claim a task (`@name`) before starting it, so we don't both edit the same files.
  Tick it off in the commit that finishes it.
- `scribbles.md`: unfinished ideas, playtest observations, "what if...". Append, don't polish.
  A decision moves to `docs/`; work moves to `TASKS.md`.

## Git workflow

- `git pull` before starting. `main` should always open and run in Godot.
- **Small changes** (tuning, fixes, docs): commit straight to `main`, pull, push.
- **Anything bigger or experimental** (new boss, a rework, a refactor touching many files):
  a branch `<name>/<topic>` (e.g. `kay/top-down-test`, `nick/player-split`), merged into `main`
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
4.7.2 on Nick's machine: `C:/Program Files/Godot_v4.7.2-stable_win64_console.exe` (Kay's may
differ). From the repo root:

```bash
godot --headless --import                                  # reimport, shows parse errors
godot --headless --quit-after 180 res://levels/arena/arena.tscn   # run a scene ~3 s
```

Any `SCRIPT ERROR` / `Parse Error` in the output means it's broken. A clean run only means it
loads; the feel still needs a human test.

## Code map

- `core/` autoloads: `GameManager` (sync meter, game state, restart, scene switching;
  `SYNC_GAINS` maps boss `sync_event` kinds to sync), `Sfx` (all sound synthesized at startup,
  `Sfx.play("name")`), `Moves` (F1 panel toggling movement abilities, saved to
  `user://moves.cfg` with a `VERSION`: bump it when defaults change; code asks
  `Moves.on("pogo")`). The fight kit is on by default, the platforming kit is off.
- `actors/player/player.gd`: one large script (~2000 lines) with all player logic: movement,
  walls/ledges, sword swings, partner clashes (launch, momentum relay, pogo clash, call),
  potions, defensive queries the boss uses (`is_perfect_parry()` etc.), and some boss-specific
  hooks (gather, tether, grab). Tuning constants at the top, grouped by feature.
- `actors/bosses/`: `BaseBoss` runs the state machine
  `IDLE → TELEGRAPH → ATTACKING → RECOVER/STAGGER`; each attack is an `Attack` (`RefCounted`,
  `base_attack.gd`) with hooks `start / update_telegraph / execute / update / on_struck /
  cleanup` and `finish()` / `finish_with_stagger()`. A boss subclass supplies its attack pool,
  weights, pose and HP. Bosses: `cubus_maximus/`, `sphaera_pendula/` (needs the Scales level).

## Conventions

- Everything is procedural: shapes drawn in code, sound synthesized. No external assets yet.
- Tuning values are named `const`s with a comment saying what they mean in feel terms
  ("0 -> SPEED in ~0.06 s"), grouped under `# --- Feature ---` headers.
- New movement abilities get a `Moves` switch so they can be A/B tested.
- Attacks telegraph by color; each color means one player response (see the boss 2 doc).
- Input: P1 keyboard, P2 gamepad (`p1_*` / `p2_*` actions; the player reads `_action("jump")`).
- Code, comments, docs and commit messages in English; `TASKS.md` / `scribbles.md` in any language.
