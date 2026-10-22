extends SceneTree
## The room code (issue #52, docs/PROTOCOL.md "Room code"): the last two numbers of the TV address, scrambled by a fixed
## multiplication and written as 4 letters. Every value round-trips, no two addresses share a code, a typo is rejected when it
## is above 65535, and the phone builds the address from its own Wi-Fi address. Also the text of the TV QR code (no PIN).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/room_code.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")

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
	_run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	_codes()
	_decode()
	_hosts()
	_links()


func _codes() -> void:
	print("the code of an address")
	_check(Protocol.room_code_for_ip("192.168.1.23") == "DREJ", "192.168.1.23 has the code DREJ (the owner's example: 1 and 23)")
	_check((Protocol.ROOM_MULTIPLIER * Protocol.ROOM_MULTIPLIER_INVERSE) % 65536 == 1 and Protocol.ROOM_MULTIPLIER % 2 == 1,
			"the multiplier is odd and its inverse undoes it modulo 65536")
	var seen := {}
	var round_trips := true
	var alphabet_ok := true
	var first_letters := {}
	for v in 65536:
		var code := Protocol.room_code_for_ip("10.9.%d.%d" % [v >> 8, v & 255])
		seen[code] = true
		round_trips = round_trips and Protocol.decode_room_code(code) == v
		alphabet_ok = alphabet_ok and code.length() == 4
		first_letters[code[0]] = true
		for ch in code:
			alphabet_ok = alphabet_ok and Protocol.ROOM_ALPHABET.contains(ch)
	_check(round_trips, "every one of the 65536 values decodes to the value that made the code")
	_check(seen.size() == 65536, "the scramble is a bijection: 65536 values give 65536 different codes (%d)" % seen.size())
	_check(alphabet_ok, "every code has 4 letters of the alphabet")
	_check(first_letters.size() <= 7 and first_letters.size() >= 2,
			"the first letter uses only part of the alphabet, as the value is below 65536 (%d letters)" % first_letters.size())
	var near := {}
	for last in 20:
		near[Protocol.room_code_for_ip("192.168.1.%d" % last)] = true
	var starts := {}
	for c in near:
		starts[String(c).substr(0, 2)] = true
	_check(starts.size() > 4, "the codes of one network do not all look alike (%d starts in 20 codes)" % starts.size())
	_check(Protocol.room_code_for_ip("") == "" and Protocol.room_code_for_ip("192.168.1") == ""
			and Protocol.room_code_for_ip("a.b.c.d") == "" and Protocol.room_code_for_ip("192.168.1.256") == "",
			"a text that is not an IPv4 address has no code")


func _decode() -> void:
	print("the typed text")
	var v := 1 * 256 + 23
	_check(Protocol.decode_room_code("DREJ") == v, "DREJ is 1 and 23")
	_check(Protocol.decode_room_code("drej") == v, "lower case is accepted")
	_check(Protocol.decode_room_code(" d r e j ") == v, "spaces are ignored")
	_check(Protocol.clean_room_code(" d r e j ") == "DREJ", "the cleaned text is upper case without spaces")
	_check(["DRE", "DREJA", ""].all(func(t): return Protocol.decode_room_code(t) == -1), "a wrong length is not a code")
	_check(["DRE1", "DREB", "DRE-"].all(func(t): return Protocol.decode_room_code(t) == -1),
			"a letter that is not in the alphabet (B, a digit, a sign) is not a code")
	_check(Protocol.decode_room_code("ZZZZ") == -1 and Protocol.decode_room_code("YAAA") == -1,
			"a value above 65535 is not a code: a typo is found at once")
	# 22^4 = 234256 texts, 65536 of them are codes: most typos of one letter are caught or point to another address.
	var caught := 0
	var total := 0
	for i in 4:
		for ch in Protocol.ROOM_ALPHABET:
			var typo := "DREJ".substr(0, i) + ch + "DREJ".substr(i + 1)
			if typo == "DREJ":
				continue
			total += 1
			if Protocol.decode_room_code(typo) == -1:
				caught += 1
	_check(caught > 0 and caught < total,
			"some one-letter typos are rejected by the phone (%d of %d), the others reach another address" % [caught, total])


func _hosts() -> void:
	print("the address that the phone builds")
	var own: Array[String] = ["192.168.1.77"]
	_check(str(Protocol.hosts_for_code("DREJ", own)) == str(["192.168.1.23"]),
			"the first two numbers are the phone's, the last two the code's")
	_check(str(Protocol.hosts_for_code("drej", own)) == str(["192.168.1.23"]), "the code is cleaned first")
	var two: Array[String] = ["192.168.1.77", "10.5.0.4", "192.168.9.9"]
	_check(str(Protocol.hosts_for_code("DREJ", two)) == str(["192.168.1.23", "10.5.1.23"]),
			"each address of the phone gives one address to try, the same one only once")
	_check(Protocol.hosts_for_code("DRE", own).is_empty(), "an invalid code has no address")
	_check(Protocol.hosts_for_code("DREJ", []).is_empty(), "a phone with no private address has none")
	var best := Protocol.best_private(["10.0.0.4", "192.168.43.1", "fe80::1", "172.20.1.1", "192.168.2.2"])
	_check(str(best) == str(["192.168.43.1", "192.168.2.2"]),
			"the phone uses the 192.168 addresses first and all of them: %s" % str(best))


func _links() -> void:
	print("the QR text")
	var url := Protocol.pair_url("192.168.1.23", "DREJ")
	_check(url == "ws://192.168.1.23:47801/DREJ", "the TV link has the address, the port and the room: " + url)
	var pair := Protocol.parse_pair_url(url)
	_check(pair.host == "192.168.1.23" and pair.port == 47801 and pair.room == "DREJ" and not pair.has("pin"),
			"the link is read back, with no PIN")
	_check(Protocol.parse_pair_url("ws://10.0.0.5:47801").room == "", "a link without a room is accepted")
	_check(Protocol.parse_pair_url(url + "?pin=1234").is_empty(), "a link of the old version with a PIN is not a TV link")
	var others := ["http://192.168.1.23:47801/DREJ", "ws://192.168.1.23/DREJ", "ws://192.168.1.23:47801/DRE",
			"ws://192.168.1.23:47801/DREB"]
	_check(others.all(func(t): return Protocol.parse_pair_url(t).is_empty()), "other text is not a TV link")
	_check(Protocol.VERSION == 4, "the protocol version is 4 (no PIN, no beacon)")
