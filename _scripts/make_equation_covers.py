#!/usr/bin/env python3
"""AI-owned one-shot generator for the blog's formula covers.

    python3 _scripts/make_equation_covers.py

Some posts have no natural figure, so their cover is the formula the post is
about. Each formula is typeset by the local LaTeX (`latex` + `dvisvgm
--no-fonts`, so glyphs become paths and the SVG needs no font), then centred on
a soft gradient panel. Output goes to math-blog/maths/images/*-equation.svg and
is committed; it is not part of the Quarto build. Re-running is a no-op unless
COVERS changes.

The panel is 1200x630. Blog cards crop with object-fit: cover at aspects from
about 1.3 (the blog grid) to about 2.2 (the home card), so the formula is kept
inside the centre band that survives both, as in _scripts/make_covers.py.
"""
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "math-blog" / "maths" / "images"

W, H = 1200, 630
BOX_W, BOX_H = 640, 300          # the formula is scaled to fit this box

# slug, alt text, LaTeX (display math), gradient start, gradient end, ink
COVERS = [
    ("closed-cones", "The cone of all Ax with x at least 0",
     r"\{\, Ax : x \geq 0 \,\}",
     "#f4f9ff", "#eaf3fb", "#17324a"),
    ("combinatorial-nullstellensatz", "f(s_1, ..., s_n) is not zero",
     r"f(s_1, s_2, \ldots, s_n) \neq 0",
     "#f4f9ff", "#eef8f4", "#1b3550"),
    ("ln-series", "The sum of chi'(n)/n over n equals ln(pi/4)",
     r"\sum_{n \in \mathbb{N}} \frac{\chi'(n)}{n} = \ln\left(\frac{\pi}{4}\right)",
     "#f8f3fb", "#fbeff1", "#332046"),
    ("pythagoras-hilbert90", "a squared plus b squared equals 1",
     r"a^2 + b^2 = 1",
     "#f3f5fd", "#eef1fb", "#1f2f5a"),
    ("with-without-order", "The hypergeometric probability",
     r"\dfrac{\dbinom{n}{k}\dbinom{N - n}{m - k}}{\dbinom{N}{m}}",
     "#f5f4ef", "#eef2f7", "#1f2a44"),
]

DOC = r"""\documentclass[border=1pt]{standalone}
\usepackage{amsmath,amssymb,xcolor}
\begin{document}
\color[HTML]{%s}$\displaystyle %s$
\end{document}
"""


def typeset(tex, ink):
    """Return (inner SVG markup, width, height) of the typeset formula."""
    with tempfile.TemporaryDirectory() as d:
        src = pathlib.Path(d) / "f.tex"
        src.write_text(DOC % (ink.lstrip("#").upper(), tex))
        subprocess.run(["latex", "-interaction=nonstopmode", "f.tex"], cwd=d,
                       check=True, capture_output=True)
        subprocess.run(["dvisvgm", "--no-fonts", "--exact-bbox", "-o", "f.svg", "f.dvi"],
                       cwd=d, check=True, capture_output=True)
        svg = (pathlib.Path(d) / "f.svg").read_text()
    vb = [float(v) for v in re.search(r"viewBox=['\"]([^'\"]+)['\"]", svg).group(1).split()]
    inner = re.search(r"<svg[^>]*>(.*)</svg>", svg, re.S).group(1)
    return inner, vb


def cover(alt, tex, c1, c2, ink):
    inner, (x, y, w, h) = typeset(tex, ink)
    k = min(BOX_W / w, BOX_H / h)
    tx = W / 2 - (x + w / 2) * k
    ty = H / 2 - (y + h / 2) * k
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" role="img" aria-label="{alt}">
  <defs>
    <linearGradient id="bg" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0%" stop-color="{c1}"/>
      <stop offset="100%" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <g transform="translate({tx:.2f} {ty:.2f}) scale({k:.4f})">{inner}</g>
</svg>
"""


def main():
    for slug, alt, tex, c1, c2, ink in COVERS:
        path = OUT / f"{slug}-equation.svg"
        path.write_text(cover(alt, tex, c1, c2, ink))
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
