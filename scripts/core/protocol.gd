extends RefCounted
## Shared constants and packet codec for the TV and the controller.
## Message reference: docs/PROTOCOL.md

const VERSION := 2
const UDP_PORT := 47800
const WS_PORT := 47801
const MAX_PLAYERS := 4
const SENSOR_HZ := 60
const SENSOR_PACKET_SIZE := 36
const PKT_SENSOR := 1
const SLOT_GRACE_MS := 30000
const PAUSED_SLOT_GRACE_MS := 300000   # A lost slot is kept this long while the game is paused for it (a phone call).
const HELLO_TIMEOUT_MS := 5000
const PEER_TIMEOUT_MS := 5000
const ROOM_ALPHABET := "ACDEFGHJKLMNPQRTUVWXYZ"
const NAME_MAX := 10                   # The longest player name, on the phone, on the TV and in a code (FD-22).
const AVATAR_COUNT := 32               # Avatars in the sprite sheet (assets/avatars/avatars.png).
const REPLACED_TOKEN_MS := 600000      # The TV remembers the token of a replaced phone this long (docs/PROTOCOL.md).

const BTN_A := 1
const BTN_B := 2
const FLAG_TOUCH := 1

const PLAYER_COLORS: Array[Color] = [
	Color("e63946"), # red
	Color("2a9d8f"), # teal
	Color("f4a261"), # orange
	Color("457b9d"), # blue
]


static func make_room_code() -> String:
	var code := ""
	for i in 4:
		code += ROOM_ALPHABET[randi() % ROOM_ALPHABET.length()]
	return code


static func make_token() -> String:
	return "%08x%08x" % [randi(), randi()]


## Pack one sensor sample. Little-endian. Layout: docs/PROTOCOL.md.
static func encode_sensor(seq: int, ts_ms: int, gyro: Vector3, accel: Vector3,
		buttons: int, flags: int, touch: Vector2) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(SENSOR_PACKET_SIZE)
	b.encode_u8(0, PKT_SENSOR)
	b.encode_u8(1, flags & 0xFF)
	b.encode_u16(2, seq & 0xFFFF)
	b.encode_u32(4, ts_ms & 0xFFFFFFFF)
	b.encode_float(8, gyro.x)
	b.encode_float(12, gyro.y)
	b.encode_float(16, gyro.z)
	b.encode_float(20, accel.x)
	b.encode_float(24, accel.y)
	b.encode_float(28, accel.z)
	b.encode_u8(32, buttons & 0xFF)
	b.encode_u8(33, 0)
	b.encode_u8(34, clampi(roundi(touch.x * 255.0), 0, 255))
	b.encode_u8(35, clampi(roundi(touch.y * 255.0), 0, 255))
	return b


## Returns an empty Dictionary when the packet is not a valid sensor packet.
static func decode_sensor(b: PackedByteArray) -> Dictionary:
	if b.size() != SENSOR_PACKET_SIZE or b.decode_u8(0) != PKT_SENSOR:
		return {}
	var flags := b.decode_u8(1)
	return {
		"flags": flags,
		"seq": b.decode_u16(2),
		"ts": b.decode_u32(4),
		"gyro": Vector3(b.decode_float(8), b.decode_float(12), b.decode_float(16)),
		"accel": Vector3(b.decode_float(20), b.decode_float(24), b.decode_float(28)),
		"buttons": b.decode_u8(32),
		"touching": (flags & FLAG_TOUCH) != 0,
		"touch": Vector2(b.decode_u8(34) / 255.0, b.decode_u8(35) / 255.0),
	}


## Parse a JSON text frame. Returns an empty Dictionary on error, and when the JSON is not an object.
## It does not print an error: any device on the Wi-Fi can send text to the beacon port.
static func parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


static func to_json(d: Dictionary) -> String:
	return JSON.stringify(d)


## Pick the most likely LAN IPv4 address of this device.
static func local_ipv4() -> String:
	var best := ""
	var best_rank := 99
	for a in IP.get_local_addresses():
		var parts := String(a).split(".")
		if parts.size() != 4:
			continue
		var rank := 99
		if a.begins_with("192.168."):
			rank = 0
		elif a.begins_with("10."):
			rank = 1
		else:
			var second := int(parts[1])
			if parts[0] == "172" and second >= 16 and second <= 31:
				rank = 2
		if rank < best_rank:
			best_rank = rank
			best = a
	return best


## Every private IPv4 address of this device (a phone can have a Wi-Fi address and a mobile one that look alike).
static func private_ipv4s() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		var parts := String(a).split(".")
		if parts.size() != 4:
			continue
		var second := int(parts[1])
		if a.begins_with("192.168.") or a.begins_with("10.") or (parts[0] == "172" and second >= 16 and second <= 31):
			out.append(String(a))
	return out


## Assume a /24 network. Good enough for home Wi-Fi.
static func subnet_broadcast(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


static func pair_url(ip: String, room: String) -> String:
	return "ws://%s:%d/%s" % [ip, WS_PORT, room]


## Parse the text of the TV QR code: ws://IP:PORT/ROOM.
## Returns {host, port, room}, or an empty Dictionary when the text is not valid.
static func parse_pair_url(text: String) -> Dictionary:
	var t := text.strip_edges()
	if not t.begins_with("ws://"):
		return {}
	var rest := t.substr(5)
	var slash := rest.find("/")
	var hostport := rest if slash < 0 else rest.substr(0, slash)
	var room := "" if slash < 0 else rest.substr(slash + 1).to_upper()
	var parts := hostport.split(":")
	if parts.size() != 2 or not is_ipv4(parts[0]) or not parts[1].is_valid_int():
		return {}
	var port := int(parts[1])
	if port < 1 or port > 65535:
		return {}
	if room.length() != 4 and room != "":
		return {}
	for ch in room:
		if not ROOM_ALPHABET.contains(ch):
			return {}
	return {"host": parts[0], "port": port, "room": room}


static func is_ipv4(s: String) -> bool:
	var parts := s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return false
	return true
