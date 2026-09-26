"""The augment content pass (2026-09-26): 31 new cards and one keystone.

Writes each card's .tres into scratch/new_cards/, and a JSON of the icon
prompts into scratch/new_cards/icons.json. Nothing touches game/ here.
"""
import json
import os

OUT = r"C:\Users\Hamed\AppData\Local\Temp\claude\E--Arxangel-GameDev-BeastRoad\19c67aba-492a-46b1-b9b8-c51fb20d916f\scratchpad\new_cards"
os.makedirs(OUT, exist_ok=True)

WARDEN, RAMPART, HEARTH = 0, 1, 2
RARITY_WORD = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# id, name, branch, tags, key, magnitude, rarity, first_act, text, icon prompt
CARDS = [
    # --- Warden -----------------------------------------------------------------
    ("honed_edge", "Honed Edge", WARDEN, ["Finisher"], "hero_damage", 0.06, 0, 1,
     "Ten strokes a side on the whetstone, every night, whatever the night was like.",
     "a sword blade resting across a small grey whetstone, oil drops"),
    ("the_oathblade", "The Oathblade", WARDEN, ["Finisher"], "hero_damage", 0.26, 3, 7,
     "It was sworn on before it was ever swung, and it remembers.",
     "an ornate longsword with a glowing golden inscription along the blade"),
    ("deep_breath", "Deep Breath", WARDEN, ["Mana"], "mana_regen", 0.12, 0, 1,
     "In for four, hold for four, out for four. The well fills while you count.",
     "a small glass vial of swirling pale blue mist, cork stopper"),
    ("wellspring_draught", "Wellspring Draught", WARDEN, ["Mana"], "mana_regen", 0.30, 2, 4,
     "Drawn from a spring the old maps do not mark. It tastes of cold stone.",
     "a round flask of bright glowing blue liquid with a leather strap"),
    ("ink_of_the_road", "Ink of the Road", WARDEN, ["Mana", "Area"], "spell_power", 0.12, 1, 2,
     "Every word written in it lands a little harder than it was said.",
     "an open inkpot of glowing violet ink with a quill standing in it"),
    ("the_loud_word", "The Loud Word", WARDEN, ["Mana", "Area"], "spell_power", 0.22, 2, 4,
     "Some spells are cast. This one is shouted.",
     "a rolled parchment scroll crackling with violet arcane sparks"),
    ("grand_incantation", "Grand Incantation", WARDEN, ["Mana"], "spell_power", 0.30, 3, 7,
     "Four pages long, and every page is a door.",
     "a thick open spellbook with glowing violet runes rising from its pages"),
    ("pack_bond", "Pack Bond", WARDEN, ["Summon"], "companion_damage", 0.16, 1, 2,
     "It fights harder when it knows you are watching.",
     "a braided leather collar with a carved wooden wolf-tooth charm"),
    ("the_alphas_due", "The Alpha's Due", WARDEN, ["Summon"], "companion_damage", 0.28, 2, 5,
     "The first bite is always the spirit's. It has earned that much.",
     "a large curved beast fang bound with red cord, faint green spirit glow"),
    ("iron_lungs", "Iron Lungs", WARDEN, ["Ward"], "hero_max_hp", 0.14, 1, 2,
     "Walking the whole road hardens something in the chest.",
     "a dented steel breastplate with a leather harness"),
    ("hard_road_boots", "Hard-Road Boots", WARDEN, ["Movement"], "hero_speed", 0.12, 1, 3,
     "Resoled three times and still the best pair on the beast's back.",
     "a pair of worn brown leather travel boots with iron-shod soles"),
    ("legends_heart", "Legend's Heart", WARDEN, ["Ward"], "hero_max_hp", 0.40, 4, 9,
     "Whoever wore it last walked the whole road. It has not forgotten how.",
     "a glowing golden heart-shaped amulet on a heavy chain, warm radiance"),
    # --- Rampart ----------------------------------------------------------------
    ("oiled_gears", "Oiled Gears", RAMPART, ["Tower", "Haste"], "tower_rate", 0.05, 0, 1,
     "A drop of fat on every axle and the whole wall turns quicker.",
     "a small brass cog wheel dripping with dark oil, an oil can beside it"),
    ("double_crews", "Double Crews", RAMPART, ["Tower", "Haste"], "tower_rate", 0.09, 1, 2,
     "One loads while the other looses. Nobody sleeps, but nothing waits.",
     "two crossed wooden loading rammers tied with rope"),
    ("the_drill_sergeant", "The Drill Sergeant", RAMPART, ["Tower", "Haste"], "tower_rate", 0.14, 2, 4,
     "Faster. Again. Faster than that.",
     "a battered brass whistle on a cord with a leather-bound drill book"),
    ("sharpened_stakes", "Sharpened Stakes", RAMPART, ["Trap"], "trap_damage", 0.10, 0, 1,
     "An afternoon with a knife and a bundle of green wood.",
     "a small bundle of sharpened wooden stakes tied with twine"),
    ("caltrop_masters", "Caltrop Masters", RAMPART, ["Trap"], "trap_damage", 0.18, 1, 3,
     "They learned it from a road that was trying to kill them. So did you.",
     "a leather pouch spilling iron caltrops"),
    ("the_killing_ground", "The Killing Ground", RAMPART, ["Trap"], "trap_damage", 0.30, 2, 5,
     "Every step on this stretch was placed by somebody who hated them.",
     "a heavy iron bear trap with jagged teeth, snapped open"),
    ("pitch_and_tar", "Pitch and Tar", RAMPART, ["Fire", "Tower"], "burn_damage", 0.40, 2, 5,
     "It sticks, and then it burns, and then it keeps burning.",
     "a small wooden bucket of black bubbling pitch with a flame on its surface"),
    ("frostbitten_iron", "Frostbitten Iron", RAMPART, ["Frost", "Tower"], "slow_strength", 0.40, 2, 5,
     "Left out on the Glass Fields for a week. It never quite warmed up.",
     "an iron chain link covered in frost and small ice crystals"),
    ("masterwork_arsenal", "Masterwork Arsenal", RAMPART, ["Tower"], "tower_damage", 0.30, 3, 7,
     "Every bolt, every stone, every shot, made by the best hands on the road.",
     "a rack of finely crafted crossbow bolts with gilded fletching"),
    ("rampart_of_legend", "Rampart of Legend", RAMPART, ["Tower", "Ward"], "tower_armour", 0.35, 3, 6,
     "Old stone from a wall that held when nothing else did.",
     "a single ancient carved stone block with a glowing blue rune"),
    ("the_storm_coil", "The Storm Coil", RAMPART, ["Storm", "Tower"], "chain_targets", 2.0, 3, 8,
     "Wound on the Iron Steppe during a storm nobody else survived.",
     "a copper wire coil crackling with bright white-blue lightning"),
    ("the_great_gate", "The Great Gate", RAMPART, ["Town", "Ward"], "town_max_hp", 0.35, 3, 7,
     "Oak from the Rustwood, iron from the Steppe, and a promise from everyone behind it.",
     "a massive iron-banded wooden gate door with a heavy ring handle"),
    # --- Hearth -----------------------------------------------------------------
    ("tithe_collector", "Tithe Collector", HEARTH, ["Economy"], "kill_resources", 0.25, 1, 2,
     "Whatever the road leaves lying, somebody counts it.",
     "a small leather coin purse with gold coins spilling out"),
    ("full_granary", "Full Granary", HEARTH, ["Economy", "Town"], "resource_rate", 0.25, 1, 2,
     "A good harvest carried on the beast's back is a harvest that travels.",
     "an overflowing burlap sack of golden grain"),
    ("the_caravan_road", "The Caravan Road", HEARTH, ["Economy", "Road"], "resource_rate", 0.40, 2, 4,
     "Traders follow the beast now. They pay well to walk in its shadow.",
     "a small wooden merchant cart loaded with crates and bundles"),
    ("hagglers_knack", "Haggler's Knack", HEARTH, ["Economy", "Tower"], "build_cost", -0.20, 2, 4,
     "The mason wanted forty. He left with thirty and thanked you for it.",
     "a hand-balance scale with a gold coin on one side and a stone on the other"),
    ("quick_muster", "Quick Muster", HEARTH, ["Road"], "raid_charge", 0.50, 2, 5,
     "Horn once, and the raiding party is already at the gate.",
     "a curved horn of polished bone with a red war banner tied to it"),
    ("long_sight", "Long Sight", HEARTH, ["Road"], "wave_foresight", 2.0, 2, 6,
     "From the top of the beast you can see the next two storms coming.",
     "a brass spyglass extended, with a small leather map"),
    ("the_beasts_stride", "The Beast's Stride", HEARTH, ["Road"], "beast_speed", 0.25, 2, 5,
     "Yuri knows the road home. Let him walk it.",
     "a huge stone-grey beast footprint pressed into earth with scattered moss"),
]

# The keystone that closes the Hearth branch.
KEYSTONES = [
    ("mortar_on_the_march", "Mortar on the March", HEARTH, ["Town", "Road"],
     "keystone_mortar", 2, 3, 6,
     "Every rank the road deals, the wall is mended as a load of timber would mend it.",
     "a mason's trowel and a small tub of wet mortar with a stone brick"),
]


def tres(card_id, name, branch, tags, key, magnitude, rarity, first_act, text,
         keystone=False, branch_needs=0):
    lines = [
        '[gd_resource type="Resource" script_class="RoadCardData" format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/resources/road_card_data.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        "branch = %d" % branch,
        "tags = Array[String]([%s])" % ", ".join('"%s"' % t for t in tags),
    ]
    if branch_needs:
        lines.append("branch_needs = %d" % branch_needs)
    lines += [
        'effect_id = "%s"' % key,
        "effect_magnitude = %s" % repr(float(magnitude)),
    ]
    if rarity:
        lines.append("rarity = %d" % rarity)
    if first_act != 1:
        lines.append("first_act = %d" % first_act)
    lines.append('card_text = "%s"' % text)
    if keystone:
        lines.append("keystone = true")
    lines += [
        'id = "%s"' % card_id,
        'display_name = "%s"' % name,
        'description = "%s card. %s"' % (RARITY_WORD[rarity], text),
        "",
    ]
    return "\n".join(lines)


icons = {}
for (card_id, name, branch, tags, key, magnitude, rarity, first_act, text, prompt) in CARDS:
    open(os.path.join(OUT, card_id + ".tres"), "w", encoding="utf-8", newline="\n").write(
        tres(card_id, name, branch, tags, key, magnitude, rarity, first_act, text))
    icons[card_id] = prompt
for (card_id, name, branch, tags, key, rarity, first_act, needs, text, prompt) in KEYSTONES:
    open(os.path.join(OUT, card_id + ".tres"), "w", encoding="utf-8", newline="\n").write(
        tres(card_id, name, branch, tags, key, 1.0, rarity, first_act, text, True, needs))
    icons[card_id] = prompt
json.dump(icons, open(os.path.join(OUT, "icons.json"), "w"), indent=1)
print(len(CARDS), "cards,", len(KEYSTONES), "keystones")
