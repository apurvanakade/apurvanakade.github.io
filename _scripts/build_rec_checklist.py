#!/usr/bin/env python3
"""AI-owned: builds rec-letters-checklist.pdf from rec-letters.qmd.

    make checklist        (or: python3 _scripts/build_rec_checklist.py)

A one-page PDF of the recommendation-letters checklist, for local use only.
It is cut from the page itself, from `## Documents to Send` to the end, so the
checklist has one source and cannot drift. Pandoc renders the `- [ ]` items as
empty boxes.

Like the CV and teaching-portfolio PDFs, it is written to the gitignored
_pdf/ folder with the local LaTeX; it is neither committed nor published.
"""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "rec-letters.qmd"
OUT = ROOT / "_pdf" / "rec-letters-checklist.pdf"
START = "## Documents to Send"

HEADER = r"""\usepackage{enumitem}
\setlist[itemize]{itemsep=3pt}
\pagestyle{empty}
\makeatletter\let\ps@plain\ps@empty\makeatother  % the title page too
"""


def main():
    text = SRC.read_text()
    if START not in text:
        raise SystemExit(f"{SRC.name}: no '{START}' heading")
    body = text[text.index(START):]

    OUT.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        md = pathlib.Path(d) / "checklist.md"
        hdr = pathlib.Path(d) / "header.tex"
        md.write_text(body + "\n")
        hdr.write_text(HEADER)
        subprocess.run([
            "quarto", "pandoc", str(md), "-o", str(OUT),
            "--pdf-engine=lualatex",
            "--include-in-header", str(hdr),
            "-M", "title=Recommendation letter checklist",
            "-M", "subtitle=Apurva Nakade · apurvanakade.github.io/rec-letters.html",
            "-V", "mainfont=TeX Gyre Heros",
            "-V", "fontsize=11pt",
            "-V", "geometry:margin=1in",
            "-V", "colorlinks=true", "-V", "urlcolor=black", "-V", "linkcolor=black",
        ], check=True)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
