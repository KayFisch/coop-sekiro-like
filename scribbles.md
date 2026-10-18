# Scribbles

Unfertige Ideen, Playtest-Beobachtungen, „was wäre wenn…“. Einfach unten anhängen, mit Datum
und Kürzel. Nichts hier ist beschlossen. Wird eine Idee zur Entscheidung, wandert sie in
`docs/`; wird sie zur Aufgabe, in `TASKS.md`.

---

## 2026-09-30 (Nicho): Grundkonstellationen + Theme „Zweiseitige Wesen“

Potentielle Grundkonzepte, auf denen das Kernprinzip des Spiels beruht.

In 2D-Side-View mit Schwerkraft können Spieler (p) und Gegner (e) grundsätzlich erstmal diese
Konstellationen haben: **ppe** und **pep**.

Grundsätzlich soll im Kampf jeder ausgeglichen etwas zu tun haben, und Backstab-Spam soll es
nicht geben.

- **pep:** Boss greift gleichzeitig oder abwechselnd beide Seiten an. Spieler agieren
  größtenteils unabhängig, interagieren aber mit demselben Rhythmus gebenden Boss, also können
  beide Seiten zusammenpassen. Während ein Spieler pariert, kann der andere einen Hit landen.
- **ppe:** Boss macht einen heftigen Angriff, der von beiden Spielern pariert werden muss.

### Theme-Idee
- **Theme:** Zweiseitige Wesen (Gegner haben vorne UND hinten Angriffe). Spieler sind
  aufgeteilt in zwei Hälften – jeder Spieler hat nur **einen Arm**, Gegner aber **zwei**.

### Grundmechanik: zwei Spieler, zwei Seiten
- Jeder Spieler deckt eine Seite des Bosses ab.
- Boss rotiert/wechselt schnell zwischen Seiten → **Rhythmus entsteht durch Seite des Schlags**.
- Spieler reagiert je nach Situation: **angreifen oder parieren**, je nachdem, wo der Boss
  hinschlägt.
- Boss kann:
  - auf **beide Seiten gleichzeitig** schlagen
  - **heftigen Schlag auf eine Seite** machen → beide Spielerarme nötig

### Sync-Mechanik (Kernidee)
- Spieler sind **normalerweise getrennt**.
- **Nur kurzzeitig vereinbar**, um heftige Angriffe in Sync zu parieren.
- **Sync-Meter** füllt sich durch erfolgreiche synchronisierte Parrys (auch in pep).
- Wenn Sync-Meter voll → **Together Mode bleibt erhalten** → Finisher/Kill möglich.

### Together Mode
- **Movement-Mechanik:** Beide Hälften können sich kurzzeitig zusammenschließen →
  **Seitenwechsel**.
- Vorteil: **weniger Positioning**, Fokus auf Sync.
- **Angriff?? im Together Mode:** Das Wind-up des Angriffs gibt das Timing vor (nicht die
  Initialisierung), da zu Beginn kein Timing-Signal existiert → potentiell nur als Finisher.

### Spielerdesign
- Yin und Yang
- Spieler sind **unterschiedlich** → können nicht einfach zusammenbleiben.
- Können sich aber **splitten**.
- **Je mehr Sync**, desto länger können sie zusammen sein → **Ultra-/Finisher-Mode**.

### Normale Gegner
- Sind entweder **Yin oder Yang ×2**, können sich **nicht trennen**, sind aber bereits in Sync.

### Offene Design-Frage
- **Wie macht man es notwendig, dass Spieler normalerweise getrennt sind?**
- Vorschlag: **nur für begrenzte Zeit zusammen möglich** (Timer oder Sync-abhängig).

### Design-Prinzipien
- **Keine unterschiedlichen Spielstile** – beide Spieler haben gleiche Reaktionen auf
  Boss-Patterns.
- Fokus auf **Reaktion und Rhythmus**, nicht auf individuelle Builds.
- Sync ist zentrale Ressource für:
  - Zusammenbleiben
  - Haltungsdurchbruch
  - Finisher

→ Erster Test der pep-Grundregel: Test-Boss **Columna Bifrons** auf dem Branch
`nicho/pep-test` (Regeln und Muster in `docs/boss_columna_bifrons.md`).

## 2026-10-01 (Nicho): Parieren vs. Blocken, Seitenwechsel

- **Parieren** kann den Boss taumeln lassen.
- **Blocken** könnte das Boss-Schwert kurz festhalten, um dem anderen Spieler Zeit zu geben,
  die Seite zu wechseln (oder sonst was).
- Kontext zur Idee: Beide Seiten werden angegriffen, P1 pariert, P2 blockt. Das Schwert schwingt
  von P1 zu P2, jetzt sind beide auf einer Seite. P1 kommt also zu P2, und das könnte etwas
  eröffnen.

## 2026-10-01 (Nicho): Playtest Columna Bifrons (allein) + Sekiro/Genichiro als Vorbild

**Playtest** (allein, die linke Seite galt immer als pariert):
- Treffer im selben Moment wie der Parry („beat“) fühlt sich jetzt schon gut an; verzögert
  („after“) ist auch gut.
- Allein nicht testbar: Gibt es echte Interaktion? Solange der Partner immer perfekt pariert,
  kann man blind zuschlagen, sobald man den Angriff auf der anderen Seite sieht. Gewünscht: P1
  muss darauf achten, ob P2 wirklich pariert, und erst dann zuschlagen. Wer den Boss angreift,
  während er blockt, soll das spüren. Nur blocken (statt parieren) darf nichts öffnen.
- Angreifen und Blocken gleichzeitig darf nicht gehen.

**Wie Sekiro es macht** (soweit erkennbar):
- Gegner blocken oder parieren Angriffe standardmäßig, solange sie selbst nicht angreifen.
- In einem Wind-up oder in der Bewegung kann man sie trotzdem treffen, eher selten. Genau diese
  Momente zu finden ist wichtig und cool.
- Wird der eigene Angriff geblockt oder pariert, fällt er zurück: kein extra Stun, aber das eine
  Fenster ist weg. Der nächste Angriff geht nach dem normalen Cooldown.

**Genichiro als Vorzeigebeispiel** (G = Genichiro, P = Spieler, a = angreifen, p = parieren):
`PaGp PaGp GaPp Ga…`
- Der Kampf ist eine Schlagabfolge, die P oder G beginnt. Beide warten, ob der andere angreift.
- Das Hauptmuster entsteht aus dem Flow: G lässt sich zweimal angreifen und pariert, dann greift
  er selbst an: ein bis drei einfache Schläge, manchmal ein Spezialangriff (Sprung, Bogen …).
- Greift P ein drittes Mal an, trifft er G vielleicht, wird aber selbst getroffen: G hat schon
  ausgeholt und staggert nicht. G hat mehr Leben, also keine gute Idee.
- Der Spieler fühlt sich, als würde er den Kampf leiten (er kann proaktiv angreifen), aber der
  Gegner gibt vor, wie der Spieler reagieren muss.
- Manchmal startet G eines seiner Muster: erst alles parieren, vorher keine Zeit anzugreifen.
  Das entspricht den festen Mustern, die Bifrons schon hat. So ist es bisher eher wie Hollow
  Knight: feste Muster, dazwischen Zeit zum Angreifen.

**Daraus abgeleitet:**
- Unsere Bosse sollten reaktiver sein. Feste Muster sind cool, aber der Spieler sollte auch
  einfach angreifen können; der Boss pariert das standardmäßig, bis er selbst angreift.
- Symmetrische Regel: Greift P1 an, pariert G und reagiert: Er greift an oder ist nochmal bereit
  zu parieren. Wozu G sich entscheidet, ist dann sein Muster.
- Mit zwei Spielern wird die Reaktion reicher: Nach dem Parry kann er P1, P2 oder beide
  angreifen, z. B. den *anderen* Spieler, mit ähnlichem Delay wie beim Treffer nach dem Parry.
  Er kann P1 angreifen und dabei für P2s Angriff parierbereit bleiben. P1 und P2 können
  gleichzeitig angreifen oder nur einer; der zweite kann in die Schlagabfolge einsteigen.
- Mögliche Specials: ein durchgehender Schwung (beginnt bei P1, schwingt durch bis P2); ein
  heftiger Schlag auf einer Seite, den beide parieren müssen.
- Zu testen: Fühlen sich beide noch zusammen an, wenn jede Seite praktisch für sich agieren
  kann? Fühlt sich der Boss wie *ein* Gegner an? Hängt wohl an den Konsequenzen eines Parrys
  und an Einschränkungen (z. B. dieser Boss greift bevorzugt zweimal links, dann zweimal rechts an).
- Parry-Belohnung: In Sekiro ist es Haltungsschaden. Bei uns ist jeder parierte Boss-Angriff
  ein Fenster für den Partner, also direkter Schadensfortschritt. Mit seltenen Parrys gewinnt
  man trotzdem irgendwann; mit vielen Parrys und vollem Sync gibt es den schnelleren,
  anspruchsvolleren Weg.
- Sync sollte nicht nur langsam über Zeit verfallen, sondern auch, wenn entscheidende
  Sync-Momente verpasst werden (vielleicht nur bei Angriffen auf beide gleichzeitig?).

→ Zum Testen: ein reaktiver Modus für Columna Bifrons, per F1 umschaltbar, zusätzlich zu den
festen Mustern (Branch `nicho/pep-test`, `docs/boss_columna_bifrons.md`).

## 2026-10-02 (Nicho): ppe, Seitenwechsel durch den Boss, Sync-Modus als Verbindung

Nach dem Solo-Test der Grundregeln (Hieb, reaktiver Modus). pep = Spieler – Boss – Spieler,
ppe = beide Spieler auf einer Seite.

**Charge mit Seitenwechsel, dann heftiger Angriff.** Zwei Varianten:
- Hieb von unten nach oben, der Spieler fliegt in die Luft, der Boss charged unten drunter durch.
- Boss und Spieler laufen kurz aneinander vorbei: Der Boss schlägt auf bestimmte Art, und egal
  ob der Spieler getroffen wird, blockt oder pariert: bewegt er sich zum Boss hin, kommt er an
  ihm vorbei, während der zur Seite geht. Wer nah steht, muss sich praktisch nicht bewegen, wer
  weiter weg steht, schon.
- In beiden Fällen schwingt das Schwert der Charge-Seite mit auf die andere Seite, damit beide
  Schwerter zu den Spielern zeigen. Nicht als festes Pattern, sondern reaktiv: Schwert 1 zeigt
  zu P1, Schwert 2 zu P2, je nachdem wo sie stehen. Spieler gucken immer zum Boss.

**ppe wie pep?** Die Patterns bleiben wie vorher, nur schlagen jetzt beide Schwerter auf
dieselbe Seite, weiter abwechselnd; ein Schwert zur Seite der Spieler, eins hinten, und je
nachdem welches angreift, kommt der Schlag vertikal oder horizontal. „Beide“ ist dann ein
heftiger Schlag, den beide zusammen parieren müssen. So spielt sich ppe praktisch wie pep.
- Oder sollte sich ppe gerade *nicht* wie pep anfühlen und nur für einzelne heftige Schläge
  aktiv sein?
- Es braucht einen Weg zurück nach pep, den der Boss auslöst: z. B. ein Sprungangriff mit
  vertikalem Stich auf die Spieler, der beide auseinander wirft (zumindest wenn nicht beide
  gleichzeitig pariert haben?).

**Sync-Modus: Verbindung und Movement** (nur in ppe, wenn beide nebeneinander stehen):
- Aus zwei Charakteren nebeneinander mit zwei Schwertern wird praktisch ein Charakter mit einem
  großen Schwert. Der Impact muss spürbar sein. In dem Zustand sind die Spieler eher der Boss,
  und der Boss muss sich verteidigen, bis seine Verteidigung gebrochen ist. Erst im Sync-Modus
  können beide wirklich zusammen angreifen.
- Der Spieler auf der Boss-Seite (vorne) übernimmt Movement und sein Schwert. Der Spieler
  hinten hält einen Knopf, solange er die Verbindung nicht beenden will, und steuert seinen Arm.
- Spieler sollten keine Quadrate sein, sondern zwei Hälften, die zusammen ein Quadrat bilden:
  dünner, damit sind Schwerter und Hitboxen näher beieinander.
- Der Spieler, der nur die Verbindung hält, könnte die Angriffe des Sync-Modus starten. Ohne
  Cue schlagen beide kaum gleichzeitig; deshalb die Überlegung, dass der Angriff automatisch
  anfängt und beide kurz vor dem Zuschlagen in Sync drücken. Der Spieler ohne Movement hat den
  Daumen frei (kein Stick): Er könnte mit den Pfeiltasten aus vier Angriffen den passenden
  cuen, und beide syncen im richtigen Moment.
- Dann ist die „Taste halten“-Aufgabe vielleicht überflüssig: Beide können die Verbindung
  einfach vorzeitig abbrechen, z. B. durch Dashen in entgegengesetzte Richtungen.

**Movement des Bosses, einfaches Schema:**
- Bei bestimmten Hieben (z. B. mit viel Ausholzeit) bewegt er sich auf den Spieler zu, den er
  damit angreift: beide Spieler müssen sich neu positionieren.
- Er geht auf einen Spieler zu, der aktiv wegläuft; Angriffe des anderen Spielers verlangsamen ihn.
- Nach einem Pattern will er wieder mittiger im Raum stehen, wenn er nicht im mittleren Drittel
  ist; aus den äußeren Fünfteln erst recht.
- ppe: nach einem „Beide“-Angriff, den nicht beide pariert haben, dasht er etwas zurück.

→ Auf `nicho/pep-test` zum Ausprobieren gebaut: Schwerter folgen den Spielern (pep und ppe mit
denselben Regeln), der Charge als Aneinander-vorbei-Laufen plus Doppelschlag, der Sprung zurück
nach pep, das Movement-Schema, Blick immer zum Boss (`docs/boss_columna_bifrons.md`). Offen:
die Hieb-nach-oben-Variante, der Sync-Modus, die Spieler als zwei Hälften.

## 2026-10-02 (Nicho): nach dem Solo-Test von ppe, Crossing, Sprung und Movement

Was sich noch nicht richtig anfühlte, und was daraus folgt:

- **Schwerter zeigen auf ihre Spieler:** gut so.
- **ppe-Haltung** noch verwirrend: Das Schwert in der hinteren Ebene darf nicht das sein, das
  vorn lang schwingt. Das hintere schwingt über den Kopf, das vordere etwas tiefer, aber nicht
  ganz so horizontal.
- **„Beide“ in eigener Farbe** ist gut, Blau aber nicht: zu nah an den Spielerfarben. Später
  wären Spieler in Schwarz und Weiß und dazu Rot cooler; dafür ist der Hintergrund noch zu
  einfarbig. Erstmal etwas Auffälliges, das keiner Spielerfarbe ähnelt (Grün / Violett).
- **Crossing** funktioniert; das Ausholen war zu langsam und nicht weit genug, er darf etwas
  weiter laufen, und beim Doppelhieb danach bewegt er sich kurz oder lang zu den Spielern
  zurück. Der Dash-Parry ist mit der Tastenbelegung noch unangenehm (später ändern).
- **Sprung** gut; Schwerter näher an seiner Mitte, Rückstoß für beide stärker. Er soll seltener
  kommen: Die Spieler sollen mehr selbst entscheiden, ob sie die Positionen tauschen.
- **Movement:** Es fühlt sich komisch an, wenn er direkt an einem Spieler steht. Bessere
  Grundidee: Er versucht immer einen passenden Abstand zu beiden zu haben, so dass er trifft,
  aber nicht zu nah dran ist; hat er beide in Reichweite, steht er mittig zwischen ihnen.
  Klemmen ihn beide ein, löst er manchmal direkt den Sprung aus, springt manchmal einfach weg
  oder nutzt den Dash.
- **Bewegung auch während der Attacken:** langsamer, und im Moment des Hiebs etwas
  beschleunigt. Entfernt sich ein Spieler im Pattern, holt er auf und verbindet den nächsten
  Hieb mit einem Dash (nicht die Dash-Attacke). Beim Hieb mit langem Ausholen: erst langsam,
  dann beim Hieb schnell. Kein Anhalten und wieder Loslaufen: Es soll als Laufen oder als
  Hiebdash zu erkennen sein. (Spieler sollten beim Schlagen eigentlich auch langsamer sein;
  erstmal egal.)
- **Ins Nichts schlagen:** Folgt er einem Spieler und der andere ist wirklich weit weg, fällt
  der Hieb auf den einfach aus (knapp außer Reichweite ist okay). Passiert das oft, wechselt er
  zeitweise in einen „ppe-Modus“ gegen den einen Spieler, mit heftigen Angriffen (er muss ja
  nicht auf beiden Seiten verteidigen), und zurück, sobald beide wieder in Reichweite sind.
  Seine Aggro bleibt dabei nicht nur auf einem: Den entfernten greift er mit einem Dash an.
- **Dash-Parry:** Spieler sollten allgemein mit einem Dash-Parry durch den Boss wechseln
  können, wenn der Parry landet?
- **Stand-in:** soll Abstand halten, verletzt werden (75 % Parry, 15 % Block, 10 % Treffer)
  und unter 20 HP weglaufen und sich heilen, damit sich mehr Szenarien alleine testen lassen.

→ Auf `nicho/pep-test` gebaut (`docs/boss_columna_bifrons.md`: „How he moves“, „Left alone“,
„The dash-parry“, „Testing alone“). Offen geblieben: einfach wegspringen ohne Angriff; Spieler
langsamer beim Schlagen; die Tastenbelegung für den Dash-Parry; die Farbfrage (Grün kollidiert
mit dem Farbvokabular von Cubus und Sphaera: Grün = „in die Luft“, Blau = „zusammen parieren“);
ob der Stand-in auch angreifen soll.

## 2026-10-02 (Nicho): Kämpfe als Beats, After-Delay je Angriff, Boss-Ideen

**Kämpfe sollen sich wie Beats anfühlen** (vielleicht sogar so anhören): Hit, Parry und Konter
kommen in bestimmten Abständen. Deshalb auch der „after“-Modus: Der Konter sitzt auf einem
eigenen Schlag nach dem Parry, nicht auf demselben.

**After-Delay an den Angriff anpassen:** Wie lange nach dem Parry die Deckung bricht, hängt
vom Angriff ab, in Notenwerten gedacht. Z. B. normaler Hieb = Achtelnote Delay, schwerer
Angriff = Viertelnote. Vielleicht macht das Sinn.

**Boss-Ideen:**
- Boss mit nur einer Waffe: schlägt abwechselnd auf beide Seiten.
- Boss, der sich auch splitten kann.
- Die Arena verursacht auf einer Seite Schaden: Die Spieler müssen die Seite wechseln.
- Boss, der Schaden auf einer Seite aufgibt und damit eine Seite stärkt: zwingt die Spieler
  in pep, um seine schwache Seite anzugreifen.

→ Die Frage, was zwischen den Bossen passiert, steht in `TASKS.md` unter „Offene
Grundsatzfragen“.

## 2026-10-02 (Nicho, mit Claude durchgesprochen): Was ist der Rest des Spiels?

**Ausgangslage.** Columna Bifrons ist inzwischen ein guter Proof of Concept. Der Sync-Modus
fehlt noch; ist der drin und getestet, steht dem Boss-Fighting nicht mehr viel im Weg. Offen
ist, was es außer Bossen gibt.

**Maßstab** (Vorschlag von Claude, Nicho stimmt zu): Was zwischen den Bossen liegt, sollte
dieselben Regeln benutzen wie der Bosskampf (dein Parry lässt mich treffen, pep/ppe, Schläge
auf dem Beat). Sonst sind es zwei Spiele.

### Wohl raus

- **Lineare Story** (Sekiro, Hollow Knight): am teuersten, weil Level, Gegner und Erzählung
  alle einmalig gebaut werden. Fortschritt kommt dort durch eigenen Skill, aber es gibt keinen
  Grund, von vorn zu beginnen.
- **Roguelike mit Mobs** (Dead Cells, Wizard of Legend): lebt von Waffen und Builds, und daran
  fehlt es bei uns; das widerspricht auch „wenige Regeln, für alle gleich“. Mobs wären der
  Hauptinhalt. Dass sie wenig HP haben, wäre nicht das Problem (ein gedeckter Mob, der nur
  durch „einer pariert, der andere trifft“ stirbt, ist ein Kampf von einem Takt), aber es
  braucht Gegnertypen, Räume und ein Fortschrittssystem, bevor es trägt.

### Im Rennen

- **Fokus auf Bosse** (Cuphead, Furi, Titan Souls): zwischen den Bossen nur wenig. Der Aufwand
  landet dort, wo der Proof of Concept liegt. Nicho: scheint sinnvoll.
- **Aufwärmphase vor einem Boss: Auto-Runner plus „Beat Saber“.** Die Spieler bewegen sich von
  selbst, im Fokus sind Springen, Dashen, Schlagen, Parieren; Dinge fliegen auf sie zu, die sie
  im Rhythmus parieren und schlagen. Sieht anders aus als der Bosskampf, funktioniert aber
  ähnlich: im Kern eine Liste von Schlägen ohne Boss, jedes Ding in der Farbe seines Spielers.
  - pep und ppe lassen sich spiegeln: **zwei Lanes, zwischen denen die Spieler wechseln**
    (Nichos Idee).
  - Passt zu „Kämpfe als Beats“ (Scribble von heute).
  - Billig: Level sind Daten, wie die Angriffstabelle.
- **Platformer.** Wir wissen schon, dass Koop-Platforming interaktiv sein kann, ohne viele
  Mobility-Fähigkeiten zu brauchen, die im Bosskampf stören würden (Launch, Relay, Pogo-Clash
  benutzen dieselben Tasten und Zeitfenster wie der Kampf). Vorbilder: Hollow Knight; Celeste
  (einzelne Räume, jeder ohne Pause zu schaffen, Pause am Raumanfang). Bedenken: Platforming
  ohne Kämpfe und Bosse ohne Platforming fühlen sich wie zwei Spiele an. Wenn, dann nur aus
  Partner-Clashes gebaut, ohne eigenes Bewegungs-Kit (Wände, Ledges, Doppelsprung).
- **Berg erklimmen mit Fortschrittsverlust** (Jump King, Bread & Fred, Chained Together):
  hochklettern, durch Fallen Fortschritt verlieren, aber nur bis zum letzten Checkpoint; Bosse
  und Minibosse an den Checkpoints (Minibosse, um einzelne Mechaniken zu lernen). Claude riet
  als Hauptstruktur ab (Schuldzuweisung im Koop, zwei bestrafende Schichten). Nicho hält
  dagegen: Genau davon leben diese Spiele. Sie sind hart und tun weh, aber das Fesselnde ist
  die Herausforderung, die man bezwingen will. Bleibt also eine Option.

### Noch nicht bedacht (von Claude)

- **Roguelite ohne Mobs:** Vielfalt aus den Bossen und den Koop-Regeln statt aus Waffen:
  zufällige Reihenfolge, Boss-Varianten (eine Variante ist nur eine andere Angriffstabelle),
  Modifikatoren (beat oder after, Schwerter vertauscht, Sync verfällt schneller).
- **Minibosse als gesamter Zwischeninhalt:** ein Miniboss = ein Ausschnitt der Tabelle plus
  eine Mechanik.
- **Der Weg als Phase null des Bosses:** Der Boss greift schon aus der Ferne an, während man
  sich nähert. Die Beat-Saber-Idee, aber im Kampf verankert.
- **Umgekehrte Aufstellung:** Gegner auf beiden Seiten, die Spieler Rücken an Rücken in der
  Mitte: das Gegenstück zu pep.
- **Bewertung statt Inhalt als Wiederspielgrund:** Ränge für Sync, Zeit, ohne Treffer;
  Rollentausch.

### Reihenfolge (Vorschlag)

1. Sync-Modus fertig bauen und testen.
2. Einen zweiten Boss aus denselben Regeln bauen (am billigsten: der mit nur einer Waffe).
   Erst zwei Bosse zeigen, ob das System trägt oder nur Bifrons.
3. Von den Bossen ausgehen; als billigsten Test für den Zwischeninhalt eine Minute „Anlauf“
   (Auto-Runner/Beat-Saber) vor Bifrons im bestehenden Level. Fühlt es sich wie derselbe Kampf
   an, ist die Frage beantwortet.
4. Roguelite-Modifikatoren erst, wenn der Wiederspielwert wirklich fehlt.

## 2026-10-02 (Kay, mit Claude): Farben, Wer und Was getrennt

Zur Farbfrage aus Bifrons Runde 4 (Grün = „zusammen parieren“ kollidiert mit Cubus/Sphaera).

- **Ein Farbvokabular für das ganze Spiel**, nicht pro Boss. Für jeden Boss neue Farben zu
  lernen, macht das Spielerlebnis holprig.
- **Spieler später in Schwarz und Weiß** (Nichos Idee): Kay findet das gut. Was Nichos „dazu
  Rot“ meint, ist noch offen.
- **Zwei Kanäle, getrennt:**
  - *Wen* ein Hieb meint: das Schwert selbst, schwarz oder weiß wie sein Spieler (heute die
    farbige Kante an der Klinge).
  - *Wie* man reagieren soll: eine **Aura ums Schwert**, die beim Telegraph kurz aufleuchtet
    (z. B. ein lila Licht). Damit kann eine Angriffsfarbe nicht mehr mit einer Spielerfarbe
    verwechselt werden.
- **Boss-Idee:** ein Boss, der die Cues von P1 und P2 gezielt vertauscht, teilweise oder ganz,
  um zu verwirren. Funktioniert nur, weil das Vokabular sonst überall gilt.
- **Farbe für „zusammen parieren“:** Kay findet **Lila oder Blau** gut, kräftig gesättigt,
  nicht blass. (Lila ist heute bei Cubus der Grab, Cubus ist aber nur ein Testboss. Blau war
  zu nah an P1; mit schwarzen und weißen Spielern wäre es wieder frei.) Soll die Mitte
  zwischen Schwarz und Weiß andeuten: mittlere Helligkeit, deutlich gesättigter als Grau.
  Noch nicht entschieden.

**BPM pro Level (Kay, 2026-10-09):** Langfristig sollen die Rhythmen an der Musik hängen.
Jedes Level hat eine BPM-Variable, aus der Abstände und Geschwindigkeiten der Interaktionen
berechnet werden (Schachtbreiten, Wurfweiten, Flugzeiten, ...). Andere Musik = anderes Tempo
= alle Rhythmen ändern sich mit. Erster Schritt: `Metronome` (`levels/metronome.gd`) mit
`bpm`, das Wall Gym rechnet seine Schachtbreiten daraus. Noch fest in Sekunden und nicht
an BPM gebunden: Wall-Jump-Höhe/-Push, `WALL_FLIGHT_TIME`, `CHIMNEY_WINDOW`, das ganze
Rhythmus-Relay (`RHYTHM_BEAT`). Bei viel langsamerem Tempo passen die nicht mehr.

## 2026-10-14 (Nicho): Licht und Schatten, gespiegelter Bildschirm

**Zu Kays Farbkatalog:** gut so. Spieler in Schwarz und Weiß könnten **Licht und Schatten**
sein, und das passt perfekt zum Sync-Thema (zwei Hälften, die zusammengehören).

**Spontane Idee: horizontal geteilter Bildschirm, die Trennlinie ist eine Spiegelung.**
- Ein Spieler kämpft oben (Licht), der andere unten (Schatten). Der Boss wird komplett
  gespiegelt: Er kann Licht- und Schattenseite nicht unabhängig bewegen, die Spieler schon.
- Vorbild: die Spiegelszene in *Gris*; der Artstyle von Gris insgesamt als Inspiration
  (fast monochrom, weißer Boden, schwarze Figuren, Farbe als Akzent).
- Könnte Platzprobleme und Sichtbarkeit lösen (die Spieler verdecken sich nie).
- Probleme: auf einem Bildschirm spielt einer immer kopfüber; jede Hälfte hat nur halb so viel
  Höhe. Auf zwei Bildschirmen spielt jeder richtig herum und sieht den anderen gespiegelt unten.

**Einschätzung (Claude):**
- *Das Wichtigste:* Die Spiegelung kann reine Darstellung sein. Die Spieler stehen weiter in
  einer Welt auf einem Boden, Regeln und Physik bleiben wie heute (pep, ppe, Dash-Parry,
  Partner-Clashes). Nur das Bild zeigt oben Licht-Spieler + Boss und unten Schatten-Spieler +
  gespiegelten Boss. In Godot: zwei SubViewports auf derselben Welt, der untere vertikal
  gespiegelt, jeder blendet den anderen Spieler aus (Visibility-Layer). Damit ist es ein
  billiger Test mit Bifrons, ohne die Mechanik anzufassen.
- *Kopfüber:* Gespiegelt ist nur das Bild, nicht die Steuerung: Springen drückt man weiter
  „hoch“, die Figur geht auf dem Bildschirm nach unten. Wie schlimm das ist, zeigt nur ein Test.
  Ausweg, falls es zu unangenehm ist: unten nicht spiegeln, sondern dieselbe Szene richtig herum
  in Schattenfarben (klassischer Splitscreen); die Spiegelung als Bild ginge verloren, die
  Trennung bliebe.
- *Platz:* 324 px Höhe pro Hälfte; Bifrons mit erhobenem Schwert ist knapp 300 px hoch. Also
  rauszoomen oder alles kleiner.
- *Was verloren gehen könnte:* dass man den Partner direkt neben sich sieht. Der Sync-Modus
  (beide nebeneinander werden einer) und die Partner-Clashes leben davon. Vielleicht ist genau
  das der Sync-Moment: die beiden Hälften treffen sich an der Spiegellinie.
- *Zwei Bildschirme* sind lokal selten; für Online-Koop wäre es natürlich. Nicht davon abhängig
  machen.

## 2026-10-15 (Nicho): Beat-Dash-Level gespiegelt

- Wie beim Bosskampf könnte der Bildschirm gespiegelt sein: Jeder Spieler hat seine Seite
  (oben Licht, unten Schatten).
- Aus einer Richtung kommen Hindernisse, über die man springen muss; aus einer anderen
  vielleicht Projektile, die man angreifen oder parieren muss.
- Es könnte Stellen geben, an denen die Spieler die Seiten wechseln oder zusammen auf eine Seite
  kommen, um besonders schwere Hindernisse oder Angriffe zu schaffen.

→ Prototyp Beat-Runner in `TASKS.md`; der Spiegel-Bildschirm (`ui/mirror_view.gd`, Branch
`nicho/pep-test`) wäre die Grundlage.

## 2026-10-15 (Kay, mit Claude): Jump'n'Run-Hindernisse mit Rhythmus

Für den Koop-Platformer („Prototyp Koop-Jump'n'Run“) brauchen wir mehr Möglichkeiten für Level,
aber keine neuen Movement-Fähigkeiten: Die machen einen allein zu mobil und geben im Bosskampf
zu viele Optionen. Grundidee daher: neue Dinge in der Welt, auf die die vorhandenen Verben
(Schlag, Parry, Block, Pogo, Dash-Slash, Launch, Relay) wirken, mit rhythmischer Komponente. So
trainiert der Platformer nebenbei den Bosskampf.

**Die Welt hat einen Takt**
- *Taktblöcke:* Plattformen existieren nur auf bestimmten Schlägen (wie Celestes Beat-Blöcke).
  Koop-Variante: je Spieler Blöcke in seiner Farbe, abwechselnd.
  Kay: viele interessante Optionen.
- *Stampfer / Sägen im Takt:* schlagen auf dem Beat zu, durch kommt man auf dem Offbeat.
  Kay: leicht und simpel.
- *Tempowechsel:* Ein Abschnitt zieht das Tempo an, Ruhezonen bremsen; wirkt sich auf den
  Rhythmus der Spieler aus. Kay: sehr interessant, muss aber klar gekennzeichnet sein.

**Die Umgebung parieren**
- *Kanonen-Relay:* Eine Kanone feuert im Takt, P1 pariert zu P2, P2 pariert in einen Schalter
  oder eine brüchige Wand. Kay: cool, muss aber wirklich als Koop funktionieren (nicht von
  einem allein lösbar).
- *Pendelklingen:* Ein Parry stoppt das Pendel oder kehrt es für ein paar Schläge um; einer
  hält auf, der andere läuft durch. Passt zu Sphaera. Kay: cool.
- *Rammkolben:* Block hält ihn nur und schiebt einen zurück, ein perfekter Parry schlägt ihn
  zurück und verriegelt ihn für N Schläge. Kay: nicht super spannend, aber okay.
- *Spiegel / Lichtstrahl* (geparkt, war unklar formuliert): Ein Strahl pulsiert im Takt; wer
  blockt, lenkt ihn mit dem Schwert um (z. B. auf einen Kristall, der etwas öffnet). Erstmal
  zurückgestellt.

**Schalter mit Rhythmus**
- *Ruf und Antwort (Simon says):* Ein Tor spielt eine Folge vor, die Spieler spielen sie nach,
  aufgeteilt auf beide („ich, du, ich, ich, du“). Kay: cool; soll Parry UND Schlag abfragen,
  also ein Rhythmus aus Instrumenten (z. B. Schlag = Trommel, Parry = Glocke).
- *Weltschalter:* Jeder Schlag auf einen Hebel kippt die Welt zwischen zwei Zuständen; einer
  spielt den Hebel im Rhythmus, der andere läuft durch die sich umbauende Welt.
  Kay: interessant; Variante: muss von beiden gleichzeitig aktiviert werden.

**Bewegliche Teile im Takt antreiben**
- *Schaukel pumpen:* Schlag/Parry im Umkehrpunkt verstärkt die Schaukel; einer pumpt, der
  andere springt am höchsten Punkt ab. Kay: gut; gekoppelt an die Musik: Man muss immer
  schneller schlagen, und die Musik wird auch schneller.
- *Ruder-Aufzug:* Ein Schlag auf dem Beat hebt ihn eine Stufe, daneben fällt er zurück;
  abwechselnd schlagen bringt ihn doppelt so schnell hoch. Kay: cool.

**Mini-Wächter**
- *Wächterstatue:* bewacht eine Lücke mit genau einer Attacke im festen Takt, in derselben
  Farbsprache wie die Bosse. Der Trick ist, die Attacke zu nutzen (parierte Klinge als
  Pogo-Fläche, Hieb als Launch). Kay: klingt cool.
- *Vokabeltrainer:* Jede Telegraph-Farbe der Bosse bekommt einen Abschnitt, in dem man die
  Antwort lernt. Kay: gehört ins Tutorial, um die „Farbvokabeln“ der Bosse beizubringen.

**Noch nicht kommentiert**
- *Metronom-Schalter:* Ein Schlag öffnet eine Tür für N hörbare Schläge, Schalter beim Partner
  verlängern (Kette über den Raum).
- *Gleichzeitig / versetzt:* zwei Glocken auf denselben Schlag (Sync) oder genau einen Schlag
  versetzt.
- *Waage im Takt:* die Waage aus dem Duo Gym, aber die Schalen schwingen selbst.
- *Dirigent und Läufer:* Einer gibt an einer Trommel das Tempo der Welt vor, der andere läuft.
- *Echo-Plattform:* Wo der Partner einen Schlag vorher stand, entsteht kurz eine Plattform.

→ Taktblöcke, Stampfer und Tempowechsel überschneiden sich mit Nichos Beat-Runner (`TASKS.md`):
Dasselbe Metronom könnte beide tragen, also absprechen. Für den Moment brauchen wir nur wenige
davon; die Auswahl folgt.

## 2026-10-16 (Nicho, mit Claude): Sync als Leben, die Umstellung

Ausgangspunkt: Der alte Sync (0 bis 100, Multiplikator ×1,5/×2) wird zu leicht voll und
belohnt Spielen ohne Partner (Mashen ist gleich schnell). Er wird für den Test gestrichen; das
alte System bleibt umschaltbar und wird später mit den Erkenntnissen angepasst.

**Anforderungen:** schwerer und länger bis voll; Sieg ohne Sync bleibt möglich; ohne Sync nie
schneller und nie sicherer als mit; Sync-Spiel fühlt sich besser an. Dazu (Claude, Nicho
einverstanden): jede Bewegung der Leiste lesbar; kein Strudel ohne Ausgang; eine Belohnung pro
Zustand; wenige Regeln, für jeden Boss gleich.

**Entscheidungen (Nicho):**
- Keine Gesundheit, keine Tränke. Ein Sync für beide Spieler, Start in der Mitte; der Boss
  startet voll (zwei Wesen, schon zusammen) und verliert nur, außer durch einen eigenen
  Koop-Parry (beide Spieler greifen gleichzeitig an, er pariert beide) oder einen Schlag, der
  beide trifft.
- Dazu Haltung wie in Sekiro. Sync und Haltung sind nicht zu viele Leisten (Sekiro hat vier);
  Haltung kann anders aussehen, z. B. ein Kreis, der schrumpft.
- Sync verfällt nicht über Zeit; Haltung regeneriert, umso langsamer, je weniger Sync.
- Gleiche Folgen für Spieler und Boss. Eingehend: ungeblockt = Sync-Schaden, geblockt =
  Haltungsschaden, pariert = weniger Haltungsschaden (kann nicht brechen), Koop-Parry =
  Sync-Gewinn. Ausgehend: nicht im Sync = kein Gewinn, im Sync = Gewinn, Fenster verpasst =
  Verlust.
- Haltung gebrochen = Stagger und aller Sync weg, wie der Todesstoß in Sekiro.
- Leerer Sync = Chaos, wie ein Revive: kein Blocken, der nächste unparierte Treffer tötet; vorbei
  erst, wenn genug Sync zurück ist (Belohnungen bleiben gleich). Vertauschte Steuerung höchstens
  als Mechanik eines Bosses.
- Voller Sync = Sync-Modus, die zweite Phase; ab da soll der Kampf nicht mehr lang sein. Ihn zu
  erreichen ist nicht nötig, also umso mehr Belohnung für sehr sync-fokussiertes Spiel.
- Ein Koop-Parry ist kein Haltungsbruch: kein oder nur kurzer Stagger.
- Sync-Hit genau auf dem Beat bringt mehr als daneben (wie Parry gegen Block), sichtbar am
  Schwert (Aufleuchten im Moment, in dem man treffen müsste).
- Blocken abhängig vom Sync: verworfen (arbeitet gegen den Sync-Aufbau). Multiplikator: weg.
- Übertrag aus dem Zwischenlevel: erstmal egal, später gedeckelt möglich.

**Offen:** Ist „nicht blocken“ als Folge des Chaos genug, oder kommt noch etwas dazu, oder fällt
das Chaos weg und leerer Sync ist direkt der Tod? Die Zahlen (F2).

→ Umgesetzt auf `nicho/pep-test`: `core/sync_rules.gd`, Regeln in
`docs/boss_columna_bifrons.md` → „Sync as life“. Der eigentliche Sync-Modus (zwei Spieler werden
einer) ist noch zu bauen.

## 2026-10-15 (Kay): Platformer in Welten, passend zu den Bossen

Das Platformer-Konzept würde ich mehr oder weniger in **Welten** aufteilen. Die Level wären dann
an ihrem Boss orientiert und umgekehrt: Hindernisse aus den Platformer-Leveln kommen als
einzelne, wiederkehrende Elemente in den Bosskampf. Eine Welt kann gerne mehrere Bosse haben,
z. B. Boss 1, Boss 2 und am Ende den finalen Boss der Welt. Das Welten-Konzept würde genauso für
die Beat-Saber-Alternative funktionieren (Nichos Beat-Runner, `TASKS.md`).
- *Beispiel Pendel:* das schneller werdende Pendel aus dem Platformer (siehe „Pendelklingen“,
  „Schaukel pumpen“) taucht im Bosskampf wieder auf: Man muss es bis zum Überschlag bringen, um
  dem Boss zu schaden. Passt zu Sphaera.
- *Beispiel Spiegel:* Nichos gespiegelter Bifrons (Schattenachse, Spiegelung an der x-Achse)
  könnte das Thema einer ganzen Parkour-Welt sein. Das passt zur Idee der Weltschalter, die die
  Welt umbauen: Der Schalter kippt zwischen Licht- und Schattenseite.

## 2026-10-16 (Kay): Woher kommen die Boss-Designs? Zweiköpfige Wesen aus Mythen

Schon beschlossen: Bosse sind meistens zweiseitig; der Look wahrscheinlich schwarz-weiß / Yin
und Yang. Offen: wie die Bosse genau aussehen. Zur Inspiration: In vielen Mythologien gibt es
zweiköpfige oder zweigesichtige Wesen, Monster und Götter. Daraus vier Wege:

- **A: Aus allen Mythologien sammeln.** Jede Kreatur wird ein eigener Boss, in unseren Stil
  übersetzt. Gibt gleich verschiedene Designs, und potenziell ein Thema pro Welt (eine Welt
  pro Mythologie, passt zu „Platformer in Welten“ vom 2026-10-15).
- **B: Eine besonders passende Kreatur** als Inspiration für alle Designs.
- **C: Eine Mythologie** auswählen und alle Designs daraus nehmen.
- **D: Komplett frei** designen.

Kay findet **A** sehr interessant. Nicho: was meinst du?

Erste Kandidaten zum Weiterdenken (Claude, ungeprüft gesammelt):
- *Janus* (römisch): zwei Gesichter, nach vorn und hinten; „bifrons“ ist sein Beiname, Columna
  Bifrons ist schon halb er.
- *Orthros* (griechisch): zweiköpfiger Hund, Bruder des Kerberos.
- *Ardhanarishvara* (hinduistisch): halb Shiva, halb Parvati, längs geteilt: zwei Hälften in
  einem Körper, nah an Yin und Yang.
- *Gandabherunda* (indisch): zweiköpfiger Vogel.
- *Fuxi und Nüwa* (chinesisch): ein Paar mit verschlungenen Schlangenleibern.
- *Amphisbaena* (griechisch-römisch): Schlange mit einem Kopf an jedem Ende.
- *Doppelköpfige Schlange* (aztekisch).
- *Ettin* (englische Folklore): zweiköpfiger Riese.

## 2026-10-17 (Nicho): Abstand schaffen, dann ein heftiger Schlag

Am neuen Crossing gefällt mir sehr: Der Boss schafft Abstand zu einem Spieler (er stößt ihn weg)
und setzt mit einem heftigen Schlag nach, sodass der andere Spieler hin-dashen muss. Das bringt
Abwechslung: Vom Spieler wird mehr verlangt als nur stehen und Parry/Hit drücken. Der Kampf wird
damit wesentlich dynamischer.

→ Mit diesem Gedanken die Patterns noch einmal überarbeiten (Task in `TASKS.md`).

Ideen dazu (Claude, zum Weiterdenken):
- Ein Schlag, der einen Spieler wegschleudert, und gleich danach einer auf den Partner: Wer
  weggeschleudert wurde, muss zurück, um im nächsten Fenster wieder dabei zu sein.
- Ein Rückzug (Hüpfer zurück, Sprung zur Seite), auf den ein Schlag aus der Distanz folgt: Beide
  müssen nachsetzen, statt zu warten.
- Ein Stoß, der beide auf eine Seite treibt, und dann ein Hieb auf den hinteren: Der muss am
  vorderen vorbei (Dash-Parry durch den Boss oder über den Partner).
- Allgemein: Jedes Pattern, das Abstand schafft, sollte mit einem Schlag enden, der nur trifft
  oder pariert wird, wenn man den Abstand wieder schließt.

## 2026-10-17 (Nicho): Haltung und Schaden, einfacher (Sync als Leben)

Systemänderung, damit das Kampfsystem verständlicher wird:
- Haltungsschaden gibt es auch beim Parieren: Der Boss greift an, ein Spieler pariert, und der
  Boss erleidet Haltungsschaden.
- Nur kleiner, mittlerer und großer Haltungsschaden, und normale und heftige Angriffe:
  - klein: ein eigener normaler Angriff wird pariert; man pariert einen normalen Angriff; man
    blockt einen normalen Angriff;
  - mittel: man wird normal getroffen (kein Block/Parry); man blockt oder pariert einen heftigen
    Angriff; ein eigener heftiger Angriff wird pariert;
  - groß: man wird von einem heftigen Angriff getroffen (kein Block/Parry).
  - Entscheidend: Blocken verursacht keinen Haltungsschaden beim Gegner.
- Sync-Schaden ist simpler: viel durch einen heftigen Angriff, ein Drittel bei normalen.
- Spieler machen normale Angriffe, nur im Sync-Modus immer heftigen Schaden. Boss und Spieler
  machen erstmal gleich viel Schaden (zwei Variablen, um es anzupassen); entscheidend ist, dass
  die Spieler weniger Leben (Sync-Max) haben als der Boss.
- Haltung regeneriert erst wieder 2 s, nachdem kein Angriff mehr landet (egal ob pariert,
  geblockt oder nichts gemacht) und kein eigener Angriff ausgeführt wird.
- Block halten, ohne angegriffen zu werden, verdoppelt die eigene Haltungsregeneration (macht
  eigentlich nur der Spieler).
- Haltungsregeneration ist bei 50 % Leben (Sync) kaum noch vorhanden, bei 75 % schon auf die
  Hälfte reduziert.
- Es ist im Grunde ein fairer Abtausch. Entscheidend ist, dass die Spieler sich heilen können
  (Sync aufbauen) und der Boss nicht: Irgendwann sorgt jeder Schlagabtausch dafür, dass der
  Boss mehr ansammelt als die Spieler. Aber der Boss hat eben mehr.
- Noch zu schauen: wie die Patterns und das Verhalten des Bosses angepasst werden müssen.

Umgesetzt auf `nicho/posture-rules` (Regeln: `docs/boss_columna_bifrons.md` → „Sync as life“).
Claude dazu:
- Seine heftigen Angriffe sind die mit beiden Schwertern (grün: beide Schwerter, der Sprung); der
  Sweep (ein Schwert) zählt als normal. Ein Sync-Hit macht so viel wie jeder normale Treffer und
  bringt euch Sync; der Sync-Modus macht eure Angriffe heftig (statt dreifach).
- Der Boss holt keinen Sync mehr zurück (die zwei Ausnahmen vom 2026-10-16 sind raus). Folge:
  Ist seine Haltung einmal gebrochen, bleibt er im Chaos, und der nächste Treffer tötet ihn: der
  Todesstoß aus Sekiro.
- Zwei Stand-ins gegen ihn: Seine Haltung bricht nach 19 bis 40 s, sein Sync steht dann noch bei
  170 bis 190 von 200. Seine Haltung kommt nur 4 bis 10 % der Zeit zurück, weil er fast immer
  angreift und seine Pausen kürzer als 2 s sind; wie viel Sync er hat, spielt dafür kaum eine
  Rolle. Hebel: Pausen in seinen Patterns, die Haltungsgrößen, seine Haltung (200).
- Ihr startet bei 50 % Sync, also mit kaum Haltungsregeneration (5 %), bis ihr Sync aufbaut.
  Gewollt? Sonst: Start-Sync höher oder die 50 %-Grenze tiefer (beides in F2).

## 2026-10-17 (Nicho): Sync-Modus

- Die pinke Farbe bleibt (die Energiewelle sieht sehr gut aus und hilft sehr).
- Wird der Sync-Modus erreicht, bekommen beide Spieler an ihren Füßen das Signal, dass sie sich
  verbinden können. Kommen sie zusammen, verbinden sich beide Charaktere: wie Yin und Yang fließt
  das Weiße etwas ins Schwarze und umgekehrt, über die Bodenlinie.
- Bewegung im verbundenen Zustand: noch offen.
- Schlagen und Parieren:
  - Beide Schwerter werden größer und säbelartiger, mit schwarz-weißem Design.
  - Beide können ihr Schwert durch gedrückt gehaltenen Schlag ausholen; maximal ausgeholt gibt
    es einen kleinen Hinweis. Sind beide ausgeholt, kommt kurz nach dem späteren ein größerer
    Hinweis, bei dem beide loslassen müssen.
  - In Sync: ein heftiger Angriff. Außer Sync: Sie schlagen zwar zu, aber man sieht, dass es kein
    krasser Schlag war, und sie verlieren Sync.
  - Im Sync-Modus schwingt der Boss wohl immer beide Schwerter zusammen (die Schwerter könnten
    dabei näher zusammen sein, damit es weniger wirr aussieht).
  - Erfolgreich parieren nur, wenn beide in Sync parieren, wie sonst bei heftigen Angriffen.
  - Der Stand-in reagiert einfach immer perfekt auf den Spieler.
  - Screen Shake oder ein anderer Effekt?
  - Überlegung: Im Sync-Modus verschmelzen die getrennten Ebenen zu einer, beide stehen wie im
    alten ppe zusammen. Dann wächst bei der Vereinigung nicht der Fuß zusammen, sondern der
    Schatten geht ins Weiße über, und die ganze untere Ebene geht aus dem Fokus: der Bildschirm
    fast wie vor dem Split.
  - Ein In-Sync-Schlag könnte auch dann Sync-Schaden machen, wenn der Boss pariert, wie ein
    normaler Treffer, der durchgeht.
  - Das Angriffsmuster des Bosses muss wohl angepasst werden, weil die Angriffe vielleicht zu
    schnell kommen, um auszuholen. Vielleicht hat der Boss sichtbar Probleme, die Angriffe zu
    parieren, und deshalb einen größeren Cooldown bis zur nächsten Aktion: der Kampf wird etwas
    langsamer.
- F1 und F2 in Tabs / Kategorien, damit nicht immer alles gleichzeitig offen ist.

Umgesetzt auf `nicho/posture-rules` (`docs/boss_columna_bifrons.md` → „The sync mode“). Claude
dazu:
- Verbunden wird, wer nah genug zusammensteht (30 px, beide am Boden); über 90 px auseinander
  löst es sich. Bewegung bleibt vorerst, wie sie ist.
- Die Verschmelzung der Spiegelhälften ist ein Schalter (`sync_merge_view`, aus): ausprobieren
  und vergleichen.
- Der In-Sync-Schlag, den er pariert, kostet ihn den Sync eines normalen Treffers und lässt ihn
  taumeln (0,8 s); euch kostet er nichts.
- Getrennte Schläge im Sync-Modus sind jetzt normale Angriffe; vorher machte der Sync-Modus jeden
  Treffer heftig. Sonst lohnt sich das Verbinden nicht.
- Im Sync-Modus nimmt er nur seine Patterns aus normalen Schlägen (alle mit beiden Schwertern),
  nichts, was euch auseinanderwirft (Crossing, Sweep, Sprung, Rush), und alles 1,4-mal so
  langsam.
