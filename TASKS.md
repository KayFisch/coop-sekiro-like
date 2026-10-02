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
  Seit der dritten Runde (2026-10-02) **folgt jedes seiner Schwerter einem Spieler**, egal auf
  welcher Seite: damit geht auch **ppe** (beide Spieler auf einer Seite) mit denselben Regeln.
  Neu dazu: **Crossing** (er charged an einem Spieler vorbei, dann Doppelschlag), **Sprung**
  (er landet zwischen den Spielern, zurück zu pep), **Movement** (er läuft Spielern nach, will
  zur Raummitte, weicht in ppe nach einem Doppelschlag zurück) und **Spieler gucken immer zu
  ihm**. Ideen dazu und was noch offen ist (Sync-Modus, Hieb-nach-oben-Variante): Scribble vom
  2026-10-02.
  **Braucht einen Playtest zu zweit**, danach entscheiden: mergen, umbauen oder verwerfen.
  Was dabei zu klären ist, steht in `docs/boss_columna_bifrons.md` (auf dem Branch) unter
  „What to look for“: Treffer-Fenster „beat“ oder „after“, wie viel Windup-Treffer wert sind,
  ob sich der längere Schwung richtig anfühlt.
  Fasst außerhalb des eigenen Ordners an: `core/moves.gd` (Schalter), `core/game_manager.gd`
  (Sync-Werte), `core/sfx.gd` (Sounds, Gesamtlautstärke), `ui/boss_select.gd` (Eintrag),
  `project.godot` (Autoload), `actors/bosses/base_boss.gd` (zwei Hooks: Pause zwischen
  Attacken, Blickrichtung der Spieler halten) und **`actors/player/player.gd`**, und das ist
  **nicht mehr klein**: Spieler gucken bei diesem Boss immer zu ihm (der Dash geht dann in die
  gehaltene Richtung; in den anderen Kämpfen ändert sich nichts). Der Schlag ist
  ein echter Schwung (Ausholen, Schnitt, Zurückführen: einer alle 0,41 s statt alle 0,3 s, er
  trifft 0,08 s nach dem Druck), währenddessen kein Block und kein Parry, pariert prallt er
  zurück, ein etwas zu früher Angriffsdruck zählt noch, und das Schwert ist größer (76 statt
  48 px, mehr Reichweite) und wird anders gehalten. Gilt in jedem Kampf, also vor dem Merge
  gemeinsam entscheiden; Cubus und Sphaera sind nicht darauf abgestimmt.
  Treffer-Fenster: Nicho tendiert nach dem Solo-Test zu **„beat“** (mit „after“ wartet man nach
  dem Parry erst, und bis man selbst wieder dran ist, dauert es zu lang; „beat“ hält das
  Ganze schneller). Noch mit Kay zu besprechen.
- [ ] **Mash-Problem bei Bifrons anschauen** (offen, niemand). Seit die Sonderregeln raus sind
  (keine Mash-Sperre, kein Treffer-Limit im Windup), lohnt sich Dauerdrücken auf Angriff:
  - **Was passiert:** Ein Spieler pariert nur die Schläge auf seiner eigenen Seite und drückt
    sonst durchgehend Angriff. Zwei Quellen bringen Schaden, ohne dass er mit dem Partner
    zusammenspielt:
    1. *Windup-Treffer:* Solange das Schwert des Bosses auf seiner Seite oben ist, landet
       jeder Schlag (10 Schaden). In einen ersten Windup (1–1,8 s) passen 2–3 Schläge, also
       20–30 Schaden, gegenüber 25 für einen Sync-Hit. Das ist gewollt („man kann immer
       treffen, wenn er nicht parieren kann“), aber pro Schlag des Bosses etwa so viel wert
       wie die eigentliche Koop-Mechanik.
    2. *Sync-Hits per Glück:* Auf der Partnerseite prallt jeder Schlag an der Deckung ab und
       kostet 0,53 s (0,08 s bis zum Treffer, 0,45 s Rückprall). Das Fenster nach dem Parry
       des Partners ist 0,25 s („beat“) bzw. 0,3 s („after“) offen, also trifft ein
       Dauerdrücker es rechnerisch in etwa der Hälfte der Fälle; gemessen 2–5 von 10, je nach
       Lauf stark schwankend.
  - **Gemessen (Bots mit echten Tasteneingaben):** nur eigene Schläge parieren und sonst
    mashen: Boss tot in 35–55 s. Sauber zusammenspielen (einer pariert, der andere trifft im
    Fenster, keine Windup-Treffer): 45 s. Mashen ist also gleich schnell, ohne dass man auf den
    Partner achten muss.
  - **Was dagegen spricht, dass es ein echtes Problem ist:** Der Bot stoppt perfekt rechtzeitig
    vor jedem eigenen Parry; ein Mensch, der masht, verpasst Parrys (während des Schwungs
    geht kein Block). Im reaktiven Modus ruft jeder abgeprallte Schlag sofort seinen nächsten
    Angriff auf den Masher. Muss mit Menschen getestet werden.
  - **Stellschrauben, ohne neue Sonderregel:** `SYNC_HIT_FACTOR` hoch (Sync-Hit klar mehr
    wert als Windup-Treffer; jetzt x2,5), `PARRIED_RECOIL` länger (weniger Glückstreffer, aber
    träger), Fenster kürzer (`BREAK_TIME`), Schläge des Bosses schneller (weniger Platz im
    Windup), Windup-Treffer weniger Schaden.
  - **Mit Sonderregel** (wollten wir eigentlich nicht): Deckung bricht nicht, wenn sie gerade
    selbst pariert hat (die alte Mash-Sperre).
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
