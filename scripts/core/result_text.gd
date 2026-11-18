extends RefCounted
## The words of a result as data (REQ-FL-67a, REQ-FL-62, issue #470). The TV sends the place as a number and the score as a key of
## `assets/lang/strings.csv` with its numbers, never as text, so that each phone writes them in its own language and not in the
## one of the TV. The TV writes its own list with the same function, so that both sides use the same keys.

const Lang = preload("res://scripts/core/lang.gd")

## The keys of a score and how many numbers each needs. The phone builds a text for these keys only (a key that is not here shows
## nothing). `num` is a plain number (`format_number()`), no text of the table.
const KINDS := {
	"num": 1, "result.not_finished": 0, "result.points": 1, "result.one_point": 0, "result.stars": 1, "result.one_star": 0,
	"result.seconds_1": 1, "result.seconds_2": 1, "tower_builder.n_bricks": 1, "tower_builder.one_brick": 0,
	"air_hockey.n_goals": 1, "air_hockey.one_goal": 0, "sheep_herding.count": 2, "paint_grab.percent": 1,
}
const SECONDS := ["result.seconds_1", "result.seconds_2"]   # The keys whose number is a decimal (the others are whole).
const PLACES := 4
const MAX_ARGS := 2


## "12" for a whole number, "12.5" otherwise.
static func format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## The place `n` (1 to 4) as text in the current language ("1ST", "ראשון"). Empty for any other number.
static func place(n: int) -> String:
	return Lang.t("result.place_%d" % n) if n >= 1 and n <= PLACES else ""


## One score as data: the key and the numbers. It is what `spec_text()` takes, and the `k` and `x` fields of `final`.
static func spec(key: String, args: Array = []) -> Array:
	return [key, args]


## The text of the score `key` with the numbers `args`, in the current language. Empty for a key that is not in `KINDS`, for too
## few numbers or for a value that is not a number.
static func text(key: String, args: Array) -> String:
	if not KINDS.has(key) or args.size() < int(KINDS[key]):
		return ""
	var values: Array = []
	for i in int(KINDS[key]):
		var v: Variant = args[i]
		if not (v is int or v is float) or not is_finite(float(v)):
			return ""
		values.append(float(v) if SECONDS.has(key) else int(v))
	if key == "num":
		return format_number(float(args[0]))
	return Lang.f(key, values) if values.size() > 0 else Lang.t(key)


## `text()` of a `spec()`.
static func spec_text(s: Array) -> String:
	return text(String(s[0]), s[1])
