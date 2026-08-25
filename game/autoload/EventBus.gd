extends Node

## The contract between scopes (GDD §11, rule 2).
##
## Systems talk through here, never through direct node references across
## scopes. The battlefield must not hold a reference to the city, and the raid
## must not hold a reference to the battlefield — that is what lets the
## battlefield keep simulating while the raid scene is active (GDD §11, rule 4).
##
## Rules for editing this file:
##   - every signal is typed, and carries a one-line comment
##   - a new signal must be mentioned in the session report, so the other side
##     of the two-person split knows it exists (CLAUDE.md §6)
##   - signals are past-tense facts ("enemy_died"), not commands ("kill_enemy")
##
## Signals below the STAGE 1 block are declared but not yet emitted. They mark
## the agreed scope boundaries; the systems that fire them arrive in later
## stages.

# ==============================================================================
# STAGE 1 — hero and enemies (live)
# ==============================================================================

## The hero's health changed for any reason, including respawn.
signal hero_health_changed(current_hp: float, max_hp: float)

## The hero took damage. `amount` is post-mitigation, `from` is world position.
signal hero_damaged(amount: float, from: Vector2)

## The hero hit zero HP. The hero node handles its own respawn timer.
signal hero_died(at: Vector2)

## The hero is alive and controllable again.
signal hero_respawned(at: Vector2)

## Act-long Wounds changed through a lethal down or Hearthmend.
signal hero_wounds_changed(wounds: int, maximum: int)

## The guaranteed pre-boss Hearthmend cleared the hero's act attrition.
signal hearthmend_completed(act: int)

## The hero's dash started; `iframes` is how long invulnerability lasts.
signal hero_dashed(iframes: float)

## A swing was thrown, whether or not it hit anything. This is the one the
## whoosh hangs off: a player swinging at air was previously silent, because the
## only attack signal fired on contact.
signal hero_swing_started(chain_step: int, at: Vector2)

## A foot hit the ground. `mass` lets the listener pick a light or heavy step.
signal footfall(at: Vector2, mass: float)

## The travelling beast planted one of its paired supports. Kept separate from
## ordinary character footfalls: this moves the entire battlefield and is the
## only step allowed to disturb every unit standing on its back.
signal beast_step_landed(impulse: Vector2, strength: float)

## A swing connected with at least one target. `chain_step` is 0-based.
signal hero_attack_landed(chain_step: int, targets_hit: int, at: Vector2)

## An individual enemy was struck by the hero; Command reads the tactical value.
signal hero_enemy_hit(enemy_id: String, lane: int, priority: bool, interrupted: bool, at: Vector2)

## An enemy entered the world. `enemy_id` is the EnemyData id, not a node name.
signal enemy_spawned(enemy_id: String, at: Vector2)

## An enemy reached zero HP. Kill credit, raid charge and drops read off this.
signal enemy_died(enemy_id: String, at: Vector2)

## The hero reached a new level, and how much is now unspent.
signal hero_levelled(level: int, attribute_points: int, skill_points: int)

## Hero XP moved, including awards that did not cross a level boundary.
signal hero_xp_changed(current: float, needed: float, level: int)

## A point was placed, so anything reading an attribute should re-read it.
signal hero_attributes_changed()

## The weather over the battlefield changed, and towers should re-read it.
signal weather_changed(weather_id: String)

## A drop was picked up (or paid out on expiry), for feedback and telemetry.
signal loot_collected(currency: String, amount: int, at: Vector2)

## Persistent gear reached the hero; a full stash converts it into shards.
signal gear_collected(piece: Dictionary, stored: bool, shards: int, at: Vector2)

## A raid chest was opened, and whether it had been locked.
signal raid_chest_opened(was_locked: bool)

## A key was picked up in a raid; carries the new total.
signal raid_key_taken(held: int)

## The stash changed: gear taken, sold, broken, upgraded or equipped.
signal stash_changed()

## A spell resolved. `slot` is 0..3.
signal spell_cast(spell_id: String, slot: int, at: Vector2)

## The hero's equipped spells changed.
signal spells_changed()

## Mansion progression telemetry and UI refresh.
signal discipline_trained(node_id: String, food_spent: int)
signal discipline_equipped(slot: int, node_id: String)
signal discipline_respecced(food_spent: int, use_count: int)

## Something wants the camera shaken — decoupled so any system can ask.
signal camera_shake_requested(magnitude: float, duration: float)

## Something wants a brief global freeze on impact. Highest request wins.
signal hitstop_requested(duration: float)

# ==============================================================================
# BATTLEFIELD — lanes, towers, waves (GDD §3, §4)
# ==============================================================================

## A lane's pressure changed, 0..1. The directional indicator reads off this.
signal lane_pressure_changed(lane_index: int, pressure: float)

## A wave began. `lanes` lists which lanes it uses.
signal wave_started(wave_number: int, lanes: Array)

## The authored formation carried by a wave. Kept separate from wave_started so
## audio and older UI consumers do not need to understand formation content.
signal wave_archetype_started(wave_number: int, archetype_id: String)

## Every enemy of a wave is dead or has arrived.
signal wave_cleared(wave_number: int)

## The contents of a tower slot changed: built, upgraded, or sold.
## A tower was built, upgraded, sold or destroyed on this tile. The anchor is
## the top-left tile of its 2x2 footprint.
signal tower_changed(anchor: Vector2i)

## A tower fired at something. Purely for feedback systems.
signal tower_fired(anchor: Vector2i, at: Vector2)

## A tower's player-selected targeting doctrine changed.
signal tower_targeting_changed(anchor: Vector2i, priority: int)

## The battle-only Command meter changed, in points from 0 to maximum.
signal command_changed(current: float, maximum: float)

## A targeted Command order resolved successfully.
signal command_order_used(order_id: String, lane: int, slot: int, at: Vector2)

## A torch was snuffed out or relit. `lane` is which road it stands on.
signal torch_state_changed(lane: int, lit: bool)

## An enemy reached the town and did damage.
signal town_damaged(amount: float, current_hp: float, max_hp: float)

## The town's health changed for any reason.
signal town_health_changed(current_hp: float, max_hp: float)

# ==============================================================================
# ECONOMY AND TOWN (GDD §5)
# ==============================================================================

signal resources_changed(amount: int)

## One of the four run wallets changed. Kept separate from Command, which resets
## every battle and is not an economy currency.
signal currency_changed(currency_id: String, amount: int)

## A bounded Market exchange completed.
signal market_traded(from_id: String, to_id: String, spent: int, received: int)
signal market_service_bought(service_id: String)

## A construction started, progressed (0..1), or finished.
signal construction_started(building_id: String, tier: int)
signal construction_progress(building_id: String, ratio: float)
signal construction_completed(building_id: String, tier: int)

## A captive was assigned to or removed from a building.
signal captive_assigned(captive_id: String, building_id: String)
signal captive_unassigned(captive_id: String)

## A relic was socketed or unsocketed in the Town Hall.
signal relic_socketed(relic_id: String)
signal relic_unsocketed(relic_id: String)

# ==============================================================================
# JOURNEY (GDD §7, §8, §9)
# ==============================================================================

signal distance_changed(total_distance: float, to_crossroad: float)
signal beast_speed_changed(speed: float)

## A segment boundary was reached; combat pauses for a crossroad.
signal crossroad_reached(segment_index: int)
signal crossroad_resolved(option_id: String)

signal act_started(act: int, terrain_id: String)

## The act's final segment is done; the boss should walk in. Distance does not
## advance again until the boss is dead.
signal act_boss_due(act: int)
signal boss_spawned(boss_id: String, act: int)
signal boss_defeated(boss_id: String, act: int)

## A boss crossed an authored health threshold and changed the encounter.
signal boss_phase_changed(boss_id: String, phase: int, phase_name: String)

# ==============================================================================
# HORN AND RAID (GDD §6)
# ==============================================================================

signal war_horn_activated(duration: float)
signal war_horn_ended()

## Raid meter, normalised 0..1.
signal raid_charge_changed(charge: float)

## The meter filled: enemies are weakened and a raid may be entered.
signal raid_available(weakened_for: float)
signal weakened_ended()

signal raid_started()

## An extraction window opened or closed.
signal raid_window_opened(seconds: float)
signal raid_window_closed()

## A window was refused; the camp escalates.
signal raid_escalated(refusals: int)

signal chieftain_spawned(captive_id: String)

## The raid ended. `reward` carries what was taken out, if anything.
signal raid_ended(reward: Dictionary)

# ==============================================================================
# RUN AND SCOPE FLOW (GDD §9)
# ==============================================================================

## The visible scope changed. Values are GameDirector.Scope.
signal scope_changed(scope: int)

## The run phase changed. Values are RunState.Phase.
signal phase_changed(phase: int, previous_phase: int)

## Preparation countdown or readiness changed.
signal preparation_changed(seconds_left: float, ready: bool)

## Ride On was refused until the player acknowledges a coverage warning.
signal preparation_warning(message: String)

signal run_started()
signal run_ended(victory: bool, summary: Dictionary)

## Something was added to the persistent unlock pool.
signal unlock_earned(kind: String, id: String)

# ==============================================================================
# CO-OP (GDD §54, amended 2026-08-24 — see docs/COOP_DESIGN.md)
# ==============================================================================

## The co-op session changed shape. `state` is a `Coop.State`, passed as an int
## because this file may not reach an autoload for a type.
signal coop_state_changed(state: int)

## The other player arrived. Host-side fact; the guest learns it by connecting.
signal coop_partner_joined(peer_id: int)

## The other player is gone — quit, dropped, or the host closed the session.
signal coop_partner_left(peer_id: int)

## Hosting or joining did not work, with a sentence fit to show a player.
signal coop_failed(reason: String)

## A guest asked the host to do something. Host-side only, and a *request* rather
## than a fact: the host still validates it and answers by authoring a fact.
## `kind` is a `CoopRelay.Request`.
signal coop_request_received(kind: int, args: Array, from_peer: int)

## Where both heroes are, authored by the host (`docs/COOP_DESIGN.md` §6).
##
## Named by role rather than by "mine" and "theirs" on purpose: the two swap
## across the wire, and a guest reading its own body as its partner's would have
## each player watching the other wearing their name.
signal coop_hero_state(host_at: Vector2, host_aim: Vector2,
	guest_at: Vector2, guest_aim: Vector2)

## A tower appeared, changed tier, or went away — on the host's say-so.
## An empty `tower_id` means the plot is now clear.
signal coop_tower_state(anchor: Vector2i, tower_id: String, level: int)

## The host put an enemy on the field and gave it an identity.
signal coop_enemy_spawned(net_id: int, data_id: String, lane: int, at: Vector2,
	hp_scale: float, damage_scale: float, speed_scale: float)

## Where every living enemy is, in one message. Entries are
## `[net_id: int, at: Vector2, health_ratio: float]`.
signal coop_enemy_batch(entries: Array)

## An enemy is gone. Sent explicitly rather than inferred from a missing batch
## entry: a guest deleting anything absent from a packet would empty the field
## the first time one arrived late.
signal coop_enemy_removed(net_id: int)

## The host refused something this machine asked for, with a reason already
## written for a player to read. Guest-side.
signal coop_request_refused(kind: int, reason: String)
