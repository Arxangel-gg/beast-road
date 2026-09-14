Anything else to discuss or ideas to consider?
Yes — there are still a handful of important decisions around extraction, storage, co-op, and the economy that I’d settle before Claude hardens the architecture. These are less flashy than disasters or skills, but they’ll determine whether the whole persistent loop feels clean or frustrating.
The biggest ones I’d add are:
Account-wide Vault, not character-specific. Unless Wilderhold is deliberately built around multiple isolated characters, everything safely extracted should go into one persistent account Vault. Skills/loadouts can differ, but forcing players to shuffle resources between characters would mostly create friction.
Craft directly from the Vault while at the Hold. Don’t make players withdraw 40 Iron just to walk five feet to the forge. Outside runs, crafting/building/upgrading should automatically consume eligible Vault materials. The Expedition Stash is only for deciding what enters danger.
Resource reservation. When the player selects a crafting recipe or saved expedition preset, the UI can show exactly what resources are missing without actually moving anything until confirmed.
Favorites / locked items. Players need a way to mark items as Favorite, Never Sell, Never Salvage, or Never Auto-Transfer. Extremely important once the Vault gets large.
Auto-deposit after extraction. Successful extraction should immediately bank cargo. No awkward “claim 73 items individually” screen.
Extraction summary. Give a satisfying post-run report: brought in, gathered, spent, secured, extracted, lost, XP earned, skill gains, blueprints discovered, market value of loot, major disasters survived, etc.
Item provenance. Particularly for rare items: Found during Act III, Crafted by X, Recovered from Lost Expedition, Meteor Impact, etc. It adds personality and also helps future economy auditing.
Protected quest/story items. Anything required for progression should never be permanently lost. Either it is automatically secure or losing it causes it to respawn/reappear.
Bound-item categories. Make the distinction explicit: Tradable, Account-Bound, Run-Bound, and perhaps Bind-on-Use where appropriate. This matters enormously if the Exchange arrives later.
Stack splitting and quick transfer. Move All, Move Half, Move X, Fill Stack, Restock, Deposit All, and drag-and-drop. Inventory UX will matter a lot.
Search/filter/sort. By skill, rarity, type, element, tradability, crafting use, newest, value, quantity, etc.
Vault categories instead of hundreds of loose slots. Materials, Gear, Consumables, Seeds, Relics, Blueprints/Fragments, Tools. Make it feel like a proper bank rather than a giant backpack.
Infinite-ish basic-material storage. Wood, stone, common ore and similar commodities should probably use very high or effectively unlimited Vault stack sizes. Storage management should come from expedition risk, not the player deleting basic materials.
Rare-item capacity can remain meaningful. If you want some storage expansion progression, use it for gear/unique-item space rather than forcing people to buy 40 extra slots for stone.
One especially important system is run abandonment. If someone chooses Abandon Expedition, that should count as a failed extraction, not a free teleport home. Otherwise the player can avoid every dangerous extraction by quitting manually.
Crashes and disconnects should be different. I’d design rules like this: if the game/server can verify an accidental disconnect, the player gets a reconnect window. If they reconnect, they return to that expedition. If the entire session dies because of a server-side failure, ideally restore the pre-run snapshot or conservatively return affected cargo rather than punish the player. Technical failure should never masquerade as gameplay risk.
Co-op also needs a clean answer for who owns loot. I’d favor personal loot for equipment/rare drops plus a voluntarily shared construction pool for common resources. That avoids fighting over Legendary drops while preserving the cooperative tower economy. If a rare world object genuinely produces one unique item, either roll ownership transparently, rotate priority, or generate per-player eligible rewards rather than “first person to click wins.”
I’d also consider Extraction Crates during Acts. Not full Vault access—never that—but perhaps a very rare consumable or expensive Engineering structure that lets players permanently ship a tiny amount of cargo home mid-run. Something like one small crate per expedition could create another strategic decision:
Send the Meteorsteel home now, or keep the crate in case we find something even better?
That is different from the Secure Pouch because it physically removes the resource from the expedition and frees carrying capacity.
Another great system would be resource conversion at Act transitions. Instead of bringing thousands of low-tier materials deeper, players can sometimes refine them:
100 Scrap → 10 Refined Components
The same economic value becomes more compact, rewarding Smithing/Engineering and reducing inventory pressure naturally.
Let preparation have opportunity cost
I’d avoid letting the player fill every Expedition Stash slot with everything they might conceivably need.
The interesting choice is:
Do I bring extra food?
Seeds?
Repair metal?
Anti-flood equipment?
Rare ammo?
Building materials?
A spare tool?
The stash is compelling because choosing one thing means not choosing another.
That also gives difficulty meaning. On Hell, players may sacrifice a resource slot for emergency disaster protection because they know how badly things can go.
Consider “Supply Value” in addition to slots
You may eventually discover that slots alone are exploitable:
One stack of 999 Wood = one slot.
One Legendary component = one slot.
If that becomes a problem, each Expedition Stash can also have a loose Supply Budget.
For example:
Common materials = tiny supply value
Consumables = moderate
Rare crafting materials = high
Large construction components = very high
You then constrain both:
slot count + total supply value
I would only add this if playtesting shows stack exploits, though. Start simpler.
Don't let extracted resources bypass progression
An extracted Level-90 material can sit safely in your Vault forever even if you can't use it yet.
That's actually good.
It creates aspiration:
“I found this strange meteor alloy at Level 32 Mining. I have no clue what to do with it yet.”
Later the player finally reaches the required skill and remembers that item they've been keeping for twenty hours.
Resource sinks should start now
Since you're building persistent storage, think about why resources ever leave the Vault:
Crafting
Repairs
Tower preparation
Engineering projects
Farming
Cooking
Herbalism
Settlement upgrades
Exchange fees
Blueprint research
Tool replacement/reforging
Every resource should ideally have at least two useful sinks, especially common materials. Otherwise max-level players eventually accumulate 200,000 wood with nothing to do with it.
I'd add one Hold system: Requests
NPCs or the Hold itself can periodically request resources:
Reconstruction requires 400 Stone and 80 Iron.
Contributing permanently removes materials but progresses settlement reconstruction, unlocks cosmetics/services, gives modest XP or reputation, etc.
This provides a natural sink that feels like building Wilderhold, not an arbitrary tax.
One potentially fantastic late-game system: Expedition Investment
Before leaving, players could optionally invest extra supplies into an expedition modifier.
For example:
Survey Expedition
Spend maps/materials → increased Archaeology sites.
Prospecting Expedition
Spend Mining supplies → richer geological opportunities.
Conservation Expedition
Spend Farming/Engineering resources → healthier starting ecology.
Fortified Expedition
Spend materials → start with limited prepared defenses.
High-Risk Expedition
Pay nothing, bring very little, but receive stronger reward modifiers.
That turns the Vault into more than a pile of resources—it becomes a way to shape the next run.
And there’s one rule I’d absolutely establish now:
The game must never destroy something valuable without clearly showing the player that it is currently at risk.
Vault = green/safe.
Secure Pouch = protected.
Expedition Stash = risk indicator.
Backpack = risk indicator.
Lost Cache = recovery possible.
Run-only item = visibly temporary.
No ambiguity.
If the player loses 40 Meteorsteel, they should think:
“I knew I was gambling that by continuing.”
not:
“Wait—why did the game delete my stuff?”
That difference will make or break whether the extraction layer feels exciting or punishing.


Taking inspiration from extraction games like arc raiders, what are your best inspiration ideas you recommend adapting for our game?


Yes — and I think we should be selective about what Wilderhold borrows. ARC Raiders’ strongest lesson is not “make Wilderhold an extraction shooter”; it’s how it turns every piece of loot into a decision about risk, preparation, value, and future progression. ARC currently uses bounded raid loadouts, protected Safe Pocket capacity, persistent Workshop/blueprint progression, danger-weighted loot, changing map conditions, quests/projects that require successful extraction, and rotating barter opportunities. ARC Raiders
These are the adaptations I think fit Wilderhold best:
Priority	Inspiration	Wilderhold adaptation
S	Danger = better loot	Create High-Risk Resource Zones. Rich ore veins, ancient forests, Legendary wildlife, rare fishing waters, Archaeology sites and high-tier chests appear disproportionately in dangerous areas or deeper Acts.
S	Safe Pocket	Keep our Secure Pouch, but make deciding what to protect one of the most important choices during an expedition. Rare blueprint? Meteor fragment? Legendary seed? Secure it—or gamble.
S	Extracted blueprints	Finding a blueprint does not automatically learn it. You must successfully secure/extract it. Once learned, the knowledge is permanent. This makes blueprint finds incredibly exciting. ARC uses this basic risk structure with extracted blueprints. ARC Raiders
S	Workshop progression	Build the persistent Hold around upgradable specialist facilities: Forge, Engineering Workshop, Farm, Kitchen, Herbalist, Archaeology Lab, etc. Skill level determines knowledge; facility level determines what infrastructure can actually produce.
S	Changing map conditions	Before entering, Wilderhold can show a broad Regional Condition: Heavy Rain, Drought, High Winds, Migration, Seismic Activity, Aurora, Flood Season, Meteor Shower, Deep Frost, etc. This affects loot, wildlife, disasters and strategies. ARC already uses rotating map conditions to alter deployments. ARC Raiders
S	Extraction decision	Your Act Extract-or-Continue design is even better suited to Wilderhold. Every completed Act becomes a temptation: bank everything now or carry the haul deeper for increasingly exceptional opportunities.
S	Loot with multiple purposes	Avoid “vendor trash.” Almost everything should feed crafting, skills, Hold upgrades, Engineering, Farming, quests/contracts, or trade. Players should hesitate before selling something because it might matter elsewhere.
A+	Free/basic loadouts	Add a Forager Expedition option. Players can enter with a free/basic kit if broke or unwilling to risk equipment. Lower preparation and capacity, but zero meaningful entry risk. Great recovery mechanic.
A+	Locked high-value areas	Rare Ancient Vaults, sealed mines, collapsed ruins, sanctums, abandoned Holds could require keys, Engineering, Archaeology, explosives/tools or environmental conditions to access. Better reward density inside.
A+	Field crafting	Allow limited expedition crafting: arrows/ammo, bandages, basic food, simple repairs, emergency bridges/firebreaks, perhaps temporary tools. Complex equipment stays Hold-only.
A+	Barter traders	Rotating NPC caravans could want specific goods rather than simply currency. “Bring 4 Meteorite Shards + 20 Fine Timber → rare Engineering blueprint.” ARC's Nomadic Envoy similarly trades high-value materials/gear for rotating rewards. ARC Raiders
A+	Projects	Add long-term Wilderhold Projects: rebuild a bridge network, restore an ancient forge, construct an observatory, establish irrigation, restore a sanctuary. They consume extracted resources over many runs and permanently alter/unlock the Hold.
A	Valuable quest cargo	Some contracts should require the object to actually make it home. Finding an ancient tablet isn't completion. Extracting with it is.
A	Loot prioritization	Backpack capacity should make players eventually ask: “Do I dump 40 Stone for this Ancient Core?” Not via tedious weight simulation—use your existing slots/stacks/capacity design.
A	Recycling	Unwanted equipment should be salvageable into useful crafting components rather than becoming meaningless trash. Higher Smithing/Engineering could improve salvage quality.
A	Hotspots	World events create temporary jackpot zones: crashed meteor, newly opened earthquake fissure, flooded ruin, Legendary migration, wildfire aftermath, storm-struck grove. High reward + environmental danger.
A	Extraction routes	Not every extraction should be identical. Some could require repairing an old gate, defending a caravan, activating a beacon, reaching a boat, restoring a lift, or surviving until a portal/road opens.
A	Threat generated by activity	Mining loudly, chopping ancient trees, firing powerful towers, opening ruins or performing Engineering could attract enemies/wildlife or increase local danger. The valuable activity itself creates pressure.
A	Rare rotating opportunities	Some Hold merchants/services could rotate weekly, offering unusual seeds, blueprints, cosmetics or resource exchanges. This gives extracted excess materials continued value.
B+	Prestige/reset	Much later, after Level 100, consider an optional Legacy Expedition where an expert voluntarily gives up some progression for prestige rewards. But this should be strictly optional and absolutely not part of 1.0.


The idea I think could be better than ARC Raiders for Wilderhold
Tie loot rarity directly to the living environment.
Instead of:
dangerous red zone = better random loot

Wilderhold can actually explain why something valuable exists there.
An earthquake exposes an ancient mineral vein.
A meteor creates Meteorsteel.
A flood exposes a buried ruin.
A wildfire reveals structures beneath a forest.
Lightning striking sand creates rare glass/crystals.
A Legendary creature establishes a territory containing unusual biological resources.
An extreme frost exposes something preserved beneath the ground.
A tornado tears open an inaccessible structure.
Suddenly the world simulation itself becomes Wilderhold's equivalent of a high-tier loot zone.
That is far more distinctive.
Dynamic map conditions could become enormous
Before an expedition, instead of only seeing:
NORMAL — ACT I
you might see:
ASHFEN EXPEDITION
Regional Conditions
High Winds
Severe Drought
Wolf Migration
Elevated Fire Wrath
Opportunities
Rare Fire Flora ↑
Ancient Timber ↑
Predator Wildlife ↑
Threats
Wildfire Risk ↑↑
Tornado Risk ↑
Water Availability ↓
Now players actually prepare their Expedition Stash around the forecast:
Bring water infrastructure?
Heat-resistant food?
Firebreak materials?
Hunting equipment?
Or perhaps they deliberately choose that region because they're farming Fire materials.
ARC Raiders currently surfaces changing map conditions as part of deployment planning; Wilderhold can take that concept much further because your climate/ecology simulation can make the conditions systemic rather than just modifiers. ARC Raiders
Add “valuable junk,” but make it Wilderhold junk
One thing extraction games do incredibly well is turning mundane objects into exciting finds because they have downstream purposes.
Wilderhold could have:
Broken Mechanism
Copper Fasteners
Ancient Gear
Animal Tendon
Resin Clump
Charred Heartwood
Flooded Manuscript
Weathered Cog
Fulgurite
Volcanic Glass
Old Nails
Fine Hide
Rare Spores
But every one should have at least one real sink.
No meaningless “sell for 18 coins” garbage category unless it's deliberately flavor loot.
Hold upgrades should consume enormous amounts of ordinary resources
This solves one of the biggest persistent-economy problems.
Your 8,000 Stone doesn't become worthless because the Hold might require:
Rebuild Eastern Wall
2,500 Stone
400 Iron
120 Hardwood
10 Engineering Components
Then perhaps:
Restore Ancient Greenhouse
Construct Weather Observatory
Expand Vault
Build Archaeology Wing
Upgrade Forge
Establish Caravan Market
These are effectively ARC-style long-term Projects translated into Wilderhold's world. ARC has continued using longer-term project/event structures in 2026, including progression tied to recovered goods and XP. ARC Raiders
And give every expedition a purpose before departure
Instead of players repeatedly pressing Start Run, ask:
Why are we going?
Perhaps:
Resource Expedition — gather whatever you can.
Mining Contract — locate specific ore.
Wildlife Survey — locate/observe rare species.
Hunt — track a particular creature.
Recovery Contract — retrieve something lost.
Archaeological Expedition — investigate a ruin.
Disaster Response — stabilize a devastated area.
Settlement Defense — defend another Hold.
Blueprint Hunt — intel points toward a rare blueprint.
Lost Cache Recovery — recover the previous team's belongings.
Deep Expedition — explicitly intended to push multiple Acts.
The run remains systemic and open-ended, but the players have a reason to care about particular discoveries.
One mechanic from extraction games I'd twist heavily: death
ARC Raiders can forfeit unsecured carried equipment on knockout. Puzzle Genome Atlas
I wouldn't copy that fully.
For Wilderhold:
Extracted persistent gear you brought in → returns damaged.
New gear found during the expedition → lost if unsecured/unextracted.
Resources → partially lost based on difficulty.
Secure Pouch → protected.
I still think that's the sweet spot.
Wilderhold already asks players to invest hundreds of hours into Skills, builds, companions and equipment. Full gear deletion would encourage people to leave their favorite toys in the Vault—which is the opposite of what we want.
One ARC idea I would explicitly not copy: PvP
ARC's Raider-versus-Raider threat is central to its extraction tension. ARC Raiders
Wilderhold doesn't need it.
You already have something that can fill that unpredictability role much more naturally:
Earth itself.
Another player isn't the thing that suddenly ruins your perfect expedition.
It's:
🌪️ tornado
🌊 flash flood
🔥 wildfire
⚡ supercell
☄️ meteor
🌎 earthquake
🐺 Legendary predator
👹 unexpected elite wave
That can become Wilderhold's unique extraction identity:
In other extraction games, you're afraid of the players you haven't seen. In Wilderhold, you're afraid of what the world hasn't done yet.

That's the direction I'd push hardest.

  Sources
ChatGPT can make mistakes. Check important info.


Ideas for the spellcasting discipline tree for our game and the best way for mana/mp to work that's meaningful for our game? Maybe magic should also have its own skill system beyond just the discipline skills? And item affixes affecting magic? Full magic system and skill tree everything pertaining to magic's best implementation and complete system for our game's best most perfect use case max perfection for production ready use?


I would add Spellcasting as Wilderhold’s 10th official persistent skill, while keeping the elemental Disciplines as specialization trees rather than nine more grindable skills. That gives magic the same long-term identity as Mining or Farming without drowning the player in separate Pyromancy XP, Cryomancy XP, etc.
The key is that magic should interact with combat, towers, climate, terrain, Earth’s Wrath, gear, extraction, crafting, and co-op. It should feel like manipulating the same forces that govern Wilderhold—not a disconnected “blue bar + fireball” system.
Here is the full spec I’d give Claude.


# WILDERHOLD — COMPLETE SPELLCASTING & MAGIC SYSTEM

## 1. CORE DESIGN

Spellcasting becomes Wilderhold's **10th official persistent skill**.

There are three separate layers:

**Spellcasting Skill — Level 1–100**  
Permanent account/character knowledge progression.

**Arcane Discipline Tree**  
Permanent but freely respecable specialization choices.

**Run Spell Augments**  
Temporary modifications acquired during an expedition and lost when the run ends.

Do NOT create separate grindable Pyromancy, Hydromancy, Cryomancy, etc. skills.

That would create unnecessary progression bloat.

The intended structure is:

**Spellcasting level = knowledge**

**Discipline tree = specialization**

**Gear = build**

**Run augments = temporary evolution**

---

# 2. DESIGN FANTASY

Magic in Wilderhold is not infinite supernatural power.

A spellcaster is manipulating the same elemental systems already affecting the world.

Fire magic creates heat.

Water magic creates moisture.

Ice removes heat.

Air changes pressure and movement.

Lightning exploits conductivity.

Earth manipulates terrain and stability.

Extensive magical manipulation can therefore contribute to:

- Earth's Wrath;
- temperature change;
- flooding;
- wildfire;
- frozen terrain;
- seismic instability;
- storms;
- compound disasters.

A powerful mage is dangerous partially because the world itself can react to what they are doing.

Core philosophy:

> Magic allows the player to command nature temporarily. Earth's Wrath determines whether nature tolerates it.

---

# 3. MANA / MP

## Base Mana

Starting maximum:

**100 Mana**

Spellcasting levels gradually increase natural capacity.

At Level 100:

approximately **120 natural Mana**

before gear.

A heavily invested endgame caster might reach roughly:

**150–160 Mana**

through equipment.

Recommended absolute balance ceiling:

approximately **180 Mana**

unless later testing proves otherwise.

Do not allow infinite scaling.

---

# 4. MANA REGENERATION

Mana needs to matter without forcing players to stand around waiting.

Recommended baseline:

**Combat Mana regeneration:** ~2 Mana/sec

**Out-of-combat regeneration:** ~8 Mana/sec after approximately 3 seconds without combat pressure.

Exact values are tuning variables.

Mana regeneration should continue naturally rather than requiring consumables.

---

# 5. ACTIVE MANA RECOVERY

Skilled gameplay should occasionally restore Mana.

Most importantly:

### Perfect Aegis Step

A successfully timed Perfect Aegis Step restores approximately:

**+6 Mana**

with a short internal cooldown around 3 seconds.

This connects Spellcasting to Wilderhold's existing combat mastery.

Possible Discipline nodes or affixes can later enable:

- Mana from parries;
- Mana from critical hits;
- Mana from elemental reactions;
- Mana when breaking enemy armor;
- Mana when destroying elite weak points.

Do NOT make killing trash enemies the dominant Mana-generation method.

Otherwise swarm encounters create infinite Mana.

---

# 6. MANA TONICS

Herbalism may produce limited Mana-restoration consumables.

Example:

**Arcane Tonic**

Restores approximately 25–35 Mana over several seconds.

It should occupy the player's single Herbal/Tonic buff category or use a limited consumable charge.

Mana potions should NEVER become endlessly spammed.

Passive regeneration remains the foundation.

---

# 7. SPELL COST TIERS

Recommended starting ranges:

| Spell Type | Typical Cost |
|---|---:|
| Cantrip / Quick Spell | 6–12 Mana |
| Standard Spell | 15–25 Mana |
| Heavy Spell | 25–40 Mana |
| Major Spell | 40–60 Mana |
| Ritual / Ultimate | 70–100+ Mana |
| Channelled Spell | Mana per second |

A caster should normally be capable of several ordinary spells before becoming depleted.

The decision should be:

**Do I spend 45 Mana now for enormous impact or preserve my reserve?**

---

# 8. COOLDOWNS

Mana should be the primary limiter on ordinary spells.

Avoid putting large cooldowns AND large Mana costs on everything.

Recommended:

Cantrips:
little/no cooldown.

Standard spells:
approximately 1–4 seconds.

Heavy spells:
approximately 4–8 seconds.

Major control/mobility:
approximately 8–20 seconds.

Rituals:
long cooldown or one meaningful use per major encounter.

Cooldowns primarily prevent mechanical abuse.

Mana controls overall spell economy.

---

# 9. SPELLCASTING LOADOUT

Do not allow players to carry thirty spells simultaneously.

Recommended maximum:

### 4 Active Spell Slots

plus:

### 1 Utility / Movement Spell

plus eventually:

### 1 Ritual Spell

This remains controller-friendly while producing meaningful preparation decisions.

---

# 10. SPELL SLOT PROGRESSION

| Spellcasting Level | Unlock |
|---|---|
| 1 | 2 Active Spell slots |
| 10 | 3rd Active Spell |
| 20 | Utility Spell slot |
| 30 | 4th Active Spell |
| 60 | Ritual Spell slot |

Players therefore gradually gain complexity rather than receiving the entire magic system immediately.

---

# 11. SPELLCASTING SKILL — LEVEL 1–100

Spellcasting XP should come from **effective magical activity**, not pressing the cast button.

XP can be awarded for:

- damaging legitimate enemies;
- crowd controlling enemies;
- protecting allies;
- creating useful elemental reactions;
- successfully maintaining barriers;
- dispelling effects;
- using magic during dangerous encounters;
- completing Rituals;
- discovering new spells;
- defeating magically relevant enemies;
- environmental magic interactions.

Casting spells into empty space provides essentially no XP.

Repeatedly exploiting trivial enemies should receive sharply diminishing XP.

---

# 12. SPELLCASTING LEVEL MILESTONES

| Level | Major Unlock |
|---|---|
| 1 | Mana unlocked, Grimoire, basic Arcane and elemental spells |
| 10 | Third Active Spell slot; basic Discipline specialization |
| 20 | Utility spell slot; elemental reactions become fully accessible |
| 30 | Fourth Active Spell slot; advanced spell modifiers |
| 40 | Major-tier spells |
| 50 | Advanced cross-element specialization |
| 60 | Ritual slot and Ritual magic |
| 70 | Advanced environmental spell interactions |
| 80 | Master Discipline nodes |
| 90 | Mythic spell discoveries become usable |
| 100 | Master Spellcaster; maximum natural Mana efficiency and access to highest spellcraft requirements |

Intermediate levels improve:

- Mana efficiency slightly;
- casting stability;
- spell identification;
- ritual success;
- access to higher-level spell requirements.

Avoid huge automatic damage increases.

---

# 13. DISCIPLINE POINTS

Players earn:

**1 Discipline Point every 5 Spellcasting levels**

= 20 points from leveling.

Additional points may come from:

- major magical bosses;
- legendary Archaeology discoveries;
- extremely rare Grimoires;
- major story milestones.

Recommended completionist maximum:

approximately **30 Discipline Points**.

There should be substantially more possible nodes than available points.

No player can permanently master everything simultaneously.

---

# 14. RESPEC

Discipline Points should be freely or cheaply respecable **at the Hold**.

Do not allow full talent-tree changes during active combat.

Players should experiment without fear of permanently ruining a character.

---

# 15. THE DISCIPLINE TREE

The tree contains:

### Core Spellcraft

and six elemental Disciplines:

**Pyromancy — Fire**

**Hydromancy — Water**

**Geomancy — Earth**

**Aeromancy — Air**

**Stormcalling — Lightning**

**Cryomancy — Ice**

Arcane magic forms the central/core branch rather than becoming another environmental element.

---

# 16. CORE SPELLCRAFT TREE

These nodes apply broadly across disciplines.

### Mana Well
+Maximum Mana.

### Controlled Casting
Reduced Mana cost.

### Quickened Invocation
Improved cast speed.

### Arcane Recovery
Improved Mana regeneration.

### Warding
Improved magical barriers.

### Focused Casting
Improved spell critical chance.

### Arcane Penetration
Ignore a portion of magical resistance.

### Ritualist
Improved Ritual casting.

### Spell Echo
Small chance for selected eligible spells to repeat at reduced effectiveness.

### Elemental Scholar
Improves elemental reaction potency.

### Channel Mastery
Reduced movement penalty while channeling.

### Overchannel
Allows selected spells to be cast with insufficient Mana by consuming health and dramatically increasing magical strain/Wrath.

Overchannel should be a late-game optional node.

It should feel dangerous.

---

# 17. PYROMANCY

## Identity

Highest sustained damage.

Ignition.

Damage-over-time.

Area denial.

Heat.

Wildfire interaction.

High Earth’s Wrath risk.

### Example Nodes

**Kindling**
Ignite duration increased.

**Accelerant**
Burning enemies take increased Fire damage.

**Backdraft**
Enemies killed while burning can cause a small fiery burst.

**Cinderstep**
Movement spells leave brief burning ground.

**Heat Sink**
Fire spells become slightly cheaper when standing in already-hot terrain.

**Conflagration**
Repeated Fire hits intensify existing burns.

**Inferno Covenant — Keystone**
Fire spells become significantly more powerful while local Fire Wrath/environmental heat is elevated, but the player contributes more strongly to Fire instability.

### Gameplay Character

Pyromancy should tempt players into deliberately dangerous environmental conditions.

---

# 18. HYDROMANCY

## Identity

Control.

Wet status.

Knockback.

Cleansing.

Defensive utility.

Flood synergy.

Lightning setup.

### Example Nodes

**Flow**
Water spells cost slightly less when cast near existing water.

**Soaking Current**
Wet lasts longer.

**Undertow**
Water movement effects gain stronger pull/knockback.

**Cleansing Waters**
Certain Water spells remove Burning and selected harmful effects.

**Mistform**
Water Utility spells briefly reduce incoming projectile damage.

**Floodcaller**
Water spells become stronger in flooded terrain.

**Tidal Dominion — Keystone**
Water spells gain substantially increased area in deeply wet/flooded environments but contribute more heavily to moisture/flood instability.

---

# 19. GEOMANCY

## Identity

Defense.

Terrain.

Armor.

Stagger.

Physical control.

Structural stability/instability.

### Example Nodes

**Stone Skin**
Earth barriers gain increased durability.

**Fracture**
Earth damage applies stronger armor break.

**Aftershock**
Heavy Earth spells create secondary stagger pulses.

**Earthen Bastion**
Barriers grant nearby allies temporary defense.

**Fault Reader**
Improves damage against enemies standing on fractured terrain.

**Deep Resonance**
Earth spells become stronger during seismic activity.

**Heart of Stone — Keystone**
Heavy Earth spells gain major stagger and barrier power but generate greater local seismic strain.

---

# 20. AEROMANCY

## Identity

Mobility.

Push/pull.

Projectile manipulation.

Speed.

Tornado interaction.

Positioning.

### Example Nodes

**Tailwind**
Movement spells gain range.

**Vacuum**
Pull effects become stronger.

**Wind Shear**
Air damage partially ignores armor.

**Slipstream**
Casting an Air spell briefly improves movement speed.

**Deflection**
Selected Air spells can redirect or weaken projectiles.

**Cyclone**
Repeated Air effects increase displacement.

**Eye of the Storm — Keystone**
While inside high-wind/storm conditions, Air spells gain dramatically improved control and mobility.

---

# 21. STORMCALLING

## Identity

Burst damage.

Chain attacks.

Conductivity.

Critical strikes.

Disruption.

Flood synergy.

### Example Nodes

**Static Charge**
Repeated Lightning hits build Shock faster.

**Arc**
Chain Lightning gains another eligible target.

**Conductive Mastery**
Wet enemies take increased Lightning reaction damage.

**Overload**
Fully Shocked enemies release a small electrical burst.

**Thunderstep**
Movement spell damages or Shocks nearby enemies.

**Stormheart**
Lightning becomes stronger during thunderstorms.

**Living Conductor — Keystone**
Chain Lightning gains significantly improved propagation through water and Wet targets but sharply increases electrical instability during storms/floods.

---

# 22. CRYOMANCY

## Identity

Slowing.

Freezing.

Shattering.

Defense.

Temperature reduction.

Flood freezing.

### Example Nodes

**Frostbite**
Chill stacks accumulate faster.

**Permafrost**
Frozen effects persist longer on ordinary enemies.

**Brittle**
Frozen/chilled enemies take increased physical or Earth damage.

**Ice Ward**
Cryomancy barriers become stronger.

**Hoarfrost**
Cold zones linger longer.

**Flash Freeze**
Wet enemies require fewer Chill stacks to Freeze.

**Deep Winter — Keystone**
Cryomancy becomes substantially stronger in already-cold environments and can temporarily freeze larger areas of shallow water.

---

# 23. ELEMENTAL STATUS EFFECTS

Each elemental Discipline should have an understandable combat identity.

| Element | Primary Status |
|---|---|
| Fire | Burning |
| Water | Wet |
| Earth | Fractured / Staggered |
| Air | Displaced / Windswept |
| Lightning | Shocked |
| Ice | Chilled → Frozen |

---

# 24. BURNING

Deals damage over time.

May ignite flammable foliage/environment under appropriate circumstances.

Repeated Fire damage increases intensity to a controlled cap.

---

# 25. WET

Minimal direct damage.

Enables strong elemental interactions.

Wet targets:

- conduct Lightning;
- freeze more easily;
- resist/cleanse Burning;
- may become more vulnerable to certain Water control effects.

---

# 26. FRACTURED

Earth attacks can build Fracture.

Fractured targets suffer:

- reduced armor;
- increased stagger vulnerability.

Bosses can be Fractured without becoming permanently stunlocked.

---

# 27. WINDSWEPT

Air magic applies movement instability.

Effects may include:

- greater knockback vulnerability;
- disrupted ranged accuracy;
- displacement interaction.

---

# 28. SHOCKED

Shock increases vulnerability to Lightning chaining/disruption.

At maximum Shock:

ordinary enemies can briefly become electrically stunned.

Bosses instead receive:

a short interruption/stagger contribution.

Never allow permanent boss stun loops.

---

# 29. CHILLED / FROZEN

Chill reduces movement/action speed.

Multiple Chill stacks can Freeze ordinary enemies.

Bosses cannot normally be fully frozen repeatedly.

Against bosses, maximum Chill instead produces:

**Brittle**

causing increased stagger/critical vulnerability for a limited duration.

---

# 30. ELEMENTAL REACTIONS

This should become one of Wilderhold magic's strongest features.

### Wet + Lightning
**Conductive Surge**

Lightning chains farther and deals increased reaction damage.

### Wet + Ice
**Flash Freeze**

Freeze occurs significantly faster.

### Fire + Water
**Steam Burst**

Creates damaging/obscuring steam and removes some Burning/Wet.

### Fire + Ice
**Thermal Shock**

Deals burst damage and greatly increases stagger.

### Earth + Water
**Mud / Quagmire**

Creates temporary slowing terrain.

### Earth + Fire
**Molten Fracture**

Creates briefly dangerous heated/cracked terrain.

### Air + Fire
**Fanned Flame**

Fire spreads/increases area.

### Air + Ice
**Whiteout**

Creates an intense slow/visibility zone.

### Air + Lightning
**Storm Surge**

Improves electrical range or produces localized arcs.

### Earth + Lightning
**Grounded Discharge**

Electrical energy spreads differently through grounded structures/terrain and can create localized burst effects.

Reactions should be individually tuned.

Do NOT allow exponential reaction loops.

---

# 31. ENVIRONMENTAL MAGIC

Small combat spells should create mostly temporary/local environmental effects.

Examples:

Firebolt:
slightly warms a cell.

Water spell:
slightly increases local moisture.

Frost Nova:
temporarily lowers temperature.

Air spell:
briefly changes local wind influence.

Earth spell:
minor seismic contribution.

Lightning:
can ignite extremely dry vegetation or propagate through floodwater.

---

# 32. MAJOR SPELL ENVIRONMENTAL IMPACT

Large spells and Rituals may materially influence climate cells.

Examples:

Repeated major Fire casting:
raises local heat.

Large Water Ritual:
raises moisture/flood risk.

Major Cryomancy:
lowers temperature significantly.

Geomancy Ritual:
raises seismic instability.

Air Ritual:
creates dangerous wind conditions.

Storm Ritual:
increases storm/electrical instability.

These effects should plug into the same climate-grid system already planned.

Never create an entirely separate magic-environment simulation.

---

# 33. SPELLCASTING AND EARTH'S WRATH

Spellcasting contributes to Earth’s Wrath based primarily upon:

- elemental intensity;
- spell tier;
- Mana consumed;
- environmental disruption;
- repeated concentration of one element;
- current biome/environment.

Small Cantrips contribute almost nothing.

Ritual-scale elemental manipulation can matter considerably.

The Wrath value remains hidden.

Players learn through environmental feedback.

Example:

A Pyromancer repeatedly casts large Fire spells in a drought-stricken forest.

The ground dries.

Leaves discolor.

Smoke appears.

Wildlife begins leaving.

Wind shifts.

Eventually:

Wildfire risk becomes severe.

This should feel systemic rather than scripted.

---

# 34. ELEMENTAL TOWER INTERACTION

Player spells and towers should cooperate.

Examples:

Water spell wets enemies entering Lightning tower range.

Lightning tower chains dramatically farther.

Earth spell Fractures enemies.

Physical/Stone towers gain stronger impact.

Cryomancy freezes enemies inside tower kill zones.

Air pushes enemies back into defended lanes.

Fire spell ignites enemies entering Fire-tower amplification.

Large elemental events can temporarily empower matching towers just like natural disasters.

Magic therefore enhances tower strategy rather than replacing towers.

---

# 35. SPELL ACQUISITION

Do NOT unlock every spell automatically by leveling Spellcasting.

Use multiple sources.

### Basic Spells
Unlocked through early Spellcasting milestones.

### Grimoires / Spell Pages
Found during expeditions.

Must be extracted or secured.

### Archaeological Magic
Ancient spells discovered through Archaeology.

### Boss Spells
Rare spells associated with specific bosses.

### Disaster Magic
Certain spells discovered from extreme elemental events.

### Quest / NPC Magic
Special teachings or rewards.

Once learned:

**Spell knowledge is permanent and cannot be lost.**

---

# 36. SPELL RARITY

Spell rarity should represent rarity/complexity, not automatically damage.

Suggested:

Common  
Uncommon  
Rare  
Legendary  
Ancient / Mythic

A Common spell can remain valuable forever if its utility is excellent.

Do not make rarity simply:

Legendary Fireball = Fireball with 800% damage.

---

# 37. EXAMPLE 1.0 SPELL CATALOG

A reasonable production target would be approximately:

**4 core spells per elemental Discipline**

plus:

**4–6 Arcane/Core spells**

Approximately 28–30 spells at launch.

More can be added later.

---

# 38. PYROMANCY SPELLS

### Ember Bolt
Fast cheap projectile.

### Flame Wave
Short-range cone/line of fire.

### Cinder Field
Creates temporary burning ground.

### Inferno
Major spell creating intense localized fire.

Possible future Ritual:

### Rain of Embers
Large area Fire Ritual with significant environmental consequences.

---

# 39. HYDROMANCY SPELLS

### Water Lance
Focused Water projectile.

### Tidal Push
Pushes enemies and applies Wet.

### Cleansing Mist
Removes Burning and selected harmful statuses.

### Deluge
Major area Water effect.

Ritual:

### Torrential Invocation
Heavy rain/moisture over a large area with flood implications.

---

# 40. GEOMANCY SPELLS

### Stone Shard
Heavy physical/earth projectile.

### Earthen Wall
Creates temporary barrier.

### Seismic Slam
Area stagger/Fracture.

### Fault Line
Creates directional ground rupture.

Ritual:

### Earthwake
Major seismic event with strong terrain/Wrath implications.

---

# 41. AEROMANCY SPELLS

### Wind Blade
Fast ranged cutting projectile.

### Gust
Strong directional push.

### Slipstream
Mobility spell.

### Cyclone
Localized pull/knock-up zone.

Ritual:

### Tempest Eye
Major wind field with tornado-risk implications.

---

# 42. STORMCALLING SPELLS

### Spark
Fast low-cost Lightning hit.

### Chain Lightning
Primary chaining attack.

### Thunderstep
Mobility + electrical burst.

### Overload
High-damage Shock-consuming attack.

Ritual:

### Stormcall
Temporarily intensifies local electrical/storm conditions.

---

# 43. CRYOMANCY SPELLS

### Ice Lance
Precise Cold projectile.

### Frost Nova
Area Chill.

### Ice Wall
Temporary defensive terrain.

### Deep Freeze
Powerful targeted freeze/Brittle spell.

Ritual:

### Winter's Grasp
Large cold zone capable of freezing shallow water.

---

# 44. ARCANE / CORE SPELLS

### Arcane Bolt
Reliable neutral magic damage.

### Mana Ward
Consumes Mana to create temporary protection.

### Blink
Short-range repositioning.

### Dispel
Removes certain magical/elemental effects.

### Gravity Well
Pulls enemies toward a central point.

### Arcane Channel
Temporarily converts Mana into increased spell output.

Arcane spells should have less environmental impact than elemental magic.

---

# 45. RITUAL MAGIC

Rituals are NOT ordinary ultimates.

They should feel dangerous and deliberate.

Typical properties:

- very high Mana cost;
- long cast/channel;
- vulnerable caster;
- substantial environmental effect;
- strong Wrath contribution;
- significant cooldown;
- major battlefield impact.

Some Rituals may allow allies to assist.

---

# 46. CO-OP RITUALS

A particularly strong Wilderhold feature:

Multiple players can optionally channel the same Ritual.

Each contributor provides:

- Mana;
- channel time;
- Discipline contribution.

More participants can:

- increase area;
- increase duration;
- reduce individual Mana cost;
- strengthen environmental impact.

But it should also potentially increase Wrath proportionally.

This creates dramatic co-op moments.

---

# 47. CATALYSTS / MAGIC EQUIPMENT

Players should NOT require a staff just to cast.

Any character can cast known/equipped spells.

However, magic-focused equipment can specialize the build.

Potential Catalyst types:

### Wand
Fast casting.

Lower Mana costs.

Lower individual spell impact.

### Staff
Higher spell power/area.

Slower casting.

### Grimoire
Utility, reaction and multi-element bonuses.

### Talisman / Focus
Wards, defensive magic, Mana efficiency.

### Spellblade
Hybrid weapon/magic play.

Do not require a separate Catalyst slot unless the equipment architecture supports it cleanly.

Catalysts may function as weapon/off-hand types.

---

# 48. MAGIC ITEM AFFIXES

Magic needs a substantial affix pool.

## General Offensive

**+Spell Power**

**+Spell Critical Chance**

**+Spell Critical Damage**

**+Cast Speed**

**+Area of Effect**

**+Projectile Speed**

**+Spell Penetration**

---

# 49. ELEMENTAL AFFIXES

Examples:

**+Fire Spell Power**

**+Water Spell Power**

**+Earth Spell Power**

**+Air Spell Power**

**+Lightning Spell Power**

**+Ice Spell Power**

**+Burn Potency**

**+Wet Duration**

**+Fracture Strength**

**+Displacement Strength**

**+Shock Potency**

**+Chill Potency**

These should enable specialization.

---

# 50. MANA AFFIXES

**+Maximum Mana**

**+Mana Regeneration**

**-% Mana Cost**

**Mana restored on Perfect Aegis Step**

**Mana restored when triggering an elemental reaction**

**Chance to refund part of spell Mana cost**

Cost reduction must have a hard or strong soft cap.

Recommended approximate cap:

**25–30% global Mana cost reduction**

before exceptional temporary effects.

Never allow permanent zero-cost builds.

---

# 51. UTILITY AFFIXES

Possible:

**+Barrier Strength**

**+Spell Duration**

**+Channel Stability**

**+Movement while Channeling**

**+Chain Range**

**+1 Chain Target**

**+Ground Effect Duration**

**+Elemental Reaction Potency**

**+Status Buildup**

**+Ritual Power**

Special mechanical affixes such as +1 chain should remain rare.

---

# 52. CONDITIONAL AFFIXES

These are particularly suited to Wilderhold.

Examples:

**Stormbound**
Lightning damage increased during rain/storms.

**Floodborn**
Water/Lightning magic strengthened while standing in floodwater.

**Ashen**
Fire magic gains power on scorched terrain.

**Permafrost**
Cryomancy stronger in frozen terrain.

**Fault-Touched**
Geomancy stronger during seismic activity.

**Galeheart**
Air magic stronger during high winds.

These create builds that intentionally interact with dangerous environmental states.

---

# 53. SPELL CRITICALS

Direct-damage spells may critically strike.

Damage-over-time effects should generally NOT critically strike automatically.

Burning scales through:

- Burn potency;
- duration;
- Fire power.

This prevents critical chance from becoming universally mandatory.

---

# 54. RESISTANCES

Enemies may possess elemental resistance.

Avoid widespread hard immunity.

Bad:

"This enemy is Fire immune; your build doesn't function."

Better:

"This enemy has 40% Fire resistance."

Players can counter with:

- penetration;
- reactions;
- secondary Discipline;
- physical weapon damage;
- teammates;
- towers.

Boss resistances should encourage adaptation, not invalidate builds.

---

# 55. CROWD CONTROL DIMINISHING RETURNS

Bosses and elites need anti-lock mechanics.

Repeated Freeze/Stun/Knock-up builds a:

### Resolve meter

As Resolve rises:

hard crowd-control duration decreases.

After a recovery period:

Resolve drops again.

This prevents four-player teams from permanently disabling bosses.

---

# 56. RUN-ONLY SPELL AUGMENTS

Spellcasting should interact strongly with Wilderhold's Run Levels.

Run-level milestones can offer temporary magical augments.

Examples:

### Fork
Projectile splits.

### Echo
Spell repeats at reduced power.

### Lingering
Ground effects last longer.

### Rebound
Projectile can bounce.

### Overcharge
Higher Mana cost, dramatically higher power.

### Conduit
Chain Lightning chains farther.

### Flashpoint
Ignite reaches maximum intensity faster.

### Deep Chill
Chill stacks faster.

### Living Stone
Earth barriers regenerate slowly.

### Slipstream
Casting while moving improves cast speed.

### Elemental Fusion
Unlock selected cross-element effects.

These disappear when the run ends.

Persistent progression provides knowledge.

Run progression creates the current build.

---

# 57. MAGIC AND GEAR QUALITY

Higher-quality gear may provide:

- stronger affix values;
- additional affixes;
- rare mechanical affixes;
- improved Catalyst characteristics.

Do NOT let Legendary equipment simply provide vastly larger raw numbers.

Legendary magic equipment should often change behavior.

Example:

### Stormglass Grimoire

Chain Lightning can jump through allied Lightning towers.

That is more interesting than:

+87% Lightning Damage.

---

# 58. UNIQUE MAGIC ITEMS

Unique items can fundamentally modify spells.

Examples:

### Cinderheart Staff
Burning enemies emit heat into nearby environmental cells faster.

### Drowned Codex
Water spells cost less while standing in floodwater.

### Faultspeaker
Seismic spells generate stronger Fracture but greatly increase Earth instability.

### Eye of the Gale
Air spells orbit briefly before releasing.

### Fulgur Crown
Lightning can chain from towers back into enemies.

### Winterglass Focus
Frozen enemies shatter into damaging Ice fragments.

These items can create recognizable build archetypes.

---

# 59. MAGIC AND SKILLS

Spellcasting should interact with existing skills.

### Mining
Magically altered crystals and catalysts.

### Smithing
Spellblades, enchanted metal components, Catalyst frames.

### Farming
Rare magical crops.

### Herbalism
Mana tonics and elemental preparations.

### Archaeology
Ancient Grimoires, Rituals, magical artifacts.

### Engineering
Magical/elemental tower interfaces and environmental instruments.

### Cooking
Limited meals providing minor Mana recovery/elemental resistance.

This keeps Spellcasting connected to Wilderhold's economy.

---

# 60. SPELLCRAFTING

Do NOT add a separate Spellcrafting skill.

Instead, late-game Spellcasting + Archaeology + relevant crafting skills can create or modify magical equipment.

Potential system:

Find:

**Ancient Rune Fragment**

Archaeology identifies it.

Spellcasting understands it.

Smithing/Engineering installs it into a Catalyst.

That is better than another skill bar.

---

# 61. MAGIC BLUEPRINTS / GRIMOIRES AND EXTRACTION

Rare Spell Pages/Grimoires found during expeditions should behave like valuable extraction loot.

If unsecured and the expedition fails:

they may be lost.

If successfully extracted:

the spell becomes permanently learned.

Once learned:

that knowledge can never be lost.

This makes finding a rare spell one of the most exciting extraction moments.

---

# 62. THE SECURE POUCH

Spell discoveries are excellent Secure Pouch candidates.

Example:

Player finds:

**Ancient Grimoire: Stormcall**

Now they must decide:

Secure it immediately?

Or keep their pouch slot available for something even rarer?

That fits Wilderhold's extraction loop extremely well.

---

# 63. MAGIC AND THE GLOBAL ECONOMY

Spell knowledge itself should generally be account-bound once learned.

However, before learning:

certain Spell Pages/Fragments may be tradable.

Possible structure:

Common/Rare Spell Pages:
tradable.

Legendary/Story spells:
account-bound.

Archaeological Ritual discoveries:
often account-bound.

This allows magical trading without letting players purchase every major progression achievement.

---

# 64. MAGIC DIFFICULTY SCALING

Do NOT reduce Mana regeneration simply because difficulty increases.

That usually feels terrible.

Instead:

### Nightmare

- smarter enemy interruption;
- more elemental resistance variation;
- stronger enemy spellcasters;
- more dangerous environmental interactions.

### Hell

- enemies punish channeling more aggressively;
- elite anti-magic mechanics;
- more complex resistances;
- greater disaster interaction;
- more powerful magical rewards.

The player's magic system itself remains consistent.

---

# 65. ANTI-MAGIC ENEMIES

Some enemies can challenge casters.

Examples:

**Silencer**
briefly disrupts casting.

**Null Warden**
creates an anti-magic zone.

**Grounder**
reduces Lightning chaining.

**Ash Eater**
consumes Burning effects.

**Frostbreaker**
shatters Ice barriers.

But these should be occasional tactical threats.

Never make entire encounters simply turn magic off.

---

# 66. SPELLCASTING AND WEAPON BUILDS

Spellcasting should support:

### Pure Caster
High Mana, Spell Power, Catalyst.

### Spellblade
Weapon attacks + magic.

### Elemental Ranger
Ranged weapon + elemental support spells.

### Battlemage
Earth/Ward + melee.

### Stormrunner
Air/Lightning mobility.

### Controller
Water/Ice/Air.

### Environmental Mage
Build intentionally exploiting climate and disasters.

### Tower Conductor
Uses spells primarily to amplify tower performance.

All should be viable.

---

# 67. PURE CASTER BALANCE

A fully specialized caster should be capable of dealing the majority of their combat damage through spells.

However:

Mana management must matter.

When depleted, the player should still have:

- weapon attacks;
- movement;
- defensive options;
- utility.

A caster should never become completely unable to play because Mana reached zero.

---

# 68. TARGET DAMAGE CONTRIBUTION

Early hybrid character:

approximately **20–40%** of damage from magic.

Dedicated midgame caster:

approximately **50–70%**.

Highly specialized endgame caster:

potentially **70–90%**.

Never require magic for all players.

---

# 69. SPELL TELEGRAPHING

Major player spells need clear visual language.

Fire:
orange/red heat distortion.

Water:
blue/clear flow.

Earth:
brown/stone fracture.

Air:
white/translucent movement streaks.

Lightning:
electric arcs.

Ice:
cyan/white crystalline patterns.

Arcane:
distinct non-elemental visual language.

Effects must remain readable when towers, enemies, weather and four players are simultaneously active.

Avoid particle overload.

---

# 70. NETWORKING / PERFORMANCE

Spell effects must be server/host authoritative for gameplay.

Replicate:

- spell cast ID;
- origin;
- direction/target;
- major impact result;
- status application;
- environmental-cell modification.

Do NOT continuously network every visual particle.

Clients render:

- particles;
- trails;
- cosmetic lightning branches;
- impact flourishes.

The authoritative simulation handles:

- damage;
- status;
- terrain effects;
- climate-cell influence;
- Wrath;
- resource consequences.

---

# 71. ENVIRONMENTAL RATE LIMITING

A Fire spell hitting grass should not cause dozens of expensive simulation events every frame.

Environmental effects should submit aggregated events to the climate/ecology grid.

Example:

Fireball impact generates:

`heat +X`

`ignition_check Y`

`radius Z`

The climate/environment system processes it on its scheduled update.

This preserves performance.

---

# 72. DEBUG TOOLS

Claude should implement development overlays for:

Mana use.

Spell DPS.

Status buildup.

Reaction triggers.

Elemental damage breakdown.

Climate influence.

Wrath contribution.

Active ground effects.

Networked spell events.

This will be essential for balancing.

---

# 73. SPELL TOOLTIP REQUIREMENTS

Every spell should clearly display:

Mana Cost

Cooldown

Element

Damage or effect

Cast Time

Range

Area

Status buildup

Environmental interaction

Discipline scaling

Reaction tags

Players should never need a wiki to understand basic spell behavior.

Advanced interactions can still be discovered.

---

# 74. GRIMOIRE UI

The Spellcasting menu should contain:

### Learned Spells

### Unknown Spell Discoveries

### Current Loadout

### Discipline Tree

### Elemental Reactions

### Rituals

### Spell Statistics

### Environmental Interactions

Unknown rare spells can appear as silhouettes or hidden entries depending on discovery philosophy.

---

# 75. MAGIC PRESETS

At the Hold, allow saved Spellcasting loadouts.

Examples:

**Stormcaller**

**Fire / Earth**

**Flood Control**

**Boss Control**

**Hell Expedition**

Changing presets automatically equips:

- spells;
- Discipline configuration if allowed;
- preferred Catalyst.

This reduces friction.

---

# 76. SPELLCASTING MASTER LEVEL 100

Level 100 should NOT provide enormous raw damage.

Level 100 represents mastery.

Benefits:

- highest-tier spell requirements;
- Mythic spell access;
- maximum natural Mana capacity;
- advanced Ritual control;
- high environmental understanding;
- best identification of magical phenomena;
- Master Spellcaster title/achievement.

A Level 100 caster is more capable because they understand more possibilities.

---

# 77. POST-100

Spellcasting does not exceed Level 100.

Post-cap use contributes to normal account Renown.

Do not introduce Spellcasting Level 120/200/etc.

---

# 78. SPELLCASTING ACHIEVEMENTS

Examples:

Trigger every elemental reaction.

Survive a disaster caused partly by your own magic.

Freeze a flooded battlefield.

Cause Lightning to chain through ten Wet enemies.

Complete a Ritual with every co-op player contributing.

Learn every standard spell.

Learn every Ritual.

Reach Spellcasting 100.

Defeat a boss primarily through elemental reactions.

Extract successfully with a Legendary Grimoire.

Avoid achievements requiring absurd RNG.

---

# 79. PRODUCTION 1.0 CONTENT TARGET

Recommended minimum:

**Spellcasting Skill 1–100**

**6 Elemental Disciplines**

**Core Spellcraft tree**

**~28–30 spells**

**6+ Rituals**

**6 elemental status systems**

**10+ elemental reactions**

**magic affix pool**

**5 Catalyst archetypes**

**Run augments**

**environmental/climate integration**

**Earth's Wrath integration**

**co-op magic interactions**

**rare Grimoire extraction**

**Spellcasting achievements**

Anything beyond this can expand post-launch.

---

# 80. IMPLEMENTATION ORDER

Recommended engineering sequence:

### Phase 1
Mana system.

Spell loadout.

Basic projectile/area spell framework.

Spellcasting XP.

### Phase 2
Elemental status framework.

Fire/Water/Earth/Air/Lightning/Ice.

### Phase 3
Elemental reactions.

### Phase 4
Discipline tree.

### Phase 5
Catalysts and magic affixes.

### Phase 6
Climate-grid interaction.

### Phase 7
Earth's Wrath contribution.

### Phase 8
Rituals.

### Phase 9
Rare Grimoires/extraction integration.

### Phase 10
Co-op synchronization, balance and optimization.

Do not build all spell VFX first.

Establish the underlying systemic architecture before content expansion.

---

# 81. MOST IMPORTANT BALANCE RULES

Magic should never:

make towers obsolete;

make weapons obsolete;

provide unlimited healing;

allow permanent boss crowd-control;

produce infinite Mana loops;

allow permanent zero-cost casting;

ignore environmental consequences;

completely neutralize natural disasters;

require one mandatory Discipline;

make non-casters objectively inferior.

Magic SHOULD:

create powerful tactical choices;

reward environmental awareness;

interact with towers;

produce elemental combinations;

generate meaningful Wrath consequences;

reward skillful Mana management;

support pure and hybrid builds;

create memorable extraction discoveries;

become more interesting—not merely stronger—as mastery increases.

---

# 82. THE WILDERHOLD MAGIC FANTASY

Early caster:

"I can throw fire."

Intermediate caster:

"Water will make those enemies conductive."

Experienced caster:

"The flood is rising. My Lightning build is about to become terrifying."

Expert caster:

"If I keep doing this, the storm will intensify."

Master caster:

"I know exactly what will happen if I cast this Ritual here—and I'm willing to accept the consequences."

That should be the defining progression.

Magic doesn't merely give the player power.

It gives them **another way to negotiate with Wilderhold itself.**


The three decisions I would lock immediately are Spellcasting becomes official Skill #10, Mana stays a single readable resource instead of adding multiple overlapping magic bars, and the Discipline tree specializes magic without creating separate elemental XP grinds.
I’d also strongly keep the Perfect Aegis Step → Mana restoration interaction. It makes a great caster more active and mechanically skillful instead of someone who just stacks Mana regeneration and waits for the blue bar to refill.



ChatGPT can make mistakes. Check important info.



What about for the rest of the disciplines?


Yes — the rest of the disciplines should get the same treatment, but I would not turn every discipline into another Level 1–100 persistent skill. That would create too many overlapping progression bars.
The cleanest structure for Wilderhold is:
- 10 persistent skills: the nine we already locked + Spellcasting.
- 8 Combat Disciplines: persistent specialization trees that define how you fight.
- Weapon Mastery: persistent familiarity with individual weapon families.
- Run Augments / Evolutions: temporary build transformation during an expedition.
That preserves the earlier Wilderhold build identities—melee, ranged/Hunter, defense, movement, Engineer/towers, Beast/companions, Scavenger, and elemental Spellcasting. 
I’d make the canonical discipline lineup:
Discipline	Primary Fantasy	Core Resource/Mechanic
Vanguard	Melee combat	Momentum
Hunter	Ranged precision	Focus
Bulwark	Defense/tanking	Guard
Wayfarer	Mobility/evasion	Aegis Step / Flow
Engineer	Towers/devices	Constructs + synergy
Beastwarden	Companions/wildlife	Bond
Scavenger	Loot/resource improvisation	Salvage/opportunity
Spellcaster	Magic/elements	Mana


And I would explicitly make Blood a high-risk cross-discipline archetype available through rare gear, augments and keystones rather than a ninth core discipline. That keeps it special.


# WILDERHOLD — COMBAT DISCIPLINES

## OVERALL STRUCTURE

Combat Disciplines are persistent talent trees.

They do NOT have independent Level 1–100 XP bars.

Players unlock Discipline Points primarily through:

- Player Level milestones;
- major bosses;
- important progression milestones;
- selected difficult achievements/challenges.

Recommended total at full progression:

**~30–36 universal Discipline Points**

There should be far more nodes available than points.

A player cannot fully master every Discipline simultaneously.

Respec:

**Free or inexpensive at the Hold.**

Never require restarting a character to change builds.

---

# DISCIPLINE TREE STRUCTURE

Each Discipline contains:

### Tier I — Fundamentals
Basic identity.

### Tier II — Specialization
Build direction.

### Tier III — Advanced Techniques
Strong mechanical changes.

### Tier IV — Mastery
Powerful specialization.

### Keystone
Major behavior-changing choice.

Players should generally commit about:

**6–10 points**

to truly specialize in one Discipline.

This allows:

- one deep primary Discipline;
- one meaningful secondary;
- a few utility investments elsewhere.

---

# 1. VANGUARD

## Fantasy

Close-range fighter.

Aggression.

Weapon combos.

Stagger.

Momentum.

Risk/reward positioning.

## Core Mechanic — Momentum

Successful melee actions build **Momentum**.

Momentum increases through:

- consecutive melee hits;
- perfect attacks;
- staggers;
- aggressive positioning.

Momentum decays if the player disengages too long.

It should NOT simply be another bar that must constantly be watched.

Use subtle visual/audio feedback.

---

## Vanguard Branches

### Execution

Criticals, finishers, low-health enemies.

### Juggernaut

Heavy attacks, stagger, armor breaking.

### Duelist

Timing, counters, attack speed, precision.

---

## Example Nodes

### Battle Rhythm
Consecutive melee attacks slightly accelerate combo recovery.

### Heavy Hand
Heavy attacks deal increased stagger.

### Opportunist
Deal additional damage to Staggered enemies.

### Relentless
Taking light damage no longer immediately interrupts certain heavy attacks.

### Executioner's Edge
Increased effectiveness against low-health enemies.

### Counterstrike
Perfect defensive timing empowers the next melee attack.

### Weapon Flow
Weapon swapping during a combo retains part of Momentum.

### Crushing Blow
Fully charged heavy attacks apply Fracture.

---

## Keystone Choices

### Unstoppable
At high Momentum, heavy attacks gain interruption resistance.

### Perfect Duelist
Perfect defensive timing creates a brief high-damage counter window.

### Reaper
Finishers refund a portion of stamina/health/resource but require aggressive play.

Only one Vanguard Keystone active.

---

# 2. HUNTER

## Fantasy

Ranged combat.

Precision.

Weak points.

Ammunition mastery.

Tracking targets.

Controlled distance.

## Core Mechanic — Focus

Focus builds through:

- accurate shots;
- weak-point hits;
- maintaining advantageous range;
- avoiding missed shots.

Focus is consumed by certain powerful ranged techniques.

---

## Hunter Branches

### Marksman

Precision and weak points.

### Skirmisher

Movement + ranged combat.

### Arsenal

Ammo types and weapon swapping.

---

## Example Nodes

### Steady Aim
Remaining relatively still briefly improves precision.

### Predator's Eye
Weak points become easier to identify.

### Piercing Shot
High-Focus shots gain penetration.

### Quickdraw
Weapon switching briefly improves handling.

### Conservation
Chance not to consume ammunition on a precision hit.

### Mobile Archer
Reduced accuracy penalty while moving.

### Finisher Shot
Low-health enemies take greater ranged damage.

### Ricochet
Certain projectiles can bounce once under appropriate conditions.

---

## Keystones

### Deadeye
Repeated weak-point hits dramatically empower the next precision attack.

### Run-and-Gun
Maintaining movement increases ranged handling and Focus generation.

### Quartermaster
Special ammunition becomes significantly more effective but more important to the build.

---

# 3. BULWARK

## Fantasy

Defense.

Protection.

Holding ground.

Damage mitigation.

Saving allies.

Tower defense synergy.

## Core Mechanic — Guard

Guard represents defensive readiness.

Blocking, parrying and protecting allies builds/maintains Guard.

Taking uncontrolled heavy damage breaks it.

---

## Bulwark Branches

### Bastion

Personal durability.

### Guardian

Protect allies.

### Retaliation

Turn defense into offense.

---

## Example Nodes

### Brace
Reduced knockback while Guard is high.

### Stonewall
Improved block efficiency.

### Interpose
Gain protection when near a critically injured ally.

### Retaliation
Successful blocks empower the next attack.

### Hold the Line
Standing near allied towers increases resistance slightly.

### Unbroken
Survive lethal damage once under strict conditions, with long cooldown.

### Protective Presence
Nearby companions/allies receive minor defensive benefit.

### Disaster Hardened
Reduced environmental knockback/stagger.

---

## Keystones

### Living Bastion
High Guard provides substantial defense but reduces mobility.

### Guardian's Oath
Taking damage intended for nearby allies generates powerful defensive bonuses.

### Revenge
Perfect defense stores a portion of prevented damage for the next attack.

---

# 4. WAYFARER

## Fantasy

Movement.

Dodging.

Aegis Step mastery.

Positioning.

Terrain traversal.

Fluid combat.

## Core Mechanic — Flow

Flow rewards continuous skilled movement.

Generated by:

- Perfect Aegis Step;
- narrowly avoiding attacks;
- successful movement abilities;
- traversing combat without being hit.

---

## Branches

### Aegis Mastery

Perfect timing.

### Pathfinder

Terrain/environment mobility.

### Momentum

Speed-driven offense.

---

## Example Nodes

### Lightfoot
Reduced movement penalties from shallow mud/water.

### Perfect Step
Slightly improves reward window for genuine Perfect Aegis Steps without making timing trivial.

### Afterimage
Perfect Aegis Step briefly reduces enemy tracking.

### Fleet
Movement speed rises slightly while Flow is maintained.

### Unburdened
Reduced movement penalty from equipped load.

### Terrain Reader
Improved movement over difficult natural terrain.

### Reflex
Perfect Aegis Step reduces Utility ability cooldown slightly.

### Windrunner
High Flow improves attack/cast handling while moving.

---

## Keystones

### Untouchable
Maintaining maximum Flow gives major mobility benefits—but being hit removes it.

### Aegis Master
Perfect Aegis Step generates stronger discipline-resource interactions.

### Pathfinder
Environmental movement penalties are substantially reduced, but never completely eliminated for catastrophic terrain.

---

# 5. ENGINEER

This is different from the persistent **Engineering Skill**.

Engineering Skill determines:

> What you know how to build.

Engineer Discipline determines:

> How your constructs behave during combat.

---

## Fantasy

Tower specialist.

Devices.

Repair.

Construct synergy.

Battlefield preparation.

## Core Mechanic — Network

Nearby player-built devices can form an Engineering Network.

Connected structures gain strategic interactions.

---

## Branches

### Architect

Tower construction and durability.

### Mechanist

Devices, traps and active machinery.

### Conductor

Elemental/tower synergy.

---

## Example Nodes

### Field Repair
Combat repairs become more efficient.

### Reinforcement
Newly built towers temporarily gain armor.

### Efficient Construction
Small chance to conserve common construction resources.

### Emergency Patch
Damaged towers can receive a temporary emergency barrier.

### Linked Systems
Nearby compatible towers gain minor synergy.

### Overclock
Temporarily increase tower output at the cost of heat/stress.

### Elemental Conduit
Elemental player effects interact more strongly with matching towers.

### Salvage Protocol
Destroyed constructs return a portion of recoverable material.

---

## Keystones

### Fortress Architect
Networks of nearby towers become increasingly resistant to damage.

### Overclocker
Greatly improve temporary tower performance while risking structural damage/elemental Wrath.

### Conductor
Player elemental effects propagate exceptionally well through tower networks.

---

# 6. BEASTWARDEN

## Fantasy

Companion-focused combat.

Bond.

Wildlife knowledge.

Coordinated attacks.

Companion survivability.

## Core Mechanic — Bond

Bond grows through fighting alongside the active companion.

Good cooperative actions build Bond.

Companion death resets current combat Bond but does NOT affect permanent unlock progression.

---

## Branches

### Packleader

Companion offense.

### Keeper

Companion defense/recovery.

### Symbiosis

Player + companion cooperative effects.

---

## Example Nodes

### Pack Tactics
Attacking the same enemy as your companion increases effectiveness.

### Protective Instinct
Companion becomes tougher when player health is low.

### Shared Hunt
Companion attacks help expose enemy weak points.

### Quick Recovery
Slightly reduces companion death cooldown.

### Call of the Wild
Companion movement/target responsiveness improves.

### Symbiotic Strike
Player and companion hitting the same enemy triggers a periodic bonus effect.

### Guardian Beast
Companion can occasionally intercept appropriate threats.

### Wild Resilience
Environmental hazards affect companions less severely.

---

## Keystones

### Alpha Bond
Maximum Bond dramatically strengthens coordinated attacks.

### Spirit Guardian
Companion becomes significantly more defensive/support-oriented.

### Apex Predator
Companion gains greater offensive power against elites/bosses.

Legendary/Shiny companions should remain balanced rather than becoming mandatory.

---

# 7. SCAVENGER

This is important because Wilderhold has an extraction economy.

## Fantasy

Survival through improvisation.

Loot.

Salvage.

Field efficiency.

Resourcefulness.

Extraction.

## Core Mechanic — Opportunity

Scavenger builds should derive combat/economic advantage from what the expedition actually provides.

Not simply "+30% loot."

---

## Branches

### Salvager

Recover value.

### Improviser

Use random resources creatively.

### Prospector

Find rare opportunities.

---

## Example Nodes

### Keen Eye
Important salvage containers/environmental opportunities are slightly easier to notice.

### Strip for Parts
Improved salvage from destroyed machinery/towers.

### Field Repairs
Can repair gear slightly more efficiently during expeditions.

### Pack Rat
Small Expedition Backpack capacity improvement.

### Resourceful
Low-tier materials can substitute for a small portion of certain field recipes.

### Fortune Favors
Slightly increased chance for higher-quality—not simply more—salvage.

### Emergency Supplies
Very low supplies can occasionally produce emergency field-crafting options.

### Cache Hunter
Improves clues toward Lost Expedition Caches and hidden stockpiles.

---

## Keystones

### Nothing Wasted
Greatly improves usefulness of otherwise low-value salvage.

### Fortune Seeker
High-risk areas offer improved rare-loot quality, but safe areas receive no benefit.

### Prepared for Anything
Gain stronger bonuses from maintaining a diverse expedition inventory.

---

# 8. SPELLCASTER

Already defined separately.

Core resource:

**Mana**

Branches:

- Core Spellcraft
- Pyromancy
- Hydromancy
- Geomancy
- Aeromancy
- Stormcalling
- Cryomancy

Spellcasting uniquely also has a persistent **Level 1–100 Spellcasting Skill** because learning magic includes:

- spell knowledge;
- Grimoire requirements;
- ritual mastery;
- Mana mastery;
- magical environmental knowledge.

That distinction is intentional.

---

# WHY THE OTHER DISCIPLINES DO NOT NEED LEVEL 1–100 SKILLS

Vanguard does not need:

"Melee Skill 1–100."

Hunter does not need:

"Ranged Skill 1–100."

Bulwark does not need:

"Defense Skill 1–100."

That creates redundant progression.

Instead, combat familiarity is handled through:

# WEAPON MASTERY

---

# WEAPON MASTERY SYSTEM

Every weapon family has persistent Mastery.

Recommended scale:

**Mastery 1–20**

rather than 1–100.

Examples:

Sword  
Greatsword  
Axe  
Hammer  
Spear  
Bow  
Crossbow  
Firearm, if applicable  
Spellblade  
Staff/Catalyst

---

## Mastery Progression

### Mastery 1
Weapon usable normally.

### Mastery 3
First technique/handling improvement.

### Mastery 5
Weapon-specific technique unlock.

### Mastery 8
Advanced handling.

### Mastery 10
Second major technique.

### Mastery 15
Expert weapon behavior.

### Mastery 20
Weapon Mastery capstone + cosmetic/title recognition.

Mastery should primarily unlock:

- moves;
- handling;
- combos;
- techniques;
- alternative attacks;

rather than enormous raw damage.

---

# EXAMPLE — SWORD MASTERY

1 — Basic combo  
3 — Improved combo transition  
5 — Riposte technique  
8 — Faster heavy recovery  
10 — Alternate finisher  
15 — Advanced counter technique  
20 — Swordmaster technique

---

# EXAMPLE — BOW MASTERY

1 — Normal shooting  
3 — Improved draw handling  
5 — Quick Shot  
8 — Movement accuracy technique  
10 — Power Draw  
15 — Advanced weak-point technique  
20 — Master Archer technique

---

# DISCIPLINE + WEAPON MASTERY

This creates much better build diversity.

Two Sword users might be completely different:

### Sword + Vanguard/Duelist
Aggressive melee counter fighter.

### Sword + Bulwark
Defensive sword-and-board guardian.

### Sword + Wayfarer
Highly mobile evasive duelist.

### Sword + Spellcaster
Spellblade.

Weapon does NOT equal class.

That is exactly what Wilderhold wants.

---

# DUAL-DISCIPLINE SYNERGIES

Certain investments across trees can create named archetypes.

These are NOT hard classes.

They're recognized combinations.

### Vanguard + Bulwark
**Juggernaut**

### Vanguard + Wayfarer
**Bladedancer**

### Hunter + Wayfarer
**Skirmisher**

### Hunter + Scavenger
**Ranger**

### Engineer + Bulwark
**Fortifier**

### Engineer + Spellcaster
**Arcane Engineer**

### Beastwarden + Hunter
**Pack Hunter**

### Beastwarden + Wayfarer
**Wildrunner**

### Spellcaster + Vanguard
**Spellblade**

### Spellcaster + Bulwark
**Battlemage**

### Spellcaster + Hunter
**Arcane Marksman**

### Spellcaster + Beastwarden
**Spiritcaller**

These labels can appear in build summaries without imposing class restrictions.

---

# BLOOD ARCHETYPE

Blood should NOT initially be a full Discipline.

Instead, it is a dangerous cross-build mechanic found through:

- rare augments;
- Legendary gear;
- Rituals;
- corrupted relics;
- high-risk keystones.

Blood mechanics exchange:

**Health ↔ Power**

Examples:

Bloodcasting  
Life-steal  
Berserk states  
Sacrifice  
Companion sacrifice interaction only where appropriate  
Health-cost Overchanneling

Blood builds should be exceptionally powerful but genuinely dangerous.

It could become a full Discipline in a later expansion only if enough unique mechanics accumulate.

---

# DISCIPLINE POINT PACING

Suggested:

Player Level 5 — first point  
10 — second  
then approximately one every 5 levels

Additional important progression milestones provide more.

At Level 100, the player should have enough to:

**deeply master 2 trees**

or

**master 1 + meaningfully invest in 3–4 others**

but never fill everything.

---

# RUN AUGMENTS

Permanent Discipline tree:

defines your identity.

Run Augments:

break the normal rules temporarily.

Example:

Permanent Hunter:
weak-point specialist.

This expedition:

Ricochet + explosive ammo + Chain Shot

Next expedition:

piercing + poison + mobility.

Same persistent character.

Different run build.

---

# EVOLUTIONS

Your strongest run builds can eventually trigger an **Evolution** when specific Augment combinations are met.

Examples:

### Stormrunner
Wayfarer + Lightning interactions.

### Infernal Vanguard
Vanguard + Fire.

### Living Fortress
Bulwark + Engineer.

### Wild Hunt
Hunter + Beastwarden.

### Tempest Architect
Engineer + Air/Lightning.

### Blood Reaver
Vanguard + rare Blood effects.

Evolutions disappear at extraction.

They should represent the outrageous high point of a particular run.

---

# PROGRESSION STACK

The complete character progression now becomes:

### PLAYER LEVEL 1–100
Overall persistent progression.

### OFFICIAL SKILLS 1–100
Knowledge/professions.

Includes Spellcasting.

### COMBAT DISCIPLINES
Persistent build specialization.

### WEAPON MASTERY 1–20
Persistent weapon familiarity.

### EQUIPMENT
Persistent build customization.

### COMPANIONS
Persistent collection/progression.

### RUN LEVEL 1–30
Temporary expedition growth.

### ROAD AUGMENTS
Temporary build mutations.

### EVOLUTIONS
Temporary end-stage build transformations.

This gives every progression system one clear job.

Nothing needs to compete with anything else.



I think this is significantly better than giving all eight Disciplines their own XP bars. Spellcasting is the exception because learning actual spells, rituals and magical knowledge genuinely supports a 1–100 skill. Vanguard/Hunter/etc. are better expressed through Discipline Points + Weapon Mastery.
And there’s one more system I’d add now that this is taking shape: Discipline Challenges. Each tree could have optional mastery feats that unlock cosmetics, titles, rare nodes or augment pools—e.g. Hunter gets a reward for a streak of weak-point kills, Bulwark for protecting allies from a huge amount of damage, Wayfarer for chaining Perfect Aegis Steps, Engineer for surviving an Act with zero destroyed towers. That gives each discipline its own mastery journey without another grind bar.




  Sources









ChatGPT can make mistakes. Check important info.