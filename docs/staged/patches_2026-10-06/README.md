# Staged patches, 2026-10-06

Two owner items written as patch scripts and **not applied**, because the
session that wrote them ran out before they could be gated and photographed.
Each is a `patchlib.patch(rel, [(old, new), ...])` script: every `old` must
occur exactly once under `game/` or the script aborts without writing, and
the file's own line endings are kept.

    cd game
    python ../docs/staged/patches_2026-10-06/p_rail.py
    python ../docs/staged/patches_2026-10-06/p_hold_doors.py

- **`p_rail.py` - the build sheet's element tabs are the element's mark on a
  thumb** (owner item 31). The rail spent 150 units of a phone's sheet on four
  names a glyph already says; on a touch layout each tab becomes a
  `ELEMENT_TAB_TOUCH_SIZE` square of the mark with its `x/10` count in the
  foot, the name in the tooltip. Gate: `road_sheet_check` at all four shapes
  (it reads the tab's count off the `unlocked` meta now rather than the text).
  Photograph: `phone_hud_shot -- --viewport=1280x592` and `430x932`, the
  sheet states.
- **`p_hold_doors.py` - the Guide, the trailer, co-op and the Wardens move
  into the Hold** (owner item 33): four stations in `HoldYard.STATIONS` bound
  to the menu's own buttons through `HubScreen.adopt`, so each door's handler
  and its way back are untouched; the front door keeps the road, the first
  Walk, the Hold, Settings and Quit. Gate: `hold_check` (a new stage,
  `four_doors`, is in the patch), `menu_check`, `menu_layout_check`,
  `pad_focus_check`, `mobile_fit_check`. Photograph: `hub_shot`. **Read the
  station cells against `hold_shot` before trusting them** - the four cells
  were chosen from the yard's shelves by reading the layout, not by a
  photograph, and this project's record on placement by number is poor.

Both scripts anchor on text as it stood at commit 73dd5db6; if an anchor no
longer matches, `patchlib` says which and writes nothing.
