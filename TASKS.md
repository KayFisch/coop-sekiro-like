# Tasks

Format: `- [ ] Aufgabe (@wer)`. Beim Anfangen Namen dran, beim Fertigwerden abhaken und
in den nächsten Commit. Erledigtes ab und zu nach unten unter „Erledigt“ schieben.
Persönliches (Lernen, Erinnerungen) gehört in die eigene `TASKS.local.md`, nicht hierher.

## Offene Grundsatzfragen

Aus dem Playtest vom 2026-09-29. Bis die geklärt sind, keine großen Features darauf bauen.

- [ ] _(weitere eintragen)_

## Entscheidungen

- **2026-09-30 – Side-Scroller, nicht Top-Down.** Kays Vorschlag; Nicho hatte Top-Down im
  Kopf, sieht aber die Vorteile. Muss noch in `docs/concept.md` rein.

## Jetzt

- [ ] **pep-Test-Boss „Columna Bifrons“** (@Nicho), Branch `nicho/pep-test`. Testet die
  Grundregel aus den Scribbles: Spieler links und rechts vom Boss, zwei Schwerter, er ist auf
  beiden Seiten gedeckt; ein Parry auf einer Seite bricht kurz die Deckung auf der anderen
  (Partner trifft im selben Takt), beide Seiten gleichzeitig pariert = Stagger.
  Dazu ein **reaktiver Modus** (F1): Der Boss pariert Angriffe der Spieler und schlägt sofort
  mit seinem nächsten Pattern auf den zurück, der ihn angegriffen hat, nach dem Vorbild
  Genichiro (siehe Scribble vom 2026-10-01).
  Und ein **Sweep**: ein Schwert von einer Seite durch zur anderen; wer pariert, entscheidet,
  wo seine Schwerter danach sind.
  Seit der zweiten Runde (2026-10-01) gilt **ein Regelsatz für jede Klinge**, Spieler wie Boss
  („eine Klinge deckt oder schwingt, nie beides“, ein parierter Schlag prallt zurück); die
  Sonderregeln (Mash-Sperre, nur ein Treffer pro Windup) sind raus.
  **Braucht einen Playtest zu zweit**, danach entscheiden: mergen, umbauen oder verwerfen.
  Was dabei zu klären ist, steht in `docs/boss_columna_bifrons.md` (auf dem Branch) unter
  „What to look for“: Treffer-Fenster „beat“ oder „after“, wie viel Windup-Treffer wert sind,
  ob sich der längere Schwung richtig anfühlt.
  Fasst außerhalb des eigenen Ordners an: `core/moves.gd` (Schalter), `core/game_manager.gd`
  (Sync-Werte), `core/sfx.gd` (Sounds, Gesamtlautstärke), `ui/boss_select.gd` (Eintrag),
  `project.godot` (Autoload), `actors/bosses/base_boss.gd` (ein Hook für die Pause zwischen
  Attacken) und **`actors/player/player.gd`**, und das ist **nicht mehr klein**: Der Schlag ist
  ein echter Schwung (Ausholen, Schnitt, Zurückführen: einer alle 0,35 s statt alle 0,3 s, er
  trifft 0,08 s nach dem Druck), währenddessen kein Block und kein Parry, pariert prallt er
  zurück, ein etwas zu früher Angriffsdruck zählt noch, und das Schwert ist größer (76 statt
  48 px, mehr Reichweite) und wird anders gehalten. Gilt in jedem Kampf, also vor dem Merge
  gemeinsam entscheiden; Cubus und Sphaera sind nicht darauf abgestimmt.
- [ ] **Zwei Controller** (@Nicho), selber Branch: bisher hört P2 auf jedes Gamepad, mit zwei
  Pads steuern beide P2. Neu: ein Pad pro Spieler (`core/pads.gd`). Braucht Test mit zwei Pads.
- [ ] **Concept aufräumen** (`docs/concept.md`). Befund vom Review 2026-09-30:
  - Vision und technische Spezifikation sind vermischt: „Moveset“ hat genaue Werte
    (136 px, 0.133 s …) und eine Kopie der F1-Schalter-Tabelle aus `core/moves.gd`, die veralten
    bei jedem Tuning. Vorschlag: Kit als *Absicht* beschreiben, Zahlen bleiben in Code/Gym-Doc.
  - Veraltet: „What is this?“ und „Current prototype scope“ sprechen von einem Boss/einer Arena.
  - Cubus-Attackenliste steht mitten in der allgemeinen Kernmechanik, Triple Stab fehlt.
    „His body“ ist auch Cubus-spezifisch → eigenes Boss-Doc (Analyse-Teil aus
    `boss_sphaera_pendula.md` als Grundlage).
  - Parry-Relay klingt, als ginge *jeder* Parry an den Partner; im Code nur bei manchen Attacken.
  - Platforming: die ersten zwei Ideen sind als Launch und Momentum Relay schon umgesetzt.
  - Side-Scroller-Entscheidung eintragen, offene Fragen verlinken.
  - Vorgeschlagene Gliederung: Vision → Offene Fragen → Kernmechaniken (Relay,
    Antwort-Vokabular + Farben, Sync) → Player-Kit → Bosse (je 1 Zeile + Link) →
    Platforming (geparkt) → Stand & Technik

## Später

- [ ] **`.gd` aufräumen, Teil 1** (klein, kann jederzeit):
  - Sync-Werte (`SYNC_GAINS`) aus `GameManager` in die jeweiligen Bosse verschieben
  - Arena-Grenzen aus `base_boss.gd` ins Level holen
  - boss-spezifische Hooks (gather, tether, grab) aus `player.gd` rauslösen
- [ ] **`.gd` aufräumen, Teil 2:** `player.gd` (~2000 Zeilen) in Komponenten aufteilen
  (Bewegung, Schwert, Partner-Moves, Zustand/Health). Side-Scroller steht, also möglich;
  sinnvoll, sobald klar ist, welche Moves bleiben. Eigener Branch, `player.gd` vorher claimen.

## Erledigt

- [x] `CLAUDE.md`, `TASKS.md`, `scribbles.md` angelegt
- [x] Godot-Projekt ins Repo-Root, Design-Docs nach `docs/`, `.gitignore` zusammengefasst
- [x] Branch- und Commit-Konventionen in `CLAUDE.md`
- [x] Session-Start-Hook: automatisch pullen und Neues zeigen
- [x] Side-Scroller vs. Top-Down entschieden
