# Augment content pass — staged, waiting on icons (2026-09-26)

Thirty-one augments and one keystone, taking the deck from 29 cards to 61
(`docs/SKILL_TREE_REWORK_2026-09-26.md` §8.7 item 5). **Staged rather than
built because the art cannot be made yet**: PixelLab's allowance for the cycle
is spent (0 generations, no credits; it resets on 2026-10-11), and the
production-art gate (`run_tool.gd -- report`, guard and release) fails any
placeholder. Shipping reused art from another asset class, or a placeholder,
was the alternative and was refused.

## What is here

- `*.tres` — the 32 cards, ready to copy into `game/data/road_cards/`.
- `icons.json` — the subject of each card's icon, by id.
- `content_cards.py` — the generator the `.tres` files came from.

## To land it

1. **Icons.** `create_image_pro_flash`, 128x128, `no_background`, with a shipped
   card icon as `style_image` (raw GitHub URL of
   `game/art/icons/road_cards/card_<similar>.png`) and
   `style_options: {color_palette: false, outline/shading/detail: true}`. Pilot
   two before the batch and contact-sheet them beside the shipped 29. Save to
   `game/art/icons/road_cards/card_<id>.png`, add each to `ASSET_MANIFEST.md`
   §5.13e, and `--import`.
2. **The five new `Modifiers` keys are already wired** (2026-09-26, later):
   `tower_rate`, `trap_damage`, `spell_power`, `mana_regen` and
   `companion_damage` have their labels, their readers, the ledger's key lists
   and `tower_rate`'s own ceiling (0.25), and `augment_check` refuses a key the
   table resolves that nothing reads. Add the five to `road_card_check`'s
   direction table (all help the player) when the cards land.
3. **`keystone_mortar`** (Mortar on the March, Hearth, `branch_needs = 6`): on
   `road_rank_gained`, the battlefield heals the town by
   `Balance.TOWN_REPAIR_AMOUNT` - the Wood repair re-routed onto the rank, its
   size unchanged. Host only; the wall already relays.
4. **The curve.** `curve_report` already reads `tower_rate` in the capability
   line and pours the modelled hand into it after tower damage, so the moment
   the rate cards land the band will say how much they bought. Re-tune the
   density against it - an augment the model does not carry is forbidden.

## The list

| Branch | Card | Key | Magnitude | Rarity | Act |
|---|---|---|---|---|---|
| Warden | Honed Edge | hero_damage | 0.06 | Common | I |
| Warden | The Oathblade | hero_damage | 0.26 | Epic | VII |
| Warden | Deep Breath | mana_regen | 0.12 | Common | I |
| Warden | Wellspring Draught | mana_regen | 0.30 | Rare | IV |
| Warden | Ink of the Road | spell_power | 0.12 | Uncommon | II |
| Warden | The Loud Word | spell_power | 0.22 | Rare | IV |
| Warden | Grand Incantation | spell_power | 0.30 | Epic | VII |
| Warden | Pack Bond | companion_damage | 0.16 | Uncommon | II |
| Warden | The Alpha's Due | companion_damage | 0.28 | Rare | V |
| Warden | Iron Lungs | hero_max_hp | 0.14 | Uncommon | II |
| Warden | Hard-Road Boots | hero_speed | 0.12 | Uncommon | III |
| Warden | Legend's Heart | hero_max_hp | 0.40 | Legendary | IX |
| Rampart | Oiled Gears | tower_rate | 0.05 | Common | I |
| Rampart | Double Crews | tower_rate | 0.09 | Uncommon | II |
| Rampart | The Drill Sergeant | tower_rate | 0.14 | Rare | IV |
| Rampart | Sharpened Stakes | trap_damage | 0.10 | Common | I |
| Rampart | Caltrop Masters | trap_damage | 0.18 | Uncommon | III |
| Rampart | The Killing Ground | trap_damage | 0.30 | Rare | V |
| Rampart | Pitch and Tar | burn_damage | 0.40 | Rare | V |
| Rampart | Frostbitten Iron | slow_strength | 0.40 | Rare | V |
| Rampart | Masterwork Arsenal | tower_damage | 0.30 | Epic | VII |
| Rampart | Rampart of Legend | tower_armour | 0.35 | Epic | VI |
| Rampart | The Storm Coil | chain_targets | 2 | Epic | VIII |
| Rampart | The Great Gate | town_max_hp | 0.35 | Epic | VII |
| Hearth | Tithe Collector | kill_resources | 0.25 | Uncommon | II |
| Hearth | Full Granary | resource_rate | 0.25 | Uncommon | II |
| Hearth | The Caravan Road | resource_rate | 0.40 | Rare | IV |
| Hearth | Haggler's Knack | build_cost | -0.20 | Rare | IV |
| Hearth | Quick Muster | raid_charge | 0.50 | Rare | V |
| Hearth | Long Sight | wave_foresight | 2 | Rare | VI |
| Hearth | The Beast's Stride | beast_speed | 0.25 | Rare | V |
| Hearth | Mortar on the March | keystone_mortar | — | Rare keystone, 6 Hearth | III |

Every card text is new player-facing copy and was written against GDD §57; read
it again before it ships.
