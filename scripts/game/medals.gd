extends RefCounted
## Medals for a round with one player (REQ-GM-73). The tiers are `[bronze, silver, gold]`, from the easy limit to the
## hard one. A score at the limit or better earns the medal. Nothing is saved: the player is not identified yet.

const NONE := ""
const BRONZE := "bronze"
const SILVER := "silver"
const GOLD := "gold"
const NAMES := [BRONZE, SILVER, GOLD]


## The best medal for `score`, or NONE. With `lower_is_better` a smaller number is a better score (a time).
static func medal(score: float, tiers: Array, lower_is_better := false) -> String:
	var best := NONE
	for i in mini(tiers.size(), NAMES.size()):
		var reached: bool = score <= float(tiers[i]) if lower_is_better else score >= float(tiers[i])
		if reached:
			best = NAMES[i]
	return best


## True when the tiers are three numbers and each one is harder than the one before.
static func is_valid(tiers: Array, lower_is_better := false) -> bool:
	if tiers.size() != NAMES.size():
		return false
	for i in range(1, tiers.size()):
		var harder: bool = float(tiers[i]) < float(tiers[i - 1]) if lower_is_better else float(tiers[i]) > float(tiers[i - 1])
		if not harder:
			return false
	return true


## The text for the result screen.
static func label(medal_name: String) -> String:
	return "%s medal!" % medal_name.capitalize() if medal_name != NONE else "No medal this time"
