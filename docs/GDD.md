# Relic Runner — game design (working title)

A 90s-style cinematic platformer in the vein of *Prince of Persia*, *Flashback* and
*Another World*, starring a fedora-wearing relic runner with a bullwhip, a revolver and a
satchel of grenades. The story campaign is in [STORY.md](STORY.md); ideas queued for later are in
[TODO.md](TODO.md).

## Pillars
1. **Weighty, rotoscope-fluid movement.** Momentum matters: runs skid to a stop, turns
   pivot, a running jump clears gaps a standing jump can't. Ledges are grabbed and climbed.
   Hills slow you going up and speed you coming down.
2. **The whip is the traversal tool.** R lashes the whip at the cursor: wrap an anchor and
   swing across chasms, or yank an enemy (or crate) toward you.
3. **The revolver is deliberate.** Hold right mouse to raise it and aim; left mouse fires. From
   the hip, a shot is a slower, looser quick-draw. Six rounds, a deliberate reload (X).
4. **Physics is at play.** Grenades bounce, roll downhill and stop in the dirt; blasts throw crates,
   corpses and other grenades; dead trees fall across chasms when kicked.
5. **Attention follows the mouse.** The head tracks the cursor. Aiming (or standing still), the
   hero faces it; otherwise the hero faces the way they're going, gun arm hanging and swinging.

## Controls
| Input | Action |
|---|---|
| A / D | Walk (Shift held: run; not while aiming) |
| Space | Jump; while running, long jump; while swinging, let go |
| W | Climb a ledge you're hanging from; reel in the whip |
| S | Drop from a ledge; pay out the whip |
| Right mouse (hold) | Raise the revolver and aim (walks slower) |
| Left mouse | Fire. Aimed: precise. From the hip: quick-draw (arm snaps up, shot goes, some spread) |
| R | Whip: swing on an anchor / yank a whippable target / crack |
| Q | Grenade. Tap: lob at 45° the way you face. Hold: aim along a predicted arc through the cursor, release to throw |
| X | Reload |
| C | Crouch (bandit bullets fly over you); Ctrl too on desktop |
| E | Punch (press again for a jab/cross combo). Next to a friendly character: talk |
| F | Front kick (launches enemies, fells dead trees, cracks walls); jump kick in the air |
| Tab / I | Satchel (loot) |
| In deep water | A/D/W/S swim (S dives, otherwise you float up to tread water), Shift swims faster, Space kicks out of the water at the surface, pushing into a bank grabs it |
| Esc / P | Pause: resume, how to play, options, restart chapter, quit to title |

## Flow
Boot (web: click to begin) → **intro film** (skippable) → **title screen** (Continue / New Game /
How to Play / Options / Credits) → chapter card → level → end-of-chapter summary → **camp** with Tomás
(sell treasure, buy upgrades, read journal pages) → the next chapter's **intro cutscene** (in-engine,
scripted in `assets/cutscenes/*.json`, written by Claude Sonnet 5.5 via `tools/gen_cutscenes.py`;
ESC skips; restarting a chapter skips it) → … → epilogue → title. No level select:
test rooms are reachable with `-- --map <id>`.

## Look
- 480×270 internal resolution, nearest-neighbour upscale, hero ~32px tall.
- Characters are **flat-shaded polygon cut-outs on a bone rig** (the Another World approach):
  2–3 tones per part, far-side limbs tinted darker, no outlines. The named cast are palette swaps of
  the same rig.
- **Real-time sky** (`scripts/world/sky.gd`): a shader sky whose clock runs while you play (one game
  hour per minute) through afternoon, golden hour, sunset, dusk and night: sun and glow, moon, stars,
  sun-lit cloud streaks. Backdrop silhouettes are calm flat-toned layers tinted by the same light and
  hazed toward the horizon colour by distance. The playfield's ambient light follows the sky.
- Tiles: limited palette with dithering only at tone transitions (no speckle). Slopes of any gradient
  are drawn with the same rock and a pixel-stepped crust.
- Type: pixel fonts only, at 8/16/32px so they stay crisp: Tiny5 for body text, Pixelify Sans for
  titles and menus (`UI.setup_fonts()` makes Tiny5 the default everywhere).
- Wind: every rig's jacket hem hangs on a spring bone and the hat tips; both answer the level's
  gusting breeze plus the air of the character's own motion (running streams the coat back, falls lift
  it). Canyon is breezy, the jungle nearly still, caves calm.
- Lighting: caves drop the ambient very low (torches, lanterns and muzzle flashes carry them; the
  hero's eyes adjust a little). Explosions flash and cast shadows.
- Melee: fists and boots leave air-cutting smears along their real path, and hits flash with a
  starburst. `tools/melee_check.gd` checks that each move's hitbox matches where the limb actually is.

## Hero animation set (all in `scripts/hero/hero_anims.gd`)
idle, idle fidget (hat tug), walk (and backpedal while aiming), run, skid, skid recovery, run-turn
pivot, standing jump, running long jump, fall, land, hard-landing roll, ledge hang, ledge climb,
whip swing, whip pull, reload, grenade throw (and wind-up hold), punches, kicks, crouch, hurt, death.
Walk and run swing both arms; aiming and head-look are layered live on top.

## Enemies
| Enemy | Biome | Behaviour | Whip | Takes |
|---|---|---|---|---|
| Scorpion | Canyon | Tail sting up close | Flips it over | 1 hit (crouch-punch it) |
| Rattlesnake | Canyon | Rattles, then lunges | Yanks it out | 1 hit |
| Bandit | Both | A glint, then a rifle shot | Pulled off his feet | 2 hits, or 1 headshot |
| Machete bandit | Both | Closes in, raises the blade, chops | Pulled off his feet | 2 hits |
| Brute | Both | Two-punch combo, then a barge | Only staggers him | 5 hits; kicks, ledges and grenades help |
| Attack dog | Both | Packs; barks, leaps to bite | Runs off yelping | 2 hits |
| Attack llama | Canyon | Spit at range, rear kick up close | Charges you, furious | 4 hits |
| Jaguar | Jungle | Stalks, crouches, pounces | Runs off | 3 hits |
| Stone Idol Guardian | Jungle | Raises its arms, slams, shockwave | Too heavy | Only its glowing glyph (shots or a blast) |

Grenades: 4/2/1 damage by distance, line of sight only, launch and stun survivors, tear limbs off
the dead. They hurt the hero too.

## Level pieces
| Piece | Map | How it plays |
|---|---|---|
| Slopes | `/` `\` | A run of N on a row climbs one tile over N tiles: 45°, 27°, 18°, 14°… |
| Dead tree / pillar | `Y` (stacked) | Kick it (F) and it falls the way you kicked, landing across the chasm as a bridge (crushing what it lands on). Punches only rock it. |
| Cracked rock | `%` (stacked) | Three kicks (two with Hobnail Boots) or one grenade. Also loose flagstones hiding fragments. |
| Relic fragment | `*` | Three per chapter, hidden high, under loose stones, or deep in a swing's arc. |
| NPC / story trigger | `N` / `!` | Talk with E; triggers play once as you pass. |
| Grenade crate | `g` | +2 grenades, once. |
| Water | `~` `,` | Knee-deep (`,`) slows you a little; waist-deep (`~`) stops running and cuts the jump; chest-deep (`,~`) is a slog, and you haul yourself out by grabbing the bank; deeper, you swim. |
| Piranha / caiman | `p` / `A` | Water predators: piranhas dart in and nip; the caiman floats eyes-up and lunges at swimmers and at anyone at the water's edge. Both suffocate if knocked onto land. |
| Anchors, spikes, crumbling floors, gates and plates, checkpoints, torches, lanterns, signs | as before | See the legend in `scripts/world/maps.gd`. |

## Loot and progression
Enemies drop coins, bandages (heal 1), grenades and treasure by loot table (tough enemies are luckier;
the Guardian always drops a legendary idol). Each item comes from a seed: kind, rarity, material,
name, value and a procedural icon. Treasure sells to Tomás at camp, where gold buys upgrades
(Lined Stetson, Bandolier, Speed Loader, Long Whip, Hobnail Boots). Relic fragments unlock journal
pages and, all 18, the secret epilogue. Progress saves at every chapter start and purchase.

## Music
Composed and synthesised in-house by `tools/gen_music.py` (pure Python, no samples): warm wavetable
pads, Karplus-Strong nylon guitar, marimba, breathy flute, soft bass, hand drums, shaker and taiko,
with a looped stereo reverb and gentle saturation. Nine seamless loops: title, intro, canyon, mesa,
mine, jungle, temple, boss, camp.

## Campaign levels
Generated from segment lists by `tools/build_maps.py`, which writes the ASCII maps
(`scripts/world/campaign_maps.gd`) **and** a matching bot route (`scripts/game/campaign_routes.gd`),
so every level is provably finishable. Numbers the builder designs around: a ledge up to 3 tiles is
grabbed, a running long jump clears 4 tiles comfortably, a swing anchor 10 rows over the lip carries you
over a 14-tile chasm, a kicked tree bridges 6 tiles, a gate stays open 7s.

1. *Dry Gulch* (canyon, afternoon to sunset): every basic, plus the tree bridge, the whip, grenades and cracked rock.
2. *Rattler Mesa* (sunset to dusk): a climb up the mesa over ledges, slopes and a high swing.
3. *The Silver Mine* (night): lantern-lit tunnels, bandit ambushes, gates, crumbling floors, swings over shafts.
4. *Canopy Run* (dawn): chained swings, jaguars, a pillar bridge, ruined steps.
5. *The Drowned Temple* (inside): spikes, crumbling floors, timed gates, sealed passages.
6. *The Idol Chamber*: the Guardian fight, then the escape out into the sunset.

## Tech
Godot 4.7.2 (gl_compatibility), web export to GitHub Pages. Art, audio and music are generated by
`tools/gen_art.py`, `tools/gen_audio.py` and `tools/gen_music.py`; campaign maps by
`tools/build_maps.py`. The play-through bots must pass at real speed: `tools/run_bots.sh` (arena
enemy checks, the mechanics testbed, the proving grounds and all six chapters).
Screenshots for review: `-- --bot --map <id> --shot <dir>` or `-- --snap <dir> [--every s] [--count n]`;
`-- --hour <h>` overrides the time of day.
