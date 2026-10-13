# NPC system, factions, needs, stores, wave event

Not tested in the Godot editor (static checks: 83 classes, 88 scripts, 0 problems; numbers verified by simulation).
Open the project once and check the Output panel. The enemy system was renamed (see "Rename"); older notes
(ENEMIES_AND_WAVES.md etc.) still use the old names.

## Keys
E = use the object you stand at (store entrance, faction storage) | G = eat | B = drink | T = upgrades and shop |
F11 = fullscreen. Developer menu (ESC > Developer): new tabs Events, Factions, Needs.

## Wave event (the old wave system)
- `events/wave_event.gd` (`WaveEvent`, based on `GameEvent`). OFF by default. Start / stop: Developer > Events.
- While it runs: every non-unique NPC is hostile to the player (`Relations.event_all_hostile`), enemies spawn in waves,
  the hourglass and wave counter exist (they are created on start and removed on stop), the shop is restocked each wave.
- Its NPCs (`is_event_npc`) drop by RARITY (the drop tables). Normal NPCs drop what they carry (coins, food ...).
- When it stops its NPCs disappear. Normal NPC spawning pauses while it runs.
- `event_npcs_get_hungry` (export, default true): with the rarity doubling a mythical event NPC starves after about
  2-3 minutes (it cannot eat). Set false to keep event NPCs from getting hungry.
- The upgrade window (T) no longer belongs to the spawner: main.gd creates it.

## Rename: enemy -> npc
Folder `npc/`, classes NpcCharacter / NpcAI / NpcManager / NpcStats / NpcBehavior / NpcProjectile / NpcTouchHitbox,
group "npc", scenes `npc/scenes/npc_basic|npc_woman|npc_speeder.tscn`. Art files keep their names (enemy1_dirs ...).

## Factions and relations (`factions/`)
- Factions: emergency, police, military, civilian, animal, cult, church, gang1, gang2, gang3, demon, holy, alien, unique.
- Faction points -100..100. Friendly at 25 or more, hostile at -25 or less (my choice, `Relation`).
- Action weights (`ActionWeight`): angelic +20, holy +10, good +5, nice +2, somewhat good +1, neutral 0, rude -1,
  hostile -5, evil -10, demonic -50. Use `Relations.apply_action(faction, weight)`.
- Player hits a peaceful NPC: hostile (-5) with its faction. Kills it: evil (-10) on top. Hostile NPCs: no penalty.
  After 5 hits a faction is hostile to the player. An attacked NPC always fights back for 12 s.
- Unique NPCs (an NpcStats with a `unique_id`): always neutral to all factions, own points with the player
  (`Relations.unique_points`), only the player changes them. None are placed yet.
- Faction against faction (`Relations.HOSTILE_PAIRS` / `FRIENDLY_PAIRS`, my defaults, edit freely): e.g. police vs gangs
  and cult, gangs vs each other, church and holy vs demon and cult, military vs alien and demon; police, emergency,
  civilian and church are friendly with each other in part. Everything else is neutral.

## NPCs
- NpcStats: faction, unique_id, npc_type (light / medium / heavy / special), goals, starting coins and food.
- Needs: hunger. Rate per minute: light 2, medium 3, heavy 4, special 0, doubled per rarity step. At 0: 5 damage per second,
  -50 % speed, -50 % melee damage. NPCs eat food they carry when hunger is below 40.
- Goals (`NpcGoal`, evaluated once a second): hunger above x, has food, has coins, health above x, no enemy nearby, a friend
  nearby, near home. 0 unfulfilled = happy, 1-2 unrest, 3-4 unhappy, 5+ depressed. Mood only changes behavior: unhappy NPCs
  notice enemies from farther away, depressed ones hardly react, only happy / unrest NPCs share food.
- Behavior: hostile (by relation) -> chase and fight, also NPC against NPC; hungry without food -> walk to the nearest
  food source (store entrance, own faction's storage) and get food; friendly NPCs give spare food to hungry friends.
- Population (`npc/npc_population.gd`): keeps about 24 NPCs around the player, spawns off screen, removes far ones.
  Factions by weights (animal, demon, holy, alien: 0, no art), mostly common, 10 % uncommon, 3 % rare.
- A faction label above every NPC (green friendly, gray neutral, red hostile; toggle in Developer > General). Ordinary common
  NPCs have no rarity label or glow.

## Player needs
- Hunger 100, 20 per minute (the table; earlier you also wrote 10, one number in `needs/npc_type.gd`): 5 minutes to empty.
  Thirst 100, 10 per minute. HUD: sandwich with more and more bites, beer mug that empties and refills, in front of the coin
  counter and the bottle.
- Mood from thirst: 80-100 happy (+20 % speed), 50-79 unrest, 10-49 unhappy (-10 %), 0-9 depressed (-40 %).
- Eating / drinking uses items from the inventory (G / B). Sandwich restores 40, beer 20 (my numbers).

## Abilities (`abilities/player_abilities.gd`)
Health regeneration and "stamina regeneration while sprinting / jumping" are locked. Unlock with
`player.abilities.unlock(PlayerAbilities.HEALTH_REGEN)` (switches in Developer > Needs). The health-regeneration shop upgrade
only shows once it is unlocked. Without the stamina ability stamina regenerates only while walking or standing; with it, regen
(10/s) beats sprint drain (6/s), so sprinting becomes unlimited.

## Inventory, stores, economy
- `Inventory` (player, NPCs, stores, factions), `ItemDatabase` (id -> item; new items go into its PATHS),
  `FactionInventories` (one shared inventory per faction), `FactionStorage` (the object where it is reached, friendly
  factions only for the player; NOT placed on the map yet).
- Items: sandwich (2 coins) and beer (1 coin), 16 x 16 icons, category NEED.
- `ItemEconomy`: change values while the game runs: `set_price(id, n)`, `set_restore(id, x)`,
  `category_price_multiplier[ItemData.Category.NEED] = 1.5`, `global_price_multiplier`. Developer > Needs has sliders.
- Gas stations: `GasStation036` and `GasStation038` (Building036 / 038, the beige shops with the striped awning), entrance zone
  on the south side. E opens the shop. Hungry NPCs shop there too.
