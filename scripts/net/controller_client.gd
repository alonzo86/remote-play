extends Node
## Phone side. WebSocket client with automatic reconnect and latency measurement.
## It does not know about screens or sensors. Other scripts call send_sensor().

const Protocol = preload("res://scripts/core/protocol.gd")

signal state_changed(state: int)
signal welcomed(slot: int, color: Color)
signal rejected(reason: String)
signal phase_changed(phase: String)
signal language_changed(code: String)   # The TV language (REQ-FL-62).
signal haptic_requested(ms: int)
signal score_changed()   # The place or the score of this phone changed (REQ-FL-67).
signal result_received(key: String, value: int)   # A round result for the active profile (REQ-GM-99).
signal profile_answered()   # The TV told which profile this phone has now (REQ-FL-70).

enum State { IDLE, CONNECTING, JOINING, CONNECTED, RECONNECTING }

const LAST_FILE := "user://controller.cfg"
const RETRY_DELAYS := [0.5, 1.0, 2.0]
const CONNECT_TIMEOUT_MS := 4000
const GIVE_UP_AFTER := 3   # Failed first attempts before "unreachable".

var state: State = State.IDLE
var slot := -1
var color := Color.WHITE
var phase := "connect"
var tv_name := ""
var rtt_ms := -1.0
var clock_offset_ms := 0.0   # TV clock minus phone clock.
var tx_rate := 0.0           # Sensor packets sent per second.
var player_name := ""        # The profile name that goes to the TV. Empty for a guest.
var pid := ""                # The profile ID that goes to the TV. Empty for a guest (FD-22).
var avatar := -1             # The avatar index of the profile, or -1.
var tv_pid := ""             # The profile that the TV has for this phone now. It can differ from `pid` during a round.
var tv_avatar := -1
var tv_player_name := ""
var score_rank := 0          # The place of this phone in the round, 1 for the leader. 0 when the TV sent no score (REQ-FL-67).
var score_of := 0            # The number of ranked players.
var recenter_button := true    # False in a game without a pointer: the pad hides the Recenter box (REQ-GM-37).
var turn_state := 0           # 0 no turn line, 1 this phone is on turn, 2 another player is on turn (REQ-BW-14).
var turn_kind := ""           # "" for the words of Pin Pals, "golf" for Mini Golf.
var turn_who := ""            # The name of the player on turn when turn_state is 2.
var score_text := ""         # The score as the TV shows it. Empty when there is no score yet.

var host := ""
var port := Protocol.WS_PORT
var room := ""
var pin := ""   # The PIN of the TV for the next join. Not saved. It is cleared when the TV accepts this phone.

var _ws: WebSocketPeer
var _closing: Array = []     # Closed sockets that still flush their last frames.
var _token := ""
var _attempt := 0
var _retry_at_ms := 0
var _open_started_ms := 0
var _was_connected := false
var _last_rx_ms := 0
var _ping_id := 0
var _next_ping_ms := 0
var _tx_count := 0
var _tx_window_ms := 0


func connect_to(p_host: String, p_port: int, p_room: String, p_pin := "") -> void:
	_close_socket()
	host = p_host
	port = p_port
	room = p_room.to_upper()
	pin = p_pin
	_attempt = 0
	_was_connected = false
	_open()


func leave() -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(Protocol.to_json({"t": "bye"}))
		_ws.poll() # Flush the bye frame now.
	_close_socket()
	_token = ""
	slot = -1
	tv_pid = ""
	tv_avatar = -1
	tv_player_name = ""
	_was_connected = false
	_set_state(State.IDLE)
	_save_last(true)


func is_connected_to_tv() -> bool:
	return state == State.CONNECTED


func send_sensor(packet: PackedByteArray) -> void:
	if state != State.CONNECTED or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send(packet, WebSocketPeer.WRITE_MODE_BINARY)
	_tx_count += 1


func send_recenter() -> void:
	_send_json({"t": "recenter"})


## Sets the profile of this phone (FD-22). An empty `p_pid` is the guest. It goes to the TV at the next `hello` and, when the
## phone is in a menu phase of the TV, at once as a `profile` message. The TV answer (`profile_answered`) says what it accepted.
func set_profile(p_pid: String, p_name: String, p_avatar: int) -> void:
	pid = p_pid
	player_name = p_name if p_pid != "" else ""
	avatar = p_avatar if p_pid != "" else -1
	_sync_profile(true)


## True in a phase where the TV takes a profile change.
func can_change_profile() -> bool:
	return state == State.CONNECTED and phase in ["connect", "menu"]


## True when the TV has the same profile with another avatar or name (an edit while the phone was away or in a round). The TV
## may add a number to a name that another player has (`Sam 2`).
func _tv_differs() -> bool:
	if tv_avatar != avatar:
		return true
	var shown := tv_player_name.strip_edges().to_upper()
	var mine := player_name.strip_edges().to_upper()
	if shown == mine:
		return false
	return not (shown.begins_with(mine + " ") and shown.substr(mine.length() + 1).is_valid_int())


## Sends the profile when the TV has another one (or `force`), in a phase where the TV takes it.
func _sync_profile(force := false) -> void:
	if can_change_profile() and (force or tv_pid != pid or (pid != "" and _tv_differs())):
		var msg := {"t": "profile"}
		if pid != "":
			msg = {"t": "profile", "pid": pid, "name": player_name, "av": avatar}
		_send_json(msg)


func load_last() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(LAST_FILE) != OK:
		return {}
	return {
		"host": cfg.get_value("last", "host", ""), "port": cfg.get_value("last", "port", Protocol.WS_PORT),
		"room": cfg.get_value("last", "room", ""), "token": cfg.get_value("last", "token", ""),
	}


func use_saved_token(token: String) -> void:
	_token = token


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for entry in _closing.duplicate():
		entry.ws.poll()
		if entry.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED or now - int(entry.since) > 1500:
			_closing.erase(entry)
		elif not entry.closed and now - int(entry.since) >= 300:
			entry.ws.close() # Delayed: a close frame can drop the frames that came before it.
			entry.closed = true
	if _ws == null:
		if state == State.RECONNECTING and now >= _retry_at_ms:
			_open()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _open_started_ms > CONNECT_TIMEOUT_MS:
				_ws.close()
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING or (state == State.RECONNECTING):
				_set_state(State.JOINING)
				_last_rx_ms = now
				var hello := {"t": "hello", "v": Protocol.VERSION, "room": room, "token": _token, "name": player_name}
				if pin != "":
					hello["pin"] = pin
				if pid != "":
					hello["pid"] = pid
					hello["av"] = avatar
				_send_json(hello)
			while _ws.get_available_packet_count() > 0:
				var data := _ws.get_packet()
				_last_rx_ms = now
				if _ws.was_string_packet():
					_handle(Protocol.parse_json(data.get_string_from_utf8()), now)
				if _ws == null:
					return
			if state == State.CONNECTED:
				_tick_connected(now)
			elif state == State.JOINING and now - _last_rx_ms > Protocol.HELLO_TIMEOUT_MS:
				_ws.close()
		WebSocketPeer.STATE_CLOSED:
			# The last frames (for example "reject") can arrive together with the close.
			while _ws.get_available_packet_count() > 0:
				var last := _ws.get_packet()
				if _ws.was_string_packet():
					_handle(Protocol.parse_json(last.get_string_from_utf8()), now)
				if _ws == null:
					return
			_on_closed()


func _tick_connected(now: int) -> void:
	if now >= _next_ping_ms:
		_next_ping_ms = now + 1000
		_ping_id += 1
		_send_json({"t": "ping", "id": _ping_id, "t0": now})
	if now - _tx_window_ms >= 1000:
		tx_rate = _tx_count * 1000.0 / maxf(now - _tx_window_ms, 1.0)
		_tx_count = 0
		_tx_window_ms = now
	if now - _last_rx_ms > Protocol.PEER_TIMEOUT_MS:
		# The TV is silent. A close handshake of a half-open link never ends, so drop the socket and reconnect at once.
		_close_socket()
		_on_closed()


func _handle(msg: Dictionary, now: int) -> void:
	match msg.get("t", ""):
		"welcome":
			slot = int(msg.get("slot", -1))
			color = Color(String(msg.get("color", "#ffffff")))
			_token = String(msg.get("token", ""))
			tv_name = String(msg.get("name", "TV"))
			phase = String(msg.get("phase", "connect"))
			recenter_button = bool(msg.get("rc", true))
			tv_pid = String(msg.get("pid", ""))
			tv_avatar = int(msg.get("av", -1)) if tv_pid != "" else -1
			tv_player_name = String(msg.get("pname", ""))
			clear_score()   # The score comes again with the next frame of the game (REQ-FL-67).
			pin = ""
			_was_connected = true
			_attempt = 0
			_tx_window_ms = now
			_tx_count = 0
			_next_ping_ms = now
			_set_state(State.CONNECTED)
			_save_last(false)
			welcomed.emit(slot, color)
			if msg.has("lang"):
				language_changed.emit(String(msg.lang))
			phase_changed.emit(phase)
			_sync_profile()   # The TV may have ignored the profile (a round was running): send it again in a menu.
		"reject":
			var reason := String(msg.get("reason", "unknown"))
			_close_socket()
			_set_state(State.IDLE)
			rejected.emit(reason)
		"pong":
			var t0 := float(msg.get("t0", now))
			var t1 := float(msg.get("t1", now))
			var rtt := maxf(now - t0, 0.0)
			rtt_ms = rtt if rtt_ms < 0.0 else lerpf(rtt_ms, rtt, 0.3)
			clock_offset_ms = t1 - (t0 + now) * 0.5
			_send_json({"t": "stat", "rtt": snappedf(rtt_ms, 0.1),
					"off": snappedf(clock_offset_ms, 0.1), "hz": snappedf(tx_rate, 0.1)})
		"phase":
			phase = String(msg.get("v", "connect"))
			recenter_button = bool(msg.get("rc", true))
			if not phase in ["playing", "paused"]:
				clear_score()   # A pause keeps the score on the phone (REQ-FL-67).
			phase_changed.emit(phase)
			_sync_profile()
		"lang":
			language_changed.emit(String(msg.get("v", "en")))
		"haptic":
			haptic_requested.emit(int(msg.get("ms", 50)))
		"score":
			score_rank = clampi(int(msg.get("rank", 0)), 0, Protocol.MAX_PLAYERS)
			score_of = clampi(int(msg.get("of", 0)), 0, Protocol.MAX_PLAYERS)
			score_text = String(msg.get("v", "")).substr(0, 12)
			score_changed.emit()
		"turn":
			turn_state = clampi(int(msg.get("s", 0)), 0, 2)
			turn_who = String(msg.get("who", "")).substr(0, 20) if turn_state == 2 else ""
			turn_kind = "golf" if String(msg.get("k", "")) == "golf" else ""
			score_changed.emit()
		"result":
			# Only the profile that plays on this phone counts (the TV sends the ID of the slot).
			var key := String(msg.get("key", ""))
			var v: Variant = msg.get("v", 0)
			if pid != "" and String(msg.get("pid", "")) == pid and key != "" and (v is int or v is float):
				result_received.emit(key, int(v))
		"profile":
			tv_pid = String(msg.get("pid", ""))
			tv_avatar = int(msg.get("av", -1)) if tv_pid != "" else -1
			tv_player_name = String(msg.get("name", "")) if tv_pid != "" else ""
			profile_answered.emit()
		"kicked":
			# The host removed this phone, or another phone took its profile (`reason` "replaced"). Forget the token. Do not
			# reconnect (REQ-FL-33).
			var kicked_reason := "replaced" if String(msg.get("reason", "")) == "replaced" else "kicked"
			_close_socket()
			_token = ""
			slot = -1
			_was_connected = false
			_set_state(State.IDLE)
			_save_last(true)
			rejected.emit(kicked_reason)
		"bye":
			_close_socket()
			_set_state(State.IDLE)
			rejected.emit("tv_closed")


func _open() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url("ws://%s:%d" % [host, port])
	_open_started_ms = Time.get_ticks_msec()
	if err != OK:
		_ws = null
		_schedule_retry_or_give_up()
		return
	_set_state(State.RECONNECTING if _was_connected else State.CONNECTING)


func _on_closed() -> void:
	_ws = null
	if state == State.IDLE:
		return
	_schedule_retry_or_give_up()


func _schedule_retry_or_give_up() -> void:
	_attempt += 1
	if not _was_connected and _attempt >= GIVE_UP_AFTER:
		_set_state(State.IDLE)
		rejected.emit("unreachable")
		return
	var delay: float = RETRY_DELAYS[mini(_attempt - 1, RETRY_DELAYS.size() - 1)] \
			if _attempt <= RETRY_DELAYS.size() else 2.0
	_retry_at_ms = Time.get_ticks_msec() + int(delay * 1000.0)
	rtt_ms = -1.0
	_set_state(State.RECONNECTING)


func _close_socket() -> void:
	if _ws != null:
		_ws.poll()
		_closing.append({"ws": _ws, "since": Time.get_ticks_msec(), "closed": false})
		_ws = null


func _send_json(d: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(Protocol.to_json(d))


## Forgets the score: the phase changed or the TV is gone (REQ-FL-67).
func clear_score() -> void:
	if score_rank != 0 or score_of != 0 or score_text != "" or turn_state != 0:
		turn_state = 0
		turn_who = ""
		turn_kind = ""
		score_rank = 0
		score_of = 0
		score_text = ""
		score_changed.emit()


func _set_state(s: State) -> void:
	if s != state:
		state = s
		state_changed.emit(s)


func _save_last(clear_token: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("last", "host", host)
	cfg.set_value("last", "port", port)
	cfg.set_value("last", "room", room)
	cfg.set_value("last", "token", "" if clear_token else _token)
	cfg.save(LAST_FILE)
