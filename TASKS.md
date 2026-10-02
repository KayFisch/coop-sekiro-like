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
  Vierte Runde (2026-10-02, nach Nichos Solo-Test der dritten): Er **hält Abstand**, statt zur
  Raummitte zu laufen (steht mittig zwischen den Spielern; weicht zurück, wenn einer an ihm
  klebt; kommt näher, wenn er nicht mehr trifft), macht **mit jedem Hieb einen Schritt oder
  Dash** auf den Spieler zu, **lässt Hiebe aus**, deren Spieler weit weg ist, und richtet nach
  1,5 s **beide Schwerter auf den, der noch da ist** (plus **Rush** zum Entfernten).
  Eingeklemmt oder mit dem Rücken zur Wand springt er eher; sonst kommt der Sprung seltener.
  Dafür wechseln die Spieler selbst die Seite: **Dash-Parry durch den Boss**. „Beide“ ist
  jetzt **grün** statt blau (zu nah an P1): Das kollidiert mit dem Farbvokabular von Cubus und
  Sphaera (Grün = „in die Luft“, Blau = „zusammen parieren“), also **Farben noch gemeinsam
  klären**. Der **Stand-in** zum Alleine-Testen spielt jetzt wirklich einen Spieler (läuft,
  pariert 75 %, blockt 15 %, wird sonst getroffen, läuft unter 20 HP weg und trinkt). Nichos
  Feedback dazu: zweiter Scribble vom 2026-10-02 („nach dem Solo-Test“).
  Fünfte Runde (2026-10-02, nach Nichos ausführlichem Test): Der Landepunkt des Sprungs steht
  beim Absprung fest. Jede Klinge hat eine **Kante in der Farbe ihres Spielers**. In ppe schlägt
  das vordere Schwert im selben Bogen wie das hintere, nur tiefer. Neu ist der **Stoß**: Er
  stößt beide Schwerter auf die Spieler und wirft sie zurück (kein Schaden, nichts zu
  parieren), wenn Zurückhüpfen ihn von der Raummitte wegtreiben würde. Das „after“-Fenster
  öffnet 0,18 s nach dem Parry statt 0,25 s. Alle Attacken stehen in **einer Tabelle**
  (`ColumnaBifrons.ATTACKS`, ein Gewicht je Situation). Nicho hat Gewichte und Patterns selbst
  angepasst (DOUBLE und BOTH an). „beat“ ist für ihn weiter gut; „after“ könnte mehr Tiefe
  bringen, jetzt mit dem kürzeren Warten noch mal vergleichen.
  **Braucht einen Playtest zu zweit**, danach entscheiden: mergen, umbauen oder verwerfen.
  Was dabei zu klären ist, steht in `docs/boss_columna_bifrons.md` (auf dem Branch) unter
  „What to look for“: Treffer-Fenster „beat“ oder „after“, wie viel Windup-Treffer wert sind,
  ob sich der längere Schwung richtig anfühlt.
  Fasst außerhalb des eigenen Ordners an: `core/moves.gd` (Schalter), `core/game_manager.gd`
  (Sync-Werte), `core/sfx.gd` (Sounds, Gesamtlautstärke), `ui/boss_select.gd` (Eintrag),
  `project.godot` (Autoload), `actors/bosses/base_boss.gd` (zwei Hooks: Pause zwischen
  Attacken, Blickrichtung der Spieler halten) und **`actors/player/player.gd`**, und das ist
  **nicht mehr klein**: Spieler gucken bei diesem Boss immer zu ihm (der Dash geht dann in die
  gehaltene Richtung; in den anderen Kämpfen ändert sich nichts). Ein Parry, der mitten im
  Dash landet, trägt den Spieler durch den Boss (**Dash-Parry**, Schalter `parry_pass`): eine
  Spieler-Regel, gilt also auch bei Cubus. Der Schlag ist
  ein echter Schwung (Ausholen, Schnitt, Zurückführen: einer alle 0,41 s statt alle 0,3 s, er
  trifft 0,08 s nach dem Druck), währenddessen kein Block und kein Parry, pariert prallt er
  zurück, ein etwas zu früher Angriffsdruck zählt noch, und das Schwert ist größer (76 statt
  48 px, mehr Reichweite) und wird anders gehalten. Gilt in jedem Kampf, also vor dem Merge
  gemeinsam entscheiden; Cubus und Sphaera sind nicht darauf abgestimmt.
  Treffer-Fenster: Nicho tendiert nach dem Solo-Test zu **„beat“** (mit „after“ wartet man nach
  dem Parry erst, und bis man selbst wieder dran ist, dauert es zu lang; „beat“ hält das
  Ganze schneller). Noch mit Kay zu besprechen.
- [ ] **Movement von Bifrons weiter tunen** (offen, niemand). Nach dem Test vom 2026-10-02:
  Das Schema steht (Abstand halten, Schritt oder Dash mit jedem Hieb, Platz schaffen, auf den
  Spieler wechseln, der noch da ist), fühlt sich aber insgesamt noch nicht rund an. Erst beim
  Spielen notieren, *was* stört (zu nervös, zu träge, steht falsch, kommt zu nah), dann drehen.
  Die Stellschrauben stehen oben in `columna_bifrons.gd` unter „Moving“, mit den aktuellen
  Werten in `docs/boss_columna_bifrons.md` → „Tuning“ (beides auf dem Branch):
  - *Abstand:* ab wann er zurückweicht und wie weit (`CROWD_DISTANCE` 62, `FIT_DISTANCE` 90),
    ab wann er nachrückt (`BLADE_REACH` 215, `REACH_MARGIN` 30), wie weit er neben der Mitte
    zwischen den Spielern stehen darf (`PLACE_SLACK` 28).
  - *Tempo:* Gehen (`WALK_SPEED` 110), während Attacken (`ATTACK_PACE` 0,5), gebremst durch
    Treffer (`SLOWED_FACTOR` 0,3 für `SLOWED_TIME` 0,6 s).
  - *Hiebdash:* kurzer Schritt, langer Dash, Zielabstand (`LUNGE_SHORT` 14, `LUNGE_LONG` 160,
    `STRIKE_DISTANCE` 105, `CLOSEST` 72); Zulaufen bei langem Ausholen (`LONG_WINDUP` 6,
    `ADVANCE_SPEED` 70).
  - *Platz schaffen:* Hüpfer zurück oder Stoß (`CROWD_PATIENCE` 0,7 s, `ROOM_COOLDOWN` 4 s,
    `BACK_OFF_DISTANCE` 110, `Shove.PUSH`, `Shove.NEAR`); wann er als „in die Ecke gedrängt“
    gilt (äußeres Fünftel des Raums).
  - *Allein gelassen:* ab wann ein Schwert wechselt und zurückwechselt (`TURN_TIME` 1,5 s,
    `RETURN_DISTANCE` 300), wie oft er zum Entfernten rusht (Gewicht von `RUSH`).
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
