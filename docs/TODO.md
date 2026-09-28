# Relic Runner — TODO

Ideas accepted for later. Each needs a design pass before building.

## Water
- [ ] **Research spike: water in general.** See [spikes/water.md](spikes/water.md) for findings and the
      recommended approach (water volumes, surface rendering, buoyancy for rigid bodies, swimming
      controller, what it does to the whip, guns, grenades and enemies).
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
- [ ] A proper pixel font for titles and dialogue (currently the engine fallback font).
