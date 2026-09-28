# Relic Runner — Story Bible

*Status: v1 campaign, as implemented. Dialogue lives in `scripts/story/story.gd`; level layouts in
`tools/build_maps.py`. This document is the "why" behind them.*

## Logline

Arizona, 1936. A disreputable relic runner answers a late letter from their old mentor and races a
smuggler with a private army from the canyon country to a drowned jungle temple, where the Sun Idol
is guarded by something made of stone that has waited a thousand years to move.

## Tone and influences

Saturday-matinee pulp serial: cliffhangers, sunsets, bad men in good suits, ancient traps that still
work. Played straight but warm, with dry humour from the hero and the supporting cast. Violence is
cartoonish-gory (toggleable) and never cruel to the innocent. The game's visual tone tracks the story:
each chapter starts at a time of day that fits it, and the sky keeps turning while you play.

## Themes

- **Who does the past belong to?** Crane sells it; Ortiz studies it; Itzel's family lives with it. The
  ending gives the Idol back to the people it was taken from.
- **Mentor and student.** Rook was taught by Ortiz and has been disappointing her for years. Rescuing
  her is also earning back her respect.
- **Greed is a trap, literally.** Every temple mechanism is built to punish people who grab.

---

## Cast (personas)

### Ezra "Rook" Calloway — the hero
- **Role:** player character. Relic runner: part archaeologist, part courier, part trespasser.
- **Look:** battered fedora, brown leather jacket, khaki shirt and trousers, knee boots, bullwhip coiled
  on the hip, a six-shot revolver.
- **Personality:** laconic, quick, more careful than they look. Talks to themselves when alone (the
  in-level hint lines). Would rather crack a whip than fire a shot, but will do both.
- **Want / need:** wants to find Ortiz and beat Crane to the Idol; needs to prove they're more than a
  treasure hunter by giving the Idol up.
- **Arc:** takes the job for the old debt → realises what Crane intends → chooses to return the Idol.
- **Voice sample:** *"That dead tree's rotten at the root. One good kick and it'd make a bridge."*
- Pronouns deliberately unused in dialogue; players can read Rook however they like.

### Professor Maribel Ortiz — the mentor
- **Role:** the reason for the journey; captured midway; the voice of conscience.
- **Look:** pale pith-style hat, cream field jacket, grey-streaked hair.
- **Personality:** brilliant, stubborn, courteous to everyone except fools. Leaves a trail of journal
  pages because she knows Rook will follow.
- **Want:** to keep the Idol out of Crane's hands. **Secret:** she already suspects the Guardian was
  built to keep something *in*, not thieves out (the relic-fragment lore pays this off).
- **Voice sample:** *"The Idol... it's warm, Rook. Like it's been waiting."*

### Silas Crane — the antagonist
- **Role:** antiquities smuggler; employer of every bandit in the first half.
- **Look:** white suit, black hat with a red band, dark shirt. Always clean. Always somewhere else.
- **Personality:** charming, contemptuous, patient. Never fights in person; pays others to.
- **Want:** the Sun Idol, and through it control of the Guardian. **Weakness:** believes everything can
  be owned.
- **Arc in v1:** always one step ahead until the Idol Chamber; escapes downriver, setting up a sequel.
- **Voice sample:** *"Oh, keep the trinket, Calloway. It's a copy. The real Key went south on Tuesday."*

### Old Hattie — the prospector (Chapter I)
- **Role:** tutorial voice and first friendly face.
- **Look:** grey hat and coat, white hair, patched trousers.
- **Personality:** gruff, funny, fond of Ortiz. Knows the gulch better than anyone living.
- **Function:** teaches running, the long jump and the whip; gives a little gold.

### Tomás Aguilar — guide and outfitter (camp, all chapters)
- **Role:** mule driver hired by Ortiz; now works for Rook. The shopkeeper and the campfire voice
  between chapters.
- **Look:** wide straw sombrero with a red band, rust-red jacket, cream shirt.
- **Personality:** cheerful mercenary with a soft heart; complains about his mules; knows local legends.
- **Function:** buys treasure, sells upgrades, reads the journal pages unlocked by relic fragments.

### Nico — the miner's kid (Chapter III)
- **Role:** captive of the bandits; freed by the player.
- **Look:** small, bare-headed, blue jacket.
- **Personality:** brave, sharp, a little scared. His father worked the mine before Crane came.
- **Function:** tells Rook the Sun Key has been found; gives grenades and teaches the grenade throw.

### Itzel — keeper of the temple (Chapters IV–VI)
- **Role:** descendant of the temple's guardians; ally in the jungle.
- **Look:** teal tunic, gold sash, dark hair, bare-headed.
- **Personality:** calm, direct, unimpressed by outsiders. Trusts Ortiz; decides to trust Rook.
- **Function:** explains the Guardian's weakness (the glyph); the Idol is returned to her people at the
  end.

### The Guardian — the boss
- A walking stone idol with a chest glyph that kindles before it can be hurt. Bullets spark off it
  otherwise; grenades work only while the glyph burns. Its awakening is the intro film's last shot.

### Crane's gang (enemies)
- **Bandits** (rifles, a glint before each shot), **machete men**, **the Brute** (bandana, fists),
  **attack dogs**. In the jungle: **jaguars**. Wildlife everywhere: scorpions, rattlesnakes, llamas.

---

## The campaign

The intro film (skippable) sets up the letter, Crane and the Guardian. Then six chapters, each ending
at camp with Tomás.

| # | Chapter | Where / when | Story beat | New mechanic it teaches |
|---|---|---|---|---|
| I | **The Letter** (Dry Gulch) | Canyon, afternoon into sunset | Hattie: Ortiz went up the mesa; Crane's men followed. Tomás waits at the end. | Run, skid, ledges, long jump, aim-and-fire, tree bridge, whip swing, grenades on loose stones, cracked walls |
| II | **Rattler Mesa** | Climbing the mesa at sunset into dusk | Ortiz's journal page: the Sun Key sleeps in the Esperanza mine. From the top, lanterns at the mine. | A long climb: ledges, slopes, snakes, a swing high above the valley |
| III | **The Silver Mine** | Night; deep, lantern-lit tunnels | Free Nico; Rook cracks the paymaster's strongbox for the Sun Key, only for Crane to gloat from the dark that it's a copy: the real Key, and Ortiz, went south on Tuesday. | Darkness, bandit ambushes, timed gates, crumbling floors |
| IV | **Canopy Run** | Jungle at dawn | Meet Itzel: the Guardian and its glyph. | Chained swings, jaguars, pillar bridges |
| V | **The Drowned Temple** | Inside the sunken temple, noon | Ortiz's abandoned camp: "Don't let him use the Key." | Traps: spikes, crumbling floors, timed gates, sealed passages |
| VI | **The Idol Chamber** | The chamber, then the escape at sunset | Crane wakes the Guardian; Rook destroys it; Crane flees; Ortiz and the escape | Boss fight (glyph timing, grenades), escape run |

**Epilogue** (at camp): the temple sinks; the Idol goes back to Itzel's people; Crane is loose
downriver. With all 18 relic fragments, a secret coda: the reassembled Sun Disc maps a second temple
far to the north (sequel hook).

---

## Humour and running gags

The comedy comes from character, never from winking at the player:
- **Dolores**, Tomás's mule, bites everyone except the professor ("Dolores has taste"), sulks after the
  steamer, is "very brave" in the epilogue and wants a raise.
- **Hattie's tall tales**: her cousin the postman (why the letter took three weeks), her knees that
  "retired in '09", and *Fella's Bottom*, the spot where a fella let go of the rope at the bottom of
  the swing.
- **Rook's dry asides** on everything: the town sign, the snakes, Crane's voice, being "the company".
- **Crane's pomposity**: cigars too good to finish, a hotel in Tucson while his men dig at night,
  "a retirement plan", and treating the Guardian like a butler.
- **Crane's gang**: the bandit who doesn't know what a professor is, and the brute who thinks the boss
  is very smart.
- **Ortiz's exasperation**: every note she leaves Rook ends in a telling-off ("stop reading and RUN").
- **Itzel's deadpan**: "You are going to touch something shiny."

## Story sense check (fixed in this pass)

- **The Sun Key.** Previously Crane mocked Rook for holding the Key, yet put "the Key" in the altar in
  Chapter VI. Now the strongbox key in the mine is a decoy; the real one went south with Crane.
- **Who found the Key.** Nico says the gang found it an hour ago and the boss locked it in his
  strongbox; Rook opens the strongbox at the end of the chapter, so the beats line up.
- **Hattie's knowledge.** She knows Ortiz went up the mesa, which sets up Chapter II's journal page.

## Cutscenes

Every chapter opens with a short in-engine cutscene (`assets/cutscenes/<chapter>.json`) staged with the
game's own sky, rigs, props, fonts and dialogue box, so it always matches the game. They complement the
levels instead of repeating them: Hattie, Itzel and Crane's big entrance stay as in-level moments.
The scripts are written by **Claude Sonnet 5.5** via `tools/gen_cutscenes.py` (structured outputs
enforce the format; extra checks keep every beat stageable and in character). The versions currently
checked in are hand-written stand-ins in the same format, until the generator is run with API
credentials.

## Incentives and progression

- **Relic fragments (3 per chapter, 18 total).** Hidden three ways: on high rock shelves (jump, grab,
  climb), under loose flagstones (grenade them open), and low in a whip swing's arc (only a full,
  daring swing reaches it). Found fragments stay found across replays. Totals unlock **journal pages**
  at camp (3, 9, 15, 18) that reveal the Guardian's true purpose; all 18 unlock the secret epilogue.
- **Gold and treasure.** Enemies drop coins, bandages, grenades and procedurally named treasure (with
  rarity). Treasure is sold to Tomás at camp.
- **Upgrades from Tomás** (bought with gold): Lined Stetson (+1 health, x2), Bandolier (+1 grenade
  carried, x2), Speed Loader (faster reload), Long Whip (+25% reach), Hobnail Boots (cracked rock breaks
  in two kicks).
- **End-of-chapter summary:** time, foes bested, gold found, fragments, falls.
- **Save:** progress, gold, treasure, upgrades, fragments and conversation flags are saved at every
  chapter start and purchase; CONTINUE on the title screen resumes.

## Presentation

- **Intro film:** five in-engine shots (title card, the letter at sunset, Crane's gang by moonlight, the
  Guardian's eyes kindling at dawn, the whip-crack title slam), with a composed score that lands the
  theme on the slam.
- **Chapter cards** over black between the camp and the level.
- **Dialogue:** letterboxed box with an animated portrait (each character's own rig, framed on head and
  shoulders), name tag in their colour, typewriter text, E/SPACE to advance, ESC to skip.
- **Music:** every cue is composed and synthesised in-house (`tools/gen_music.py`): a heroic D-minor
  theme (title, boss), Phrygian desert guitar (Dry Gulch), sunset fingerpicking (the mesa), drones and
  lamp bells (the mine), marimba and hand drums (the jungle), taiko and glyph bells (the temple), and
  a campfire guitar for Tomás's camp.

## Open threads for later chapters

- Crane's buyer: who pays a smuggler that well?
- The second temple on the Sun Disc's back.
- Hattie knew Ortiz "before the war": what happened then?
- Vehicles and water set pieces are queued in `docs/TODO.md` (motorcycle chase, landing a plane,
  speedboat run, an underwater chapter).
