# Tasks

Format: `- [ ] Aufgabe (@wer)`. Beim Anfangen Namen dran, beim Fertigwerden abhaken und
in den nächsten Commit. Erledigtes ab und zu nach unten unter „Erledigt“ schieben.
Persönliches (Lernen, Erinnerungen) gehört in die eigene `TASKS.local.md`, nicht hierher.

## Offene Grundsatzfragen

Aus dem Playtest vom 2026-09-29. Bis die geklärt sind, keine großen Features darauf bauen.

- [ ] **Was ist zwischen den Bossen?** (Nicho, 2026-10-02) Jump-and-Run-Räume wie in Celeste,
  eine lineare Story, oder generiert / roguelike? Also: Platformer oder Mob-Fights zwischen
  den Bosskämpfen.
  Stand nach dem Durchsprechen (Scribble vom 2026-10-02, „Was ist der Rest des Spiels?“):
  lineare Story und Roguelike mit Mobs fallen wohl raus; im Rennen sind Fokus auf Bosse, eine
  Aufwärmphase als Auto-Runner/Beat-Saber, Platformer und der Berg mit Fortschrittsverlust.
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
  **Getestet (2026-10-14): für einen Prototyp sehr gut.**
  Treffer-Fenster: Nicho tendiert nach dem Solo-Test zu **„beat“** (mit „after“ wartet man nach
  dem Parry erst, und bis man selbst wieder dran ist, dauert es zu lang; „beat“ hält das
  Ganze schneller). Noch mit Kay zu besprechen.
- [ ] **Sync-Modus** (offen, niemand; Hauptaufgabe neben den Zwischen-Prototypen). Der
  fehlende Teil des Proof of Concept: in ppe, beide nebeneinander, werden zwei Spieler mit zwei
  Schwertern zu einem mit einem großen Schwert, und der Boss muss sich verteidigen. Ideen:
  Scribble vom 2026-10-02 („Sync-Modus: Verbindung und Movement“). Dazu gehört die
  **schmalere Spieler-Hitbox** (Spieler als zwei Hälften, die zusammen ein Quadrat bilden):
  auf `nicho/pep-test` gemacht (2026-10-14), 20×40 statt 40×40 (`Player.BODY_SIZE`).
- [ ] **Prototyp Beat-Runner** (@Nicho): die andere Antwort auf „Was ist zwischen den
  Bossen?“, etwas zwischen Beat Saber und Geometry Dash (Auto-Runner, Dinge fliegen im Rhythmus
  auf die Spieler zu, parieren und schlagen; vielleicht zwei Lanes für pep/ppe). Siehe Scribble
  vom 2026-10-02 („Was ist der Rest des Spiels?“). Läuft parallel zu Kays Jump'n'Run.
- [ ] **Spiegel-Bildschirm** (@Nicho), Branch `nicho/pep-test`, Schalter `mirror_view` (F1,
  Standard aus). Nichos Idee aus dem Scribble vom 2026-10-14: Bildschirm an der Bodenlinie
  geteilt, oben P1 als Licht, unten die Spiegelung mit P2 als Schatten (nach Gris), der Boss
  ganz gespiegelt. Nur das Bild ändert sich, Regeln und Welt bleiben; die Spieler gehen dort
  durcheinander durch. Zu klären beim Spielen: Ist kopfüber spielbar? Fehlt der Partner neben
  einem mehr, als der Platz bringt? Was wird aus Sync und Partner-Clashes, wenn man sich nur an
  der Linie trifft?
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
- [ ] **Stoß von Bifrons umbauen** (offen, niemand; Nicho, 2026-10-02, nach dem Test):
  - Kein Stich mehr: Er schubst die Spieler mit der flachen Seite weg, die Schwerter stehen
    dabei senkrecht.
  - Nur, wenn er nah am Rand des Raums steht.
  - Nicht mehr, weil die Spieler nah an ihm sind: In ppe müssen sie nah stehen (sonst erreicht
    ihn der hintere nicht). Heute löst genau das den Stoß aus (0,7 s näher als 62 px, oder nach
    einem Doppelhieb ohne Stagger, wenn Zurückhüpfen ihn von der Raummitte wegführt):
    `make_room()` in `columna_bifrons.gd`, `attacks/shove.gd`.
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
- [ ] **Prototyp Koop-Jump'n'Run** (@Kay), Branch `kay/coop-platformer`. Testet eine Antwort
  auf „Was ist zwischen den Bossen?“: ein kurzer Abschnitt, den man nur zu zweit schafft.
  Baut auf den Gyms (`levels/gym/`) und dem Platforming-Kit in `Moves` auf. Der Branch hat
  `nicho/pep-test` schon reingemergt (neuer Schwung usw.), kann also erst mit oder nach ihm
  nach `main`.
  Erstes Element: **Rhythmus-Relay** (Schalter `relay_rhythm`, Abschnitt „RHYTHM RELAY“ in
  `player.gd`): ein Takt aus vier Schlägen, 1 Ausholen (Dasher), 2 Parry (Anker), 3 Schlag des
  Ankers, dessen Stick die Richtung gibt (4 Wege), 4 Scheitelpunkt, wo das Level eine Aktion
  verlangt. Testraum mit Bot als P2: „Relay Gym“ (Glocken, Pogo auf 4, Dash auf 4; Hebel
  holen den Bot). Zweites Element: **Wall-Rhythmus** (Schalter `wall_rhythm`, nur Sound):
  breiter Schacht 1-1-1-1, enger doppelt so schnell, Koop-Kamin mit Chimney Clash im
  Zwei-Schlag-Takt; Testraum „Wall Gym“ mit Spiegel-Bot. **Fasst `player.gd` an**
  (Relay, Dash-Slash, Wall Jump, Chimney Clash), Nicho bitte dort nicht parallel ändern.
  Umgesetzt nach Kays Test vom 2026-10-04 (headless getestet, **Gefühl noch testen**):
  - Wall-Takt eigener Beat `WALL_BEAT` 500 ms (breit 500, eng 250, Koop-Kamin 1000 pro
    Sprung-Paar); Wall Jump höher (145 px) und nicht mehr per Loslassen kürzbar, Flug 0.55 s.
  - Koop-Kamin: lag an der Geometrie (die beiden kamen sich nur knapp auf 60 px nahe) und am
    Rückwurf, der nach 0.15 s abgebremst wurde. Jetzt treffen sie sich sicher, der Rückwurf
    bleibt bis zur Wand ungesteuert. Readout heißt jetzt „chimney clashes (met mid-air)“.
  - Relay: Dasher hängt oben still (60 ms vor bis 20 ms nach Schlag 4), Wurfhöhe jetzt
    exakt. Dash-Fenster am Turm ca. −60 … +75 ms. Das Readout zeigte den Dash ~35 ms zu spät an.
  - Pogo auf 4: die Laterne nimmt nur Presses ±50 ms um Schlag 4.
  - Kamera: F1 → Controls → „Gym camera follows only P1“.
  Zweite Runde (Kays Test 2026-10-08: Relay passt; Wall Jumps: Abstände passen nicht zum
  Timing, kein Anhaltspunkt wann drücken, Koop-Kamin = zusammen runterfallen):
  - `wall_rhythm` ist jetzt Mechanik: erster Wall Jump startet ein Metronom (Tick + Ring, der
    sich zum Schlag schließt). Wall Jump auf dem Schlag (±50 ms) voll, daneben ohne Auftrieb.
    Spammen klettert nicht mehr. Schächte bringen einen 100 ms vor dem Tick an die Wand.
  - Koop-Kamin: der Bot hat nur die Sprungtaste kopiert, ohne Stick in die Wand klebte P2
    nicht und sprang gar nicht. Jetzt kopiert er den Wall Jump selbst. Ein schwacher Sprung
    gibt auch einen schwachen Rückwurf. Beide teilen ein Metronom.
  - Loslassen des Sticks bremst den Wall-Jump-Flug nicht mehr (betrifft alle Gyms).
  - ~~Offen: enger Schacht, auf den Tick warten~~ (dritte Runde: kein Warten mehr)
  Dritte Runde (Kays Wünsche 2026-10-09):
  - Timing hängt jetzt am **Wandkontakt**, nicht am Metronom: Wall Jump ±50 ms (jetzt ±40) um den
    Moment, in dem man die Wand trifft (früher Druck wartet per Jump-Buffer auf die Wand).
    Der enge Schacht ist damit doppelt so schnell (halber Schlag Flug), kein Warten mehr.
    ~~Erster Wall Jump auf den Metronom-Tick~~ (vierte Runde: startet den Takt).
  - Wall Gym: Metronom tickt die ganze Zeit (`Metronome`-Node, `levels/metronome.gd`);
    Schachtbreiten werden aus `BPM` berechnet (breit 1 Schlag, eng ½, Koop: Treffen nach 1).
  - Ring schließt sich auf den nächsten Sprungmoment (Wand, Tick, Treffen mit Partner).
  - Chimney Clash braucht jetzt **beide Sprungtasten** beim Treffen (±80 ms), sonst fallen
    beide; der Bot kopiert P1s Druck. Gilt auch im Coop Gym.
  - Offen: fühlt sich ±40 ms um den Wandkontakt fair an? ±80 ms beim Treffen?
  Vierte Runde (Kays Test 2026-10-09):
  - Wall-Jump-Flug ohne Steuern nur noch 0.3 s (vorher 0.55): reicht für den engen Schacht,
    im breiten muss man zur Wand hin halten (gilt in allen Gyms). Danach frei steuerbar.
  - Koop-Kamin schneller: Hin, Clash, zurück an der Wand in 1.5 Schlägen (`CHIMNEY_CYCLE`,
    vorher 2). Schacht dafür schmaler (370). Man muss zur Mitte hin halten.
  - Erster Wall Jump eines Aufstiegs ist immer voll und startet den Takt: das Metronom setzt
    seinen Schlag auf diesen Sprung neu an (außer der Partner klettert schon).
  - Metronom tickt erst ab dem ersten Wall Jump und verstummt bei der Landung. Dazu ein
    leiserer, tieferer Off-Beat-Tick zwischen den Schlägen (für den engen Schacht).
    Toter Bereich an der Wandkante behoben: wer an einer Wand über ihre Oberkante hinaus
    hochrutscht, hüpft jetzt auf sie drauf (statt neben der Kante zu hängen, ohne Wand zum
    Abspringen).
  - ~~Breiter Schacht schmaler (0.9 Schläge, `WIDE_BEATS`), Koop-Kamin +35 px (`COOP_EXTRA`)~~
    (später: wieder genau 1 Schlag, siehe unten).
    Auf jeder Schachtwand oben ein Sims (`CAP`) nach außen: vorher lief man mit gehaltenem
    Stick über die 40 px breite Wandkrone hinaus und fiel ganz runter.
  - Bug behoben: mit Wand-Modus "off" (kein Ankleben) wurde der Wandkontakt nie gemerkt,
    späte Drücke zählten als 0 ms und voll. Kontakt wird jetzt unabhängig vom Ankleben
    erfasst; ohne Ankleben gilt ein Druck bis 40 ms nach dem Abprallen noch (dann schwach
    oder voll je nach Timing). Fenster jetzt ±40 ms.
  - Chimney Clash neu: der Partner ist die zweite Wand. Beim Treffen (Berührung) springen
    beide wie ein normaler Wall Jump voneinander ab (gleicher Push, gleiche Höhe, kein Halten,
    kein Boost); Timing gegen den Moment des Treffens wie an der Wand. Koop-Kamin = genau
    zwei breite Schächte (440), Takt wie im breiten Schacht. `CHIMNEY_CYCLE`, `COOP_EXTRA` und
    der Wurf (`CHIMNEY_PUSH`/`_BOOST_HEIGHT`) sind weg. Gilt auch im Coop Gym.
  - Kein Wegdriften mehr: ein voller, aber später Wall Jump (oder Clash) holt die verpasste
    Zeit nach (`_catch_up()`: fliegt ab da weiter, wo er pünktlich wäre), so addieren sich
    +30-ms-Drücke nicht und der Takt bleibt am ersten Sprung (und am Metronom).
  - Breiter Schacht wieder genau 1 Schlag (`WIDE_BEATS` 1.0, 220 px), Koop-Kamin 440: mit dem
    Nachholen trifft jetzt jeder Wandkontakt auf 120 BPM (gemessen: 500, 1000, 1500, 2000 ms;
    Koop: Treffen 500, zurück an der Wand 1000). Beim Clash wird ein Frame mit nachgeholt
    (er kommt nach der Bewegung im Frame, ein Wall Jump davor).
  - Kay: „erster Tick stimmt, je höher desto mehr Abweichung“. Jeder volle Wall Jump/Clash
    wird jetzt auf den nächsten Halbschlag des Metronoms gezogen (`_resync()`, höchstens
    ±100 ms, `WALL_RESYNC_MAX`): Kontakt zu spät → fliegt nach, zu früh → wartet kurz an der
    Wand. Kleine Verluste (Wand "off": −5 ms pro Sprung) addieren sich nicht mehr. Offen:
    langes Loslassen des Sticks im breiten Schacht kostet ~50–100 ms pro Flug, das holt es
    nicht ganz ein.
  - Auswertung von Kays Blindtest (75 Läufe): Physik auf dem Raster, Abstürze kommen vom
    Steuern mit geschlossenen Augen (breit/Koop) und vom Vorauseilen im engen Schacht.
    Danach: kein Teleport/Warten mehr beim Nachholen. Stattdessen fliegt der Sprung bis zur
    nächsten Wand (bzw. zum Treffen) bis zu ±20 % schneller/langsamer (`_tempo`,
    `WALL_TEMPO_RANGE`), auch beim Selbststeuern. Bewertung bleibt gegen den Wandkontakt
    (Kontakt und Takt sollen ja übereinstimmen), kein ungleiches Fenster, kein längerer Flug.
  - Zweiter Blindtest (Läufe 93–144; 76–92 im Log sind Claudes Testskripte): breit und Koop
    kamen ab dem ersten Flug ~30 ms nach dem Tick an (Analogstick nicht ganz durchgedrückt,
    Tempo geht im Flug verloren). Die Korrektur steuert jetzt laufend (`_steer_tempo()`): jeden
    Frame wird die normale Ankunft auf den nächsten Halbschlag gerundet und das Tempo dafür
    gesetzt (±20 %), solange man zur Wand hält; jede Neigung zur Wand fliegt dabei mindestens
    wie halber Stick. Gilt jetzt auch für den ersten Sprung.
  - Dritter Test (Läufe 145–154): Wände genau auf dem Tick (±1 ms), aber das Treffen im Koop
    immer einen Frame zu früh (−16 ms): es zählt schon 4 px vorher (`WALL_PROBE`). Die
    Steuerung zielt jetzt auf diesen Punkt; im Test Treffen bei 494–498 ms statt 483–492.
    Alle Abstürze: pünktlich gedrückt, aber Treffen/Wand kam nie, also vermutlich zu früh
    zurückgelenkt. Neu zum Ausprobieren, F1 → Walls → "turn grace" (`wall_turn_grace`, aus =
    altes Verhalten): in den letzten `WALL_TURN_GRACE` (0,12 s) vor Wand/Treffen dreht
    Zurücklenken einen nicht mehr um, man fliegt noch hin. Test: 80 ms zu früh gelenkt ohne
    → Absturz nach dem ersten Sprung, mit → alles auf dem Takt; 150 ms zu früh dreht weiter um.
    Fix danach: mit Grace kam man zwar an die Wand, der Kontakt zählte aber nicht (Tempo 0 beim
    Aufprall, Stick weg); Loslassen zählt jetzt auch (Analogstick geht beim Umdrehen durch die
    Mitte).
  - Zweite Variante zum Vergleich, F1 → Walls → "wall reach" (`wall_reach`: off/4/8/12/16 px):
    wer knapp vor der Wand umdreht, springt trotzdem noch ab, aus der Luft; der Druck wird gegen
    den nächsten Metronom-Tick bewertet (keine Berührung da). Koop: gilt für beide (bis 2 × px); die
    Clash-Taste zählt dann im Zeitfenster, auch wenn man schon auseinanderfliegt.
  - Kletter-Log fürs Auswerten (F1 → Walls → "wall gym: log every climb's timing", `WallLog`,
    `levels/gym/wall_log.gd`): jeder Aufstieg im Wall Gym eine JSON-Zeile in
    `user://wall_log.jsonl` (Schacht, Erfolg/Absturz, alle Drücke, Kontakte, Treffen, Sprünge,
    ms ab dem ersten Wall Jump = Schlag 0; Abweichung zum Kontakt bis ±500 ms und zum
    nächsten Tick/Off-Beat). Kay testet blind nach Metronom.
  **Horologium und der Level-Baukasten** (2026-10-15). Erste Fassung (fertige Räume mit Hammer,
  Glockenschacht, Pendelgang) nach Kays Test verworfen: kaum Koop nötig, nur Ausweichen. Neu:
  Räume wie bei Celeste (schwere Passage, stirbt einer, fangen beide am Raumanfang an), die Kay
  selbst im Godot-Editor baut. Doku: `docs/level_kit.md`.
  - Baukasten `levels/kit/`: `KitRoom` (Raum, BPM, gemeinsamer Tod, Ziel → nächster Raum),
    `KitSpawn`, `KitBlock` (Wand/Boden, Einweg-Plattform, auch nur für P1/P2), `KitSpikes`,
    `KitSwitch` (schlagen oder Platte, für alle/P1/P2, Toggle/Einmal/Zeit/Halten, „auf die 1“)
    + `KitDoor` (Tür oder Plattform, „irgendein“ oder „alle“ Schalter), `KitHammer`,
    `KitPendulum`, `KitBeatStep` (Rhythmus: Muster über N Takte + Versatz), `KitShaft`
    (Wandsprung-Schacht wide/narrow/coop, Breite aus BPM und der schmalen Spielerbreite),
    `KitGoal`. Alle zeichnen sich im Editor, die Takt-Teile bewegen sich dort sogar.
  - Erster Raum: `levels/horologium/horologium1.tscn` (Menü „Horologium“), Vorlage
    `levels/kit/room_template.tscn`, Beispiele unter „Kit: showcase“ (`levels/kit/showcase/`:
    Auswahlraum, ein Raum pro Teil).
  - Takt-Uhr `Beat` (Autoload, 150 BPM), Anzeige `BeatDisplay`. `Moves.override()`: ein Raum
    schaltet F1-Schalter vorübergehend ein (Schächte: Wandsprung), ohne sie zu speichern.
  - Außerhalb von `levels/kit/` und `levels/horologium/` angefasst: `core/beat.gd` (neu),
    `project.godot` (Autoload), `core/sfx.gd` (Klick und Hindernis-Sounds), `core/moves.gd`
    (`override()`), `ui/beat_display.gd` (neu), `ui/boss_select.gd` (Einträge), `levels/gym/`
    (schmale Spieler: Gefahrenbox, Kamine 110/380, Wall-Gym-Schächte; `checkpoint_needs_all`;
    eigene Physik-Layer pro Spieler), `actors/player/` nur Nichos Patch aus 70470c7
    (`BODY_SIZE` 20×40), Zeichen für Zeichen übernommen.
  - `KitCannon` + Ziel (`KitSwitch` mit `trigger` BALL): Kugel im Takt, geradeaus; perfekter
    Parry wirft sie zurück wie eine Billardkugel an der Bande (waagrecht dreht um, senkrecht
    bleibt), Block halten zerschellt sie, sonst tot. Wände zerschellen sie, Einweg-Plattformen nicht.
    Showcase-Raum `cannon`. Headless getestet (P2 → P1 → Ziel), Gefühl noch ungetestet.
  - Dazu (2026-10-16): `KitElevator` (Aufzug auf eine Schlagfolge wie `1-2-1-2-3`, 3 = beide;
    Treffer: eine Stufe hoch, Fehler: zwei runter und einen Takt Pause), `KitText`
    (Infotext), `KitBlock` mit `look` und `edges`, `KitSpikes` mit `timed`, `KitShaft` mit
    Eingang/Kappen links oder rechts, verschieden hohen Wänden, Wanddicke. Showcase-Räume
    `elevator` und `walls`. Headless getestet, Gefühl ungetestet.
  - Als Nächstes (Ideen, nicht gebaut): Pendel-Schaukel (pumpen und abspringen), Ruder-Aufzug,
    Weltschalter.
  - Offen: `Metronome` (Wall Gym, Echtzeit, startet beim Wall Jump) und `Beat` laufen
    nebeneinander. Später zusammenführen?
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
- [x] Zwei Controller: ein Pad pro Spieler (`core/pads.gd`, Branch `nicho/pep-test`), mit zwei
  Pads getestet (2026-10-14)
