# Spike: water

**Question:** what would it take to add water to Relic Runner (pools, rivers, flooded temple rooms,
and eventually a fully underwater chapter and a speedboat run), and how should we build it?

**Short answer:** it's very doable in Godot 4 with the current architecture. Build it as **water
volumes** (rectangles from the map grid) that own three things: a **spring-mesh surface** for looks
and splashes, a **buoyancy/drag field** for physics bodies, and a **swim state** on the hero (and a
"wet" reaction on enemies). Start with shallow/deep pools in existing biomes; the underwater chapter
and the boat come after, on the same foundation.

**Status: prototyped.** The prototype is built and runs in the testbed (`-- --map testbed`): a knee,
waist and chest-deep ford, then a deep pool with a rock to dive under, piranhas, a caiman and a floating
crate. The bot swims it end to end. Results are in §8.

---

## 1. How water fits the existing systems

| System | What water needs | Notes |
|---|---|---|
| **Maps** (`build_maps.py`, ASCII) | A new cell, `~`. Contiguous `~` cells merge into rectangles; the top row is the surface. | Same approach as `dark` rects. The builder gets `pool(w, depth)` and `flood()` segments. |
| **Rendering** | Surface line, body tint, refraction wobble, caustics, splash particles, underwater darkening. | See §2. The whole look stays flat and banded to match the art. |
| **Lighting** | Water gets darker with depth; torches don't work underwater (fish-oil lanterns / glowing algae do). | Reuse the cave ambient blend (`Level._dark_w`) with a depth factor. |
| **Hero** (CharacterBody2D) | A `SWIM` state: floating motion, drag, buoyancy, 8-way swimming, surface treading, climbing out at edges, an air meter. | §3. `motion_mode = MOTION_MODE_FLOATING` while swimming avoids floor/wall logic. |
| **Rig / animation** | Tread water (upright, arms sculling), swim (body laid horizontal, flutter kick from the hips, arms forward/breaststroke), dive, climb out. | The rig already supports whole-body rotation (`hr`, used by rolls); swimming is a 90° body lean plus a leg cycle. |
| **Rigid bodies** (grenades, crates, ragdolls) | Buoyancy by density plus heavy drag. Crates float, grenades sink slowly, bodies bob. | §4. Area2D damping alone isn't enough: it doesn't know the submerged fraction. |
| **Enemies** | Land enemies: slow wade in shallows, drown/flee in deep water. Water enemies: divers (the underwater chapter), eels, piranha schools, crocodiles. | Base `Enemy` gets an `in_water` flag and a `_swim()` fallback. |
| **Weapons** | Revolver: short range, slow bubble-trail "tracer", no ricochet. Whip: slow and short underwater (drag). Grenades: fuse still burns, blast is a bigger, fireless shockwave with bubbles. | Speargun and depth charges are the underwater chapter's kit (see TODO). |
| **Gore** | Blood becomes diffusing clouds, not droplets and stains. | New `Gore.cloud()`: cheap alpha blobs that spread and fade. |
| **Audio** | Underwater muffling, bubbles, splash sizes, surface lapping loop. | An `AudioEffectLowPassFilter` on the SFX and Music buses, faded in while the camera is submerged. |
| **Camera / screen** | Tint and wobble below the surface line. | One full-screen canvas shader keyed to the surface's screen Y. |

## 2. Rendering options

1. **Spring-mesh surface (recommended).** One column spring every 4px along the surface; neighbours
   spread motion (the classic 2D water model). Splashes are impulses to nearby springs. Draw the body
   as a single polygon from the spring heights, with 2–3 flat colour bands and a bright 1px lip. Cost is
   trivial (tens of springs per pool).
2. **Refraction and tint** through a canvas shader reading the screen (`hint_screen_texture`, supported
   in the Compatibility renderer): offset UVs by a slow sine (a few pixels, in whole pixels to stay
   crisp), tint toward the water colour by depth. Cheap on the web build, but it needs one
   `BackBufferCopy` per water region: confirm the cost in the prototype.
3. **Caustics:** a scrolling, posterised noise texture multiplied onto the floor and back wall inside
   the volume. Optional polish.
4. **Rejected:** particle/SPH fluids (expensive, uncontrollable, wrong look), and tile-animated water
   (can't react to splashes).

## 3. Swimming controller (hero)

- **Entering:** when the chest point enters a volume deeper than ~20px, switch to `SWIM`; shallower
  water just slows walking (wading, splashes on steps).
- **Physics:** gravity scaled to about 0.15 and buoyancy pushing toward a neutral depth. Strong linear
  drag (about 3/s). Input accelerates in 8 directions. SHIFT is a power kick (burst plus stamina).
- **Surface:** at the top, tread water (head above the line, breath restored); SPACE jumps out if a
  ledge is within reach (reuse `_find_ledge` with the swim pose's hand height).
- **Air:** a meter of about 12s that drains while the head is under; refills at the surface or at air
  pockets / diving-bell air. Empty means damage ticks, then drowning (the ragdoll floats up).
- **Facing:** swimming faces the movement direction; aiming (RMB) turns the body to the cursor, as on
  land.
- **Anims:** `tread`, `swim` (0.7s flutter cycle, body rotated so the hero lies along the velocity),
  `dive`, `climb_out`.

## 4. Buoyancy for physics bodies

Per water volume, each physics tick, for each overlapping RigidBody2D:
`submerged = clamp((surface_y - (body_y - r)) / (2r), 0, 1)`,
`force = -gravity * mass * submerged * (1 / density)`, plus drag `-v * k * submerged`.
Densities: crate 0.6 (floats), ragdoll parts 0.95 (bobs just under), grenade 2.5 (sinks, slowly). Use
`Area2D` only to find overlaps, and apply forces ourselves. The built-in Area2D gravity override is
all-or-nothing and would make crates hover mid-pool.

## 5. Where water shows up in the game

- **Near term (existing biomes):** flooded mine tunnels (dive under a low rock to progress), the
  Drowned Temple's lower halls (flooded rooms; kick a pillar into the water as a raft), jungle river
  crossings with crocodiles, a canyon waterhole.
- **Underwater chapter** (TODO): builds on everything above plus the diving kit (wetsuit, mask, tank,
  speargun, dive knife, depth charges) and bandit divers in leaky gear.
- **Speedboat run** (TODO): a boat is a RigidBody2D riding the spring surface (buoyancy points at bow
  and stern); pursuit boats; wakes are spring impulses. Needs a long, scrolling river volume.

## 6. Recommendation and plan

1. **Prototype (2–3 days):** `WaterVolume` node (spring surface + buoyancy + tint), a `~` map cell, and
   a hero `SWIM` state with placeholder anims, in the testbed. Confirm: screen-texture shader cost on
   web, the spring-surface look at 480×270, and swim feel.
2. **Integrate (about a week):** air meter and HUD, splashes and audio muffling, rig swim/tread
   animations, enemy wading/drowning, weapon rules underwater, gore clouds, bot helpers (`swim_to`)
   and a testbed route.
3. **Content:** flooded rooms in Chapters III and V; then the underwater chapter; then the boat.

**Risks:** the swim feel (needs iteration; keep it fast and forgiving). Bot routes through water need
new steps. Screen-texture refraction on low-end browsers (fallback: tint only). Grenade and ragdoll
buoyancy tuning.

## 7. Prototype checklist (to confirm this spike)

- [ ] `hint_screen_texture` refraction runs at 60fps in the web export with 3 pools on screen.
- [ ] Spring surface reacts to the hero, a grenade and a crate; looks right at pixel scale.
- [ ] A crate floats, a grenade sinks, a ragdoll bobs, with the §4 formula.
- [ ] Swim controller: enter, dive, surface, climb out, air meter.
- [ ] Underwater low-pass fades in and out cleanly as the camera crosses the surface.

## 8. Prototype results

Built: `scripts/world/water.gd` (volume, spring surface, refraction shader, buoyancy), the hero's
`SWIM` state and graded wading in `scripts/hero/hero.gd`, `swim`/`tread` clips, water-aware enemies
(wading, drowning, bodies float up), `Piranha` and `Caiman`, the air meter, underwater low-pass on
the audio buses, splash/gasp sounds, and `Fx.droplets` / `Fx.bubbles`.

- [x] Refraction via `hint_screen_texture` works in the Compatibility renderer (desktop). **Web still to
      be measured.**
- [x] Spring surface reacts to the hero, crates and grenades. First pass was too bouncy; now heavily
      damped (K 110, damping 9), waves capped at 3px (or a third of the depth), splashes softened.
- [x] Buoyancy by density: the crate floats, grenades sink, corpses bob; drag stops bodies bouncing.
- [x] Swimming: enter by falling or walking in, float up to tread water, dive with S, lie along the
      stroke with a flutter kick, 10s of air (bubbles on the HUD), gasp on surfacing, climb out by
      grabbing the bank (the bank should be a tile above the water line). The water absorbs most of a
      fall on entry.
- [x] Depths: a half-full cell (`,`) makes knee-deep water possible on the 16px grid.
- [x] Pools draw a rock back wall like caves, so water never floats in front of the sky.
- [ ] Web export performance with several pools on screen.

Lessons: a script error doesn't always stop the bot, so `tools/run_bots.sh` now fails any run that
logs one.
