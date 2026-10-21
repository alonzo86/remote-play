extends RefCounted
## Tells a test whether it runs in the instrumented copy of the coverage run (tools/coverage.sh, CI). The copy counts every line,
## so it is several times slower. A check about wall-clock time keeps its strict limit on a normal run and uses `limit()` there.
## The checks are never removed: only the number grows. The copy is recognised by its manifest file.


static func instrumented() -> bool:
	return FileAccess.file_exists("res://coverage_manifest.json") or OS.get_environment("COVERAGE_OUT") != ""


## `strict` on a normal run, `strict * factor` in the instrumented copy.
static func limit(strict: float, factor: float = 4.0) -> float:
	return strict * factor if instrumented() else strict
