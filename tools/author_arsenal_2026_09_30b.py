"""Authors the Arsenal's third wave of weapons (2026-09-30, later the same day).

    python tools/author_arsenal_2026_09_30b.py

Owner, 2026-09-30: "Players should be able to collect and have even more
arsenal cards available in their capacity limit cap ... And also add even more
arsenal options and varieties and game juice to it all."

Twelve weapons, data only, each in a pattern and on an anchor the Arsenal
already fires from, in an element that pattern-and-anchor did not have yet. Each
is a **copy of a sibling** - the weapon of the same pattern and anchor named in
`clone` - with its own name, element, tint, words and hit picture, so its
mechanics, its power and its model are exactly the sibling's: `arsenal_check`
measures it as it measures the sibling, and `curve_report`'s best hand is the
hand it already was. What the wave adds is choice.

Writes `game/data/arsenal/<id>.tres` and `game/data/road_cards/<id>.tres`.
Re-running overwrites exactly these files and nothing else.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARSENAL = os.path.join(ROOT, "game", "data", "arsenal")
CARDS = os.path.join(ROOT, "game", "data", "road_cards")

ELEMENT = {"fire": 0, "water": 1, "earth": 2, "air": 3}
ELEMENT_TAG = {"fire": "Fire", "water": "Water", "earth": "Earth", "air": "Air"}
RARITY = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

# id, name, clone, element, rarity, first_act, tint, description, card text
WEAPONS = [
    # --- Ways of killing -------------------------------------------------------
    ("quarry_arc", "Quarry Arc", "emberline", "earth", 1, 2, (0.82, 0.7, 0.5),
     "The towers near you lob a stone over the front line and into the crowd behind it.",
     "A wall that throws itself, one block at a time."),
    ("tide_motes", "Tide Motes", "sentry_wisps", "water", 0, 1, (0.5, 0.8, 1.0),
     "Beads of water circle the towers near you and soak what they touch - lightning follows a wet road.",
     "The towers drink from the same river you do."),
    ("cairn_stones", "Cairn Stones", "sentry_wisps", "earth", 1, 3, (0.78, 0.7, 0.55),
     "Stones circle the towers near you and knock back what walks into them.",
     "Every tower keeps a few of its own foundations awake."),
    ("hearth_flare", "Hearth Flare", "bell_of_the_hold", "fire", 1, 2, (1.0, 0.6, 0.3),
     "The gate flares and burns whatever crowds against it.",
     "The town keeps its fire banked for exactly this."),
    ("bedrock_shrug", "Bedrock Shrug", "bell_of_the_hold", "earth", 2, 3, (0.8, 0.68, 0.5),
     "The ground under the gate heaves and throws the crowd back.",
     "The beast shifts its weight, and the road remembers who was on it."),
    ("drowned_bell", "Drowned Bell", "soulfire", "water", 1, 3, (0.5, 0.78, 1.0),
     "A body that falls near the gate lets go a cold toll that slows the next one.",
     "Somewhere under the town a bell still rings for the drowned."),
    ("cairnfall", "Cairnfall", "falling_stars", "earth", 2, 4, (0.82, 0.72, 0.52),
     "Stones fall from the walls on the thickest knot of bodies at the gate.",
     "The wall gives up a little of itself to keep the rest standing."),
    ("ember_rain", "Ember Rain", "fortress_barrage", "fire", 1, 3, (1.0, 0.55, 0.25),
     "Burning cinders fall where the towers near you are aiming.",
     "The towers learned to throw what the forge spits out."),
    # --- Ways of not dying ------------------------------------------------------
    ("cinder_skin", "Cinder Skin", "thornskin", "fire", 1, 2, (1.0, 0.55, 0.28),
     "When you are struck, embers burst from you at whatever is close.",
     "Anything that touches the Warden learns the price of heat."),
    ("ember_stones", "Ember Stones", "guardian_stones", "fire", 2, 3, (1.0, 0.6, 0.3),
     "A coal circles you and swallows one shot; it reforms on its clock.",
     "A spark that has decided you are worth keeping."),
    ("stone_rampart", "Stone Rampart", "gate_ward", "earth", 1, 3, (0.8, 0.7, 0.52),
     "The gate takes a ward of stone on a clock.",
     "Every mason who ever worked on this town is still working."),
    ("wellspring_tide", "Wellspring Tide", "cinder_salve", "water", 1, 3, (0.5, 0.82, 1.0),
     "The towers near you are mended on a clock by a share of what they are missing.",
     "The river under the road runs through the towers too."),
]


# The hit picture a sibling of another element would have brought along and
# that this one should not: stones land as a slam, cinders as a burning bloom.
EFFECT = {"cairnfall": "slam_impact", "ember_rain": "meteor_bloom"}


def read(path):
    return open(path, encoding="utf-8").read()


def put(text, key, value):
    pattern = re.compile(r"^%s = .*$" % re.escape(key), re.M)
    if pattern.search(text):
        return pattern.sub("%s = %s" % (key, value), text, count=1)
    return text.replace("\n%s = " % "id", "\n%s = %s\nid = " % (key, value), 1)


def main():
    made = 0
    for wid, name, clone, element, rarity, first_act, tint, words, flavour in WEAPONS:
        sibling = os.path.join(ARSENAL, clone + ".tres")
        if not os.path.exists(sibling):
            raise SystemExit("no sibling %s for %s" % (clone, wid))
        text = read(sibling)
        text = put(text, "id", '"%s"' % wid)
        text = put(text, "display_name", '"%s"' % name)
        text = put(text, "description", '"%s"' % words)
        text = put(text, "element", str(ELEMENT[element]))
        text = put(text, "tint", "Color(%s, %s, %s, 1)" % tint)
        if re.search(r'^head = "(fire|water|earth|air)"', text, re.M):
            text = put(text, "head", '"%s"' % element)
        if re.search(r'^effect = "hit_(fire|water|earth|air)"', text, re.M):
            text = put(text, "effect", '"hit_%s"' % element)
        # The element's own touch, not the sibling's: only fire burns, and water
        # slows what it soaks - a cold toll that set its target alight would be
        # the sibling's fire wearing a new name.
        if element != "fire":
            text = re.sub(r"^burn_share = .*\n", "", text, flags=re.M)
        elif not re.search(r"^burn_share = ", text, re.M):
            text = put(text, "burn_share", "0.3")
            if not re.search(r"^duration = ", text, re.M):
                text = put(text, "duration", "2.0")
        if element == "water" and not re.search(r"^slow = ", text, re.M):
            text = put(text, "slow", "0.75")
            if not re.search(r"^duration = ", text, re.M):
                text = put(text, "duration", "2.0")
        if wid in EFFECT:
            text = put(text, "effect", '"%s"' % EFFECT[wid])
        open(os.path.join(ARSENAL, wid + ".tres"), "w", encoding="utf-8", newline="\n").write(text)

        card = read(os.path.join(CARDS, clone + ".tres"))
        tags = re.search(r"^tags = Array\[String\]\(\[(.*)\]\)$", card, re.M)
        kept = [t.strip().strip('"') for t in tags.group(1).split(",")] if tags else []
        kept = [t for t in kept if t not in ELEMENT_TAG.values()]
        tag_text = ", ".join('"%s"' % t for t in [ELEMENT_TAG[element]] + kept)
        card = put(card, "id", '"%s"' % wid)
        card = put(card, "display_name", '"%s"' % name)
        card = put(card, "description", '"%s card. %s"' % (RARITY[rarity], words))
        card = put(card, "rarity", str(rarity))
        card = put(card, "first_act", str(first_act))
        card = put(card, "tags", "Array[String]([%s])" % tag_text)
        card = put(card, "card_text", '"%s"' % flavour)
        card = put(card, "weapon", '"%s"' % wid)
        open(os.path.join(CARDS, wid + ".tres"), "w", encoding="utf-8", newline="\n").write(card)
        made += 1
    print("authored %d weapons" % made)


if __name__ == "__main__":
    main()
