# Death explosions, HUD, camera / fullscreen, new drops, T key for upgrades

> **Update:** the death animations and the coin text of this file were changed later, see `WEAPON_CLASSES_DEATH_COIN.md`
> (explosion only for heavy weapons, a bloody corpse for light weapons, spinning coin counter).


Not tested in the Godot editor. Open the project once (registers the new classes and imports the new PNGs), then
check the Output panel. This file supersedes the older notes about the upgrade window opening at the start of a wave.

## Death: everybody explodes into red goo
- **All four characters** (player, enemy 1, 2, 3) have their own 8-frame death animation (`assets/characters/death/*_death.png`,
  48 x 48 per frame, generated from each character's own sprite by `tools/make_death_art.py`): the sprite flashes white,
  swells and cracks, bursts with a white-hot core, chunks of the character fly out (in its own colors), a goo cloud grows and
  breaks up, and a puddle forms.
- On top of the animation: flying goo chunks, droplets and a dark mist (particles), and a pixel-pattern puddle that stays on
  the ground (`GooSplat`, random every time like the water splash, fades after ~18 s). At most 80 puddles exist at once, the
  oldest disappear, so big waves stay fast.
- **Enemies** explode instantly when killed (after their drops are rolled). Higher rarity = bigger and wetter. The sheet is
  `EnemyStats.death_sheet`, so a new enemy type just needs its own sheet.
- **Player:** explodes, and the game over screen comes `death_delay` = 1 s later (export `death_sheet`, `death_delay`). The
  explosion is bigger than the enemies'.

## HUD
- **Wave counter** "WAVE n" under the hourglass (`show_wave_number` on `WaveHud`, now on by default).
- **Secondary ability gauge** (bottom right) replaces the "Bottle: ..." text: a glass bottle that fills with water as the
  cooldown runs down (empty right after the throw, full = ready, with a little pop when it is ready again). The water
  rises in whole pixels, with a lighter line at the surface.
- **Replaceable for other characters:** `ui/ability_gauge.gd` is generic. The player's exports in the group "Secondary ability"
  (`secondary_icon_empty`, `secondary_icon_full`, `secondary_fill_top`, `secondary_fill_bottom`, `secondary_name`) pick the
  art; any two same-sized textures work, plus the rows where the fill is.
- The bottom right also shows "[T] Upgrades & Shop".

## Camera and fullscreen
- The project starts **fullscreen** (`display/window/size/mode`). **F11** toggles it anywhere, also in Options.
- `world/camera_fit.gd` is on the camera. It picks the zoom so that **one art pixel is a whole number of screen pixels**
  (5x at 720p, 7x at 1080p, 9x at 1440p, 14x at 4K) and about 154-160 world pixels are visible vertically, so the picture
  stays sharp and the view stays about as big as before (at 1080p it is practically your old zoom 4.21; the old fixed zoom
  gave 7.017 screen pixels per art pixel, which is uneven). Ultrawide (21:9, 32:9) shows more world to the sides, it never
  stretches. It re-fits when the window changes. The HUD is anchored to the screen edges and scales with the stretch mode.

## New drop system (death drops depend on the enemy's RARITY)
Tables: `items/drops/drops_common.tres ... drops_mythical.tres` (edit them in the editor). A table can pick exactly ONE
outcome ("single choice", weights, with "nothing") or roll every entry independently, and can limit the total number of pickups.

| Rarity | Drops |
|---|---|
| Common | max 1 item: coin 50 %, AK-47 10 %, health pack 5 %, stamina drink 5 %, nothing 30 % |
| Uncommon | max 1 item: coin 50 %, AK-47 20 %, health pack 5 %, stamina drink 5 %, nothing 20 % |
| Rare | 2 coins (100 %), AK-47 30 %, health pack 25 %, stamina drink 25 %, ability core 2 %. At most 5 pickups |
| Legendary | 3 coins (100 %), AK-47 50 %, rocket launcher 5 %, health pack 50 %, 1-2 stamina drinks 50 %, ability core 5 %. At most 7 |
| Mythical | 10 coins (100 %), 1-3 AK-47 50 %, 1-2 rocket launchers 10 %, 1-5 health packs 100 %, 1-5 stamina drinks 100 %, ability core 7 %. At most 15 |

I tested the tables with 200,000 simulated kills each: the percentages match, the limits hold, rare always gives exactly 2 coins
(except the 0.04 % case below) and mythical always at least 10.
- **The limit:** if the roll gives more pickups than allowed, extras are removed at random, but never below an entry's own
  minimum (so "10 coins" stays 10). Only if the minimums alone exceed the limit (rare with everything at once = 6 pickups)
  coins go first. For mythical this means the 1-5 health packs / stamina drinks are trimmed to about 2 each on average, because
  10 coins + the rest would exceed 15.
- **Ability core** ("ability item" in your list; a new pickup, placeholder sprite): permanently shortens the cooldowns of the
  bottle and the teleport by 10 % per core (minimum 0.25 s / 0.5 s) and resets them immediately. You did not say what an
  ability item does, so this is my interpretation; the effect is `ItemData.Effect.ABILITY`, easy to change in `player.gd`
  (`_apply_ability_core`).
- The old per-type tables and the 30 % coin drop when an enemy is only hurt are gone (the new rules say "only one item" and
  a total limit per rarity). Hurt drops still exist as a feature (`EnemyStats.hurt_drops`) but nothing uses it.
  `EnemyStats.death_drops` still overrides the rarity table for a specific enemy type.
- Rocket launchers now only drop from Legendary and Mythical enemies. The developer menu (Drops tab) has a slider for the
  ability core too.

## Upgrade window on the T key
- It no longer opens or pauses by itself at the start of a wave. **T** opens it (the game pauses while it is open), **T or ESC**
  closes it. It does not open while the pause menu is open or you are dead.
- The shop **restocks when a new wave starts** (new random offers, prices follow the enemy rank), including wave 1; if you buy
  something it shows "Sold" until the next wave. The stats do not change.
