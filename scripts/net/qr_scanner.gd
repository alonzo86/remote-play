extends Node
## Phone side. Glue to the plugin "QrScanner": on Android android/plugin/QrScannerPlugin.java (the build ran
## tools/patch_android_manifest.sh), on an iPhone ios/plugin/qr_scanner (built by tools/build_ios_plugin.sh, issue #299).
## Without the plugin, is_available() is false and the Connect screen has no scan button (REQ-FL-58, REQ-FL-83a).

signal scanned(text: String)
signal failed(reason: String)

const Lang = preload("res://scripts/core/lang.gd")

const PLUGIN_NAME := "QrScanner"
## The small buzz when a code is read on an iPhone (REQ-FL-89). The screens send it through `Haptics.on_message`, which
## follows the HAPTICS switch.
const BUZZ_MS := 40

## A test sets it to "iOS" or "Android".
var os_name := OS.get_name()
var _plugin: Object


## The text for a failed scan, or "" when nothing is shown (REQ-FL-90, REQ-FL-91). "cancelled" is silent (issue #43);
## "camera_denied" and "no_camera" have their own texts; any other reason keeps the old text with the reason in it.
static func failure_text(reason: String) -> String:
	match reason:
		"cancelled":
			return ""
		"camera_denied":
			return Lang.t("connect.camera_denied")
		"no_camera":
			return Lang.t("connect.no_camera")
	return Lang.f("connect.qr_failed", [reason])


## True when a good scan buzzes the phone (REQ-FL-89): an iPhone only.
func buzzes_on_scan() -> bool:
	return os_name == "iOS"


func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		_plugin.connect("scanned", func(text: String): scanned.emit(text))
		_plugin.connect("failed", func(reason: String): failed.emit(reason))


func is_available() -> bool:
	return Engine.has_singleton(PLUGIN_NAME)


func scan() -> void:
	if _plugin == null and is_available():
		_ready()
	if _plugin == null:
		failed.emit("unavailable")
		return
	if os_name == "iOS":
		# The native view has no text of its own: it gets the two texts in the language of the app (REQ-FL-63, REQ-FL-88).
		_plugin.call("scan", Lang.t("connect.scan_hint"), Lang.t("connect.scan_cancel"))
	else:
		_plugin.call("scan")


## Hold the low-latency Wi-Fi lock and the multicast lock. Needs a plugin that has the method (the Android plugin);
## the iOS plugin has none, and a desktop has no plugin. Returns true when the plugin was called.
func acquire_wifi_locks() -> bool:
	if _plugin == null and is_available():
		_ready()
	# app.gd calls this on every start, so the iOS plugin must not get a call it does not have.
	if _plugin != null and _plugin.has_method("acquireWifiLocks"):
		_plugin.call("acquireWifiLocks")
		return true
	return false
