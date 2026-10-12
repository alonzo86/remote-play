extends SceneTree
## Finding a TV without the UDP beacon (docs/PROTOCOL.md, "Probe", REQ-FL-83): the answer of the TV to a hello with a room that
## cannot exist, the scan of the addresses of the network, and the list of the phone. Real sockets on the local machine.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/probe.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const TvProber = preload("res://scripts/net/tv_prober.gd")

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_until(cond: Callable, max_ms := 20000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	await process_frame   # The App autoload is ready after the first frame.
	_addresses()
	_answers()
	await _list()
	await _scan()


## The addresses a scan asks (the other 253 of each /24 network, once), and the private addresses of a device.
func _addresses() -> void:
	print("addresses")
	var hosts := TvProber.hosts_to_probe(["192.168.1.20", "10.0.0.11", "192.168.1.30"])
	_check(hosts.size() == 254 * 2 - 3 and "192.168.1.20" not in hosts and "10.0.0.11" not in hosts
			and "192.168.1.30" not in hosts and "192.168.1.1" in hosts and "10.0.0.254" in hosts
			and hosts.count("192.168.1.1") == 1 and "10.0.1.1" not in hosts,
			"a scan asks the other addresses of each /24 network once: %d" % hosts.size())
	_check(TvProber.hosts_to_probe(["garbage", "1.2.3"]).is_empty(), "a scan of a bad address asks nothing")
	_check(Protocol.private_ipv4s().all(func(a): return a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172.")),
			"private_ipv4s gives only private addresses")
	var wifi_and_mobile := ["10.45.3.7", "192.168.1.20", "fe80::1", "127.0.0.1", "192.168.1.21", "8.8.8.8"]
	_check(Protocol.best_private(wifi_and_mobile) == ["192.168.1.20", "192.168.1.21"],
			"only the best kind of private address is scanned, not the mobile one (10.x next to 192.168.x)")
	_check(Protocol.best_private(["10.0.0.5", "172.20.1.1"]) == ["10.0.0.5"]
			and Protocol.best_private(["172.31.0.2", "172.32.0.2"]) == ["172.31.0.2"]
			and Protocol.best_private(["127.0.0.1", "169.254.1.1", "garbage"]).is_empty(),
			"10.x comes before 172.16 to 172.31, and other addresses are not private")
	_check(TvProber.hosts_to_probe(["192.168.1.20"], 3) == ["192.168.1.1", "192.168.1.2", "192.168.1.3"],
			"a scan can be limited to the first hosts")


## What an answer of a TV must have to be a TV.
func _answers() -> void:
	print("answers")
	var reject := {"t": "reject", "reason": "bad_room", "room": "KQZM", "name": "Den", "players": 2, "max": 4}
	var tv := TvProber.tv_from_reject(reject, "192.168.1.5")
	_check(tv.room == "KQZM" and tv.ip == "192.168.1.5" and tv.port == Protocol.WS_PORT and tv.players == 2 and tv.name == "Den",
			"a bad_room answer with a room is a TV")
	_check(TvProber.tv_from_reject({"t": "reject", "reason": "full"}, "1.1.1.1").is_empty()
			and TvProber.tv_from_reject({"t": "reject", "reason": "bad_room"}, "1.1.1.1").is_empty()
			and TvProber.tv_from_reject({"t": "welcome"}, "1.1.1.1").is_empty(),
			"a full answer, an old TV without the room and another message are not a TV")


## A TV that a scan found is in the list of the phone, lives longer than a beacon TV, and a beacon replaces it.
func _list() -> void:
	print("list")
	await _expiry_without_port()
	var disc: Node = root.get_node("App").controller_discovery   # The one that listens on the beacon port.
	disc.tvs.clear()
	await process_frame
	var changes := [0]
	disc.list_changed.connect(func(): changes[0] += 1)
	var tv := TvProber.tv_from_reject({"t": "reject", "reason": "bad_room", "room": "KQZM", "name": "Den", "players": 1,
			"max": 4}, "192.168.1.5")
	disc.add_probed(tv)
	_check(disc.tvs.has("KQZM") and disc.tvs["KQZM"].probed and changes[0] == 1, "a found TV is in the list")
	disc.add_probed(tv)
	_check(changes[0] == 1, "the same TV again does not change the list")
	disc.tvs["KQZM"].seen_ms = Time.get_ticks_msec() - disc.EXPIRE_MS - 500
	disc._process(0.0)
	_check(disc.tvs.has("KQZM"), "a found TV lives longer than a beacon TV")
	disc.tvs["KQZM"].seen_ms = Time.get_ticks_msec() - disc.PROBED_EXPIRE_MS - 500
	disc._process(0.0)
	_check(not disc.tvs.has("KQZM"), "and goes when it is not found again")
	disc.tvs["KQZM"] = {"room": "KQZM", "ip": "192.168.1.5", "port": 47801, "name": "Den", "players": 1, "max": 4,
			"seen_ms": Time.get_ticks_msec()}
	disc.add_probed(tv)
	_check(not disc.tvs["KQZM"].get("probed", false), "a TV that has a beacon stays a beacon TV")
	disc.tvs.clear()


## A listener that could not bind the beacon port (another listener has it) still removes a found TV that is not found again.
func _expiry_without_port() -> void:
	var disc: Node = load("res://scripts/net/controller_discovery.gd").new()
	root.add_child(disc)   # The App already listens on the port, so this one cannot bind.
	await process_frame
	var answer := {"t": "reject", "reason": "bad_room", "room": "ZZZZ", "name": "Den", "players": 0, "max": 4}
	var tv := TvProber.tv_from_reject(answer, "10.0.0.9")
	disc.add_probed(tv)
	disc.tvs["ZZZZ"].seen_ms = Time.get_ticks_msec() - disc.PROBED_EXPIRE_MS - 500
	disc._process(0.0)
	_check(not disc.listening and not disc.tvs.has("ZZZZ"), "without the beacon port a found TV still expires")
	disc.queue_free()


## A real TV on this machine: the scan finds it with its room code, name and player count, and joins nothing.
func _scan() -> void:
	print("scan")
	var server := TvServer.new()
	root.add_child(server)
	server.start({})
	server.set_phase("menu")
	var prober := TvProber.new()
	root.add_child(prober)
	var seen := []
	prober.found.connect(func(tv): seen.append(tv))
	prober.start(["127.0.0.200"], 4)   # It asks 127.0.0.1 to 127.0.0.4; the TV listens on 127.0.0.1.
	await _wait_until(func(): return not prober.running)
	_check(not seen.is_empty() and seen[0].room == server.room_code and seen[0].port == Protocol.WS_PORT
			and seen[0].players == 0 and seen[0].max == Protocol.MAX_PLAYERS and seen[0].name == server.tv_name,
			"a scan finds the TV with its room code, name and player count: %s" % str(seen))
	_check(server.player_count() == 0, "a scan joins nothing")
	prober.queue_free()
	server.stop()
