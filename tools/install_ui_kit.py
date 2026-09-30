"""Install the Emberbound UI kit's exports under runtime names.

Copies (never moves) from art_inbox/chatgpt/ui, checking each source file's
sha256 against the kit's own manifest first, and brings docs/ASSET_MANIFEST.md
5.17 in line. The inbox is left exactly as it was - it is the only master.

The compact buttons and the focus frame are resampled down from the kit's 2x
export rather than copied at 1x: the kit drew them at 64 px tall with 20 px
horns, and this game's buttons are 34-54 px tall, where a 20 px horn is half
the button. At 0.75 the horn is 15 px and a 34 px button still holds both."""
import hashlib, json, os, shutil
from PIL import Image

REPO = r'E:\Arxangel\GameDev\BeastRoad'
INBOX = os.path.join(REPO, 'art_inbox', 'chatgpt', 'ui')
ART = os.path.join(REPO, 'game', 'art', 'ui')
MANIFEST = os.path.join(REPO, 'docs', 'ASSET_MANIFEST.md')

BUTTON = (192, 48)
FOCUS = (96, 96)

# runtime name, kit id, target size (None = the 1x export as delivered), colour
MAP = [
    ('ui_button', 'eb_button_secondary_normal', BUTTON, '#1E3440'),
    ('ui_button_hover', 'eb_button_secondary_hover', BUTTON, '#2A4654'),
    ('ui_button_pressed', 'eb_button_secondary_pressed', BUTTON, '#14242C'),
    ('ui_button_disabled', 'eb_button_disabled', BUTTON, '#242C30'),
    ('ui_button_primary', 'eb_button_primary_normal', BUTTON, '#7A4410'),
    ('ui_button_primary_hover', 'eb_button_primary_hover', BUTTON, '#955418'),
    ('ui_button_primary_pressed', 'eb_button_primary_pressed', BUTTON, '#5A300A'),
    ('ui_button_danger', 'eb_button_danger_normal', BUTTON, '#6A1C18'),
    ('ui_button_danger_hover', 'eb_button_danger_hover', BUTTON, '#842420'),
    ('ui_button_danger_pressed', 'eb_button_danger_pressed', BUTTON, '#4A1210'),
    ('ui_panel', 'eb_panel_main', None, '#14262C'),
    ('ui_panel_dark', 'eb_panel_dark', None, '#0E1C22'),
    ('ui_panel_inset', 'eb_panel_inset', None, '#10222A'),
    ('ui_panel_tooltip', 'eb_panel_tooltip', None, '#0E1E24'),
    ('ui_slot', 'eb_slot_normal', None, '#14262C'),
    ('ui_slot_selected', 'eb_slot_selected', None, '#1C2E34'),
    ('ui_focus_frame', 'eb_focus_frame', FOCUS, '#E8A33D'),
]

kit = json.load(open(os.path.join(INBOX, 'asset_manifest.json'), encoding='utf-8'))
by_id = {a['id']: a for a in kit['assets']}


def delivered(kit_id, scale):
    entry = next(d for d in by_id[kit_id]['delivery'] if d['scale'] == scale)
    source = os.path.join(INBOX, entry['path'].replace('/', os.sep))
    digest = hashlib.sha256(open(source, 'rb').read()).hexdigest()
    assert digest == entry['sha256'], (kit_id, scale, 'sha256 differs from the kit manifest')
    return source, entry


rows = {}
for runtime, kit_id, size, colour in MAP:
    target = os.path.join(ART, runtime + '.png')
    if size is None:
        source, entry = delivered(kit_id, 1)
        shutil.copyfile(source, target)
        size = (entry['width'], entry['height'])
    else:
        source, _entry = delivered(kit_id, 2)
        # Premultiplied while resampling, so the transparent rim's colour does
        # not bleed a dark fringe into the frame's edge.
        image = Image.open(source).convert('RGBa')
        image = image.resize(size, Image.LANCZOS).convert('RGBA')
        image.save(target)
    rows[runtime] = '| `%s.png` | %d\u00d7%d | T | `%s` |' % (runtime, size[0], size[1], colour)
    print('installed', runtime, size, '<-', kit_id)

lines = open(MANIFEST, encoding='utf-8').read().split('\n')
out = []
seen = set()
for line in lines:
    for runtime, row in rows.items():
        if line.startswith('| `%s.png` |' % runtime):
            out.append(row)
            seen.add(runtime)
            break
    else:
        out.append(line)
# New rows go straight after ui_slot.png, inside 5.17 and nowhere else.
anchor = next(i for i, l in enumerate(out) if l.startswith('| `ui_slot.png` |'))
missing = [rows[r] for r, *_ in MAP if r not in seen]
out[anchor + 1:anchor + 1] = missing
open(MANIFEST, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('manifest: %d rows changed, %d added' % (len(seen), len(missing)))
