# Raids and rifts: what is there, what was asked, what was built, 2026-10-06

Owner item 29 of 2026-10-06: *"Raids/rifts: more features, procedural dungeons,
loot chests, interactables, traps, juice."* This is the triage against what
ships, written before anything was built so that the two additions below are
chosen rather than the first two things that came to mind. The rule the
triage is held to is the one every addition to the deep has been held to since
2026-09-11: **a rift pays what the road already pays** - run currency, gear on
the same tables, Shards, a relic at the bottom - and nothing new persists.

## 1. What a raid and a rift already are

Most of the ask is a description of what ships, under other names. Read off the
code on 2026-10-06:

| Asked for | What ships | Where |
|---|---|---|
| Procedural dungeons | A maze dealt on a lattice by a recursive walk, rooms knocked through where the walk went, loops opened, the vault at the end of the longest walk; a rift is the same cut looser. New every stage. | `DungeonLayout` (2026-09-12) |
| Loot chests | The guardian's chest in the vault: the stage's currency bursts on the floor as drops, its gear is named and banked; the raid's own supply and relic chests on the plain. | `DungeonChest`, `RaidChest` |
| Interactables | The chest, the exit portal, the stairs between stages, every one walked up to and taken with Interact; the rift gates on the road. | `DungeonPortal`, `RiftGates` |
| Traps | The collapse: the clock runs out, the exit opens, the ground bites a share of the Warden's health a second, rock sheds from a ceiling nobody can see, and the place groans for `DUNGEON_TREMOR_WARNING` seconds first. | `RiftArena._begin_collapse`, `FallingRock` |
| Juice | The floor and the rock as one Wang sheet, iron sconces every few tiles with real lights on every third, rubble, puddles and bones, crystal and stalagmite, a rune circle on the vault that brightens as the rift fills and flares when the guardian steps through, dust and drips in the air, the deep's own dark, the collapse-out shader, the chest burst, the raid's camp fires and war-camp props. | `DungeonDecor`, `DungeonAir`, `DungeonTiles`, `collapse_out.gdshader` (2026-09-14) |
| Bodies that come for you | Steered by a flow field from the hero's tile, dealt a walk away on open floor. | `RiftArena.route_hint` |
| Stakes | Deeper is harder (`DUNGEON_STAGE_ESCALATION`), the clock, dying pays nothing, a collapse pays only what was banked, an exit in time keeps it; the arena fights at the road's strength since 2026-10-01. | `RiftArena._escalation`, `WaveDirector.road_hp_scale` |
| Co-op | A rift is a party decision with a vote and a clock; a guest's rift is its own arena and its reward is asked of the host by result, never by amount. | `PartyEvents` (2026-09-12) |

So "procedural dungeons", "loot chests" and most of "juice" are done, and the
genuine gaps are **a reason to leave the main line**, **a hazard that is not
the clock**, and interactables that are not doors.

## 2. What was built

Both are presentation and ecology of the maze; neither is a new reward kind,
and `rift_check` holds both.

**Caches** (`DungeonCache`). A crate in each of the two deepest rooms the main
line does not end in. **It moves where a stage is paid, never how much**: the
vault's chest or the exit pays the stage's figure less every cache's share
(`DUNGEON_CACHE_SHARE` each), a cache broken open pays its share on the floor
as drops, and a cache left shut when the stage ends forfeits it. The sum with
every cache opened is exactly the stage's figure, so the bound stands; what the
player decides is whether to go and look against the clock, which is the whole
reason a maze has rooms off the way. Co-op needs nothing: a guest's arena lays
and pays its own caches exactly as it bursts its own chest.

**Pressure plates** (`DungeonPlate`). Iron plates on corridor floor between the
entry and the vault, never in a room, spaced so one step cannot fire two. Anything
that stands on one - the hero, a spirit, a body - fires a telegraphed circle on
the plate through `EnemyGroundStrike`, the same node every mortar lands, so the
tell is drawn at the blow's own radius, the riser swells toward it and the
debrief names it ("A pressure plate"). It takes `DUNGEON_PLATE_DAMAGE` of the
hero's own pool and `DUNGEON_PLATE_BODY_SHARE` of a body's own, over the bodies
of the plate's field alone, and rearms after `DUNGEON_PLATE_REARM`. Shares, so a
plate is the same danger on every road and never a wall for a new Warden; a
column can be baited across one, which is the first thing in the deep that is
the player's to use rather than to survive.

## 3. What is next, in order, and why it waits

1. **A barred room and a lever** - a side room sealed by a `Cell.WALL` the maze
   lays on purpose, opened by a lever elsewhere on the floor. Wants the flow
   field refreshed on the pull (`DUNGEON_FLOW_REFRESH` already does) and the
   collision rebuilt for the opened face (`RaidArena._build_cliffs` does not
   rebuild mid-stage). A room's worth of work; the caches give the same "go and
   look" decision for a day's less code, which is why they came first.
2. **Themed rooms** - a bone pit, a flooded hall, a crystal cave - as decor
   sets per room rather than per kind. Content; `DungeonDecor.PIECES` is the
   table to grow.
3. **A mini-boss between the fill and the guardian** - an elite with a mark,
   rolled on the fill's halfway point. The guardian already is the stage's
   fight; a second one is a pacing decision for the owner.
4. **Keys** - a cache that wants a key a body dropped. Refused for now: a key is
   a new drop kind and the caches are already a decision without one.

## 4. Refused, and why

- **Persistent dungeon floors** (a floor that remembers its state between
  runs). Working rule 7: nothing of a rift persists but a statistic.
- **A rift that pays a new kind of thing** (a cosmetic, a permanent point).
  `rift_check` names every reward key; the bound is the whole design.
- **Traps that scale by a number of their own** rather than a share. Shares
  are what keep a plate off the curve the acts are tuned to.
