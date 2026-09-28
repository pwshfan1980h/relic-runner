class_name Story
extends RefCounted
## The campaign: the cast, the chapters in order, and every conversation.
##
## 1936. Ezra "Rook" Calloway, a relic runner of doubtful reputation, gets a letter
## from their old mentor, Professor Maribel Ortiz: she has found the trail of the Sun
## Idol, and so has Silas Crane, a smuggler who pays bandits in stolen gold. The trail
## runs from the canyon country, through a bandit-held silver mine, to a drowned temple
## in the jungle, where something made of stone is still guarding the Idol.
##
## Conversations are lists of [speaker id, line]. "rook" is the hero; "" is narration.
## NPCs in maps name a conversation; `after` conversations replay on later talks.

## id -> {name, color (name tag), swap (HeroRig palette), hat (false = bare head), scale}
const CAST := {
	"rook": {"name": "ROOK", "color": Color("#e8b070")},
	"hattie": {"name": "OLD HATTIE", "color": Color("#c8c0a8"), "scale": 0.95, "swap": {
		HeroRig.HAT: Color("#8a8070"), HeroRig.HAT_D: Color("#6a6254"), HeroRig.BAND: Color("#3a2a1a"),
		HeroRig.JACKET: Color("#5a6a7a"), HeroRig.JACKET_D: Color("#44505e"), HeroRig.JACKET_L: Color("#6e7e8e"),
		HeroRig.SHIRT: Color("#d8d0c0"), HeroRig.TROUSER: Color("#6a5a48"), HeroRig.TROUSER_D: Color("#4e4234"),
		HeroRig.SKIN: Color("#d8a078"), HeroRig.SKIN_D: Color("#a87a58"), HeroRig.HAIR: Color("#d8d8d0")}},
	"tomas": {"name": "TOMÁS", "color": Color("#e0a050"), "swap": {
		HeroRig.HAT: Color("#c8a860"), HeroRig.HAT_D: Color("#a08448"), HeroRig.BAND: Color("#a02828"),
		HeroRig.JACKET: Color("#b04a2a"), HeroRig.JACKET_D: Color("#86361e"), HeroRig.JACKET_L: Color("#d06a3a"),
		HeroRig.SHIRT: Color("#e8e0c8"), HeroRig.TROUSER: Color("#4a4238"), HeroRig.TROUSER_D: Color("#36302a"),
		HeroRig.SKIN: Color("#b87a4a"), HeroRig.SKIN_D: Color("#8a5a34")}},
	"nico": {"name": "NICO", "color": Color("#90c0e0"), "scale": 0.8, "hat": false, "swap": {
		HeroRig.JACKET: Color("#4a6a8a"), HeroRig.JACKET_D: Color("#36506a"), HeroRig.JACKET_L: Color("#5a7a9a"),
		HeroRig.SHIRT: Color("#e0d8c0"), HeroRig.TROUSER: Color("#6a5a4a"), HeroRig.TROUSER_D: Color("#4e4236"),
		HeroRig.SKIN: Color("#c08858"), HeroRig.SKIN_D: Color("#946438"), HeroRig.HAIR: Color("#201410")}},
	"itzel": {"name": "ITZEL", "color": Color("#80d090"), "hat": false, "swap": {
		HeroRig.JACKET: Color("#2a6a5a"), HeroRig.JACKET_D: Color("#1e4e42"), HeroRig.JACKET_L: Color("#3a8a74"),
		HeroRig.SHIRT: Color("#e8c040"), HeroRig.TROUSER: Color("#5a4a3a"), HeroRig.TROUSER_D: Color("#42362a"),
		HeroRig.SKIN: Color("#a86a40"), HeroRig.SKIN_D: Color("#7e4e2c"), HeroRig.HAIR: Color("#140c08"),
		HeroRig.BOOT: Color("#6a4a2a"), HeroRig.BOOT_D: Color("#4a3420")}},
	"ortiz": {"name": "PROF. ORTIZ", "color": Color("#f0d890"), "swap": {
		HeroRig.HAT: Color("#e0d4b0"), HeroRig.HAT_D: Color("#b8ac8a"), HeroRig.BAND: Color("#6a4a2a"),
		HeroRig.JACKET: Color("#c8b890"), HeroRig.JACKET_D: Color("#a09070"), HeroRig.JACKET_L: Color("#dccca4"),
		HeroRig.SHIRT: Color("#f0ece0"), HeroRig.TROUSER: Color("#8a7a5a"), HeroRig.TROUSER_D: Color("#6a5c42"),
		HeroRig.SKIN: Color("#c89068"), HeroRig.SKIN_D: Color("#9a6a48"), HeroRig.HAIR: Color("#5a5048")}},
	"crane": {"name": "SILAS CRANE", "color": Color("#d05050"), "swap": {
		HeroRig.HAT: Color("#18161a"), HeroRig.HAT_D: Color("#0c0b0e"), HeroRig.BAND: Color("#a02020"),
		HeroRig.JACKET: Color("#e8e4dc"), HeroRig.JACKET_D: Color("#bcb8b0"), HeroRig.JACKET_L: Color("#f8f6f0"),
		HeroRig.SHIRT: Color("#2a2a30"), HeroRig.TROUSER: Color("#d8d4cc"), HeroRig.TROUSER_D: Color("#aca8a0"),
		HeroRig.SKIN: Color("#e0b090"), HeroRig.SKIN_D: Color("#b08060")}},
	"": {"name": "", "color": Color("#c8b890")},
}

## The campaign, in order. hour: time of day at the start (the sky keeps turning).
const CHAPTERS := [
	{"map": "dry_gulch", "num": "CHAPTER I", "title": "The Letter", "hour": 15.2,
		"card": "Arizona, 1936. A letter from Professor Ortiz, three weeks late: \"I have found the Sun Idol's trail. So has Crane. Come quickly, and bring your whip.\""},
	{"map": "rattler_mesa", "num": "CHAPTER II", "title": "Rattler Mesa", "hour": 17.6,
		"card": "Ortiz's trail climbs to the old Spanish watchtower on the mesa. The sun is going down, and the snakes are coming out."},
	{"map": "bandit_mine", "num": "CHAPTER III", "title": "The Silver Mine", "hour": 21.0,
		"card": "Crane's hired guns have taken the Esperanza silver mine. Whatever Ortiz buried there, they're digging for it tonight."},
	{"map": "canopy_run", "num": "CHAPTER IV", "title": "Canopy Run", "hour": 5.8,
		"card": "Six days south by tramp steamer and mule. Dawn over the jungle, and somewhere beneath it, a temple the maps forgot."},
	{"map": "sunken_temple", "num": "CHAPTER V", "title": "The Drowned Temple", "hour": 11.0,
		"card": "The temple of the Sun has half sunk into the swamp. Ortiz went in two days ago. Crane went in after her."},
	{"map": "idol_chamber", "num": "CHAPTER VI", "title": "The Idol Chamber", "hour": 17.0,
		"card": "At the heart of the temple, the Sun Idol. And standing over it, the thing that has guarded it for a thousand years."},
]

const TALKS := {
	# --- Chapter I ---
	"hattie_hello": [
		["hattie", "Well, if it ain't a greenhorn in a good hat. You Maribel's runner? She said you'd come."],
		["rook", "She's here?"],
		["hattie", "Was. Went up the mesa with a map, a shovel, and a look on her face like she'd seen a ghost. Crane's boys went up the day after."],
		["hattie", "Mind the gulch. Run, then jump: a running jump clears what a standing one won't. Hold SHIFT to run."],
	],
	"hattie_after": [
		["hattie", "Still here? The trail's east. And take the long way round the snakes."],
	],
	"hattie_rope": [
		["hattie", "See that iron ring? Point at it and press R. The whip'll bite, and you swing. A and D to pump, SPACE to let go."],
	],
	"gulch_tree": [
		["rook", "That dead tree's rotten at the root. One good kick (F) and it'd make a bridge."],
	],
	"gulch_crane_sign": [
		["", "A fresh bootprint in the dust, and a cigar end: expensive, Cuban. Crane doesn't smoke anything cheaper."],
	],
	"tomas_camp1": [
		["tomas", "Rook! Tomás Aguilar, at your service. The professor hired me and my mules. Then she vanished, so now I suppose I work for you."],
		["tomas", "Gold buys gear. I trade in anything that shines. Come find me at camp between the hard days."],
	],
	# --- Chapter II ---
	"mesa_start": [
		["rook", "The watchtower's at the top. Jump at a ledge to grab it, then W to climb."],
	],
	"mesa_journal": [
		["", "A page from Ortiz's journal, pinned under a stone: \"The Sun Key sleeps in the Esperanza mine. The Idol will not wake without it. Crane must not have it.\""],
	],
	"mesa_top": [
		["rook", "Lights down in the valley. Lanterns, at the old mine. Crane's already digging."],
	],
	# --- Chapter III ---
	"mine_enter": [
		["rook", "Rifles glint before they fire. Hold C to duck under the shot, or hold RIGHT MOUSE to aim and shoot first."],
	],
	"nico_help": [
		["nico", "Hey! Hey, over here! They tied me up when I wouldn't dig. You gonna shoot me too?"],
		["rook", "Not today. What's your name?"],
		["nico", "Nico. My pa worked this mine before Crane came. There's a key they want: gold, shaped like the sun. They found it an hour ago."],
		["nico", "Take these, they dropped 'em. Pa says never throw one uphill. Tap Q to lob it, or hold Q to aim."],
	],
	"nico_after": [
		["nico", "Go on, get the key back! I'll find my own way out, I know every tunnel."],
	],
	"mine_wall": [
		["rook", "The rock's cracked here. Kicks might do it. A grenade would do it faster."],
	],
	"mine_key": [
		["crane", "(from the dark) Keep your little key, Calloway. I have the professor, and she knows the way. See you in the jungle."],
	],
	# --- Chapter IV ---
	"itzel_meet": [
		["itzel", "Stop. You are the one Ortiz spoke of. I am Itzel. My family has watched this temple for longer than yours has had a name."],
		["rook", "Then you know what's inside."],
		["itzel", "The Guardian. Stone that walks. Bullets are nothing to it. Only when the glyph on its chest burns can it be hurt."],
		["itzel", "The branches over the gorge will hold your whip. Swing, and let go at the top of the arc."],
	],
	"itzel_after": [
		["itzel", "The temple is east, past the gorge. Be quick. The jaguars hunt at dawn."],
	],
	"canopy_tree": [
		["rook", "Another rotten trunk. Kick it over the gap."],
	],
	# --- Chapter V ---
	"temple_enter": [
		["rook", "Spikes in the floor, plates in the stones. Somebody really didn't want visitors."],
	],
	"ortiz_camp": [
		["", "Ortiz's abandoned camp. A cold fire, a torn satchel, and a line scratched on the wall: \"He's taking me to the Idol. Don't let him use the Key.\""],
	],
	"temple_plate": [
		["rook", "The plate opens the gate, but not for long. Run."],
	],
	# --- Chapter VI ---
	"idol_crane": [
		["crane", "Right on time. The professor was just telling me how the Idol wakes."],
		["ortiz", "Rook, no! He's put the Key in the altar. The Guardian..."],
		["crane", "...answers to whoever holds the Idol. Which is about to be me. Kill them."],
	],
	"idol_after": [
		["ortiz", "You did it. The Guardian's gone, and Crane ran when it fell. The Idol... it's warm, Rook. Like it's been waiting."],
		["ortiz", "The chamber is coming down. The way out is east, over the pit. Go!"],
	],
}

## After the last chapter.
const EPILOGUE := [
	["", "The temple folded into the swamp behind them, and the jungle closed over it by morning."],
	["ortiz", "The Sun Idol belongs to Itzel's people. It goes back to them, not to a museum, and certainly not to Crane."],
	["rook", "And Crane?"],
	["ortiz", "Somewhere down river, with a bad temper and no Idol. We haven't seen the last of him."],
	["", "THE END ... for now."],
]

## Relic fragments: three hidden in every level. All of them restore the Sun Disc.
const FRAGMENTS_PER_LEVEL := 3

## Journal pages the outfitter shows at camp, unlocked per fragment total.
const LORE := [
	[3, "The Sun Disc was broken into eighteen pieces and scattered, so no one could wake the Guardian twice."],
	[9, "Ortiz's notes: the Guardian was not built to keep thieves out. It was built to keep something in."],
	[15, "The disc's rim is carved with a map. The Idol was never the treasure: it points somewhere else."],
	[18, "The Sun Disc is whole. On its back, a second temple, far to the north. Another adventure, another day."],
]


static func chapter_index(map_id: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i]["map"] == map_id:
			return i
	return -1


static func talk(id: String) -> Array:
	return TALKS.get(id, [])
