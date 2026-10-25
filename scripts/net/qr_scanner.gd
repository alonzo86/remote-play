extends Node
## Phone side. Glue to the Android plugin "QrScanner" (android/plugin/QrScannerPlugin.java).
## The plugin exists only in Android builds that ran tools/patch_android_manifest.sh.
## Without it, is_available() is false and the Connect screen has no scan button.

signal scanned(text: String)
signal failed(reason: String)

const PLUGIN_NAME := "QrScanner"

var _plugin: Object


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
	_plugin.call("scan")


## Hold the low-latency Wi-Fi lock and the multicast lock (needs the plugin, no-op elsewhere).
func acquire_wifi_locks() -> void:
	if _plugin == null and is_available():
		_ready()
	if _plugin != null:
		_plugin.call("acquireWifiLocks")
