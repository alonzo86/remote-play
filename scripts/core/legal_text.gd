extends RefCounted
## The privacy notice inside the app. The text is the file of the website: `docs/legal/privacy-notice.md` (English) and
## `privacy-notice.he.md` (Hebrew), which the export presets include in the app (`include_filter`). So the app, the website
## (`tools/make_legal_pages.py`) and the store forms have one text, and a change of the file changes all of them.
## This module reads the small Markdown subset that the converter of the website knows: `#` and `##` headings, paragraphs,
## `- ` lists, one table, `**bold**`, `` `code` ``, `[text](url)`, `<url>` and the `<div>` wrapper of the Hebrew text. The marks
## are removed: the pixel font has no bold, and an address is not a link here (the notice is text, the app opens no web page).

const Lang = preload("res://scripts/core/lang.gd")

const FILES := {Lang.EN: "res://docs/legal/privacy-notice.md", Lang.HE: "res://docs/legal/privacy-notice.he.md"}
const WRAPPERS := ['<div dir="rtl" lang="he">', "</div>"]

static var _marks: RegEx   # The marked parts of a line (made on the first use).


## The file of the language of the app (Hebrew has its own file, every other language gets the English one).
static func privacy_file(language: String = Lang.current()) -> String:
	return FILES.get(language, FILES[Lang.EN])


## The blocks of the privacy notice in the language `language`: [{"kind": "h1" | "h2" | "p" | "li" | "row", "text": text}].
static func privacy_blocks(language: String = Lang.current()) -> Array:
	return parse(FileAccess.get_file_as_string(privacy_file(language)))


## The blocks of a Markdown text. A row of the table is one block: each cell with the name of its column ("Where it lives: ...").
static func parse(markdown: String) -> Array:
	var out: Array = []
	var lines := markdown.replace("\r\n", "\n").split("\n")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if line.strip_edges() == "" or line.strip_edges() in WRAPPERS:
			i += 1
		elif line.begins_with("# "):
			out.append({"kind": "h1", "text": plain(line.substr(2))})
			i += 1
		elif line.begins_with("## "):
			out.append({"kind": "h2", "text": plain(line.substr(3))})
			i += 1
		elif line.begins_with("- "):
			out.append({"kind": "li", "text": plain(line.substr(2))})
			i += 1
		elif line.begins_with("|"):
			var rows: Array = []
			while i < lines.size() and String(lines[i]).begins_with("|"):
				rows.append(cells(lines[i]))
				i += 1
			var names: Array = rows[0]
			for r in range(2, rows.size()):   # Row 1 is the line of dashes under the names.
				var parts := PackedStringArray()
				for c in names.size():
					parts.append("%s: %s" % [names[c], rows[r][c] if c < rows[r].size() else ""])
				out.append({"kind": "row", "text": "\n".join(parts)})
		else:
			var para := PackedStringArray()
			while i < lines.size() and String(lines[i]).strip_edges() != "" and not _starts_block(lines[i]):
				para.append(plain(String(lines[i]).strip_edges()))
				i += 1
			out.append({"kind": "p", "text": "\n".join(para)})
	return out


static func _starts_block(line: String) -> bool:
	return line.begins_with("#") or line.begins_with("- ") or line.begins_with("|")


## The cells of a table line, without the marks.
static func cells(line: String) -> Array:
	var out: Array = []
	for c in line.strip_edges().trim_prefix("|").trim_suffix("|").split("|"):
		out.append(plain(c.strip_edges()))
	return out


## A text without its marks: bold and code lose the signs, `[text](url)` becomes "text (url)" and `<url>` becomes the address.
static func plain(text: String) -> String:
	if _marks == null:
		_marks = RegEx.create_from_string("<(https?://[^>\\s]+)>|\\*\\*(.+?)\\*\\*|`([^`]+)`|\\[([^\\]]+)\\]\\(([^)\\s]+)\\)")
	var out := ""
	var pos := 0
	for m in _marks.search_all(text):
		out += text.substr(pos, m.get_start() - pos)
		if m.get_string(1) != "":
			out += m.get_string(1)
		elif m.get_string(2) != "":
			out += plain(m.get_string(2))
		elif m.get_string(3) != "":
			out += m.get_string(3)
		else:
			out += "%s (%s)" % [plain(m.get_string(4)), m.get_string(5)]
		pos = m.get_end()
	return out + text.substr(pos)
