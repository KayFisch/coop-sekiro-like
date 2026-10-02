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
