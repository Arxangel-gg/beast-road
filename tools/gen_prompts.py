"""Builds docs/ASSET_PROMPTS.md: one copy-paste-ready prompt per manifest asset.

Subjects live here; sizes, paths and the T/O split are read from
docs/ASSET_MANIFEST.md so the two can never disagree about what exists.
"""
import io, re, sys

ROOT = "E:/Arxangel/GameDev/BeastRoad/"
MANIFEST = ROOT + "docs/ASSET_MANIFEST.md"
OUT = ROOT + "docs/ASSET_PROMPTS.md"

# Four stems, not one. The first version used a single stem carrying
# "camera looking down at roughly 60 degrees" and applied it to everything -
# which asked for a camera angle on a UI icon, and asked a character to be shot
# from the same angle as a building. A human at 60 degrees is a head and two
# shoulders; almost every top-down action game draws structures steeply and
# characters much flatter so they can still be read.
#
# Each stem leads with the medium and the camera, because image models weight
# early tokens hardest. The first version buried the camera in sentence nine and
# got eye-level portraits back.

_PALETTE = ("Muted desaturated palette (#0B1416 near-black, #1E2E33 slate, #E8A33D amber, "
    "#D9CDB8 bone, #8C3A2B rust) with one saturated accent. Warm amber rim light from the upper "
    "right against deep teal-black shadow.")

_ALPHA = ("Fully transparent background - no ground, no cast shadow, no frame, no text, no "
    "border. Export as PNG with a true alpha channel.")

CHARACTER_STEM = (
    "An isometric game character sprite, in the style of a top-down isometric action RPG.\n\n"
    "VIEW - describe by what is visible, not by an angle. Degree instructions do not work on "
    "these models; a list of what the camera can and cannot see does:\n\n"
    "  - You SEE: the top of the head and shoulders, the upper back, the outer sides of the arms, "
    "the tops of the feet.\n\n"
    "  - You DO NOT SEE: the face, the front of the chest, the underside of a cloak, or the soles "
    "of the feet.\n\n"
    "  - The head overlaps the chest because you are looking down onto it. The legs are short and "
    "foreshortened. The figure looks slightly squashed vertically, and that is correct.\n\n"
    "POSE: standing upright and compact, weight settled, facing away from the viewer and slightly "
    "down-screen. A calm ready stance. NOT leaping, NOT lunging, NOT sprawled diagonally across "
    "the frame, NOT a dramatic action pose.\n\n"
    "SIZE: displayed at about {display} pixels in game - roughly a thumbnail. Build it from large "
    "flat shapes and one strong silhouette. No fine straps, no small buckles, no cloth folds, no "
    "rendered texture. If a detail would be under two pixels, leave it out.\n\n"
    "STYLE: flat painterly game art, confident simple brushwork, no black outlines, no realistic "
    "rendering, no gloss. " + _PALETTE + "\n\n"
    "FRAMING: one figure, centred, standing vertically and filling most of the square with a "
    "small even margin. Square 1:1. " + _ALPHA + "\n\n"
    "SUBJECT: "
)

STRUCTURE_STEM = (
    "A 2D game sprite of a building or structure for a top-down game, drawn to be seen small.\n\n"
    "CAMERA: looking down from a steep three-quarter angle, about 60 degrees. The roof and upper "
    "surfaces are the dominant part of the image; the walls are visible but foreshortened. This "
    "is NOT an eye-level architectural view and NOT concept art.\n\n"
    "SIZE: this will be displayed about {display}px tall in game. Bold readable masses, clear "
    "silhouette, no fine detail that would disappear at that size.\n\n"
    "STYLE: simplified painterly game art, flat confident brushwork, no black outlines, no "
    "photoreal rendering. " + _PALETTE + "\n\n"
    "FRAMING: one structure, centred, upright in frame with a small even margin, nothing else in "
    "the image. Square 1:1. " + _ALPHA + "\n\n"
    "SUBJECT: "
)

ICON_STEM = (
    "A 2D game UI icon.\n\n"
    "VIEW: flat and front-on. No perspective, no camera angle, no three-dimensional staging. One "
    "clear symbol, like a printed pictogram.\n\n"
    "SIZE: this will be displayed about {display}px. Thick bold shapes only - it has to read at "
    "thumbnail size. No thin lines, no small parts, no texture detail.\n\n"
    "STYLE: limited flat colour - amber (#E8A33D) and bone (#D9CDB8), with near-black (#0B1416) "
    "for separation. Slight hand-painted texture is fine; gradients, gloss and realistic "
    "rendering are not.\n\n"
    "FRAMING: the symbol centred and filling most of the frame. Square 1:1. " + _ALPHA + "\n\n"
    "SUBJECT: "
)

UI_FRAME_STEM = (
    "A 2D user-interface panel graphic for a game, built to be stretched.\n\n"
    "VIEW: flat and front-on, no perspective, no camera angle.\n\n"
    "CONSTRUCTION: symmetrical left-to-right and top-to-bottom, with a decorated border and a "
    "completely flat, empty, evenly-coloured centre. The centre must stay plain because it gets "
    "stretched - any pattern there will smear. Put nothing inside it.\n\n"
    "STYLE: dark weathered stone and iron, muted and low contrast so text sits on top of it "
    "legibly. " + _PALETTE + " Restrained - this is a frame, not a focal point.\n\n"
    "FRAMING: the panel fills the whole image, edge to edge. " + _ALPHA + "\n\n"
    "SUBJECT: "
)

MJ_OPAQUE = (
    "{subject}, dark painterly grim-fantasy game art, hand-painted digital matte painting, "
    "visible brushwork, warm amber light against deep teal-black shadow, muted desaturated "
    "palette, heavy atmosphere, volumetric haze, no characters, no text, no UI --ar 16:9 --s 250"
)
MJ_TILE = (
    "seamless tileable top-down ground texture, {subject}, dark painterly grim-fantasy game art, "
    "hand-painted, muted desaturated palette, even lighting with no directional shadow, no "
    "objects casting shadow, no text --tile --ar 1:1 --s 150"
)

S = {}

S["hero_base.png"] = ("a lone armored scavenger-warrior, curved single-edged blade held low at one "
    "side, tattered dark cloak, bone-white featureless mask, lean wiry build, scavenged plate "
    "over wrapped cloth")
S["hero_ascended_1.png"] = ("the same armored scavenger-warrior, now transformed - the mask "
    "cracked open with amber light bleeding through, the cloak longer and torn, one arm sheathed "
    "in fused bone plating, the blade glowing faintly at its edge")
S["hero_ascended_2.png"] = ("the same warrior in final transformation - towering and monstrous, "
    "the mask fully shattered into a crown of bone shards, amber light pouring from every seam, "
    "cloak become a mass of trailing ribbons, the blade elongated and burning")

S["enemy_bogkin.png"] = ("a hunched swamp-dweller creature, waterlogged and bloated, moss and "
    "dead reeds hanging from its limbs, dim pale eyes, heavy rounded shoulders, dripping black water")
S["enemy_glassborn.png"] = ("a jagged crystalline humanoid made of fractured salt glass, thin "
    "sharp limbs, semi-translucent body catching light, hairline fractures across its shoulders")
S["enemy_steppehorde.png"] = ("a scrappy nomad raider in scavenged rusted iron plates, crude iron "
    "spear held upright, wiry underfed frame, cloth-wrapped head")
S["elite_warden.png"] = ("a heavily armored bulwark warrior hunched behind an enormous riveted "
    "iron shield taller than itself, dense immovable silhouette, minimal visible body")
S["elite_howler.png"] = ("a gaunt ritual-caller with an oversized curved bone horn raised to its "
    "mouth, ragged banner strapped to its back, throat distended")
S["elite_burrower.png"] = ("a segmented armored digging creature erupting from broken ground, "
    "heavy clawed forelimbs, eyeless armored head plate, broad chitinous back")

S["boss_drowned_choir.png"] = ("a towering mass of fused drowned bodies forming a single "
    "cathedral-like figure, dozens of open singing mouths across its surface, black water pouring "
    "continuously from its frame, tattered ceremonial cloth, immense and vertical")
S["boss_mirrorfang.png"] = ("an enormous predatory quadruped beast built from mirrored salt "
    "glass, overlapping reflective shard plating, long fanged skull, refracted amber light "
    "scattering off its flanks")
S["boss_rust_crown.png"] = ("a colossal armored warlord fused to a throne of corroded iron, a "
    "crown of jagged rusted spires grown into its skull, chains and torn banners hanging from its "
    "shoulders, monumental scale")

S["tower_ember_spire.png"] = ("a slender tall stone spire capped with an open burning brazier, "
    "narrow iron banding, embers rising from the top")
S["tower_pyre_cannon.png"] = ("a squat heavy siege cannon of blackened iron with a glowing "
    "fire-chamber, wide short barrel, mounted on a stone base")
S["tower_rime_lance.png"] = ("a tall narrow tower of pale stone ending in a single "
    "frost-encrusted spear point, sheets of blue-white ice down one side")
S["tower_hoarfrost_bell.png"] = ("a heavy stone frame holding a large frost-covered bronze bell, "
    "long icicles hanging from its rim")
S["tower_bulwark.png"] = ("a squat fortified stone bunker with layered overlapping shield "
    "plating, heavy and wide, almost no ornament, built to absorb")
S["tower_shard_thrower.png"] = ("a mechanical ballista of stone and iron loaded with a single "
    "long jagged rock shard, tensioned cables")
S["tower_arc_coil.png"] = ("a metal tower wrapped in tiered copper coils, arcs of pale violet "
    "lightning crackling between the rings")
S["tower_gale_turret.png"] = ("a slim tower with spinning bladed vanes and open wind funnels at "
    "its crown, motion blur on the blades")

S["tower_firestorm.png"] = ("a tower of blackened iron and stone with a cyclone of burning embers "
    "spiralling above its open crown, wind-torn flame, scorched banding")
S["tower_magma.png"] = ("a squat cracked-stone tower with molten rock glowing through its "
    "fissures, slow lava seeping down its base onto the ground")
S["tower_steam_burst.png"] = ("a riveted copper and stone tower with pressure valves along its "
    "flanks venting thick white steam, condensation running down the metal")
S["tower_blizzard.png"] = ("a pale ice-sheathed tower with a swirling vortex of snow and violet "
    "lightning around its upper spire, frost spreading from its base")
S["tower_glacier.png"] = ("a massive block of blue-white glacial ice fused around a stone core, "
    "thick frozen buttresses, deep internal cracks catching light")
S["tower_quake.png"] = ("a heavy megalith tower of stacked raw stone with shattered rock and dust "
    "erupting around its foundations, visible ground fracture rings")
S["tower_conflagration.png"] = ("a tall furnace-tower entirely engulfed in roaring fire, iron "
    "ribs glowing white-hot, a column of flame rising from its open top")
S["tower_deep_freeze.png"] = ("a jagged spire of solid black-blue ice, razor-sharp frozen shards "
    "radiating outward, air visibly frosting around it")
S["tower_bastion.png"] = ("an immense squat fortress block of layered granite and iron plating, "
    "utterly immovable, arrow slits and buttresses, no ornament")
S["tower_tempest.png"] = ("a skeletal iron lattice tower crowned with a violent storm cloud, "
    "multiple violet lightning bolts branching outward simultaneously")

S["city_base.png"] = ("a small fortified settlement built on a curved platform of vast bone and "
    "lashed timber, tiered stone buildings, banners, chimney smoke, defensive palisade around the "
    "rim, viewed from three-quarter above")
S["city_damage_1.png"] = ("the same small fortified settlement, lightly ruined - scorch marks, "
    "one collapsed roof, torn banners, thin smoke, viewed from three-quarter above")
S["city_damage_2.png"] = ("the same small fortified settlement, heavily ruined - several "
    "buildings burned down to their frames, the palisade breached, fires still burning, viewed "
    "from three-quarter above")
S["city_damage_3.png"] = ("the same small fortified settlement, almost destroyed - mostly "
    "blackened rubble with only the town hall still standing, viewed from three-quarter above")
S["building_town_hall.png"] = ("a tiered stone hall with a heavy timber roof and a relic-socket "
    "frame above its door, banners on both sides")
S["building_forge.png"] = ("a squat stone forge with a glowing open furnace mouth, anvil outside, "
    "smoke stack")
S["building_sanctum.png"] = ("a narrow stone shrine with a burning bowl on a pedestal and hanging "
    "chains, ritual markings on the walls")
S["building_granary.png"] = ("a rounded timber and stone storehouse with sacks and barrels "
    "stacked outside, thatched roof")
S["building_scavenging_post.png"] = ("a low open-sided work yard of rough timber and hide awnings, "
    "sorting tables piled with salvaged scrap and bone, tool racks, a heavy chain post")
S["building_watchtower.png"] = ("a tall narrow timber and stone lookout tower with an open railed "
    "platform at the top, a hanging signal lantern and a mounted spyglass")
S["plot_empty.png"] = ("an empty flattened building plot of packed earth ringed by low foundation "
    "stones, a few survey stakes and coiled rope, nothing built on it")
S["plot_locked.png"] = ("an overgrown derelict building plot behind a barred timber palisade, "
    "chained gate, weeds and rubble, clearly sealed off")

S["beast_profile.png"] = ("an immense ancient beast walking across a wasteland - part sea "
    "serpent, part armored turtle, part dinosaur - a long scaled neck and horned skull, a vast "
    "domed shell of stone and moss on its back carrying a small fortified city lashed down with "
    "chains, six heavy legs, seen in full side profile, colossal scale")

S["terrain_ashfen.png"] = ("dark marsh ground, pools of black standing water, pale dead reeds, "
    "ash-grey mud, sunken twisted roots")
S["terrain_saltglass.png"] = ("cracked salt flat, pale white-blue crystalline crust, thin "
    "fracture lines, scattered glassy shards")
S["terrain_steppe.png"] = ("dry snow hardpan, red-brown cracked earth, scattered rusted iron "
    "debris, sparse dead grass tufts")

S["macro_act1.png"] = ("a vast fog-drowned marsh valley stretching to the horizon, drowned trees, "
    "low grey mist, distant water")
S["macro_act2.png"] = ("an endless cracked white salt desert under a bruised sky, distant glass "
    "formations catching light, heat shimmer")
S["macro_act3.png"] = ("a red-brown iron snow under a heavy dust sky, the ruined silhouette of "
    "an immense fortress on the far horizon")
S["crossroad_bg.png"] = ("a fork in an ancient road at dusk, two paths diverging into different "
    "distant landscapes, weathered stone waymarker in the foreground")
S["raid_arena_bg.png"] = ("a hostile enemy warcamp seen from directly above, ringed by bone "
    "totems and burning braziers, packed dirt floor, tents at the edges")
S["menu_key_art.png"] = ("an immense ancient beast - part serpent, part turtle, part dinosaur - "
    "walking away across a wasteland at dusk with a small lit fortified city on its back, seen "
    "from behind and below, dramatic scale, cinematic key art")
S["splash_studio.png"] = ("a plain dark textured background of deep teal-black with a faint warm "
    "amber glow in the centre, empty, no subject, minimal, for a studio logo to sit on top of")

S["lane_path.png"] = ("a trodden dirt road surface, packed earth rutted by cart wheels and "
    "footfall, scattered gravel, slightly darker than surrounding ground")
S["build_spot.png"] = ("a circular stone foundation pad set into the ground, cut flagstones with "
    "an empty socket in the centre, faint carved markings around the rim, nothing built on it")
S["build_spot_combo.png"] = ("a circular stone foundation pad inscribed with a glowing violet "
    "binding sigil, two linked channels running to its edges, empty socket in the centre")
S["town_core.png"] = ("a compact fortified keep of tiered stone with a banner mast, heavy gate "
    "and a low protective wall, seen from three-quarter above, the heart of a small settlement")

S["chieftain_ashfen.png"] = ("an enormous bloated marsh warlord crowned with antlers and reeds, "
    "draped in waterlogged hides, carrying a heavy bone maul, black water streaming from its bulk")
S["chieftain_saltglass.png"] = ("a tall crystalline warlord of fused salt glass shards, a "
    "mirrored faceless head, jagged blade-limbs, refracting amber light")
S["chieftain_steppe.png"] = ("a broad iron-plated nomad warlord in a horned rusted helm, layered "
    "scavenged armour, twin curved cleavers, torn clan banners on its back")
S["captive_bogkin.png"] = ("a defeated hunched swamp-dweller creature kneeling with its head "
    "bowed, heavy iron shackles on its wrists, moss and dead reeds hanging from its limbs")
S["captive_glassborn.png"] = ("a defeated crystalline salt-glass humanoid kneeling with its head "
    "bowed, heavy iron shackles on its cracked wrists, dulled fractured body")
S["captive_steppehorde.png"] = ("a defeated nomad raider kneeling with its head bowed, heavy iron "
    "shackles on its wrists, stripped armour and torn cloth wrappings")

S["ui_panel.png"] = ("a rectangular dark stone and iron interface panel with a riveted border and "
    "worn corner brackets, flat empty centre, symmetrical, suitable for nine-slice stretching")
S["ui_panel_dark.png"] = ("a rectangular near-black stone interface panel with a thin recessed "
    "iron border, flat empty centre, symmetrical, suitable for nine-slice stretching")
S["ui_button.png"] = ("a wide horizontal dark iron button plate with bevelled edges and small "
    "corner rivets, flat empty centre, symmetrical, suitable for nine-slice stretching")
S["ui_button_hover.png"] = ("the same wide horizontal iron button plate lit with a warm amber "
    "inner glow along its bevelled edges, flat empty centre, symmetrical")
S["ui_slot.png"] = ("a square recessed inventory socket of dark stone with a worn iron rim and an "
    "empty hollow centre, symmetrical")
S["ui_bar_fill.png"] = ("a small horizontal bar of solid warm amber-rust light with a soft inner "
    "glow, flat, seamless left to right, no border")
S["ui_bar_back.png"] = ("a small horizontal empty trough of dark recessed iron, flat, seamless "
    "left to right, no border")
S["ui_logo.png"] = ("the words BEAST ROAD as a wide game logo wordmark in a heavy weathered "
    "carved-bone serif, amber and bone, a faint horned serpent silhouette behind the letters")

_SPELLS = {
    "spell_rift_step.png": "a torn slit in space with a figure stepping through it",
    "spell_cinder_nova.png": "a bursting star of ember and ash radiating outward",
    "spell_bulwark_ward.png": "a domed protective barrier over a straight line",
    "spell_marrow_drain.png": "a curved fang siphoning a spiral of light",
    "spell_chain_hook.png": "a barbed hook trailing a taut chain",
    "spell_ash_veil.png": "a drifting veil of ash concealing a silhouette",
    "spell_tremor.png": "concentric shockwave rings cracking outward from a point",
    "spell_beasts_breath.png": "a cone of exhaled breath widening into a beam",
}
for _k, _v in _SPELLS.items():
    S[_k] = "a rough hand-drawn ritual sigil representing " + _v

_UI = {
    "ui_element_fire.png": "a stylised flame", "ui_element_water.png": "a stylised water droplet",
    "ui_element_earth.png": "a stylised faceted stone", "ui_element_air.png": "a stylised swirling gust",
    "ui_resource.png": "a heap of salvaged scrap and bone", "ui_blueprint.png": "a rolled schematic scroll",
    "ui_relic.png": "a faceted ritual amulet", "ui_war_horn.png": "a curved war horn",
    "ui_raid_charge.png": "a filling lightning-charged meter",
    "ui_distance.png": "a winding road vanishing to a point",
    "ui_city_health.png": "a fortified gate tower", "ui_pressure_arrow.png": "a bold directional arrow",
    "ui_captive.png": "a pair of iron shackles", "ui_wave.png": "three advancing spear silhouettes",
    "ui_upgrade.png": "a chevron arrow pointing up", "ui_build.png": "a mason's hammer and chisel",
    "ui_pause.png": "two vertical pause bars", "ui_settings.png": "a toothed iron cog",
    "ui_lock.png": "a heavy closed padlock", "ui_close.png": "a bold X cross",
}
for _k, _v in _UI.items():
    S[_k] = _v

_RELICS = ["a cracked bone crown", "a rusted iron heart", "a sealed clay jar",
    "a knotted cord of teeth", "a shattered mirror shard", "a blackened iron key",
    "a wax-sealed scroll", "a carved horn ring", "a burnt feather",
    "a river stone bound in wire", "a tarnished silver bell", "a bundle of splintered arrows",
    "a cracked hourglass of black sand", "a flensed animal skull", "a coil of braided hair",
    "a broken compass needle", "a vial of dark oil", "a chipped obsidian blade",
    "a rusted shackle bolt", "a folded leather map"]
for _i, _obj in enumerate(_RELICS, start=1):
    S["relic_%02d.png" % _i] = _obj + ", an ancient ritual object, worn and weathered"
for _k, _v in {
        "relic_core_drowned_choir.png": "a fused knot of singing bone mouths weeping black water",
        "relic_core_mirrorfang.png": "a curved mirrored glass fang refracting amber light",
        "relic_core_rust_crown.png": "a jagged crown of corroded iron spires"}.items():
    S[_k] = _v + ", an ancient ritual object of great power, worn and weathered"


def parse_manifest():
    text = io.open(MANIFEST, encoding='utf-8').read()
    assets, folder, dw, dh, dt, in5, section = [], "", 0, 0, True, False, ""
    re_sec = re.compile(r"^###\s+(5\.\d+[^\n]*?)\s*$")
    re_folder = re.compile(r"`res://art/([A-Za-z0-9_/]+?)/?`")
    re_def = re.compile(r"[Aa]ll\s+(\d+)\s*[x\u00d7X]\s*(\d+)\s*,\s*type\s+([TO])")
    re_size = re.compile(r"^(\d+)\s*[x\u00d7X]\s*(\d+)$")
    re_png = re.compile(r"`([A-Za-z0-9_\-./]+\.png)`")
    re_ell = re.compile(r"[\u2026]|\.\.\.")
    for raw in text.split("\n"):
        line = raw.strip()
        if line.startswith("## "):
            in5 = line.startswith("## 5.")
            continue
        if not in5:
            continue
        m = re_sec.match(line)
        if m:
            section = m.group(1)
            mf = re_folder.search(line)
            folder = mf.group(1) if mf else ""
            dw = dh = 0
            dt = True
            continue
        if not folder or line.startswith(">"):
            continue
        md = re_def.search(line)
        if md:
            dw, dh, dt = int(md.group(1)), int(md.group(2)), md.group(3) == "T"
            continue
        names, w, h, t = [], dw, dh, dt
        if line.startswith("|"):
            for cell in line.split("|"):
                cell = cell.strip()
                if not cell:
                    continue
                mp = re_png.search(cell)
                if mp:
                    names.append(mp.group(1))
                    continue
                st = cell.replace("`", "").strip()
                ms = re_size.match(st)
                if ms:
                    w, h = int(ms.group(1)), int(ms.group(2))
                    continue
                if st in ("T", "O"):
                    t = st == "T"
            if not names:
                continue
        else:
            all_m = list(re_png.finditer(line))
            if not all_m:
                continue
            ells = list(re_ell.finditer(line))
            for i, mm in enumerate(all_m):
                names.append(mm.group(1))
                if i + 1 < len(all_m):
                    a, b = mm.end(), all_m[i + 1].start()
                    if any(a <= e.start() and e.end() <= b for e in ells):
                        p1, p2 = mm.group(1)[:-4], all_m[i + 1].group(1)[:-4]
                        d1, d2 = re.search(r"(\d+)$", p1), re.search(r"(\d+)$", p2)
                        if d1 and d2:
                            pad = len(d1.group(1))
                            pre = p1[:-pad]
                            for n in range(int(d1.group(1)) + 1, int(d2.group(1))):
                                names.append("%s%s.png" % (pre, str(n).zfill(pad)))
        for n in names:
            assets.append({"file": n, "path": "res://art/%s/%s" % (folder, n),
                           "w": w, "h": h, "t": t, "section": section})
    return assets


def main():
    assets = parse_manifest()
    missing = [a["file"] for a in assets if a["file"] not in S]
    if missing:
        print("MISSING SUBJECTS (%d):" % len(missing))
        for m in missing:
            print("   ", m)
        sys.exit(1)

    chat = [a for a in assets if a["t"]]
    mj = [a for a in assets if not a["t"]]

    L = []
    A = L.append
    A("# BEAST ROAD - Asset Generation Prompts")
    A("")
    A("**Generated from `ASSET_MANIFEST.md`.** Do not hand-edit the sizes here - fix the manifest")
    A("and regenerate, or the two will disagree about what the game loads.")
    A("")
    A("%d assets: **%d ChatGPT** (transparent background) and **%d Midjourney** (opaque)."
      % (len(assets), len(chat), len(mj)))
    A("")
    A("---")
    A("")
    A("## How to use this")
    A("")
    A("1. Generate the image with the prompt given.")
    A("2. Save it with **exactly the filename in the heading**. That is the only thing you have")
    A("   to get right - not the folder, not the resolution.")
    A("3. Drop every finished file into `art_inbox/` at the repo root.")
    A("4. Run:")
    A("")
    A("```")
    A("tools\\import_art.ps1")
    A("```")
    A("")
    A("That resizes each image to its exact target dimensions, verifies transparent assets really")
    A("have an alpha channel, files each one at its correct `res://art/...` path, and reports")
    A("anything it could not match.")
    A("")
    A("You do not need to resize anything yourself. Generate ChatGPT assets at 1024x1024 and")
    A("Midjourney assets at whatever the aspect ratio gives you.")
    A("")
    A("### Getting real transparency out of ChatGPT")
    A("")
    A("If it returns a grey-and-white checkerboard *painted into the image* instead of genuinely")
    A("empty pixels, reply:")
    A("")
    A("> regenerate with a true transparent alpha channel, not a checkerboard pattern drawn in the image")
    A("")
    A("The importer refuses a transparent-type asset that arrives fully opaque, so a bad export")
    A("gets caught before it reaches the game.")
    A("")
    A("### Locking the Midjourney style")
    A("")
    A("Generate `menu_key_art.png` first. Once you have one you like, take its `--sref` code and")
    A("append it to every later Midjourney prompt. That is what makes the opaque set look like one")
    A("game instead of separate paintings.")
    A("")
    A("---")
    A("")

    def emit(group, title, note, builder):
        A("# %s" % title)
        A("")
        A(note)
        A("")
        by_section = {}
        for a in group:
            by_section.setdefault(a["section"], []).append(a)
        for sec, rows in by_section.items():
            A("## %s" % sec)
            A("")
            for a in rows:
                A("### `%s`" % a["file"])
                A("")
                A("`%d x %d`  ->  `%s`" % (a["w"], a["h"], a["path"]))
                A("")
                A("```text")
                A(builder(a))
                A("```")
                A("")
        A("---")
        A("")

    def chat_builder(a):
        path = a["path"]
        display = max(a["w"], a["h"])
        if (path.startswith("res://art/hero/") or path.startswith("res://art/enemies/")
                or path.startswith("res://art/bosses/")
                or "chieftain_" in path or "captive_" in path):
            stem = CHARACTER_STEM
        elif path.startswith("res://art/icons/"):
            stem = ICON_STEM
        elif path.startswith("res://art/ui/"):
            stem = UI_FRAME_STEM
        else:
            stem = STRUCTURE_STEM
        return stem.format(display=display) + S[a["file"]]

    emit(chat, "ChatGPT prompts - transparent background",
         "Paste the whole block, including the SUBJECT line. Every one of these needs a real "
         "alpha channel.",
         chat_builder)

    def mj_builder(a):
        subj = S[a["file"]]
        if a["path"].startswith("res://art/terrain/"):
            return MJ_TILE.format(subject=subj)
        out = MJ_OPAQUE.format(subject=subj)
        if a["w"] == a["h"]:
            out = out.replace("--ar 16:9", "--ar 1:1")
        return out

    emit(mj, "Midjourney prompts - opaque",
         "Terrain tiles use `--tile` and should be checked by tiling them 2x2 before use.",
         mj_builder)

    A("# Checklist")
    A("")
    A("| # | File | Size | Tool |")
    A("|---|------|------|------|")
    for i, a in enumerate(sorted(assets, key=lambda x: x["path"]), start=1):
        A("| %d | `%s` | %d x %d | %s |" % (i, a["file"], a["w"], a["h"],
                                            "ChatGPT" if a["t"] else "Midjourney"))
    A("")

    io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(L))
    print("wrote %s" % OUT)
    print("  %d assets: %d ChatGPT, %d Midjourney" % (len(assets), len(chat), len(mj)))


main()
