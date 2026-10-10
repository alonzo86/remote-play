extends CPUParticles2D
## One burst of square pixel confetti (REQ-FL-42, REQ-FL-45). Drawn by particles, no image files.
## Use Confetti.burst(parent, position). It frees itself when it is done.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const PIXEL := 16   # The size of one piece: two pixels of the 8 px grid.


static func burst(parent: Node, pos: Vector2) -> void:
	var c: CPUParticles2D = (load("res://scripts/ui/confetti.gd") as GDScript).new()
	c.position = pos
	parent.add_child(c)


func _ready() -> void:
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.34, 0.67])
	ramp.colors = PackedColorArray(UiTheme.CONFETTI)
	color_initial_ramp = ramp
	texture = _square()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	one_shot = true
	explosiveness = 1.0
	amount = 36
	lifetime = 0.9
	direction = Vector2(0, -1)
	spread = 70.0
	initial_velocity_min = 380.0
	initial_velocity_max = 760.0
	gravity = Vector2(0, 1500)
	z_index = 100
	emitting = true
	finished.connect(queue_free)


## A white square of one piece. The particle color tints it.
static func _square() -> Texture2D:
	var img := Image.create(PIXEL, PIXEL, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
