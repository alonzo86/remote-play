extends RefCounted
## A player profile (FD-22, docs/PROFILES_PLAN.md): a random ID, a name, an avatar. It lives on the phone. The phone sends the ID,
## the name and the avatar when it joins a TV, so the player is the same in every room. The TV checks what it receives with the
## static functions of this file (`clean_name`, `clean_id`, `clean_avatar`).

const Protocol = preload("res://scripts/core/protocol.gd")

var id := ""
var player_name := ""
var avatar := 0
var rev := 0   # Counts the edits of name and avatar. The copy with the higher number wins (docs/PROFILES_PLAN.md 6.5).
var bests := {}   # best key -> integer. Filled by the personal best rules (REQ-GM-98).


## A new random ID: 32 lower case hex characters (16 random bytes).
static func make_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## `s` in lower case when it is a profile ID (32 hex characters), else an empty text.
static func clean_id(s: String) -> String:
	var t := s.strip_edges().to_lower()
	if t.length() != 32 or not t.is_valid_hex_number(false):
		return ""
	return t


## A character that a player name can have: the Latin letters, the digits, the space and the Hebrew letters. These are
## characters that both pixel fonts draw (a test checks it). Control characters, direction marks and nikud are not in the list.
static func is_allowed_char(code: int) -> bool:
	return code == 32 or (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
			or (code >= 0x05D0 and code <= 0x05EA)


## `text` with only the allowed characters. The name field uses it while the player types (a space at the end stays).
static func filter_name(text: String) -> String:
	var out := ""
	for i in text.length():
		if is_allowed_char(text.unicode_at(i)):
			out += text[i]
	return out


## A name as the phone and the TV accept it: only allowed characters, no space at the ends, at most `Protocol.NAME_MAX`
## characters. It can be empty.
static func clean_name(text: String) -> String:
	return filter_name(text).strip_edges().substr(0, Protocol.NAME_MAX).strip_edges()


## The avatar index from a message: an integer from 0 to 255, or -1 when there is none or it is not valid.
static func clean_avatar(v: Variant) -> int:
	if not (v is int or v is float):
		return -1
	var n := int(v)
	return n if n >= 0 and n <= 255 else -1


func is_valid() -> bool:
	return clean_id(id) != "" and clean_name(player_name) != ""


func to_dict() -> Dictionary:
	return {"id": id, "name": player_name, "avatar": avatar, "rev": rev, "bests": bests}


## A profile from a saved dictionary. Returns null when it is not valid.
static func from_dict(d: Dictionary) -> RefCounted:
	var p = load("res://scripts/core/profile.gd").new()
	p.id = clean_id(String(d.get("id", "")))
	p.player_name = clean_name(String(d.get("name", "")))
	var av := clean_avatar(d.get("avatar", 0))
	p.avatar = maxi(av, 0)
	p.rev = maxi(int(d.get("rev", 0)), 0)
	var b = d.get("bests", {})
	p.bests = b.duplicate() if b is Dictionary else {}
	return p if p.is_valid() else null
