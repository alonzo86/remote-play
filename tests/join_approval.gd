extends SceneTree
## Join approval, the TV server and the phone client (FD-30, issue #393, docs/JOIN_APPROVAL_PLAN.md phase 1): a new phone waits in
## a list of its own until the host allows it; the checks of a `hello`; the timers; the limits; the refusal counter and its
## bound; the known tokens; an old phone (a frozen copy of the controller of VERSION 5) and a new phone against this TV. Real
## sockets on the local machine. The addresses of the requests are set by the test (`_fake`): one machine has one address.
## Run by tests/run_all.sh: godot --headless --path . --script tests/join_approval.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const OldClient = preload("res://tests/fixtures/controller_client_v5.gd")
const RefusalTable = preload("res://scripts/net/refusal_table.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

const PID_A := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const PID_B := "00112233445566778899aabbccddeeff"

# Not the game port, and not the port of another suite that runs at the same time.
var PORT := 48000 + OS.get_process_id() % 900

var _checks := 0
var _fails := 0
var _server: TvServer
var _fakes: Array[Fake] = []
var _clients: Array[Node] = []
var _changes := 0   # requests_changed signals of the current server


## A raw phone: one socket and the frames that it got, with the time of each.
class Fake extends RefCounted:
	var ws := WebSocketPeer.new()
	var frames: Array = []
	var times: Array = []

	func poll() -> void:
		ws.poll()
		while ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
			frames.append(Protocol.parse_json(ws.get_packet().get_string_from_utf8()))
			times.append(Time.get_ticks_msec())

	func has(t: String) -> bool:
		return frames.any(func(f: Dictionary) -> bool: return f.get("t", "") == t)

	func first(t: String) -> Dictionary:
		for f in frames:
			if f.get("t", "") == t:
				return f
		return {}

	## The `reason` of the last `kicked` or `reject` frame, or "".
	func reason() -> String:
		for i in range(frames.size() - 1, -1, -1):
			if frames[i].get("t", "") in ["kicked", "reject"]:
				return str(frames[i].get("reason", ""))
		return ""

	## The time (ms) of the first frame of type `t`, or -1.
	func time_of(t: String) -> int:
		for i in frames.size():
			if frames[i].get("t", "") == t:
				return int(times[i])
		return -1

	func is_closed() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_CLOSED


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


func _run() -> void:
	_versions()
	_refusal_table()
	await _default_off()
	await _check_order()
	await _flow()
	await _phases()
	await _timeouts()
	await _gap()
	await _replace_same_address()
	await _cancel()
	await _setting_off()
	await _allow_rechecks()
	await _stop()
	await _flood()
	await _busy()
	await _refusal_counter()
	await _refusal_allow_and_addresses()
	await _refusal_bound()
	await _known_tokens()
	await _old_phone()
	await _new_phone()


# ---- helpers ----

## Polls every raw phone while the frames go by.
func _spin(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		for f in _fakes:
			f.poll()
		await process_frame


func _until(cond: Callable, ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		for f in _fakes:
			f.poll()
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _new_server(on := true) -> void:
	_server = TvServer.new()
	_server.address_lookup = func() -> String: return "192.168.0.1"
	_server.port = PORT
	_server.max_accepts_per_ip = 100000
	_server.max_pending_per_ip = 100
	_server.approve_new = on
	_server.approval_gap_ms = 50
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_changes = 0
	_server.requests_changed.connect(func() -> void: _changes += 1)


func _stop_server() -> void:
	for f in _fakes:
		f.ws.close()
	_fakes.clear()
	for c in _clients:
		if is_instance_valid(c):
			c.free()
	_clients.clear()
	_server.stop()
	_server.free()
	for i in 8:
		await process_frame


func _hello(fields := {}) -> String:
	var msg := {"t": "hello", "v": Protocol.VERSION, "room": _server.room_code, "token": "", "name": ""}
	msg.merge(fields, true)
	return Protocol.to_json(msg)


## Opens a socket, gives it the address `host` on the TV side, and sends `hello` (unless `send` is false). One machine has one
## address, so the test sets the address of the pending entry before the hello goes out; the TV reads it as any other.
func _fake(host := "127.0.0.1", fields := {}, send := true) -> Fake:
	var f := Fake.new()
	_fakes.append(f)
	f.ws.connect_to_url("ws://127.0.0.1:%d" % PORT)
	var tagged := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		f.poll()
		if not tagged:
			for e in _server._pending:
				if not e.has("test"):
					e["test"] = true
					e.host = host
					tagged = true
					break
		if tagged and f.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if send:
				f.ws.send_text(_hello(fields))
			break
		await process_frame
	return f


func _shown() -> bool:
	return not _server.shown_request().is_empty()


## A phone that joins through the card: the request, the allow, the `welcome`.
func _join(host := "127.0.0.1", fields := {}) -> Fake:
	var f := await _fake(host, fields)
	await _until(_shown)
	_server.allow_request(int(_server.shown_request().get("id", -1)))
	await _until(func() -> bool: return f.has("welcome"))
	return f


## A phone that joins with no card (the approval is switched off for this one `hello`).
func _join_direct(fields := {}) -> Fake:
	_server.approve_new = false
	var f := await _fake("127.0.0.1", fields)
	await _until(func() -> bool: return f.has("welcome"))
	_server.approve_new = true
	return f


## A request that the host refuses.
func _refuse_once(host: String) -> Fake:
	var f := await _fake(host)
	await _until(_shown)
	_server.refuse_request(int(_server.shown_request().get("id", -1)))
	await _until(func() -> bool: return f.has("kicked"))
	return f


## True when a new `hello` of `host` gets `pending` (it is not blocked). The request is withdrawn with `bye` afterwards.
func _gets_card(host: String) -> bool:
	var f := await _fake(host)
	await _until(func() -> bool: return f.has("pending") or f.has("kicked") or f.has("reject"))
	var ok := f.has("pending") and not f.has("kicked")
	f.ws.send_text('{"t":"bye"}')
	await _until(func() -> bool: return _server.request_count() == 0 or not ok)
	return ok


## True when a new `hello` of `host` gets `kicked` / `refused` at once, with no `pending` and no change of the list.
func _is_blocked(host: String) -> bool:
	var before := _changes
	var f := await _fake(host)
	await _until(func() -> bool: return f.has("kicked") or f.has("pending"))
	await _spin(100)
	return f.reason() == "refused" and not f.has("pending") and _changes == before and _server.request_count() == 0


func _client(cls: GDScript) -> Node:
	var c: Node = cls.new()
	root.add_child(c)
	_clients.append(c)
	return c


# ---- the checks ----

func _versions() -> void:
	print("the protocol")
	_check(Protocol.VERSION == 5, "VERSION stays 5 (pending is optional for both sides)")
	_check(Protocol.MESSAGES.get("pending", "") == "tv", "pending is a message of the TV")
	_check(Protocol.PENDING_KEEPALIVE_MS * 2 < Protocol.HELLO_TIMEOUT_MS,
			"the keepalive (%d ms) is under half of the 5 s hello clock of an old phone" % Protocol.PENDING_KEEPALIVE_MS)


func _refusal_table() -> void:
	print("the refusal table")
	var t := RefusalTable.new()
	t.count_refusal("a", 0, 3, 1000, 8)
	t.count_refusal("a", 10, 3, 1000, 8)
	_check(not t.is_blocked("a", 20), "2 refusals do not block")
	t.count_refusal("a", 20, 3, 1000, 8)
	_check(t.is_blocked("a", 500) and t.is_blocked("a", 1019) and not t.is_blocked("a", 1020),
			"the 3rd refusal blocks for the block time, and the block ends")
	_check(t.size() == 0, "an ended block with count 0 leaves no entry")
	t.count_refusal("a", 2000, 3, 1000, 8)
	t.clear("a", 2001)
	t.count_refusal("a", 2002, 3, 1000, 8)
	t.count_refusal("a", 2003, 3, 1000, 8)
	_check(not t.is_blocked("a", 2004), "an allow sets the count to 0")
	# The bound: everyone blocked, the block that ends first goes.
	var b := RefusalTable.new()
	b.count_refusal("A", 0, 1, 1000, 2)
	b.count_refusal("B", 10, 1, 500, 2)
	b.count_refusal("C", 20, 1, 800, 2)
	_check(b.size() == 2 and b.is_blocked("A", 30) and b.is_blocked("C", 30) and not b.is_blocked("B", 30),
			"a full table of blocks forgets the block that ends first, not a younger one")
	b.clear("A", 40)
	_check(b.is_blocked("A", 41), "an allow does not lift a live block")
	var c := RefusalTable.new()
	for i in 20:
		c.count_refusal("h%d" % i, i, 3, 1000, 4)
	_check(c.size() <= 4, "the table never holds more than its bound (%d)" % c.size())


func _default_off() -> void:
	print("approve_new is off in the code: the join of today")
	var plain := TvServer.new()
	_check(not plain.approve_new, "a new TvServer has approve_new false")
	plain.free()
	_new_server(false)
	var f := await _fake("127.0.0.1", {"name": "Sam"})
	await _until(func() -> bool: return not f.frames.is_empty())
	_check(f.frames[0].get("t", "") == "welcome", "the first frame after hello is welcome")
	await _spin(2300)
	_check(not f.has("pending") and _changes == 0 and _server.request_count() == 0 and _server.player_count() == 1,
			"no pending, no request, no signal; the phone has its slot")
	_check(_server.shown_request().is_empty(), "no request is shown")
	await _stop_server()


func _check_order() -> void:
	print("the checks of a hello come before the queue")
	_new_server()
	var bad_room := await _fake("127.0.0.1", {"room": "ZZZZ"})
	await _until(func() -> bool: return bad_room.has("reject"))
	_check(bad_room.reason() == "bad_room" and _server.request_count() == 0, "a wrong room code: reject bad_room, no request")
	var wrong_v := await _fake("127.0.0.1", {"v": 4})
	await _until(func() -> bool: return wrong_v.has("reject"))
	_check(wrong_v.reason() == "version" and _server.request_count() == 0, "a wrong version: reject version, no request")
	var tok := "ab".repeat(16)
	_server._replaced_tokens[tok] = Time.get_ticks_msec() + 60000
	var replaced := await _fake("127.0.0.1", {"token": tok})
	await _until(func() -> bool: return replaced.has("kicked"))
	_check(replaced.reason() == "replaced" and _server.request_count() == 0, "a replaced token: kicked replaced, no request")
	var holder := await _join("127.0.0.1", {"pid": PID_A, "name": "Ann", "av": 2})
	var dup := await _fake("10.0.0.2", {"pid": PID_A, "name": "Ann", "av": 2})
	await _until(func() -> bool: return dup.has("kicked"))
	_check(dup.reason() == "replaced" and _server.request_count() == 0 and not dup.has("pending"),
			"a profile that a connected phone holds: kicked replaced before any approval, no request")
	for i in 3:
		await _join("127.0.0.1", {"name": "G%d" % i})
	_check(_server.player_count() == 4, "4 phones joined through the card")
	var full := await _fake("10.0.0.3", {"name": "Late"})
	await _until(func() -> bool: return full.has("reject"))
	_check(full.reason() == "full" and _server.request_count() == 0 and not full.has("pending"),
			"a full TV: reject full, no card for a phone that cannot get a slot")
	_check(holder.has("welcome"), "the holder was not touched")
	await _stop_server()


func _flow() -> void:
	print("a new phone waits for the host")
	_new_server()
	var f := await _fake("127.0.0.1", {"pid": PID_A, "name": "Sam", "av": 3})
	await _until(func() -> bool: return f.has("pending"))
	_check(f.frames[0] == {"t": "pending"}, "the first frame is pending, and it has no field (no time on the wire)")
	_check(_server.request_count() == 1 and _server.player_count() == 0 and _server.players_in().is_empty(),
			"1 request, 0 slots used, nobody in the room")
	_check(not f.has("welcome") and not f.has("phase"), "the phone gets no game message")
	await _until(_shown)
	var sh := _server.shown_request()
	var keys := sh.keys()
	keys.sort()
	_check(keys == ["av", "guest", "id", "name", "others", "slot_hint"], "the shown request has no time key: %s" % str(keys))
	_check(sh.name == "Sam" and sh.av == 3 and sh.slot_hint == 0 and sh.others == 0 and sh.guest == false,
			"name, avatar, first free slot, no others, not a guest")
	_server.allow_request(int(sh.id) + 99)
	await _spin(200)
	_check(_server.request_count() == 1 and not f.has("welcome"), "an allow for another id does nothing")
	_server.allow_request(int(sh.id))
	await _until(func() -> bool: return f.has("welcome"))
	var w := f.first("welcome")
	_check(_server.request_count() == 0 and _server.player_count() == 1 and int(w.slot) == 0, "allow: welcome, slot 0, no request")
	_check(str(w.token).length() == 32, "the welcome has a new token")
	_check(w.pid == PID_A and w.pname == "Sam", "the welcome carries the profile of the hello")
	_server.allow_request(int(sh.id))
	_check(_server.player_count() == 1, "a second allow for the same id does nothing")
	# Refuse, and a guest with a name that is cleaned.
	var g := await _fake("10.0.0.2", {"name": "Bo!"})
	await _until(_shown)
	var gs := _server.shown_request()
	_check(gs.name == "Bo" and gs.av == -1 and gs.slot_hint == 1 and gs.guest == true,
			"a guest: the cleaned name, no avatar, slot hint 1, marked as a guest")
	_server.refuse_request(int(gs.id))
	await _until(func() -> bool: return g.has("kicked"))
	_check(g.reason() == "refused" and _server.player_count() == 1 and _server.request_count() == 0,
			"refuse: kicked refused, no slot")
	await _until(func() -> bool: return g.is_closed(), 2500)
	_check(g.is_closed(), "the TV closes the socket after kicked")
	_server.refuse_request(int(gs.id))
	_check(_server.player_count() == 1, "a refuse for an id that is gone does nothing")
	var anon := await _fake("10.0.0.3", {"name": ""})
	await _until(_shown)
	_check(_server.shown_request().name == "", "a phone with no name: the name is empty (the screen shows Player N)")
	await _stop_server()


func _phases() -> void:
	print("the card shows only in a menu phase")
	_new_server()
	_server.set_phase("playing")
	var f := await _fake("127.0.0.1", {"name": "Sam"})
	await _until(func() -> bool: return f.has("pending"))
	await _spin(300)
	_check(_server.request_count() == 1 and _server.shown_request().is_empty(), "in a round the request waits, not shown")
	_server.allow_request(1)
	await _spin(100)
	_check(_server.request_count() == 1 and not f.has("welcome"), "no allow is possible in a round")
	_server.set_phase("menu")
	_check(await _until(_shown), "the menu phase shows the head")
	var before := _changes
	_server.set_phase("playing", [0])
	_check(_server.shown_request().is_empty() and _changes > before and _server.request_count() == 1,
			"the phase goes to a round: the shown request goes back to not shown, and the list is told")
	_server.set_phase("menu")
	await _until(_shown)
	_server.set_phase("paused")
	_check(_server.shown_request().is_empty() and _server.request_count() == 1, "paused hides it too")
	_server.set_phase("connect")
	_check(await _until(_shown), "the connect phase shows it again")
	await _stop_server()


func _timeouts() -> void:
	print("the timers: 60 s shown, 180 s in total")
	_new_server()
	_server.approval_timeout_ms = 500
	var f := await _fake("127.0.0.1")
	await _until(_shown)
	var t_shown := Time.get_ticks_msec()
	await _until(func() -> bool: return f.has("kicked"), 4000)
	var dt := f.time_of("kicked") - t_shown
	_check(f.reason() == "timeout" and dt >= 400 and dt < 2500 and _server.request_count() == 0 and _server.player_count() == 0,
			"a shown request with no answer ends as kicked timeout after the shown time (%d ms)" % dt)
	# Never shown: the total time.
	_server.approval_timeout_ms = 60000
	_server.approval_total_ms = 600
	_server.set_phase("playing")
	var g := await _fake("127.0.0.1")
	await _until(func() -> bool: return g.has("kicked"), 4000)
	_check(g.reason() == "timeout" and _server.shown_request().is_empty(), "a request that was never shown ends by the total time")
	# A request that goes back to not shown gets a new shown time.
	_server.approval_total_ms = 60000
	_server.approval_timeout_ms = 700
	_server.set_phase("menu")
	var h := await _fake("127.0.0.1")
	await _until(_shown)
	_server.set_phase("playing", [0])
	await _spin(500)
	_server.set_phase("menu")
	await _until(_shown)
	var t2 := Time.get_ticks_msec()
	await _until(func() -> bool: return h.has("kicked"), 4000)
	var dt2 := h.time_of("kicked") - t2
	_check(h.reason() == "timeout" and dt2 >= 600,
		"after a round the request has a new shown time (%d ms, not the rest of the old one)" % dt2)
	await _stop_server()


func _gap() -> void:
	print("one second between two cards")
	_new_server()
	_server.approval_gap_ms = 700
	var a := await _fake("10.0.0.1", {"name": "One"})
	await _until(_shown)
	var b := await _fake("10.0.0.2", {"name": "Two"})
	await _until(func() -> bool: return b.has("pending"))
	var first_id := int(_server.shown_request().id)
	_check(_server.shown_request().others == 1, "the card says that 1 other waits")
	var t0 := Time.get_ticks_msec()
	_server.refuse_request(first_id)
	_check(_server.shown_request().is_empty(), "after the answer the next card is not shown at once")
	await _spin(300)
	_check(_server.shown_request().is_empty(), "and not 300 ms later")
	await _until(_shown, 3000)
	var gap := Time.get_ticks_msec() - t0
	_check(_shown() and _server.shown_request().name == "Two" and gap >= 650 and gap < 1800,
		"the next card shows after the gap (%d ms)" % gap)
	_check(a.reason() == "refused", "the first phone got kicked refused")
	await _stop_server()


func _replace_same_address() -> void:
	print("one request for each address")
	_new_server()
	_server.set_phase("playing")   # No card shows yet: the old request is not shown when it is replaced.
	var a := await _fake("10.0.0.5", {"name": "One"})
	await _until(func() -> bool: return a.has("pending"))
	var other := await _fake("10.0.0.6", {"name": "Other"})
	await _until(func() -> bool: return other.has("pending"))
	var id: int = _server._waiting[0].id
	var arrived: int = _server._waiting[0].arrived_ms
	var b := await _fake("10.0.0.5", {"name": "Two"})
	await _until(func() -> bool: return b.has("pending"))
	_check(_server.request_count() == 2, "a second hello of the same address does not add a request")
	_check(_server._waiting[0].id == id and _server._waiting[0].arrived_ms == arrived and _server._waiting[0].host == "10.0.0.5",
			"the new hello of a request that was not shown keeps the place, the id and the arrival time of the old one")
	await _until(func() -> bool: return a.is_closed(), 2500)
	_check(a.is_closed() and not a.has("kicked") and not a.has("welcome"), "the old socket is closed with no message")
	_server.set_phase("menu")
	await _until(_shown)
	_check(_server.shown_request().name == "Two", "the card shows the newer hello")
	_server.allow_request(id)
	await _until(func() -> bool: return b.has("welcome"))
	_check(b.has("welcome") and not a.has("welcome"), "the allow gives the slot to the new socket")
	await _stop_server()


func _cancel() -> void:
	print("a phone that cancels or is gone")
	_new_server()
	var a := await _fake("10.0.0.1")
	await _until(func() -> bool: return a.has("pending"))
	a.ws.send_text('{"t":"bye"}')
	await _until(func() -> bool: return _server.request_count() == 0)
	_check(_server.request_count() == 0 and not a.has("kicked"), "bye removes the request, no message")
	var b := await _fake("10.0.0.2")
	await _until(func() -> bool: return b.has("pending"))
	b.ws.close()
	_check(await _until(func() -> bool: return _server.request_count() == 0), "a closed socket removes the request")
	var c := await _fake("10.0.0.3")
	await _until(func() -> bool: return c.has("pending"))
	c.ws.send_text('{"t":"ping","id":1,"t0":0}')
	c.ws.send(PackedByteArray([1, 2, 3]), WebSocketPeer.WRITE_MODE_BINARY)
	await _spin(300)
	_check(_server.request_count() == 1 and not c.has("pong"), "other frames of a waiting phone are dropped and change nothing")
	await _stop_server()


func _setting_off() -> void:
	print("the setting goes off")
	_new_server()
	var a := await _fake("10.0.0.1")
	var b := await _fake("10.0.0.2")
	await _until(func() -> bool: return b.has("pending") and a.has("pending"))
	_server.set_approve_new(true)
	await _spin(200)
	_check(_server.request_count() == 2, "turning it on again changes nothing")
	_server.set_approve_new(false)
	await _until(func() -> bool: return a.has("kicked") and b.has("kicked"))
	_check(a.reason() == "refused" and b.reason() == "refused" and _server.request_count() == 0 and _server.player_count() == 0,
			"off: every waiting phone gets kicked refused, nobody gets in")
	_check(_server._refusals.size() == 0, "the off refusal does not count")
	var c := await _fake("10.0.0.1")
	await _until(func() -> bool: return c.has("welcome"))
	_check(c.has("welcome") and not c.has("pending"), "with the setting off a phone joins at once (the join of today)")
	_server.set_approve_new(true)
	_check(await _gets_card("10.0.0.1"), "and the address is not blocked when it is on again")
	await _stop_server()


func _allow_rechecks() -> void:
	print("the allow checks the room again")
	_new_server()
	for i in 3:
		await _join("127.0.0.1", {"name": "G%d" % i})
	var r := await _fake("10.0.0.2", {"name": "R"})
	await _until(_shown)
	await _join_direct({"name": "Fourth"})
	_check(_server.player_count() == 4, "the room became full while the request waited")
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return r.has("reject"))
	_check(r.reason() == "full" and _server.player_count() == 4 and _server.request_count() == 0, "allow on a full TV: reject full")
	await _stop_server()
	_new_server()
	var q := await _fake("10.0.0.3", {"pid": PID_A, "name": "Ann", "av": 1})
	await _until(_shown)
	var holder := await _join_direct({"pid": PID_A, "name": "Ann", "av": 1})
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return q.has("kicked"))
	_check(q.reason() == "replaced" and holder.has("welcome") and not holder.has("kicked") and _server.player_count() == 1,
			"a holder of the profile came back while the request waited: kicked replaced, the holder is not touched")
	await _stop_server()
	# A lost holder is replaced at the allow only, also on a full TV.
	_new_server()
	_server.slot_grace_ms = 60000
	var lost := await _join("127.0.0.1", {"pid": PID_B, "name": "Bea", "av": 4})
	var lost_token := str(lost.first("welcome").token)
	for i in 3:
		await _join("127.0.0.1", {"name": "G%d" % i})
	lost.ws.close()
	await _until(func() -> bool: return _server.players[0].state == PlayerInput.State.LOST)
	var takeover := await _fake("10.0.0.4", {"pid": PID_B, "name": "Bea", "av": 4})
	await _until(func() -> bool: return takeover.has("pending") or takeover.has("reject"))
	await _until(_shown)
	_check(takeover.has("pending") and not takeover.has("reject"),
		"a lost holder on a full TV: the request is queued, not rejected full")
	_check(_server.players[0].is_present() and _server._replaced_tokens.is_empty(),
			"the slot of the lost holder is not touched while the request waits")
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return takeover.has("welcome"))
	_check(takeover.has("welcome") and int(takeover.first("welcome").slot) == 0 and _server._replaced_tokens.has(lost_token),
			"at the allow the lost holder is replaced (its token is remembered) and the phone gets the slot")
	await _stop_server()


func _stop() -> void:
	print("the TV app stops")
	_new_server()
	await _join("127.0.0.1", {"name": "In"})
	var w := await _fake("10.0.0.2")
	await _until(func() -> bool: return w.has("pending"))
	_check(_server._known_tokens.size() == 1, "the TV knows the token of the phone that joined")
	_server.stop()
	await _until(func() -> bool: return w.has("bye"))
	_check(w.has("bye") and not w.has("kicked") and _server.request_count() == 0, "a waiting phone gets bye, the list is empty")
	_check(_server._known_tokens.is_empty(), "the known tokens are forgotten")
	await _stop_server()


func _flood() -> void:
	print("a waiting socket that floods frames")
	_new_server()
	var f := await _fake("10.0.0.1")
	await _until(func() -> bool: return f.has("pending"))
	_server.set_process(false)
	for i in 20:
		f.ws.send_text('{"t":"ping","id":%d,"t0":0}' % i)
	f.ws.send_text('{"t":"bye"}')
	await _spin(400)
	_server._poll_waiting(Time.get_ticks_msec())
	_check(_server.request_count() == 1,
		"one frame of the TV reads at most %d frames of a waiting socket" % TvServer.MAX_WAITING_FRAMES)
	_server._poll_waiting(Time.get_ticks_msec())
	_server._poll_waiting(Time.get_ticks_msec())
	_check(_server.request_count() == 0, "the rest is read in the next frames: the bye at the end of the flood is seen")
	_server.set_process(true)
	await _stop_server()


func _busy() -> void:
	print("4 requests wait: the fifth gets busy")
	_new_server()
	var waiting: Array[Fake] = []
	for i in 4:
		waiting.append(await _fake("10.0.1.%d" % (i + 1), {"name": "P%d" % i}))
	await _until(func() -> bool: return _server.request_count() == TvServer.MAX_WAITING)
	await _spin(100)
	var before := _changes
	var fifth := await _fake("10.0.1.9")
	await _until(func() -> bool: return fifth.has("kicked") or fifth.has("pending"))
	await _spin(200)
	_check(fifth.reason() == "busy" and not fifth.has("pending") and _changes == before and _server.request_count() == 4,
			"the fifth request gets kicked busy, no pending, no change of the list")
	var same := await _fake("10.0.1.2", {"name": "Again"})
	await _until(func() -> bool: return same.has("pending") or same.has("kicked"))
	_check(same.has("pending") and not same.has("kicked") and _server.request_count() == 4,
			"a hello of an address that already waits replaces its request, it does not get busy")
	await _until(_shown)
	_server.refuse_request(int(_server.shown_request().id))
	await _until(func() -> bool: return _server.request_count() == 3)
	var sixth := await _fake("10.0.1.9")
	await _until(func() -> bool: return sixth.has("pending") or sixth.has("kicked"))
	_check(sixth.has("pending") and _server.request_count() == 4, "when one request ended a new hello gets pending again")
	await _stop_server()


func _refusal_counter() -> void:
	print("the refusal counter: 3 refusals in a row block the address")
	_new_server()
	_server.refuse_block_ms = 1500
	var h := "10.0.2.1"
	await _refuse_once(h)
	_check(await _gets_card(h), "1 refusal: the next hello gets a card")
	await _refuse_once(h)
	_check(await _gets_card(h), "2 refusals: the next hello still gets a card (no block)")
	# Things that neither count nor reset: timeout, bye, closed socket, replacement, setting off.
	_server.approval_timeout_ms = 300
	var t := await _fake(h)
	await _until(func() -> bool: return t.has("kicked"), 3000)
	_server.approval_timeout_ms = 60000
	_check(t.reason() == "timeout" and await _gets_card(h), "a timeout does not count (the next hello gets a card)")
	var c := await _fake(h)
	await _until(func() -> bool: return c.has("pending"))
	c.ws.close()
	await _until(func() -> bool: return _server.request_count() == 0)
	_check(await _gets_card(h), "a closed socket does not count")
	var r1 := await _fake(h)
	await _until(func() -> bool: return r1.has("pending"))
	var r2 := await _fake(h)
	await _until(func() -> bool: return r2.has("pending"))
	r2.ws.send_text('{"t":"bye"}')
	await _until(func() -> bool: return _server.request_count() == 0)
	_check(await _gets_card(h), "a replacement by a newer hello and its cancel do not count")
	var o := await _fake(h)
	await _until(func() -> bool: return o.has("pending"))
	_server.set_approve_new(false)
	await _until(func() -> bool: return o.has("kicked"))
	_server.set_approve_new(true)
	_check(o.reason() == "refused" and await _gets_card(h), "the setting off does not count")
	# All of that left the count at 2: the next refusal is the third.
	await _refuse_once(h)
	_check(await _is_blocked(h), "the 3rd refusal in a row blocks: kicked refused, no pending, no change of the list")
	_check(await _is_blocked(h), "and the next hello is blocked too (it does not count)")
	await _spin(1700)
	_check(await _gets_card(h), "after the block time the address gets a card again")
	await _refuse_once(h)
	await _refuse_once(h)
	_check(await _gets_card(h), "the blocked hellos did not count: after the block 2 refusals do not block")
	await _refuse_once(h)
	_check(await _is_blocked(h), "3 new refusals block again")
	await _stop_server()


func _refusal_allow_and_addresses() -> void:
	print("an allow resets the counter; each address has its own")
	_new_server()
	_server.refuse_block_ms = 5000
	var h := "10.0.2.2"
	await _refuse_once(h)
	await _refuse_once(h)
	await _join(h, {"name": "Ok"})
	await _refuse_once(h)
	await _refuse_once(h)
	_check(await _gets_card(h), "2 refusals, 1 allow, 2 refusals: no block")
	await _refuse_once(h)
	_check(await _is_blocked(h), "the count was 2 after the allow: one more refusal blocks")
	var a := "10.0.2.3"
	var b := "10.0.2.4"
	await _refuse_once(a)
	await _refuse_once(b)
	await _refuse_once(a)
	await _refuse_once(b)
	_check(await _gets_card(a) and await _gets_card(b), "2 refusals on each of two addresses: neither is blocked")
	_check(await _is_blocked(h), "the other address stays blocked")
	await _stop_server()


func _refusal_bound() -> void:
	print("the refusal table is bounded")
	_new_server()
	_server.max_refusal_entries = 2
	_server.refuse_block_ms = 20000
	await _refuse_once("10.0.3.1")   # A
	await _refuse_once("10.0.3.2")   # B
	await _refuse_once("10.0.3.3")   # C: the table is full, A (the oldest count) is forgotten
	await _refuse_once("10.0.3.1")
	await _refuse_once("10.0.3.1")
	_check(await _gets_card("10.0.3.1"), "a forgotten address starts again from 0 (a table with no bound would have blocked it)")
	await _refuse_once("10.0.3.1")
	_check(await _is_blocked("10.0.3.1"), "the address is blocked after 3 refusals in a row")
	await _refuse_once("10.0.3.2")
	await _refuse_once("10.0.3.3")
	await _refuse_once("10.0.3.4")
	_check(_server._refusals.size() <= 2, "the table holds at most 2 addresses (%d)" % _server._refusals.size())
	_check(await _is_blocked("10.0.3.1"), "a blocked address is not forgotten to make room for others")
	await _stop_server()


func _known_tokens() -> void:
	print("a phone that this TV welcomed comes back with no card")
	_new_server()
	_server.slot_grace_ms = 300
	var a := await _join("127.0.0.1", {"name": "Ann"})
	var tok := str(a.first("welcome").token)
	a.ws.close()
	await _until(func() -> bool: return _server.player_count() == 0, 4000)
	_check(_server.player_count() == 0, "the slot was freed after the grace time")
	var before := _changes
	var back := await _fake("127.0.0.1", {"token": tok, "name": "Ann"})
	await _until(func() -> bool: return back.has("welcome") or back.has("pending"))
	_check(back.has("welcome") and not back.has("pending") and str(back.first("welcome").token) == tok and _changes == before
			and _server.request_count() == 0, "menu: welcome with the same token, no pending, no signal")
	back.ws.close()
	await _until(func() -> bool: return _server.player_count() == 0, 4000)
	_server.set_phase("playing", [])
	var in_round := await _fake("127.0.0.1", {"token": tok, "name": "Ann"})
	await _until(func() -> bool: return in_round.has("welcome") or in_round.has("pending"))
	_check(in_round.has("welcome") and not in_round.has("pending") and str(in_round.first("welcome").token) == tok,
			"in a round: a returning player joins with no card too")
	_server.set_phase("menu")
	_server.drop_player(int(in_round.first("welcome").slot))
	await _spin(100)
	var dropped := await _fake("127.0.0.1", {"token": tok})
	await _until(func() -> bool: return dropped.has("welcome") or dropped.has("pending"))
	_check(dropped.has("welcome") and str(dropped.first("welcome").token) == tok,
		"after drop_player (Resume without) the token is kept")
	# A kick, a bye and a replacement revoke the token.
	var b := await _join("127.0.0.1", {"name": "Bob"})
	var tok_b := str(b.first("welcome").token)
	_server.kick(int(b.first("welcome").slot))
	await _until(func() -> bool: return b.has("kicked"))
	_check(await _gets_card_with("127.0.0.1", tok_b), "after kick the token needs a card")
	var c := await _join("127.0.0.1", {"name": "Cy"})
	var tok_c := str(c.first("welcome").token)
	c.ws.send_text('{"t":"bye"}')
	await _until(func() -> bool: return _server.player_count() == 1)
	_check(await _gets_card_with("127.0.0.1", tok_c), "after the bye of the phone the token needs a card")
	var d := await _join("127.0.0.1", {"name": "Di", "pid": PID_A})
	var tok_d := str(d.first("welcome").token)
	_server._replace_slot(int(d.first("welcome").slot), Time.get_ticks_msec())
	var gone := await _fake("127.0.0.1", {"token": tok_d})
	await _until(func() -> bool: return gone.has("kicked") or gone.has("welcome"))
	_check(gone.reason() == "replaced" and not gone.has("welcome"), "after a replacement the token gets kicked replaced")
	_server._replaced_tokens.clear()
	_check(await _gets_card_with("127.0.0.1", tok_d), "and when the replaced token is forgotten it still needs a card")
	await _stop_server()
	# The bound: 32 tokens, the oldest goes first.
	_new_server()
	var tokens: Array[String] = []
	for i in TvServer.MAX_KNOWN_TOKENS + 1:
		var p := await _join_direct({"name": "P%d" % (i % 9)})
		tokens.append(str(p.first("welcome").token))
		_server.drop_player(int(p.first("welcome").slot))
	_check(_server._known_tokens.size() == TvServer.MAX_KNOWN_TOKENS, "the TV keeps at most %d tokens" % TvServer.MAX_KNOWN_TOKENS)
	_check(await _gets_card_with("127.0.0.1", tokens[0]), "the oldest token was pushed out: it needs a card")
	var newest := await _fake("127.0.0.1", {"token": tokens[tokens.size() - 1]})
	await _until(func() -> bool: return newest.has("welcome") or newest.has("pending"))
	_check(newest.has("welcome") and not newest.has("pending"), "the newest token is known: no card")
	await _stop_server()
	# A TV that restarts knows no token.
	_new_server()
	_check(await _gets_card_with("127.0.0.1", tokens[tokens.size() - 1]),
		"a new TvServer (a restart of the TV app) knows no old token")
	await _stop_server()


## True when a `hello` with `token` gets `pending` (a card), not `welcome`. The request is withdrawn afterwards.
func _gets_card_with(host: String, token: String) -> bool:
	var f := await _fake(host, {"token": token})
	await _until(func() -> bool: return f.has("pending") or f.has("welcome") or f.has("kicked"))
	var ok := f.has("pending") and not f.has("welcome")
	f.ws.send_text('{"t":"bye"}')
	await _until(func() -> bool: return _server.request_count() == 0 or not ok)
	return ok


func _old_phone() -> void:
	print("an old phone (VERSION 5, no pending) against this TV")
	_new_server()
	# The frames that the TV sends while it waits come at least every 2.5 s: this is what keeps the 5 s clock of the old phone.
	var probe := await _fake("10.0.9.9", {"name": "Probe"})
	var old: Node = _client(OldClient)
	var reasons: Array[String] = []
	old.rejected.connect(func(r: String) -> void: reasons.append(r))
	old.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return _server.request_count() == 2)
	var accepts_start: int = _server._accepts.get("127.0.0.1", []).size()
	await _spin(6200)
	_check(_server._accepts.get("127.0.0.1", []).size() == accepts_start,
		"the old phone did not close its socket and connect again while it waited")
	_check(old.state == OldClient.State.JOINING and reasons.is_empty(),
		"after 6 s the old phone still waits in JOINING (more than its 5 s clock)")
	var pend: Array = []
	for i in probe.frames.size():
		if probe.frames[i].get("t", "") == "pending":
			pend.append(probe.times[i])
	var worst := 0
	for i in range(1, pend.size()):
		worst = maxi(worst, int(pend[i]) - int(pend[i - 1]))
	_check(pend.size() >= 3 and worst > 0 and worst < 2500,
		"the TV sends pending about every 2 s: %d frames, largest gap %d ms" % [pend.size(), worst])
	_server.allow_request(int(_server.shown_request().id))
	await _until(_shown)
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return old.state == OldClient.State.CONNECTED)
	_check(old.state == OldClient.State.CONNECTED and old.slot >= 0 and old._token != "",
		"after the allow the old phone has a slot and a token")
	await _stop_server()
	# The old phone, refused / timeout / busy: kicked, no token, no new connection.
	for kind in ["refused", "timeout", "busy"]:
		_new_server()
		if kind == "timeout":
			_server.approval_timeout_ms = 500
		if kind == "busy":
			for i in 4:
				await _fake("10.0.8.%d" % (i + 1))
			await _until(func() -> bool: return _server.request_count() == 4)
		var phone: Node = _client(OldClient)
		var got: Array[String] = []
		phone.rejected.connect(func(r: String) -> void: got.append(r))
		phone.connect_to("127.0.0.1", PORT, _server.room_code)
		if kind == "refused":
			await _until(_shown)
			_server.refuse_request(int(_server.shown_request().id))
		await _until(func() -> bool: return not got.is_empty(), 4000)
		var accepts_before: int = _server._accepts.get("127.0.0.1", []).size()
		await _spin(3000)
		_check(got == ["kicked"] and phone.state == OldClient.State.IDLE and phone._token == "",
				"old phone, %s: IDLE, rejected gave kicked, no token" % kind)
		_check(_server._accepts.get("127.0.0.1", []).size() == accepts_before, "old phone, %s: no new connection in 3 s" % kind)
		await _stop_server()
	# A blocked address.
	_new_server()
	_server.refuse_block_ms = 20000
	for i in 3:
		await _refuse_once("127.0.0.1")
	var blocked: Node = _client(OldClient)
	var got2: Array[String] = []
	blocked.rejected.connect(func(r: String) -> void: got2.append(r))
	blocked.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return not got2.is_empty(), 4000)
	_check(got2 == ["kicked"] and blocked.state == OldClient.State.IDLE and _server.request_count() == 0,
			"old phone against a blocked address: IDLE, rejected gave kicked, no request")
	await _stop_server()
	# Approval off: the old phone joins at once.
	_new_server(false)
	var plain: Node = _client(OldClient)
	plain.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return plain.state == OldClient.State.CONNECTED)
	_check(plain.state == OldClient.State.CONNECTED, "approval off: the old phone is CONNECTED with no allow")
	await _stop_server()


func _new_phone() -> void:
	print("the new phone against this TV")
	_new_server()
	var c: ControllerClient = _client(ControllerClient)
	var states: Array[int] = []
	var reasons: Array[String] = []
	c.state_changed.connect(func(s: int) -> void: states.append(s))
	c.rejected.connect(func(r: String) -> void: reasons.append(r))
	c.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return c.state == ControllerClient.State.WAITING)
	_check(c.state == ControllerClient.State.WAITING and states.has(ControllerClient.State.JOINING), "pending: the phone is WAITING")
	_check(ControllerClient.State.WAITING > ControllerClient.State.RECONNECTING,
		"WAITING is the last state: the other numbers did not move")
	await _spin(2600)
	_check(c.state == ControllerClient.State.WAITING and reasons.is_empty(), "it keeps waiting while pending frames come (2.6 s)")
	await _until(_shown)
	_server.allow_request(int(_server.shown_request().id))
	await _until(func() -> bool: return c.state == ControllerClient.State.CONNECTED)
	_check(c.state == ControllerClient.State.CONNECTED and c.slot == 0, "the allow: CONNECTED with a slot")
	c.cancel_wait()
	await _spin(100)
	_check(c.state == ControllerClient.State.CONNECTED, "cancel_wait does nothing when the phone is not waiting")
	_server.kick(c.slot)
	await _until(func() -> bool: return reasons.has("kicked"))
	_check(reasons == ["kicked"], "kicked with no reason stays kicked")
	await _stop_server()
	# The reasons go out as they are.
	for kind in ["refused", "timeout", "busy"]:
		_new_server()
		if kind == "timeout":
			_server.approval_timeout_ms = 400
		if kind == "busy":
			for i in 4:
				await _fake("10.0.7.%d" % (i + 1))
			await _until(func() -> bool: return _server.request_count() == 4)
		var p: ControllerClient = _client(ControllerClient)
		var got: Array[String] = []
		p.rejected.connect(func(r: String) -> void: got.append(r))
		p.connect_to("127.0.0.1", PORT, _server.room_code)
		if kind == "refused":
			await _until(_shown)
			_server.refuse_request(int(_server.shown_request().id))
		await _until(func() -> bool: return not got.is_empty(), 4000)
		await _spin(500)
		_check(got == [kind] and p.state == ControllerClient.State.IDLE, "rejected gives exactly %s (%s)" % [kind, str(got)])
		await _stop_server()
	# CANCEL.
	_new_server()
	var w: ControllerClient = _client(ControllerClient)
	var got3: Array[String] = []
	w.rejected.connect(func(r: String) -> void: got3.append(r))
	w.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return w.state == ControllerClient.State.WAITING)
	w.cancel_wait()
	await _until(func() -> bool: return _server.request_count() == 0)
	_check(w.state == ControllerClient.State.IDLE and got3.is_empty() and _server.request_count() == 0,
			"cancel_wait: bye to the TV, IDLE, no message")
	await _stop_server()
	# The TV stops.
	_new_server()
	var s: ControllerClient = _client(ControllerClient)
	var got4: Array[String] = []
	s.rejected.connect(func(r: String) -> void: got4.append(r))
	s.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return s.state == ControllerClient.State.WAITING)
	_server.stop()
	await _until(func() -> bool: return not got4.is_empty(), 3000)
	_check(got4 == ["tv_closed"] and s.state == ControllerClient.State.IDLE, "the TV stops: tv_closed (%s)" % str(got4))
	await _stop_server()
	# A lost link: the TV closes the socket with no message, and the TV goes silent.
	_new_server()
	var l: ControllerClient = _client(ControllerClient)
	var got5: Array[String] = []
	l.rejected.connect(func(r: String) -> void: got5.append(r))
	l.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return l.state == ControllerClient.State.WAITING)
	var accepts: int = _server._accepts.get("127.0.0.1", []).size()
	_server._waiting[0].ws.close()
	await _until(func() -> bool: return not got5.is_empty(), 3000)
	await _spin(2500)
	_check(got5 == ["wait_lost"] and l.state == ControllerClient.State.IDLE, "the TV closes the socket: wait_lost (%s)" % str(got5))
	_check(_server._accepts.get("127.0.0.1", []).size() == accepts, "and the phone does not try again (no new connection)")
	await _stop_server()
	_new_server()
	var q: ControllerClient = _client(ControllerClient)
	var got6: Array[String] = []
	q.rejected.connect(func(r: String) -> void: got6.append(r))
	q.connect_to("127.0.0.1", PORT, _server.room_code)
	await _until(func() -> bool: return q.state == ControllerClient.State.WAITING)
	var accepts6: int = _server._accepts.get("127.0.0.1", []).size()
	_server.set_process(false)   # The TV sends nothing any more, and the socket stays open.
	var t0 := Time.get_ticks_msec()
	await _until(func() -> bool: return not got6.is_empty(), 8000)
	var dt := Time.get_ticks_msec() - t0
	_check(got6 == ["wait_lost"] and dt >= 2500 and dt < 7500, "5 s with no frame: wait_lost (%s after %d ms)" % [str(got6), dt])
	await _spin(2500)
	_check(_server._accepts.get("127.0.0.1", []).size() == accepts6 and q.state == ControllerClient.State.IDLE, "and no retry")
	_server.set_process(true)
	await _stop_server()
