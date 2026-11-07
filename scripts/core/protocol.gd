extends RefCounted
## Shared constants and packet codec for the TV and the controller.
## Message reference: docs/PROTOCOL.md

const VERSION := 5
const WS_PORT := 47801
const MAX_PLAYERS := 4
const SENSOR_HZ := 60
const SENSOR_PACKET_SIZE := 36
const PKT_SENSOR := 1
const SLOT_GRACE_MS := 5000    # A lost slot outside a paused game is freed after this (REQ-FL-8).
const PAUSED_SLOT_GRACE_MS := 300000   # A lost slot is kept this long while the game is paused for it (a phone call).
const HELLO_TIMEOUT_MS := 5000
const PENDING_KEEPALIVE_MS := 2000   # A waiting phone gets `pending` this often (under half of HELLO_TIMEOUT_MS).
const PEER_TIMEOUT_MS := 3000
const ROOM_ALPHABET := "ACDEFGHJKLMNPQRTUVWXYZ"
const ROOM_LENGTH := 4                 # Letters of a room code.
const ROOM_MULTIPLIER := 40503         # The scramble of a room code: a multiplication modulo 65536 (odd, so reversible).
const ROOM_MULTIPLIER_INVERSE := 30599 # ROOM_MULTIPLIER * ROOM_MULTIPLIER_INVERSE = 1 modulo 65536.
const NAME_MAX := 10                   # The longest player name, on the phone, on the TV and in a code (FD-22).
const AVATAR_COUNT := 32               # Avatars in the sprite sheet (assets/avatars/avatars.png).
const REPLACED_TOKEN_MS := 600000      # The TV remembers the token of a replaced phone this long (docs/PROTOCOL.md).

## Every message of the JSON protocol: the value `"t"` -> who sends it (`"phone"`, `"tv"` or `"both"`). The net code writes the
## names as literals; tests/protocol_doc.gd checks that this table, the literals of scripts/net/ and the tables of
## docs/PROTOCOL.md agree, and that the numbers above are the ones the document quotes (issue #296). A new message: add it here
## and to the document, in the same change (skill `change-protocol`).
const MESSAGES := {
	"hello": "phone", "welcome": "tv", "reject": "tv",
	"ping": "phone", "pong": "tv", "stat": "phone", "recenter": "phone",
	"phase": "tv", "lang": "tv", "haptic": "tv", "score": "tv", "turn": "tv",
	"setup": "tv", "play": "phone", "swing_ok": "phone",
	"profile": "both", "result": "tv", "bye": "both", "kicked": "tv", "pending": "tv",
}

## `lang` and `welcome.lang` are still sent, but the phone ignores them (issue #171). Remove both at the next VERSION bump,
## which is an incompatible change anyway. tests/protocol_doc.gd fails when VERSION is above this number and `lang` is still in
## MESSAGES.
const LANG_REMOVE_AFTER_VERSION := 5

const BTN_A := 1
const BTN_B := 2
const FLAG_TOUCH := 1

const PLAYER_COLORS: Array[Color] = [
	Color("3dcef2"), # cyan
	Color("cc7e0a"), # orange
	Color("aa3df2"), # purple
	Color("f20c68"), # pink
]


## The room code of a TV with the address `ip`: the last two numbers of the address (16 bits) multiplied by ROOM_MULTIPLIER
## modulo 65536 (so that the codes of one network do not all look alike), written as ROOM_LENGTH letters. An empty text when
## `ip` is not an IPv4 address (docs/PROTOCOL.md, "Room code").
static func room_code_for_ip(ip: String) -> String:
	if not is_ipv4(ip):
		return ""
	var parts := ip.split(".")
	var n := ((int(parts[2]) << 8) | int(parts[3])) * ROOM_MULTIPLIER % 65536
	var code := ""
	for i in ROOM_LENGTH:
		code = ROOM_ALPHABET[n % ROOM_ALPHABET.length()] + code
		n /= ROOM_ALPHABET.length()
	return code


## What a player types, as a room code: no spaces, upper case.
static func clean_room_code(text: String) -> String:
	return text.replace(" ", "").strip_edges().to_upper()


## The last two numbers of the TV address that a room code holds, as `third * 256 + fourth`; -1 when `code` is not a room code
## (a wrong length, a letter that is not in the alphabet, or a value above 65535).
static func decode_room_code(code: String) -> int:
	var c := clean_room_code(code)
	if c.length() != ROOM_LENGTH:
		return -1
	var n := 0
	for ch in c:
		var d := ROOM_ALPHABET.find(ch)
		if d < 0:
			return -1
		n = n * ROOM_ALPHABET.length() + d
	if n > 65535:
		return -1
	return n * ROOM_MULTIPLIER_INVERSE % 65536


## The addresses where the TV of `code` can be, for a phone that has the addresses `own` (it keeps the first two numbers of each
## and takes the last two from the code). Empty when the code is not valid or the phone has no private address.
static func hosts_for_code(code: String, own: Array) -> Array[String]:
	var v := decode_room_code(code)
	var out: Array[String] = []
	if v < 0:
		return out
	for a in own:
		var parts := String(a).split(".")
		if parts.size() != 4:
			continue
		var host := "%s.%s.%d.%d" % [parts[0], parts[1], v >> 8, v & 255]
		if not out.has(host):
			out.append(host)
	return out


static func make_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()   # 32 hex characters from the system random source (issue #388).


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


## A gyro (rad/s) or accel (m/s2) value above this is not physical (a phone sensor stays below about 35 rad/s and 160 m/s2).
const SENSOR_MAX_ABS := 1000.0


## Returns an empty Dictionary when the packet is not a valid sensor packet (a wrong size or type, a NaN or INF float, or a
## value above `SENSOR_MAX_ABS`).
static func decode_sensor(b: PackedByteArray) -> Dictionary:
	if b.size() != SENSOR_PACKET_SIZE or b.decode_u8(0) != PKT_SENSOR:
		return {}
	for at in [8, 12, 16, 20, 24, 28]:
		var v := b.decode_float(at)
		if not is_finite(v) or absf(v) > SENSOR_MAX_ABS:
			return {}   # NaN, INF or a huge value would go into the orientation state (issue #388).
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
## It does not print an error: any device on the Wi-Fi can send text to the TV port.
static func parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


## Typed readers for the fields of a parsed frame. Any device on the Wi-Fi can send any value, so a handler never casts a field
## itself (`float()`, `int()`, `String()` and `bool()` raise a script error for an Array or a Dictionary). A value of another
## type gives `default`. A number must be finite. A boolean is not a number.
static func num(msg: Dictionary, key: String, default: float = 0.0) -> float:
	var v: Variant = msg.get(key, default)
	if (v is int or v is float) and is_finite(float(v)):
		return float(v)
	return default


## `num` for an integer field.
static func whole(msg: Dictionary, key: String, default: int = 0) -> int:
	var v: Variant = msg.get(key, default)
	if v is int:
		return v
	if v is float and is_finite(v) and absf(v) < 1.0e15:
		return int(v)
	return default


static func text(msg: Dictionary, key: String, default: String = "") -> String:
	var v: Variant = msg.get(key, default)
	return v if v is String else default


static func flag(msg: Dictionary, key: String, default: bool = false) -> bool:
	var v: Variant = msg.get(key, default)
	return v if v is bool else default


static func to_json(d: Dictionary) -> String:
	return JSON.stringify(d)


## Pick the most likely LAN IPv4 address of this device: the first address of the best private kind (see `best_private`),
## or an empty text when there is none. A test gives its own list.
static func local_ipv4(addresses: Array = IP.get_local_addresses()) -> String:
	var best := best_private(addresses)
	return best[0] if not best.is_empty() else ""


## The private IPv4 addresses of this device that are of the best kind (`192.168.x.x`, else `10.x.x.x`, else `172.16.x.x` to
## `172.31.x.x`, the order of `local_ipv4()`). A phone can have a Wi-Fi address and a mobile-data address of another kind: only
## the best kind is used, so a scan does not go into the network of the mobile provider.
static func private_ipv4s() -> Array[String]:
	return best_private(IP.get_local_addresses())


## The addresses of `addresses` of the best private kind (a test gives its own list).
static func best_private(addresses: Array) -> Array[String]:
	var best_rank := 99
	var out: Array[String] = []
	for a in addresses:
		var rank := _private_rank(String(a))
		if rank < best_rank:
			best_rank = rank
			out.clear()
		if rank == best_rank and rank < 99:
			out.append(String(a))
	return out


## 0 for `192.168.x.x`, 1 for `10.x.x.x`, 2 for `172.16.x.x` to `172.31.x.x`, else 99.
static func _private_rank(a: String) -> int:
	var parts := a.split(".")
	if parts.size() != 4:
		return 99
	if a.begins_with("192.168."):
		return 0
	if a.begins_with("10."):
		return 1
	return 2 if parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31 else 99


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
