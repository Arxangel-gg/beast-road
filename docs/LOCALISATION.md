# Keeping translation possible

**Written 2026-09-26.** Wilderhold 1.0 ships in English, and that is fine. This
is about not painting a later translation out: what it would take today,
measured, and the few rules that keep the cost from growing while nobody is
translating anything.

## What a translation would be handed

`python tools/extract_strings.py <out.pot>` writes every string a player reads
as a gettext template. On 2026-09-26:

| Where | Strings |
|---|---|
| Data files (names, descriptions, the Guide, lore, cards, portents, tutorial) | 2,389 |
| Text the interface sets on its controls | 197 |
| Text formatted before it reaches a control | 142 |
| Places a script draws text itself | 12 |
| **Total** | **about 2,700 strings, 27,000 words** |

At common rates for game translation that is a few thousand dollars a language,
before review and a play-through in that language.

## Why most of it needs no code change

Godot translates the text of a `Label`, a `Button` or any other control on its
own when a loaded translation holds that exact English string - every control
auto-translates unless told not to. Working rule 9 already keeps player-facing
words in data, and the data reaches the screen through those controls. So for
the 2,389 data strings and the 197 interface strings, **a `.po` file keyed by
the English is the whole job**: load it, and the words change.

## What does need code

- **Formatted strings (142).** `"%d of %d done" % [a, b]` is formatted before the
  control sees it, so the finished sentence never matches anything. Each needs
  its format string wrapped: `tr("%d of %d done") % [a, b]`. The template marks
  every one with its file and line.
- **Drawn text (12).** A `_draw` that calls `draw_string` bypasses the controls
  entirely: the names on the pool bars (`BarName`), the act track, the sundial,
  the revive bar, the placement cursor and the thumb sticks' labels. The damage
  numbers on the effects canvas and the climate's F7 debug view draw too, but
  numbers and a developer's view need no translation. Each of the others needs
  `tr()` on what it draws.
- **Plurals.** "1 Warden" and "2 Wardens" built by hand do not survive a
  language with three plural forms. `tr_n()` exists for this.

## The fonts

The body face (Atkinson Hyperlegible Next) and the display face (Cinzel) cover
Latin only. Both fall back to Alegreya (`UiFonts`), which covers Latin
Extended, Cyrillic, Greek and Vietnamese - so those languages would render, in a
mixed face. **Chinese, Japanese and Korean have no glyphs at all.** They would
need a CJK fallback font, which is large (a Noto CJK subset is several
megabytes to tens of megabytes) and a download-size decision.

## The layout

German and French run 20 to 40 percent longer than English. The interface has
fixed widths in places - the phone HUD's tiles, the ability slots, the build
rows - and `layout_check` only measures the English. A pseudo-locale that pads
every string (`[Ŵåŕđéñ'š Ĝļåšš~~~~]`) run under `layout_check` would find
every place a longer language breaks, before anybody translates a word.

## The rules that keep the cost from growing

1. **Keep words in data**, as working rule 9 already says.
2. **Never build a sentence out of pieces.** `"Build " + name + " for " + cost`
   cannot be reordered by a translator; one format string can.
3. **Wrap a new format string in `tr()`** when it is written. It costs nothing
   in English, and it is one of 142 fewer later.
4. **Do not draw text in `_draw` when a control would do.** Where it must be
   drawn (a label on a thin bar), wrap it in `tr()`.
5. **Leave room.** A button sized to its English label will be too small in
   German.

## Not decided

Which languages, if any, and when. That is the owner's call, and it can wait
for 1.0 to ship; what cannot wait is breaking the rules above until then.
