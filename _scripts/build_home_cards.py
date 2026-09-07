#!/usr/bin/env python3
"""AI-owned pre-render step. Generates _includes/home-cards.html.

Emits two cards for the home page, each showing one item drawn at random with
probability proportional to its `weight:`

  1. "Featured project"  -- from projects/*.qmd
  2. "From the blog"     -- from math-blog/posts/**/*.qmd

Weighting
---------
Any of those files may carry a `weight:` in its frontmatter:

    weight: 5   -- five times as likely to be featured as weight 1
    weight: 1   -- the default when the field is absent
    weight: 0   -- never featured (still listed on its own section page)

A non-numeric weight logs a warning and falls back to 1; a negative one is
clamped to 0.

Both lists are read straight off disk at render time and embedded as JSON, so
the cards work offline, in `quarto preview`, and with no network access. The draw
itself happens in the browser on each page load; the highest-weighted item of
each kind is baked into the HTML as the no-JavaScript fallback.

Post filenames contain spaces, so hrefs and image paths are percent-encoded
here. Post `image:` paths are frontmatter-relative and are rewritten relative to
the site root.

(Before the blog was merged into this repo, the second card fetched
/math-blog/weights.json and scraped the blog's rendered listing cross-origin.
That is all gone -- the data is local now.)

Never edit _includes/home-cards.html by hand -- it is overwritten on every
render. See CLAUDE.md.
"""
import datetime
import html
import json
import os
import pathlib
import re
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECTS = ROOT / "projects"
BLOG_POSTS = ROOT / "math-blog" / "posts"
OUT = ROOT / "_includes" / "home-cards.html"

BLOG_INDEX = "math-blog/"


def parse_frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    out = {}
    for line in m.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m2 = re.match(r"^(\w[\w-]*):\s*(.*)$", line)
        if m2 and m2.group(2).strip():
            out[m2.group(1)] = m2.group(2).strip().strip('"').strip("'")
    return out


def url(path_str):
    """Percent-encode a site-relative path (several posts have spaces in their
    filenames) while leaving the separators alone."""
    return urllib.parse.quote(path_str, safe="/-_.~")


def pretty_date(raw):
    """'2023-10-26 09:01:26' -> 'Oct 26, 2023'. Unrecognised input is passed
    through untouched rather than dropped."""
    if not raw:
        return ""
    head = raw.strip().strip('"').split()[0]
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%d-%m-%Y"):
        try:
            return datetime.datetime.strptime(head, fmt).strftime("%b %-d, %Y")
        except ValueError:
            continue
    return raw


def read_weight(fm, path):
    raw = fm.get("weight")
    if raw is None:
        return 1.0
    try:
        w = float(raw)
    except ValueError:
        print(f"build_home_cards: {path.name}: weight {raw!r} is not a number; using 1")
        return 1.0
    if w < 0:
        print(f"build_home_cards: {path.name}: negative weight {w}; using 0")
        return 0.0
    return w


def collect_posts():
    """Blog posts, newest-looking metadata first. Images in post frontmatter are
    written relative to the post file; rewrite them relative to the site root."""
    items, skipped = [], []
    for path in sorted(BLOG_POSTS.rglob("*.qmd")):
        if path.name.startswith("_"):
            continue
        fm = parse_frontmatter(path)
        if not fm or "title" not in fm:
            continue
        weight = read_weight(fm, path)
        if weight == 0:
            skipped.append(path.stem)
            continue
        rel = path.relative_to(ROOT).with_suffix(".html")
        image = fm.get("image", "")
        if image:
            image = os.path.normpath(
                str((path.parent / image).relative_to(ROOT))
            ).replace("\\", "/")
        items.append({
            "title": fm["title"],
            "desc": fm.get("description", ""),
            "date": pretty_date(fm.get("date", "")),
            "href": url(str(rel).replace("\\", "/")),
            "image": url(image),
            "weight": weight,
        })
    items.sort(key=lambda i: (-i["weight"], i["title"]))
    return items, skipped


def collect():
    items, skipped = [], []
    for path in sorted(PROJECTS.glob("*.qmd")):
        if path.name == "index.qmd":
            continue
        fm = parse_frontmatter(path)
        if not fm or "title" not in fm:
            continue
        weight = read_weight(fm, path)
        if weight == 0:
            skipped.append(path.stem)
            continue
        image = fm.get("image", "")
        # project frontmatter is written relative to projects/; the home page
        # sits one level up, so ../images/... becomes images/...
        if image.startswith("../"):
            image = image[3:]
        items.append({
            "title": fm["title"],
            "desc": fm.get("description", ""),
            "href": url(f"projects/{path.stem}.html"),
            "image": url(image),
            "weight": weight,
        })
    items.sort(key=lambda i: (-i["weight"], i["title"]))
    return items, skipped


def card_html(item):
    img = (
        f'<img class="home-card__thumb" src="{html.escape(item["image"])}" alt="" loading="lazy">'
        if item["image"]
        else ""
    )
    return (
        f'{img}'
        f'<div class="home-card__body">'
        f'<h3 class="home-card__title"><a href="{html.escape(item["href"])}">'
        f'{html.escape(item["title"])}</a></h3>'
        f'<p class="home-card__desc">{html.escape(item["desc"])}</p>'
        f"</div>"
    )


TEMPLATE = """<!-- GENERATED by _scripts/build_home_cards.py -- do not edit. See CLAUDE.md. -->
<div class="home-cards">

  <div class="home-card" id="featured-project">
    <div class="home-card__eyebrow">Featured project</div>
    <div class="home-card__slot">{project_seed}</div>
    <div class="home-card__footer"><a href="projects/">See all projects &#8594;</a></div>
  </div>

  <div class="home-card" id="featured-post">
    <div class="home-card__eyebrow">From the blog</div>
    <div class="home-card__slot">{post_seed}</div>
    <div class="home-card__footer"><a href="{blog}">Read the blog &#8594;</a></div>
  </div>

</div>

<script>
(function () {{
  // Picks one entry with probability proportional to its weight. Entries at
  // weight 0 are filtered out at build time and never reach this code.
  function pick(items) {{
    var total = 0, i;
    for (i = 0; i < items.length; i++) total += items[i].weight;
    if (total <= 0) return items[Math.floor(Math.random() * items.length)];
    var r = Math.random() * total;
    for (i = 0; i < items.length; i++) {{
      r -= items[i].weight;
      if (r < 0) return items[i];
    }}
    return items[items.length - 1];
  }}

  function render(id, items, sub) {{
    var slot = document.querySelector('#' + id + ' .home-card__slot');
    if (!slot || !items.length) return;
    var it = pick(items);
    slot.innerHTML =
      (it.image ? '<img class="home-card__thumb" src="' + it.image + '" alt="" loading="lazy">' : '') +
      '<div class="home-card__body">' +
        '<h3 class="home-card__title"><a></a></h3>' +
        '<p class="home-card__desc"></p>' +
        '<div class="home-card__meta"></div>' +
      '</div>';
    var a = slot.querySelector('.home-card__title a');
    a.href = it.href;
    a.textContent = it.title;
    slot.querySelector('.home-card__desc').textContent = it.desc || '';
    slot.querySelector('.home-card__meta').textContent = sub ? (it.date || '') : '';
  }}

  render('featured-project', {projects_json}, false);
  render('featured-post', {posts_json}, true);
}})();
</script>
"""


def main():
    projects, p_skipped = collect()
    posts, b_skipped = collect_posts()
    if not projects:
        raise SystemExit("build_home_cards: no eligible projects (all weight 0?)")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        TEMPLATE.format(
            project_seed=card_html(projects[0]),
            post_seed=card_html(posts[0]) if posts else "",
            projects_json=json.dumps(projects, ensure_ascii=False),
            posts_json=json.dumps(posts, ensure_ascii=False),
            blog=BLOG_INDEX,
        ),
        encoding="utf-8",
    )

    def note(skipped):
        return f", {len(skipped)} at weight 0 excluded" if skipped else ""

    print(
        f"build_home_cards: wrote {OUT.relative_to(ROOT)} -- "
        f"{len(projects)} featurable projects{note(p_skipped)}; "
        f"{len(posts)} featurable posts{note(b_skipped)}"
    )


if __name__ == "__main__":
    main()
