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
