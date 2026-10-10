extends RefCounted
## The language of the app (FD-19, REQ-FL-54, 60 to 63): English and Hebrew. The text of the UI is its English text in upper case
## (a format string stays as it is written); `scripts/core/strings.gd` has the Hebrew text for each. Labels and buttons
## translate by themselves when the language changes. Text that code draws (`Shell`) or builds (a format with a name or a
## number) goes through `t()` and `f()`. Player names are never translated.

const Strings = preload("res://scripts/core/strings.gd")

const EN := "en"
const HE := "he"
const CODES: Array[String] = [EN, HE]
## The name of each language, in that language (the choice on the logo screen).
const NAMES := {EN: "English", HE: "עברית"}

static var _code := EN
static var _registered := false


## Gives the translations to the TranslationServer. It is safe to call it again.
static func register() -> void:
	if _registered:
		return
	_registered = true
	var tr_he := Translation.new()
	tr_he.locale = HE
	for k in Strings.HE:
		tr_he.add_message(k, Strings.HE[k])
	TranslationServer.add_translation(tr_he)


static func current() -> String:
	return _code


static func is_rtl() -> bool:
	return _code == HE


## The language of the device when the app supports it, else English (Hebrew has two codes, "he" and the old "iw").
static func system_language() -> String:
	var l := OS.get_locale_language()
	return HE if l == HE or l == "iw" else EN


## Switches the UI to `code` at once. `window` gets the layout direction (right to left in Hebrew). Labels and buttons update
## by themselves. A code that is not supported is ignored.
static func set_language(code: String, window: Window = null) -> void:
	if not (code in CODES):
		return
	register()
	_code = code
	TranslationServer.set_locale(code)
	if window != null:
		window.set_layout_direction(Window.LAYOUT_DIRECTION_RTL if is_rtl() else Window.LAYOUT_DIRECTION_LTR)


## The next language after `code` in the list (the Settings row switches between the two).
static func other(code: String) -> String:
	return HE if code != HE else EN


## `msg` in the current language. A plain text is looked up in upper case, a format string as it is written.
## A text that has no translation stays as it is.
static func t(msg: String) -> String:
	if _code == EN:
		return msg
	var out := TranslationServer.translate(msg)
	if out != msg:
		return out
	var upper := msg.to_upper()
	out = TranslationServer.translate(upper)
	return out if out != upper else msg   # Without a translation the server gives the key back: keep the text as it was written.


## A format string in the current language, with its values. `fmt` uses `%s` and `%d`.
static func f(fmt: String, args: Array) -> String:
	return t(fmt) % args
