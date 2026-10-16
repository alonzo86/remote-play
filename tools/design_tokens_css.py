#!/usr/bin/env python3
"""Writes docs/design-system/tokens.css from tokens.json.
Usage: tools/design_tokens_css.py          write the file
       tools/design_tokens_css.py --check  exit 1 when the file is not up to date"""
import json
import os
import sys

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "design-system")


def build() -> str:
	with open(os.path.join(DIR, "tokens.json"), encoding="utf-8") as f:
		t = json.load(f)
	out = ["/* Sababi: generated from tokens.json by tools/design_tokens_css.py. Fonts live in assets/fonts. */", ":root{"]
	for fam in ("color", "spacing", "border"):
		for k in t[fam]["tokens"]:
			out.append("  --%s: %s;" % (k["name"], k["value"]))
	for k, v in t["type"]["families"].items():
		out.append("  --font-%s: %s;" % (k, v))
	out.append("}")
	for font in t["type"]["fonts"]:
		out.append('@font-face{font-family:"%s";src:url(../../assets/%s) format("truetype");font-weight:%s}'
				% (font["family"], font["file"], font["weight"]))
	return "\n".join(out) + "\n"


def main() -> int:
	path = os.path.join(DIR, "tokens.css")
	css = build()
	if "--check" in sys.argv:
		current = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
		if current != css:
			print("docs/design-system/tokens.css is out of date. Run tools/design_tokens_css.py")
			return 1
		print("tokens.css is up to date")
		return 0
	with open(path, "w", encoding="utf-8") as f:
		f.write(css)
	return 0


sys.exit(main())
