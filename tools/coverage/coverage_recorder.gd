class_name CoverageRecorder
extends RefCounted
## Records which instrumented lines ran. tools/coverage/instrument.py puts `CoverageRecorder.h(file, line)` before
## the statements of the scripts in a copy of the project. This file is copied there too.
## When the process ends, the hits go to $COVERAGE_OUT/hits_<pid>.json. Nothing else uses it.

## Keys are file * 1000000 + line. One Dictionary, shared with the sink node.
static var _hits := {}
static var _sink: Node


static func h(file: int, line: int) -> void:
	_hits[file * 1000000 + line] = true
	if _sink == null:
		_install()


static func _install() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	_sink = Sink.new()
	_sink.hits = _hits
	(loop as SceneTree).root.add_child.call_deferred(_sink)


## A node in the tree. It writes the file when the tree is destroyed (quit).
class Sink extends Node:
	var hits: Dictionary

	func _exit_tree() -> void:
		var dir := OS.get_environment("COVERAGE_OUT")
		if dir == "" or hits.is_empty():
			return
		var f := FileAccess.open("%s/hits_%d.json" % [dir, OS.get_process_id()], FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(hits.keys()))
