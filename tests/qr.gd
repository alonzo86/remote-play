extends SceneTree
## The QR encoder for the player profile code (FD-22): the versions 7 to 14 and the limit of 458 bytes.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/qr.gd -- --role=controller

const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const GOLDEN := "eec1854a09ab1ec13243d8c0df2a8af3830c41c5f96f9b48c40ca0c0b611c93a"

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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Versions 7 to 14 (FD-22, the player profile code): size, function patterns, version information, the capacity of each version
## and a fixed text with the hash of its modules. The hash was made once and the modules were read back by an outside decoder
## (zxing-cpp, 66 texts of 1 to 458 bytes, all versions); a change of the hash means the code changed (docs/PROFILES_PLAN.md 6.2).
func _run() -> void:
	print("qr versions 7 to 14")
	var caps := {7: 156, 8: 194, 9: 232, 10: 274, 11: 324, 12: 370, 13: 428, 14: 461}
	var all_ok := true
	for ver in caps:
		# The longest text of a version: 4 bits of mode, the count (8 bits, 16 from version 10), then bytes.
		var most: int = (caps[ver] * 8 - 4 - (8 if ver < 10 else 16)) / 8
		var q := QrEncoder.encode("a".repeat(most))
		var n: int = ver * 4 + 17
		var ok := q.size() == n
		if ok:
			ok = q[0][0] and q[0][6] and q[6][0] and q[n - 7][0] and q[0][n - 7] and not q[1][1] and q[2][2]   # Finders.
			ok = ok and q[6][8] and not q[6][9] and q[6][10]   # The timing pattern.
			ok = ok and q[n - 8][8]   # The dark module.
		# One more byte needs the next version (or is too long at 14).
		var over := QrEncoder.encode("a".repeat(most + 1))
		ok = ok and (over.size() == (n + 4 if ver < 14 else 0))
		all_ok = all_ok and ok
		if not ok:
			print("    version ", ver, " is wrong (size ", q.size(), ", longest text ", most, ")")
	_check(all_ok, "versions 7 to 14: size, finders, timing, dark module, and the capacity limit of each version")
	# Version information of version 7 (BCH 18 bits, ISO 18004): 000111110010010100.
	var q7 := QrEncoder.encode("a".repeat(150))
	var bits := 0
	for i in 18:
		if q7[i / 3][q7.size() - 11 + i % 3]:
			bits |= 1 << i
	_check(q7.size() == 45 and bits == 0x07C94, "version 7 has its version information in the two blocks: %x" % bits)
	var text := ""
	for i in 300:
		text += "abcdefghijklmnopqrstuvwxyz0123456789-_"[(i * 7 + 3) % 38]
	var fixed := QrEncoder.encode(text)
	var flat := ""
	for row in fixed:
		for dark in row:
			flat += "1" if dark else "0"
	_check(fixed.size() == 61 and flat.sha256_text() == GOLDEN,
			"a fixed text of 300 bytes gives fixed modules: %s" % flat.sha256_text())
