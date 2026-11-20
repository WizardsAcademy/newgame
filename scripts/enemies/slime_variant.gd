extends RefCounted
class_name SlimeVariant
## The slime FAMILY: one shared 12-pose rig, four creatures.
##
## WHY A DATA TABLE AND NOT FOUR SCRIPTS
##   Every variant is the *same* slime with different numbers and one extra
##   beat (acid pool / ember fuse / spiked body). Four subclasses would have
##   copied the whole chase-lunge state machine four times. Here the AI stays
##   in one place (`slime.gd`) and this file only answers two questions:
##
##     1. "What are this slime's stats and which row of the sheet is it?"
##        -> get_data(id)
##     2. "Which slime should wave N spawn?"  -> pick_for_wave(N)
##
## THE SHEET
##   assets/textures/slime.png holds 24 frames per variant (built by
##   tools/make_slime_sprites.py):
##       row 2i     : the 12 coloured poses
##       row 2i + 1 : the 12 white hit-flash silhouettes
##   `row` below is `i`, i.e. the row PAIR index. Frame maths lives in
##   slime_visuals.gd, nowhere else.
##
## THE DESIGN RULES (docs/SLIME_VARIANTS.md)
##   * every variant carries a silhouette feature, never colour alone
##   * exactly one new mechanic per variant
##   * the red tremble telegraph is never removed, only extended
##   * everything is answerable with walk / punch / dash

# ---------------------------------------------------------------------------
# Mechanics the slime AI knows how to run (see slime.gd `_mechanic`)
# ---------------------------------------------------------------------------
enum Mechanic {
	NONE,             # plain chase + lunge (grass)
	ACID_POOL,        # dies into a damaging puddle on the floor
	EMBER_FUSE,       # detonates shortly after death
	CONTACT_DAMAGE,   # the body itself hurts on touch (basalt spikes)
}

const DEFAULT_ID: String = "grass"

## `hp` / `speed` / `damage` / `telegraph` are MULTIPLIERS applied on top of
## whatever the wave spawner already added (same ordering the Elite helper
## uses for its 3x HP, so variants and elites stack predictably).
const DATA: Dictionary = {
	"grass": {
		"name": "Grass Slime",
		"tag": "Slime",          # used in node names / logs
		"row": 0,
		"hp": 1.0,
		"speed": 1.0,
		"damage": 1.0,
		"telegraph": 1.0,
		"mechanic": Mechanic.NONE,
		"contact_damage": 0,
		"goo": "6EC866",
	},
	"acid": {
		"name": "Acid Slime",
		"tag": "AcidSlime",
		"row": 1,
		"hp": 1.25,
		"speed": 0.9,
		"damage": 1.0,
		"telegraph": 1.15,
		"mechanic": Mechanic.ACID_POOL,
		"contact_damage": 0,
		"goo": "965CC6",
	},
	"ember": {
		"name": "Ember Slime",
		"tag": "EmberSlime",
		"row": 2,
		"hp": 0.75,
		"speed": 1.15,
		"damage": 0.9,
		"telegraph": 0.85,
		"mechanic": Mechanic.EMBER_FUSE,
		"contact_damage": 0,
		"goo": "D46020",
	},
	"basalt": {
		"name": "Basalt Slime",
		"tag": "BasaltSlime",
		"row": 3,
		"hp": 1.6,
		"speed": 0.75,
		"damage": 1.25,
		"telegraph": 1.3,
		"mechanic": Mechanic.CONTACT_DAMAGE,
		"contact_damage": 4,
		"goo": "666E76",
	},
}

## Spawn weights for the SLIME SLOT ONLY. Archers and golems keep their own
## rolls in wave_spawner.gd; when a slime is picked, this table decides which
## slime it is. Entries are ordered by `from_wave`; the last matching row wins.
##
## The curve is deliberately gentle: one new creature every ~3 waves, and the
## grass slime never disappears (it is the visual baseline everything else is
## read against). Frost / Splitter / Void slots are still folded into basalt
## until those variants ship (Phase V2/V3).
const WAVE_TABLE: Array = [
	{"from_wave": 1, "weights": {"grass": 100}},
	{"from_wave": 3, "weights": {"grass": 70, "acid": 30}},
	{"from_wave": 6, "weights": {"grass": 50, "acid": 25, "ember": 25}},
	{"from_wave": 9, "weights": {"grass": 40, "acid": 20, "ember": 25, "basalt": 15}},
	{"from_wave": 12, "weights": {"grass": 30, "acid": 20, "ember": 25, "basalt": 25}},
	{"from_wave": 18, "weights": {"grass": 20, "acid": 20, "ember": 30, "basalt": 30}},
]


## Every variant id, in sheet order.
static func ids() -> Array:
	return DATA.keys()


## The full data dictionary for one variant (empty {} when unknown).
static func get_data(id: String) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	return {}


## Row pair of `assets/textures/slime.png` this variant draws from.
static func row_for(id: String) -> int:
	return int(get_data(id).get("row", 0))


## Node-name / log tag ("Slime", "AcidSlime", ...).
static func display_tag(id: String) -> String:
	return String(get_data(id).get("tag", "Slime"))


## Goo colour (particles, death splat) for one variant.
static func goo_color(id: String) -> Color:
	var raw: String = String(get_data(id).get("goo", "6EC866"))
	return Color(raw)


## The weights that apply to a given wave (never empty: wave 1 is grass only).
static func weights_for_wave(wave: int) -> Dictionary:
	var chosen: Dictionary = {"grass": 100}
	for entry in WAVE_TABLE:
		if wave >= int(entry["from_wave"]):
			chosen = entry["weights"]
	return chosen


## Sum of the weights that apply to a wave (handy for tests and tooling).
static func total_weight(wave: int) -> int:
	var total: int = 0
	for key in weights_for_wave(wave):
		total += int(weights_for_wave(wave)[key])
	return total


## Roll one variant id for a wave. Wave 1 always answers "grass".
static func pick_for_wave(wave: int) -> String:
	var weights: Dictionary = weights_for_wave(wave)
	var total: int = 0
	for key in weights:
		total += int(weights[key])
	if total <= 0:
		return DEFAULT_ID

	var roll: float = randf() * float(total)
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return String(key)
	return DEFAULT_ID
