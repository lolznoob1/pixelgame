# Sword swing no longer locks the player, walking animations for weapons

Not tested in the Godot editor. Open the project once, then check the Output panel.

## Sword swing
- **Before:** while the swing animation played (about 0.5 s) the whole player update was skipped and the velocity was
  zeroed: no walking, sprinting, teleport, jump, bottle or weapon switch.
- **Now:** the swing is only an animation. While it plays you can
  - **move** (at `attack_move_factor` = 0.8 of your speed, an export on the player; set 1.0 for full speed. A swing at full
    run speed looks like sliding, which is why I made it a little slower),
  - **sprint, throw a bottle, teleport, jump, change weapon**.
  Teleport, jump and weapon change end the swing right away (they have their own animations). The swing's damage is dealt
  at the start of the swing as before, so cancelling it loses nothing. Being stunned still ends it.
- The swing animation keeps playing while you walk instead of being replaced by the walk cycle, and keeps the direction it
  was started in. It is a side-view animation, so while strafing you see the swing pose until it ends (about half a
  second), then the normal 8-direction walk takes over again.
- You still cannot start a second swing during a swing (there is also the 0.8 s sword cooldown).

## Walking with a weapon
- The AK-47 and the rocket launcher used the idle frames, sped up, while you walked. They now have real walk cycles:
  `walk_gun` and `walk_rocket` (4 frames, 8 fps, 1.6x faster while sprinting). The body bobs by one pixel and the boots step:
  wide stride, passing with one boot lifted, wide stride, passing with the other boot lifted. The robe hides the legs, so
  that is what you see of them.
- Idle still uses the idle frames; firing still plays the fire animation; aiming mostly up or down still uses the turned
  8-direction body with the weapon icon (that already had real walk animations).
- The art is generated from your idle frames by `tools/make_walk_art.py`
  (`assets/characters/player_walk_armed.png`, preview in `tools/previews/`).
- The sword has no visible weapon in the walk / idle animations (unchanged): it only appears in the swing.
