# Turning sprites, bottle, upgrade window

Not tested in the Godot editor. Open the project once (imports the new PNGs, registers the new classes), then check
the Output panel.

## Small changes
- **Shoe doesn't stun:** `EnemyStats.projectile_stun` (default false). A shoe hit deals damage and gives a short red
  flash, but the player keeps control. `HitInfo.stun` is the general switch: melee hits still stun, and any future
  projectile can choose. Knockback of non-stunning hits is a small instant push (`knockback_distance`).
- **No coin drops for the player:** the player no longer has drop tables assigned (the drop system itself is untouched;
  assign `hurt_drops` / `death_drops` on the player again to bring it back). Coins are now only spent in the upgrade window.

## 360 degree turning
- The art only exists front-facing, so `tools/make_directions.py` generates 8-direction sheets for the player and the
  three enemy types (`assets/characters/dirs/*.png`): profile views, three-quarter views and back views (face and
  the player's cross disappear, enemy 2's ponytail swings behind her head). It is placeholder quality; re-run the script
  after changing the source art, or replace the sheets with hand-drawn ones that use the same layout.
- `DirectionalFacing` turns step by step: reversing direction plays through the in-between directions
  (south > southwest > west > northwest > north takes about 0.14 s), so it looks like turning around.
- Used for idle, walk and sprint. Sprint uses your side-run frames for east/west and the walk frames for the rest.
- Not directional (still side-view with a left/right flip): the sword swing, the AK-47 animations and enemy 2's throw,
  because those sheets only contain side views.
- Enemy sheets are set in `EnemyStats.direction_sheet`, the player's on the player node (`direction_sheet`).

## Bottle (right mouse button)
- Throws a glass bottle toward the mouse (up to `bottle_range` = 190 px). It shatters on the first enemy it hits
  (damage 20 x your damage multiplier, small knockback), on a wall or house, or where it lands.
- A shatter spawns glass shards, water droplets and a `WaterSplash`: 11-17 single water pixels in a random pattern inside
  a 15 px circle, plus a small puddle in the middle. The water stays about 5 s, then fades. It is decoration only for now.
- Cooldown is `bottle_cooldown` on the player (1 s), shown in the HUD. The Background now has z_index -10 so the
  water lies on the ground, below characters.
- There is no throw animation (the sheet has none); the bottle just leaves the player's hand position.

## Upgrade window
- Opens at the start of every wave from wave 2 on (`upgrade_menu_from_wave` on the spawner, 0 = never) and pauses the game
  (wave timer, enemies and everything else stop) until you press Continue.
- Spend coins on 5 stats (max oxygen, oxygen regeneration, move speed, damage, armor) and 4 abilities (sprint efficiency,
  bottle cooldown, teleport cooldown, sword reach). Costs rise per level, e.g. damage 6, 9, 14, 22, 35, 54.
- Add an upgrade: one entry in `ui/upgrade_catalog.gd` plus a case in `_apply_upgrade()` in `player.gd`.
- The teleport cooldown (Q) is now a countdown instead of a timer, so it no longer runs while the game is paused.
