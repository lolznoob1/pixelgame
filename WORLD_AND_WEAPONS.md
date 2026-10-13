# Houses, sprint, AK-47

Not tested in the Godot editor. Open the project once so the new PNGs are imported and the new classes
(`HouseColliders`, `Ak47Weapon`, `PlayerBullet`, `Fx`, `TossedWeapon`) are registered, then check the Output panel.

## Shoe knockback
`EnemyStats.projectile_knockback` (new, default 0). Thrown shoes no longer push the player. The setting and
the whole `HitInfo.knockback_distance` path are still there: give a future projectile a value and it knocks back.
Melee hits (`attack_knockback`) are unchanged.

## House collision (`world/house_colliders.gd`, node `Houses` in main.tscn)
- 36 houses were found in the city background by image analysis and verified on an overlay:
  36 roof rectangles (66x54 px) plus 20 annexes, as `CollisionShape2D` children of `Houses`
  (House01, House01_annex, ...). They are solid for the player, enemies, shoes and bullets, and you can move or
  resize them in the editor.
- Anything whose CENTER ends up inside one of those shapes is out of bounds and is teleported to
  `respawn_point` = (0, 0): the player (checked every physics frame, e.g. after teleporting into a house) and
  enemies (ghost knockback through a wall). The spawner never spawns inside a house; dropped items never
  land inside one.
- This note was about the first step (houses only). Buildings, containers, silos and trees got collision later, see
  `OBSTACLES.md`. World (0, 0) is plain asphalt at a road intersection (an earlier version of this note wrongly
  said it was a shop roof).
- Shapes must be axis-aligned rectangles (no rotation).
- Enemies steer straight at the player and have no pathfinding, so they slide along walls. To stop them from
  pressing against a wall forever, an enemy that is chasing but barely moving for 0.5 s sidesteps to a random
  side for 0.7 s.

## Sprint
- Hold Shift (new input action `sprint`, rebindable in Project Settings). Speed x1.7 (`sprint_multiplier`).
- It costs oxygen: 6 per second (`sprint_oxygen_cost`), oxygen regeneration is paused while sprinting, and
  sprinting stops below 10 oxygen. Set the cost to 0 for a free sprint. You cannot sprint while firing.
- Animation: the previously unused third row of your player sheet (y=32, 4 frames) is the new `sprint` animation, plus
  little dust puffs behind the player.

## AK-47
- **Pickup:** item `items/data/ak47.tres` (new placeholder icon). Enemies drop it: 5 % from common-table
  enemies (enemy 1 and 2), 12 % from enemy 3.
- **Ammo:** the first pickup equips the rifle with a loaded magazine (30). Every further pickup adds one spare
  magazine (30 bullets) to the reserve, up to 150. The HUD under the oxygen bar shows `AK-47  magazine / reserve`.
- **Firing:** with the rifle the attack button (hold) fires it at the mouse position, 10 shots per second, instead
  of swinging the sword. Bullets have hit detection (take_hit on enemies, they stop at walls and houses) and
  armor applies. Damage 12 per bullet, power-ups multiply it.
- **Reload:** automatic when the magazine hits 0 and there is reserve ammo, or manually with R (keeps the
  bullets still in the magazine). It uses your `reload_gun` animation, stretched to the 1.6 s reload time.
  The player uses the `idle_gun` (new, from the unused rifle idle row at y=96), `attack_gun` and `reload_gun` rows.
- **Toss:** when the magazine is empty and there is no reserve, the gun is thrown away after a short delay.
  It flies, tumbles, bounces and fades out. A pickup during that delay saves it. After that the sword is back.
- **Effects:** muzzle flash, spark particles, ejected brass casings, bullet impact sparks (yellow on walls, red
  on enemies), dust when sprinting. All in `weapons/fx.gd`; tweak the numbers there.
- All values (fire rate, reload time, damage, spread, bullet speed, spare magazines) are exports on
  `weapons/ak47_weapon.gd`.
