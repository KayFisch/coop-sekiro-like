# Übergabe an Kay: Heavy Hitter, Schritt 2 (B3): Wut und Phase 2

Von Nicho (2026-10-21), mit Claude im Chat vorbereitet. **Nur B3, sonst nichts.** Danach testen
Nicho und Kay den Hitter (und den Wächter) gemeinsam, bevor irgendetwas weitergebaut wird.

Schritt 1 (Grundgerüst, Phase 1) ist gebaut und nach Nichos erstem Test umgebaut, auf
`nicho/heavy-hitter` (von `nicho/chains`, nicht in `main`). Was drin ist:
`docs/boss_heavy_hitter.md` → „Built (phase 1, …)“ und „First test (Nicho, 2026-10-21)“.

## So gehst du vor

1. Session-Start wie in `CLAUDE.md` (die Notizen für Kay dort weitergeben).
2. **Branch:** `kay/hitter-rage`, abgezweigt von `nicho/heavy-hitter`. Nicho ändert auf seinem
   Branch eventuell noch Kleinigkeiten; nicht dort committen, nichts nach `main` mergen.
3. Lies `docs/boss_heavy_hitter.md` ganz, vor allem „The rules (v0)“ (Regeln 1 und 2 sind seit dem
   Test neu), „Rage“, „Provoking“, „Finales“, das Verb „Flip“ und „Built (phase 1, …)“.
4. **Zeig vor dem Bauen den Plan**, mit der Tabelle unten (was jedes Wut-Pattern in pep und ppe
   bedeutet) so, wie du sie im Code verstehst. Weicht etwas ab oder ist unklar: fragen.
5. Gefühl und A/B hinter Schalter: F1 (`core/moves.gd`) oder F2 (seine Seite „Heavy Hitter“,
   `tuning_entries()` in seinem Skript). Jede neue Regel bekommt einen Test; vor dem Commit alle
   Tests (`godot --headless --script res://tests/run.gd`). Was außerhalb von `BaseBoss`'
   Idle-Timer startet, respektiert `dev_hold`.
6. **Nach B3 ist Schluss.** Keine weiteren Ideen einbauen. Am Ende: Doc und `TASKS.md`
   nachziehen, eine Notiz „For Nicho, from Kay“ in `CLAUDE.md` mit dem, was gebaut ist und worauf
   beim gemeinsamen Test zu achten ist.

## Was seit dem Entwurf der Wut anders ist

Der Abschnitt „Rage“ im Doc wurde vor dem Umbau vom 2026-10-21 geschrieben. Seitdem:

- **Regel 1:** Jeder Kopf geht auf seinen Spieler. Nur wenn beide vor der Klinge stehen, kommt
  ein heftiger Schlag in beiden Ebenen (gemeinsam parieren, sonst Wirkung eines Blocks). Einer an
  der Klinge, einer am Knauf: normale Schläge, jeder in seiner Ebene.
- **Regel 2, der Riss:** Eine Klinge, die nichts gestoppt hat, bricht an der Stelle **in die
  andere Hälfte** durch (still, nach 0,3 s, trifft dort den Spieler am Boden in 70 px).
  „Gestoppt“ heißt pariert, oder geblockt, während die Klinge der anderen Ebene pariert wurde.

**Festlegung für die Wut** (Claude, mit dem Wut-Text verträglich; Nicho und Kay prüfen sie beim
gemeinsamen Test): **In der Wut kommt jeder Klingenschlag in beiden Ebenen und heftig**, egal wo
die Spieler stehen (beide Köpfe legen ihre Wut in jeden Schlag; er richtet sich nicht nach euch).
Ein einzelner Parry hat also die Wirkung eines Blocks; Risse nach Regel 2. Daraus folgt:

| Pattern | ppe (beide auf einer Seite) | pep (je einer pro Seite) |
|---|---|---|
| **Pendel** (parallel, abwechselnd links und rechts) | Schlag auf eure Seite: gemeinsam parieren. Schlag auf die andere Seite: beide Klingen gehen ins Leere, die Risse brechen auf der leeren Seite durch (harmlos). **Leicht.** | Wer auf der getroffenen Seite steht, pariert allein (nur Block); die Klinge des Partners geht ins Leere und bricht direkt unter ihm durch: nach dem Parry springen. Nächster Schlag: umgekehrt. **Schwer.** |
| **Kreuz** (diagonal, abwechselnd) | Abwechselnd pariert einer allein (nur Block); die andere Klinge bricht auf der leeren Seite durch (harmlos). Kein Sync, kaum Stagger. **Schwer.** | Beide vor der Klinge: gemeinsam parieren. Danach beide Klingen ins Leere: jede bricht unter dem Partner durch, beide springen. **Leicht.** |

Er wählt das schwere Pattern für die Formation zu Beginn des Telegraphs (pep → Pendel, ppe →
Kreuz); während des Telegraphs können die Spieler umstellen und es leicht machen.

**Wie oft:** Laut „Built“ bricht seine Haltung im together-Feld etwa einmal pro Kette. Mit einer
ganzen Wut-Kette wäre das sehr oft. Nicht selbst entscheiden: mit dem Stand-in messen, wie oft die
Wut kommt, und es in der Notiz für Nicho nennen (F2 „hitter_posture_max“, „hitter_pommel_posture“).

## B3: der Auftrag

~~~text
Ersetze den Platzhalter beim Haltungsbruch (heute "hitter_break_stagger", über
BaseBoss.on_posture_broken()) durch die Wut, und schalte mit der ersten Wut Phase 2 frei.

Wut
- Haltungsbruch → Telegraph: beide Köpfe rot, ein Brüllen (F2-Dauer, Start 1,6 s). Das Pattern
  wählt er nach der Formation zu Beginn des Telegraphs: pep → Pendel, ppe → Kreuz. Am Telegraph
  erkennbar, welches kommt (Pendel: die Waffe in beiden Hälften gleich; Kreuz: über Kreuz).
- Dann das Pattern ohne Umdrehen, egal wo die Spieler stehen; jeder Klingenschlag in beiden
  Ebenen und heftig (siehe Tabelle oben), Risse nach Regel 2. Pendel = parallel, abwechselnd
  links und rechts; Kreuz = diagonal, abwechselnd. Anzahl und Abstand auf F2 (Start: 6 Schläge,
  je 3 Schläge der Uhr).
- Danach Erschöpfung: Stagger 0,5 s plus 0,2 s je parierter Klinge in der Wut (gemeinsam 0,4 s;
  ein Parry mit der Wirkung eines Blocks zählt nicht). Sein Sync bleibt, die Haltung ist danach
  voll, die Ausrichtung bleibt, wie das Pattern sie hinterlässt (Pendel parallel, Kreuz
  diagonal).

Phase 2 (ab der ersten Wut; zum Testen ein F1-Schalter oder F5, um direkt in Phase 2 zu
starten)
- Diagonal auch im Normalmodus: die Felder ergeben sich aus der Tabelle "The weapon in two
  layers", die Motive und Regeln wie in Phase 1.
- Das Kippen als Verb: die Köpfe drehen sich zueinander, einer reißt die Klinge an sich, die
  Waffe schwingt in einer Ebene um 180°, parierbar, wo sie einen Spieler erreicht.
- Das Kippen als Finale, wenn das together-Feld zu lange dauert (statt des Stampfsprungs; F2
  "hitter_together_stale"): eine Ebene kippt (together → split), dann ein Klingenschlag mit so
  langem Ausholen, dass einer rüber kann (F2); stellen sie um und parieren gemeinsam → Stagger
  wie beim Großen Hammer.
- Im Atem dreht er sich weiter nur um (beide Ebenen), sodass möglichst viele vor der Klinge
  stehen; die Ausrichtung ändert sich nur durchs Kippen und in der Wut.
- Provokation: ein Treffer auf seiner Knaufseite in deiner Ebene → der Kopf wird sofort rot; am
  nächsten Ende einer Wiederholung kippt deine Ebene zu dir (aus split wird together).

Optional, F1, Standard aus: die letzte Wut, wenn sein Sync unter einen Anteil fällt (F2):
Pendel und Kreuz im Wechsel, Ende im Großen Hammer.

Stand-in (hitter_stand_in.gd): stellt sich im Wut-Telegraph und nach dem Kippen um, wenn das
hilft (F2-Wahrscheinlichkeit), springt die Risse der Wut.

F5-Labor: RAGE_PENDULUM, RAGE_CROSS, FLIP, FLIP-Finale einzeln startbar.

Tests (tests/test_heavy_hitter.gd): Wahl des Wut-Patterns nach Formation, heftig in beiden
Ebenen in der Wut, Erschöpfungs-Stagger, Ausrichtung nach der Wut, Sync bleibt beim
Haltungsbruch, Kippen nur in einer Ebene, Provokation kippt erst am Ende der Wiederholung,
Freischaltung von Phase 2.

Docs: in docs/boss_heavy_hitter.md den Abschnitt "Rage" an die Festlegung oben anpassen
(Tabelle), einen Abschnitt "Built (rage and phase 2)" mit Schaltern und Zahlen; TASKS.md;
die Notiz für Nicho in CLAUDE.md.
~~~
