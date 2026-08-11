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

## The hero's dash started; `iframes` is how long invulnerability lasts.
signal hero_dashed(iframes: float)

## A swing connected with at least one target. `chain_step` is 0-based.
signal hero_attack_landed(chain_step: int, targets_hit: int, at: Vector2)

## An enemy entered the world. `enemy_id` is the EnemyData id, not a node name.
signal enemy_spawned(enemy_id: String, at: Vector2)

## An enemy reached zero HP. Kill credit, raid charge and drops read off this.
signal enemy_died(enemy_id: String, at: Vector2)

## Something wants the camera shaken — decoupled so any system can ask.
signal camera_shake_requested(magnitude: float, duration: float)

## Something wants a brief global freeze on impact. Highest request wins.
signal hitstop_requested(duration: float)

# ==============================================================================
# STAGE 2+ — battlefield, city, macro, raid (declared, not yet emitted)
# ==============================================================================

## A lane's pressure value changed; the directional indicator reads off this.
signal lane_pressure_changed(lane_index: int, pressure: float)

## An enemy reached the city centre and did damage.
signal city_damaged(amount: float, current_hp: float, max_hp: float)

## Total distance travelled changed. Construction progress is gated on this.
signal distance_changed(total_distance: float, act_distance: float)

## The beast's walking speed changed in response to performance.
signal beast_speed_changed(speed: float)

## The war horn was blown. Distance freezes for `duration` seconds.
signal war_horn_activated(duration: float)

## The war horn window closed and distance resumes.
signal war_horn_ended()

## Raid charge changed, normalised 0..1.
signal raid_charge_changed(charge: float)

## The hero left for the enemy base. The battlefield keeps running.
signal raid_started()

## The raid ended. `standard_id` is empty if the hero was ejected with nothing.
signal raid_ended(standard_id: String)

## A segment boundary was reached and combat paused for a crossroad.
signal crossroad_reached(segment_index: int)

## The player chose a road and combat resumes.
signal crossroad_resolved(option_id: String)

## An act boss was killed. Act 3's kill also ends the run.
signal boss_defeated(boss_id: String, act: int)

## The run ended, either by reaching the safe zone or by losing the city.
signal run_ended(victory: bool)
