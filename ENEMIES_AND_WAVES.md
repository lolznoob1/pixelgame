# Rarity, approach styles, ranged enemy, waves

Not tested in the Godot editor. Open the project once (so the new PNGs are imported and classes registered),
then check the Output panel.

## Rarity
`enemy/rarity.gd`. Common, Uncommon, Rare, Legendary, Mythical. Each step doubles **health, armor and attack damage**:
x1, x2, x4, x8, x16. The name is drawn above every enemy in its rarity color and the sprite gets a light tint.
- Set it per enemy with the `rarity` export on the enemy node (the spawner sets it for spawned enemies).
- `contact_damage` is NOT scaled: the player's oxygen drain grows exponentially with it, so doubling it per tier
  would kill instantly. Attack hits and thrown shoes scale.
- **Armor** (new stat in `EnemyStats`): damage taken = damage x 100 / (100 + armor). Armor 10 = -9 %, 80 = -44 %.
  Base armor: enemy 1 = 10, enemy 2 and 3 = 5. With your 100-damage sword that means:
  common/uncommon die in one hit, rare in two, legendary in about five, mythical in about thirteen.
  Because enemies now survive hits, hurt drops and the flee state can actually trigger.

## Approach styles (`EnemyStats.approach`)
- **Enemy 1 - DIRECT:** straight line to the player (it still gets a small push away from neighbours so they don't merge).
- **Enemy 2 - KEEP_DISTANCE:** walks until it is within 80 px, backs away when closer than 30 px, stands still in between.
  Retreat speed is 30, slower than the player (40), so it can be cornered.
- **Enemy 3 - ENCIRCLE:** unchanged (spreads around the player, then closes in).

## Enemy 2: shoe thrower
- Attack = throw (`projectile_scene` in its stats). The throw animation (`assets/characters/enemy2_throw.png`,
  4 placeholder frames) is timed so the shoe leaves the hand at frame 2, exactly when the 0.4 s windup ends.
- The shoe (`assets/projectiles/shoe.png`, spins in flight) is an `EnemyProjectile`: it damages the player once
  via `take_hit`, disappears on walls, and is a dodgeable object (aimed at where the player is at release).
- To make another thrower: set `approach = KEEP_DISTANCE` and a `projectile_scene` in its stats; add a
  "throw" animation to its SpriteFrames (or leave it out, it still works without one).

## Waves (`enemy_spawner.gd`, group "Waves")
- A wave lasts `wave_duration` = 30 s. The HUD in the top-right corner shows the wave, the time until the next one
  and the current enemy rank.
- Wave 1: 10 enemies + 1 extra "variant" at RARE. Everything doubles every wave: 20+2, 40+4, 80+8, 160+16.
- After `waves_per_cycle` = 5 waves everything ranks up one step and the doubling starts over:
  wave 6 = 10 uncommon + 1 legendary, ..., wave 10 = 160 + 16, wave 11 = 10 rare + 1 mythical, and so on.
  (Ranks are capped at Mythical.)
- Set `reset_count_each_cycle = false` if the counts should keep doubling forever instead (wave 10 would be 5120).
- A wave's enemies trickle in over `spawn_spread_seconds` (20 s) instead of appearing all at once, and spawning
  pauses while `max_enemies` is reached (main.tscn sets 2000; 300-500 is more realistic for performance).
- Enemy types (1/2/3) are still picked by `enemy2_chance` / `enemy3_chance`.
- The old continuous spawn system (interval, per-minute difficulty) was removed.
