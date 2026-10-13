# Auto attack, bullets, teleport damage, regeneration, HUD, shop

Not tested in the Godot editor. Open the project once (registers the new classes), then check the Output panel.

## Auto attack (ESC > Options > "Auto attack")
Off by default, saved with the other options. When on and you do not hold the rifle, the sword swings by itself at the
nearest enemy whose center is inside the sword's reach (`attack_range`, 20 px + upgrades). The player turns toward that
enemy for the swing; the normal sword cooldown (0.8 s) still applies. Clicking still works as before.

## AK-47: total bullets instead of magazines
- One bullet pool, **max 300** (`max_ammo` on `weapons/ak47_weapon.gd`). Every pickup (or shop purchase) adds 30; the first
  one equips the rifle. A full rifle refuses further pickups (the shop shows "Full").
- The reload is gone: no reload, no R key use, no reload animation. When the last bullet is fired the rifle is thrown away
  after the short delay (a pickup during that delay saves it).
- The HUD shows `AK-47: bullets / 300`.

## Teleport damage
Q now damages every enemy within `teleport_radius` (20 px) of the arrival point: `teleport_damage` (30, multiplied by your
damage multiplier) plus `teleport_knockback` (20 px), with a burst and an expanding ring showing the radius. The amount was
not specified, so 30 is my choice; change the three exports in the "Teleport" group of the player. A refused teleport (into a
house) deals no damage.

## Regeneration
- **Health regenerates 2 per second**, stamina 10 per second (the previous rate). Both are in the developer menu
  (ESC > Developer > **Player** tab) and live-adjustable; "Reset all to defaults" restores them.
- Shop upgrades add on top: new **Health Regeneration** (+1/s per level) next to Stamina Regeneration (+2/s).

## HUD
- **Bottom left:** health bar (red) and stamina bar (yellow) with their numbers inside. Active buffs (speed boost, shield,
  damage boost) are listed directly above the bars and the list grows upward.
- **Bottom right:** coins, bottle cooldown, rifle bullets and hints.
- The optional FPS counter moved to the top-left so it does not overlap.

## Upgrade window and shop (start of every wave from wave 2)
- **Stats** only: Max Health, Max Stamina, Health Regeneration, Stamina Regeneration, Move Speed. Armor, Damage and the
  whole Abilities section were removed (their code is still in the player, they are just not for sale).
- **Shop:** a centered box under the stats with 4 randomized offers, drawn with replacement from the weapons and the health
  pack (`ui/shop_catalog.gd`; currently AK-47 and Health Pack, so duplicates are common). A new set is rolled every wave.
  - AK-47 costs **5 coins** (+30 bullets), Health Pack **2 coins** (+30 health).
  - **Prices double with every enemy rank-up**: waves 1-5 x1, waves 6-10 x2 (AK-47 10, Health Pack 4), 11-15 x4, 16-20 x8,
    21+ x16. The window shows the current multiplier.
  - A button shows "Full" when the item would be wasted (full health, rifle at 300 bullets) and "Sold" after buying.
- Add something to the shop: one entry in `ENTRIES` in `ui/shop_catalog.gd` (an ItemData resource and a base price).
