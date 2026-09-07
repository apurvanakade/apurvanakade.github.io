#!/usr/bin/env python3
"""AI-owned one-shot generator for typographic SVG cover images used by
projects that have no natural figure.  Re-run only to change the look:

    python3 _scripts/make_covers.py

Output: images/projects/*.svg  (committed; not part of the Quarto build)
"""
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "images" / "projects"

TPL = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500" role="img" aria-label="{alt}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{c1}"/><stop offset="100%" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect width="800" height="500" fill="url(#g)"/>
  <g fill="none" stroke="#ffffff" stroke-opacity="0.16" stroke-width="1.5">{deco}</g>
  <text x="400" y="{ky}" text-anchor="middle" font-family="Inter, Helvetica, Arial, sans-serif"
        font-size="20" font-weight="500" fill="#ffffff" fill-opacity="0.72"
        letter-spacing="2.5">{kicker}</text>
  <text x="400" y="{ty}" text-anchor="middle" font-family="Inter, Helvetica, Arial, sans-serif"
        font-size="{fs}" font-weight="600" fill="#ffffff" letter-spacing="-1">{lines}</text>
</svg>
"""

def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def tspans(title, fs):
    words, lines, cur = title.split(), [], ""
    for w in words:
        if len(cur + " " + w) > 15 and cur:
            lines.append(cur); cur = w
        else:
            cur = (cur + " " + w).strip()
    lines.append(cur)
    return "".join(
        f'<tspan x="400" dy="{0 if i == 0 else fs * 1.15}">{esc(l)}</tspan>'
        for i, l in enumerate(lines)
    ), len(lines)

GRID = "".join(f'<path d="M{x} 0 V500"/>' for x in range(80, 800, 80))
DOTS = "".join(
    f'<circle cx="{x}" cy="{y}" r="3"/>'
    for x in range(90, 800, 70) for y in range(60, 400, 70)
)
WAVE = "".join(
    f'<path d="M0 {y} Q200 {y-60} 400 {y} T800 {y}"/>' for y in range(90, 520, 55)
)

COVERS = [
    ("visual-math-lab",      "Visual Math Lab",           "INTERACTIVE VISUALIZATION", "#0f5f6a", "#123c52", WAVE),
    ("ams-course-explorer",  "AMS Course Explorer",       "COURSE MAP",                "#1c4f7c", "#16324f", GRID),
    ("lean-formalization",   "Formalizing Math in Lean",  "PROOF ASSISTANT",           "#3b3663", "#231f3f", DOTS),
    ("oer-linear-algebra",   "Open Textbook, Linear Algebra", "OER",                   "#6b4226", "#3f2716", GRID),
    ("expository-notes",     "Expository Notes",          "ASSORTED WRITING",          "#2f4a3f", "#1c2e28", DOTS),
    ("mathcamp-assorted",    "More Mathcamp Classes",     "CANADA/USA MATHCAMP",       "#7a3b52", "#43202e", WAVE),
    ("intro-to-optimization", "Introduction to Optimization", "LINEAR PROGRAMMING",     "#14535e", "#0e3038", GRID),
    ("discrete-math-online", "Discrete Math, Asynchronous", "COURSE DESIGN",            "#4a3a70", "#26203c", DOTS),
    ("group-cohomology",     "Arithmetic to Group Cohomology", "EXACT SEQUENCES",       "#5c3f2a", "#33221a", GRID),
    ("symmetries-and-polynomials", "Symmetries & Polynomials", "GALOIS THEORY",         "#2d4a63", "#1a2c3c", WAVE),
]

def monte_carlo():
    """A real figure rather than a typographic cover: the Monte Carlo estimate of
    pi, as points scattered over a square with an inscribed quarter circle.

    This replaces a 13.5 MB animated GIF that was hot-linked from Wikimedia --
    far too heavy for a card thumbnail, and it visibly failed to load. Generated
    here so it is small, on-palette, and ours.
    """
    import math
    import random

    rng = random.Random(20260907)          # fixed seed: regenerating is a no-op
    W, H = 800, 500
    side = 300                             # plot square, kept inside the crop band
    x0, y0 = 70, (H - side) / 2

    inside, outside = [], []
    for _ in range(1100):
        u, v = rng.random(), rng.random()
        pt = f'<circle cx="{x0 + u * side:.1f}" cy="{y0 + side - v * side:.1f}" r="2.4"/>'
        (inside if u * u + v * v <= 1 else outside).append(pt)

    n_in, n_all = len(inside), len(inside) + len(outside)
    est = 4 * n_in / n_all
    tx = x0 + side + 55                    # text column, right of the scatter
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" role="img"
     aria-label="Monte Carlo estimate of pi: {n_in} of {n_all} random points fall inside the quarter circle">
  <defs>
    <linearGradient id="mc" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#123c52"/><stop offset="100%" stop-color="#0d2a3a"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#mc)"/>
  <rect x="{x0}" y="{y0}" width="{side}" height="{side}" fill="none"
        stroke="#ffffff" stroke-opacity="0.25"/>
  <path d="M{x0} {y0} A {side} {side} 0 0 1 {x0 + side} {y0 + side}"
        fill="none" stroke="#ffffff" stroke-opacity="0.5" stroke-width="2"/>
  <g fill="#f2b880" fill-opacity="0.95">{''.join(inside)}</g>
  <g fill="#ffffff" fill-opacity="0.30">{''.join(outside)}</g>
  <text x="{tx}" y="{H / 2 - 42}" font-family="Inter, Helvetica, Arial, sans-serif"
        font-size="20" font-weight="500" fill="#ffffff" fill-opacity="0.62"
        letter-spacing="2.5">MONTE CARLO</text>
  <text x="{tx}" y="{H / 2 + 14}" font-family="Inter, Helvetica, Arial, sans-serif"
        font-size="46" font-weight="600" fill="#ffffff" letter-spacing="-1">&#960; &#8776; {est:.3f}</text>
  <text x="{tx}" y="{H / 2 + 52}" font-family="Inter, Helvetica, Arial, sans-serif"
        font-size="21" fill="#ffffff" fill-opacity="0.62">4 &#215; {n_in}/{n_all}</text>
</svg>
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "monte-carlo.svg").write_text(monte_carlo())
    print("wrote monte-carlo.svg")
    for slug, title, kicker, c1, c2, deco in COVERS:
        fs = 54
        lines, n = tspans(title, fs)
        block = n * fs * 1.15                       # height of the title block
        ty = int(250 - block / 2 + fs * 0.35)       # title, centred on y=250
        svg = TPL.format(alt=esc(title), c1=c1, c2=c2, deco=deco, lines=lines,
                         fs=fs, ty=ty, ky=ty - fs - 14, kicker=esc(kicker))
        (OUT / f"{slug}.svg").write_text(svg)
        print("wrote", slug + ".svg")

if __name__ == "__main__":
    main()
