extends SceneTree
## Issue #296: nothing else ties scripts/core/protocol.gd and the net code to docs/PROTOCOL.md. This suite does:
## (1) the messages of the tables of the document, Protocol.MESSAGES and the "t" values written in scripts/net/ are the same set,
## with the same sender; (2) the numbers that the document quotes are the numbers of protocol.gd; (3) the removal of `lang` is not
## forgotten at the next VERSION bump. Run:
##   godot --headless --path . --script tests/protocol_doc.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The `"t"` values that a file writes as literals: {"t": "bye"} (not "t0", not a comparison with get("t")).
func _literals(path: String) -> Array:
	var re := RegEx.create_from_string('"t":\\s*"([a-z_]+)"')
	var names := {}
	for m in re.search_all(_read(path)):
		names[m.get_string(1)] = true
	var out := names.keys()
	out.sort()
	return out


## name -> sender ("phone", "tv" or "both") from the rows `| Phone | ...{"t":"x"` of the tables of docs/PROTOCOL.md.
func _doc_messages() -> Dictionary:
	var senders := {}
	var row := RegEx.create_from_string('^\\| (Phone|TV|Both) \\| `\\{"t":"([a-z_]+)"')
	for line in _read("res://docs/PROTOCOL.md").split("\n"):
		var m := row.search(line)
		if m == null:
			continue
		var who := m.get_string(1).to_lower()
		var name := m.get_string(2)
		if not senders.has(name):
			senders[name] = who
		elif senders[name] != who:
			senders[name] = "both"
	return senders


func _run() -> void:
	var doc := _doc_messages()
	var code: Dictionary = Protocol.MESSAGES
	var doc_names := doc.keys()
	doc_names.sort()
	var code_names := code.keys()
	code_names.sort()
	_check(doc_names.size() > 15, "the document lists the messages (%d)" % doc_names.size())
	_check(doc_names == code_names,
			"docs/PROTOCOL.md and Protocol.MESSAGES list the same messages (doc: %s, code: %s)" % [str(doc_names), str(code_names)])
	for name in code_names:
		if doc.has(name):
			_check(doc[name] == code[name], "%s: sender %s in Protocol.MESSAGES, %s in the document" % [name, code[name], doc[name]])

	# The "t" literals of the net code: every one is a known message, and each message is written by the files of its sender.
	var tv_lit := _literals("res://scripts/net/tv_server.gd")
	var ph_lit := _literals("res://scripts/net/controller_client.gd")
	for name in tv_lit:
		_check(code.has(name) and code[name] in ["tv", "both"], "tv_server.gd writes \"%s\": it is a message of the TV" % name)
	for name in ph_lit:
		_check(code.has(name) and code[name] in ["phone", "both"], "controller_client.gd writes \"%s\": a message of the phone" % name)
	for name in code_names:
		var who: String = code[name]
		if who in ["tv", "both"]:
			_check(name in tv_lit, "%s: tv_server.gd writes it" % name)
		if who in ["phone", "both"]:
			_check(name in ph_lit, "%s: controller_client.gd writes it" % name)

	# The numbers that the document quotes.
	var text := _read("res://docs/PROTOCOL.md")
	_quote(text, "# Network protocol, version (\\d+)", Protocol.VERSION, "the version in the title")
	_quote(text, "\\| (\\d+) \\| TCP \\|", Protocol.WS_PORT, "the port")
	_quote(text, "Size: (\\d+) bytes", Protocol.SENSOR_PACKET_SIZE, "the size of the sensor packet")
	_quote(text, "The TV has (\\d+) slots", Protocol.MAX_PLAYERS, "the number of slots")
	_quote(text, "about (\\d+) per second", Protocol.SENSOR_HZ, "the sensor packets a second")
	_quote(text, "sends no `hello` in (\\d+) seconds", Protocol.HELLO_TIMEOUT_MS / 1000, "the time to the hello (s)")
	_quote(text, "silent for (\\d+) seconds \\(`PEER_TIMEOUT_MS`", Protocol.PEER_TIMEOUT_MS / 1000, "PEER_TIMEOUT_MS (s)")
	_quote(text, "no frame for `PEER_TIMEOUT_MS` \\((\\d+) s\\)", Protocol.PEER_TIMEOUT_MS / 1000, "PEER_TIMEOUT_MS again (s)")
	_quote(text, "keeps a lost slot for (\\d+) seconds \\(`SLOT_GRACE_MS`", Protocol.SLOT_GRACE_MS / 1000, "SLOT_GRACE_MS (s)")
	_quote(text, "keeps it for (\\d+) minutes \\(`PAUSED_SLOT_GRACE_MS`", Protocol.PAUSED_SLOT_GRACE_MS / 60000,
			"PAUSED_SLOT_GRACE_MS (min)")
	_quote(text, "for (\\d+) minutes \\(`REPLACED_TOKEN_MS`", Protocol.REPLACED_TOKEN_MS / 60000, "REPLACED_TOKEN_MS (min)")
	_quote(text, "`NAME_MAX` = (\\d+)", Protocol.NAME_MAX, "NAME_MAX")
	_quote(text, "`LEAVE_ASK_MIN_MS` \\((\\d+) ms", Protocol.LEAVE_ASK_MIN_MS, "LEAVE_ASK_MIN_MS (ms)")

	# The join approval (FD-30): the keepalive of `pending` and the numbers of the TV that the document quotes.
	_quote(text, "again every (\\d+) seconds \\(`PENDING_KEEPALIVE_MS`", Protocol.PENDING_KEEPALIVE_MS / 1000,
		"PENDING_KEEPALIVE_MS (s)")
	var tv: TvServer = TvServer.new()
	_quote(text, "(\\d+) seconds with the card shown \\(`approval_timeout_ms`", tv.approval_timeout_ms / 1000,
		"approval_timeout_ms (s)")
	_quote(text, "or (\\d+) seconds in total \\(`approval_total_ms`", tv.approval_total_ms / 1000, "approval_total_ms (s)")
	_quote(text, "(\\d+) second after the last \\(`approval_gap_ms`", tv.approval_gap_ms / 1000, "approval_gap_ms (s)")
	_quote(text, "at most (\\d+) requests wait at one time \\(`TvServer.MAX_WAITING`", TvServer.MAX_WAITING, "MAX_WAITING")
	_quote(text, "at most (\\d+) request \\(`max_waiting_per_ip`", tv.max_waiting_per_ip, "max_waiting_per_ip")
	_quote(text, "After (\\d+) host refusals in a row from one address \\(`refuse_block_after`", tv.refuse_block_after,
		"refuse_block_after")
	_quote(text, "blocked for (\\d+) seconds \\(`refuse_block_ms`", tv.refuse_block_ms / 1000, "refuse_block_ms (s)")
	_quote(text, "for at most (\\d+) addresses \\(`max_refusal_entries`", tv.max_refusal_entries, "max_refusal_entries")
	_quote(text, "keeps at most (\\d+) \\(`MAX_KNOWN_TOKENS`", TvServer.MAX_KNOWN_TOKENS, "MAX_KNOWN_TOKENS")
	_quote(text, "for at most (\\d+) frames in each frame \\(`MAX_WAITING_FRAMES`", TvServer.MAX_WAITING_FRAMES,
		"MAX_WAITING_FRAMES")
	tv.free()

	# REQ-FL-29: the document names every value of `phase` that the TV code sends, among them `connect` and `menu`.
	var phase_row := ""
	for line in text.split("\n"):
		if line.contains('{"t":"phase"'):
			phase_row = line
	var tv_src := _read("res://scripts/net/tv_server.gd") + _read("res://scripts/app.gd")
	for v in ["connect", "menu", "playing", "paused", "waiting"]:
		_check(phase_row.contains("`%s`" % v), "REQ-FL-29: docs/PROTOCOL.md describes the phase value `%s`" % v)
	for v in ["connect", "menu"]:
		_check(tv_src.contains('set_phase("%s")' % v), "REQ-FL-29: the TV code sends the phase `%s` (set_phase)" % v)

	# `lang` goes at the next incompatible version (issue #171, #296).
	var lang_due: bool = Protocol.VERSION > Protocol.LANG_REMOVE_AFTER_VERSION and Protocol.MESSAGES.has("lang")
	_check(not lang_due, "VERSION is %d: remove `lang` and welcome.lang when it is above %d"
			% [Protocol.VERSION, Protocol.LANG_REMOVE_AFTER_VERSION])
	_check(text.contains("LANG_REMOVE_AFTER_VERSION"), "the document tells that `lang` goes at the next VERSION bump")


func _quote(text: String, pattern: String, expected: int, what: String) -> void:
	var m := RegEx.create_from_string(pattern).search(text)
	if m == null:
		_check(false, "%s: the document does not quote it (pattern %s)" % [what, pattern])
		return
	_check(int(m.get_string(1)) == expected, "%s: the document says %s, protocol.gd has %d" % [what, m.get_string(1), expected])
