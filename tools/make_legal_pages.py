#!/usr/bin/env python3
"""Writes the privacy and terms pages of the website (site/) from the texts of docs/legal/ (issue #37).
Usage: tools/make_legal_pages.py          write the four pages (en and he)
       tools/make_legal_pages.py --check  exit 1 when a page is not up to date (tests/legal_pages.gd runs it)

The header, the navigation and the footer of each page stay as they are in the file: only the <title> and the part between
<main> and </main> are written from the Markdown text. The text is converted as it is: nothing is added, cut or reworded, so the
pages say what the Markdown text says. The Markdown subset is the one that the four texts use:
# and ## headings, paragraphs (a line break stays a line break), "- " lists, one table, **bold**, `code`, [text](url), <url>
and e-mail addresses (and the <div dir="rtl" lang="he"> wrapper of the Hebrew texts, which is left out). A line that this converter does not know makes it stop with an error, so a new kind of line is noticed."""
import html
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PAGES = [  # (Markdown text, page)
	("docs/legal/privacy-notice.md", "site/privacy.html"),
	("docs/legal/privacy-notice.he.md", "site/he/privacy.html"),
	("docs/legal/terms.md", "site/terms.html"),
	("docs/legal/terms.he.md", "site/he/terms.html"),
]
SITE_TITLE = {"en": "Sababi", "he": "Sababi"}
# A line that starts like another kind of Markdown block (a quote, a numbered or starred list, code, a rule, an indented line).
UNKNOWN = re.compile(r"^(>|\d+[.)] |[*+] |\s+\S|---|===|```|~~~|\[[^\]]+\]:)")
INLINE = re.compile(r"<(https?://[^>\s]+)>|\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|([\w.+-]+@[\w-]+(?:\.[\w-]+)*\.[A-Za-z]{2,})")


def inline(text: str) -> str:
	out = []
	pos = 0
	for m in INLINE.finditer(text):
		out.append(plain(text[pos:m.start()]))
		if m.group(1):
			out.append('<a href="%s">%s</a>' % (html.escape(m.group(1)), html.escape(m.group(1), quote=False)))
		elif m.group(2) is not None:
			out.append("<strong>%s</strong>" % inline(m.group(2)))
		elif m.group(3):
			out.append("<code>%s</code>" % html.escape(m.group(3), quote=False))
		elif m.group(4):
			out.append('<a href="%s">%s</a>' % (html.escape(m.group(5)), inline(m.group(4))))
		else:
			out.append('<a href="mailto:%s">%s</a>' % (m.group(6), m.group(6)))
		pos = m.end()
	out.append(plain(text[pos:]))
	return "".join(out)


def plain(text: str) -> str:
	"""Text between the marked parts: escaped. A mark that the converter does not know (*italic*, _italic_, a backslash escape)
	stops it, because it would be written as it is, wrongly."""
	if "*" in text or "\\" in text or re.search(r"(^|\s)_\S", text):
		raise SystemExit("emphasis or escape that the converter does not know: %r" % text)
	return html.escape(text, quote=False)


def cells(line: str) -> list:
	return [c.strip() for c in line.strip().strip("|").split("|")]


def convert(markdown: str) -> tuple:
	"""Returns (the title, the HTML of <main>)."""
	lines = markdown.replace("\r\n", "\n").split("\n")
	out = []
	title = ""
	i = 0
	while i < len(lines):
		line = lines[i]
		if line.strip() == "":
			i += 1
		elif line.strip() in ('<div dir="rtl" lang="he">', "</div>"):
			i += 1   # The wrapper that makes a Markdown viewer lay the Hebrew text out right to left: the page is already so.
		elif line.startswith("# "):
			title = line[2:].strip()
			out.append("<h1>%s</h1>" % inline(title))
			i += 1
		elif line.startswith("## "):
			out.append("<h2>%s</h2>" % inline(line[3:].strip()))
			i += 1
		elif line.startswith("- "):
			out.append("<ul>")
			while i < len(lines) and lines[i].startswith("- "):
				out.append("<li>%s</li>" % inline(lines[i][2:].strip()))
				i += 1
				if i < len(lines) and lines[i].strip() != "" and not lines[i].startswith(("- ", "#", "|")):
					raise SystemExit("a list item goes on in the next line (not known to the converter): %r" % lines[i])
			out.append("</ul>")
		elif line.startswith("|"):
			rows = []
			while i < len(lines) and lines[i].startswith("|"):
				rows.append(lines[i])
				i += 1
			if len(rows) < 3 or not re.fullmatch(r"\|[-| :]+\|", rows[1].strip()):
				raise SystemExit("a table needs a header row and a separator row: %r" % rows[0])
			width = len(cells(rows[0]))
			for r in rows:
				if len(cells(r)) != width or "\\|" in r:
					raise SystemExit("a table row with another number of cells (or an escaped |): %r" % r)
			out.append('<div class="table-wrap"><table>')
			out.append("<thead><tr>%s</tr></thead>" % "".join("<th>%s</th>" % inline(c) for c in cells(rows[0])))
			out.append("<tbody>")
			for r in rows[2:]:
				out.append("<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in cells(r)))
			out.append("</tbody></table></div>")
		elif UNKNOWN.match(line) or line.startswith("#"):   # "#" is a heading level ("### ") or a text that it does not know.
			raise SystemExit("this kind of line is not known to the converter: %r" % line)
		else:
			para = []
			while i < len(lines) and lines[i].strip() != "" and not lines[i].startswith(("#", "- ", "|")):
				if UNKNOWN.match(lines[i]):
					raise SystemExit("this kind of line is not known to the converter: %r" % lines[i])
				para.append(lines[i].strip())
				i += 1
			out.append("<p>%s</p>" % "<br>\n".join(inline(p) for p in para))
	return title, "\n".join(out)


def build(md_path: str, page_path: str) -> str:
	with open(os.path.join(ROOT, md_path), encoding="utf-8", newline="") as f:
		title, body = convert(f.read())
	with open(os.path.join(ROOT, page_path), encoding="utf-8", newline="") as f:
		page = f.read()
	lang = "he" if "/he/" in page_path else "en"
	page, n = re.subn(r"<title>.*?</title>", lambda _m: "<title>%s | %s</title>" % (html.escape(title, quote=False), SITE_TITLE[lang]), page, count=1)
	if n != 1:
		raise SystemExit("no <title> in " + page_path)
	page, n = re.subn(r"<main>.*?</main>", lambda _m: "<main>\n%s\n</main>" % body, page, count=1, flags=re.S)
	if n != 1:
		raise SystemExit("no <main> in " + page_path)
	return page


def main() -> int:
	check = "--check" in sys.argv[1:]
	stale = []
	for md_path, page_path in PAGES:
		new = build(md_path, page_path)
		path = os.path.join(ROOT, page_path)
		with open(path, encoding="utf-8", newline="") as f:
			old = f.read()
		if new != old:
			stale.append(page_path)
			if not check:
				with open(path, "w", encoding="utf-8", newline="") as f:
					f.write(new)
				print("wrote", page_path)
	if check and stale:
		print("not up to date (run tools/make_legal_pages.py): " + ", ".join(stale))
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main())
