class_name Item
extends RefCounted
## A generated treasure: kind, rarity, name and value all come from one seed, so the
## same seed always gives the same item (and the same icon, see ItemArt).

const KINDS := ["gem", "idol", "amulet", "dagger", "scroll", "skull", "key"]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]
const RARITY_COLORS := [Color("#d8d0c0"), Color("#6ad04a"), Color("#4aa0ff"), Color("#ffa020")]
const BASE_VALUE := {"gem": 12, "idol": 20, "amulet": 15, "dagger": 14, "scroll": 8, "skull": 10, "key": 6}
const RARITY_MULT := [1, 4, 15, 60]

const MATERIALS := [
	["Tarnished Brass", "Chipped Clay", "Worn Copper", "Cracked Bone", "Dented Tin"],
	["Silver", "Carved Jade", "Polished Bronze", "Turquoise"],
	["Gold", "Obsidian", "Ivory", "Lapis"],
	["Sunstone", "Starmetal", "Blood Gold", "Crystal"],
]
const GEM_ADJ := ["Cloudy", "Clear", "Flawless", "Burning"]
const PAPER_ADJ := ["Faded", "Illuminated", "Gilded", "Sacred"]
const GEMS := ["Ruby", "Emerald", "Sapphire", "Topaz", "Opal", "Amethyst"]
const NOUNS := {
	"idol": ["Idol", "Figurine", "Effigy"],
	"amulet": ["Amulet", "Medallion", "Pendant", "Talisman"],
	"dagger": ["Dagger", "Kris", "Sacrificial Knife"],
	"scroll": ["Map Fragment", "Scroll", "Codex Page"],
	"skull": ["Skull", "Mask", "Totem"],
	"key": ["Key", "Seal"],
}
const EPITHETS := ["of the Serpent King", "of the Sun Cult", "of the Drowned Temple", "of the Jaguar Priest",
		"of the Lost Expedition", "of Seven Winds", "of the Red Canyon", "of the First Dynasty"]

var seed := 0
var kind := "gem"
var rarity := 0
var name := ""
var value := 0
var material := ""  # drives the icon palette
var gem := ""


## Rarity roll: luck shifts the odds up (tough enemies, bosses).
static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0, minimum := 0) -> int:
	var r := rng.randf() * (1.0 - luck * 0.5)
	var rarity := 0
	if r < 0.012:
		rarity = 3
	elif r < 0.08:
		rarity = 2
	elif r < 0.3:
		rarity = 1
	return maxi(rarity, minimum)


static func generate(p_seed: int, luck := 0.0, min_rarity := 0, p_kind := "") -> Item:
	var it := Item.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	it.seed = p_seed
	it.kind = p_kind if p_kind != "" else KINDS[rng.randi() % KINDS.size()]
	it.rarity = roll_rarity(rng, luck, min_rarity)
	var mats: Array = MATERIALS[it.rarity]
	it.material = mats[rng.randi() % mats.size()]
	it.gem = GEMS[rng.randi() % GEMS.size()]
	if it.kind == "gem":
		it.name = "%s %s" % [GEM_ADJ[it.rarity], it.gem]
	elif it.kind == "scroll":
		# Paper, not metal: scrolls get their own adjectives.
		var nouns: Array = NOUNS["scroll"]
		it.name = "%s %s" % [PAPER_ADJ[it.rarity], nouns[rng.randi() % nouns.size()]]
	else:
		var nouns: Array = NOUNS[it.kind]
		it.name = "%s %s" % [it.material, nouns[rng.randi() % nouns.size()]]
	if it.rarity >= 2:
		it.name += " " + EPITHETS[rng.randi() % EPITHETS.size()]
	it.value = BASE_VALUE[it.kind] * RARITY_MULT[it.rarity] + rng.randi_range(0, 5) * (it.rarity + 1)
	return it


func color() -> Color:
	return RARITY_COLORS[rarity]


func to_dict() -> Dictionary:
	return {"seed": seed, "kind": kind, "rarity": rarity, "name": name, "value": value}
