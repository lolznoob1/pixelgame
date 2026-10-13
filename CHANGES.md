# Änderungen (Review + Überarbeitung Enemy-System)

**Wichtig:** Ich konnte das Projekt nicht in Godot starten. Geprüft wurde statisch (Pfade, UIDs, Klassennamen, Einrückung, Klammern). Öffne das Projekt einmal im Editor, lass die Scripte neu einlesen und teste Spawnen, Schwertschlag, Jump-Attack und Teleport.

## Gefundene Fehler
| # | Fehler | Folge | Fix |
|---|--------|-------|-----|
| 1 | Zwei parallele Enemy-Systeme: `enemy.tscn`/`enemy2.tscn` nutzten das alte `enemy.gd`, nur `enemy3` das neue System | Halb migriert, EnemyAI-Node bei 1+2 ohne Funktion | Alle drei nutzen jetzt `enemy_controller.gd` + Stats-Resource |
| 2 | `enemy.gd`: `play("hurt")` ohne Hurt-Animation, `hurt` wurde nie zurückgesetzt | Nach dem ersten Treffer dauerhaft verlangsamt + Fehlermeldung | Hurt läuft über Timer, unabhängig von Animationen |
| 3 | `enemy.gd`: Code nach dem `match` in `_on_animation_finished` | Zugriff auf freigegebenen Player möglich | Alt-Script entfernt |
| 4 | `basic_stats_speeder.tres` enthielt leeres `SpriteFrames` | Enemy3 war unsichtbar | Aus der .tres entfernt; Controller ignoriert leere Frames zusätzlich |
| 5 | `enemy3.tscn`: `detection_range = null` usw. | Kaputte Szenendaten | Zeilen entfernt |
| 6 | `attack_range = 30`: Enemy3 blieb 30 px vor dem Spieler stehen | Berührte nie (Hitbox ~13 px) und war für das Schwert (20 px) unerreichbar | Default 18, ATTACK drückt weiter Richtung Ziel |
| 7 | O(n²): `get_nodes_in_group` pro Gegner pro Frame (Separation) und alle 0,25 s (Slots) | Bei 500-2000 Gegnern massiver FPS-Einbruch | Neuer `EnemyManager` mit Spatial Grid, Separation gecacht |
| 8 | Slot-Zuweisung nach Instance-ID | Slots verschoben sich bei jedem Spawn/Tod, Gegner kreuzten den Spieler | Zuweisung nach Winkel, einmal pro Intervall |
| 9 | Gegner im Ring liefen wieder nach außen zum Slot | Hängen am Ring | "Committed": im Ring wird direkt angegriffen |
| 10 | Kollision-Immunität setzte `collision_mask = 0` | Gegner liefen durch die Weltgrenze | Position wird in die Welt geklemmt |
| 11 | `await create_timer` in Gegner und TouchHitbox | "Resumed function after await, but instance is gone" bei Tod | Countdowns in `_physics_process` / Zeitstempel |
| 12 | Tote Gegner blieben kollidierend, in der Gruppe und konnten schaden | Latent bei Todesanimation | `_die()` deaktiviert alles |
| 13 | Zwei Quellen für "berührt Spieler" (DetectionArea + TouchHitbox), Cooldown blockierte sogar die Registrierung | Inkonsistenter Zustand | TouchHitbox ist einzige Quelle |
| 14 | Spawner verband `player_touched` mit einer Methode, die nichts tat | Toter Code + Warnungen | Entfernt |
| 15 | Spawn-Chancen verschachtelt (enemy3 = 22,8 % statt 33,9 %) | Inspector-Werte waren irreführend | Gewichtete Auswahl; 0,328/0,339 ergibt jetzt wirklich ca. 1/3 je Typ |
| 16 | Spawner-Zeit über `Time.get_ticks_msec()` | Läuft in der Pause weiter | Zeit über `_process(delta)` |
| 17 | `attack.gd` und `player.gd` lasen beide den Input, Cooldown 0,8 s vs. Animation | Schwung ohne Schaden | Spieler ruft `attack.try_attack()` auf |
| 18 | Teleport (Q) ohne Grenzen | Spieler konnte die Karte verlassen | Auf Weltrechteck geklemmt |
| 19 | `main.tscn`: Kollisionsform in WorldBounds | Unsichtbarer 20x20-Block bei (0,0) | Node entfernt |
| 20 | `JumpAttackArea`: Radius 1,4e11 mit Scale 1e-5 mal 2 | Präzisionsrisiko | Radius 14.56, Scale 1 (gleiche Größe) |
| 21 | `main.tscn6007796577.tmp`, `enemy2.gd`, root-`enemy_ai.gd`, `new_script.gd` | Müll / ruft nicht existierende `execute()` | Gelöscht, `*.tmp` in `.gitignore` |

## Bewusste Verhaltensänderungen (leicht rückgängig zu machen)
- Spawn-Verteilung (#15), Jump-Knockback immer weg vom Spieler, einzelner Gegner spawnt zufällig im Bogen statt immer mittig, Spieler wird per `add_to_group("player")` selbst registriert.

## Neue / geänderte Dateien
- Neu: `enemy/enemy_manager.gd`
- Neu geschrieben: `enemy/enemy_controller.gd`, `enemy/enemy_ai.gd`, `enemy/behaviors/chase_behavior.gd`, `attack_behavior.gd`, `enemy_spawner.gd`, `touch_hitbox.gd`, `attack.gd`
- Angepasst: `player.gd`, `world_bounds.gd`, `enemy.tscn`, `enemy2.tscn`, `enemy3.tscn`, `main.tscn`, `basic_stats_speeder.tres`, `.gitignore`

## Weitere Beobachtungen (nicht geändert)
- Schaden an der Spielerin ist exponentiell (`5 * 2^(threat-2)`), bei vielen Gegnern praktisch sofort Game Over.
- `max_enemies = 2000` ist für GDScript + `move_and_slide` sehr hoch; 300-500 sind realistischer.
- Gegner werden immer über dem Spieler gezeichnet (kein Y-Sort).
- `flee`-State ist aktuell unerreichbar, weil das Schwert mit 100 Schaden alles auf einen Schlag tötet.
