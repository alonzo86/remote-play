extends RefCounted
## Medals for a round with one player (REQ-GM-73). The tiers are `[bronze, silver, gold]`, from the easy limit to the
## hard one. A score at the limit or better earns the medal. A medal is not saved; the personal best of a profile is separate
## (REQ-GM-98).

const Lang = preload("res://scripts/core/lang.gd")

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


## The medal of a place in a round with more than one player: 1st gold, 2nd silver, 3rd bronze, nothing after that. Players that
## share a place (a tie) have the same medal.
static func for_place(place: int) -> String:
	return NAMES[NAMES.size() - place] if place >= 1 and place <= NAMES.size() else NONE


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
	match medal_name:
		BRONZE:
			return Lang.t("medals.bronze_medal")
		SILVER:
			return Lang.t("medals.silver_medal")
		GOLD:
			return Lang.t("medals.gold_medal")
	return Lang.t("medals.no_medal_time")
