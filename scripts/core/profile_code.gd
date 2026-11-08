extends RefCounted
## The text of a player profile for the copy to another phone (FD-22, docs/PROFILES_PLAN.md 6): `WP1.` and base64url of the
## binary data: format version, 16 bytes of ID, avatar, rev (varint), name (length and UTF-8 bytes), the bests (a number of
## `ProfileKeys` and a varint for each) and a CRC-16. A QR code carries the same text, and COPY CODE and IMPORT (a scan) use it.

const Profile = preload("res://scripts/core/profile.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")

const PREFIX := "WP1."
## Version 1 carries up to 39 bests (numbers 1 to 39). Version 2 carries up to 42 (Bowling, numbers 40 to 42). Version 3 carries
## up to 48 (Whack-a-Mole 43 to 45 and Tennis 46 to 48). A profile is written with the lowest version that holds its bests, so an
## older app reads it when it can. All versions have the same layout, and this app reads all of them.
const FORMAT_VERSION := 1
const FORMAT_VERSION_2 := 2
const FORMAT_VERSION_3 := 3
const MAX_KEYS_V1 := 39
const MAX_KEYS_V2 := 42
const NAME_BYTES_MAX := 20
const VALUE_MAX := 4000000000
const REASON_BAD := "This code does not work"


## The code of a profile. Bests with a key that the table does not know, or a value out of range, are left out.
static func encode(p: RefCounted) -> String:
	var b := PackedByteArray()
	b.append(FORMAT_VERSION)   # Raised below when a best has a number above 39 or 42.
	b.append_array(p.id.hex_decode())
	b.append(clampi(p.avatar, 0, 255))
	_put_varint(b, p.rev)
	var name_bytes := Profile.clean_name(p.player_name).to_utf8_buffer()
	b.append(name_bytes.size())
	b.append_array(name_bytes)
	var numbers: Array[int] = []
	for key in p.bests:
		var n := ProfileKeys.number_of(String(key))
		var v := int(p.bests[key])
		if n > 0 and v > 0 and v <= VALUE_MAX:
			numbers.append(n)
	numbers.sort()
	if not numbers.is_empty():
		var top: int = numbers[numbers.size() - 1]
		if top > MAX_KEYS_V2:
			b[0] = FORMAT_VERSION_3
		elif top > MAX_KEYS_V1:
			b[0] = FORMAT_VERSION_2
	b.append(numbers.size())
	for n in numbers:
		b.append(n)
		_put_varint(b, int(p.bests[ProfileKeys.key_of(n)]))
	var crc := crc16(b)
	b.append(crc >> 8)
	b.append(crc & 0xFF)
	return PREFIX + Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")


## Reads a code. Returns {"ok": true, "profile": Profile} or {"ok": false, "reason": text}. The name and the bests go through
## the same rules as typed or sent ones: the name is cleaned and cut, an unknown key or a value out of range is skipped, a key
## twice or any break of the format refuses the whole code.
static func decode(text: String) -> Dictionary:
	var t := text.strip_edges()
	if not t.begins_with(PREFIX):
		return _fail()
	var b64 := t.substr(PREFIX.length()).replace("-", "+").replace("_", "/")
	for c in b64:
		if not (c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"):
			return _fail()
	while b64.length() % 4 != 0:
		b64 += "="
	var b := Marshalls.base64_to_raw(b64)
	if b.size() < 1 + 16 + 1 + 1 + 1 + 1 + 2 or b.size() > 400:
		return _fail()
	var crc := crc16(b.slice(0, b.size() - 2))
	if b[b.size() - 2] != (crc >> 8) or b[b.size() - 1] != (crc & 0xFF):
		return _fail()
	var body := b.slice(0, b.size() - 2)
	if body[0] < FORMAT_VERSION or body[0] > FORMAT_VERSION_3:
		return _fail()
	var pos := [17]   # A position that the readers move.
	var p = Profile.new()
	p.id = body.slice(1, 17).hex_encode()
	p.avatar = body[pos[0]]
	pos[0] += 1
	var rev := _get_varint(body, pos)
	if rev < 0:
		return _fail()
	p.rev = rev
	if pos[0] >= body.size():
		return _fail()
	var name_len: int = body[pos[0]]
	pos[0] += 1
	if name_len > NAME_BYTES_MAX or pos[0] + name_len >= body.size():
		return _fail()
	p.player_name = Profile.clean_name(body.slice(pos[0], pos[0] + name_len).get_string_from_utf8())
	pos[0] += name_len
	var k: int = body[pos[0]]
	pos[0] += 1
	if k > ProfileKeys.MAX_KEYS or (body[0] == FORMAT_VERSION and k > MAX_KEYS_V1) \
			or (body[0] == FORMAT_VERSION_2 and k > MAX_KEYS_V2):
		return _fail()
	var seen := {}
	for i in k:
		if pos[0] >= body.size():
			return _fail()
		var n: int = body[pos[0]]
		pos[0] += 1
		var v := _get_varint(body, pos)
		if v < 0 or seen.has(n):
			return _fail()
		seen[n] = true
		var key := ProfileKeys.key_of(n)
		if key != "" and v > 0 and v <= VALUE_MAX:
			p.bests[key] = v
	if pos[0] != body.size() or not p.is_valid():
		return _fail()
	return {"ok": true, "profile": p}


static func _fail() -> Dictionary:
	return {"ok": false, "reason": REASON_BAD}


## CRC-16/CCITT-FALSE (polynomial 0x1021, start value 0xFFFF).
static func crc16(data: PackedByteArray) -> int:
	var crc := 0xFFFF
	for byte in data:
		crc ^= byte << 8
		for i in 8:
			crc = ((crc << 1) ^ 0x1021) if (crc & 0x8000) != 0 else (crc << 1)
			crc &= 0xFFFF
	return crc


static func _put_varint(b: PackedByteArray, value: int) -> void:
	var v := maxi(value, 0)
	while v >= 0x80:
		b.append((v & 0x7F) | 0x80)
		v >>= 7
	b.append(v)


## A varint at `pos[0]` (moved on). Returns -1 when the data ends or the number has more than 5 bytes.
static func _get_varint(b: PackedByteArray, pos: Array) -> int:
	var v := 0
	for i in 5:
		if pos[0] >= b.size():
			return -1
		var byte: int = b[pos[0]]
		pos[0] += 1
		v |= (byte & 0x7F) << (7 * i)
		if byte & 0x80 == 0:
			return v
	return -1
