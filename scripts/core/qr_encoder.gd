extends RefCounted
## Minimal QR code encoder. Byte mode, error correction level L, versions 1 to 14.
## Use: var m := QrEncoder.encode("text"); m[y][x] is true for a dark module.
## Returns an empty Array when the text is too long (max 458 bytes). The TV link is small and uses the first versions;
## a player profile code (FD-22) uses up to version 14.

# Per version: [data codewords total, ecc codewords per block, block count]
const _L_TABLE := {
	1: [19, 7, 1],
	2: [34, 10, 1],
	3: [55, 15, 1],
	4: [80, 20, 1],
	5: [108, 26, 1],
	6: [136, 18, 2],
	7: [156, 20, 2],
	8: [194, 24, 2],
	9: [232, 30, 2],
	10: [274, 18, 4],
	11: [324, 20, 4],
	12: [370, 24, 4],
	13: [428, 26, 4],
	14: [461, 30, 4],
}

const MAX_VERSION := 14
const _ALIGN := {
	1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34],
	7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50], 11: [6, 30, 54], 12: [6, 32, 58], 13: [6, 34, 62],
	14: [6, 26, 46, 66],
}

var _size := 0
var _modules: Array = [] # [y][x] bool
var _is_func: Array = []


static func encode(text: String) -> Array:
	var data := text.to_utf8_buffer()
	for ver in range(1, MAX_VERSION + 1):
		var info: Array = _L_TABLE[ver]
		# 4 bits mode + the count (8 bits, 16 bits from version 10) + data bits must fit
		if 4 + _count_bits(ver) + data.size() * 8 <= info[0] * 8:
			var q = load("res://scripts/core/qr_encoder.gd").new()
			return q._build(data, ver)
	return []


## The bits of the character count field in byte mode.
static func _count_bits(ver: int) -> int:
	return 8 if ver < 10 else 16


func _build(data: PackedByteArray, ver: int) -> Array:
	var info: Array = _L_TABLE[ver]
	var capacity: int = info[0]
	# Bit stream
	var bits: Array = []
	_put(bits, 0x4, 4)
	_put(bits, data.size(), _count_bits(ver))
	for b in data:
		_put(bits, b, 8)
	_put(bits, 0, mini(4, capacity * 8 - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)
	var cw := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var v := 0
		for j in 8:
			v = (v << 1) | bits[i + j]
		cw.append(v)
	var pad := 0xEC
	while cw.size() < capacity:
		cw.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	var all := _add_ecc_interleave(cw, ver)
	# Matrix
	_size = ver * 4 + 17
	_modules = []
	_is_func = []
	for y in _size:
		var row := []
		var frow := []
		row.resize(_size)
		row.fill(false)
		frow.resize(_size)
		frow.fill(false)
		_modules.append(row)
		_is_func.append(frow)
	_draw_function_patterns(ver)
	_place_data(all)
	var best_mask := 0
	var best_pen := 1 << 30
	for m in 8:
		_apply_mask(m)
		_draw_format(m)
		var pen := _penalty()
		if pen < best_pen:
			best_pen = pen
			best_mask = m
		_apply_mask(m) # undo (XOR)
	_apply_mask(best_mask)
	_draw_format(best_mask)
	return _modules


static func _put(bits: Array, value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


# ---- Reed-Solomon ----

static func _gf_mul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z


static func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_mul(root, 2)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in divisor.size():
			result[i] ^= _gf_mul(divisor[i], factor)
	return result


func _add_ecc_interleave(data: PackedByteArray, ver: int) -> PackedByteArray:
	var info: Array = _L_TABLE[ver]
	var num_blocks: int = info[2]
	var ecc_len: int = info[1]
	var raw := _raw_codewords(ver)
	var num_short := num_blocks - raw % num_blocks
	var short_len := raw / num_blocks
	var divisor := _rs_divisor(ecc_len)
	var blocks: Array = []
	var k := 0
	for i in num_blocks:
		var dat_len := short_len - ecc_len + (0 if i < num_short else 1)
		var dat := data.slice(k, k + dat_len)
		k += dat_len
		var ecc := _rs_remainder(dat, divisor)
		if i < num_short:
			dat.append(0)
		dat.append_array(ecc)
		blocks.append(dat)
	var result := PackedByteArray()
	for i in blocks[0].size():
		for j in blocks.size():
			if i != short_len - ecc_len or j >= num_short:
				result.append(blocks[j][i])
	return result


static func _raw_codewords(ver: int) -> int:
	var size := ver * 4 + 17
	var result := size * size
	result -= 8 * 8 * 3
	result -= 15 * 2 + 1
	result -= (size - 16) * 2
	if ver >= 2:
		var n := ver / 7 + 2
		result -= (n - 1) * (n - 1) * 25
		result -= (n - 2) * 2 * 20
	if ver >= 7:
		result -= 36   # The two blocks of version information.
	return result / 8


# ---- Matrix drawing ----

func _set_func(x: int, y: int, dark: bool) -> void:
	_modules[y][x] = dark
	_is_func[y][x] = true


func _draw_function_patterns(ver: int) -> void:
	for i in _size:
		_set_func(6, i, i % 2 == 0)
		_set_func(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(_size - 4, 3)
	_draw_finder(3, _size - 4)
	var pos: Array = _ALIGN[ver]
	for i in pos.size():
		for j in pos.size():
			var skip: bool = (i == 0 and j == 0) or (i == 0 and j == pos.size() - 1) \
					or (i == pos.size() - 1 and j == 0)
			if not skip:
				_draw_align(pos[i], pos[j])
	_draw_format(0)
	if ver >= 7:
		_draw_version(ver)


func _draw_finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var dist := maxi(absi(dx), absi(dy))
			var xx := cx + dx
			var yy := cy + dy
			if xx >= 0 and xx < _size and yy >= 0 and yy < _size:
				_set_func(xx, yy, dist != 2 and dist != 4)


func _draw_align(cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_func(cx + dx, cy + dy, maxi(absi(dx), absi(dy)) != 1)


## The 18 bits of version information (BCH code), in two blocks of 6 x 3 modules, for version 7 and higher.
func _draw_version(ver: int) -> void:
	var rem := ver
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits := (ver << 12) | rem
	for i in 18:
		var dark := _bit(bits, i)
		var a := _size - 11 + i % 3
		var b := i / 3
		_set_func(a, b, dark)
		_set_func(b, a, dark)


func _draw_format(mask: int) -> void:
	var data := (1 << 3) | mask # level L = 01
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_func(8, i, _bit(bits, i))
	_set_func(8, 7, _bit(bits, 6))
	_set_func(8, 8, _bit(bits, 7))
	_set_func(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_func(14 - i, 8, _bit(bits, i))
	for i in range(0, 8):
		_set_func(_size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_func(8, _size - 15 + i, _bit(bits, i))
	_set_func(8, _size - 8, true)


static func _bit(v: int, i: int) -> bool:
	return ((v >> i) & 1) != 0


func _place_data(data: PackedByteArray) -> void:
	var i := 0
	var right := _size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in _size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := (_size - 1 - vert) if upward else vert
				if not _is_func[y][x] and i < data.size() * 8:
					_modules[y][x] = _bit(data[i >> 3], 7 - (i & 7))
					i += 1
		right -= 2


func _apply_mask(m: int) -> void:
	for y in _size:
		for x in _size:
			if _is_func[y][x]:
				continue
			var inv := false
			match m:
				0: inv = (x + y) % 2 == 0
				1: inv = y % 2 == 0
				2: inv = x % 3 == 0
				3: inv = (x + y) % 3 == 0
				4: inv = (x / 3 + y / 2) % 2 == 0
				5: inv = (x * y) % 2 + (x * y) % 3 == 0
				6: inv = ((x * y) % 2 + (x * y) % 3) % 2 == 0
				7: inv = ((x + y) % 2 + (x * y) % 3) % 2 == 0
			if inv:
				_modules[y][x] = not _modules[y][x]


func _penalty() -> int:
	var score := 0
	var dark := 0
	# Rules 1 and 3 for rows and columns
	for pass_i in 2:
		for a in _size:
			var run := 1
			var hist: Array = []
			for b in _size:
				var cur: bool = _modules[a][b] if pass_i == 0 else _modules[b][a]
				hist.append(cur)
				if b > 0:
					var prev: bool = hist[b - 1]
					if cur == prev:
						run += 1
						if run == 5:
							score += 3
						elif run > 5:
							score += 1
					else:
						run = 1
			# finder-like pattern 1011101 with 4 light modules on a side
			for s in range(0, _size - 10):
				var w1 := true
				var w2 := true
				var p1 := [true, false, true, true, true, false, true, false, false, false, false]
				var p2 := [false, false, false, false, true, false, true, true, true, false, true]
				for t in 11:
					if hist[s + t] != p1[t]:
						w1 = false
					if hist[s + t] != p2[t]:
						w2 = false
				if w1:
					score += 40
				if w2:
					score += 40
	# Rule 2: 2x2 blocks
	for y in _size - 1:
		for x in _size - 1:
			var c: bool = _modules[y][x]
			if c == _modules[y][x + 1] and c == _modules[y + 1][x] and c == _modules[y + 1][x + 1]:
				score += 3
	# Rule 4: dark/light balance
	for y in _size:
		for x in _size:
			if _modules[y][x]:
				dark += 1
	var total := _size * _size
	var k := (absi(dark * 20 - total * 10) + total - 1) / total - 1
	score += maxi(k, 0) * 10
	return score
