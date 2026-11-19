extends Node
## Autoload "App". Owns the services and switches screens.
## TV role: server, debug overlay, menu and minigames.
## Controller role: client, connect screen and pad screen.

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Registry = preload("res://scripts/game/registry.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const Backdrop = preload("res://scripts/ui/backdrop.gd")
const JoinRequests = preload("res://scripts/ui/join_requests.gd")
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
const ControllerProfileEdit = preload("res://scripts/ui/controller_profile_edit.gd")
const ControllerProfileShare = preload("res://scripts/ui/controller_profile_share.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const ConfigIO = preload("res://scripts/core/config_io.gd")

const SETTINGS_FILE := "user://settings.cfg"

## Shared with every Orientation object. Changes apply at once.
var settings := {
	"invert_tilt": false,
	"overlay": false,
	"approve_players": true,   # TV: the host lets each new phone in (REQ-FL-93, issue #393). ON by default.
	"music_volume": 7,   # TV: 0 to 10 (REQ-FL-64)
	"sfx_volume": 8,     # TV: 0 to 10
	"haptics": true,     # Phone: vibrate in games (REQ-FL-66)
	"language": "",   # "en" or "he". Empty until the owner chooses on the logo screen (TV) (REQ-FL-60).
}

var theme_res: Theme
var server: Node            # TV only
var overlay: CanvasLayer    # TV only, and only when `debug_tools` is true (a debug build).
## The debug overlay and its keys exist only in a debug build (owner, 2026-11-18): a release build (the store bundles) has no
## overlay, no Menu or F3 key for it and no Settings row. A test may set it to check a release build.
var debug_tools := OS.is_debug_build()
var join_requests: CanvasLayer   # TV only. The card of a phone that asks to join (issue #393, FD-30.12).
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


## Switches the UI at once (REQ-FL-61). On the TV the choice is saved and goes to the phones (they ignore it). A phone saves
## the choice of its own Settings screen too (REQ-FL-62); it never follows the TV.
func set_language(code: String, remember := true) -> void:
	if not (code in Lang.CODES):
		return
	Lang.set_language(code, get_tree().root)
	UiTheme.refresh_line_gaps(self)   # The open screen: the Hebrew final letters need a larger gap (issue #403).
	if remember:
		settings.language = code
		save_settings()
	if Role.is_tv() and server != null:
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
		# In a game, OK does nothing (REQ-GM-31), so it has no sound either. On a dim game tile OK plays `denied` only (TvGames).
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
	if join_requests != null:
		move_child(join_requests, -1)   # The card layer is the last child: its keys come first (issue #393, 7.2).
		join_requests.on_screen_changed()


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
	Sound.prepare_song(id)   # The song is made while the players choose, so the first round has music (issue #149).
	go(TvGameSettings, {"game_id": id})
	server.set_phase("menu")
	server.set_setup(bool(Registry.find(id).get("swing", false)), not bool(Registry.find(id).get("enroll", false)))


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


## The join card consumed a BACK key: the notification of the same press (up to 250 ms later) is dropped by `_back()`.
func note_back() -> void:
	_last_back_ms = Time.get_ticks_msec()


func _back() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back_ms < 250:
		return # The same press can arrive as a key and as a notification.
	_last_back_ms = now
	if join_requests != null and join_requests.is_open():
		return # BACK does nothing while a join card shows (owner, D12).
	if _screen != null and _screen.has_method("on_back"):
		_screen.on_back()
		# A screen can take longer than 250 ms to build. The second event of the same press waits in the queue
		# meanwhile, so the time is counted from the end (issue #134).
		_last_back_ms = Time.get_ticks_msec()
	else:
		_quit()


## A phone asks to end the game (REQ-FL-52c): the screen that runs the game does what Back on the TV remote does.
func _on_leave_asked(slot: int) -> void:
	if _screen != null and _screen.has_method("request_leave"):
		_screen.request_leave(slot)


func _quit() -> void:
	if server != null:
		if server.stop() and not quit_hook.is_valid():
			# The phones get "bye" and the close handshake needs a moment; then the TV closes (issue #169).
			await get_tree().create_timer(0.45).timeout
	if client != null:
		client.leave()
	if quit_hook.is_valid():
		quit_hook.call()
		return
	get_tree().quit()


# ---- Settings ----

## Returns false when the file could not be written; the settings stay in memory (issue #309).
func save_settings(path := SETTINGS_FILE) -> bool:
	var cfg := ConfigFile.new()
	for k in settings:
		if k != "overlay": # The debug overlay always starts off.
			cfg.set_value("settings", k, settings[k])
	return ConfigIO.save(cfg, path)


## A value of the wrong type in the file keeps the default (the first start choice for `language`); a volume is cut to 0..10.
func _load_settings(path := SETTINGS_FILE) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k in settings:
		if k != "overlay":
			settings[k] = ConfigIO.fit(cfg.get_value("settings", k, settings[k]), settings[k])
	settings.music_volume = clampi(settings.music_volume, 0, 10)
	settings.sfx_volume = clampi(settings.sfx_volume, 0, 10)
	if not (settings.language == "" or settings.language in Lang.CODES):
		settings.language = ""
	# The Mute row is gone (issue #49): keep the silence of an old file.
	if ConfigIO.fit(cfg.get_value("settings", "mute", false), false):
		settings.music_volume = 0
		settings.sfx_volume = 0


# ---- TV ----

func _start_tv() -> void:
	server = TvServer.new()
	add_child(server)
	server.set_approve_new(bool(settings.approve_players))   # Before start(): the setter, never the member (FD-30.3).
	server.start(settings)
	server.language = Lang.current()
	server.leave_asked.connect(_on_leave_asked)
	server.player_joined.connect(func(_s): Sound.sfx("join"))
	server.player_lost.connect(func(_s): Sound.sfx("leave"))
	server.player_removed.connect(func(_s): Sound.sfx("leave"))
	if debug_tools:
		overlay = DebugOverlay.new()
		overlay.visible = bool(settings.overlay)
		add_child(overlay)
	join_requests = JoinRequests.new()
	add_child(join_requests)
	join_requests.setup(server)
	Sound.music("menu")
	go_logo()


func toggle_overlay() -> void:
	set_overlay(not bool(settings.overlay))


func set_overlay(on: bool) -> void:
	if not debug_tools or overlay == null:
		return   # A release build has no overlay.
	settings.overlay = on
	overlay.visible = on
	save_settings()


## The setting "approve new players" (REQ-FL-93). OFF refuses the phones that wait (REQ-FL-102).
func set_approve_players(on: bool) -> void:
	settings.approve_players = on
	save_settings()
	if server != null:
		server.set_approve_new(on)


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


## For desktop runs: `--join=127.0.0.1` joins the TV at that address without a room code (only a debug TV takes a hello
## with no room).
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
		last_best = {}   # The player left: the message never shows without its game (REQ-GM-100).
		# A failed connection does not close the profile screens: a typed name stays (the phone works without the TV).
		if not (_screen is ControllerConnect or _screen is ControllerProfileEdit or _screen is ControllerProfileShare):
			go(ControllerConnect)


## Gives the active profile (or the guest) to the client. It goes to the TV at the next join, and at once in a menu phase.
func apply_profile() -> void:
	var p = profiles.active()
	if p == null:
		client.set_profile("", "", -1)
	else:
		client.set_profile(p.id, p.player_name, p.avatar)


func _on_client_phase(phase: String) -> void:
	if not phase in ["playing", "paused"]:
		last_best = {}   # NEW BEST! belongs to the result of its game: it is gone when the TV goes back to the menu (REQ-GM-100).
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
## a switch of the player. It shows only while the phone is joined and in the game phases, where the result of the game is open:
## never on the waiting screen, after the player left, or when the TV is back at the menu (REQ-GM-100).
func current_best() -> Dictionary:
	if last_best.is_empty() or last_best.pid != client.pid:
		return {}
	if client.state != ControllerClient.State.CONNECTED or not client.phase in ["playing", "paused"]:
		return {}
	return last_best


## The ID of the player that the last scan added or updated; empty when the last scan was refused (REQ-FL-76).
var last_import_id := ""


## Takes the text of a scan that should be a player code (FD-22, REQ-FL-76). Returns the sentence for the
## player: the player was added or updated, or why the text does not work. A player that was added or updated becomes the
## selected player (`last_import_id`), and the change goes to the TV.
func import_profile_text(text: String) -> String:
	last_import_id = ""
	if not text.strip_edges().begins_with(ProfileCode.PREFIX):
		return Lang.t("app.room_link") if not Protocol.parse_pair_url(text).is_empty() else Lang.t("app.code_does_not_work")
	var r := ProfileCode.decode(text)
	if not r.ok:
		return Lang.t("app.code_does_not_work")
	var done: Dictionary = profiles.import_profile(r.profile)
	if done.status == "full":
		return Lang.f("profiles.maximum", [ProfileStore.MAX_PROFILES])
	profiles.set_active(done.id)
	apply_profile()
	last_import_id = done.id
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
	if (_screen is ControllerProfileEdit or _screen is ControllerProfileShare) \
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
		"refused": Lang.t("connect.approval_refused"),   # The join approval (issue #393, REQ-FL-101, REQ-FL-103).
		"timeout": Lang.t("connect.approval_timeout"),
		"busy": Lang.t("connect.approval_busy"),
		"wait_lost": Lang.t("connect.room_not_found"),
	}.get(reason, Lang.f("connect.refused", [reason]))
