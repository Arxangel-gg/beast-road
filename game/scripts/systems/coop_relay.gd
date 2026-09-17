class_name CoopRelay
extends Node

## The one place a co-op message crosses the wire.
##
## Step 2 of `docs/COOP_DESIGN.md`. The design's §4 argument is that `EventBus`
## is already the right seam for a network boundary — its signals describe facts
## about the run rather than node plumbing, which is exactly what has to travel.
## What it has never had to carry is **authority**, and that is what this adds.
##
## Three kinds of traffic, and the split is the whole design:
##
## * **Host-authored facts** travel host → guest. The guest re-emits them on its
##   own `EventBus` so guest-side systems keep working unchanged and never learn
##   a network exists.
## * **Guest requests** travel guest → host. The host is told a request arrived
##   and answers it by authoring a fact. A guest's own UI never decides an
##   outcome.
## * **Cosmetic signals** — camera shake, sparks, sound — are **not relayed** at
##   all. Each client derives them from the facts it already has, and sending
##   them would double the traffic to reproduce something free.
##
## **One relay point, not a hundred call sites.** Nothing in the battlefield, the
## town or the beast scope is aware of any of this. That is deliberate and worth
## defending: the moment a gameplay system starts asking "am I the host" inline,
## the seam stops being a seam.
##
## Raw packets rather than `@rpc`, and not for style. An `@rpc` call resolves by
## node path and therefore needs the sender and receiver at the *same* path in
## their respective trees. The co-op harness necessarily has a host and a guest
## at different paths in one tree, so a path-bound relay could not be tested in
## process — which would throw away the property step 1 was built to have.
## `SceneMultiplayer.send_bytes` is path-independent.

## Facts the host authors and the guest mirrors. Wire values: append only,
## never renumber — an older build must not read a newer one's packet as a
## different fact.
enum Fact {
	ENEMY_DIED = 0,
	WAVE_CLEARED = 1,
	BOSS_DEFEATED = 2,
	LANE_PRESSURE = 3,
	PHASE_CHANGED = 4,
	CURRENCY_CHANGED = 5,
	TOWN_HEALTH = 6,
	HERO_STATE = 7,
	TOWER_STATE = 8,
	ENEMY_SPAWNED = 9,
	ENEMY_BATCH = 10,
	ENEMY_REMOVED = 11,
	XP_AWARDED = 12,
	RUN_STARTED = 13,
	HOST_INPUT = 14,
	WORLD_CLOCK = 15,
	PAUSED = 16,
	HERO_DOWN = 17,
	HERO_REVIVED = 18,
	TOWER_FIRED = 19,
	CINEMATIC_SKIPPED = 20,
	TEAM_WIPE = 21,
	REVIVE_PROGRESS = 22,
	TRAP_STATE = 23,
	TRAP_FIRED = 24,
	BARRICADE_STATE = 25,
	LOOT_SPAWNED = 26,
	LOOT_TAKEN = 27,
	WILDLIFE_SPAWNED = 28,
	WILDLIFE_BATCH = 29,
	WILDLIFE_REMOVED = 30,
	RUN_ENDED = 31,
	CROSSROAD_OPENED = 32,
	ROAD_CHOSEN = 33,
	POINTER = 34,
	RELIC_CHOSEN = 35,
	ENEMY_STRUCK = 36,
	PARTY_ROSTER = 37,
	CHAT = 38,
	ACT_STARTED = 39,
	LAST_SCAR_ACCEPTED = 40,
	LAST_SCAR_RESOLVED = 41,
	BOSS_SPAWNED = 42,
	BOSS_PHASE_CHANGED = 43,
	## Live crossroad tallies, host to everyone.
	##
	## **Purely cosmetic, and deliberately a Fact rather than a Request.** The
	## vote itself still travels as `CHOOSE_ROAD`, which every build already
	## speaks - so a guest on an older build casts a perfectly good vote and
	## merely does not see the running count, and a guest on a newer build
	## talking to an older host falls back to that host's first-click-wins
	## instead of waiting forever for a tally that will never come. Adding a
	## Request kind would have made both of those a hang.
	ROAD_VOTES = 45,
	WILDLIFE_DIED = 44,
	CHRONICLE_PROGRESS = 46,
	## The whole trade table, host to guest, after every change.
	##
	## The entire state each time rather than the edit that caused it. Both
	## machines then hold the same table because they were told the same table,
	## not because they replayed the same edits in the same order - and a
	## dropped edit in a screen that moves permanent gear is a desync nobody
	## would notice until the wrong sword changed hands.
	TRADE_STATE = 47,
	## The settlement: what the guest gives, and what it gets.
	TRADE_SETTLED = 48,
	## The portent the party read, host to guest.
	OMEN_CHOSEN = 49,
	## The card the party kept, host to everyone.
	ROAD_CARD_CHOSEN = 50,
	## A camp's state on the outskirts, host to guest. See `Camps`.
	CAMP_STATE = 51,
	## A road's fork opened, host to guest.
	FORK_OPENED = 52,
	## The sky's four numbers, host to guest, twice a second. See `Sky`.
	SKY_CLOCK = 53,
	## Lightning came down, host to guest: a place and a radius, to draw.
	LIGHTNING = 54,
	## The earth's wrath, host to guest, each a thing to draw. See `WeatherSky`.
	EARTHQUAKE = 55,
	WILDFIRE_LIT = 56,
	TORNADO_SPAWNED = 57,
	TORNADO_MOVED = 58,
	METEOR_INCOMING = 59,
	WRATH_ZONE = 60,
	WRATH_WARNED = 61,
	CLIMATE_BAND = 62,
	WILDLIFE_SACK = 63,
	## The run as it stands, for a guest whose field has just stood up (the
	## welcome, 2026-09-14). Addressed to that guest alone.
	WELCOME = 64,
	## The party events, host to everyone. See `PartyEvents`.
	##
	## **These were 53-58 and collided with the weather block above**, found
	## 2026-09-14. Two authors numbered by hand into the same range, and
	## `_receive`'s match takes the *first* arm with a given value - so the
	## party arms, which are written first, swallowed every SKY_CLOCK,
	## LIGHTNING, EARTHQUAKE, WILDFIRE_LIT, TORNADO_SPAWNED, TORNADO_MOVED and
	## METEOR_INCOMING a host ever sent. A guest saw no weather and no earth at
	## all. Renumbered above the block rather than the weather renumbered into
	## the gap, because these are the newer names; `coop_check` refuses a
	## duplicate value now, which is the fix that lasts.
	PARTY_EVENT_PROPOSED = 65,
	PARTY_EVENT_VOTES = 66,
	PARTY_EVENT_DECIDE_ASK = 67,
	PARTY_EVENT_RESOLVED = 68,
	PARTY_EVENT_RETURNED = 69,
	## A seat stepped off the road into an event, or came back to it.
	PARTY_EVENT_AWAY = 70,
	## A piece of gear on the ground, with the identity `LOOT_TAKEN` settles by.
	GEAR_DROPPED = 71,
	## An animal's family life changed (2026-09-14): it began or ended a
	## courtship, its blight moved on a stage, or it grew. `WildlifeFamilies.Word`
	## says which, and the guest only draws it.
	WILDLIFE_FAMILY = 72,
	## A birth, so a guest's field holds the same young. The rarity, the shine
	## and the sex are the host's; a guest never rolls one.
	WILDLIFE_BORN = 73,
	## A clutch on the ground, host to guest. Only a species, a count and a
	## place: what the eggs become is the host's decision and arrives as a
	## birth. See `WildlifeNests`.
	WILDLIFE_NESTED = 75,
	## An egg taken, host to everyone: the nest's new count and the species
	## that is now hunting.
	WILDLIFE_ROBBED = 76,
	## The wind, as a heading and a strength (2026-09-15). Sent on a threshold
	## rather than a clock: silent through a settled quarter, talking through a
	## turn. A guest eases toward it and simulates every leaf itself.
	WIND = 74,
	## **A partner's moment** (owner, 2026-09-16): a level, a craft level, and
	## what they just worked out of the ground or the water.
	##
	## Cosmetic, and that is a bound rather than a description - see
	## `EventBus.coop_partner_levelled`. A level is an account's own and my run
	## is not changed by my partner's, so these may only draw. They grant no
	## experience, no material, no fish and no level, which is why they are facts
	## rather than requests: nothing here asks for anything, so nothing here can
	## print anything.
	##
	## They travel both ways, unlike most facts, because a level is not the
	## host's to announce - it happened on whichever machine earned it.
	PARTNER_LEVELLED = 77,
	PARTNER_CRAFT_LEVELLED = 78,
	PARTNER_WORKED = 79,
	## **The Hold as a place** (owner ruling, 2026-09-17). Presence and nothing
	## else: who is standing in which seat, where they are, and who takes the
	## Hold when the host goes. No save, stash, pen or piece of gear travels on
	## any of them - see `HoldSession` for why that is the whole bound.
	HOLD_SEATS = 80,
	HOLD_MOVED = 81,
	HOLD_HANDOVER = 82,
	## **The host is taking the party out** (2026-09-17): the kind of road, the
	## act it opens at, a line describing it, and the seconds to answer in.
	PARTY_RUN_OFFER = 83,
}

## Things a guest may ask the host to do. Arriving is all this step promises;
## the systems that carry them out are steps 3 and 4.
enum Request {
	BUILD_TOWER = 0,
	UPGRADE_TOWER = 1,
	COMMAND_ORDER = 2,
	WAR_HORN = 3,
	RIDE_ON = 4,
	ENTER_RAID = 5,
	HERO_INPUT = 6,
	PAUSE = 7,
	SKIP_CINEMATIC = 8,
	PLACE_TRAP = 9,
	RAISE_BARRICADE = 10,
	CHOOSE_ROAD = 11,
	CHOOSE_RELIC = 12,
	TEND_HERO = 13,
	REPAIR_TOWN = 14,
	DECLARE_TIER = 15,
	ACCEPT_LAST_SCAR = 16,
	## A portent read at the end of an act. One for the party, like the relic.
	CHOOSE_OMEN = 23,
	## A Road Card kept at a crossroad, and what was left behind for it.
	##
	## **One message carrying both ids**, not two. A take and a drop sent
	## separately leave a hand of four if the connection dies between them, and
	## a hand of four is not a state any screen can explain.
	CHOOSE_ROAD_CARD = 25,
	## A guest landed a fish and wants the Food it pays.
	##
	## **By id, never by amount.** The host looks the Food up itself, so the
	## worst a forged packet can carry is the name of a fish that does not
	## exist. A number in this message would have been a currency printer.
	LAND_FISH = 24,
	## A guest took an egg. **By species, never by amount**, the same rule the
	## fish and the crop are asked under: the host reads the Food off its own
	## content, so the worst a forged packet carries is the name of an animal.
	TAKE_EGG = 35,
	# --- Trading (owner brief, 2026-09-10) -----------------------------------
	#
	# Six verbs rather than one, because a trade is a conversation and the
	# whole safety of it is that each step is separately agreed. Collapsing
	# them into a single "here is my trade" would remove the second screen,
	# which is the thing that stops a last-second swap.
	TRADE_INVITE = 17,
	TRADE_ANSWER = 18,
	TRADE_OFFER = 19,
	TRADE_ACCEPT = 20,
	TRADE_CONFIRM = 21,
	TRADE_CANCEL = 22,
	## The party events (2026-09-12): a guest proposes a raid or a rift, votes
	## on one, decides one it proposed, reports its return, and asks for the
	## reward of an event it ran alone - by *result*, never by amount.
	## A guest put a piece out of its own stash and wants it on the ground.
	##
	## The guest removes it from its stash *before* sending this, which is what
	## stops a double press making two swords. The host owns whether the drop
	## exists on the field, so a forged packet can only ever create a piece the
	## sender had; it cannot mint one out of nothing for the host.
	DROP_GEAR = 32,
	PARTY_EVENT_PROPOSE = 26,
	PARTY_EVENT_VOTE = 27,
	PARTY_EVENT_DECIDE = 28,
	PARTY_EVENT_RETURN = 29,
	PARTY_EVENT_REWARD = 30,
	## A guest stepped off the road into its own event, or came back.
	PARTY_EVENT_AWAY = 31,
	## A guest's field is up: tell me the run as it stands.
	## **This was 32 and collided with `DROP_GEAR`**, found 2026-09-14 with the
	## seven in `Fact`. `CoopWorld._on_request` matches WELCOME first, so a
	## guest putting a piece of gear on the ground composed an entire welcome
	## instead and dropped nothing.
	WELCOME = 34,
	## A guest pulled a crop: pay the run its Food, by crop id.
	HARVEST_CROP = 33,
	## A guest walked into the Hold and says who it is: a name and a title.
	## The host decides which seat that is; a guest naming its own seat would
	## be a guest seating itself.
	## **35 is `TAKE_EGG`'s.** These three were authored at 35-37 by reading the
	## tail of this enum rather than all of it, and `coop_check` named the
	## collision immediately - which is the gate written after the last one
	## doing its job. Read the whole table, not the end of it.
	HOLD_HELLO = 36,
	## A guest's Warden moved in the Hold. The host re-announces it as a fact
	## carrying the seat, so four machines agree about who walked.
	HOLD_MOVE = 37,
	## A guest answered the host's road offer: accepted, or not.
	PARTY_RUN_REPLY = 38,
	## **Which mount a guest's Warden is on** (2026-09-17). Sent on change and
	## on nothing else, because it is a *choice* rather than an action: getting
	## on and off already crosses as the mount button inside `HERO_INPUT`, so
	## what travels here is only which animal to draw.
	##
	## **39, read off the whole table rather than its tail.** The three Hold
	## requests above were authored at 35-37 by reading the end of this enum and
	## collided with `TAKE_EGG`; `coop_check` named it immediately. The lesson is
	## written there and obeyed here.
	HERO_MOUNT = 39,
}

## Facts that are *state announcements* rather than events.
##
## A machine re-stating something it already holds - the town saying how much
## health it has on the frame it is built - is not the same as claiming something
## happened. Both are host-authored and both are relayed; the difference is only
## that a guest emitting one is harmless rather than a bug, because the host's
## own value overwrites it immediately.
##
## Kept deliberately short. Everything absent from it is an event, and a guest
## originating an event is exactly what the guard exists to catch.
const ANNOUNCEMENT_FACTS: Array[int] = [Fact.TOWN_HEALTH, Fact.CURRENCY_CHANGED]

## Facts **either** player may author, and therefore either player may receive.
##
## The host drops every incoming fact, because a guest claiming an outcome is the
## thing this layer exists to prevent. A cursor position is not an outcome - it
## is where somebody's hand is - and there is no version of "whose hand" that has
## one author. Without this the guest's pointer was sent, arrived, and was thrown
## away by the guard on the doorstep: the sending side had its exemption and the
## receiving side did not, which is the kind of half-exemption that looks correct
## in both files.
##
## Kept as short as ANNOUNCEMENT_FACTS and for the same reason. Anything added
## here is something a guest can make the host believe.
## Facts with more than one rightful author.
##
## The pointer is where somebody's hand is and chat is a person speaking: both
## describe a *player* rather than the world, so the authority guard would be
## wrong to catch either. Everything absent from this list has exactly one
## author, and a guest originating one is what the guard exists to catch.
const SYMMETRIC_FACTS: Array[int] = [Fact.POINTER, Fact.CHAT]

## Wire tags. A packet is `[tag, kind, args]`.
##
## A refusal is its own tag rather than a fact, because it is the one message
## addressed to a *person* rather than describing the world. It goes to the peer
## that asked and nobody else, and it carries a sentence rather than state.
const TAG_FACT: int = 0
const TAG_REQUEST: int = 1
const TAG_REFUSAL: int = 2

## The session that says whether we are the host. Assigned by `Coop` on creation.
var session: Node = null

## The event bus this relay listens to and speaks on. `EventBus` in the game.
##
## Injected rather than reached for, and the reason is not purity. Two machines
## have two buses; a harness simulating both in one process would otherwise have
## them share the single autoload, and then the host's own emissions arrive at
## the guest's relay directly — which both echoes facts back and forth forever
## and trips the guard on traffic that never crossed a wire. A test that cannot
## tell the two machines apart cannot test the thing that separates them.
var bus: Node = null

## True only while re-emitting a received fact, so the guard below can tell a
## mirrored fact from one this machine invented.
var _replaying: bool = false

## Host-authored signals seen originating on a guest. A permanent architecture
## error rather than a runtime hiccup — see `_guard`.
var _violations: PackedStringArray = []

## Reported once per fact kind. A violation usually fires every frame, and a log
## flooded with the same line is a log nobody reads.
var _reported: Dictionary = {}

## Whether a violation also goes to the error log. Always true in the game.
##
## The co-op gate provokes a violation on purpose to prove the guard catches it,
## and `guard.yml` fails any check that prints an `ERROR:` line — so a passing
## test would have broken the build to demonstrate that the build-breaking
## machinery works. The gate turns this off and asserts on `violations()`
## instead, which is the detection itself; only the logging is silenced.
var report_violations: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_transport()
	_bind_facts()


func _bind_transport() -> void:
	var api: MultiplayerAPI = multiplayer
	var scene_api := api as SceneMultiplayer
	if scene_api == null:
		return
	# Never decode objects off the wire. A packet is data; letting it name a
	# class to instantiate turns a corrupt or hostile message into code
	# execution. It is false by default and is set here so that stays true on
	# purpose rather than by luck.
	scene_api.allow_object_decoding = false
	scene_api.peer_packet.connect(_on_packet)


## Swaps the bus this relay speaks on, dropping the old connections first.
##
## Only the co-op harness needs this: a relay is built by `Coop` and bound to
## `EventBus` before it enters the tree, so in the game the bus never changes.
## The harness gives each simulated machine its own bus and has to do so *after*
## the session exists, because the session is what creates the relay.
func rebind_bus(to: Node) -> void:
	_unbind_facts()
	bus = to
	_bind_facts()


## Subscribes to every relayed signal, on both sides.
##
## The host uses these to send. The guest uses the same connections to *watch*,
## which is what makes the guard free: no extra bookkeeping, and a violation is
## caught at the moment it happens rather than by inspection.
func _bind_facts() -> void:
	if bus == null:
		return
	for entry: Array in _fact_bindings():
		bus.connect(StringName(entry[0]), entry[1] as Callable)


func _unbind_facts() -> void:
	if bus == null:
		return
	for entry: Array in _fact_bindings():
		var name := StringName(entry[0])
		var handler := entry[1] as Callable
		if bus.is_connected(name, handler):
			bus.disconnect(name, handler)


## Every relayed signal, paired with the method that forwards it.
##
## Named methods rather than lambdas, so the same table can bind *and* unbind.
## A lambda cannot be disconnected without having kept the exact Callable, and a
## relay that can only ever attach is a relay whose bus can never be swapped.
##
## Signals absent from this table are not relayed. That is how a cosmetic signal
## stays local: by omission, with no per-call-site decision to get wrong.
func _fact_bindings() -> Array:
	return [
		["enemy_died", _on_enemy_died],
		["wave_cleared", _on_wave_cleared],
		["boss_defeated", _on_boss_defeated],
		["boss_spawned", _on_boss_spawned],
		["boss_phase_changed", _on_boss_phase_changed],
		["lane_pressure_changed", _on_lane_pressure_changed],
		["coop_phase", _on_coop_phase],
		["currency_changed", _on_currency_changed],
		["town_health_changed", _on_town_health_changed],
		["coop_hero_state", _on_coop_hero_state],
		["coop_tower_state", _on_coop_tower_state],
		["coop_enemy_spawned", _on_coop_enemy_spawned],
		["coop_enemy_batch", _on_coop_enemy_batch],
		["coop_enemy_removed", _on_coop_enemy_removed],
		["coop_xp_awarded", _on_coop_xp_awarded],
		["coop_partner_levelled", _on_partner_levelled],
		["coop_partner_craft_levelled", _on_partner_craft_levelled],
		["coop_partner_worked", _on_partner_worked],
		["hold_seats", _on_hold_seats],
		["hold_moved", _on_hold_moved],
		["hold_handover", _on_hold_handover],
		["party_run_offered", _on_party_run_offered],
		["coop_run_started", _on_coop_run_started],
		["coop_host_input", _on_coop_host_input],
		["coop_world_clock", _on_coop_world_clock],
		["coop_sky_clock", _on_coop_sky_clock],
		["lightning_struck", _on_lightning_struck],
		["earthquake", _on_earthquake],
		["wildfire_lit", _on_wildfire_lit],
		["tornado_spawned", _on_tornado_spawned],
		["tornado_moved", _on_tornado_moved],
		["meteor_incoming", _on_meteor_incoming],
		["wrath_zone_opened", _on_wrath_zone_opened],
		["wrath_warned", _on_wrath_warned],
		["climate_band_changed", _on_climate_band_changed],
		["wind_changed", _on_wind_changed],
		["coop_chronicle_progress", _on_chronicle_progress],
		["coop_paused", _on_coop_paused],
		["coop_hero_down", _on_coop_hero_down],
		["coop_hero_revived", _on_coop_hero_revived],
		["coop_tower_fired", _on_coop_tower_fired],
		["coop_trade_state", _on_coop_trade_state],
		["coop_trade_settled", _on_coop_trade_settled],
		["coop_cinematic_skipped", _on_coop_cinematic_skipped],
		["coop_team_wipe", _on_coop_team_wipe],
		["coop_revive_progress", _on_coop_revive_progress],
		["coop_trap_state", _on_coop_trap_state],
		["coop_trap_fired", _on_coop_trap_fired],
		["coop_barricade_state", _on_coop_barricade_state],
		["coop_loot_spawned", _on_coop_loot_spawned],
		["coop_loot_taken", _on_coop_loot_taken],
		["coop_gear_dropped", _on_coop_gear_dropped],
		["coop_wildlife_spawned", _on_coop_wildlife_spawned],
		["coop_wildlife_batch", _on_coop_wildlife_batch],
		["coop_wildlife_removed", _on_coop_wildlife_removed],
		["coop_wildlife_died", _on_coop_wildlife_died],
		["coop_wildlife_sack", _on_coop_wildlife_sack],
		["coop_wildlife_family", _on_coop_wildlife_family],
		["coop_wildlife_born", _on_coop_wildlife_born],
		["coop_wildlife_nested", _on_coop_wildlife_nested],
		["coop_wildlife_robbed", _on_coop_wildlife_robbed],
		["coop_camp_state", _on_coop_camp_state],
		["coop_fork_opened", _on_coop_fork_opened],
		["coop_party_event_proposed", _on_coop_party_event_proposed],
		["coop_party_event_votes", _on_coop_party_event_votes],
		["coop_party_event_decide_ask", _on_coop_party_event_decide_ask],
		["coop_party_event_resolved", _on_coop_party_event_resolved],
		["coop_party_event_returned", _on_coop_party_event_returned],
		["coop_party_event_away", _on_coop_party_event_away],
		["coop_run_ended", _on_coop_run_ended],
		["coop_crossroad_opened", _on_coop_crossroad_opened],
		["coop_road_chosen", _on_coop_road_chosen],
		["coop_relic_chosen", _on_coop_relic_chosen],
		["coop_omen_chosen", _on_coop_omen_chosen],
		["coop_road_card_chosen", _on_coop_road_card_chosen],
		["coop_enemy_struck", _on_coop_enemy_struck],
		["coop_party_roster", _on_coop_party_roster],
		["coop_chat", _on_coop_chat],
		["act_started", _on_act_started],
		["coop_last_scar_accepted", _on_coop_last_scar_accepted],
		["coop_last_scar_resolved", _on_coop_last_scar_resolved],
		["coop_pointer_moved", _on_coop_pointer_moved],
	]


func _on_enemy_died(id: String, at: Vector2) -> void:
	_relay(Fact.ENEMY_DIED, [id, at])


func _on_partner_levelled(seat: int, level: int) -> void:
	_relay(Fact.PARTNER_LEVELLED, [seat, level])


func _on_partner_craft_levelled(seat: int, craft: String, level: int) -> void:
	_relay(Fact.PARTNER_CRAFT_LEVELLED, [seat, craft, level])


func _on_partner_worked(seat: int, icon: String, line: String, colour: Color) -> void:
	_relay(Fact.PARTNER_WORKED, [seat, icon, line, colour])


## **The Hold** (2026-09-17). Presence, authored by the host: a guest asks to
## move (`Request.HOLD_MOVE`) and is told where it now is, exactly as it is
## told everything else about the world it is standing in.
func _on_hold_seats(rows: Array) -> void:
	_relay(Fact.HOLD_SEATS, [rows])


func _on_hold_moved(seat: int, at: Vector2, facing: Vector2) -> void:
	_relay(Fact.HOLD_MOVED, [seat, at, facing])


func _on_hold_handover(who: String) -> void:
	_relay(Fact.HOLD_HANDOVER, [who])


func _on_party_run_offered(kind: int, act: int, detail: String,
		seconds: float) -> void:
	_relay(Fact.PARTY_RUN_OFFER, [kind, act, detail, seconds])


func _on_wave_cleared(wave: int) -> void:
	_relay(Fact.WAVE_CLEARED, [wave])


func _on_boss_defeated(id: String, act: int) -> void:
	_relay(Fact.BOSS_DEFEATED, [id, act])


func _on_boss_spawned(id: String, act: int) -> void:
	_relay(Fact.BOSS_SPAWNED, [id, act])


func _on_boss_phase_changed(id: String, phase: int, phase_name: String) -> void:
	_relay(Fact.BOSS_PHASE_CHANGED, [id, phase, phase_name])


func _on_lane_pressure_changed(lane: int, pressure: float) -> void:
	_relay(Fact.LANE_PRESSURE, [lane, pressure])


func _on_coop_phase(phase: int, previous: int) -> void:
	_relay(Fact.PHASE_CHANGED, [phase, previous])


func _on_coop_cinematic_skipped() -> void:
	_relay(Fact.CINEMATIC_SKIPPED, [])


func _on_coop_team_wipe() -> void:
	_relay(Fact.TEAM_WIPE, [])


func _on_coop_revive_progress(slot: int, progress: float) -> void:
	_relay(Fact.REVIVE_PROGRESS, [slot, progress])


func _on_coop_trap_state(tile: Vector2i, trap_id: String, triggers_left: int) -> void:
	_relay(Fact.TRAP_STATE, [tile, trap_id, triggers_left])


func _on_coop_trap_fired(tile: Vector2i) -> void:
	_relay(Fact.TRAP_FIRED, [tile])


func _on_coop_barricade_state(tile: Vector2i, barricade_id: String,
		health: float) -> void:
	_relay(Fact.BARRICADE_STATE, [tile, barricade_id, health])


func _on_coop_loot_spawned(net_id: int, currency: String, amount: int,
		at: Vector2) -> void:
	_relay(Fact.LOOT_SPAWNED, [net_id, currency, amount, at])


func _on_coop_loot_taken(net_id: int) -> void:
	_relay(Fact.LOOT_TAKEN, [net_id])


func _on_coop_gear_dropped(net_id: int, piece: Dictionary, at: Vector2,
		by_a_player: bool) -> void:
	_relay(Fact.GEAR_DROPPED, [net_id, piece, at, by_a_player])


func _on_coop_wildlife_spawned(net_id: int, kind_id: String, at: Vector2) -> void:
	_relay(Fact.WILDLIFE_SPAWNED, [net_id, kind_id, at])


func _on_coop_wildlife_family(net_id: int, word: int, value: int) -> void:
	_relay(Fact.WILDLIFE_FAMILY, [net_id, word, value])


func _on_coop_wildlife_born(net_id: int, kind_id: String, at: Vector2, born: Dictionary) -> void:
	_relay(Fact.WILDLIFE_BORN, [net_id, kind_id, at, born])


func _on_coop_wildlife_nested(kind_id: String, eggs: int, at: Vector2) -> void:
	_relay(Fact.WILDLIFE_NESTED, [kind_id, eggs, at])


func _on_coop_wildlife_robbed(kind_id: String, at: Vector2, left: int) -> void:
	_relay(Fact.WILDLIFE_ROBBED, [kind_id, at, left])


func _on_coop_wildlife_batch(entries: Array) -> void:
	_relay(Fact.WILDLIFE_BATCH, [entries])


func _on_coop_wildlife_removed(net_id: int) -> void:
	_relay(Fact.WILDLIFE_REMOVED, [net_id])


func _on_coop_wildlife_died(net_id: int) -> void:
	_relay(Fact.WILDLIFE_DIED, [net_id])


func _on_coop_wildlife_sack(net_id: int, carrying: bool, hiding: bool) -> void:
	_relay(Fact.WILDLIFE_SACK, [net_id, carrying, hiding])


func _on_coop_camp_state(lane: int, tier: int, state: int) -> void:
	_relay(Fact.CAMP_STATE, [lane, tier, state])


func _on_coop_fork_opened(lane: int) -> void:
	_relay(Fact.FORK_OPENED, [lane])


func _on_coop_party_event_proposed(kind: int, subkind: int, by_slot: int, seconds: float) -> void:
	_relay(Fact.PARTY_EVENT_PROPOSED, [kind, subkind, by_slot, seconds])


func _on_coop_party_event_votes(accepted: Array, declined: Array) -> void:
	_relay(Fact.PARTY_EVENT_VOTES, [accepted, declined])


func _on_coop_party_event_decide_ask(slot: int, seconds: float) -> void:
	_relay(Fact.PARTY_EVENT_DECIDE_ASK, [slot, seconds])


func _on_coop_party_event_resolved(kind: int, subkind: int, goers: Array) -> void:
	_relay(Fact.PARTY_EVENT_RESOLVED, [kind, subkind, goers])


func _on_coop_party_event_returned(slot: int) -> void:
	_relay(Fact.PARTY_EVENT_RETURNED, [slot])


func _on_coop_party_event_away(slot: int, away: bool) -> void:
	_relay(Fact.PARTY_EVENT_AWAY, [slot, away])


func _on_coop_run_ended(victory: bool, returned: bool) -> void:
	_relay(Fact.RUN_ENDED, [victory, returned])


func _on_coop_crossroad_opened(segment: int) -> void:
	_relay(Fact.CROSSROAD_OPENED, [segment])


func _on_coop_road_chosen(road_id: String, difficulty_id: String) -> void:
	_relay(Fact.ROAD_CHOSEN, [road_id, difficulty_id])


## Who is currently voting for what, as road id -> count.
func road_votes(tally: Dictionary, voters: int) -> void:
	_relay(Fact.ROAD_VOTES, [tally, voters])


func _on_coop_last_scar_accepted() -> void:
	_relay(Fact.LAST_SCAR_ACCEPTED, [])


func _on_coop_last_scar_resolved(success: bool, reason: String,
		maximum: int) -> void:
	_relay(Fact.LAST_SCAR_RESOLVED, [success, reason, maximum])


func _on_coop_relic_chosen(relic_id: String) -> void:
	_relay(Fact.RELIC_CHOSEN, [relic_id])


func _on_coop_omen_chosen(omen_id: String) -> void:
	_relay(Fact.OMEN_CHOSEN, [omen_id])


func _on_coop_road_card_chosen(card_id: String, dropped: String) -> void:
	_relay(Fact.ROAD_CARD_CHOSEN, [card_id, dropped])


func _on_coop_enemy_struck(net_id: int, at: Vector2) -> void:
	_relay(Fact.ENEMY_STRUCK, [net_id, at])


func _on_coop_party_roster(rows: Array) -> void:
	_relay(Fact.PARTY_ROSTER, [rows])


## **The act is told, not worked out.**
##
## Every machine could derive it - the distance is replicated and the act falls
## out of it - and deriving it in two places is exactly how the two drifted: the
## host announced Act I from `journey.start()` on a condition a guest had already
## satisfied, and later acts came from a world-clock comparison that a guest's
## own journey had usually made first. Reported twice as the act title appearing
## for the host alone. One author now, and the banner, the music, the ambience
## and the region cinematic all hang off the same sentence.
func _on_act_started(act: int, terrain_id: String) -> void:
	_relay(Fact.ACT_STARTED, [act, terrain_id])


## **Chat is the other fact either player may author**, like the pointer.
##
## It is not a claim about the world - it is a person speaking - so the authority
## guard would be wrong to catch it. The host still relays it onward to everyone
## else, because in a party of four a guest can only reach the host directly.
func _on_coop_chat(slot: int, text: String) -> void:
	if _replaying or session == null:
		return
	if not bool(session.call("partner_present")):
		return
	_send([TAG_FACT, int(Fact.CHAT), [slot, text]])


## The pointer is the one fact **either** player may author.
##
## It is not a claim about the world - it is where somebody's hand is - so the
## guard would be wrong to catch it, and the host has as much reason to send it
## as the guest does. Everything else here has exactly one author; this does not.
func _on_coop_pointer_moved(at: Vector2) -> void:
	if _replaying or session == null:
		return
	if not bool(session.call("partner_present")):
		return
	_send([TAG_FACT, int(Fact.POINTER), [at]])


func _on_currency_changed(id: String, amount: int) -> void:
	_relay(Fact.CURRENCY_CHANGED, [id, amount])


func _on_town_health_changed(current: float, maximum: float) -> void:
	_relay(Fact.TOWN_HEALTH, [current, maximum])


## Hero positions are a fact like any other, and travel the same way.
##
## Worth noting because it looked at first like it needed its own send path: it
## does not. `CoopHeroes` emits this on the host's own bus and the relay forwards
## it, exactly as it forwards a death or a wave clearing. One mechanism, and the
## guard covers hero state for free - a guest that tried to author a position
## would be caught by the same check that catches a guest inventing a kill.
func _on_coop_hero_state(rows: Array) -> void:
	_relay(Fact.HERO_STATE, [rows])


func _on_coop_tower_state(anchor: Vector2i, tower_id: String, level: int) -> void:
	_relay(Fact.TOWER_STATE, [anchor, tower_id, level])


func _on_coop_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	_relay(Fact.TOWER_FIRED, [anchor, at])


func _on_coop_enemy_spawned(net_id: int, data_id: String, lane: int, at: Vector2,
		hp_scale: float, damage_scale: float, speed_scale: float,
		oath_pursuer: bool) -> void:
	_relay(Fact.ENEMY_SPAWNED,
		[net_id, data_id, lane, at, hp_scale, damage_scale, speed_scale,
			oath_pursuer])


func _on_coop_enemy_batch(entries: Array) -> void:
	_relay(Fact.ENEMY_BATCH, [entries])


func _on_coop_enemy_removed(net_id: int) -> void:
	_relay(Fact.ENEMY_REMOVED, [net_id])


func _on_coop_xp_awarded(amount: float) -> void:
	_relay(Fact.XP_AWARDED, [amount])


func _on_coop_run_started(seed_value: int) -> void:
	_relay(Fact.RUN_STARTED, [seed_value])


func _on_coop_host_input(slot: int, snapshot: Array) -> void:
	_relay(Fact.HOST_INPUT, [slot, snapshot])


func _on_coop_world_clock(distance: float, weather_id: String, act: int) -> void:
	_relay(Fact.WORLD_CLOCK, [distance, weather_id, act])


func _on_coop_sky_clock(rain_scale: float, flood: float, charge: float, temperature: float) -> void:
	_relay(Fact.SKY_CLOCK, [rain_scale, flood, charge, temperature])


func _on_lightning_struck(at: Vector2, radius: float) -> void:
	_relay(Fact.LIGHTNING, [at, radius])


func _on_earthquake(magnitude: float, seconds: float) -> void:
	_relay(Fact.EARTHQUAKE, [magnitude, seconds])


func _on_wildfire_lit(at: Vector2) -> void:
	_relay(Fact.WILDFIRE_LIT, [at])


func _on_tornado_spawned(at: Vector2, target: Vector2, seconds: float) -> void:
	_relay(Fact.TORNADO_SPAWNED, [at, target, seconds])


func _on_tornado_moved(at: Vector2, burning: bool) -> void:
	_relay(Fact.TORNADO_MOVED, [at, burning])


func _on_meteor_incoming(at: Vector2) -> void:
	_relay(Fact.METEOR_INCOMING, [at])


func _on_wrath_zone_opened(kind_id: String, at: Vector2, radius: float, seconds: float) -> void:
	_relay(Fact.WRATH_ZONE, [kind_id, at, radius, seconds])


func _on_wrath_warned(kind_id: String, at: Vector2, seconds: float) -> void:
	_relay(Fact.WRATH_WARNED, [kind_id, at, seconds])


func _on_climate_band_changed(cell: int, temp_band: int, wet_band: int) -> void:
	_relay(Fact.CLIMATE_BAND, [cell, temp_band, wet_band])


func _on_wind_changed(blowing: Vector2) -> void:
	_relay(Fact.WIND, [blowing])


func _on_chronicle_progress(summary: Dictionary) -> void:
	_relay(Fact.CHRONICLE_PROGRESS, [summary])


func _on_coop_paused(paused: bool) -> void:
	_relay(Fact.PAUSED, [paused])


## The trade table, host to guest, after every change.
##
## Relayed through the bus like every other fact rather than sent directly, so
## `_guard` covers it: a guest that somehow authored a trade table would be
## caught by the same rule that catches a guest inventing an enemy death, and
## the whole point of one authority is that the exceptions are visible.
func _on_coop_trade_state(wire: Array) -> void:
	_relay(Fact.TRADE_STATE, [wire])


func _on_coop_trade_settled(given: Array, received: Array) -> void:
	_relay(Fact.TRADE_SETTLED, [given, received])


func _on_coop_hero_down(slot: int, at: Vector2) -> void:
	_relay(Fact.HERO_DOWN, [slot, at])


func _on_coop_hero_revived(slot: int, at: Vector2) -> void:
	_relay(Fact.HERO_REVIVED, [slot, at])


# --- Sending -----------------------------------------------------------------

## A relayed signal fired locally. Forward it, or catch a guest inventing it.
func _relay(kind: Fact, args: Array) -> void:
	if _replaying:
		# This machine is mirroring a fact it was told. Sending it back would be
		# an echo, and on the guest it is also the one case where a host-authored
		# signal legitimately fires locally.
		return
	if session == null:
		return
	if not bool(session.call("is_host")):
		# A guest re-announcing state it already holds is not a guest inventing an
		# outcome, and the guard must be able to tell the two apart.
		#
		# Found in live play: the guest's town emits `town_health_changed` when the
		# battlefield builds, because a full-health town announcing itself is what
		# that signal is *for* on a single machine. The host's own value arrives a
		# moment later and overwrites it, so nothing is wrong - but the guard saw a
		# host-authored fact originating on a guest and was right to shout.
		#
		# Suppressed rather than reported, and suppressed *silently*: it must not
		# reach the wire either, because the host does not want to be told what its
		# guest's town thinks. A guest that authored something genuinely new - a
		# kill, a wave clearing, a position - is still caught, because those carry
		# information the host never sent.
		if not ANNOUNCEMENT_FACTS.has(kind):
			_guard(kind)
		return
	if not bool(session.call("partner_present")):
		# Single player, or a host nobody has joined. Nothing to tell.
		return
	_send([TAG_FACT, int(kind), args])


## Asks the host to do something. Called on the guest.
##
## Returns whether the request was *sent*, never whether it was granted — the
## answer comes back later as a fact, and a caller that treats true as success
## has reinvented the client-authority bug this whole layer exists to prevent.
func request(kind: Request, args: Array = []) -> bool:
	if session == null or not bool(session.call("is_guest")):
		return false
	return _send([TAG_REQUEST, int(kind), args])


## Tells one peer a fact the rest already hold. Host side only.
##
## Addressed rather than broadcast, and that is the whole point: the welcome
## (2026-09-14) re-states the run for a guest whose field has just stood up,
## and told to everybody it would start every other guest's run again.
func tell(peer: int, kind: Fact, args: Array) -> bool:
	if session == null or not bool(session.call("is_host")):
		return false
	return _send([TAG_FACT, int(kind), args], peer)


## Tells one peer it cannot have what it asked for.
##
## Addressed rather than broadcast: the other player has no use for it, and a
## refusal shown on both screens would read as the game refusing *both* of them.
## Host side only - a guest has nobody to refuse.
func refuse(peer: int, kind: int, reason: String) -> bool:
	if session == null or not bool(session.call("is_host")):
		return false
	return _send([TAG_REFUSAL, kind, [reason]], peer)


func _send(packet: Array, to_peer: int = 0) -> bool:
	var api := multiplayer as SceneMultiplayer
	if api == null or not api.has_multiplayer_peer():
		return false
	# 0 means every peer. With two players that is the other one.
	return api.send_bytes(var_to_bytes(packet), to_peer,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE) == OK


# --- Receiving ---------------------------------------------------------------

func _on_packet(from: int, packet: PackedByteArray) -> void:
	# `allow_objects` left at its default false, deliberately and for the same
	# reason as `allow_object_decoding` above.
	var decoded: Variant = bytes_to_var(packet)
	if not (decoded is Array):
		return
	var message: Array = decoded
	if message.size() != 3 or not (message[2] is Array) \
			or not (message[0] is int) or not (message[1] is int):
		return
	var tag: int = int(message[0])
	var kind: int = int(message[1])
	var args: Array = message[2]

	if tag == TAG_FACT:
		# Guests may receive forwarded chat, but only peer 1 owns run facts.
		# Transport topology is not a substitute for validating their author.
		if session != null and bool(session.call("is_guest")) \
				and from != 1 and not SYMMETRIC_FACTS.has(kind):
			return
		# Only the host authors facts. A packet claiming otherwise is either a
		# bug or something hostile, and either way it is not obeyed - except for
		# the handful that genuinely have two authors.
		if session != null and bool(session.call("is_host")) 				and not SYMMETRIC_FACTS.has(kind):
			return
		_replay(kind, args)
		# **In a party of four, a guest can only reach the host.** Everything
		# host-authored already goes to everybody, but a fact with two authors
		# arrives at the host addressed to nobody else - so the host passes it
		# on, or two of the four players never hear the third one speak.
		if kind == Fact.CHAT and session != null 				and bool(session.call("is_host")):
			_send([TAG_FACT, kind, args])
	elif tag == TAG_REQUEST:
		if session == null or not bool(session.call("is_host")):
			return
		bus.coop_request_received.emit(kind, args, from)
	elif tag == TAG_REFUSAL:
		if from != 1:
			return
		# Only a host refuses. A packet telling the host it was refused is either a
		# bug or something hostile, and either way it is not believed.
		if session != null and bool(session.call("is_host")):
			return
		if args.size() == 1:
			bus.coop_request_refused.emit(kind, String(args[0]))


## Re-emits a received fact on this machine's own EventBus.
##
## Guest-side systems then behave exactly as they do in single player. Every
## argument is cast to the signal's declared type rather than passed through:
## the wire carries Variants, and a float arriving where an int is declared is a
## silent mismatch that would surface far from here.
func _replay(kind: int, args: Array) -> void:
	_replaying = true
	match kind:
		Fact.ENEMY_DIED:
			if args.size() == 2:
				bus.enemy_died.emit(String(args[0]), args[1] as Vector2)
		Fact.WAVE_CLEARED:
			if args.size() == 1:
				bus.wave_cleared.emit(int(args[0]))
		Fact.BOSS_DEFEATED:
			if args.size() == 2:
				bus.boss_defeated.emit(String(args[0]), int(args[1]))
		Fact.LANE_PRESSURE:
			if args.size() == 2:
				bus.lane_pressure_changed.emit(int(args[0]), float(args[1]))
		Fact.PHASE_CHANGED:
			if args.size() == 2:
				bus.coop_phase.emit(int(args[0]), int(args[1]))
		Fact.TRADE_STATE:
			if args.size() == 1 and args[0] is Array:
				bus.coop_trade_state.emit(args[0] as Array)
		Fact.TRADE_SETTLED:
			if args.size() == 2 and args[0] is Array and args[1] is Array:
				bus.coop_trade_settled.emit(args[0] as Array, args[1] as Array)
		Fact.CINEMATIC_SKIPPED:
			bus.coop_cinematic_skipped.emit()
		Fact.TEAM_WIPE:
			bus.coop_team_wipe.emit()
		Fact.REVIVE_PROGRESS:
			if args.size() == 2:
				bus.coop_revive_progress.emit(int(args[0]), float(args[1]))
		Fact.CURRENCY_CHANGED:
			if args.size() == 2:
				bus.currency_changed.emit(String(args[0]), int(args[1]))
		Fact.TOWN_HEALTH:
			if args.size() == 2:
				bus.town_health_changed.emit(float(args[0]), float(args[1]))
		Fact.HERO_STATE:
			if args.size() == 1 and args[0] is Array:
				bus.coop_hero_state.emit(args[0] as Array)
		Fact.WILDLIFE_SPAWNED:
			if args.size() == 3:
				bus.coop_wildlife_spawned.emit(int(args[0]), String(args[1]),
					args[2] as Vector2)
		Fact.WILDLIFE_BATCH:
			if args.size() == 1 and args[0] is Array:
				bus.coop_wildlife_batch.emit(args[0] as Array)
		Fact.WILDLIFE_REMOVED:
			if args.size() == 1:
				bus.coop_wildlife_removed.emit(int(args[0]))
		Fact.WILDLIFE_DIED:
			if args.size() == 1:
				bus.coop_wildlife_died.emit(int(args[0]))
		Fact.WILDLIFE_SACK:
			if args.size() == 3:
				bus.coop_wildlife_sack.emit(int(args[0]), bool(args[1]), bool(args[2]))
		Fact.WILDLIFE_FAMILY:
			if args.size() == 3:
				bus.coop_wildlife_family.emit(int(args[0]), int(args[1]), int(args[2]))
		Fact.WILDLIFE_BORN:
			if args.size() == 4 and args[3] is Dictionary:
				bus.coop_wildlife_born.emit(int(args[0]), String(args[1]),
					args[2] as Vector2, args[3] as Dictionary)
		Fact.WILDLIFE_NESTED:
			if args.size() == 3 and args[2] is Vector2:
				bus.coop_wildlife_nested.emit(String(args[0]), int(args[1]),
					args[2] as Vector2)
		Fact.WILDLIFE_ROBBED:
			if args.size() == 3 and args[1] is Vector2:
				bus.coop_wildlife_robbed.emit(String(args[0]),
					args[1] as Vector2, int(args[2]))
		Fact.WIND:
			if args.size() == 1 and args[0] is Vector2:
				bus.coop_wind_changed.emit(args[0] as Vector2)
		# **Drawn, never granted.** Each of these re-emits the same signal the
		# sender did; `PartyJuice` is the only listener and it only draws.
		Fact.PARTNER_LEVELLED:
			if args.size() == 2:
				bus.coop_partner_levelled.emit(int(args[0]), int(args[1]))
		Fact.PARTNER_CRAFT_LEVELLED:
			if args.size() == 3:
				bus.coop_partner_craft_levelled.emit(int(args[0]),
					String(args[1]), int(args[2]))
		Fact.HOLD_SEATS:
			if args.size() == 1 and args[0] is Array:
				bus.hold_seats.emit(args[0] as Array)
		Fact.HOLD_MOVED:
			if args.size() == 3:
				bus.hold_moved.emit(int(args[0]), args[1] as Vector2, args[2] as Vector2)
		Fact.HOLD_HANDOVER:
			if args.size() == 1:
				bus.hold_handover.emit(String(args[0]))
		Fact.PARTY_RUN_OFFER:
			if args.size() == 4:
				bus.party_run_offered.emit(int(args[0]), int(args[1]),
					String(args[2]), float(args[3]))
		Fact.PARTNER_WORKED:
			if args.size() == 4 and args[3] is Color:
				bus.coop_partner_worked.emit(int(args[0]), String(args[1]),
					String(args[2]), args[3] as Color)
		Fact.RUN_ENDED:
			# A return is a second flag beside the victory; a host that does
			# not send one ended the run the old way.
			if args.size() >= 1 and args[0] is bool:
				bus.coop_run_ended.emit(bool(args[0]), args.size() >= 2 and bool(args[1]))
		Fact.CHRONICLE_PROGRESS:
			if args.size() == 1 and args[0] is Dictionary:
				bus.coop_chronicle_progress.emit(args[0] as Dictionary)
		Fact.CROSSROAD_OPENED:
			if args.size() == 1:
				bus.coop_crossroad_opened.emit(int(args[0]))
		Fact.ROAD_CHOSEN:
			if args.size() == 2:
				bus.coop_road_chosen.emit(String(args[0]), String(args[1]))
		Fact.ROAD_VOTES:
			if args.size() == 2:
				bus.coop_road_votes.emit(args[0] as Dictionary, int(args[1]))
		Fact.POINTER:
			if args.size() == 1:
				bus.coop_pointer_moved.emit(args[0] as Vector2)
		Fact.RELIC_CHOSEN:
			if args.size() == 1:
				bus.coop_relic_chosen.emit(String(args[0]))
		Fact.ROAD_CARD_CHOSEN:
			if args.size() >= 2:
				bus.coop_road_card_chosen.emit(String(args[0]), String(args[1]))
		Fact.OMEN_CHOSEN:
			if args.size() == 1:
				bus.coop_omen_chosen.emit(String(args[0]))
		Fact.CAMP_STATE:
			if args.size() == 3:
				bus.coop_camp_state.emit(int(args[0]), int(args[1]), int(args[2]))
		Fact.FORK_OPENED:
			if args.size() == 1:
				bus.coop_fork_opened.emit(int(args[0]))
		Fact.PARTY_EVENT_PROPOSED:
			if args.size() == 4:
				bus.coop_party_event_proposed.emit(int(args[0]), int(args[1]), int(args[2]), float(args[3]))
		Fact.PARTY_EVENT_VOTES:
			if args.size() == 2:
				bus.coop_party_event_votes.emit(args[0] as Array, args[1] as Array)
		Fact.PARTY_EVENT_DECIDE_ASK:
			if args.size() == 2:
				bus.coop_party_event_decide_ask.emit(int(args[0]), float(args[1]))
		Fact.PARTY_EVENT_RESOLVED:
			if args.size() == 3:
				bus.coop_party_event_resolved.emit(int(args[0]), int(args[1]), args[2] as Array)
		Fact.PARTY_EVENT_RETURNED:
			if args.size() == 1:
				bus.coop_party_event_returned.emit(int(args[0]))
		Fact.PARTY_EVENT_AWAY:
			if args.size() == 2:
				bus.coop_party_event_away.emit(int(args[0]), bool(args[1]))
		Fact.ENEMY_STRUCK:
			if args.size() == 2:
				bus.coop_enemy_struck.emit(int(args[0]), args[1] as Vector2)
		Fact.PARTY_ROSTER:
			if args.size() == 1 and args[0] is Array:
				bus.coop_party_roster.emit(args[0] as Array)
		Fact.CHAT:
			if args.size() == 2:
				bus.coop_chat.emit(int(args[0]), String(args[1]))
		Fact.ACT_STARTED:
			if args.size() == 2:
				bus.act_started.emit(int(args[0]), String(args[1]))
		Fact.LAST_SCAR_ACCEPTED:
			bus.coop_last_scar_accepted.emit()
		Fact.LAST_SCAR_RESOLVED:
			if args.size() == 3:
				bus.coop_last_scar_resolved.emit(bool(args[0]), String(args[1]),
					int(args[2]))
		Fact.BOSS_SPAWNED:
			if args.size() == 2:
				bus.boss_spawned.emit(String(args[0]), int(args[1]))
		Fact.BOSS_PHASE_CHANGED:
			if args.size() == 3:
				bus.boss_phase_changed.emit(String(args[0]), int(args[1]),
					String(args[2]))
		Fact.LOOT_SPAWNED:
			if args.size() == 4:
				bus.coop_loot_spawned.emit(int(args[0]), String(args[1]),
					int(args[2]), args[3] as Vector2)
		Fact.LOOT_TAKEN:
			if args.size() == 1:
				bus.coop_loot_taken.emit(int(args[0]))
		Fact.GEAR_DROPPED:
			if args.size() == 4:
				bus.coop_gear_dropped.emit(int(args[0]), args[1] as Dictionary,
					args[2] as Vector2, bool(args[3]))
		Fact.BARRICADE_STATE:
			if args.size() == 3:
				bus.coop_barricade_state.emit(args[0] as Vector2i, String(args[1]),
					float(args[2]))
		Fact.TRAP_STATE:
			if args.size() == 3:
				bus.coop_trap_state.emit(args[0] as Vector2i, String(args[1]),
					int(args[2]))
		Fact.TRAP_FIRED:
			if args.size() == 1:
				bus.coop_trap_fired.emit(args[0] as Vector2i)
		Fact.TOWER_FIRED:
			if args.size() == 2:
				bus.coop_tower_fired.emit(args[0] as Vector2i, args[1] as Vector2)
		Fact.TOWER_STATE:
			if args.size() == 3:
				bus.coop_tower_state.emit(args[0] as Vector2i, String(args[1]),
					int(args[2]))
		Fact.ENEMY_SPAWNED:
			if args.size() == 8:
				bus.coop_enemy_spawned.emit(int(args[0]), String(args[1]),
					int(args[2]), args[3] as Vector2, float(args[4]),
					float(args[5]), float(args[6]), bool(args[7]))
		Fact.ENEMY_BATCH:
			if args.size() == 1 and args[0] is Array:
				bus.coop_enemy_batch.emit(args[0] as Array)
		Fact.ENEMY_REMOVED:
			if args.size() == 1:
				bus.coop_enemy_removed.emit(int(args[0]))
		Fact.XP_AWARDED:
			if args.size() == 1:
				bus.coop_xp_awarded.emit(float(args[0]))
		Fact.RUN_STARTED:
			if args.size() == 1:
				bus.coop_run_started.emit(int(args[0]))
		Fact.WELCOME:
			if args.size() == 1 and args[0] is Dictionary:
				bus.coop_welcome.emit(args[0] as Dictionary)
		Fact.HOST_INPUT:
			if args.size() == 2 and args[1] is Array:
				bus.coop_host_input.emit(int(args[0]), args[1] as Array)
		Fact.WORLD_CLOCK:
			if args.size() == 3:
				bus.coop_world_clock.emit(float(args[0]), String(args[1]), int(args[2]))
		Fact.SKY_CLOCK:
			if args.size() == 4:
				bus.coop_sky_clock.emit(float(args[0]), float(args[1]), float(args[2]), float(args[3]))
		Fact.LIGHTNING:
			if args.size() == 2:
				bus.coop_lightning.emit(args[0] as Vector2, float(args[1]))
		Fact.EARTHQUAKE:
			if args.size() == 2:
				bus.coop_earthquake.emit(float(args[0]), float(args[1]))
		Fact.WILDFIRE_LIT:
			if args.size() == 1:
				bus.coop_wildfire_lit.emit(args[0] as Vector2)
		Fact.TORNADO_SPAWNED:
			if args.size() == 3:
				bus.coop_tornado_spawned.emit(args[0] as Vector2, args[1] as Vector2, float(args[2]))
		Fact.TORNADO_MOVED:
			if args.size() == 2:
				bus.coop_tornado_moved.emit(args[0] as Vector2, bool(args[1]))
		Fact.METEOR_INCOMING:
			if args.size() == 1:
				bus.coop_meteor_incoming.emit(args[0] as Vector2)
		Fact.WRATH_ZONE:
			if args.size() == 4:
				bus.coop_wrath_zone_opened.emit(String(args[0]), args[1] as Vector2, float(args[2]), float(args[3]))
		Fact.WRATH_WARNED:
			if args.size() == 3:
				bus.coop_wrath_warned.emit(String(args[0]), args[1] as Vector2, float(args[2]))
		Fact.CLIMATE_BAND:
			if args.size() == 3:
				bus.coop_climate_band_changed.emit(int(args[0]), int(args[1]), int(args[2]))
		Fact.PAUSED:
			if args.size() == 1:
				bus.coop_paused.emit(bool(args[0]))
		Fact.HERO_DOWN:
			if args.size() == 2:
				bus.coop_hero_down.emit(int(args[0]), args[1] as Vector2)
		Fact.HERO_REVIVED:
			if args.size() == 2:
				bus.coop_hero_revived.emit(int(args[0]), args[1] as Vector2)
	_replaying = false


# --- The guard ---------------------------------------------------------------

## A host-authored fact originated on a guest.
##
## This is the invariant the whole layer rests on, and it cannot be enforced by
## review alone — it only has to be broken once, in one system, for the two
## machines to start disagreeing about what happened. Catching it at the moment
## of emission names the signal instead of leaving a desync to be explained
## later.
##
## Recorded rather than thrown. A guest that mistakenly emits `enemy_died` is
## wrong, but crashing the run in front of two players is worse than a loud log
## and a gate that fails on the next push.
func _guard(kind: Fact) -> void:
	if session == null or not bool(session.call("is_guest")):
		return
	var name: String = Fact.keys()[int(kind)]
	_violations.append(name)
	if not report_violations or _reported.has(name):
		return
	_reported[name] = true
	push_error("[coop] a guest originated the host-authored fact %s. "
		% name + "Only the host may author this; see docs/COOP_DESIGN.md §4.")


## Every violation seen, for the gate. Empty is the only correct answer.
func violations() -> PackedStringArray:
	return _violations


## True while mirroring, for tests that need to tell the two cases apart.
func is_replaying() -> bool:
	return _replaying
