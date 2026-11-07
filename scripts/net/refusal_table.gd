extends RefCounted
## The host refusals of each address, kept by the TV for the run of the TV app (docs/JOIN_APPROVAL_PLAN.md 4.6, REQ-FL-104).
## `after` refusals in a row from one address block it for `block_ms`; an allow starts the count again. The table is bounded:
## a device with many addresses can only make the TV forget an old counter, never grow the memory.

var _entries := {}   # address -> {count, blocked_until_ms, touched_ms}


## True while the address is blocked. An entry with no count and an ended block is dropped here.
func is_blocked(host: String, now: int) -> bool:
	if not _entries.has(host):
		return false
	var e: Dictionary = _entries[host]
	if now < int(e.blocked_until_ms):
		return true
	if int(e.count) == 0:
		_entries.erase(host)
	return false


## One host refusal from `host`. At the `after`-th one in a row the address is blocked for `block_ms` and its count goes to 0.
func count_refusal(host: String, now: int, after: int, block_ms: int, max_entries: int) -> void:
	if not _entries.has(host):
		_make_room(now, max_entries)
		_entries[host] = {"count": 0, "blocked_until_ms": 0, "touched_ms": now}
	var e: Dictionary = _entries[host]
	e.count = int(e.count) + 1
	e.touched_ms = now
	if int(e.count) >= after:
		e.blocked_until_ms = now + block_ms
		e.count = 0


## The host allowed a request of `host`: its count is 0. A live block stays.
func clear(host: String, now: int) -> void:
	if _entries.has(host) and now >= int(_entries[host].blocked_until_ms):
		_entries.erase(host)


func size() -> int:
	return _entries.size()


func reset() -> void:
	_entries.clear()


## Makes room for one new address (the bound of 4.6): first the entries with no count and an ended block, then the oldest entry
## that is not blocked, then (every entry blocked) the one whose block ends first.
func _make_room(now: int, max_entries: int) -> void:
	if _entries.size() < max_entries:
		return
	for host in _entries.keys():
		var e: Dictionary = _entries[host]
		if int(e.count) == 0 and now >= int(e.blocked_until_ms):
			_entries.erase(host)
	while _entries.size() >= max_entries and not _entries.is_empty():
		var victim := ""
		var oldest := -1
		for host in _entries:
			var e: Dictionary = _entries[host]
			if now < int(e.blocked_until_ms):
				continue
			if victim == "" or int(e.touched_ms) < oldest:
				victim = host
				oldest = int(e.touched_ms)
		if victim == "":
			for host in _entries:
				var e: Dictionary = _entries[host]
				if victim == "" or int(e.blocked_until_ms) < oldest:
					victim = host
					oldest = int(e.blocked_until_ms)
		_entries.erase(victim)
