class_name Heralds
extends RefCounted

## **The Herald: the one body on the road only a Warden can stop** (2026-09-30).
##
## `DESIGN_DIRECTION_2026-09-22` section 2 named two answers to a late game
## that plays itself once every road is covered. Siege orders were the first
## (2026-09-24): the board takes attrition and the Warden has somewhere to be.
## This is the second - an objective the towers cannot solve.
##
## A Herald is an ordinary breed of the region, promoted by its own numbers,
## running for the gate. **The board cannot see it**: no tower aims at it and a
## shot's splash glances off it (the Mirrorhide door, `glances_tower_shots`), no
## trap springs on it or bites it, no ground a tower's shot leaves burns it, and
## no weapon on the board's Arsenal reaches it. A Warden's own sword, spells,
## arrows, spirit and Arsenal do.
##
## **Reaching the wall is a call**, not a loss: the next wave comes larger a
## road (`Balance.HERALD_REINFORCE_SHARE`), and the board may shoot the Herald
## from then on, so the wave still ends through the ordinary door. **Run down
## before it gets there, it drops a purse** the size of a camp's, split as a
## raze is. So fast-forwarding a wave with a Herald in it costs something the
## player can see, and the Warden's place on the field is a decision again.
##
## **Solo for 1.0**, as the wayside encounters are: which machine's Warden ran
## it down is a question for the co-op relay nobody has asked yet. Never on the
## Walk, whose valley teaches the road before it teaches this.

const ROSE_LINE: String = "A Herald runs for the gate. The towers cannot see it - catch it."
const CALLED_LINE: String = "The Herald reached the wall. Its horn calls the next wave larger."
const FELL_LINE: String = "The Herald is down before it could call. Its purse is yours."


## Whether a wave in `act` may carry a Herald at all.
static func may_rise(act: int) -> bool:
	if Coop.is_networked() or RunState.walking:
		return false
	return act >= Balance.HERALD_FIRST_ACT


## What a Herald run down before the wall leaves on the ground, by currency.
## One function, read by the payout and by `herald_check`.
static func bounty(act: int) -> Dictionary:
	var value: float = float(Balance.HERALD_BOUNTY) * Balance.kill_act_scale(act)
	var out: Dictionary = {}
	for id: Variant in Balance.CAMP_CURRENCY_SPLIT:
		out[String(id)] = int(round(value * float(Balance.CAMP_CURRENCY_SPLIT[id])))
	return out


## A road's bodies after a Herald's call: a share more, and never fewer than one
## more, so a small early wave is still visibly larger.
static func reinforced(per_lane: int) -> int:
	return per_lane + maxi(1, ceili(float(per_lane) * Balance.HERALD_REINFORCE_SHARE))
