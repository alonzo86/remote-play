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
var player_name := ""

var host := ""
var port := Protocol.WS_PORT
var room := ""

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


func connect_to(p_host: String, p_port: int, p_room: String) -> void:
	_close_socket()
	host = p_host
	port = p_port
	room = p_room.to_upper()
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
	_was_connected = false
	_set_state(State.IDLE)
	_save_last(true)


func is_connected_to_tv() -> bool:
	return state == State.CONNECTED


func send_sensor(packet: PackedByteArray) -> void:
	if state != State.CONNECTED:
		return
	_ws.send(packet, WebSocketPeer.WRITE_MODE_BINARY)
	_tx_count += 1


func send_recenter() -> void:
	_send_json({"t": "recenter"})


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
				_send_json({"t": "hello", "v": Protocol.VERSION, "room": room,
						"token": _token, "name": player_name})
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
		_ws.close() # The TV is silent. Reconnect.


func _handle(msg: Dictionary, now: int) -> void:
	match msg.get("t", ""):
		"welcome":
			slot = int(msg.get("slot", -1))
			color = Color(String(msg.get("color", "#ffffff")))
			_token = String(msg.get("token", ""))
			tv_name = String(msg.get("name", "TV"))
			phase = String(msg.get("phase", "connect"))
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
			phase_changed.emit(phase)
		"lang":
			language_changed.emit(String(msg.get("v", "en")))
		"haptic":
			haptic_requested.emit(int(msg.get("ms", 50)))
		"kicked":
			# The host removed this phone. Forget the token. Do not reconnect (REQ-FL-33).
			_close_socket()
			_token = ""
			slot = -1
			_was_connected = false
			_set_state(State.IDLE)
			_save_last(true)
			rejected.emit("kicked")
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
