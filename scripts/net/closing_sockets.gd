extends RefCounted
## Sockets that the TV or a phone has let go and that still finish their close handshake (issues #169, #310). A close frame
## sent at once can drop the frames that came before it (a `bye`, a `reject`), so the socket is polled first and closed
## `CLOSE_DELAY_MS` later; one that has not ended `CLOSE_GIVE_UP_MS` after it was added is dropped. `TvServer` and
## `ControllerClient` use the same rule through this class.

const CLOSE_DELAY_MS := 300       # The wait before the close frame is sent.
const CLOSE_GIVE_UP_MS := 1500    # The wait after which the socket is dropped, closed or not.

var _entries: Array = []          # [{ws, since, closed}]


## Takes the socket and polls it once. `now` is in ms (`Time.get_ticks_msec()`).
func add(ws: WebSocketPeer, now: int) -> void:
	ws.poll()
	_entries.append({"ws": ws, "since": now, "closed": false})


## Call about once per frame.
func service(now: int) -> void:
	for entry in _entries.duplicate():
		entry.ws.poll()
		if entry.ws.get_ready_state() == WebSocketPeer.STATE_CLOSED or now - int(entry.since) > CLOSE_GIVE_UP_MS:
			_entries.erase(entry)
		elif not entry.closed and now - int(entry.since) >= CLOSE_DELAY_MS:
			entry.ws.close()
			entry.closed = true


func is_empty() -> bool:
	return _entries.is_empty()


func size() -> int:
	return _entries.size()
