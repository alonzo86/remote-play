#!/usr/bin/env python3
"""Line coverage for GDScript, step 3: merge the hits and write the reports.

Usage: report.py <manifest.json> <hits dir> <output dir> [--min PERCENT]

Reads `hits_*.json` files (written by coverage_recorder.gd, one for each Godot run) and the manifest
of instrument.py. Writes summary.md, summary.json and lcov.info to the output directory, and prints
the summary. With --min the exit code is 1 when the total line coverage is lower.
"""
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


def markdown(rows, total):
    out = ["## Test coverage (GDScript lines)", "",
           "**Total: %.1f%%** (%d of %d statements ran in the headless tests)" % (
               total["percent"], total["covered"], total["total"]), "",
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
        out.append("| `%s` | %d | %d | %.1f |" % (r["path"], r["covered"], r["total"], r["percent"]))
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
    args = sys.argv[1:]
    minimum = None
    if "--min" in args:
        i = args.index("--min")
        minimum = float(args[i + 1])
        del args[i:i + 2]
    if len(args) != 3:
        sys.exit(__doc__)
    manifest_path, hits_dir, out_dir = args
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    hits = load_hits(hits_dir)
    if not hits:
        sys.exit("no hits found in %s: did the tests run on the instrumented copy?" % hits_dir)
    rows = build(manifest, hits)
    covered = sum(r["covered"] for r in rows)
    count = sum(r["total"] for r in rows)
    total = {"covered": covered, "total": count, "percent": round(percent(covered, count), 1)}
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "summary.md"), "w", encoding="utf-8") as f:
        f.write(markdown(rows, total))
    with open(os.path.join(out_dir, "summary.json"), "w", encoding="utf-8") as f:
        json.dump({"total": total, "files": rows}, f, indent=1)
    with open(os.path.join(out_dir, "lcov.info"), "w", encoding="utf-8") as f:
        f.write(lcov(rows, manifest))
    print(markdown(rows, total))
    if minimum is not None and total["percent"] < minimum:
        sys.exit("coverage %.1f%% is lower than the minimum %.1f%%" % (total["percent"], minimum))


if __name__ == "__main__":
    main()
