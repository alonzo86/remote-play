extends Node
## TV side. Sends a UDP beacon once each second so phones can find the TV.

const Protocol = preload("res://scripts/core/protocol.gd")

var server: Node          # TvServer. Only used to read room code and player count.
var ip := ""

var _udp := PacketPeerUDP.new()
var _timer := 0.0


func _ready() -> void:
	_udp.set_broadcast_enabled(true)
	ip = Protocol.local_ipv4()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or server == null or not server.listening:
		return
	_timer = 1.0
	ip = Protocol.local_ipv4()
	var beacon := Protocol.to_json({
		"t": "beacon", "v": Protocol.VERSION, "room": server.room_code,
		"port": Protocol.WS_PORT, "name": server.tv_name,
		"players": server.player_count(), "max": Protocol.MAX_PLAYERS,
	}).to_utf8_buffer()
	var targets: Array[String] = ["255.255.255.255", "127.0.0.1"]
	var sub := Protocol.subnet_broadcast(ip)
	if sub != "":
		targets.append(sub)
	for t in targets:
		_udp.set_dest_address(t, Protocol.UDP_PORT)
		_udp.put_packet(beacon)
