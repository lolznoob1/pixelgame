# Health and stamina, mouse aiming, pause menu, developer settings

Not tested in the Godot editor. Open the project once (registers the new classes, imports the new PNG), then check the
Output panel.

## Health and stamina
- Oxygen is now **stamina**. A new **health** pool (red bar, stamina is the yellow one below it, numbers in the HUD text).
- **Enemies damage health only**: attack hits (melee and shoes) and the contact drain. The contact drain keeps its old
  formula (threat 2 = 5 per second, doubling per extra threat), now applied to health (`contact_drain_base`). It no longer
  gives stamina back; stamina regenerates by itself (`stamina_regen_rate`) unless you are sprinting.
- **Stamina** is used by sprinting and the jump attack. It cannot kill you. The game over now happens at 0 health
  (`player.died` signal, `main.gd` updated).
- Items: the oxygen tank became the **Stamina Drink**; new **Health Pack** (placeholder sprite, `HEALTH` effect). Both are in
  the enemy drop tables. Upgrades: Max Health, Max Stamina, Stamina Regeneration (+ the old ones, armor now reduces
  damage to health). Armor, shield and invulnerability frames work as before.

## Teleport
Q is refused if the target (plus the player's body) would overlap a house: nothing happens, the cooldown is not used, and
"Can't teleport into a house" shows in the HUD for 1.5 s.

## Facing the mouse
- **AK-47 equipped:** the character turns (8 directions, step by step) toward the mouse. Aiming mostly sideways or
  diagonally uses your rifle animations as before (they are side views, flipped left/right). Aiming mostly up or down shows
  the turned back / front body with a rifle sprite pointing at the mouse (behind the body when aiming up, in front when
  aiming down, with recoil and a shake while reloading).
- **Left mouse button (sword)** and **right mouse button (bottle)** turn the player toward the mouse. The sword's 180
  degree arc now points at the mouse (`aim_with_mouse` is on by default).

## AK-47 bullets
Hitbox doubled: 10 x 2 px became 20 x 4 px (`weapons/bullet.tscn`).

## Pause menu (ESC)
- **Resume**, **Options**, **Exit**, **Developer**. ESC in a sub screen goes back; ESC on the main screen resumes. It is
  ignored while the upgrade window or the game over screen is open.
- **Options:** fullscreen, VSync, show FPS, master volume. Saved to `user://settings.cfg` and applied at startup once saved.
- **Exit** closes the game immediately.

## Developer screen (ESC > Developer)
All changes apply live. The spawner's inspector values are the defaults ("Reset all to defaults" restores them). The values
survive "Restart" after a game over, but not closing the game.
- **General:** show / hide the enemy rarity labels.
- **Spawner:** chance of enemy 1 / 2 / 3 (relative weights, normalized), enemies and variants in wave 1, growth per wave
  (2 = doubling), waves until rank-up, restart counts after a rank-up, wave duration, spawn spread, max living enemies.
- **Rarity:** "Random extra rank" (off by default): every normal enemy additionally rolls +0 to +4 ranks with the given
  weights, on top of the wave rank.
- **Drops:** multipliers for coin chance / amount and for all pickups' chance / amount, plus a chance multiplier for each
  pickup type (health pack, stamina drink, speed boost, damage boost, shield, AK-47). Chances are capped at 100 %; amounts
  are rounded randomly (1.4 x of 1 item = 1, with a 40 % chance of a second).
