extends Node
## Autoload "Role". Decides if this run is the TV app or the phone controller.
## Order: command line `--role=...`, then feature tag, then a fallback.

enum Kind { TV, CONTROLLER }

var kind: Kind = Kind.TV
var _touch_ui := -1   # -1 not asked yet, 0 no, 1 yes. The answer cannot change while the app runs.


func _init() -> void:
	kind = _detect()


func is_tv() -> bool:
	return kind == Kind.TV


func is_controller() -> bool:
	return kind == Kind.CONTROLLER


func _detect() -> Kind:
	return pick(OS.get_cmdline_user_args() + OS.get_cmdline_args(), OS.has_feature)


## The choice itself. `args` are the command line arguments. `has_feature` takes a feature tag and
## returns true or false. A test can call this with its own values.
static func pick(args: Array, has_feature: Callable) -> Kind:
	for arg in args:
		if arg == "--role=tv":
			return Kind.TV
		if arg == "--role=controller":
			return Kind.CONTROLLER
	if has_feature.call("controller"):
		return Kind.CONTROLLER
	if has_feature.call("tv"):
		return Kind.TV
	# No tag and no argument (for example, the editor). Phones are the safer default.
	return Kind.CONTROLLER if has_feature.call("mobile") else Kind.TV


## True on a device that is used by touch: a phone or a tablet. The TV prompts then say TAP and not PRESS OK (REQ-FL-3, 6).
## `has_system_feature` takes a name of an Android system feature and returns true or false (`system_feature`); a test gives its
## own. A phone has a touchscreen and is not a TV; an Android TV has the leanback feature (the one that the manifest
## of the TV app requires, docs/EXPORT.md) or says that it is a television, and a desktop or an unknown device keeps PRESS OK.
static func touch_ui(has_system_feature: Callable) -> bool:
	return bool(has_system_feature.call("android.hardware.touchscreen")) \
			and not bool(has_system_feature.call("android.software.leanback")) \
			and not bool(has_system_feature.call("android.hardware.type.television"))


## Asks Android if the device has a system feature (`PackageManager.hasSystemFeature`). False when this is not Android or the
## answer cannot be read: the prompts then keep PRESS OK, which is the safe text on a TV.
static func system_feature(feature: String) -> bool:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.getActivity() if runtime != null else null
	if activity == null:
		return false
	var manager: Object = activity.getPackageManager()
	return manager != null and bool(manager.hasSystemFeature(feature))


## True when the prompts of this device say TAP (a phone or a tablet).
func is_touch_ui() -> bool:
	if _touch_ui < 0:
		_touch_ui = 1 if touch_ui(system_feature) else 0
		if OS.has_feature("android"):
			print("Role: touch prompts %s (touchscreen %s, leanback %s, television %s)" % [_touch_ui == 1,
					system_feature("android.hardware.touchscreen"), system_feature("android.software.leanback"),
					system_feature("android.hardware.type.television")])
	return _touch_ui == 1


## A real touch on a phone or a tablet proves that the device is a touch device, whatever Android answered (the answer cannot be
## read on some devices). A TV is used with a remote and never gets a touch. A mouse on a desktop does not count.
func note_touch() -> void:
	if _touch_ui != 1 and OS.has_feature("mobile"):
		_touch_ui = 1
