# Core Keeper: what to adopt, adapt or refuse, 2026-09-23

The owner asked what Wilderhold can take from [Core Keeper](https://store.steampowered.com/app/1621690/Core_Keeper/)
(Pugstorm, Unity, 1.0 in August 2024): its systems first, and then, in detail,
what makes it look and feel so polished. Owner rulings on 2026-09-23: **no idols**,
and "you know best what to implement, adapt, reject". This document is the
triage. It records what was built the same day, and what comes next, in order.

## 1. What makes Core Keeper polished

Studied from its store page, its wiki, and reviews that single out its presentation.

1. **Light is the art direction.** The game is 3D internally, which is how its
   lighting works. Lights have intensity and direction, and since 0.5.2 the
   indirect (bounce) light "takes surface color into account, resulting in
   softer, more saturated dynamic lighting". Darkness is the canvas: glowing
   tulips and ores punctuate it, and glow is a stat that food and equipment can
   raise. Reviewers say screenshots "do not do it any justice on the lighting".
2. **Cozy against creepy.** A small lit base in a dark world is "warm and cozy"
   without effort. The contrast *is* the mood, and the light marks safety.
3. **Tactile feedback.** "Items pop and walls bend when struck" is how one
   review sums up the moment-to-moment feel: a dopamine loop built from small
   reactions.
4. **Every biome its own palette, mood and music**, with the music "alternating
   between calm melodies in safe zones and intense, suspenseful compositions in
   more dangerous areas".
5. **You look like what you wear.** Armour changes the character. Vanity
   pieces and a Dresser act as transmog. Character creation covers body type,
   skin, hair style and colour, eye colour, and shirt and pants colour, and a
   Magic Mirror changes them later.
6. **Palette discipline.** About ninety colours, organised by hue family. That
   is why a thousand props read as one world.
7. **Charm in motion**: endearing idles, moving water, pets that follow.
8. **World building is its thinnest layer.** Ruins, titans, an ancient core;
   one reviewer notes it "lacks the historical and mythological sense" of its
   peers. Wilderhold's canon already outweighs it, so this is not an area to copy.

## 2. Already in Wilderhold

Checked in the code before anything was proposed, per the rule this project
keeps relearning:

| Core Keeper | Wilderhold, under its own name |
|---|---|
| Walls bend, items pop | Gather nodes recoil toward the swing and shed chips; towers pulse and spark when struck; the town squashes and flashes |
| Dynamic lights, darkness | `LightKit` lights that follow `DayNight`; lit dungeons with sconces; fog of war |
| Biome identity | Eleven regions, each with ground, backdrop, faction, ambience bed and battle track |
| Skills that level by use | Five crafts: Angler, Woodcutter, Miner, Smith, Farmer |
| Pets, breeding, fishing, farming | Spirit companions, the pen, families and nests, the ponds, the plots |
| Titans | A boss per act with slams, volleys and phases |
| Character colours | Two dyes, cloak and sash |
| Co-op | Up to four, drop-in, rejoin |

## 3. Built on 2026-09-23

Each changes presentation only. `polish_check` holds all three, and was shown
to fail by planting a glow lit at noon.

1. **The music settles when the road is safe.** During Preparation on the
   battlefield the music bus eases through a low-pass and a small trim, as if
   heard from inside the walls; a wave opens it back up over three seconds. It
   is the same song, and neither the player's slider nor the post-boss hush
   moves. A raid is never a safe place. Building it found a real bug: a fade
   that skipped every small step stalled at a high frame rate.
2. **Flowers glow at night.** About 45% of the flower, blossom, wildflower and
   mushroom patches carry a soft additive halo behind the plant. Its colour is
   read off the petals (an orange flower glows orange), it fades in with the
   dark, and each breathes on its own clock. Halos are sprites rather than
   lights, capped at 90 a field; 82 on the test seed.
3. **You look like what you wear.** A set worn in full puts its own colour on
   the Warden's cloak - the colour its ring already turns in at the feet - but
   only on a cloak the player left undyed. Every place this machine draws or
   sends its own Warden (the road, the Hold's seats, the lobby, a partner's
   screen) uses the worn look, so everyone sees the same Warden.

## 4. Systems, decided

**Adopt, in this order:**

1. **Claim a seam: the drill you defend.** During Preparation, build a drill on
   an ore seam in the outskirts. It pays that seam's materials every wave it
   stands, and a share of each wave peels off to break it. This is the "enemies
   that attack the board, and objectives only the Warden can answer" fix from
   `DESIGN_DIRECTION_2026-09-22.md`, built from things the game already has:
   seams, structures, siege targeting. Bounds to write before the code: it
   yields materials and nothing else, it is run-scoped, the host decides it, and
   the share it pulls is a share of the wave rather than extra bodies. Needs one
   structure painted in idle and working states.
2. **A talent at every tenth craft level**, a choice between two, each touching
   only its own craft - the Angler's wider bite window *or* its rarer fish.
   Crafts become builds, and the bound every craft lives under is unchanged.
3. **A Sandbox road.** Every tower, a full purse, any act, any battlefield, and
   nothing paid to the account. It is Core Keeper's Creative mode, and the
   fastest way to test the map modes shipped today.
4. **Two-ingredient cooking at the town's hearth**: a fish from the pantry
   plus a crop grown *this* run makes a dish carrying both effects. This is the
   exact condition CLAUDE.md set for cooking to return: several materials into
   something the road cannot drop, an effect other than more health, and still
   counted against `FISH_MEALS_PER_RUN`. It also makes farming worth the plot.

**Adapt later (1.1):** decorating the Hold (cosmetic, persistent, low risk);
soft-rock and ore walls in rift mazes that a practised Miner can dig for
shortcuts and gems.

**Refuse:**
- **Idols.** Owner ruling.
- **Digging the battlefield.** Every system reads the fixed road lattice.
- **Dropping your inventory where you die.** Gear persists here.
- **Eight-player servers.** Co-op is scoped to a small party.
- **Conveyor factories.** A second game.
- **Glow radius as a stat.** The fog hides and never helps: a stat that let a
  player see further would be the fog feeding the fight.

## 5. The visual roadmap from here

**All six built on 2026-09-24** (owner: "all of these"). Two departures, both
for a reason: the third dye is the *leather*, because the metal trim shares its
hues with the lantern and the leather has a clean band of its own; and the
normal maps are not files - the shader reads the relief off each frame, so every
tower frame is covered without a single sheet redrawn. See CLAUDE.md, "The
visual pass that followed".

In order of how much of Core Keeper's look each buys for its cost:

1. **Warm safety at the town.** A broad warm pool of light round the town
   through the night, so the base reads as shelter against a dark field -
   Core Keeper's cozy contrast, and one light.
2. **Light that takes the ground's colour.** A faint second pool under torches
   and structures, tinted by `GroundTone`: the cheap version of bounce light.
   Budget it against `perf_check`, since only every second torch carries a real
   light today.
3. **Seams and gems that glow at night**, like its ores: the same halo as the
   flowers, in the material's colour.
4. **Normal-mapped sprites**, so lights shade the art directionally. This is the
   single largest step toward its look and the most expensive: normals would be
   generated from each sprite's silhouette. Pilot on the towers, photograph, and
   judge by eye before rolling out.
5. **Customisation depth.** A third dye (the metal trim) and a set of preset
   swatches are cheap. Hair and body options mean redrawing every sheet, so each
   is a budget decision to pilot on one direction first, as the mount idles were.
6. **A palette audit per region**: a contact sheet of every sprite in a region
   against that region's own ramp, because no gate can see a palette.

## 6. The map, which is the P0

The authored battlefield is a pinwheel: 100% symmetric under a quarter turn,
44% under its own mirror. Six mirror-symmetric layouts and Random (any layout
but Classic, varied from the seed) shipped today as settings. **The default is
still Classic**, because the ruling was to add and preserve. Moving the default
to a symmetric layout, or to Random, before anybody outside plays is now a
one-line change.
