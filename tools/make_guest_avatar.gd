extends SceneTree
## Writes `assets/avatars/guest.png`: the avatar of a guest (a phone with no profile), 16 x 16 pixels, in the palette of the
## avatar sheet (owner, 2026-11-11: a grey silhouette with a question mark, option A of the mocks). It is not one of the 32
## avatars that a player can choose, so it is not in `avatars.png` (docs/PROFILES_PLAN.md section 7).
## Run: godot --headless --path . --script tools/make_guest_avatar.gd

const OUT := "res://assets/avatars/guest.png"
const GREY := Color8(124, 124, 124)
const WHITE := Color8(252, 252, 252)
## "D" grey, "W" white, "." clear.
const ROWS := [
	"................",
	"....DDDDDDDD....",
	"...DDDDDDDDDD...",
	"...DDDWWWWDDD...",
	"...DDWWDDWWDD...",
	"...DDDDDDWWDD...",
	"...DDDDDWWDDD...",
	"...DDDDWWDDDD...",
	"...DDDDDDDDDD...",
	"...DDDDWWDDDD...",
	"....DDDDDDDD....",
	".....DDDDDD.....",
	"..DDDDDDDDDDDD..",
	".DDDDDDDDDDDDDD.",
	".DDDDDDDDDDDDDD.",
	"................",
]


func _initialize() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c: String = ROWS[y][x]
			img.set_pixel(x, y, GREY if c == "D" else (WHITE if c == "W" else Color(0, 0, 0, 0)))
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("guest avatar written: ", error_string(err))
	quit(0 if err == OK else 1)
