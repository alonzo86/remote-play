extends RefCounted
## The language of the app (FD-19, REQ-FL-54, 60 to 63): English and Hebrew. Each text of the UI has a key (`pin.wrong`) and a
## row in `assets/lang/strings.csv` with the English and the Hebrew text. Labels and buttons translate by themselves when the
## language changes (their text is the key). Text that code draws (`Shell`) or builds (a format with a name or a number) goes
## through `t()` and `f()`. Player names are never translated.

## The table of texts: `assets/lang/strings.csv` has a row for each text (key, English, Hebrew, where, notes).
const TABLE_FILE := "res://assets/lang/strings.csv"

const EN := "en"
const HE := "he"
const CODES: Array[String] = [EN, HE]
## The name of each language, in that language (the choice on the logo screen).
const NAMES := {EN: "English", HE: "עברית"}

static var _code := EN
## The language code of the device. Empty means ask the operating system. A test sets it to pretend a device with that locale.
static var device_locale := ""
static var _registered := false
static var _table: Dictionary = {}   # key -> {"en": text, "he": text}


## Reads the CSV and gives the translations to the TranslationServer. It is safe to call it again.
static func register() -> void:
	if _registered:
		return
	_registered = true
	_table = parse_table(FileAccess.get_file_as_string(TABLE_FILE))
	for code in CODES:
		var tr := Translation.new()
		tr.locale = code
		for key in _table:
			tr.add_message(key, _table[key][code])
		TranslationServer.add_translation(tr)


## The rows of a CSV text (first line: key, en, he, where, notes) as {key: {"en": ..., "he": ...}}. A Hebrew cell that is empty
## falls back to the English text. The file may start with a byte order mark (Excel adds one). A text without the header row
## gives an empty table.
static func parse_table(text: String) -> Dictionary:
	var lines := parse_csv(text.trim_prefix("\ufeff"))
	if lines.is_empty() or lines[0].size() < 3 or lines[0][0] != "key":
		return {}
	var out := {}
	for i in range(1, lines.size()):
		var cells: Array = lines[i]
		if cells.size() >= 3 and cells[0] != "":
			out[cells[0]] = {EN: cells[1], HE: cells[2] if cells[2] != "" else cells[1]}
	return out


## The cells of a CSV text, a line at a time. A cell in quotes may hold commas, line breaks and a quote written twice.
static func parse_csv(text: String) -> Array:
	var rows: Array = []
	var row: Array = []
	var cell := ""
	var quoted := false
	var i := 0
	while i < text.length():
		var ch := text[i]
		if quoted:
			if ch == '"' and i + 1 < text.length() and text[i + 1] == '"':
				cell += '"'
				i += 1
			elif ch == '"':
				quoted = false
			else:
				cell += ch
		elif ch == '"':
			quoted = true
		elif ch == ",":
			row.append(cell)
			cell = ""
		elif ch == "\n" or ch == "\r":
			if ch == "\r" and i + 1 < text.length() and text[i + 1] == "\n":
				i += 1
			row.append(cell)
			cell = ""
			rows.append(row)
			row = []
		else:
			cell += ch
		i += 1
	if cell != "" or not row.is_empty():
		row.append(cell)
		rows.append(row)
	return rows


## All rows of the table: {key: {"en": ..., "he": ...}}.
static func table() -> Dictionary:
	register()
	return _table


## True when `key` is a key of the table (a player name or any other text is not).
static func has(key: String) -> bool:
	register()
	return _table.has(key)


static func current() -> String:
	return _code


static func is_rtl() -> bool:
	return _code == HE


## The language of the device when the app supports it, else English (Hebrew has two codes, "he" and the old "iw").
static func system_language() -> String:
	var l := device_locale if device_locale != "" else OS.get_locale_language()
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


## The text of `key` in the current language. A text that is not a key (a player name) stays as it is.
static func t(key: String) -> String:
	register()
	return _table[key][_code] if _table.has(key) else key


## A format text in the current language, with its values. The text uses `%s` and `%d`.
static func f(key: String, args: Array) -> String:
	return t(key) % args
