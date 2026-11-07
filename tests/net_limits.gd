extends SceneTree
## Limits of the TV against a client on the Wi-Fi (issues #387 and #388): connections that never send `hello` are capped, one
## address cannot open endless connections, a text frame above the limit is dropped before it is parsed, and a hello with no
## room is turned away by a release build. Real sockets on the local machine, like tests/net_malformed.gd.
## Run by tests/run_all.sh: godot --headless --path . --script tests/net_limits.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")

# Not the game port: another test or a TV app may hold it. It depends on the process, so two runs of this suite at the same
# time (two agents, two terminals) do not share a port and fail each other (found in the review of PR #391).
var PORT := 47000 + OS.get_process_id() % 900

var _checks := 0
var _fails := 0
var _server: TvServer


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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _pump(ws: WebSocketPeer, ms := 400) -> Array:
	var got := []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		ws.poll()
		while ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
			got.append(Protocol.parse_json(ws.get_packet().get_string_from_utf8()))
		await process_frame
	return got


func _connect() -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	ws.connect_to_url("ws://127.0.0.1:%d" % PORT)
	return ws


func _open(fields := {}) -> WebSocketPeer:
	var ws := _connect()
	var t0 := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t0 < 3000:
		ws.poll()
		await process_frame
	var msg := {"t": "hello", "v": Protocol.VERSION, "room": _server.room_code, "token": "", "name": ""}
	msg.merge(fields, true)
	ws.send_text(Protocol.to_json(msg))
	return ws


func _has(frames: Array, t: String) -> bool:
	return frames.any(func(f: Dictionary) -> bool: return f.get("t", "") == t)


func _new_server() -> void:
	_server = TvServer.new()
	_server.address_lookup = func() -> String: return "192.168.0.1"
	_server.port = PORT
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")


func _stop_server() -> void:
	_server.stop()
	_server.free()
	await _frames(5)


func _run() -> void:
	_codec()
	await _pending_cap()
	await _pending_per_address()
	await _requests_count()
	await _accept_rate()
	_address_key()
	await _address_keys()
	await _replace_shown()
	await _refusal_keys()
	await _big_frames()
	await _empty_room()


func _codec() -> void:
	print("sensor packets and tokens")
	for bad in [NAN, INF, -INF]:
		for field in 6:
			var vals := [0.0, 0.0, 0.0, 0.0, 9.81, 0.0]
			vals[field] = bad
			var evil := Protocol.encode_sensor(1, 1, Vector3(vals[0], vals[1], vals[2]),
					Vector3(vals[3], vals[4], vals[5]), 0, 0, Vector2.ZERO)
			_check(Protocol.decode_sensor(evil).is_empty(), "a packet with %s in float %d is rejected" % [str(bad), field])
	var good := Protocol.encode_sensor(1, 1, Vector3(1, 2, 3), Vector3(0, 9.81, 0), 0, 0, Vector2.ZERO)
	_check(not Protocol.decode_sensor(good).is_empty(), "a packet with finite floats is read")
	var huge := Protocol.encode_sensor(1, 1, Vector3(3.0e38, 0, 0), Vector3(0, 9.81, 0), 0, 0, Vector2.ZERO)
	_check(Protocol.decode_sensor(huge).is_empty(), "a packet with a huge float (3e38) is dropped")
	var big_accel := Protocol.encode_sensor(1, 1, Vector3.ZERO, Vector3(0, Protocol.SENSOR_MAX_ABS + 1.0, 0), 0, 0, Vector2.ZERO)
	var top_accel := Protocol.encode_sensor(1, 1, Vector3.ZERO, Vector3(0, 160.0, 0), 0, 0, Vector2.ZERO)
	_check(Protocol.decode_sensor(big_accel).is_empty() and not Protocol.decode_sensor(top_accel).is_empty(),
			"an accel above 1000 is dropped, 160 m/s2 (a hard hit) is read")
	var t1 := Protocol.make_token()
	_check(t1.length() == 32 and t1.is_valid_hex_number(false) and t1 != Protocol.make_token(),
			"a token is 32 hex characters and not repeated: " + t1)


func _pending_cap() -> void:
	print("connections that never send hello")
	_new_server()
	_server.max_pending_per_ip = 100   # Here every socket comes from 127.0.0.1: only the global cap is under test.
	var socks: Array[WebSocketPeer] = []
	for i in TvServer.MAX_PENDING + 8:
		socks.append(_connect())
		await _frames(2)
	await _frames(20)
	_check(_server._pending.size() <= TvServer.MAX_PENDING,
			"the TV holds at most %d: %d" % [TvServer.MAX_PENDING, _server._pending.size()])
	var late := await _open()
	var frames := await _pump(late)
	_check(not _has(frames, "welcome"), "a hello on a connection above the cap gets no welcome")
	for s in socks:
		s.close()
	await _frames(10)
	_server._pending.clear()
	var ok := await _open()
	_check(_has(await _pump(ok), "welcome"), "a phone joins when the pending connections are gone")
	await _stop_server()


func _pending_per_address() -> void:
	print("connections of one address that never send hello")
	_new_server()
	_server.max_pending_per_ip = 3
	var socks: Array[WebSocketPeer] = []
	for i in 5:
		socks.append(_connect())
		await _frames(2)
	await _frames(20)
	_check(_server._pending.size() == 3 and _server._pending_of("127.0.0.1") == 3,
			"one address holds at most 3 (the 4th and 5th are closed): %d" % _server._pending.size())
	_check(_server._pending_of("10.0.0.7") == 0, "another address has none pending")
	for s in socks:
		s.close()
	await _frames(10)
	_server._pending.clear()
	var ok := await _open()
	_check(_has(await _pump(ok), "welcome"), "the address joins again when its pending connections are gone")
	await _stop_server()


## A phone that waits for the host: its `hello` is queued, and the entry gets the address `host` (one machine has one address).
func _request(host: String) -> WebSocketPeer:
	var ws := _connect()
	var tagged := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		ws.poll()
		if not tagged:
			for e in _server._pending:
				if not e.has("test"):
					e["test"] = true
					e.host = host
					tagged = true
					break
		if tagged and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(Protocol.to_json({"t": "hello", "v": Protocol.VERSION, "room": _server.room_code, "token": "", "name": ""}))
			break
		await process_frame
	return ws


func _requests_count() -> void:
	print("phones that wait for the host count toward the limits of connections without hello (FD-30.8)")
	_new_server()
	_server.approve_new = true
	_server.max_pending_per_ip = 100
	var reqs: Array[WebSocketPeer] = []
	for i in TvServer.MAX_WAITING:
		reqs.append(await _request("10.0.0.%d" % (i + 1)))
	await _frames(10)
	_check(_server._waiting.size() == TvServer.MAX_WAITING and _server._pending.is_empty(), "4 requests wait, none is pending")
	var socks: Array[WebSocketPeer] = []
	for i in TvServer.MAX_PENDING:
		socks.append(_connect())
		await _frames(2)
	await _frames(20)
	_check(_server._pending.size() == TvServer.MAX_PENDING - TvServer.MAX_WAITING,
			"with 4 requests the TV holds only %d more connections (16 together): %d" % [
					TvServer.MAX_PENDING - TvServer.MAX_WAITING, _server._pending.size()])
	for s in socks + reqs:
		if s.get_ready_state() == WebSocketPeer.STATE_OPEN:
			s.close()
	await _frames(10)
	await _stop_server()
	_new_server()
	_server.approve_new = true
	var one := await _request("127.0.0.1")
	await _frames(10)
	_check(_server._waiting_of("127.0.0.1") == 1, "one address has a request")
	var more: Array[WebSocketPeer] = []
	for i in 5:
		more.append(_connect())
		await _frames(2)
	await _frames(20)
	_check(_server._pending_of("127.0.0.1") == _server.max_pending_per_ip - 1,
			"the request is one of the 4 of its address: %d more connections are held" % _server._pending_of("127.0.0.1"))
	for m in more + [one]:
		if m.get_ready_state() == WebSocketPeer.STATE_OPEN:
			m.close()
	await _frames(10)
	await _stop_server()


func _accept_rate() -> void:
	print("connections from one address")
	_new_server()
	_server.max_accepts_per_ip = 3
	var welcomed := 0
	for i in 5:
		var ws := await _open()
		if _has(await _pump(ws, 300), "welcome"):
			welcomed += 1
		ws.close()
	_check(welcomed == 3, "the 4th and 5th connection of one address in the window are refused (welcomed: %d)" % welcomed)
	_check(_server._accept_allowed("10.0.0.7", 0), "another address is not affected")
	_server.max_accepts_per_ip = 1
	_check(not _server._accept_allowed("10.0.0.7", 100)
			and _server._accept_allowed("10.0.0.7", 100 + TvServer.ACCEPT_WINDOW_MS + 1),
			"an address may connect again after the window")
	await _stop_server()


## Addresses of one /64 and a mapped address share the tables of the TV (security review of PR #397).
func _address_keys() -> void:
	print("one key for the addresses of one device")
	_new_server()
	_server.max_accepts_per_ip = 2
	_check(_server._accept_allowed("2001:db8:1:2::1", 0) and _server._accept_allowed("2001:DB8:1:2:aaaa::7", 1)
			and not _server._accept_allowed("2001:db8:1:2:5::5", 2), "the accept window counts one /64 as one address")
	_check(_server._accept_allowed("2001:db8:1:3::1", 3), "another /64 has its own window")
	_check(_server._accept_allowed("::ffff:10.0.0.9", 0) and _server._accept_allowed("10.0.0.9", 1)
			and not _server._accept_allowed("::ffff:10.0.0.9", 2), "a mapped address and its IPv4 address share the window")
	_server._pending.append({"ws": null, "since": 0, "host": "2001:db8:1:2::1"})
	_server._pending.append({"ws": null, "since": 0, "host": "2001:db8:1:2::2"})
	_server._pending.append({"ws": null, "since": 0, "host": "::ffff:10.0.0.9"})
	_check(_server._pending_of("2001:db8:1:2:ffff::1") == 2 and _server._pending_of("10.0.0.9") == 1
			and _server._pending_of("2001:db8:1:9::1") == 0, "the pending count of a /64 and of a mapped address")
	_server._pending.clear()
	_server.max_accepts_per_ip = 1000
	_server.max_pending_per_ip = 100   # Here every socket is tagged with its own address: only the waiting list is under test.
	_server.approve_new = true
	var held: Array[WebSocketPeer] = []   # A socket that is freed closes: the request would end.
	for i in TvServer.MAX_WAITING:
		held.append(await _request("2001:db8:%d::1" % (i + 1)))
		await _frames(5)
	_check(_server._waiting.size() == TvServer.MAX_WAITING, "4 requests from 4 different /64 fill the waiting list")
	var same := await _request("2001:db8:1:0:ffff::5")
	await _frames(15)
	_check(_server._waiting.size() == TvServer.MAX_WAITING, "a new address of an old /64 replaces its request, it is not a fifth")
	var fifth := await _request("2001:db8:99::1")
	var got := await _pump(fifth, 400)
	_check(_has(got, "kicked") and not _has(got, "pending"), "a fifth /64 gets busy")
	same.close()
	for h in held:
		h.close()
	await _stop_server()


func _address_key() -> void:
	print("the key of an address")
	_check(TvServer.address_key("1.2.3.4") == "1.2.3.4" and TvServer.address_key("::ffff:1.2.3.4") == "1.2.3.4"
			and TvServer.address_key("::FFFF:1.2.3.4") == "1.2.3.4" and TvServer.address_key("0:0:0:0:0:ffff:102:304") == "1.2.3.4",
			"an IPv4-mapped IPv6 address is the IPv4 address")
	_check(TvServer.address_key("2001:db8:1:2::1") == TvServer.address_key("2001:DB8:1:2:ffff:ffff:ffff:ffff")
			and TvServer.address_key("2001:db8:1:2::1") == "2001:0db8:0001:0002",
			"an IPv6 address is its /64 prefix, in lower case")
	_check(TvServer.address_key("2001:db8:1:2::1") != TvServer.address_key("2001:db8:1:3::1"),
			"two different /64 are different keys")
	_check(TvServer.address_key("2001:db8::1") == "2001:0db8:0000:0000", "'::' expands to zero groups")
	_check(TvServer.address_key("::1") == "0000:0000:0000:0000" and TvServer.address_key("fe80::1%eth0") == "fe80:0000:0000:0000",
			"::1 and a zone id")
	for odd in ["", "garbage", "1:2:3", "2001:db8::1::2", "zzzz::1", "1:2:3:4:5:6:7:8:9", "::ffff:1.2.3", "::ffff:1.2.3.999"]:
		_check(TvServer.address_key(odd) == odd, "anything that is not an address stays as it is: '%s'" % odd)


func _shown_id() -> int:
	return int(_server.shown_request().get("id", -1))


## The old request was already on the card: the newer `hello` is a new request (new id, shows again after the gap).
func _replace_shown() -> void:
	print("a request that was shown and is replaced")
	_new_server()
	_server.approve_new = true
	_server.approval_gap_ms = 50
	var a := await _request("10.0.0.5")
	for i in 200:
		if _shown_id() > 0:
			break
		await _frames(1)
	var old_id := _shown_id()
	var b := await _request("10.0.0.5")
	await _frames(5)
	_check(_server._waiting.size() == 1 and int(_server._waiting[0].id) != old_id,
			"the shown request that is replaced is a new request (a new id)")
	for i in 200:
		if _shown_id() > 0:
			break
		await _frames(1)
	var new_id := _shown_id()
	_check(old_id > 0 and new_id > 0 and new_id != old_id, "it shows again with a new id (%d -> %d)" % [old_id, new_id])
	_server.allow_request(old_id)
	var got := await _pump(b, 200)
	_check(not _has(got, "welcome") and _server.request_count() == 1, "a late allow of the old id does nothing")
	_server.allow_request(new_id)
	_check(_has(await _pump(b, 400), "welcome"), "the allow of the new id gives the slot to the new socket")
	a.close()
	await _stop_server()


## Refusals from two addresses of one /64, or from a mapped address and its IPv4 address, add up to one block.
func _refusal_keys() -> void:
	print("the refusal block uses one key for a /64 and for a mapped address")
	for pair in [["2001:db8:5:5::1", "2001:db8:5:5:9::2"], ["::ffff:10.9.9.9", "10.9.9.9"]]:
		_new_server()
		_server.approve_new = true
		_server.approval_gap_ms = 50
		_server.max_pending_per_ip = 100
		var held: Array[WebSocketPeer] = []
		for i in 3:
			held.append(await _request(pair[i % 2]))
			for k in 200:
				if _shown_id() > 0:
					break
				await _frames(1)
			_server.refuse_request(_shown_id())
			await _frames(5)
		var late := await _request(pair[1])
		var got := await _pump(late, 400)
		_check(_has(got, "kicked") and not _has(got, "pending"), "3 refusals from %s and %s block the address" % pair)
		await _stop_server()


func _big_frames() -> void:
	print("a text frame above the limit")
	_new_server()
	var big := {"name": "A".repeat(TvServer.MAX_TEXT_BYTES + 100)}
	var ws := await _open(big)
	_check(not _has(await _pump(ws), "welcome"), "a hello above the text limit is dropped, not parsed")
	ws.close()
	await _frames(10)
	var ok := await _open({"name": "Sam"})
	_check(_has(await _pump(ok), "welcome"), "a normal hello joins")
	ok.send_text('{"t":"ping","id":1,"t0":0,"pad":"%s"}' % "x".repeat(TvServer.MAX_TEXT_BYTES))
	_check(not _has(await _pump(ok, 300), "pong"), "a ping above the limit gets no pong")
	ok.send_text('{"t":"ping","id":2,"t0":0}')
	_check(_has(await _pump(ok, 300), "pong"), "a normal ping after it is answered")
	ok.close()
	await _stop_server()


func _empty_room() -> void:
	print("a hello with no room")
	_new_server()
	_server.allow_empty_room = false
	var ws := await _open({"room": ""})
	var frames := await _pump(ws)
	_check(frames.any(func(f: Dictionary) -> bool: return f.get("reason", "") == "bad_room"), "a release build answers bad_room")
	ws.close()
	_server.allow_empty_room = true
	var dev := await _open({"room": ""})
	_check(_has(await _pump(dev), "welcome"), "a debug build accepts it (a desktop run with --join)")
	dev.close()
	await _stop_server()
