# Items, drops and combat

Not tested in the Godot editor (no Godot available while writing). Open the project once so Godot imports the new
PNGs and registers the new classes, then check the Output panel for errors.

## Hit detection (`combat/`)
- `HitDetection.is_in_arc(origin, facing, point, reach, arc_degrees)` is the one test used by player AND enemy attacks:
  inside `reach` pixels and within `arc_degrees / 2` of the facing direction.
- `HitInfo` carries damage, source, direction and knockback. Anything hittable implements `take_hit(hit: HitInfo)`.
- **Player sword** (`attack.gd`): 180 degree sector (`attack_arc_degrees`) toward `player.facing_direction`
  (last movement direction; tick `aim_with_mouse` on the player to aim with the cursor instead).
  `show_arc` flashes the area as a placeholder visual.
- **Enemy attack** (`enemy_controller.gd`): when the AI enters ATTACK, the enemy telegraphs for `attack_windup`
  seconds (red tint), then checks a 120 degree arc toward where the player WAS. Moving away dodges it.
  A hit costs `attack_damage` oxygen (EnemyStats), knocks the player back, starts the hurt state and a short
  invulnerability. The old contact oxygen drain still exists in addition.

## Items (`items/`)
- `ItemData` (.tres): id, name, effect (COIN / OXYGEN / SPEED / DAMAGE / SHIELD), amount, duration, texture, tint.
  Add an item = duplicate a file in `items/data/` and change it.
- Power-ups are timed (speed +50 %, damage +100 %, shield) and refresh instead of stacking. Coins go into
  `player.inventory`; a small label next to the oxygen bar shows coins and active power-ups.
- Oxygen tanks are ignored while oxygen is full.

## Drops
- `DropTable` (list of `DropEntry`: item, chance, min/max count, `from_inventory`).
- **Enemies:** `EnemyStats.death_drops` and `hurt_drops` (hurt drops roll when an enemy is hit but survives).
  Currently: common table for enemy 1+2, rare table for enemy 3, coin chance on hurt.
- **Player:** `hurt_drops` (loses 1-5 coins per hit, taken from the inventory) and `death_drops` (all coins),
  set on the player node.
- `ItemDropper` is created automatically on enemies and the player. Pickups pop out, hover, get pulled in
  by a magnet, blink and vanish after 15 s. At most 150 pickups exist at once (`ItemSpawner.MAX_PICKUPS`).

## Tips
- Your sword does 100 damage, so enemies die in one hit and never show the hurt state. To see hurt drops, lower
  `attack_damage` on the `attack` node or raise `max_health` in the enemy stats.
- Placeholder art lives in `assets/items/` (16x16). Swap the texture inside each `items/data/*.tres`.
