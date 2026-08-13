"""Split the approved generated UI sheets into padded runtime assets."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def split(source: Path, boxes: list[tuple[int, int, int, int]], names: list[str],
          destination: Path, canvas: int) -> None:
    image = Image.open(source).convert("RGBA")
    destination.mkdir(parents=True, exist_ok=True)
    for box, name in zip(boxes, names, strict=True):
        part = image.crop(box)
        bounds = part.getchannel("A").getbbox()
        if bounds:
            part = part.crop(bounds)
        target = canvas - 12
        scale = min(target / part.width, target / part.height)
        part = part.resize(
            (max(1, round(part.width * scale)), max(1, round(part.height * scale))),
            Image.Resampling.LANCZOS,
        )
        output = Image.new("RGBA", (canvas, canvas))
        output.alpha_composite(part, ((canvas - part.width) // 2, (canvas - part.height) // 2))
        output.save(destination / name)


split(
    ROOT / "art_inbox/generated/beastroad_hud_icons_transparent.png",
    [(0, 0, 887, 887), (887, 0, 1774, 887)],
    ["ui_hero_health.png", "ui_wounds.png"],
    ROOT / "game/art/icons/ui",
    128,
)
split(
    ROOT / "art_inbox/generated/beastroad_cursor_sheet_transparent.png",
    [(index * 362, 0, (index + 1) * 362, 724) for index in range(6)],
    [
        "cursor_default.png", "cursor_point.png", "cursor_build.png",
        "cursor_attack.png", "cursor_repair.png", "cursor_busy.png",
    ],
    ROOT / "game/art/cursors",
    64,
)

discipline_names = {
    "blood": [
        "hemorrhage_edge", "red_pursuit", "sanguine_guard", "marrow_drain",
        "hunters_pulse", "open_vein", "crimson_tempest", "blood_remembers",
    ],
    "holy": [
        "consecrated_chain", "judgment_brand", "aegis_step", "bulwark_ward",
        "vigil", "mercy_under_fire", "dawn_bell", "unbroken_oath",
    ],
    "berserk": [
        "cleaving_road", "chain_hook", "iron_roar", "tremor",
        "rising_fury", "no_ground_given", "beasts_breath", "break_the_host",
    ],
}
for discipline, names in discipline_names.items():
    source = ROOT / f"art_inbox/generated/discipline_{discipline}_transparent.png"
    image = Image.open(source)
    width, height = image.size
    cell_w, cell_h = width // 4, height // 2
    boxes = [
        (column * cell_w, row * cell_h,
         width if column == 3 else (column + 1) * cell_w,
         height if row == 1 else (row + 1) * cell_h)
        for row in range(2) for column in range(4)
    ]
    split(
        source,
        boxes,
        [f"discipline_{name}.png" for name in names],
        ROOT / "game/art/icons/disciplines",
        192,
    )

# Regional enemy atlases use a 3x2 grid and are composited to a generous 192px
# runtime canvas. Godot scales by authored role/category, so retaining detail
# here avoids the muddy 96px source ceiling without changing collision sizes.
enemy_families = {
    "verdant": [
        "coalpaint_raider", "wolf_rider", "rootshield", "ember_shaman",
        "pack_howler", "wolf_standard_bearer",
    ],
    "sunglass": [
        "veiled_skirmisher", "scale_rider", "glassguard", "dune_burrower",
        "mirage_seer", "siege_lizard",
    ],
    "white_teeth": [
        "rime_marauder", "ice_hauler", "snowhide_brute", "storm_caller",
        "avalanche_warden", "white_maw_giant",
    ],
}
for family, names in enemy_families.items():
    source = ROOT / f"art_inbox/generated/enemies_{family}_transparent.png"
    if not source.exists():
        continue
    image = Image.open(source)
    width, height = image.size
    cell_w, cell_h = width // 3, height // 2
    boxes = [
        (column * cell_w, row * cell_h,
         width if column == 2 else (column + 1) * cell_w,
         height if row == 1 else (row + 1) * cell_h)
        for row in range(2) for column in range(3)
    ]
    split(
        source,
        boxes,
        [f"enemy_{name}.png" if index < 4 else f"elite_{name}.png"
         for index, name in enumerate(names)],
        ROOT / "game/art/enemies",
        192,
    )
