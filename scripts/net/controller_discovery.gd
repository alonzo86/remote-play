extends Node
## Phone side. Listens for TV beacons on the UDP port.

const Protocol = preload("res://scripts/core/protocol.gd")

signal list_changed

const EXPIRE_MS := 4000
const PROBED_EXPIRE_MS := 20000   # A TV found by a probe (TvProber) has no beacon to keep it, so it lives longer.

## room code -> {room, ip, port, name, players, max, seen_ms}
var tvs: Dictionary = {}

var _udp := PacketPeerUDP.new()
var listening := false


func _ready() -> void:
	# IPv4 only: the beacon is an IPv4 broadcast, and a dual-stack socket (the "*" default) may not get it on some Android phones.
	var err := _udp.bind(Protocol.UDP_PORT, "0.0.0.0")
	listening = (err == OK)
	if err != OK:
		push_warning("ControllerDiscovery: cannot bind UDP port %d (error %d)" % [Protocol.UDP_PORT, err])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var changed := false
	while listening and _udp.get_available_packet_count() > 0:
		var data := _udp.get_packet()
		var from_ip := _udp.get_packet_ip()
		var msg := Protocol.parse_json(data.get_string_from_utf8())
		if msg.get("t", "") != "beacon" or int(msg.get("v", 0)) != Protocol.VERSION:
			continue
		var room := String(msg.get("room", ""))
		if room == "":
			continue
		if not tvs.has(room):
			changed = true
		tvs[room] = {
			"room": room, "ip": from_ip, "port": int(msg.get("port", Protocol.WS_PORT)),
			"name": String(msg.get("name", "TV")), "players": int(msg.get("players", 0)),
			"max": int(msg.get("max", Protocol.MAX_PLAYERS)), "seen_ms": now,
		}
	# Also without the beacon port (the bind failed): a TV that a scan found must still go when it is not found again.
	for room in tvs.keys():
		if now - int(tvs[room].seen_ms) > (PROBED_EXPIRE_MS if tvs[room].get("probed", false) else EXPIRE_MS):
			tvs.erase(room)
			changed = true
	if changed:
		list_changed.emit()


## A TV that a probe found (`TvProber.found`). A beacon of the same TV replaces it and keeps the list the same.
func add_probed(tv: Dictionary) -> void:
	var room := String(tv.room)
	var is_new := not tvs.has(room)
	if tvs.has(room) and not tvs[room].get("probed", false):
		tvs[room].seen_ms = Time.get_ticks_msec()   # The beacon works: nothing to add.
		return
	var entry := tv.duplicate()
	entry["seen_ms"] = Time.get_ticks_msec()
	entry["probed"] = true
	tvs[room] = entry
	if is_new:
		list_changed.emit()


## Forget every TV seen (the Refresh button). The next beacons fill the list again.
func forget_all() -> void:
	if not tvs.is_empty():
		tvs.clear()
		list_changed.emit()


func sorted_list() -> Array:
	var r: Array = tvs.values()
	r.sort_custom(func(a, b): return a.room < b.room)
	return r
