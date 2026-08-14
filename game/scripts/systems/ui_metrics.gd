class_name UiMetrics
extends RefCounted

## The interface's spacing numbers, in the one place both halves can reach.
##
## These are used by two things that cannot see each other:
##
## * `tools/theme_builder.gd`, which bakes them into `ui_theme.tres`. It runs
##   under `run_tool.gd`, which replaces the main loop — so **no autoload
##   exists** and it cannot read `Balance`.
## * `scenes/ui/hud.gd`, which lines runtime-positioned children up with the
##   padding the theme already applies. It ships, and `export_presets.cfg`
##   excludes `tools/*` — so it cannot read `ThemeBuilder`.
##
## That second one is not hypothetical. The HUD held
## `const BUILD_ROW_PRICE_INSET := float(ThemeBuilder.PAD_BUTTON_X)` for exactly
## one release. In the editor it was fine. In an exported build `ThemeBuilder` is
## not in the .pck, so `hud.gd` failed to *parse* — which meant no HUD at all and
## no tower slot ever wired to a click handler. Every headless gate passed,
## because every headless gate runs from source.
##
## So: anything both the theme and the running game need to agree about lives
## here, in `scripts/`, which ships.

# --- Padding -----------------------------------------------------------------
#
# One set of numbers for the whole interface rather than a judgement call at each
# call site. Every frame in the art has a decorative border with bolts in the
# corners, and content has to clear the bolts, not the straight run of frame
# between them — so these are measured against the deepest intrusion.
#
# Symmetric on both axes. Asymmetric padding is invisible until you notice it,
# and then it is the only thing you can see.

## Buttons. 34 clears the corner bolt on `ui_button`; 14 centres a 17px line in a
## 42px row instead of leaving it sitting low in its box.
const PAD_BUTTON_X: int = 34
const PAD_BUTTON_Y: int = 14

## The ornate panel frame is the deepest in the set — its corner pieces reach
## about 40px in, so less than this puts a heading on the ironwork.
const PAD_PANEL_X: int = 38
const PAD_PANEL_Y: int = 32

## The spell slot's own frame, as a fraction of the drawn size.
##
## `ui_slot.png` is a riveted border around a dark interior, and its border is
## about 23% of the width. Content was being placed 13px from the edge of a
## 118px slot - well inside the ironwork - so icons and names sat on the frame
## rather than in it.
##
## A fraction rather than pixels because the slot is drawn stretched: a fixed
## inset would be right at one size and wrong at every other.
const SLOT_INSET_X: float = 0.23
const SLOT_INSET_Y: float = 0.20

## The plain dark frame is a thin border and needs far less.
const PAD_DARK_X: int = 20
const PAD_DARK_Y: int = 16
