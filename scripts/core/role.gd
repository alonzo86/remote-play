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
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg == "--role=tv":
			return Kind.TV
		if arg == "--role=controller":
			return Kind.CONTROLLER
	if OS.has_feature("controller"):
		return Kind.CONTROLLER
	if OS.has_feature("tv"):
		return Kind.TV
	# No tag and no argument (for example, the editor). Phones are the safer default.
	return Kind.CONTROLLER if OS.has_feature("mobile") else Kind.TV
