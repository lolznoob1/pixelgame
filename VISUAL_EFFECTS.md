# Hourglass, jump and teleport effects, enemy glow, green stamina

Not tested in the Godot editor. Open the project once (registers the new classes), then check the Output panel.

## Hourglass (replaces the "WAVE n" text, top right)
- `ui/hourglass_view.gd` draws a pixel-art hourglass (13 x 26 art pixels, drawn 3x), `ui/wave_hud.gd` drives it.
- The wave starts with the top chamber full. The sand trickles through the neck (animated stream) and the pile grows in the
  bottom chamber. When the top is empty and the bottom is full, the glass **turns 180 degrees** and the sand is on top again.
- **Timing:** the turn takes 6 % of the wave duration (min 0.6 s, max 3 s, never more than half the wave), so it scales when
  you change the wave duration (also live in the developer menu). The sand runs for the rest of the wave and the turn
  *ends exactly when the next wave starts*. For the default 30 s that is 28.2 s of sand plus a 1.8 s turn, so the glass
  finishes turning as the new wave begins. Tune `flip_fraction`, `min_flip_time`, `max_flip_time` on `WaveHud`.
- The art is point-symmetric: the turned glass with all the sand at the bottom is pixel-identical to a fresh glass with the sand
  on top (verified), so the turn flows seamlessly into the next wave.
- The text (wave number, countdown, enemy rank) is gone. The wooden caps are tinted with the current enemy rank color, and
  `show_wave_number` on `WaveHud` brings back a small wave number under the glass.

## Jump (superhero take-off)
At take-off, on the ground under the player: two expanding **air pressure rings**, dust blown outward and a puff pushed up, and
**random cracks** in the ground (6-9 crooked cracks with some side branches, drawn pixel by pixel, spreading from the middle,
fading after about 6 s; new random pattern every jump, like the water splash). The circle is the size of the jump's knockback
zone: the radius is read from the `JumpAttackArea` collision shape, so it stays correct if you edit that shape. While in the air
the player has a ground shadow that shrinks as it rises, and a small dust puff plays on landing.

## Teleport
The character is **sucked into the center of its sprite** (shrinks to a point while spinning once, glows, particles are pulled in).
Then it is moved to the target and **the same animation plays backwards** there (grows back, spins back), with the burst and ring
of the arrival damage (`teleport_radius`). Durations: `teleport_out_time` / `teleport_in_time` (0.18 s each). While teleporting the
player has no control and cannot be hurt.

## Enemy rarity shade
Every enemy now has a soft colored light on the ground under it (common gray, uncommon green, rare blue, legendary orange,
mythical purple); stronger and a bit larger for higher rarity (`enemy/rarity_glow.gd`). The sprite tint was also made stronger
(40 % to 50 %). The glow can be switched off in ESC > Developer > General.

## Stamina drink and bar
The Stamina Drink sprite is now green (the old blue art, hue-shifted), and the stamina bar uses the same green
(`STAMINA_COLOR` in `player.gd`, `Color(0.298, 0.914, 0.380)`).
