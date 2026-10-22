extends Node
## Autoload "App". Owns the services and switches screens.
## TV role: server, debug overlay, menu and minigames.
## Controller role: client, connect screen and pad screen.

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const Backdrop = preload("res://scripts/ui/backdrop.gd")
const TvLogo = preload("res://scripts/ui/tv_logo.gd")
const TvConnect = preload("res://scripts/ui/tv_connect.gd")
const TvGames = preload("res://scripts/ui/tv_games.gd")
const TvSettings = preload("res://scripts/ui/tv_settings.gd")
const TvGameSettings = preload("res://scripts/ui/tv_game_settings.gd")
const ControllerConnect = preload("res://scripts/ui/controller_connect.gd")
const ControllerPad = preload("res://scripts/ui/controller_pad.gd")
const ControllerWait = preload("res://scripts/ui/controller_wait.gd")
const QrScanner = preload("res://scripts/net/qr_scanner.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
const AboutScreen = preload("res://scripts/ui/about_screen.gd")
const ControllerSettings = preload("res://scripts/ui/controller_settings.gd")
const ControllerProfiles = preload("res://scripts/ui/controller_profiles.gd")
const ControllerProfileEdit = preload("res://scripts/ui/controller_profile_edit.gd")
const ControllerProfileShare = preload("res://scripts/ui/controller_profile_share.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")

const SETTINGS_FILE := "user://settings.cfg"

## Shared with every Orientation object. Changes apply at once.
var settings := {
	"invert_tilt": false,
	"overlay": false,
	"music_volume": 7,   # TV: 0 to 10 (REQ-FL-64)
	"sfx_volume": 8,     # TV: 0 to 10
	"mute": false,       # TV: mutes music and effects
	"haptics": true,     # Phone: vibrate in games (REQ-FL-66)
	"language": "",   # "en" or "he". Empty until the owner chooses on the logo screen (TV) (REQ-FL-60).
}

var theme_res: Theme
var server: Node            # TV only
var overlay: CanvasLayer    # TV only
var client: Node            # Controller only
## The last personal best of this phone: {"key", "value", "old"} or empty (REQ-GM-100). Cleared when the next round starts.
var last_best := {}
var profiles: ProfileStore  # Controller only. The profiles of this phone (FD-22).
var last_error := ""        # Controller only. Shown on the connect screen.
var last_game := ""         # TV only. The Games screen focuses this tile again.

## A test sets it to see that Quit was chosen without closing the test. It replaces `get_tree().quit()`.
var quit_hook := Callable()
var _screen: Control
var _last_back_ms := 0


func _ready() -> void:
	Lang.register()
	_load_settings()
	Sound.apply_settings()
	set_language(language_to_use(), false)
	theme_res = UiTheme.make()
	var layer := CanvasLayer.new()
	layer.layer = -100
	layer.add_child(Backdrop.new())
	add_child(layer)
	DisplayServer.screen_set_keep_on(true)
	get_tree().set_auto_accept_quit(false)
	if Role.is_tv():
		_start_tv()
	else:
		_start_controller()


## The language the app starts in: the saved one, else the language of the device (REQ-FL-60).
func language_to_use() -> String:
	var saved := String(settings.get("language", ""))
	return saved if saved in Lang.CODES else Lang.system_language()


## True when the TV has no saved language: the logo screen asks for it (REQ-FL-60).
func needs_language_choice() -> bool:
	return not (String(settings.get("language", "")) in Lang.CODES)


## Switches the UI at once (REQ-FL-61). On the TV the choice is saved and goes to the phones; a phone follows the TV and
## does not save it.
func set_language(code: String, remember := true) -> void:
	if not (code in Lang.CODES):
		return
	Lang.set_language(code, get_tree().root)
	if Role.is_tv():
		if remember:
			settings.language = code
			save_settings()
		if server != null:
			server.set_language(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		# A click or a tap must not leave a focus outline on the button. The D-pad and the remote still focus.
		_release_focus.call_deferred(event.position)
	if Role.is_tv():
		_menu_sound(event)
	if event.is_action_pressed("ui_cancel"):
		_back() # Escape on desktop. On Android the Back key comes as KEY_BACK.
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACK:
			_back()
		elif Role.is_tv() and (event.keycode == KEY_MENU or event.keycode == KEY_F3):
			toggle_overlay()


## Drops the focus after a tap. A text field keeps it when the tap is on the field (the phone keyboard stays open); a tap anywhere
## else drops it and closes the keyboard (REQ-FL-72).
func _release_focus(at := Vector2.INF) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if (owner is LineEdit or owner is TextEdit) and (owner as Control).get_global_rect().has_point(at):
		return
	get_viewport().gui_release_focus()
	if owner is LineEdit or owner is TextEdit:
		DisplayServer.virtual_keyboard_hide()


## The sound of the D-pad on the TV (docs/AUDIO_PLAN.md, section 2.2).
func _menu_sound(event: InputEvent) -> void:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(a):
			Sound.sfx("move")
			return
	if event.is_action_pressed("ui_accept"):
		# In a game, OK opens the pause menu, which has its own sound. On a dim game tile OK plays `denied` only (TvGames).
		var tile := get_viewport().gui_get_focus_owner()
		if tile != null and tile.get("fits") == false:
			return
		if _screen == null or not ("start_props" in _screen):
			Sound.sfx("select")
	elif event.is_action_pressed("ui_cancel"):
		Sound.sfx("back")


# ---- Screens ----

## Switches to a screen. `props` are set on the new screen before it enters the tree,
## so its _ready() can use them. A minigame keeps them in start_props for restart().
func go(script: GDScript, props := {}) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = script.new()
	for k in props:
		_screen.set(k, props[k])
	if "start_props" in _screen:
		_screen.start_props = props
	_screen.theme = theme_res
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_safe_area()
	if not ("start_props" in _screen):
		# Menu screens fade in (REQ-FL-42). Games do not: they start at once.
		_screen.modulate.a = 0.0
		_screen.create_tween().tween_property(_screen, "modulate:a", 1.0, 0.18)


## A phone screen stays inside the safe area: a notch, a Dynamic Island, the status bar and the home bar cover nothing
## (REQ-FL-68).
## The TV uses the whole screen.
func _apply_safe_area() -> void:
	if _screen == null or not Role.is_controller():
		return
	_apply_insets(SafeArea.current(get_viewport().get_visible_rect().size))


## Puts the screen inside the insets `m` (left, top, right, bottom). In Hebrew the screen is laid out right to left, so Godot
## mirrors its left and right offsets: they swap here, and a notch at the physical left stays at the physical left.
func _apply_insets(m: Vector4) -> void:
	if Lang.is_rtl():
		m = Vector4(m.z, m.y, m.x, m.w)
	_screen.offset_left = m.x
	_screen.offset_top = m.y
	_screen.offset_right = -m.z
	_screen.offset_bottom = -m.w


## The TV flow: logo -> connect -> games (-> settings). See docs/TV_FLOW.md.
func go_logo() -> void:
	go(TvLogo)
	server.set_phase("connect")


func go_connect() -> void:
	go(TvConnect)
	server.set_phase("connect")


func go_games() -> void:
	go(TvGames)
	server.set_phase("menu")


## The settings view of a game (REQ-GM-90). The Games screen focuses the tile of the game when Back returns to it.
func go_game_settings(id: String) -> void:
	last_game = id
	go(TvGameSettings, {"game_id": id})
	server.set_phase("menu")


func go_settings() -> void:
	go(TvSettings)
	server.set_phase("menu")


## Back to the Games screen. Minigames call this ("Back to menu").
func go_menu() -> void:
	Sound.duck(false)
	Sound.music("menu")
	go_games()


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
	if quit_hook.is_valid():
		quit_hook.call()
		return
	get_tree().quit()


# ---- Settings ----

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		if k != "overlay": # The debug overlay always starts off.
			cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_FILE)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	for k in settings:
		if k != "overlay":
			settings[k] = cfg.get_value("settings", k, settings[k])


# ---- TV ----

func _start_tv() -> void:
	server = TvServer.new()
	add_child(server)
	server.start(settings)
	server.language = Lang.current()
	server.player_joined.connect(func(_s): Sound.sfx("join"))
	server.player_lost.connect(func(_s): Sound.sfx("leave"))
	server.player_removed.connect(func(_s): Sound.sfx("leave"))
	overlay = DebugOverlay.new()
	overlay.visible = bool(settings.overlay)
	add_child(overlay)
	Sound.music("menu")
	go_logo()


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
	add_child(client)
	profiles = ProfileStore.new()
	profiles.load_from_disk()
	apply_profile()
	var wifi_locks := QrScanner.new()
	add_child(wifi_locks)
	wifi_locks.acquire_wifi_locks() # Less jitter on Android.
	client.state_changed.connect(_on_client_state)
	get_viewport().size_changed.connect(_apply_safe_area)   # A turn changes the safe area (REQ-FL-68).
	client.phase_changed.connect(_on_client_phase)
	client.result_received.connect(_on_result)
	client.language_changed.connect(func(code: String): set_language(code, false))
	client.rejected.connect(_on_client_rejected)
	var last: Dictionary = client.load_last()
	if String(last.get("host", "")) != "" and String(last.get("token", "")) != "":
		client.use_saved_token(String(last.token))
		go(ControllerConnect)
		client.connect_to(String(last.host), int(last.port), String(last.room))
	else:
		go(ControllerConnect)
		var join_host := _join_arg()
		if join_host != "":
			client.connect_to(join_host, Protocol.WS_PORT, "")


## For desktop runs: `--join=127.0.0.1` joins the TV at that address without a room code (the TV takes a hello with no room).
func _join_arg(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	for a in args:
		if a.begins_with("--join="):
			return a.substr(7)
	return ""


func _on_client_state(state: int) -> void:
	if state == ControllerClient.State.CONNECTED:
		last_error = ""
		_show_phone_screen()
	elif state == ControllerClient.State.IDLE:
		set_language(Lang.system_language(), false)   # Away from the TV, the phone uses its own language (REQ-FL-62).
		# A failed connection does not close the profile screens: a typed name stays (the phone works without the TV).
		if not (_screen is ControllerConnect or _screen is ControllerProfiles or _screen is ControllerProfileEdit):
			go(ControllerConnect)


## Gives the active profile (or the guest) to the client. It goes to the TV at the next join, and at once in a menu phase.
func apply_profile() -> void:
	var p = profiles.active()
	if p == null:
		client.set_profile("", "", -1)
	else:
		client.set_profile(p.id, p.player_name, p.avatar)


func _on_client_phase(phase: String) -> void:
	if phase == "playing":
		last_best = {}
	_show_phone_screen()


## The result of a round for the active profile (REQ-GM-99, 100): the profile keeps the best, and the waiting screen says
## NEW BEST! when this was one.
func _on_result(key: String, value: int) -> void:
	var done := profiles.record_best(client.pid, key, value)
	if done.new_best:
		last_best = {"pid": client.pid, "key": key, "value": value, "old": done.old}


## The NEW BEST! of the player on this phone, or an empty dictionary. A best that belongs to another profile is not shown after
## a switch of the player (REQ-GM-100).
func current_best() -> Dictionary:
	return last_best if not last_best.is_empty() and last_best.pid == client.pid else {}


## Takes the text of a scan or of the clipboard that should be a player code (FD-22, REQ-FL-76). Returns the sentence for the
## player: the player was added or updated, or why the text does not work. A change of the active profile goes to the TV.
func import_profile_text(text: String) -> String:
	if not text.strip_edges().begins_with(ProfileCode.PREFIX):
		return Lang.t("app.room_link") if not Protocol.parse_pair_url(text).is_empty() else Lang.t("app.code_does_not_work")
	var r := ProfileCode.decode(text)
	if not r.ok:
		return Lang.t("app.code_does_not_work")
	var done: Dictionary = profiles.import_profile(r.profile)
	if done.status == "full":
		return Lang.f("profiles.maximum", [ProfileStore.MAX_PROFILES])
	if done.id == profiles.active_id:
		apply_profile()
	return Lang.t("app.player_added") if done.status == "added" else Lang.t("app.player_updated")


## Leaves the profile screens: back to the waiting screen when a TV is joined, else to the Connect screen.
func leave_profile_screens() -> void:
	if client.state == ControllerClient.State.IDLE:
		go(ControllerConnect)
	else:
		go(ControllerWait)


## The pad while a game runs, the waiting screen otherwise (REQ-FL-28). The profile screens stay open while the TV is in a menu
## phase; a round (or a late join) closes them (REQ-FL-71).
func _show_phone_screen() -> void:
	if client.state == ControllerClient.State.IDLE:
		return
	if (_screen is ControllerProfiles or _screen is ControllerProfileEdit or _screen is ControllerProfileShare) \
			and client.phase in ["connect", "menu"]:
		return
	var playing: bool = client.phase in ["playing", "paused"]
	if playing and not (_screen is ControllerPad):
		go(ControllerPad)
	elif not playing and not (_screen is ControllerWait) and not (_screen is ControllerSettings) \
			and not (_screen is AboutScreen):
		go(ControllerWait)


func _on_client_rejected(reason: String) -> void:
	last_error = {
		"full": Lang.t("app.room_full_4_players"),
		"bad_room": Lang.t("app.wrong_room_code"),
		"version": Lang.t("app.app_version_does_not"),
		"unreachable": Lang.t("app.cannot_connect_room"),
		"tv_closed": Lang.t("app.tv_closed_connection"),
		"kicked": Lang.t("app.host_removed_scan_code"),
		"replaced": Lang.t("app.player_already_in_room"),
	}.get(reason, Lang.f("connect.refused", [reason]))
