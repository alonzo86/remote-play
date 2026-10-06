extends Node
## Autoload "App". Owns the services and switches screens.
## TV role: server, discovery beacon, debug overlay, menu and minigames.
## Controller role: client, discovery listener, connect screen and pad screen.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const TvDiscovery = preload("res://scripts/net/tv_discovery.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ControllerDiscovery = preload("res://scripts/net/controller_discovery.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const TvMenu = preload("res://scripts/ui/tv_menu.gd")
const ControllerConnect = preload("res://scripts/ui/controller_connect.gd")
const ControllerPad = preload("res://scripts/ui/controller_pad.gd")

const SETTINGS_FILE := "user://settings.cfg"

## Shared with every Orientation object. Changes apply at once.
var settings := {
	"invert_tilt": false,
	"invert_yaw": false,
	"pointer_range_deg": 25.0,
	"overlay": false,
}

var theme_res: Theme
var server: Node            # TV only
var discovery: Node         # TV only
var overlay: CanvasLayer    # TV only
var client: Node            # Controller only
var controller_discovery: Node
var last_error := ""        # Controller only. Shown on the connect screen.

var _screen: Control
var _last_back_ms := 0


func _ready() -> void:
	_load_settings()
	theme_res = UiTheme.make()
	DisplayServer.screen_set_keep_on(true)
	get_tree().set_auto_accept_quit(false)
	if Role.is_tv():
		_start_tv()
	else:
		_start_controller()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back() # Escape on desktop. On Android the Back key comes as KEY_BACK.
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACK:
			_back()
		elif Role.is_tv() and (event.keycode == KEY_MENU or event.keycode == KEY_F3):
			toggle_overlay()


# ---- Screens ----

func go(script: GDScript) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = script.new()
	_screen.theme = theme_res
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func go_menu() -> void:
	go(TvMenu)
	if server != null:
		server.set_phase("lobby")


func current_screen() -> Control:
	return _screen


func _back() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back_ms < 250:
		return # The same press can arrive as a key and as a notification.
	_last_back_ms = now
	if _screen != null and _screen.has_method("on_back"):
		_screen.on_back()
	else:
		_quit()


func _quit() -> void:
	if server != null:
		server.stop()
	if client != null:
		client.leave()
	get_tree().quit()


# ---- Settings ----

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_FILE)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])


# ---- TV ----

func _start_tv() -> void:
	server = TvServer.new()
	add_child(server)
	server.start(settings)
	discovery = TvDiscovery.new()
	discovery.server = server
	add_child(discovery)
	overlay = DebugOverlay.new()
	overlay.visible = bool(settings.overlay)
	add_child(overlay)
	go_menu()


func toggle_overlay() -> void:
	settings.overlay = not bool(settings.overlay)
	overlay.visible = settings.overlay
	save_settings()


# ---- Controller ----

func _start_controller() -> void:
	var win := get_window()
	win.content_scale_size = Vector2i(1080, 1920)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	if not OS.has_feature("mobile"):
		win.size = Vector2i(450, 800)
	client = ControllerClient.new()
	client.player_name = "Phone %d" % (randi() % 90 + 10)
	add_child(client)
	controller_discovery = ControllerDiscovery.new()
	add_child(controller_discovery)
	client.state_changed.connect(_on_client_state)
	client.rejected.connect(_on_client_rejected)
	if "--auto-join" in OS.get_cmdline_user_args():
		# For desktop tests: join the first TV that sends a beacon.
		controller_discovery.list_changed.connect(_auto_join)
	var last: Dictionary = client.load_last()
	if String(last.get("host", "")) != "" and String(last.get("token", "")) != "":
		client.use_saved_token(String(last.token))
		go(ControllerConnect)
		client.connect_to(String(last.host), int(last.port), String(last.room))
	else:
		go(ControllerConnect)


func _auto_join() -> void:
	var tvs: Array = controller_discovery.sorted_list()
	if client.state == ControllerClient.State.IDLE and not tvs.is_empty():
		client.connect_to(tvs[0].ip, tvs[0].port, tvs[0].room)


func _on_client_state(state: int) -> void:
	if state == ControllerClient.State.CONNECTED:
		last_error = ""
		if not (_screen is ControllerPad):
			go(ControllerPad)
	elif state == ControllerClient.State.IDLE:
		if not (_screen is ControllerConnect):
			go(ControllerConnect)


func _on_client_rejected(reason: String) -> void:
	last_error = {
		"full": "The TV is full (4 players).",
		"bad_room": "Wrong room code.",
		"version": "App version does not match the TV.",
		"unreachable": "Cannot reach the TV. Check the Wi-Fi.",
		"tv_closed": "The TV closed the connection.",
	}.get(reason, "Connection refused: " + reason)
