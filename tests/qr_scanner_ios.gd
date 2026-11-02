extends SceneTree
## The iPhone QR scanner on the GDScript side (issue #299, REQ-FL-58, REQ-FL-88 to 92), with a fake plugin: the call with the
## two texts, the guard of the Wi-Fi lock call, the scan button without an OS check, the text of each reason, the buzz.
## The native plugin (ios/plugin/qr_scanner) cannot run here: Manual test 33.
## Run: godot --headless --path . --script tests/qr_scanner_ios.gd -- --role=controller

const Lang = preload("res://scripts/core/lang.gd")

var _checks := 0
var _fails := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A stand-in for the iOS plugin "QrScanner" (ios/plugin/qr_scanner): scan() takes the two texts, is_supported() says
## whether VisionKit runs on the phone (A12 chip or newer), and there is no acquireWifiLocks.
class FakeIosQrPlugin extends Object:
	signal scanned(text: String)
	signal failed(reason: String)
	var scans: Array = []
	var supported := true

	func is_supported() -> bool:
		return supported

	func scan(hint: String, cancel: String) -> void:
		scans.append([hint, cancel])


## A stand-in for the Android plugin: it has no is_supported(), so it is always supported.
class FakeAndroidQrPlugin extends Object:
	signal scanned(text: String)
	signal failed(reason: String)


## The iPhone scanner (issue #299, REQ-FL-58, 88 to 92): the call with the two texts, the Wi-Fi lock guard, the button
## without the OS check, the texts of the reasons and the buzz.
func _run() -> void:
	var qr_script: GDScript = load("res://scripts/net/qr_scanner.gd")
	var app: Node = root.get_node("App")
	var connect_script: GDScript = load("res://scripts/ui/controller_connect.gd")
	print("qr scanner on an iPhone")
	var fake := FakeIosQrPlugin.new()
	Engine.register_singleton("QrScanner", fake)
	var ios = qr_script.new()
	ios.os_name = "iOS"
	root.add_child(ios)
	ios.scan()
	_check(fake.scans == [[Lang.t("connect.scan_hint"), Lang.t("connect.scan_cancel")]],
			"on iOS scan() passes the hint and the CANCEL text in the language of the app: %s" % str(fake.scans))
	Lang.set_language("he", root)
	ios.scan()
	_check(fake.scans[1] == [Lang.t("connect.scan_hint"), Lang.t("connect.scan_cancel")]
			and fake.scans[1][1] != fake.scans[0][1], "in Hebrew the texts are the Hebrew ones: %s" % str(fake.scans[1]))
	Lang.set_language("en", root)
	_check(ios.acquire_wifi_locks() == false, "a plugin with no acquireWifiLocks is not called (the iOS plugin)")
	_check(ios.is_available(), "a plugin that is_supported() is available")
	fake.supported = false
	_check(not ios.is_available(), "a phone older than the A12 chip (is_supported() false) is not available (REQ-FL-58)")
	fake.supported = true
	Engine.unregister_singleton("QrScanner")
	var android_fake := FakeAndroidQrPlugin.new()
	Engine.register_singleton("QrScanner", android_fake)
	_check(ios.is_available(), "a plugin with no is_supported() (the Android plugin) is available")
	Engine.unregister_singleton("QrScanner")
	android_fake.free()
	Engine.register_singleton("QrScanner", fake)
	var texts: Array = []
	var fails: Array = []
	ios.scanned.connect(func(t): texts.append(t))
	ios.failed.connect(func(r): fails.append(r))
	fake.scanned.emit("ws://192.168.1.20:47801/KQZM")
	fake.failed.emit("camera_denied")
	_check(texts == ["ws://192.168.1.20:47801/KQZM"] and fails == ["camera_denied"], "the signals of the iOS plugin come out")

	# The Connect screen has the scan button on an iPhone that has the plugin (REQ-FL-58), and not without it.
	var screen = connect_script.new()
	screen.os_name = "iOS"
	screen.theme = app.theme_res
	root.add_child(screen)
	await process_frame
	var shown: Array = screen.find_children("*", "Button", true, false).map(func(b): return b.text)
	_check(shown.has("connect.scan_qr_code"), "an iPhone with the plugin has the SCAN QR CODE button: %s" % str(shown))
	# REQ-FL-90 / 91: a cancel shows nothing; a refusal and no camera have their own text; any other reason the old text.
	app.last_error = ""
	screen._on_qr_failed("cancelled")
	_check(screen._status.text == "" and app.last_error == "", "a cancelled scan shows no message")
	screen._on_qr_failed("camera_denied")
	_check(screen._status.text == Lang.t("connect.camera_denied").to_upper(),
			"camera_denied shows the camera text: '%s'" % screen._status.text)
	screen._on_qr_failed("no_camera")
	_check(screen._status.text == Lang.t("connect.no_camera").to_upper(), "no_camera shows its text: '%s'" % screen._status.text)
	screen._on_qr_failed("error")
	_check(screen._status.text == Lang.f("connect.qr_failed", ["error"]).to_upper(),
			"another reason keeps the QR SCAN FAILED text: '%s'" % screen._status.text)

	# REQ-FL-89: one buzz when a code is read on an iPhone, only with HAPTICS on; none on Android.
	var haptics: GDScript = load("res://scripts/game/haptics.gd")
	var buzzes: Array = []
	haptics.vibrate_call = func(ms: int) -> void: buzzes.append(ms)
	var old_haptics: bool = app.settings.get("haptics", true)
	app.settings.haptics = true
	screen._on_qr_text("https://example.com")
	_check(buzzes == [qr_script.BUZZ_MS], "a scan on an iPhone buzzes once with HAPTICS on: %s" % str(buzzes))
	app.settings.haptics = false
	screen._on_qr_text("https://example.com")
	_check(buzzes.size() == 1, "and not with HAPTICS off")
	app.settings.haptics = true
	screen._qr.os_name = "Android"
	screen._on_qr_text("https://example.com")
	_check(buzzes.size() == 1, "an Android scan does not buzz")
	app.settings.haptics = old_haptics
	haptics.vibrate_call = Callable()
	screen.queue_free()
	ios.queue_free()
	Engine.unregister_singleton("QrScanner")
	fake.free()
	await process_frame
	var plain = connect_script.new()
	plain.os_name = "iOS"
	plain.theme = app.theme_res
	root.add_child(plain)
	await process_frame
	_check(not plain.find_children("*", "Button", true, false).any(func(b): return b.text == "connect.scan_qr_code"),
			"an iPhone build without the plugin has no scan button")
	plain.queue_free()
	await process_frame
	_done()


func _done() -> void:
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
