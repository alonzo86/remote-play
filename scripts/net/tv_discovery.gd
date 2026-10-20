extends Node
## TV side. Sends a UDP beacon once each second so phones can find the TV.

const Protocol = preload("res://scripts/core/protocol.gd")

var server: Node          # TvServer. Only used to read room code and player count.
var ip := ""
## Finds the address of this device. A test sets another one (an empty text is a device with no network).
var address_lookup: Callable = Protocol.local_ipv4

var _udp := PacketPeerUDP.new()
var _timer := 0.0


func _ready() -> void:
	_udp.set_broadcast_enabled(true)
	ip = address_lookup.call()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or server == null or not server.listening:
		return
	_timer = 1.0
	ip = address_lookup.call()
	var beacon := Protocol.to_json({
		"t": "beacon", "v": Protocol.VERSION, "room": server.room_code,
		"port": server.port, "name": server.tv_name,
		"players": server.player_count(), "max": Protocol.MAX_PLAYERS,
	}).to_utf8_buffer()
	var targets: Array[String] = ["255.255.255.255", "127.0.0.1"]
	var sub := Protocol.subnet_broadcast(ip)
	if sub != "":
		targets.append(sub)
	for t in targets:
		_udp.set_dest_address(t, Protocol.UDP_PORT)
		_udp.put_packet(beacon)
