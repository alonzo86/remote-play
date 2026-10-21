extends Node
## A TCP relay between a phone and the TV for the tests of a lost Wi-Fi (docs/MANUAL_TESTS.md test 7, "Wi-Fi off").
## A phone that loses its Wi-Fi does not close its connection: nothing arrives on either side and no FIN is sent. `cut()` makes
## exactly that: the open connections stay open and every byte is dropped, and new connections hang. `restore()` ends the frozen
## connections (the phone has a new IP session, so the old one is dead) and lets new connections through.
## Not a test itself (it is not in tests/suites.txt).

var listen_port := 0
var upstream_port := 0
var cut_now := false
var accepted := 0           # Connections that were accepted, also while the link was cut.
var passed := 0             # Connections that were relayed to the TV.

var _server := TCPServer.new()
var _pairs: Array = []      # {down: StreamPeerTCP (phone side), up: StreamPeerTCP (TV side), frozen: bool}
var _hanging: Array = []    # Phone-side connections that came while the link was cut.


func start(p_listen: int, p_upstream: int) -> Error:
	listen_port = p_listen
	upstream_port = p_upstream
	return _server.listen(listen_port, "127.0.0.1")


func stop() -> void:
	_server.stop()
	for p in _pairs:
		p.down.disconnect_from_host()
		p.up.disconnect_from_host()
	_pairs.clear()
	for h in _hanging:
		h.disconnect_from_host()
	_hanging.clear()


## The link goes away without a close.
func cut() -> void:
	cut_now = true
	for p in _pairs:
		p.frozen = true


## The link is back. The connections that were frozen are dead; new ones work.
func restore() -> void:
	cut_now = false
	for p in _pairs.duplicate():
		if p.frozen:
			p.down.disconnect_from_host()
			p.up.disconnect_from_host()
			_pairs.erase(p)
	for h in _hanging:
		h.disconnect_from_host()
	_hanging.clear()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var down := _server.take_connection()
		accepted += 1
		if cut_now:
			_hanging.append(down)   # The SYN is answered, nothing else ever comes: the phone times out.
			continue
		var up := StreamPeerTCP.new()
		if up.connect_to_host("127.0.0.1", upstream_port) == OK:
			passed += 1
			_pairs.append({"down": down, "up": up, "frozen": false})
	for p in _pairs.duplicate():
		p.down.poll()
		p.up.poll()
		if p.frozen:
			_drain(p.down)   # Dropped.
			_drain(p.up)
			continue
		if p.up.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_pump(p.down, p.up)
			_pump(p.up, p.down)
		if p.down.get_status() != StreamPeerTCP.STATUS_CONNECTED or p.up.get_status() == StreamPeerTCP.STATUS_ERROR \
				or p.up.get_status() == StreamPeerTCP.STATUS_NONE:
			p.down.disconnect_from_host()
			p.up.disconnect_from_host()
			_pairs.erase(p)


func _drain(peer: StreamPeerTCP) -> void:
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var n := peer.get_available_bytes()
	if n > 0:
		peer.get_data(n)


func _pump(from: StreamPeerTCP, to: StreamPeerTCP) -> void:
	if from.get_status() != StreamPeerTCP.STATUS_CONNECTED or to.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var n := from.get_available_bytes()
	if n > 0:
		var r := from.get_data(n)
		if r[0] == OK:
			to.put_data(r[1])
