# Tasks

Format: `- [ ] Aufgabe (@wer)`. Beim Anfangen Namen dran, beim Fertigwerden abhaken und
in den nächsten Commit. Erledigtes ab und zu nach unten unter „Erledigt“ schieben.

## Offene Grundsatzfragen

Aus dem Playtest vom 2026-09-29. Bis die geklärt sind, keine großen Features darauf bauen.

- [ ] **Side-Scroller vs. Top-Down**: davon hängt fast der ganze Player-Code ab
- [ ] _(weitere eintragen)_

## Jetzt

- [ ] Side-Scroller vs. Top-Down klären (Argumente in `scribbles.md` sammeln)

## Später

- [ ] `.gd`-Aufräumen, Teil 1 (unabhängig von der Grundsatzfrage):
  - Sync-Werte (`SYNC_GAINS`) aus `GameManager` in die jeweiligen Bosse verschieben
  - Arena-Grenzen aus `base_boss.gd` ins Level holen
  - boss-spezifische Hooks (gather, tether, grab) aus `player.gd` rauslösen
- [ ] `.gd`-Aufräumen, Teil 2: `player.gd` in Komponenten aufteilen (Bewegung, Schwert,
  Partner-Moves, Zustand/Health). **Erst nach der Side-Scroll/Top-Down-Entscheidung**, sonst
  wird aufgeteilter Code danach weggeworfen.
- [ ] P2-Eingabe: hört auf jedes Gamepad (`device: -1`), mit zwei Pads steuern beide P2
- [ ] `docs/concept.md`: Abschnitt „Current prototype scope“ aktualisieren (zwei Bosse, Gyms)

## Erledigt

- [x] `CLAUDE.md`, `TASKS.md`, `scribbles.md` angelegt
- [x] Godot-Projekt ins Repo-Root, Design-Docs nach `docs/`, `.gitignore` zusammengefasst
- [x] Branch- und Commit-Konventionen in `CLAUDE.md`
