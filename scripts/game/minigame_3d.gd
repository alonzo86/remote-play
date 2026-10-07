extends "res://scripts/game/minigame.gd"
## Base class for 3D minigames. It keeps everything from minigame.gd (player list, pause while a
## phone is lost, D-pad pause menu, Back key) and adds a 3D world inside a SubViewport.
## To add a 3D minigame:
##   1. Make a folder under scripts/game/.
##   2. Extend this script. Override _world_ready(), _world_tick(), and optionally _hud_draw().
##   3. Add the game to scripts/game/registry.gd.
## Build the scene in code under `world`. Use primitive meshes and flat materials.
## Key objects (players, goals, hazards) use add_outlined_mesh(): a dark outline made of an inverted
## hull, with no shader (REQ-GM-47c). See docs/GAME_REQUIREMENTS.md, "Visual language".
## The world is frozen while the game is paused, so physics bodies stop too.

## Root of the 3D scene. Add your nodes here.
var world: Node3D
## Default camera. Move or replace it in _world_ready().
var camera: Camera3D
## 2D layer above the 3D view. Scores and labels are drawn here with _hud_draw().
var hud: Control

const OUTLINE_RATIO := 0.08
const OUTLINE_MIN := 0.03
const OUTLINE_MAX := 0.10

var _viewport: SubViewport


func _game_ready() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED # Cheap on weak TV boxes. Subclasses may raise it.
	_viewport.audio_listener_enable_3d = true
	container.add_child(_viewport)

	world = Node3D.new()
	world.name = "World"
	_viewport.add_child(world)
	_make_environment()

	camera = Camera3D.new()
	camera.position = Vector3(0, 10, 10)
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)

	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.draw.connect(_on_hud_draw)
	add_child(hud)

	_world_ready()


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _background_color()
	# A strong ambient light: the shaded side of an object is at least 60% of the lit side (REQ-GM-47h).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.5
	sun.shadow_enabled = false # Shadows are costly on Android TV. Turn on per game if needed.
	world.add_child(sun)


func _process(delta: float) -> void:
	super(delta)
	if world != null:
		world.process_mode = Node.PROCESS_MODE_DISABLED if is_paused() else Node.PROCESS_MODE_INHERIT


func _game_tick(delta: float) -> void:
	_world_tick(delta)


## 3D games draw on the HUD layer. The base 2D draw only has to fill nothing.
func _draw() -> void:
	pass


func _request_redraw() -> void:
	if hud != null:
		hud.queue_redraw()


func _on_hud_draw() -> void:
	_hud_draw(hud)
	_draw_overlays(hud)


## A flat, lit material for primitive meshes.
static func flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


## Adds a mesh with a flat color to `parent` and returns it.
static func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = flat_material(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A flat material with a dark outline: the mesh, and a child hull that is a little bigger, drawn with
## its front faces culled (REQ-GM-47c). The thickness is 8% of the smallest size of the mesh,
## from 0.03 m to 0.10 m.
static func add_outlined_mesh(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := add_mesh(parent, mesh, color, pos)
	var sz := mesh.get_aabb().size
	var smallest := minf(sz.x, minf(sz.y, sz.z))
	var t := clampf(OUTLINE_RATIO * smallest, OUTLINE_MIN, OUTLINE_MAX)
	var hull := MeshInstance3D.new()
	hull.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = UiTheme.OUTLINE
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	hull.material_override = m
	hull.scale = Vector3(1.0 + 2.0 * t / maxf(sz.x, 0.001), 1.0 + 2.0 * t / maxf(sz.y, 0.001),
			1.0 + 2.0 * t / maxf(sz.z, 0.001))
	mi.add_child(hull)
	return mi


# ---- Override in subclasses ----

## The color behind the world. Pick one from the Party Pop set (REQ-GM-48).
func _background_color() -> Color:
	return UiTheme.BG


## Build the scene under `world`. Players are in `participants`.
func _world_ready() -> void:
	pass


## Game logic. Not called while the game is paused.
func _world_tick(_delta: float) -> void:
	pass


## Draw 2D text and shapes above the 3D view. Keep text inside the 60 px TV safe margin.
func _hud_draw(_canvas: Control) -> void:
	pass
