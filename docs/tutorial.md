# The tutorial

Built 2026-11-03 for the playtest with two friends (`TASKS.md`, B4 of the handover of 2026-10-31);
since 2026-11-06 with moving first and the sync rules said (Nicho, after playing it: how sync works
wasn't told). A little moving, then a guided fight against a training dummy, step by step: what
every fight asks, none of a single boss's own rules (the Kultist's elements, the Acrobat's strike
back, the Hitter's rage), no cards before the fights. First entry on the select screen, always
shown.

Code: `levels/tutorial/`: `tutorial.tscn` (Bifrons's room, an inherited scene of
`levels/threshold/threshold.tscn`), `tutorial.gd` (the steps), `tutorial_text.gd` (the words in
each half), `dummy_look.gd` (his look). Tests: `godot --headless --script res://tests/run.gd --
tutorial`.

## The dummy

The try-out boss in a training dummy's look: a straw sack with seams over his body (his own colors
show through, and the half of him that lights up yellow as he winds up still does), a crossbar,
a sack head with a target stitched on, a plank. Why him and no boss of its own: he already has
everything the tutorial teaches (two blades, yellow then red, each blade in its player's half,
green for two blades on one place, the windows and the pink wave, reeling after a co-op parry,
the sync mode and the pair's strike), so the tutorial shows the rules exactly as they are in the
fights.

He stands still between his attacks (`dev_still`), and the tutorial sends him each one
(`dev_next`, as the F5 lab's loop does); none while the lab holds him (`dev_hold`), none while
they move. His room holds its switches while it's there (`Moves.fix()`, as the Warden's room
does), whatever F1 says: `bifrons_mode` patterns, `bifrons_guard_break` on (a parry opens his
other side, so the partner's hit gets through), the blade rules on, `mirror_view` on with
`mirror_blades` color, `sync_merge_view` on, `sync_steer` upper.

## The steps

A sentence or two each, the principle, no numbers. A step goes on once what it asks is there; how
many: F2, page "tutorial", tab "steps" (defaults in brackets). Where a step talks of a meter, the
HUD points it out (a frame round it pulsing: `hud.gd`, `pulse()`).

| Step | He does | It says | On when |
|---|---|---|---|
| Move | nothing | Walk and jump: reach both marks in your half (one on the floor, one up in the air). | each reached both |
| Dash | nothing | Dash: a quick burst, the way you hold (or face). | each dashed (2) |
| Parry | SINGLE, at each in turn | Hold block to take a blow; press it just as it lands to parry. Blocking wears down your posture, a parry his too; broken, you reel, and a hit then takes all your sync. (Posture bars pulse.) | each parried (2) and blocked (1) |
| Colors | TRIPLE (its waits differ) | Yellow: this one is for you. Red: now. | each parried (3) |
| Halves | DOUBLE and TRIPLE, in turn | Your half shows the blades aimed at you; your partner's you hardly see. | each parried (3) |
| Dash-parry | SINGLE, at each in turn | Dash at him and parry as his blow lands: you go through him. | each through him (1) |
| Sync hit | SINGLE, at each in turn | A parry sends its energy to your partner, in pink: their hit then is a sync hit, worth more right on the beat. In the half he's about to strike: "Parry him."; in the other: "Wait for the pink, then strike." | each landed sync hits (2), one on the beat (1) |
| Sync is life | DOUBLE; their sync from 30 % | The meter is your shared sync, your life: his hits cost it, sync hits win it back. Empty, it's chaos: no blocking, and the next hit ends it. Fill it up to half. (The sync meter pulses.) | their sync at 50 % |
| Green | BOTH in ppe; apart (pep), CROSSING first (it brings both to one side and ends with both swords on them) | Green: two blades on one place. Parry them together: he reels, and it wins you sync. | he reeled (2) |
| Sync mode | their sync full: he fights as in their sync mode | Stand together to bind: the upper one steers. Both hold attack, let go on the big cue. Below the mark, the sync mode is over. | pair strikes landed (2) |

Then "Done": Enter or pad A goes on to the first boss (Bifrons, the Warden), Esc back to the
select screen.

The words are said once (Nicho, 2026-11-06): a short one in the light half only, a longer one
begun there and gone on in the shadow half; what one player is to do ("Parry him.") in their own
half. Under each half's words, how far its player has got ("parry 1/2   block 0/1"); what's theirs
together, above only. They're over the picture, not in the world (a text in the world would read
upside down in the shadow half): the light half's at its top under the HUD, the shadow half's at
its bottom; merged, all of it above. All the words are in English, as the rest of the game's.

## No defeat, skipping, alone

- **Nobody loses** (`SyncRules.spared`): the players' sync never falls below half (in "Sync is
  life" a fifth, so a hit shows), his below 30 %, no posture below 30 %: no chaos, nothing breaks.
  A hit that gets through starts the step's count over; its words stay (the progress under them
  shows it). Before the sync mode's step their sync stays under 90 % (no sync mode yet); in it,
  it's full, and falling out of the sync mode starts the step over, full again.
- **Skip a step**: hold Tab or Start on a pad a moment (F2 "tutorial_skip_hold", 1 s). Not a dev
  key: those are locked from B5 on.
- **Alone**: the stand-in (F1 → Fights → "Stand-in") plays the partner, and here it gets through
  every step (`BifronsStandIn.perfect`: every strike parried, but blocked where the parry step asks
  for it; every window used, unless his next strike at it would come before its swing is back;
  bound, it draws back by itself). What it can't do (the marks, the dash, the dash-parry) counts as
  done for it. A test runs two, one per player (`plays`): done in about a minute.

## Numbers (F2, page "tutorial")

Steps: `tutorial_dashes` 2, `tutorial_parries` 2, `tutorial_blocks` 1, `tutorial_colors` 3,
`tutorial_halves` 3, `tutorial_through` 1, `tutorial_sync_hits` 2, `tutorial_on_beat` 1,
`tutorial_life_from` 30 %, `tutorial_life_to` 50 %, `tutorial_staggers` 2,
`tutorial_pair_strikes` 2. Pace: `tutorial_read_time` (a step's words alone before his first
attack) 2.5 s, `tutorial_pause` (between two of his attacks) 0.9 s, `tutorial_skip_hold` 1 s. His
own numbers are the try-out boss's (page "bifrons").

## Outside its folder

- `ui/boss_select.gd`: its entry, first.
- `ui/hud.gd`: `pulse()`, a frame round a meter pulsing.
- `core/dev.gd`: `Dev.noted(kind, data)`, every event of the fight's log as a signal (parries,
  blocks, hits, sync hits): what the tutorial counts by.
- `core/sync_bond.gd`: a log event for the pair's strike landing (`pair_strike`).
- `core/sync_rules.gd`: `spared` and `spared_team` (SPARED: nobody loses).
- `core/tuning.gd`: its page.
- `actors/bosses/columna_bifrons/stand_in.gd`: `perfect`, `block_next`, `plays`, `playing()`.

## Open

- Whether the order and the counts teach it well: only a test with new players shows.
- German words for the playtest's friends? Everything else in the game is English.
- After it, on to the Warden: or should the playtest go in another order?
