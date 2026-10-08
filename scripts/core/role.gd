extends Node
## Autoload "Role". Decides if this run is the TV app or the phone controller.
## Order: command line `--role=...`, then feature tag, then a fallback.

enum Kind { TV, CONTROLLER }

var kind: Kind = Kind.TV


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
