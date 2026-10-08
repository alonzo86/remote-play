#!/usr/bin/env python3
"""Line coverage for GDScript, step 1: copy the project and instrument the scripts.

Godot 4.7 has no coverage switch. This tool parses every script in `scripts/` with the parser of
gdtoolkit (the same one that gdlint uses) and puts one call `Cov.h(file, line)` before each
statement inside a function. A statement is counted when it starts on its own line. A statement
that shares its line with a header (`if x: return`) is covered by the header line.
The copy has the recorder `coverage_recorder.gd` (a global class, so no script needs a constant for it)
and a manifest of all counted lines.

Usage: instrument.py <project dir> <output dir>
"""
import json
import os
import shutil
import sys

from gdtoolkit.parser import parser

# Statements that can start a line inside a function body.
STATEMENTS = {
    "pass_stmt", "return_stmt", "func_var_stmt", "break_stmt", "breakpoint_stmt", "continue_stmt",
    "expr_stmt", "const_stmt", "if_stmt", "while_stmt", "for_stmt", "for_stmt_typed", "match_stmt",
}
FUNCTIONS = {"func_def", "static_func_def"}
# "coverage" is tools/coverage: the copy gets the recorder in its root, so the class is defined once.
IGNORE = shutil.ignore_patterns(".git", ".godot", "build", "*.apk", "*.aab", "__pycache__", "coverage")


def statement_lines(tree, lines):
    """Return the 1-based lines of the counted statements of one script."""
    found = set()

    def walk(node, in_func):
        for child in node.children:
            if not hasattr(child, "data"):
                continue
            name = str(child.data)
            inside = in_func or name in FUNCTIONS
            if inside and name in STATEMENTS and child.meta and not child.meta.empty:
                line = child.meta.line
                text = lines[line - 1]
                indent = len(text) - len(text.lstrip("\t "))
                if child.meta.column - 1 == indent:
                    found.add(line)
            walk(child, inside)

    walk(tree, False)
    return sorted(found)


def instrument(path, file_id):
    with open(path, encoding="utf-8") as f:
        source = f.read()
    lines = source.split("\n")
    tree = parser.parse(source, gather_metadata=True)
    counted = statement_lines(tree, lines)
    wanted = set(counted)
    out = []
    for number, text in enumerate(lines, start=1):
        if number in wanted:
            indent = text[: len(text) - len(text.lstrip("\t "))]
            out.append("%sCoverageRecorder.h(%d, %d)" % (indent, file_id, number))
        out.append(text)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    return counted


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=IGNORE)
    shutil.copy(os.path.join(src, "tools", "coverage", "coverage_recorder.gd"),
                os.path.join(dst, "coverage_recorder.gd"))
    files = []
    for root, _dirs, names in os.walk(os.path.join(dst, "scripts")):
        for name in sorted(names):
            if not name.endswith(".gd"):
                continue
            full = os.path.join(root, name)
            counted = instrument(full, len(files))
            files.append({"id": len(files), "path": os.path.relpath(full, dst).replace(os.sep, "/"),
                          "lines": counted})
    files.sort(key=lambda f: f["path"])
    with open(os.path.join(dst, "coverage_manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"files": files}, f)
    print("instrumented %d scripts, %d statements" % (len(files), sum(len(x["lines"]) for x in files)))


if __name__ == "__main__":
    main()
