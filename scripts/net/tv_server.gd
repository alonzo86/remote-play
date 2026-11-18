# gdlint:ignore=max-public-methods
extends Node
## TV side. WebSocket server (TCPServer + WebSocketPeer) with 4 player slots.
## It owns all sockets. It writes into PlayerInput objects and emits signals.
## It never refers to game scripts. The join approval (FD-30, docs/JOIN_APPROVAL_PLAN.md) is part of this class, so it has more
## public methods than the linter allows (the first line).

const Protocol = preload("res://scripts/core/protocol.gd")
const ClosingSockets = preload("res://scripts/net/closing_sockets.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Profile = preload("res://scripts/core/profile.gd")
const PlayerNames = preload("res://scripts/net/player_names.gd")
const RefusalTable = preload("res://scripts/net/refusal_table.gd")

signal player_joined(slot: int)
signal player_lost(slot: int)
signal player_resumed(slot: int)
signal player_removed(slot: int)
## A phone asks to end the game that runs (`leave_ask`): the App gives it to the game, which asks "End the game?" (REQ-FL-52c).
signal leave_asked(slot: int)
## A join request was added, removed, shown or hidden (docs/JOIN_APPROVAL_PLAN.md 4.5). No data: read `shown_request()`.
signal requests_changed()

var room_code := ""                  # The code of `ip` (Protocol.room_code_for_ip). Empty while the TV has no address.
## The LAN address of this TV. The room code follows it, so a new address shows a new code (REQ-FL-4).
var ip := "":
	set(value):
		ip = value
		room_code = Protocol.room_code_for_ip(value)
## Finds the address of this device. A test sets another one (an empty text is a device with no network).
var address_lookup: Callable = Protocol.local_ipv4
## A `hello` with an empty `room` is accepted only in a debug build (a run on a desktop: `--join=127.0.0.1`, issue #388). A test
## sets it to false to check a release build.
var allow_empty_room := OS.is_debug_build()
var tv_name := "Living Room TV"
## False while a game without a pointer is running: the phones then hide the Recenter box (REQ-GM-37). It is sent in the
## `phase` and `welcome` messages as `rc` and only when it is false.
var recenter_button := true
## The buttons of the pad while a game runs: "", "a", "b" or "ab" (REQ-GM-37a). Sent as `ab` in the `phase` and `welcome`
## messages, and only when it is not "ab".
var pad_buttons := "ab"
## True while the settings view of a swing game is open: phones show the safety card and answer `swing_ok` (REQ-GM-102).
var setup_swing := false
var setup_pick := true    # False for a game that enrolls its players itself (Air Hockey): the phones are not asked IN or OUT.
## True while the settings view of a game is open (issue #76, #79): the phones get `setup` messages.
var setup_open := false
var _out := {}   # slot -> true for a phone that chose OUT of the game in the settings view (REQ-GM-104).
var _setup_sig := ""
var _swing_ok := {}   # slot -> true for a phone that tapped OK on the safety card (for the view that is open).
var phase := "connect"   # connect, menu, playing, paused. See docs/PROTOCOL.md.
var round_slots: Array[int] = []   # Slots that take part in the running round (when `round_limited`).
var round_limited := false         # True when the round has its own list. A freed slot leaves the list.
var players: Array[PlayerInput] = []
var listening := false
var port := Protocol.WS_PORT          # The TCP port. Tests that run beside a TV app use another one.
## The language of the TV, sent to every phone (REQ-FL-62): "en" or "he".
var language := "en"
## Silence that makes a phone lost, and how long a lost slot is kept. Tests make them short.
var peer_timeout_ms := Protocol.PEER_TIMEOUT_MS
var slot_grace_ms := Protocol.SLOT_GRACE_MS
var paused_slot_grace_ms := Protocol.PAUSED_SLOT_GRACE_MS

## True when a new phone waits for the host (`allow_request`, `refuse_request`) before it gets a slot (FD-30, REQ-FL-93). It is
## false here: the App sets it from the setting, so a TV server that nobody configures joins a phone in one step, as before.
## Write it only through `set_approve_new` (OFF refuses the waiting requests); the App in phase 4 must call the setter.
var approve_new := false
## Approval timers and limits (docs/JOIN_APPROVAL_PLAN.md 4.5). Tests make them short.
var approval_timeout_ms := 60000   # A request that is shown with no answer ends as `timeout` after this.
var approval_total_ms := 180000    # A request ends as `timeout` this long after it arrived, shown or not.
var approval_gap_ms := 1000        # The next request is shown this long after the last one ended.
var refuse_block_ms := 60000       # The block of an address after `refuse_block_after` host refusals in a row.
var refuse_block_after := 3
var max_refusal_entries := 64      # Addresses whose refusals the TV keeps.
var max_waiting_per_ip := 1        # A new `hello` of an address with a request replaces that request.

## Limits against a client on the Wi-Fi that opens many connections or sends big frames (issue #387). The phone sends 36-byte
## sensor packets and JSON messages of a few hundred bytes, so these are far above real use.
const MAX_PENDING := 16                 # Connections that have not sent `hello` yet. More are closed at once.
const MAX_TEXT_BYTES := 4096            # A longer text frame is dropped before it is parsed.
# Inbound and outbound buffer of a socket: a bigger frame closes that socket. About 15 s of 36-byte sensor packets, so a
# hitch of the TV does not drop a phone.
const BUFFER_BYTES := 32768
const MAX_QUEUED_PACKETS := 1024        # Frames a socket may hold between two polls (a sensor packet every 16 ms, about 17 s).
const ACCEPT_WINDOW_MS := 10000
const MAX_WAITING := 4                  # Requests that wait for the host at one time. A fifth gets `kicked` / `busy`.
const MAX_KNOWN_TOKENS := 32            # Tokens that this TV gave and did not revoke; the oldest goes first (FD-30.4).
const MAX_WAITING_FRAMES := 8           # Frames read from one waiting socket in one frame.
## Connections of one address that have not sent `hello` yet. One device cannot fill the whole `MAX_PENDING` and keep the
## phones of the family out. Four are enough for 4 phones that join at the same moment behind one address.
var max_pending_per_ip := 4
## Connections that one address may open in `ACCEPT_WINDOW_MS`. A real phone opens a few (a retry, a reconnect). A test sets it.
var max_accepts_per_ip := 30

var _address_timer := 0.0
var _accepts := {}                   # address -> [times (ms) of its recent connections]
var _tcp := TCPServer.new()
var _pending: Array = []             # [{ws, since_ms}]
var _sockets: Array[WebSocketPeer] = []
var _last_rx_ms: Array[int] = []
var _last_leave_ask_ms := {}         # slot -> when the TV took the last `leave_ask` of that phone.
var _waiting: Array = []             # [{id, ws, host, hello, arrived_ms, shown_ms, last_keepalive_ms}], the head is shown first.
var _next_request_id := 1
var _last_card_end_ms := -1000000    # When the last request that was shown ended or was hidden (for the gap of the next one).
var _known_tokens: Array[String] = []   # Tokens of phones that this TV welcomed in this run and did not revoke, oldest first.
var _refusals := RefusalTable.new()
var _closing := ClosingSockets.new()   # Rejected, replaced and stopped sockets that finish their close handshake.
var _replaced_tokens := {}           # token -> time (ms) until which the TV remembers it (a phone that was replaced, FD-22).
var _final_sent := {}                # slot -> the `final` message of the open result (REQ-FL-67a).
var _turn_sent := {}                 # slot -> the last turn message sent to that phone.
var _score_sent := {}                # slot -> the last score message sent to that phone (it is not sent again, REQ-FL-67).


func start(settings: Dictionary) -> Error:
	ip = address_lookup.call()
	# A second call starts again with 4 empty slots; it never adds slots to the ones it has (issue #310).
	players.clear()
	_sockets.clear()
	_last_rx_ms.clear()
	for i in Protocol.MAX_PLAYERS:
		players.append(PlayerInput.new(i, settings))
		_sockets.append(null)
		_last_rx_ms.append(0)
	if not player_removed.is_connected(_on_player_removed):
		player_removed.connect(_on_player_removed)
	var err := _tcp.listen(port)
	listening = (err == OK)
	if err != OK:
		push_error("TvServer: cannot listen on port %d (error %d)" % [port, err])
	return err


## A slot that is freed during a round (left, removed, grace time over, host continued without it)
## is not in the round any more. A new phone in that slot waits for the next round (REQ-FL-25).
func _on_player_removed(slot: int) -> void:
	_final_sent.erase(slot)   # A new phone in this slot never gets the row of the player that left (REQ-FL-67a).
	round_slots.erase(slot)
	if not in_round():
		PlayerNames.assign(players)


## Stops the server. Every phone gets "bye" first (issue #169). Returns true when sockets are still finishing their close
## handshake: the app waits a moment before it quits.
func stop() -> bool:
	for i in _sockets.size():
		if _sockets[i] != null:
			_send_json(i, {"t": "bye"})
			_discard(_sockets[i])   # Closed 300 ms later: a close right after the bye can drop it (issue #169).
			_sockets[i] = null
	for entry in _waiting:
		if entry.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			entry.ws.send_text(Protocol.to_json({"t": "bye"}))
		_discard(entry.ws)
	_waiting.clear()
	_known_tokens.clear()
	_refusals.reset()
	_tcp.stop()
	_replaced_tokens.clear()
	listening = false
	return not _closing.is_empty()


## The number of present players. The tests use it to wait for a join or a leave; the game code uses `players_in()`.
func player_count() -> int:
	var n := 0
	for p in players:
		if p.is_present():
			n += 1
	return n


func connected_slots() -> Array[int]:
	var r: Array[int] = []
	for p in players:
		if p.is_connected_now():
			r.append(p.slot)
	return r


## Tells the phones what the TV shows. During a round (`playing`, `paused`), a phone that is not in
## `slots` gets the phase `waiting`: it joined late and takes part in the next round (REQ-FL-25).
func set_phase(p_phase: String, slots: Array[int] = []) -> void:
	if p_phase != "paused" and not (phase == "paused" and p_phase == "playing"):
		_final_sent.clear()   # A new round or a menu ends the result line; a pause and its resume keep it (REQ-FL-67a).
	phase = p_phase
	if p_phase in ["playing", "paused"]:
		_hide_shown_request()   # No card in a round: the request waits for the next menu phase (FD-30.9).
	setup_open = false
	setup_swing = false
	setup_pick = true
	_swing_ok.clear()
	if not p_phase in ["playing", "paused"]:
		_out.clear()   # Every phone is IN again outside a round (the Games screen, a new settings view).
		recenter_button = true
		pad_buttons = "ab"
	round_slots.clear()
	round_limited = false
	if not p_phase in ["playing", "paused"]:
		PlayerNames.assign(players)   # Names are made again in the menus only, so they do not change in a round (PROFILES_PLAN 4.3).
		_turn_sent.clear()
		_score_sent.clear()   # The phones clear their score at the phase message (REQ-FL-67); a pause keeps it.
	if p_phase in ["playing", "paused"] and not slots.is_empty():
		round_slots.append_array(slots)
		round_limited = true
	for p in players:
		if p.is_connected_now():
			var msg := {"t": "phase", "v": phase_for(p.slot)}
			if not recenter_button:
				msg["rc"] = false
			if pad_buttons != "ab":
				msg["ab"] = pad_buttons
			_send_json(p.slot, msg)


## Opens the setup of the game that the settings view shows (issues #76 and #79). Every connected phone gets the `setup` message
## (`swing`, `pick`, `in`, see `sync_setup()`); the answers of `swing_ok` and the choices IN and OUT start again. Any `set_phase`
## closes the setup.
func set_setup(swing: bool, pick := true) -> void:
	setup_open = true
	setup_swing = swing
	setup_pick = pick
	_swing_ok.clear()
	_out.clear()
	_setup_sig = ""
	sync_setup()


## Sends the `setup` message to every connected phone when something in it changed since the last time: the phones that are
## connected, a choice of IN or OUT, the swing flag. `pick` is true with two or more phones (the phone shows the question
## "play this game?"); `in` is the choice of this phone. It runs every frame while the setup is open, so a phone that joins
## or returns gets it at once.
func sync_setup() -> void:
	if not setup_open:
		return
	var slots := connected_slots()
	var sig := "%s|%s|%s|%s" % [str(slots), str(_out.keys()), str(setup_swing), str(setup_pick)]
	if sig == _setup_sig:
		return
	_setup_sig = sig
	for s in slots:
		var many := slots.size() >= 2   # With one phone nobody is asked, and an OUT from before does not count.
		_send_json(s, {"t": "setup", "swing": setup_swing, "pick": setup_pick and many, "in": not many or not _out.has(s)})


## The connected phones that play the next game: all of them, except the ones that chose OUT in the settings view (REQ-GM-104).
func players_in() -> Array[int]:
	var r: Array[int] = []
	var slots := connected_slots()
	for s in slots:
		# With one phone left nobody is asked, so an OUT choice from before (the other phone left) no longer counts.
		if slots.size() < 2 or not _out.has(s):
			r.append(s)
	return r


## A phone chose IN (`true`) or OUT. With two or more phones every phone may go OUT: with nobody IN, Start is off. A single phone
## is never asked and cannot go OUT, as before.
func set_in(slot: int, value: bool) -> void:
	if value:
		_out.erase(slot)
	elif connected_slots().size() >= 2 and connected_slots().has(slot):
		_out[slot] = true


## The slots of the phones that play and have not tapped OK on the safety card yet (a phone that is OUT is not asked). Empty when
## the setup is not a swing game.
func swing_pending() -> Array[int]:
	var r: Array[int] = []
	if setup_swing:
		for s in players_in():
			if not _swing_ok.has(s):
				r.append(s)
	return r


## Sets the language of the TV and tells every connected phone (REQ-FL-62).
func set_language(code: String) -> void:
	if code == language:
		return
	language = code
	if in_menu_phase():
		PlayerNames.assign(players)   # A phone without a name is "Player N" in the new language.
	for p in players:
		if p.is_connected_now():
			_send_json(p.slot, {"t": "lang", "v": language})


## The phase that one slot sees.
func phase_for(slot: int) -> String:
	if phase in ["playing", "paused"] and round_limited and not (slot in round_slots):
		return "waiting"
	return phase


## Tells one phone its place in the round and its score text (REQ-FL-67). `rank` is 1 for the leader, `of` the number of ranked
## players, `text` the score as the leader chip shows it (it can be empty: a race has no score before the finish). The same
## message is not sent twice in a row, so a game can call this every frame.
func send_score(slot: int, rank: int, of: int, text: String) -> void:
	var msg := {"t": "score", "rank": rank, "of": of, "v": text}
	if _score_sent.get(slot, {}) == msg:
		return
	if slot >= 0 and slot < players.size() and players[slot].is_connected_now():
		_score_sent[slot] = msg
		_send_json(slot, msg)


## Tells one phone its line of the result of the game (REQ-FL-67a): the text of its row in the result menu of the TV, with the
## place, the name and the score. The phone shows it in the middle of the screen with no button until the next round. It is kept
## for a phone that returns while the result is open. `parts` has the same row in pieces for the three lines of the phone: `g` the
## registry id of the game, `p` the place, `s` the score and `m` the medal tier (a field that is empty is not sent). `v` stays for
## a phone of an older build. `n` (place number), `k` (score key of `ResultText`) and `x` (its numbers) are the same place and
## score as data: the phone writes them in its own language, not the TV's (REQ-FL-62, issue #470). No phone gets another row.
func send_final(slot: int, text: String, parts := {}) -> void:
	var msg := {"t": "final", "v": text}
	for key in ["g", "p", "s", "m", "n", "k", "x"]:   # A field that is empty is not sent.
		if parts.has(key) and str(parts[key]) != "":
			msg[key] = parts[key]
	if slot >= 0 and slot < players.size():
		_final_sent[slot] = msg
		if players[slot].is_connected_now():
			_send_json(slot, msg)


## Tells one phone whose turn it is in a game with turns (REQ-BW-14): `state` 0 for no turn line, 1 when it is the turn of this
## phone, 2 when another player is on turn (`who` is the name of that player). `kind` names the words of the waiting line ("" for
## bowling, "golf" for Mini Golf). The same message is not sent twice in a row.
func send_turn(slot: int, state: int, who: String, kind := "") -> void:
	var msg := {"t": "turn", "s": state, "who": who if state == 2 else ""}
	if kind != "":
		msg["k"] = kind
	if _turn_sent.get(slot, {"s": 0, "who": ""}) == msg:
		return
	if slot >= 0 and slot < players.size() and players[slot].is_connected_now():
		_turn_sent[slot] = msg
		_send_json(slot, msg)


## Tells one phone the result of the round for its profile (FD-22, REQ-GM-99). Only a phone with a profile gets it, and only
## while it is connected: a lost phone does not get it and the score is not kept.
func send_result(slot: int, key: String, value: int) -> void:
	if slot >= 0 and slot < players.size() and players[slot].is_connected_now() and players[slot].has_profile():
		_send_json(slot, {"t": "result", "pid": players[slot].profile_id, "key": key, "v": value})


func haptic(slot: int, ms: int) -> void:
	if slot >= 0 and slot < players.size() and players[slot].is_connected_now():
		_send_json(slot, {"t": "haptic", "ms": ms})


## Remove a slot now (for example, when the player pressed OK to continue without it).
func drop_player(slot: int) -> void:
	if _sockets[slot] != null:
		_send_json(slot, {"t": "bye"})
		_discard(_sockets[slot])
		_sockets[slot] = null
	players[slot].reset()
	player_removed.emit(slot)


## Remove a player (the host chose "Remove" in the Players modal, REQ-FL-33). The slot is free at once.
## The phone gets `kicked`, forgets its token, and does not reconnect by itself.
func kick(slot: int) -> void:
	if _sockets[slot] != null:
		_send_json(slot, {"t": "kicked"})
		_discard(_sockets[slot])
		_sockets[slot] = null
	_forget_token(players[slot].token)   # The host removed this phone: its token no longer skips the approval.
	players[slot].reset()
	player_removed.emit(slot)


func _process(delta: float) -> void:
	_closing.service(Time.get_ticks_msec())
	if not listening:
		return
	sync_setup()
	_address_timer -= delta
	if _address_timer <= 0.0:
		_address_timer = 1.0
		var found: String = address_lookup.call()
		if found != ip:
			ip = found
	var now := Time.get_ticks_msec()
	_poll_waiting(now)   # Before the accept loop: a phone that closed its old socket and opened a new one is not two requests.
	while _tcp.is_connection_available():
		var stream := _tcp.take_connection()
		var host := stream.get_connected_host()
		# A waiting request counts like a connection that has not sent `hello` (FD-30.8).
		if _pending.size() + _waiting.size() >= MAX_PENDING or _pending_of(host) + _waiting_of(host) >= max_pending_per_ip \
				or not _accept_allowed(host, now):
			stream.disconnect_from_host()
			continue
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = BUFFER_BYTES
		ws.outbound_buffer_size = BUFFER_BYTES
		ws.max_queued_packets = MAX_QUEUED_PACKETS
		if ws.accept_stream(stream) == OK:
			_pending.append({"ws": ws, "since": now, "host": host})
	_poll_pending(now)
	for i in _sockets.size():
		_poll_slot(i, now)
		players[i].tick(now)


## The key of every per-address table (accept window, pending, waiting, refusals), so that one phone cannot get many keys by
## changing its IPv6 address (security review of PR #397). An IPv4-mapped IPv6 address (`::ffff:1.2.3.4`) is the IPv4 address;
## an IPv6 address is its /64 prefix (the first 4 groups, lower case, 4 digits each); an IPv4 address and anything that is not
## a valid IPv6 address stay as they are.
static func address_key(host: String) -> String:
	if not host.contains(":"):
		return host
	var s := host.to_lower()
	var zone := s.find("%")
	if zone >= 0:
		s = s.substr(0, zone)
	if s.begins_with("[") and s.ends_with("]"):
		s = s.substr(1, s.length() - 2)
	var parts: Array = []
	var dots := s.rfind(".")
	if dots >= 0:   # A dotted IPv4 tail takes the place of the last two groups.
		var cut := s.rfind(":")
		var v4 := s.substr(cut + 1).split(".")
		if v4.size() != 4:
			return host
		var bytes: Array[int] = []
		for b in v4:
			if not b.is_valid_int() or int(b) < 0 or int(b) > 255 or b.length() > 3:
				return host
			bytes.append(int(b))
		s = s.substr(0, cut + 1) + "%x:%x" % [bytes[0] * 256 + bytes[1], bytes[2] * 256 + bytes[3]]
	var halves := s.split("::")
	if halves.size() > 2:
		return host
	var head: PackedStringArray = halves[0].split(":") if halves[0] != "" else PackedStringArray()
	var tail := PackedStringArray()
	if halves.size() == 2 and halves[1] != "":
		tail = halves[1].split(":")
	var count := head.size() + tail.size()
	if halves.size() == 2:
		if count > 7:
			return host
		parts.append_array(head)
		for i in 8 - count:
			parts.append("0")
		parts.append_array(tail)
	else:
		if count != 8:
			return host
		parts.append_array(head)
	for i in parts.size():
		var g: String = parts[i]
		if g.length() < 1 or g.length() > 4 or not g.is_valid_hex_number(false):
			return host
		parts[i] = g.lpad(4, "0")
	if parts[0] == "0000" and parts[1] == "0000" and parts[2] == "0000" and parts[3] == "0000" and parts[4] == "0000" \
			and parts[5] == "ffff":
		var hi: int = parts[6].hex_to_int()
		var lo: int = parts[7].hex_to_int()
		return "%d.%d.%d.%d" % [hi >> 8, hi & 255, lo >> 8, lo & 255]
	return "%s:%s:%s:%s" % [parts[0], parts[1], parts[2], parts[3]]


## How many connections of the address `host` have not sent `hello` yet (the key of `address_key`).
func _pending_of(host: String) -> int:
	var key := address_key(host)
	var n := 0
	for entry in _pending:
		if address_key(str(entry.get("host", ""))) == key:
			n += 1
	return n


## True when the address `host` has not used up its connections in the last `ACCEPT_WINDOW_MS`. A refused try is not counted.
func _accept_allowed(address: String, now: int) -> bool:
	var host := address_key(address)
	var times: Array = _accepts.get(host, [])
	while not times.is_empty() and now - int(times[0]) > ACCEPT_WINDOW_MS:
		times.pop_front()
	if times.size() >= max_accepts_per_ip:
		_accepts[host] = times
		return false
	times.append(now)
	_accepts[host] = times
	if _accepts.size() > 256:   # Forget the addresses that are quiet.
		for h in _accepts.keys():
			var t: Array = _accepts[h]
			if t.is_empty() or now - int(t[t.size() - 1]) > ACCEPT_WINDOW_MS:
				_accepts.erase(h)
	return true


## The JSON object of a text frame; empty for a frame above `MAX_TEXT_BYTES`, without parsing it.
func _parse_text(data: PackedByteArray) -> Dictionary:
	if data.size() > MAX_TEXT_BYTES:
		return {}
	return Protocol.parse_json(data.get_string_from_utf8())


func _poll_pending(now: int) -> void:
	for entry in _pending.duplicate():
		var ws: WebSocketPeer = entry.ws
		ws.poll()
		var st := ws.get_ready_state()
		var drop := false
		if st == WebSocketPeer.STATE_OPEN:
			if ws.get_available_packet_count() > 0:
				var data := ws.get_packet()
				if ws.was_string_packet():
					_check_hello(ws, _parse_text(data), now, str(entry.get("host", "")))
				drop = true # Either it joined (moved to a slot) or it was rejected.
		elif st == WebSocketPeer.STATE_CLOSED:
			drop = true
		if not drop and now - int(entry.since) > Protocol.HELLO_TIMEOUT_MS:
			ws.close()
			drop = true
		if drop:
			_pending.erase(entry)


## The checks of a `hello` in the order of docs/JOIN_APPROVAL_PLAN.md 4.2. A phone that can join goes to `_admit`; with
## `approve_new` a new phone goes to the approval gate instead (`_queue_request`).
func _check_hello(ws: WebSocketPeer, msg: Dictionary, now: int, host := "") -> void:
	if Protocol.text(msg, "t") != "hello":
		ws.close()
		return
	if Protocol.whole(msg, "v") != Protocol.VERSION:
		_reject(ws, "version")
		return
	var room := Protocol.text(msg, "room").to_upper()
	if room != room_code and not (room == "" and allow_empty_room):
		_reject(ws, "bad_room")
		return
	var token := Protocol.text(msg, "token")
	if token != "" and _replaced_tokens.has(token):
		if now < int(_replaced_tokens[token]):
			_send_kicked(ws, "replaced")   # This phone was replaced by another phone with its profile.
			return
		_replaced_tokens.erase(token)
	if not approve_new or _slot_with_token(token) >= 0:
		_admit(ws, msg, now, false)   # The join of today, or a resume: no card.
		return
	if token != "" and _known_tokens.has(token):
		_admit(ws, msg, now, true)    # A returning phone that this TV welcomed in this run (FD-30.4): no card.
		return
	var refusal := _refusal_for(msg)
	if refusal == "replaced":
		_send_kicked(ws, "replaced")   # Before any approval (issue #388, REQ-FL-74).
	elif refusal == "full":
		_reject(ws, "full")            # No card for a phone that cannot get a slot (REQ-FL-95).
	else:
		_queue_request(ws, msg, now, host)


## The answer that a new phone would get from `_admit` with no side effect: "replaced" (a connected phone holds its profile),
## "full" (no free slot, and no lost holder to take over), or "" (it can get a slot).
func _refusal_for(msg: Dictionary) -> String:
	var want_pid := Profile.clean_id(Protocol.text(msg, "pid"))
	if want_pid != "":
		var dup := _slot_with_pid(want_pid)
		if dup >= 0:
			if players[dup].state == PlayerInput.State.CONNECTED:
				return "replaced"
			if in_menu_phase():
				return ""   # The holder is lost: the takeover frees its slot (at the allow only).
	for p in players:
		if not p.is_present():
			return ""
	return "full"


## The approval gate (4.2 step 10): a blocked address, a replacement of the request of the same address, a full queue, a new
## request.
func _queue_request(ws: WebSocketPeer, msg: Dictionary, now: int, address: String) -> void:
	var host := address_key(address)   # Phones behind one address (NAT, hotspot) share one request: an accepted limit.
	if _refusals.is_blocked(host, now):
		_send_kicked(ws, "refused")   # Not counted again.
		return
	if max_waiting_per_ip > 0 and _waiting_of(host) >= max_waiting_per_ip:
		for entry in _waiting:   # The newest `hello` of the address takes the place and the times of the old one.
			if entry.host == host:
				_discard(entry.ws)
				entry.ws = ws
				entry.hello = msg
				entry.last_keepalive_ms = now
				if int(entry.shown_ms) >= 0:
					# The host saw the old phone: the new one is a new request (a late allow of the old id does nothing),
					# and the card shows again after the gap.
					entry.id = _next_request_id
					_next_request_id += 1
					entry.shown_ms = -1
					_last_card_end_ms = now
				_send_pending(ws)
				requests_changed.emit()
				return
	if _waiting.size() >= MAX_WAITING:
		_send_kicked(ws, "busy")
		return
	_waiting.append({"id": _next_request_id, "ws": ws, "host": host, "hello": msg, "arrived_ms": now, "shown_ms": -1,
			"last_keepalive_ms": now})
	_next_request_id += 1
	_send_pending(ws)
	requests_changed.emit()


## The slot that holds this token (a present slot), or -1.
func _slot_with_token(token: String) -> int:
	if token != "":
		for p in players:
			if p.is_present() and p.token == token:
				return p.slot
	return -1


## The slot path of a `hello` that passed the checks: resume, held profile, lost holder, free slot, `welcome`. `known` is a phone
## with a token of this run and no present slot: it keeps its token. At the allow of a request this runs again, so a room that
## changed in the meantime gives `kicked` / `replaced` or `reject` / `full` (FD-30.5).
func _admit(ws: WebSocketPeer, msg: Dictionary, now: int, known: bool) -> void:
	var token := Protocol.text(msg, "token")
	var in_menu := in_menu_phase()
	# The profile of the phone. It counts only in the menu phases: in a round the new phone is a guest (PROFILES_PLAN.md 4.4).
	var pid := Profile.clean_id(Protocol.text(msg, "pid")) if in_menu else ""
	var av := Profile.clean_avatar(msg.get("av", -1)) if pid != "" else -1
	var p_name := Profile.clean_name(Protocol.text(msg, "name"))
	if not in_menu and Profile.clean_id(Protocol.text(msg, "pid")) != "":
		p_name = ""   # A new phone with a profile joins a round as a guest.
	var slot := -1
	var resumed := false
	if _slot_with_token(token) >= 0:
		slot = _slot_with_token(token)
		resumed = true
	var want_pid := Profile.clean_id(Protocol.text(msg, "pid"))   # In every phase: a held profile is not taken.
	if want_pid != "":
		var dup := _slot_with_pid(want_pid)
		if dup >= 0 and dup != slot:
			if players[dup].state == PlayerInput.State.CONNECTED:
				if not resumed:
					# The phone that holds the profile is connected: the newer phone is sent away with a message and takes no
					# slot (owner decision 2026-11-07, issue #388, REQ-FL-74).
					_send_kicked(ws, "replaced")
					return
				pid = ""   # A phone that returns with the profile of another connected phone is a guest.
				av = -1
				p_name = ""
			elif pid != "":
				_replace_slot(dup, now)   # The holder is lost: a takeover is allowed (a family moves a profile). Before the "full" check.
	if slot < 0:
		for p in players:
			if not p.is_present():
				slot = p.slot
				break
	if slot < 0:
		_reject(ws, "full")
		return
	if _sockets[slot] != null:
		_sockets[slot].close() # A resume replaces the old (dead) socket.
	_sockets[slot] = ws
	_last_rx_ms[slot] = now
	var player := players[slot]
	if not resumed and not known:
		token = Protocol.make_token()
	_remember_token(token)
	var keep := resumed and not in_menu   # A phone that returns in a round keeps the profile that the TV has.
	var old_pid := player.profile_id
	var old_av := player.avatar
	var old_raw := player.raw_name
	var old_shown := player.player_name
	player.on_join(p_name, token)
	if keep:
		player.set_profile(old_pid, old_av, old_raw)
		player.player_name = old_shown   # A phone that returns in a round keeps the name the TV showed (REQ-FL-69).
	else:
		player.set_profile(pid, av, p_name)
		PlayerNames.assign(players, slot if in_round() else -1)
	_turn_sent.erase(slot)
	_score_sent.erase(slot)   # A phone that joins or returns has no score yet.
	var welcome := {
		"t": "welcome", "slot": slot, "token": token,
		"color": "#" + player.color.to_html(false),
		"phase": phase_for(slot), "name": tv_name, "lang": language,
		"pid": player.profile_id, "av": player.avatar, "pname": player.player_name if player.has_profile() else "",
	}
	if not recenter_button:
		welcome["rc"] = false
	if pad_buttons != "ab":
		welcome["ab"] = pad_buttons
	_send_json(slot, welcome)
	if resumed and _final_sent.has(slot) and in_round():   # The result menu runs in the phase `playing`.
		_send_json(slot, _final_sent[slot])   # The same phone returns while the result is open: its line again.
	if not resumed:
		_swing_ok.erase(slot)   # A new phone in a used slot has not tapped OK yet, and is IN.
		_out.erase(slot)
	_setup_sig = ""   # A phone that joins or returns while the settings view is open gets `setup` (sync_setup).
	if resumed:
		player_resumed.emit(slot)
	else:
		player_joined.emit(slot)


## True in a phase where a phone can change its profile: the logo and Connect screens and the menus.
func in_menu_phase() -> bool:
	return phase in ["connect", "menu"]


## True while a round runs (the game plays or is paused).
func in_round() -> bool:
	return phase in ["playing", "paused"]


## The slot of the player with this profile ID, or -1.
func _slot_with_pid(pid: String) -> int:
	for p in players:
		if p.is_present() and p.profile_id == pid:
			return p.slot
	return -1


## Frees the slot of a phone that was replaced by another phone with the same profile. The old phone gets `kicked` with the
## reason `replaced`, and the TV remembers its token, so that the phone does not come back and replace the new one.
func _replace_slot(slot: int, now: int) -> void:
	if _sockets[slot] != null:
		_send_json(slot, {"t": "kicked", "reason": "replaced"})
		_discard(_sockets[slot])
		_sockets[slot] = null
	for token in _replaced_tokens.keys():
		if now >= int(_replaced_tokens[token]):
			_replaced_tokens.erase(token)   # Only a token that is still remembered counts.
	if players[slot].token != "":
		_replaced_tokens[players[slot].token] = now + Protocol.REPLACED_TOKEN_MS
	_forget_token(players[slot].token)
	players[slot].reset()
	player_removed.emit(slot)


func _send_kicked(ws: WebSocketPeer, reason: String) -> void:
	ws.send_text(Protocol.to_json({"t": "kicked", "reason": reason}))
	_discard(ws)


## A `profile` message from a phone (docs/PROTOCOL.md): it changes the profile of its slot in the menu phases. The answer says
## what the TV has now, so the phone shows the truth.
func _handle_profile(i: int, msg: Dictionary, now: int) -> void:
	if in_menu_phase():
		var pid := Profile.clean_id(Protocol.text(msg, "pid"))
		var av := Profile.clean_avatar(msg.get("av", -1)) if pid != "" else -1
		var p_name := Profile.clean_name(Protocol.text(msg, "name")) if pid != "" else ""
		if pid != "":
			var dup := _slot_with_pid(pid)
			if dup >= 0 and dup != i:
				if players[dup].state == PlayerInput.State.CONNECTED:
					pid = ""   # The holder is connected: this phone becomes a guest (issue #388, REQ-FL-74).
					av = -1
					p_name = ""
				else:
					_replace_slot(dup, now)
		players[i].set_profile(pid, av, p_name)
		PlayerNames.assign(players)
	var p := players[i]
	_send_json(i, {"t": "profile", "pid": p.profile_id, "name": p.player_name if p.has_profile() else "", "av": p.avatar})


func _reject(ws: WebSocketPeer, reason: String) -> void:
	ws.send_text(Protocol.to_json({"t": "reject", "reason": reason}))
	_discard(ws)


## Close a socket and keep polling it, so the last frames are sent.
## The close is delayed: a close frame can drop the frames that came before it.
func _discard(ws: WebSocketPeer) -> void:
	_closing.add(ws, Time.get_ticks_msec())


func _poll_slot(i: int, now: int) -> void:
	var ws := _sockets[i]
	var player := players[i]
	if ws != null:
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var data := ws.get_packet()
				_last_rx_ms[i] = now
				if ws.was_string_packet():
					_handle_control(i, _parse_text(data), now)
				else:
					var pkt := Protocol.decode_sensor(data)
					if not pkt.is_empty():
						player.on_sensor(pkt, now)
			if player.is_connected_now() and now - _last_rx_ms[i] > peer_timeout_ms:
				# Silent for too long (for example the phone lost its Wi-Fi). The slot is lost now. A close handshake
				# would never end, because the phone cannot answer, so the TV would never notice.
				_sockets[i] = null
				_discard(ws)
				_mark_lost(i)
				return
		elif st == WebSocketPeer.STATE_CLOSED:
			while ws.get_available_packet_count() > 0: # Frames that came with the close.
				var data2 := ws.get_packet()
				if ws.was_string_packet():
					_handle_control(i, _parse_text(data2), now)
			if _sockets[i] == ws: # A "bye" in those frames may have cleared the slot.
				_sockets[i] = null
				_mark_lost(i)
	# While the game is paused for a lost phone (a phone call), the slot is kept longer.
	var grace := paused_slot_grace_ms if phase == "paused" else slot_grace_ms
	if player.state == PlayerInput.State.LOST and now - player.lost_since_ms > grace:
		player.reset()
		player_removed.emit(i)


func _mark_lost(i: int) -> void:
	var player := players[i]
	if player.state == PlayerInput.State.CONNECTED:
		player.on_lost()
		player_lost.emit(i)


func _handle_control(i: int, msg: Dictionary, now: int) -> void:
	match Protocol.text(msg, "t"):
		"ping":
			_send_json(i, {"t": "pong", "id": Protocol.whole(msg, "id"), "t0": Protocol.num(msg, "t0"), "t1": now})
		"stat":
			players[i].on_stat(Protocol.num(msg, "rtt", -1.0), Protocol.num(msg, "off"))
		"recenter":
			players[i].recenter(false)   # The button: the pose in the hand is neutral, no snap to flat.
		"leave_ask":
			_handle_leave_ask(i, now)
		"swing_ok":
			if setup_swing:
				_swing_ok[i] = true
		"play":
			if setup_open and msg.get("v", true) is bool:
				set_in(i, bool(msg.v))
				if players_in().has(i) != bool(msg.v):
					_setup_sig = ""   # A refused choice: the phone gets the choice that the TV kept.
		"profile":
			_handle_profile(i, msg, now)
		"bye":
			if _sockets[i] != null:
				_discard(_sockets[i])
			_sockets[i] = null
			_forget_token(players[i].token)   # The player left: its token no longer skips the approval.
			players[i].reset()
			player_removed.emit(i)


## A `leave_ask` from a phone (docs/PROTOCOL.md, REQ-FL-52c). The TV takes it only while a game plays, from a connected phone that
## takes part in the round, and at most once each `Protocol.LEAVE_ASK_MIN_MS` from one phone (a child must not spam it). Any other
## `leave_ask` is ignored with no answer. The game decides whether a question is already open (`leave_asked`).
func _handle_leave_ask(i: int, now: int) -> void:
	if phase_for(i) != "playing" or not players[i].is_connected_now():
		return
	if _last_leave_ask_ms.has(i) and now - int(_last_leave_ask_ms[i]) < Protocol.LEAVE_ASK_MIN_MS:
		return
	_last_leave_ask_ms[i] = now
	leave_asked.emit(i)


func _send_json(slot: int, d: Dictionary) -> void:
	var ws := _sockets[slot]
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(Protocol.to_json(d))


## Tells a phone that waits for the host that its `hello` arrived (docs/PROTOCOL.md, "Approval"). It has no field: no time.
func _send_pending(ws: WebSocketPeer) -> void:
	ws.send_text(Protocol.to_json({"t": "pending"}))


## How many requests of the address `host` wait.
func _waiting_of(host: String) -> int:
	var key := address_key(host)
	var n := 0
	for entry in _waiting:
		if address_key(str(entry.host)) == key:
			n += 1
	return n


## The number of phones that wait for the host.
func request_count() -> int:
	return _waiting.size()


## The request that the host sees now: `{id, name, av, slot_hint, others}`, or empty when no card shows. `name` is empty for a
## phone with no name; `av` is -1 for a guest; `slot_hint` is the first free slot; `others` the requests behind this one. It has
## no time (FD-30.14).
func shown_request() -> Dictionary:
	if _waiting.is_empty() or int(_waiting[0].shown_ms) < 0:
		return {}
	var msg: Dictionary = _waiting[0].hello
	var has_pid := Profile.clean_id(Protocol.text(msg, "pid")) != ""
	var hint := -1
	for p in players:
		if not p.is_present():
			hint = p.slot
			break
	return {"id": int(_waiting[0].id), "name": Profile.clean_name(Protocol.text(msg, "name")),
			"av": Profile.clean_avatar(msg.get("av", -1)) if has_pid else -1, "guest": not has_pid, "slot_hint": hint,
			"others": _waiting.size() - 1}


## The host allowed the shown request: the phone gets a slot (or the answer that the room gives now) and the refusal count of its
## address goes to 0. Nothing happens for an id that is not shown (a key press that comes after a timeout).
func allow_request(id: int) -> void:
	if shown_request().get("id", -1) != id:
		return
	var now := Time.get_ticks_msec()
	var entry: Dictionary = _waiting.pop_front()
	_last_card_end_ms = now
	_refusals.clear(entry.host, now)
	_admit(entry.ws, entry.hello, now, false)
	requests_changed.emit()


## The host refused the shown request: `kicked` / `refused`. The third refusal in a row from one address blocks it. Nothing
## happens for an id that is not shown.
func refuse_request(id: int) -> void:
	if shown_request().get("id", -1) != id:
		return
	var now := Time.get_ticks_msec()
	_refusals.count_refusal(_waiting[0].host, now, refuse_block_after, refuse_block_ms, max_refusal_entries)
	_end_request(0, "refused", now)


## The setting changed. OFF refuses every waiting request, with no count and no block (FD-30.10); ON changes nothing.
func set_approve_new(on: bool) -> void:
	approve_new = on
	if on:
		return
	var now := Time.get_ticks_msec()
	while not _waiting.is_empty():
		_end_request(_waiting.size() - 1, "refused", now)


## Ends a request: `kicked` with `reason`, or no message for "" (a cancel or a replacement). The socket closes 300 ms later.
func _end_request(index: int, reason: String, now: int) -> void:
	var entry: Dictionary = _waiting[index]
	_waiting.remove_at(index)
	if int(entry.shown_ms) >= 0:
		_last_card_end_ms = now
	if reason != "" and entry.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		entry.ws.send_text(Protocol.to_json({"t": "kicked", "reason": reason}))
	_discard(entry.ws)
	requests_changed.emit()


## The shown request goes back to "not shown" (the phase went to a round): it gets a new time at the next menu phase.
func _hide_shown_request() -> void:
	if not _waiting.is_empty() and int(_waiting[0].shown_ms) >= 0:
		_waiting[0].shown_ms = -1
		_last_card_end_ms = Time.get_ticks_msec()
		requests_changed.emit()


## Each frame: reads the waiting sockets (a `bye` or a close ends the request with no message), sends the keepalive, ends the
## requests that ran out of time and shows the head of the queue (docs/JOIN_APPROVAL_PLAN.md 4.3, FD-30.9).
func _poll_waiting(now: int) -> void:
	for entry in _waiting.duplicate():
		var ws: WebSocketPeer = entry.ws
		ws.poll()
		var st := ws.get_ready_state()
		var gone := st == WebSocketPeer.STATE_CLOSED
		if st == WebSocketPeer.STATE_OPEN:
			var read := 0
			while ws.get_available_packet_count() > 0 and read < MAX_WAITING_FRAMES and not gone:
				read += 1
				var data := ws.get_packet()
				if ws.was_string_packet() and Protocol.text(_parse_text(data), "t") == "bye":
					gone = true   # CANCEL on the phone. Other frames of a waiting phone are dropped.
		if gone:
			var i := _waiting.find(entry)
			if i >= 0:
				_end_request(i, "", now)
			continue
		if st == WebSocketPeer.STATE_OPEN and now - int(entry.last_keepalive_ms) >= Protocol.PENDING_KEEPALIVE_MS:
			entry.last_keepalive_ms = now
			_send_pending(ws)
	for i in range(_waiting.size() - 1, -1, -1):
		var e: Dictionary = _waiting[i]
		if now - int(e.arrived_ms) >= approval_total_ms \
				or (int(e.shown_ms) >= 0 and now - int(e.shown_ms) >= approval_timeout_ms):
			_end_request(i, "timeout", now)   # The refusal count does not change.
	if not _waiting.is_empty() and int(_waiting[0].shown_ms) < 0 and in_menu_phase() \
			and now - _last_card_end_ms >= approval_gap_ms:
		_waiting[0].shown_ms = now
		requests_changed.emit()


## Remembers the token of a phone that got a slot (FD-30.4): the newest is last, at most `MAX_KNOWN_TOKENS` are kept.
func _remember_token(token: String) -> void:
	if token == "":
		return
	_known_tokens.erase(token)
	_known_tokens.append(token)
	while _known_tokens.size() > MAX_KNOWN_TOKENS:
		_known_tokens.remove_at(0)


## A kick, a `bye` or a replacement of the slot: the token no longer skips the approval.
func _forget_token(token: String) -> void:
	_known_tokens.erase(token)
