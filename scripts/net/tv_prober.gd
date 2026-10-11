extends Node
## Phone side. Finds TVs without the UDP beacon: some routers and some computers drop broadcast packets while a direct
## connection works (the QR code joins). It asks every address of the /24 network of the phone for a TV: a `hello` with a room
## that cannot exist, which the TV answers with `reject` / `bad_room` and its room code, name and player count
## (docs/PROTOCOL.md, "Probe"). It joins nothing. Each answer goes out as `found`.

const Protocol = preload("res://scripts/core/protocol.gd")

signal found(tv: Dictionary)
signal finished

const BATCH := 32            # Connections that are tried at the same time (a router can take a faster scan for an attack).
const PROBE_TIMEOUT_MS := 1500
const PROBE_ROOM := "-"      # Not a room code (the alphabet has no "-"), so the TV rejects it with `bad_room`.

var running := false

var _queue: Array[String] = []
var _active: Array = []   # {ws, ip, since, sent}


## Starts a scan of the /24 network of each address of `local_ips` (the phone's addresses). It does nothing while a scan runs.
func start(local_ips: Array) -> void:
	if running:
		return
	_queue = hosts_to_probe(local_ips)
	_active.clear()
	running = not _queue.is_empty()


## The addresses to ask: 1 to 254 of the /24 network of each address, without the address of the phone, each only once.
static func hosts_to_probe(local_ips: Array) -> Array[String]:
	var out: Array[String] = []
	for local_ip in local_ips:
		var parts := String(local_ip).split(".")
		if parts.size() != 4:
			continue
		for host in range(1, 255):
			var ip := "%s.%s.%s.%d" % [parts[0], parts[1], parts[2], host]
			if ip not in local_ips and ip not in out:
				out.append(ip)
	return out


func stop() -> void:
	for p in _active:
		p.ws.close()
	_active.clear()
	_queue.clear()
	running = false


func _process(_delta: float) -> void:
	if not running:
		return
	var now := Time.get_ticks_msec()
	while _active.size() < BATCH and not _queue.is_empty():
		var ip: String = _queue.pop_front()
		var ws := WebSocketPeer.new()
		if ws.connect_to_url("ws://%s:%d" % [ip, Protocol.WS_PORT]) == OK:
			_active.append({"ws": ws, "ip": ip, "since": now, "sent": false})
	for p in _active.duplicate():
		if _poll_probe(p, now):
			_active.erase(p)
	if _active.is_empty() and _queue.is_empty():
		running = false
		finished.emit()


## Returns true when this probe is over.
func _poll_probe(p: Dictionary, now: int) -> bool:
	var ws: WebSocketPeer = p.ws
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not p.sent:
				p.sent = true
				ws.send_text(Protocol.to_json({"t": "hello", "v": Protocol.VERSION, "room": PROBE_ROOM}))
			while ws.get_available_packet_count() > 0:
				var msg := Protocol.parse_json(ws.get_packet().get_string_from_utf8())
				var tv := tv_from_reject(msg, String(p.ip))
				if not tv.is_empty():
					found.emit(tv)
					ws.close()
					return true
		WebSocketPeer.STATE_CLOSED:
			return true
	if now - int(p.since) > PROBE_TIMEOUT_MS:
		ws.close()
		return true
	return false


## The TV that a probe answer describes, in the format of `ControllerDiscovery.tvs`, or an empty Dictionary when the message is
## not the answer of a TV.
static func tv_from_reject(msg: Dictionary, ip: String) -> Dictionary:
	if msg.get("t", "") != "reject" or msg.get("reason", "") != "bad_room" or String(msg.get("room", "")) == "":
		return {}
	return {"room": String(msg.room), "ip": ip, "port": Protocol.WS_PORT, "name": String(msg.get("name", "TV")),
			"players": int(msg.get("players", 0)), "max": int(msg.get("max", Protocol.MAX_PLAYERS))}
