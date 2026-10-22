extends Node
## TV side. WebSocket server (TCPServer + WebSocketPeer) with 4 player slots.
## It owns all sockets. It writes into PlayerInput objects and emits signals.
## It never refers to game scripts.

const Protocol = preload("res://scripts/core/protocol.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Profile = preload("res://scripts/core/profile.gd")

signal player_joined(slot: int)
signal player_lost(slot: int)
signal player_resumed(slot: int)
signal player_removed(slot: int)

var room_code := ""                  # The code of `ip` (Protocol.room_code_for_ip). Empty while the TV has no address.
## The LAN address of this TV. The room code follows it, so a new address shows a new code (REQ-FL-4).
var ip := "":
	set(value):
		ip = value
		room_code = Protocol.room_code_for_ip(value)
## Finds the address of this device. A test sets another one (an empty text is a device with no network).
var address_lookup: Callable = Protocol.local_ipv4
var tv_name := "Living Room TV"
## False while a game without a pointer is running: the phones then hide the Recenter box (REQ-GM-37). It is sent in the
## `phase` and `welcome` messages as `rc` and only when it is false.
var recenter_button := true
## The buttons of the pad while a game runs: "", "a", "b" or "ab" (REQ-GM-37a). Sent as `ab` in the `phase` and `welcome`
## messages, and only when it is not "ab".
var pad_buttons := "ab"
## True while the settings view of a swing game is open: phones show the safety card and answer `swing_ok` (REQ-GM-102).
var setup_swing := false
## True while the settings view of a game is open (issue #76, #79): the phones get `setup` messages.
var setup_open := false
var _out := {}   # slot -> true for a phone that chose OUT of the game in the settings view (REQ-GM-104).
var _setup_sig := ""
var _swing_ok := {}   # slot -> true for a phone that tapped OK on the safety card (or had tapped it before in this run).
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

var _address_timer := 0.0
var _tcp := TCPServer.new()
var _pending: Array = []             # [{ws, since_ms}]
var _sockets: Array[WebSocketPeer] = []
var _last_rx_ms: Array[int] = []
var _closing: Array = []             # Rejected sockets that finish their close handshake.
var _replaced_tokens := {}           # token -> time (ms) until which the TV remembers it (a phone that was replaced, FD-22).
var _turn_sent := {}                 # slot -> the last turn message sent to that phone.
var _score_sent := {}                # slot -> the last score message sent to that phone (it is not sent again, REQ-FL-67).


func start(settings: Dictionary) -> Error:
	ip = address_lookup.call()
	for i in Protocol.MAX_PLAYERS:
		players.append(PlayerInput.new(i, settings))
		_sockets.append(null)
		_last_rx_ms.append(0)
	player_removed.connect(_on_player_removed)
	var err := _tcp.listen(port)
	listening = (err == OK)
	if err != OK:
		push_error("TvServer: cannot listen on port %d (error %d)" % [port, err])
	return err


## A slot that is freed during a round (left, removed, grace time over, host continued without it)
## is not in the round any more. A new phone in that slot waits for the next round (REQ-FL-25).
func _on_player_removed(slot: int) -> void:
	round_slots.erase(slot)
	if not in_round():
		_assign_names()


func stop() -> void:
	for i in _sockets.size():
		if _sockets[i] != null:
			_send_json(i, {"t": "bye"})
			_sockets[i].poll() # Flush the bye frame.
			_sockets[i].close()
			_sockets[i].poll()
	_tcp.stop()
	_replaced_tokens.clear()
	listening = false


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
	phase = p_phase
	setup_open = false
	setup_swing = false
	_swing_ok.clear()
	if not p_phase in ["playing", "paused"]:
		_out.clear()   # Every phone is IN again outside a round (the Games screen, a new settings view).
		recenter_button = true
		pad_buttons = "ab"
	round_slots.clear()
	round_limited = false
	if not p_phase in ["playing", "paused"]:
		_assign_names()   # The names are made again in the menus only, so they do not change in a round (docs/PROFILES_PLAN.md 4.3).
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
func set_setup(swing: bool) -> void:
	setup_open = true
	setup_swing = swing
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
	var sig := "%s|%s|%s" % [str(slots), str(_out.keys()), str(setup_swing)]
	if sig == _setup_sig:
		return
	_setup_sig = sig
	for s in slots:
		_send_json(s, {"t": "setup", "swing": setup_swing, "pick": slots.size() >= 2, "in": not _out.has(s)})


## The connected phones that play the next game: all of them, except the ones that chose OUT in the settings view (REQ-GM-104).
func players_in() -> Array[int]:
	var r: Array[int] = []
	for s in connected_slots():
		if not _out.has(s):
			r.append(s)
	return r


## A phone chose IN (`true`) or OUT. The last phone that is IN cannot go OUT: a game needs a player.
func set_in(slot: int, value: bool) -> void:
	if value:
		_out.erase(slot)
	elif players_in().has(slot) and players_in().size() > 1:
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
	players[slot].reset()
	player_removed.emit(slot)


func _process(delta: float) -> void:
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
	while _tcp.is_connection_available():
		var stream := _tcp.take_connection()
		var ws := WebSocketPeer.new()
		if ws.accept_stream(stream) == OK:
			_pending.append({"ws": ws, "since": now})
	_poll_pending(now)
	for entry in _closing.duplicate():
		entry.ws.poll()
		if entry.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED or now - int(entry.since) > 1500:
			_closing.erase(entry)
		elif not entry.closed and now - int(entry.since) >= 300:
			entry.ws.close()
			entry.closed = true
	for i in _sockets.size():
		_poll_slot(i, now)
		players[i].tick(now)


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
					_handle_hello(ws, Protocol.parse_json(data.get_string_from_utf8()), now)
				drop = true # Either it joined (moved to a slot) or it was rejected.
		elif st == WebSocketPeer.STATE_CLOSED:
			drop = true
		if not drop and now - int(entry.since) > Protocol.HELLO_TIMEOUT_MS:
			ws.close()
			drop = true
		if drop:
			_pending.erase(entry)


func _handle_hello(ws: WebSocketPeer, msg: Dictionary, now: int) -> void:
	if msg.get("t", "") != "hello":
		ws.close()
		return
	if int(msg.get("v", 0)) != Protocol.VERSION:
		_reject(ws, "version")
		return
	var room := String(msg.get("room", "")).to_upper()
	if room != "" and room != room_code:
		_reject(ws, "bad_room")
		return
	var token := String(msg.get("token", ""))
	if token != "" and _replaced_tokens.has(token):
		if now < int(_replaced_tokens[token]):
			_send_kicked(ws, "replaced")   # This phone was replaced by another phone with its profile.
			return
		_replaced_tokens.erase(token)
	var in_menu := in_menu_phase()
	# The profile of the phone. It counts only in the menu phases: in a round the new phone is a guest (PROFILES_PLAN.md 4.4).
	var pid := Profile.clean_id(String(msg.get("pid", ""))) if in_menu else ""
	var av := Profile.clean_avatar(msg.get("av", -1)) if pid != "" else -1
	var p_name := Profile.clean_name(String(msg.get("name", "")))
	if not in_menu and Profile.clean_id(String(msg.get("pid", ""))) != "":
		p_name = ""   # A new phone with a profile joins a round as a guest.
	var slot := -1
	var resumed := false
	if token != "":
		for p in players:
			if p.is_present() and p.token == token:
				slot = p.slot
				resumed = true
				break
	if pid != "":
		var dup := _slot_with_pid(pid)
		if dup >= 0 and dup != slot:
			_replace_slot(dup, now)   # The newer phone wins. This is before the "full" check, so a full TV still takes it.
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
	if not resumed:
		token = Protocol.make_token()
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
		_assign_names(slot if in_round() else -1)
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
	players[slot].reset()
	player_removed.emit(slot)


func _send_kicked(ws: WebSocketPeer, reason: String) -> void:
	ws.send_text(Protocol.to_json({"t": "kicked", "reason": reason}))
	_discard(ws)


## The names that the TV shows (docs/PROFILES_PLAN.md 4.3): the profile name, or "Player N" for a phone without a name. A
## name that another player has already gets a number (`Sam`, `Sam 2`); case and spaces at the ends do not count. With `only`
## set, only that slot is made again (a phone that joins in a round), against the names of the others.
func _assign_names(only := -1) -> void:
	var used: Array[String] = []
	if only >= 0:
		for p in players:
			if p.is_present() and p.slot != only:
				used.append(p.player_name.strip_edges().to_upper())
	for p in players:
		if not p.is_present() or (only >= 0 and p.slot != only):
			continue
		var base: String = p.raw_name if p.raw_name != "" else "Player %d" % (p.slot + 1)
		var shown := base
		var n := 2
		while used.has(shown.strip_edges().to_upper()):
			shown = "%s %d" % [base, n]
			n += 1
		p.player_name = shown
		used.append(shown.strip_edges().to_upper())


## A `profile` message from a phone (docs/PROTOCOL.md): it changes the profile of its slot in the menu phases. The answer says
## what the TV has now, so the phone shows the truth.
func _handle_profile(i: int, msg: Dictionary, now: int) -> void:
	if in_menu_phase():
		var pid := Profile.clean_id(String(msg.get("pid", "")))
		var av := Profile.clean_avatar(msg.get("av", -1)) if pid != "" else -1
		var p_name := Profile.clean_name(String(msg.get("name", ""))) if pid != "" else ""
		if pid != "":
			var dup := _slot_with_pid(pid)
			if dup >= 0 and dup != i:
				_replace_slot(dup, now)
		players[i].set_profile(pid, av, p_name)
		_assign_names()
	var p := players[i]
	_send_json(i, {"t": "profile", "pid": p.profile_id, "name": p.player_name if p.has_profile() else "", "av": p.avatar})


func _reject(ws: WebSocketPeer, reason: String) -> void:
	ws.send_text(Protocol.to_json({"t": "reject", "reason": reason}))
	_discard(ws)


## Close a socket and keep polling it, so the last frames are sent.
## The close is delayed: a close frame can drop the frames that came before it.
func _discard(ws: WebSocketPeer) -> void:
	ws.poll()
	_closing.append({"ws": ws, "since": Time.get_ticks_msec(), "closed": false})


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
					_handle_control(i, Protocol.parse_json(data.get_string_from_utf8()), now)
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
					_handle_control(i, Protocol.parse_json(data2.get_string_from_utf8()), now)
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
	match msg.get("t", ""):
		"ping":
			_send_json(i, {"t": "pong", "id": msg.get("id", 0), "t0": msg.get("t0", 0), "t1": now})
		"stat":
			players[i].on_stat(float(msg.get("rtt", -1)), float(msg.get("off", 0)))
		"recenter":
			players[i].recenter()
		"swing_ok":
			if setup_swing:
				_swing_ok[i] = true
		"play":
			if setup_open and msg.get("v", true) is bool:
				set_in(i, bool(msg.v))
				_setup_sig = ""   # The phone gets the choice that the TV accepted, also when it refused one.
		"profile":
			_handle_profile(i, msg, now)
		"bye":
			if _sockets[i] != null:
				_discard(_sockets[i])
			_sockets[i] = null
			players[i].reset()
			player_removed.emit(i)


func _send_json(slot: int, d: Dictionary) -> void:
	var ws := _sockets[slot]
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(Protocol.to_json(d))
