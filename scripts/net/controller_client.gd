extends Node
## Phone side. WebSocket client with automatic reconnect and latency measurement.
## It does not know about screens or sensors. Other scripts call send_sensor().

const Protocol = preload("res://scripts/core/protocol.gd")
const ConfigIO = preload("res://scripts/core/config_io.gd")
const ClosingSockets = preload("res://scripts/net/closing_sockets.gd")

signal state_changed(state: int)
signal welcomed(slot: int, color: Color)
signal rejected(reason: String)
signal phase_changed(phase: String)
signal haptic_requested(ms: int)
signal score_changed()   # The place or the score of this phone changed (REQ-FL-67).
signal result_received(key: String, value: int)   # A round result for the active profile (REQ-GM-99).
signal setup_changed()   # The safety card of a swing game opened or closed (issue #79).
signal profile_answered()   # The TV told which profile this phone has now (REQ-FL-70).

## WAITING is last, so the numbers of the other states do not change. The TV has the `hello` and waits for its host (`pending`).
enum State { IDLE, CONNECTING, JOINING, CONNECTED, RECONNECTING, WAITING }

const LAST_FILE := "user://controller.cfg"
const FINAL_MAX := 60   # The longest line of the result that the phone keeps (REQ-FL-67a).
const RETRY_DELAYS := [0.5, 1.0, 2.0]
const CONNECT_TIMEOUT_MS := 4000
const GIVE_UP_AFTER := 3   # Failed first attempts before "unreachable".
const QUICK_GIVE_UP_AFTER := 1
const QUICK_CONNECT_TIMEOUT_MS := 2000

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
var pad_buttons := "ab"       # The buttons the pad shows: "", "a", "b" or "ab" (REQ-GM-37a).
var setup_swing := false      # The TV settings view of a swing game is open: the phone shows the safety card (REQ-GM-102).
var setup_pick := false       # Two or more phones are connected: the phone asks "play this game?" (issue #76, REQ-GM-104).
var setup_open := false       # The TV settings view of a game is open: the waiting screen says so.
var setup_in := true          # This phone plays the game (the choice IN); the TV sets it back to IN when it refuses the last OUT.
var sat_out := false          # The round that runs began with this phone OUT: the waiting screen says so (issue #242).
var swing_acked := false      # The player tapped OK for the settings view that is open; the next view asks again (issue #148).
var turn_state := 0           # 0 no turn line, 1 this phone is on turn, 2 another player is on turn (REQ-BW-14).
var turn_kind := ""           # "" for the words of Bowling, "golf" for Mini Golf.
var turn_who := ""            # The name of the player on turn when turn_state is 2.
var final_text := ""          # The line of this phone in the result, as the TV shows it. Empty outside a result (REQ-FL-67a).
var score_text := ""         # The score as the TV shows it. Empty when there is no score yet.

var host := ""
var port := Protocol.WS_PORT
var room := ""
var give_up_after := GIVE_UP_AFTER   # Failed first attempts before "unreachable" (the join by a typed code makes it 1).
var connect_timeout_ms := CONNECT_TIMEOUT_MS

var _ws: WebSocketPeer
var _closing := ClosingSockets.new()   # Closed sockets that still flush their last frames.
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


## `quick` is for a guess of the address (a typed room code): one try with a short timeout, so a wrong code fails fast.
func connect_to(p_host: String, p_port: int, p_room: String, quick := false) -> void:
	_close_socket()
	host = p_host
	port = p_port
	room = p_room.to_upper()
	give_up_after = QUICK_GIVE_UP_AFTER if quick else GIVE_UP_AFTER
	connect_timeout_ms = QUICK_CONNECT_TIMEOUT_MS if quick else CONNECT_TIMEOUT_MS
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


## The player cancels the wait for the host (REQ-FL-100): the TV is told, the socket closes, and no message shows. Nothing happens
## in another state.
func cancel_wait() -> void:
	if state != State.WAITING:
		return
	leave()


func send_sensor(packet: PackedByteArray) -> void:
	if state != State.CONNECTED or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send(packet, WebSocketPeer.WRITE_MODE_BINARY)
	_tx_count += 1


func send_recenter() -> void:
	_send_json({"t": "recenter"})


## The pause button and Back of the pad ask the TV to do what Back on the TV remote does in a game: pause and ask "End the game?"
## (REQ-FL-52c, REQ-GM-31a). Only while the phone is connected and the game plays; the TV decides.
func send_leave_ask() -> void:
	if state == State.CONNECTED and phase == "playing":
		_send_json({"t": "leave_ask"})


## The player chose IN (`true`) or OUT for the game of the settings view (issue #76). The TV answers with `setup` and the
## choice it accepted.
func send_play(value: bool) -> void:
	setup_in = value
	_send_json({"t": "play", "v": value})
	setup_changed.emit()


## The player tapped OK on the safety card of a swing game (issue #79): tell the TV, and do not show the card again for this view.
func send_swing_ok() -> void:
	swing_acked = true
	_send_json({"t": "swing_ok"})
	setup_changed.emit()


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


## The saved TV. A value of the wrong type is the default, and the port is 1 to 65535 (issue #309).
func load_last(path := LAST_FILE) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	var p: int = ConfigIO.fit(cfg.get_value("last", "port", Protocol.WS_PORT), Protocol.WS_PORT)
	return {
		"host": ConfigIO.fit(cfg.get_value("last", "host", ""), ""),
		"port": p if p >= 1 and p <= 65535 else Protocol.WS_PORT,
		"room": ConfigIO.fit(cfg.get_value("last", "room", ""), ""),
		"token": ConfigIO.fit(cfg.get_value("last", "token", ""), ""),
	}


func use_saved_token(token: String) -> void:
	_token = token


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	_closing.service(now)
	if _ws == null:
		if state == State.RECONNECTING and now >= _retry_at_ms:
			_open()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _open_started_ms > connect_timeout_ms:
				_ws.close()
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING or (state == State.RECONNECTING):
				_set_state(State.JOINING)
				_last_rx_ms = now
				var hello := {"t": "hello", "v": Protocol.VERSION, "room": room, "token": _token, "name": player_name}
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
			elif state == State.WAITING and now - _last_rx_ms > Protocol.HELLO_TIMEOUT_MS:
				_end_wait()   # The TV sent no `pending` for 5 s: the link is lost. No retry (a retry would queue again).
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
	match Protocol.text(msg, "t"):
		"welcome":
			slot = Protocol.whole(msg, "slot", -1)
			color = Color(Protocol.text(msg, "color", "#ffffff"))
			_token = Protocol.text(msg, "token", "")
			tv_name = Protocol.text(msg, "name", "TV")
			sat_out = false
			swing_acked = false   # A new session (another TV or slot) never inherits an earlier answer (issue #148).
			phase = Protocol.text(msg, "phase", "connect")
			recenter_button = Protocol.flag(msg, "rc", true)
			pad_buttons = Protocol.text(msg, "ab", "ab")
			tv_pid = Protocol.text(msg, "pid", "")
			tv_avatar = Protocol.whole(msg, "av", -1) if tv_pid != "" else -1
			tv_player_name = Protocol.text(msg, "pname", "")
			clear_score()   # The score comes again with the next frame of the game (REQ-FL-67).
			clear_final()   # The TV sends it again when the result is open (REQ-FL-67a).
			_was_connected = true
			connect_timeout_ms = CONNECT_TIMEOUT_MS   # A reconnect on a weak Wi-Fi gets the long timeout.
			_attempt = 0
			_tx_window_ms = now
			_tx_count = 0
			_next_ping_ms = now
			_set_state(State.CONNECTED)
			_save_last(false)
			welcomed.emit(slot, color)
			# `lang` (the TV language) is ignored: a phone has its own language (REQ-FL-62).
			phase_changed.emit(phase)
			_sync_profile()   # The TV may have ignored the profile (a round was running): send it again in a menu.
		"pending":
			# The TV has the `hello` and waits for its host. Nothing is sent; the frames show that the TV is alive.
			if state == State.JOINING or state == State.WAITING:
				_set_state(State.WAITING)
		"reject":
			var reason := Protocol.text(msg, "reason", "unknown")
			_close_socket()
			_set_state(State.IDLE)
			rejected.emit(reason)
		"pong":
			var t0 := Protocol.num(msg, "t0", now)
			var t1 := Protocol.num(msg, "t1", now)
			var rtt := maxf(now - t0, 0.0)
			rtt_ms = rtt if rtt_ms < 0.0 else lerpf(rtt_ms, rtt, 0.3)
			clock_offset_ms = t1 - (t0 + now) * 0.5
			_send_json({"t": "stat", "rtt": snappedf(rtt_ms, 0.1),
					"off": snappedf(clock_offset_ms, 0.1), "hz": snappedf(tx_rate, 0.1)})
		"phase":
			var was_phase := phase
			phase = Protocol.text(msg, "v", "connect")
			recenter_button = Protocol.flag(msg, "rc", true)
			pad_buttons = Protocol.text(msg, "ab", "ab")
			setup_open = false
			var was_out := setup_pick and not setup_in   # The view closes with this phone OUT (REQ-GM-104).
			sat_out = (sat_out or was_out) if phase == "waiting" else false
			if setup_swing or setup_pick:
				setup_swing = false
				setup_pick = false
				swing_acked = false   # The next settings view of a swing game asks again (REQ-GM-102, issue #148).
				setup_in = true
				setup_changed.emit()
			if not phase in ["playing", "paused"]:
				clear_score()   # A pause keeps the score on the phone (REQ-FL-67).
			if phase != "paused" and was_phase != "paused":
				clear_final()   # A new round ends the result line; a pause and its resume keep it (REQ-FL-67a).
			phase_changed.emit(phase)
			_sync_profile()
		"setup":
			setup_open = true
			setup_swing = Protocol.flag(msg, "swing", false)
			setup_pick = Protocol.flag(msg, "pick", false)
			setup_in = Protocol.flag(msg, "in", true)
			if setup_swing and swing_acked:
				send_swing_ok()   # The same view is synced again (a phone joined): this phone has answered already.
			setup_changed.emit()
		"lang":
			pass   # The TV language: a phone does not follow it (REQ-FL-62, issue #171).
		"haptic":
			haptic_requested.emit(Protocol.whole(msg, "ms", 50))
		"score":
			score_rank = clampi(Protocol.whole(msg, "rank", 0), 0, Protocol.MAX_PLAYERS)
			score_of = clampi(Protocol.whole(msg, "of", 0), 0, Protocol.MAX_PLAYERS)
			score_text = Protocol.text(msg, "v", "").substr(0, 12)
			score_changed.emit()
		"final":
			final_text = Protocol.text(msg, "v", "").substr(0, FINAL_MAX)
			score_changed.emit()
		"turn":
			turn_state = clampi(Protocol.whole(msg, "s", 0), 0, 2)
			turn_who = Protocol.text(msg, "who", "").substr(0, 20) if turn_state == 2 else ""
			turn_kind = "golf" if Protocol.text(msg, "k", "") == "golf" else ""
			score_changed.emit()
		"result":
			# Only the profile that plays on this phone counts (the TV sends the ID of the slot).
			var key := Protocol.text(msg, "key", "")
			var v: Variant = msg.get("v", 0)
			if pid != "" and Protocol.text(msg, "pid", "") == pid and key != "" and (v is int or v is float):
				result_received.emit(key, int(v))
		"profile":
			tv_pid = Protocol.text(msg, "pid", "")
			tv_avatar = Protocol.whole(msg, "av", -1) if tv_pid != "" else -1
			tv_player_name = Protocol.text(msg, "name", "") if tv_pid != "" else ""
			profile_answered.emit()
		"kicked":
			# The host removed this phone, or another phone took its profile (`reason` "replaced"). Forget the token. Do not
			# reconnect (REQ-FL-33).
			var kicked_reason := Protocol.text(msg, "reason", "")
			if not kicked_reason in ["replaced", "refused", "timeout", "busy"]:
				kicked_reason = "kicked"
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
	if state == State.WAITING:
		_end_wait()   # The TV closed the socket with no message while the phone waited: no retry.
		return
	_schedule_retry_or_give_up()


## The wait for the host ended because the link is lost: back to IDLE with the reason `wait_lost`, and no retry (FD-30.13).
func _end_wait() -> void:
	_close_socket()
	_set_state(State.IDLE)
	rejected.emit("wait_lost")


func _schedule_retry_or_give_up() -> void:
	_attempt += 1
	if not _was_connected and _attempt >= give_up_after:
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
		_closing.add(_ws, Time.get_ticks_msec())
		_ws = null


func _send_json(d: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(Protocol.to_json(d))


## Forgets the line of the result (REQ-FL-67a).
func clear_final() -> void:
	if final_text != "":
		final_text = ""
		score_changed.emit()


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


func _save_last(clear_token: bool, path := LAST_FILE) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("last", "host", host)
	cfg.set_value("last", "port", port)
	cfg.set_value("last", "room", room)
	cfg.set_value("last", "token", "" if clear_token else _token)
	return ConfigIO.save(cfg, path)
