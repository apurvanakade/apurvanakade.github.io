#!/usr/bin/env python3
"""AI-owned: builds rec-letters-checklist.pdf from rec-letters.qmd.

    make checklist        (or: python3 _scripts/build_rec_checklist.py)

The recommendation-letters page links to a one-page PDF of its checklist.
The PDF is cut from the page itself, from `## Documents to Send` to the end,
so the checklist has one source and cannot drift. Any line that links to the
PDF is dropped from it. Pandoc renders the `- [ ]` items as empty boxes.

Like CV.pdf, the output is built with the local LaTeX, committed at the repo
root and copied into docs/ by `resources:` in _quarto.yml; CI never builds it.
It is not a format of rec-letters.qmd, so a full render does not delete it
(see CLAUDE.md §10). Run it after editing the page's checklist sections, then
commit the PDF.
"""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "rec-letters.qmd"
OUT = ROOT / "rec-letters-checklist.pdf"
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
    body = "\n".join(l for l in body.splitlines() if OUT.name not in l)

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
