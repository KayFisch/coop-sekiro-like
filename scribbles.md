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
