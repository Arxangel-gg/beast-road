"""Authors the Arsenal's second wave of weapons (2026-09-30).

    python tools/author_arsenal_2026_09_30.py

Owner, 2026-09-30: "Need way more arsenal cards and varieties so that players
do not often see the same card and have a huge pool of options to luckily draw
from making them always wonder about possibilities they may not have been lucky
enough to get to try yet, and hope to get one day."

Twenty-nine weapons, data only: every pattern the Arsenal already fires, in the
elements and on the anchors it lacked. Each is its sibling's mechanics - the
weapon named in `clone` - in a new element, a new anchor or a new trade, so the
measurement `arsenal_check` makes of the sibling is what this one will measure
too. **Each sits inside the power its anchor already spans** (a Warden's
non-evolved weapons reach about 150 a second at level V in the model, the
towers' about 60, the town's about 110), so `curve_report`'s best hand - which
plans the strongest weapons it can hold - is the hand it already was. What the
wave adds is choice, not a stronger best case. Spread over Acts I to IV and
three rarities, so a road keeps turning up cards a player has never held.

Writes `game/data/arsenal/<id>.tres` and `game/data/road_cards/<id>.tres`.
Re-running overwrites exactly these files and nothing else.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARSENAL = os.path.join(ROOT, "game", "data", "arsenal")
CARDS = os.path.join(ROOT, "game", "data", "road_cards")

PATTERN = {"ORBIT": 0, "SEEKER": 1, "CHAIN": 2, "NOVA": 3, "TRAIL": 4, "STRIKE": 5,
           "ON_KILL": 6, "ARC": 7, "WARD": 8, "MEND": 9, "RETORT": 10, "GUARD": 11,
           "FIELD": 12}
ANCHOR = {"W": 0, "T": 1, "H": 2}
ELEMENT = {"fire": 0, "water": 1, "earth": 2, "air": 3}
ELEMENT_TAG = {"fire": "Fire", "water": "Water", "earth": "Earth", "air": "Air"}
PATTERN_TAG = {"ORBIT": "Orbit", "SEEKER": "Seeker", "CHAIN": "Chain", "NOVA": "Nova",
               "TRAIL": "Trail", "STRIKE": "Strike", "ON_KILL": "On kill", "ARC": "Arc",
               "WARD": "Ward", "MEND": "Mend", "RETORT": "Retort", "GUARD": "Guard",
               "FIELD": "Field"}
RARITY = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

DEFAULT_LD = [1.0, 1.25, 1.55, 1.85, 2.2]
DEFAULT_LC = [0, 0, 1, 1, 2]
FLAT = [1.0, 1.0, 1.0, 1.0, 1.0]

# id, name, pattern, anchor, element, rarity, first_act, tint, fields, description, card text
WEAPONS = [
    # --- The Warden's -----------------------------------------------------------
    ("gale_blades", "Gale Blades", "ORBIT", "W", "air", 1, 2, (0.78, 0.92, 1.0),
     dict(clone="ember_wisps", damage=5.0, cooldown=0.6, count=2, radius=105.0, speed=3.6,
          knockback=40.0, crowd=0.72, level_damage=[1.0, 1.2, 1.45, 1.7, 2.0],
          level_count=[0, 1, 1, 2, 3], head="air", effect="hit_air"),
     "Blades of wind circle you and throw back what they cut. More blades as it grows.",
     "The road's wind learned your name and keeps close."),
    ("hurled_stones", "Hurled Stones", "SEEKER", "W", "earth", 0, 1, (0.8, 0.68, 0.5),
     dict(clone="seeking_flames", damage=16.0, cooldown=1.0, count=1, reach=440.0, speed=520.0,
          knockback=70.0, crowd=1.0, level_count=[0, 0, 1, 1, 2], head="earth", effect="hit_earth"),
     "Stones fly at the nearest bodies and knock them back. More stones as it grows.",
     "Every road is paved with something to throw."),
    ("tidal_chain", "Tidal Chain", "CHAIN", "W", "water", 1, 2, (0.45, 0.78, 1.0),
     dict(clone="chain_spark", damage=10.0, cooldown=1.6, count=3, reach=380.0, slow=0.85,
          crowd=1.0, level_count=[0, 1, 2, 3, 4], head="water", effect="hit_water"),
     "Water leaps from body to body and leaves each one soaked - lightning follows a wet road further.",
     "The tide does not ask which of them is next."),
    ("wildfire_leap", "Wildfire Leap", "CHAIN", "W", "fire", 1, 3, (1.0, 0.55, 0.22),
     dict(clone="chain_spark", damage=8.0, cooldown=1.6, count=3, reach=380.0, burn_share=0.4,
          duration=2.0, crowd=1.0, level_count=[0, 1, 2, 3, 4], head="fire", effect="hit_fire"),
     "Fire jumps from body to body and leaves each one burning. More jumps as it grows.",
     "A spark that remembers every body it has been in."),
    ("rockslide", "Rockslide", "CHAIN", "W", "earth", 2, 4, (0.78, 0.66, 0.48),
     dict(clone="chain_spark", damage=13.0, cooldown=1.8, count=2, reach=360.0, knockback=50.0,
          crowd=1.0, level_count=[0, 1, 1, 2, 3], head="earth", effect="slam_impact"),
     "A stone caroms from body to body, heavier than it looks.",
     "It does not stop because something is in the way."),
    ("quake_pulse", "Quake Pulse", "NOVA", "W", "earth", 1, 2, (0.82, 0.7, 0.5),
     dict(clone="flame_nova", damage=16.0, cooldown=3.0, radius=115.0, knockback=110.0,
          crowd=4.0, level_damage=[1.0, 1.35, 1.75, 2.2, 2.7],
          level_radius=[1.0, 1.1, 1.2, 1.3, 1.45], level_count=[0, 0, 0, 0, 0], effect="quake_dust"),
     "The ground bucks around you and throws the bodies back.",
     "Stamp once. The road answers."),
    ("static_wake", "Static Wake", "TRAIL", "W", "air", 1, 3, (0.75, 0.85, 1.0),
     dict(clone="thorn_wake", damage=2.2, cooldown=0.7, radius=55.0, duration=2.0, slow=0.9,
          crowd=6.6, level_radius=[1.0, 1.1, 1.2, 1.3, 1.45], level_count=[0, 0, 0, 0, 0]),
     "Where you walk the air crackles, stinging what stands in it - hardest on the soaked.",
     "Your footsteps hum for a while after you leave."),
    ("meteor_shard", "Meteor Shard", "STRIKE", "W", "fire", 2, 3, (1.0, 0.6, 0.3),
     dict(clone="lightning_strike", damage=18.0, cooldown=2.4, count=2, radius=55.0, reach=460.0,
          burn_share=0.3, duration=2.5, crowd=0.9, level_count=[0, 0, 1, 1, 2], head="fire",
          effect="meteor_bloom"),
     "Burning stones fall on the thickest knot of bodies and leave them alight.",
     "The sky keeps a small piece of every fire."),
    ("pyre_spirits", "Pyre Spirits", "ON_KILL", "W", "fire", 1, 2, (1.0, 0.5, 0.25),
     dict(clone="marrow_seekers", damage=11.0, cooldown=0.8, count=1, reach=400.0, speed=480.0,
          burn_share=0.3, duration=2.0, crowd=1.0, level_damage=[1.0, 1.2, 1.45, 1.7, 2.0],
          level_count=[0, 0, 1, 1, 2], head="fire", effect="hit_fire"),
     "A body you kill lets a flame go to hunt the next one.",
     "What burns does not burn alone."),
    ("frost_wraiths", "Frost Wraiths", "ON_KILL", "W", "water", 1, 3, (0.6, 0.85, 1.0),
     dict(clone="marrow_seekers", damage=12.0, cooldown=0.9, count=1, reach=400.0, speed=440.0,
          slow=0.7, crowd=1.0, level_count=[0, 0, 1, 1, 2], head="water", effect="hit_water"),
     "A body you kill lets a cold shade go that slows the next one it finds.",
     "The dead are cold, and they share it."),
    ("bone_shards", "Bone Shards", "ON_KILL", "W", "earth", 2, 4, (0.9, 0.86, 0.74),
     dict(clone="marrow_seekers", damage=9.0, cooldown=1.0, count=2, reach=380.0, speed=520.0,
          knockback=30.0, crowd=1.0, level_count=[0, 0, 1, 1, 2], head="earth", effect="hit_physical"),
     "A body you kill breaks into shards that fly at the ones beside it.",
     "Nothing on this road goes to waste."),
    # The Warden's defence.
    ("tidewall", "Tidewall", "WARD", "W", "water", 1, 2, (0.55, 0.82, 1.0),
     dict(clone="lantern_ward", damage=0.0, cooldown=7.5, share=0.08, crowd=1.0,
          level_damage=[1.0, 1.2, 1.4, 1.65, 1.9], level_count=[0, 0, 0, 0, 0],
          level_radius=FLAT, effect="ward"),
     "Every seven and a half seconds, a ward of a twelfth of your health.",
     "Water stands between you and the blow, and then it is gone."),
    ("static_skin", "Static Skin", "RETORT", "W", "air", 1, 2, (0.78, 0.88, 1.0),
     dict(clone="thornskin", damage=12.0, cooldown=2.5, radius=100.0, knockback=30.0, crowd=3.0,
          level_damage=[1.0, 1.2, 1.4, 1.65, 1.9], level_count=[0, 0, 0, 0, 0],
          level_radius=[1.0, 1.1, 1.2, 1.3, 1.4], effect="hit_air"),
     "When you are struck, the air around you snaps at whatever is close.",
     "Touch the Warden and find out what the storm thinks of it."),
    ("wind_stones", "Wind Stones", "GUARD", "W", "air", 2, 3, (0.8, 0.9, 1.0),
     dict(clone="guardian_stones", damage=0.0, cooldown=6.5, radius=58.0, count=1, crowd=1.0,
          level_damage=FLAT, level_count=[0, 0, 1, 1, 2],
          level_radius=[1.0, 1.05, 1.1, 1.15, 1.2], head="air", effect="guard_shatter"),
     "A pebble of wind circles you and swallows one shot; it reforms every six and a half seconds.",
     "An arrow that meets the wind forgets where it was going."),
    ("dawn_salve", "Dawn Salve", "MEND", "W", "fire", 1, 3, (1.0, 0.78, 0.45),
     dict(clone="marrow_mend", damage=0.0, cooldown=5.5, share=0.06, crowd=1.0,
          level_damage=[1.0, 1.25, 1.5, 1.8, 2.1], level_count=[0, 0, 0, 0, 0],
          level_radius=FLAT, effect="mend_motes"),
     "Every five and a half seconds you heal a sixteenth of what you are missing.",
     "Warmth, a little at a time, is still warmth."),
    ("sucking_mire", "Sucking Mire", "FIELD", "W", "earth", 2, 4, (0.6, 0.5, 0.34),
     dict(clone="frostbound_ring", damage=0.0, cooldown=2.0, radius=110.0, slow=0.6, crowd=1.0,
          level_damage=FLAT, level_count=[0, 0, 0, 0, 0],
          level_radius=[1.0, 1.1, 1.25, 1.4, 1.6], effect="quake_dust"),
     "Bodies within the ring wade through mud at six tenths of their pace.",
     "The ground around you has decided they are not leaving."),
    # --- The Rampart's: the towers near you ----------------------------------------
    ("brazier_wisps", "Brazier Wisps", "ORBIT", "T", "fire", 1, 2, (1.0, 0.6, 0.3),
     dict(clone="sentry_wisps", damage=2.6, cooldown=0.7, count=1, radius=70.0, speed=2.6,
          burn_share=0.4, duration=2.0, crowd=1.05, level_count=[0, 0, 1, 1, 2], head="fire"),
     "Every tower near you keeps an ember circling it that sets what comes near alight.",
     "The walls carry coals now."),
    ("tidewire", "Tidewire", "ARC", "T", "water", 1, 3, (0.5, 0.8, 1.0),
     dict(clone="arc_lattice", damage=8.0, cooldown=0.9, count=2, radius=26.0, slow=0.8,
          crowd=0.5, level_count=[0, 1, 1, 2, 3], head="water"),
     "A line of water hangs between towers near you and soaks and slows what crosses it.",
     "Cross it and walk the rest of the way wet."),
    ("emberline", "Emberline", "ARC", "T", "fire", 2, 4, (1.0, 0.55, 0.25),
     dict(clone="arc_lattice", damage=6.5, cooldown=0.9, count=2, radius=26.0, burn_share=0.5,
          duration=2.0, crowd=0.5, level_count=[0, 1, 1, 2, 3], head="fire"),
     "A line of fire hangs between towers near you and burns what crosses it.",
     "The towers have drawn a line, and it is lit."),
    ("storm_beacon", "Storm Beacon", "STRIKE", "T", "air", 1, 2, (0.75, 0.85, 1.0),
     dict(clone="fortress_barrage", damage=11.0, cooldown=6.0, every_kills=10, radius=60.0,
          crowd=1.8, level_count=[0, 0, 0, 0, 0], head="air", effect="hit_air"),
     "Every ten kills on the road, the towers near you call lightning down on a body.",
     "The towers keep count, and so does the sky."),
    ("glacier_shards", "Glacier Shards", "STRIKE", "T", "water", 2, 3, (0.6, 0.86, 1.0),
     dict(clone="fortress_barrage", damage=10.0, cooldown=5.0, every_kills=14, radius=80.0,
          slow=0.7, crowd=1.8, level_count=[0, 0, 0, 0, 0], head="water", effect="frost_ring"),
     "Every fourteen kills on the road, ice falls from the towers near you and slows what it lands on.",
     "The towers have been saving the cold."),
    ("forge_ward", "Forge Ward", "WARD", "T", "fire", 2, 3, (1.0, 0.7, 0.4),
     dict(clone="ward_lattice", damage=0.0, cooldown=10.0, share=0.1, crowd=1.0,
          level_damage=[1.0, 1.2, 1.4, 1.65, 1.9], level_count=[0, 0, 0, 0, 0],
          level_radius=FLAT, effect="ward"),
     "Every ten seconds each tower near you gains a ward of a tenth.",
     "Tempered, and then tempered again."),
    ("cinder_salve", "Cinder Salve", "MEND", "T", "fire", 1, 2, (1.0, 0.72, 0.45),
     dict(clone="masons_wisps", damage=0.0, cooldown=5.0, share=0.04, crowd=1.0,
          level_damage=[1.0, 1.2, 1.4, 1.65, 1.9], level_count=[0, 0, 0, 0, 0],
          level_radius=FLAT, effect="mend_motes"),
     "Every five seconds the towers near you mend a little of what they are missing.",
     "Warm mortar sets faster."),
    ("thorn_bastion", "Thorn Bastion", "RETORT", "T", "earth", 1, 2, (0.55, 0.8, 0.35),
     dict(clone="kiln_skin", damage=12.0, cooldown=3.0, radius=80.0, knockback=70.0, crowd=2.0,
          level_damage=[1.0, 1.2, 1.4, 1.65, 1.9], level_count=[0, 0, 0, 0, 0],
          level_radius=[1.0, 1.1, 1.2, 1.3, 1.4], effect="thorn_burst"),
     "When a tower near you is struck, thorns burst from its foot and throw back what is there.",
     "The walls grew teeth."),
    # --- The Hearth's: the town ------------------------------------------------------
    ("tide_bell", "Tide Bell", "NOVA", "H", "water", 2, 3, (0.55, 0.82, 1.0),
     dict(clone="bell_of_the_hold", damage=18.0, cooldown=5.0, radius=360.0, knockback=60.0,
          slow=0.75, crowd=4.0, level_damage=[1.0, 1.35, 1.75, 2.2, 2.7],
          level_radius=[1.0, 1.08, 1.16, 1.24, 1.35], level_count=[0, 0, 0, 0, 0], effect="frost_ring"),
     "The town rings a bell of water that soaks and slows everything near it.",
     "Every body at the gate hears it, and every one is wet."),
    ("icefall", "Icefall", "STRIKE", "H", "water", 1, 2, (0.6, 0.86, 1.0),
     dict(clone="falling_stars", damage=15.0, cooldown=2.4, count=2, radius=60.0, reach=900.0,
          slow=0.7, crowd=1.2, level_count=[0, 1, 1, 2, 3], head="water", effect="hit_water"),
     "Ice falls on bodies near the town and slows what it lands on. More of it as it grows.",
     "The eaves have been saving it all winter."),
    ("watchfire_crows", "Watchfire Crows", "ON_KILL", "H", "air", 1, 3, (0.8, 0.88, 1.0),
     dict(clone="soulfire", damage=14.0, cooldown=1.0, radius=80.0, reach=700.0, crowd=2.0,
          level_radius=[1.0, 1.1, 1.2, 1.3, 1.4], level_count=[0, 0, 0, 0, 0], effect="hit_air"),
     "A body that dies near the town lets a crow of wind go that strikes the ones beside it.",
     "The watch keeps birds, and the birds keep watch."),
    ("wellspring", "Wellspring", "MEND", "H", "water", 2, 4, (0.5, 0.82, 1.0),
     dict(clone="hearthstone", damage=0.0, cooldown=8.0, share=0.012, crowd=1.0,
          level_damage=[1.0, 1.2, 1.45, 1.7, 2.0], level_count=[0, 0, 0, 0, 0],
          level_radius=FLAT, effect="mend_motes"),
     "Every eight seconds the town's wall mends a little of what it is missing.",
     "The town drinks, and stands a little straighter."),
]

FIELD_ORDER = ["pattern", "anchor", "element", "tint", "damage", "cooldown", "count",
               "radius", "reach", "speed", "duration", "burn_share", "slow", "knockback",
               "every_kills", "share", "crowd", "level_damage", "level_count", "level_radius",
               "head", "effect"]


def fmt(key, value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if key == "tint":
        return "Color(%s, %s, %s, 1)" % value
    if key in ("level_damage", "level_radius"):
        return "Array[float]([%s])" % ", ".join(repr(float(v)) for v in value)
    if key == "level_count":
        return "Array[int]([%s])" % ", ".join(str(int(v)) for v in value)
    if isinstance(value, str):
        return '"%s"' % value
    if isinstance(value, float):
        return repr(value)
    return str(value)


def modelled(fields, level):
    if fields.get("pattern") in (8, 9, 10, 11, 12):
        return 0.0
    ld = fields.get("level_damage", DEFAULT_LD)
    lc = fields.get("level_count", DEFAULT_LC)
    count = max(int(fields.get("count", 1)) + lc[level - 1], 1)
    return (fields["damage"] * ld[level - 1] * (1.0 + fields.get("burn_share", 0.0))
            * count * fields.get("crowd", 1.0) / max(fields["cooldown"], 0.05))


def main():
    ceiling = {"W": 150.0, "T": 62.0, "H": 110.0}
    for wid, name, pattern, anchor, element, rarity, first_act, tint, extra, desc, text in WEAPONS:
        fields = dict(extra)
        fields.pop("clone")
        fields["pattern"] = PATTERN[pattern]
        fields["anchor"] = ANCHOR[anchor]
        fields["element"] = ELEMENT[element]
        fields["tint"] = tint
        top = modelled(fields, 5)
        assert top <= ceiling[anchor], (wid, top)
        lines = ['[gd_resource type="Resource" script_class="ArsenalWeaponData" load_steps=2 format=3]',
                 "",
                 '[ext_resource type="Script" path="res://scripts/resources/arsenal_weapon_data.gd" id="1_data"]',
                 "",
                 "[resource]",
                 'script = ExtResource("1_data")',
                 'id = "%s"' % wid,
                 'display_name = "%s"' % name,
                 'description = "%s"' % desc]
        for key in FIELD_ORDER:
            if key in fields:
                lines.append("%s = %s" % (key, fmt(key, fields[key])))
        with open(os.path.join(ARSENAL, wid + ".tres"), "w", encoding="utf-8", newline="\n") as out:
            out.write("\n".join(lines) + "\n")
        tags = [ELEMENT_TAG[element], "Arsenal", PATTERN_TAG[pattern]]
        if anchor == "T":
            tags.append("Tower")
        elif anchor == "H":
            tags.append("Town")
        card = ['[gd_resource type="Resource" script_class="RoadCardData" load_steps=2 format=3]',
                "",
                '[ext_resource type="Script" path="res://scripts/resources/road_card_data.gd" id="1_data"]',
                "",
                "[resource]",
                'script = ExtResource("1_data")',
                'id = "%s"' % wid,
                'display_name = "%s"' % name,
                'description = "%s card. %s"' % (RARITY[rarity], desc),
                "rarity = %d" % rarity,
                "first_act = %d" % first_act,
                "branch = %d" % ANCHOR[anchor],
                "tags = Array[String]([%s])" % ", ".join('"%s"' % t for t in tags),
                'card_text = "%s"' % text,
                'weapon = "%s"' % wid]
        with open(os.path.join(CARDS, wid + ".tres"), "w", encoding="utf-8", newline="\n") as out:
            out.write("\n".join(card) + "\n")
        print("%-16s %-8s %s  L1 %6.1f  L5 %6.1f" % (wid, pattern, anchor, modelled(fields, 1), top))
    print("weapons", len(WEAPONS))


if __name__ == "__main__":
    main()
