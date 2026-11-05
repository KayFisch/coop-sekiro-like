# Tasks

Format: `- [ ] Aufgabe (@wer)`. Beim Anfangen Namen dran, beim Fertigwerden abhaken und
in den nächsten Commit. Erledigtes ab und zu nach unten unter „Erledigt“ schieben.
Persönliches (Lernen, Erinnerungen) gehört in die eigene `TASKS.local.md`, nicht hierher.

Am 2026-11-05 aufgeräumt und zusammengefasst: Was gebaut ist, steht in den Docs; hier nur noch,
was offen ist, mit Verweis. Den Verlauf der einzelnen Runden (vor allem Try-out-Boss und Kays
Wall-Rhythmus) hat die Git-Historie dieser Datei.

## Offene Grundsatzfragen

Aus dem Playtest vom 2026-09-29. Bis die geklärt sind, keine großen Features darauf bauen.

- [ ] **Was ist zwischen den Bossen?** (Nicho, 2026-10-02) Raus: lineare Story, Roguelike mit
  Mobs. Im Rennen: Fokus auf Bosse, eine Aufwärmphase als Auto-Runner/Beat-Saber (Beat-Runner,
  Beat-Ring), Platformer (Kays Koop-Jump'n'Run, Horologium) und der Berg mit Fortschrittsverlust.
  Der Beat-Ring wird keine Phase des Akrobaten, der übernimmt nur seine Idee (parierte Projektile
  gehen zum Partner, der sie zurückschlagen kann); was aus dem Ring selbst wird, ist offen.
  Scribble vom 2026-10-02 („Was ist der Rest des Spiels?“).
- [ ] **Woher kommen die Boss-Designs?** (Kay, 2026-10-16) Zweiköpfige Wesen aus Mythen; Kay neigt
  zu A (aus allen Mythologien, ein Boss je Kreatur, evtl. eine Welt je Mythologie). Geplant und
  gebaut: Bifrons der Wächter (Janus), Ettin der Heavy Hitter, Kultist, Akrobat (Mythos offen:
  Gandabherunda oder Amphisbaena), ein letzter Boss (nur Notizen). Reihenfolge grob nach der
  Spiegelregel, Wächter zuerst. Details: `scribbles.md`, 2026-10-16 und 2026-10-25.
- [ ] _(weitere eintragen)_

## Entscheidungen

- **2026-09-30 – Side-Scroller, nicht Top-Down.** Kays Vorschlag; Nicho hatte Top-Down im
  Kopf, sieht aber die Vorteile. Muss noch in `docs/concept.md` rein.
- **2026-10-19 – Sync-Hit „after“, nicht „beat“.** Timing im Detail noch offen.
- **2026-10-19 – Spiegel-Bildschirm ist Grundlage der Bosskämpfe** (Nicho und Kay). Ansicht frei
  wählbar (gespiegelt / einseitig). Die Hälften sind zwei verbundene Seiten: Jede zeigt die
  Klingen, die auf ihren Spieler zielen.
- **2026-10-19 – Sync-Modus = Bossphase der Spieler** (beendet den Kampf standardmäßig, eine
  halbe bis ganze Minute, eigene Patterns des Bosses). `docs/concept.md`.
- **2026-10-19 – Bosse:** heutiger Bifrons = Try-out-Boss; Columna Bifrons neu (Wächter);
  als Nächstes Heavy Hitter; später Akrobat. Leitlinien (Sekiro statt Hollow Knight, Ketten,
  Reaktionen auf Detailebene, Lesbarkeit, pro Klinge ein Parry, Stagger, Knockback):
  `docs/concept.md`.
- **2026-10-19 – Ein gemeinsamer Parry gibt beiden ein Sync-Hit-Fenster** (allgemeine Regel,
  `docs/concept.md`). Ein Sync-Hit kostet den Boss so viel wie jeder Treffer; sein Wert ist der
  Sync-Gewinn.
- **2026-10-19 – Heavy Hitter = der Ettin** (zwei Köpfe, eine Waffe; die Waffe steht in den beiden
  Ebenen parallel oder diagonal; Unisono; offen, solange er angreift; Haltung = Wut-Meter).
  `docs/boss_heavy_hitter.md`.
- **2026-10-25 – Die Spiegelregel** (`docs/concept.md`, „The mirror rule“): Der Boss ist ein Körper
  in einer Welt; die Hälften unterscheiden sich nur darin, wem etwas gilt. Jeder Bruch ist ein
  Ereignis, und die Bosse brechen sie Stufe um Stufe: Wächter 0, Hitter (Phase 2) und Kultist 1,
  Akrobat 2, ein letzter Boss 3.
- **2026-10-25 – Finten zeigen sich beim Ausholen** (eigenes, immer gleiches Zeichen; rot lügt nie;
  fester Platz im Motiv).
- **2026-10-25 – Kein Finale öfter als zweimal hintereinander** (alle Bosse).
- **2026-10-25 – Akrobat (v1) und letzter Boss getrennt.** Akrobat = der Ort
  (`docs/boss_acrobat.md`); letzter Boss = Zeit und Lüge, nur Notizen (`scribbles.md`,
  2026-10-25). Der Beat-Ring wird nicht 1:1 eine Phase des Akrobaten.
- **2026-10-31 – Ein Farbvokabular für alle Bosse** (`docs/concept.md`, „The colors“): Gelb, dann
  Rot (deins, jetzt); Grün = zusammen, in jedem Angriff für beide irgendwo zu sehen (auch im gelben
  Blitz des Kultisten); Orange = ausweichen; Pink = Sync-Energie.
- **2026-10-31 – Sync-Modus: Verbunden steuert erstmal nur einer**, der andere wird mitgetragen.
- **2026-10-31 – Verschmelzen:** Der Bildschirm wandert mit dem einfließenden Spieler nach oben, die
  untere Hälfte bleibt als Streifen; jeder Boss zeigt sich dabei gleich.
- **2026-10-31 – Der Wächter bekommt einen eigenen Raum;** der Try-out-Boss und alle unfertigen und
  Test-Räume sind per F1 ausgeblendet (Standard: aus).
- **2026-10-31 – Dev-Modus (F1 bis F5) erst nach Eingabe von „kek“.**

## Jetzt

### Playtest mit zwei Freunden (@Nicho; Übergabe vom 2026-10-31)

Vier Bosse (Bifrons der Wächter, Ettin, Kultist, Akrobat) und ein Tutorial, auf `nicho/playtest`.
Gebaut: alle Branches nach `main` (2026-10-31), B1 Sync-Modus (verbunden steuert einer, neues
Verschmelzen, seit Runde 1 ein Charakter), B2 Farben, Sync-Hits beim Kultisten, B3 Wächter-Raum und
Auswahl (mit den Titeln), B4 Tutorial (seit Runde 2 mit Sync-Erklärung), B5 Dev-Modus („kek“).
Was genau: die jeweiligen Docs und Kays Notiz vom 2026-10-31 in `CLAUDE.md`.

- [ ] **Anspielen** (Nicho): Sync-Hits beim Kultisten (pinke Welle, Fenster), das Grün im Blitz
  (jetzt mit Säule), Wächter-Raum, Tutorial, Sync-Modus als ein Charakter, die neue Haltungsregel
  für alle Kämpfe (gebrochen = taumeln, erst ein Treffer darin nimmt den ganzen Sync).
- [ ] **Kultist: wann fällt seine Deckung?** (Frage an Kay). Nichos Scribble vom 2026-11-02: Im
  Feuer-Angriff fliegt er ungedeckt, man landet sehr viele Treffer.
- [ ] **Farben, Rest aus B2:** Doppelhieb und Sprung des Try-out-Bosses (also auch beim Wächter) sind
  in pep grün, obwohl jeder seine eigene Klinge pariert.
- [ ] **Tutorial-Texte:** Englisch wie der Rest des Spiels, für die Freunde Deutsch?
- [ ] **Stats tunen** (Nicho und Kay), damit es sich wenigstens richtig spielen lässt. Für Wächter,
  Ettin, Kultist und Akrobat zugleich der erste gemeinsame Test (offene Punkte je Boss unten).
  F1- und F2-Werte liegen pro Rechner (`user://moves.cfg`, `user://tuning.cfg`; Nicho hat z. B. den
  Streifen beim Verschmelzen auf 125): Spielen die Freunde woanders, müssen sie als Standard in den
  Code.
- [ ] **Playtest** mit den beiden.

### Bosse

- [ ] **Bifrons, der Wächter** (@Nicho). Hat seinen eigenen Raum (`levels/warden/`, Auswahl
  „Bifrons, the Warden“), läuft dort aber noch auf dem Code des Try-out-Bosses mit festen Schaltern
  und teilt dessen F2-Zahlen (`docs/boss_bifrons_warden.md` → „His room“); eigener Code kommt mit
  dem fertigen Design.
  - [ ] Gemeinsam testen (Nicho und Kay): die Ketten (mit Deckung nur am Motivende), Torsprung,
    Klingenregeln (pro Klinge ein Parry, Knockback nach Ausgang, Stagger 0,5 + 0,2 s), gemeinsame
    Fenster. Worauf achten: `docs/boss_columna_bifrons.md` → „chains“, „The gate leap“, „The blade
    rules of 2026-10-19“.
  - [ ] Fertig designen: die drei Motive und ihre Haltungen, Verzweigungsregeln, Deckungsöffnung am
    Motivende, Torsprung Schritt 5, Sync-Modus-Pattern (`docs/boss_bifrons_warden.md` → „Open“).
- [ ] **Ettin, der Heavy Hitter.** Phase 1, Wut und Phase 2 gebaut (`docs/boss_heavy_hitter.md` →
  „Built …“). Gemeinsam ausgiebig testen (Nicho und Kay): die Listen „To look for in the next
  test“ und „To look for in the joint test“, „Open“, und wie oft die Wut kommt.
- [ ] **Kultist** (@Kay). Erste spielbare Fassung; Sync-Hits wie bei jedem Boss (2026-11-02). Offen:
  - alle `TODO(design)` (`docs/boss_kultist.md` → „Open, and not built“), wann seine Deckung fällt
    (oben beim Playtest);
  - Einordnung in die Spiegelregel: Er hat Stufe 1 von Anfang an (ein Stab je Hälfte). Kommt er
    nach dem Ettin, oder sind seine Stäbe in einer Phase 1 gespiegelt? Abgrenzung zum Akrobaten
    (beide schicken etwas durch die Achse): Vorschlag in `docs/boss_acrobat.md` → „Open“.
  - Alleine testen: F1 → Fights → „Stand-in“.
- [ ] **Akrobat** (@Nicho). Phase 1 gebaut (`docs/boss_acrobat.md` → „Built (phase 1)“).
  - [ ] Phase 1 testen (Liste „To look for in the first test“).
  - [ ] Danach den Prompt für Schritt 2, Phase 2, schreiben und bauen. Das Design steht („His
    posture and phase 2“); offen ist noch das Tauchen in Phase 2.
- [ ] **Für alle Bosse:**
  - Kein Finale öfter als zweimal hintereinander: beim Ettin und in den Ketten des Try-out-Bosses
    (also auch beim Wächter) noch nachrüsten (klein; `docs/concept.md`, „The boss reacts to what
    happens“).
  - Durchgang durch Bosse klären: Sperren nur die Waffen einen Dash, nicht der Körper? Oder ist
    nur Bifrons undurchdringlich? (`docs/concept.md` → „Bosses“).
  - Sync-Modus-Patterns der Bosse: offen, nicht jetzt (Platzhalter bleiben).
  - Namen: Kultist und Akrobat („the Enlightened“, „the Unresting“) noch offen.

### Try-out-Boss (Werkbank, offen, niemand)

Seit 2026-10-19 Werkbank für Regeln und rohe Ideen, seit B3 (2026-11-03) auch in der Auswahl vom
Wächter getrennt: „Try-out boss“, nur mit F1 → Dev „select_all“. Was er ist und kann: `docs/boss_columna_bifrons.md`.
Solange der Wächter auf seinem Code läuft, betrifft alles hier auch den Wächter.

- [ ] **Name.** Danach Docs umbenennen: `boss_columna_bifrons.md` → `boss_<name>.md`,
  `boss_bifrons_warden.md` → `boss_columna_bifrons.md` (Verweise mitziehen).
- [ ] **Movement tunen.** Das Schema steht (Abstand halten, Schritt oder Dash mit jedem Hieb, Platz
  schaffen, auf den Spieler wechseln, der noch da ist), fühlt sich aber noch nicht rund an. Erst
  beim Spielen notieren, *was* stört (zu nervös, zu träge, steht falsch, kommt zu nah), dann drehen.
  Stellschrauben: `docs/boss_columna_bifrons.md` → „Tuning“.
- [ ] **Stoß umbauen** (Nicho, 2026-10-02): nur noch nah am Rand des Raums, nicht mehr, weil die
  Spieler nah an ihm sind (in ppe müssen sie das). Heute löst genau das ihn aus: `make_room()` in
  `columna_bifrons.gd`, `attacks/shove.gd`.
- [ ] **Seine Haltung kommt fast nie zurück** (Stand 2026-10-17: er steht kaum je 2 s still, der
  Kampf entscheidet sich über seine Haltung). Mit den Ketten und ihrem Atem noch aktuell?
- [ ] **Mash-Problem:** Dauerdrücken auf Angriff ist so schnell wie sauberes Zusammenspiel (Bots:
  35–55 s gegen 45 s), muss mit Menschen getestet werden. Messungen und Stellschrauben:
  `docs/boss_columna_bifrons.md` → „What to look for in the playtest“. Möglicher Ansatz: Deckung nur
  am Motivende (`bifrons_guard_break` motif_end, im Wächter-Raum schon fest an).
- [ ] **Beobachtungen aus Nichos Test vom 2026-10-19** (nicht sicher, erst nachprüfen):
  - Der Stand-in bleibt manchmal an der Wand stecken. Nicht nachgestellt; bitte merken, wann es
    passiert (ppe? Partner an der Wand? nach Shove/Leap?). Verdacht: `DISTANCE_BEHIND` in
    `stand_in.gd` legt sein Ziel in die Wand, wenn der Partner an ihr steht.
  - Im Chaos-Modus scheint Parieren manchmal nicht zu klappen. Parieren selbst geht
    (`test_blade_rules.test_parry_in_chaos`); mögliche Gründe: Haltung bricht im Chaos leicht
    (0,8 s Stagger), Block-Mashen sperrt den Parry (`PARRY_SPAM_LOCK`), ein Parry gegen beide
    Schwerter auf einer Seite ist nur ein Block.

### Sync-Modus, Spiegel-Bildschirm, Spieler

- [ ] **Sync-Modus** (@Nicho). Gebaut: Sync als Leben (keine Gesundheit), die Haltungsregeln vom
  2026-10-17, verbinden, ausholen und gemeinsam auf den großen Cue loslassen, verbunden steuert
  einer (F1 „sync_steer“), das neue Verschmelzen, ein Charakter. Regeln: `docs/concept.md` → „Sync
  as life“, „The sync mode“, „The two screen halves“. Offen: Rollenwechsel (wann wechselt, wer
  steuert?); spätere Kandidaten fürs Bewegen (einer bewegt, der andere startet den Cue; Verben
  aufgeteilt); die Sync-Modus-Patterns der Bosse (oben).
- [ ] **Spiegel-Bildschirm** (@Nicho): seit 2026-10-19 Grundlage der Bosskämpfe, standardmäßig an.
  Offen: Gefühl testen bei den Klingen je Hälfte (F1 „mirror_blades“, Standard „color“; „fade“ mit
  F2 „bifrons_fade_alpha“); die einseitige Ansicht der neueren Bosse.
- [ ] **Controller-Belegung für den Dash-Parry ausprobieren:** Standard, Sekiro, „dash left“,
  „Sekiro swapped“ (Hauptmenü, P).

### Zwischen den Bossen (Prototypen)

- [ ] **Beat-Runner und Beat-Ring** (@Nicho). Der Runner wirkt eher „meh“; der Ring ist seit Runde 4
  der Kampf des Try-out-Bosses ohne ihn (seine Patterns, Gewichte und sein Tempo, der violette
  Splitter so spät wie der Sync-Hit). Wie es weitergeht, hängt an der Grundsatzfrage oben.
  `docs/beat_runner.md`, `docs/beat_ring.md`.
- [ ] **Koop-Jump'n'Run und Horologium** (@Kay; seit 2026-10-19 auf `main`). Gebaut: das
  Rhythmus-Relay (`relay_rhythm`, Relay Gym), der Wall-Rhythmus (`wall_rhythm`, Wall Gym: Timing am
  Wandkontakt ±40 ms, fliegt auf die Halbschläge von `Beat`, Chimney Clash mit dem Partner als
  zweiter Wand), der Level-Baukasten und Horologium (Räume wie bei Celeste, die Kay im Editor baut;
  `docs/level_kit.md`), dazu Kanone und Aufzug. Offen:
  - Gefühl testen: ±40 ms an Wand und Partner fair? Wall-Rhythmus auf `Beat`, Kanone, Aufzug.
  - Vergleichen: F1 → Walls „turn grace“ gegen „wall reach“; dazu das Kletter-Log (F1 → Walls,
    `user://wall_log.jsonl`) zum Auswerten.
  - Nächste Ideen (nicht gebaut): Pendel-Schaukel (pumpen und abspringen), Ruder-Aufzug,
    Weltschalter.
  - Kays Teile des Spielers (Wände, Relay, Chimney Clash): vor Änderungen absprechen.

### Docs

- [ ] **Concept aufräumen** (`docs/concept.md`). Noch offen (geprüft am 2026-11-05):
  - „Moveset“ hat genaue Werte (136 px, 0.133 s …) und eine Kopie der F1-Schalter-Tabelle, die bei
    jedem Tuning veralten. Vorschlag: Kit als *Absicht* beschreiben, Zahlen bleiben in
    Code/Gym-Doc.
  - Veraltet: „What is this?“ und „Current prototype scope“ (ein Testboss; Wächter, Kultist,
    Akrobat und Tutorial fehlen), „Bosses“ (Try-out-Boss als „today's Columna Bifrons“, Akrobat
    noch auf `nicho/acrobat`).
  - Platforming: die ersten zwei Ideen sind als Launch und Relay schon gebaut.
  - Side-Scroller-Entscheidung eintragen, offene Fragen verlinken.

## Später

- [ ] **`.gd` aufräumen, Teil 1** (klein, kann jederzeit): Arena-Grenzen (`ARENA_LEFT` …) aus
  `base_boss.gd` ins Level holen.

## Erledigt

- [x] **Playtest-Vorbereitung B1 bis B5** und Nichos Testrunden 1 und 2 (2026-10-31 bis 2026-11-06,
  `nicho/playtest`; Details siehe oben).
- [x] **Akrobat designen** (Nicho, 2026-10-25, v1) und **bauen, Schritt 1: Grundgerüst und Phase 1**
  (Nicho, 2026-10-26).
- [x] **Heavy Hitter designen** (Nicho, 2026-10-19, v0), **bauen, Schritt 1: Phase 1** (Nicho,
  2026-10-20, nach Nichos erstem Test umgebaut) und **Schritt 2: Wut und Phase 2** (Kay, 2026-10-21).
- [x] **Code-Aufträge aus dem Design vom 2026-10-19:** Klingen je Bildhälfte, Klingenregeln,
  Torsprung, Ketten (alle gebaut, Gefühl testen: beim Wächter und Spiegel-Bildschirm oben),
  Dash-Parry-Belegungen. Nicht umgesetzt: Sweep und Crossing-Stich schneller (der Sweep gehört zum
  Hitter, das Crossing ist eher ein Bild-Problem).
- [x] **Gemeinsamer Parry gibt beiden ein Sync-Hit-Fenster**, im Try-out-Boss (Nicho, 2026-10-20).
- [x] **`mirror_view` standardmäßig an** (Nicho, 2026-10-19) und vierte Controller-Belegung
  „Sekiro swapped“.
- [x] **Try-out-Boss als Prototyp** (pep-Test, ab 2026-10-01 in fünf Runden; getestet 2026-10-14:
  „für einen Prototyp sehr gut“), Treffer-Fenster „after“ entschieden, auf `main`, seit 2026-10-19
  Werkbank.
- [x] Sync-Werte (`SYNC_GAINS`) aus `GameManager` raus.
- [x] **Kays Branch, Code-Überarbeitung und `player.gd`-Baukasten auf `main`** (2026-10-19):
  `kay/coop-platformer` → `nicho/kay-to-main` → `nicho/code-overhaul` → `kay/player-kit`, von
  Nicho lokal getestet und zusammen nach `main` gemergt.
- [x] `CLAUDE.md`, `TASKS.md`, `scribbles.md` angelegt
- [x] Godot-Projekt ins Repo-Root, Design-Docs nach `docs/`, `.gitignore` zusammengefasst
- [x] Branch- und Commit-Konventionen in `CLAUDE.md`
- [x] Session-Start-Hook: automatisch pullen und Neues zeigen
- [x] Side-Scroller vs. Top-Down entschieden
- [x] Zwei Controller: ein Pad pro Spieler (`core/pads.gd`, Branch `nicho/pep-test`), mit zwei
  Pads getestet (2026-10-14)
- [x] **`.gd` aufräumen, Teil 2:** `player.gd` in Schichten aufgeteilt wie Bifrons: Körper,
  Schwert, Wände, Partner, der Spieler selbst (`actors/player/player_*.gd`, `player.gd`); die
  boss-spezifischen Hooks sind mit Cubus und Sphaera raus (2026-10-18, `kay/player-kit`)
