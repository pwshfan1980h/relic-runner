# Relic Runner — TODO

Ideas accepted for later. Each needs a design pass before building.

## Water
- [x] **Research spike: water in general.** Done and prototyped: see [spikes/water.md](spikes/water.md)
      (water volumes, spring surface, refraction, buoyancy, swimming, wading depths, air, drowning,
      piranhas and a caiman). Proven in the testbed's water course.
- [ ] **Water in the campaign.** Add `pool`/`river` segments to `tools/build_maps.py` (with bot
      `swim_to`/`climb_out` steps) and use them: flooded mine tunnels, the Drowned Temple's lower halls,
      jungle river crossings with piranhas and caimans.
- [ ] **Generate the cutscenes with Sonnet 5.5.** `pip install anthropic`, set credentials, run
      `python3 tools/gen_cutscenes.py`; review the JSON (the checked-in ones are hand-written stand-ins).
- [ ] **Water polish.** Caustics, blood clouds in water (Gore), the whip being slow underwater, grenade
      shockwaves with bubbles, the hero's hat floating off on a long dive.
- [ ] **Underwater level (campaign chapter).** A fully submerged level: the hero swims horizontally,
      propelled by kicking their feet (a flutter-kick swim cycle on the rig, body laid flat, arms
      forward), in a wetsuit with diving gear (mask, tank, air hose) and underwater weapons: a speargun
      (slow, arcing bolts, reload per shot), a dive knife for melee, and depth charges instead of
      grenades. Bandits in shoddy, patched diving gear (leaking helmets trailing bubbles, rusty tanks,
      mismatched flippers) who panic when their air runs out. Needs: air meter, currents, darkness
      with depth, sunken wreck set dressing, wetsuit/diving palettes for the hero rig and bandits.
      Depends on the water spike.

## Vehicle set pieces (the pulp-serial chase scenes)
- [ ] **Motorcycle chase.** A side-scrolling run on a sidecar motorcycle along a canyon road: lean
      forward/back to jump ramps, shoot or whip pursuing bandits, duck under low rock arches. Rig pose
      for riding; the bike as a RigidBody2D with wheel joints on the level's slopes.
- [ ] **Landing a plane.** A short piloting sequence: a sputtering biplane over the jungle, trimming
      pitch and throttle to set down on a river sandbar or a too-short airstrip. Physics lift/drag
      model, crash-and-retry at a checkpoint.
- [ ] **Speedboat run.** Down a jungle river pursued by Crane's launches: steer between rocks and
      logs, jump wakes, throw grenades astern. Builds on the water spike (surface, buoyancy, wakes).

## Carried over
- [ ] Voice barks for the named cast (Hattie, Tomás, Nico, Itzel, Ortiz, Crane).
