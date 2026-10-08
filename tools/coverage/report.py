#!/usr/bin/env python3
"""Line coverage for GDScript, step 3: merge the hits and write the reports.

Usage: report.py <manifest.json> <hits dir> <output dir> [--min PERCENT] [--min-file PERCENT]
                 [--exclusions FILE]

Reads `hits_*.json` files (written by coverage_recorder.gd, one for each Godot run) and the manifest
of instrument.py. Writes summary.md, summary.json and lcov.info to the output directory, and prints
the summary. The exit code is 1 when
  - the total line coverage is lower than --min, or
  - a module (a script file) is lower than --min-file and is not in the exclusions file.
The exclusions file lists the modules that are set aside for now, one for each line: `path | reason`.
A line that starts with # is a comment. A set-aside module needs a reason, and the path must exist.
"""
import argparse
import glob
import json
import os
import sys


def load_hits(hits_dir):
    hits = set()
    for path in glob.glob(os.path.join(hits_dir, "hits_*.json")):
        with open(path, encoding="utf-8") as f:
            hits.update(int(k) for k in json.load(f))
    return hits


def percent(covered, total):
    return 100.0 if total == 0 else 100.0 * covered / total


def build(manifest, hits):
    rows = []
    for item in manifest["files"]:
        counted = item["lines"]
        covered = [n for n in counted if item["id"] * 1000000 + n in hits]
        rows.append({
            "path": item["path"], "total": len(counted), "covered": len(covered),
            "percent": round(percent(len(covered), len(counted)), 1),
            "missed": [n for n in counted if n not in set(covered)],
        })
    rows.sort(key=lambda r: r["path"])
    return rows


def folder(path):
    parts = path.split("/")
    return "/".join(parts[:3]) if len(parts) > 3 else "/".join(parts[:-1])


def load_exclusions(path, known_paths):
    """Return {path: reason}. Raises ValueError for a line without a reason or for an unknown path."""
    result = {}
    if not path or not os.path.exists(path):
        return result
    with open(path, encoding="utf-8") as f:
        for number, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            module, _, reason = (part.strip() for part in line.partition("|"))
            if not reason:
                raise ValueError("%s:%d: a set-aside module needs a reason (`path | reason`)" % (path, number))
            if module not in known_paths:
                raise ValueError("%s:%d: %s is not a script of the project" % (path, number, module))
            result[module] = reason
    return result


def failing_modules(rows, minimum, excluded):
    """Modules below the minimum that are not set aside."""
    return [r for r in rows if r["percent"] < minimum and r["path"] not in excluded]


def markdown(rows, total, minimum=None, excluded=None):
    excluded = excluded or {}
    below = failing_modules(rows, minimum, excluded) if minimum is not None else []
    out = ["## Test coverage (GDScript lines)", "",
           "**Total: %.1f%%** (%d of %d statements ran in the headless tests)" % (
               total["percent"], total["covered"], total["total"]), ""]
    if minimum is not None:
        if below:
            out += ["**%d module%s below the minimum of %g%%:** %s" % (
                len(below), "" if len(below) == 1 else "s", minimum, ", ".join("`%s` (%.1f%%)" % (r["path"], r["percent"]) for r in below)), ""]
        else:
            out += ["Every module is at %g%% or more%s." % (minimum, " (except the ones set aside)" if excluded else ""), ""]
    out += [
           "Counted: statements inside functions in `scripts/`. Tests run: `tests/run_tests.gd` and `tests/smoke_tv.gd`.",
           "", "### By folder", "", "| Folder | Covered | Statements | % |", "|---|---:|---:|---:|"]
    groups = {}
    for r in rows:
        g = groups.setdefault(folder(r["path"]), [0, 0])
        g[0] += r["covered"]
        g[1] += r["total"]
    for name in sorted(groups):
        c, t = groups[name]
        out.append("| `%s` | %d | %d | %.1f |" % (name, c, t, percent(c, t)))
    out += ["", "### By file", "", "| File | Covered | Statements | % |", "|---|---:|---:|---:|"]
    for r in sorted(rows, key=lambda r: (r["percent"], r["path"])):
        mark = " (set aside)" if r["path"] in excluded else ""
        out.append("| `%s`%s | %d | %d | %.1f |" % (r["path"], mark, r["covered"], r["total"], r["percent"]))
    if excluded:
        out += ["", "### Set aside for later", "", "| Module | Reason |", "|---|---|"]
        for module in sorted(excluded):
            out.append("| `%s` | %s |" % (module, excluded[module]))
    return "\n".join(out) + "\n"


def lcov(rows, manifest):
    lines_of = {f["path"]: f["lines"] for f in manifest["files"]}
    out = []
    for r in rows:
        missed = set(r["missed"])
        out.append("TN:")
        out.append("SF:%s" % r["path"])
        for n in lines_of[r["path"]]:
            out.append("DA:%d,%d" % (n, 0 if n in missed else 1))
        out.append("LF:%d" % r["total"])
        out.append("LH:%d" % r["covered"])
        out.append("end_of_record")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("manifest")
    ap.add_argument("hits_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--min", type=float, default=None, help="minimum total percent")
    ap.add_argument("--min-file", type=float, default=None, help="minimum percent of every module")
    ap.add_argument("--exclusions", default=None, help="file with the modules that are set aside")
    args = ap.parse_args()
    with open(args.manifest, encoding="utf-8") as f:
        manifest = json.load(f)
    hits = load_hits(args.hits_dir)
    if not hits:
        sys.exit("no hits found in %s: did the tests run on the instrumented copy?" % args.hits_dir)
    rows = build(manifest, hits)
    try:
        excluded = load_exclusions(args.exclusions, {r["path"] for r in rows})
    except ValueError as err:
        sys.exit(str(err))
    covered = sum(r["covered"] for r in rows)
    count = sum(r["total"] for r in rows)
    total = {"covered": covered, "total": count, "percent": round(percent(covered, count), 1)}
    os.makedirs(args.out_dir, exist_ok=True)
    text = markdown(rows, total, args.min_file, excluded)
    with open(os.path.join(args.out_dir, "summary.md"), "w", encoding="utf-8") as f:
        f.write(text)
    with open(os.path.join(args.out_dir, "summary.json"), "w", encoding="utf-8") as f:
        json.dump({"total": total, "files": rows, "set_aside": excluded}, f, indent=1)
    with open(os.path.join(args.out_dir, "lcov.info"), "w", encoding="utf-8") as f:
        f.write(lcov(rows, manifest))
    print(text)
    if args.min is not None and total["percent"] < args.min:
        sys.exit("coverage %.1f%% is lower than the minimum %.1f%%" % (total["percent"], args.min))
    if args.min_file is not None:
        below = failing_modules(rows, args.min_file, excluded)
        if below:
            sys.exit("%d module(s) below %g%%: %s\nWrite tests for them, or set them aside with a reason in %s" % (
                len(below), args.min_file, ", ".join("%s (%.1f%%)" % (r["path"], r["percent"]) for r in below),
                args.exclusions or "tools/coverage/exclusions.txt"))


if __name__ == "__main__":
    main()
