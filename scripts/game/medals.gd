extends RefCounted
## Medals (REQ-GM-73). A medal is given for a place only, in a round with more than one player: 1st gold, 2nd silver, 3rd bronze.
## There are no medal tiers for a score and no medal for one player (issue #119). A medal is not saved; the personal best of a
## profile is separate (REQ-GM-98).

const NONE := ""
const BRONZE := "bronze"
const SILVER := "silver"
const GOLD := "gold"
const NAMES := [BRONZE, SILVER, GOLD]


## The medal of a place in a round with more than one player: 1st gold, 2nd silver, 3rd bronze, nothing after that. Players that
## share a place (a tie) have the same medal.
static func for_place(place: int) -> String:
	return NAMES[NAMES.size() - place] if place >= 1 and place <= NAMES.size() else NONE
