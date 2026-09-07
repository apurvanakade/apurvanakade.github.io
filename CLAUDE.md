# CLAUDE.md

Working notes for Claude on `apurvanakade.github.io` — a [Quarto](https://quarto.org/)
static site built and deployed to GitHub Pages by GitHub Actions.

---

## 0. Keep this file current

**This file describes the repository as it currently is — its structure,
conventions and constraints. It is not a changelog, a status report or a task
list.** Nothing here should record what was done, when, or by whom; git already
does that. If a sentence would read as "we did X", it does not belong.

Updating it is the last step of any change, so it never describes a structure
that no longer exists. A change requires an edit here whenever it:

- adds, removes, moves or renames a top-level directory or a content file;
- changes a published URL, or the reason a URL is shaped the way it is;
- adds or changes a build hook, filter, include, generated file or dependency;
- changes a frontmatter field's meaning, or adds a new one;
- changes the ownership split in §1;
- reverses or supersedes a decision recorded here.

Two rules about *how* to write it:

1. **Record the reason, not just the rule.** "Do not set a height on
   `.card-img-top`" is forgettable; "do not set one, because each listing's own
   `image-height` becomes an inline style on the `<img>` and a competing height
   makes titles overlap the image" survives. Every trap listed in §4 and §6 cost
   real debugging time — that is why they are written down.
2. **Delete what is no longer true.** Do not append a correction below a stale
   paragraph; replace the paragraph. A file that contradicts itself is worse than
   one that is merely out of date.

Prune as you go. When a decision is reversed, rewrite the affected section so it
describes only the current design — do not leave the superseded version behind
with a note attached.

---

## 1. The ownership rule (read this first)

The single most important convention in this repo is a hard split between files
**Apurva writes** and files **Claude maintains**.

| Apurva edits — Claude does not restructure | Claude maintains — Apurva never needs to open |
|---|---|
| `index.qmd`, `references.qmd`, `rec-letters.qmd`, `teaching-statement.qmd` | `_quarto.yml` |
| `projects/*.qmd` (frontmatter + prose) | `_theme/*.scss` |
| `projects/index.qmd` | `_filters/*.lua` |
| `CV.qmd`, `cv/*.qmd` | `_includes/*.html` |
| `math-blog/index.qmd`, `math-blog/*/index.qmd` | `_scripts/*.py` |
| `math-blog/posts/**/*.qmd` | `cv/preamble.tex` |
| `math-blog/drafts/*.qmd` | `projects/_metadata.yml` |
| `styles.css` (personal CSS overrides) | `math-blog/_metadata.yml` |
| | `math-blog/_includes/*.html` |
| | `math-blog/posts/*/_metadata.yml` |
| | `CLAUDE.md` |

**Consequences for Claude:**

- Content files stay *prose plus minimal YAML*. No raw HTML, no `::: {.div}`
  wrappers, no shortcodes, no chrome. If a page needs structure, add it in a Lua
  filter or an include — never inline in a content file.
- `styles.css` is Apurva's scratch space. Never write to it. All generated CSS
  goes in `_theme/`.
- Anything in `_includes/` that says `GENERATED` is overwritten on every render.
  Change the generator in `_scripts/`, not the output.

---

## 2. Build & deploy

```bash
make build     # quarto render --output-dir docs/   (local only, gitignored)
make clean     # rm -rf docs/
make covers    # regenerate the SVG project covers (rarely needed)
quarto preview # local live preview (not in the makefile)
```

There is no test suite and no linter. **Verification is visual**: render, serve
`docs/` on a local port, and screenshot with Playwright (installed) in both
colour schemes before claiming a style change works. Quarto's dark mode is a
manual toggle — click `.quarto-color-scheme-toggle`, don't rely on
`prefers-color-scheme`.

`quarto render` runs two hooks defined in `_quarto.yml`:

- **pre-render** `_scripts/build_home_cards.py` → writes `_includes/home-cards.html`
- **post-render** `_scripts/write_redirects.py` → writes meta-refresh stubs into `docs/`

Neither needs anything beyond the Python standard library.

### Execution dependencies

There is **no R dependency** — the two R plots that used to live in `notes.qmd`
were rendered once and committed as `images/projects/*.png`. Keep it that way.

There is exactly **one** Jupyter dependency: `math-blog/posts/maths/nth-fibonacci.qmd`
has Python cells and needs the `myenv` kernel. Every other code cell in the blog
(50 of them) is Observable JS, which runs in the reader's browser and needs
nothing at render time.

`math-blog/_metadata.yml` sets `freeze: auto` for that subtree, so `_freeze/` is
committed and the kernel is only needed when that one post itself changes.
**`_freeze/` must stay committed** — without it a machine lacking the `myenv`
kernel cannot build the site.

### Deployment

Publishing is CI, not `make`. `.github/workflows/publish.yml` triggers on a push
to **`2026-quarto`** or a manual `workflow_dispatch`, and:

1. installs Quarto and TinyTeX,
2. runs `quarto render` (no R, no Jupyter kernel — see above),
3. uploads `docs/` with `actions/upload-pages-artifact` and publishes it with
   `actions/deploy-pages`.

This is GitHub's **native Pages deployment**, matching Settings → Pages →
Source: "GitHub Actions". The site is served from the uploaded artifact.
**Nothing is pushed to a `gh-pages` branch** — that branch is a leftover from a
2023 deployment method, is not read by anything, and can be deleted. Changing
the Pages source back to "Deploy from a branch" would silently stop deploys,
because this workflow never writes a branch.

`docs/` is therefore **local build output only** — gitignored, never committed
from a source branch, and never hand-edited. A local `make build` is for
preview; it has no effect on the published site.

**`2026-quarto` is the deploy branch, not `2023-quarto`.** `2023-quarto` is the
repo's GitHub default branch but is kept only for stashing older work; pushing
to it publishes nothing. If the default branch is ever switched to
`2026-quarto`, the `branches:` list in the workflow stays correct as written.

---

## 3. Site structure

```
index.qmd                       home; pulls in _includes/home-cards.html
projects/index.qmd              grid listing, filter + category UI
projects/<slug>.qmd             one project per file
math-blog/index.qmd             all posts, grid listing
math-blog/maths/index.qmd       maths section listing
math-blog/scribbles/index.qmd   scribbles section listing
math-blog/posts/maths/*.qmd     the posts themselves
math-blog/posts/scribbles/*.qmd
math-blog/drafts/*.qmd          rendered and published, but not listed anywhere
CV.qmd                          assembles cv/*.qmd; renders to HTML *and* PDF
cv/<section>.qmd                one CV section per file
teaching-statement.qmd
rec-letters.qmd
references.qmd
```

Navbar: **Home · Projects · Blog · Teaching ▾ · CV**. `Teaching` is a dropdown
holding the teaching statement, recommendation-letter instructions, and
references.

**There is no sidebar for the blog subtree, deliberately.** The blog index and
both section pages already carry a grid listing plus a categories rail, and every
post has a back-link, so a sidebar would be a third column of duplicate
navigation. The standalone blog used an explicit sidebar file list in its
`_quarto.yml` and it had gone stale — it still pointed at a post deleted months
earlier. Listings cannot rot that way. If a sidebar is ever wanted again, note
that Quarto rejects `auto:` globs combined with a `href:` on the same section.

---

## 4. The CV system

The PDF must look like the LaTeX CV it replaced: a narrow bold label column on
the left, entries on the right, years right-aligned in their own gutter. The HTML
version mirrors it.

**How it works.** `_filters/cv.lua` rewrites the document:

- Each `## Section` becomes a two-column block. In HTML that is
  `div.cv-section > (div.cv-label + div.cv-body)`; in LaTeX it is
  `\begin{cvsection}{Label}…\end{cvsection}` from `cv/preamble.tex`.
- Any entry paragraph ending in `, <year>` has the year lifted into a right-aligned
  column. Recognised tails: `2025`, `2019-2021`, `2019-21`, `2023-Present`,
  `2023-`, `Fall 2024`, `Winter, Spring 2022`.
- The name / affiliation / contact header is built from `cv-subtitle` and
  `cv-contact` in `CV.qmd`'s frontmatter.
- The PDF gets an automatic `Updated on: <date>` line.

**So the content convention is: one entry per paragraph, year last, after a comma.**
Write `Faculty Forward Fellowship, JHU, 2025` and the layout takes care of itself.
Set `cv-layout: false` in frontmatter to switch the filter off.

### Constraints — do not regress

- **Pandoc's `section-divs` copies a header's classes onto the wrapping
  `<section>`.** A visually-hidden rule written as `.cv-anchor { … }` collapsed
  the entire CV body to 1px. The rule must be scoped to the element:
  `h2.cv-anchor { … }`.
- **The TOC only sees top-level headers.** A header nested inside a Div produces
  no TOC entry, so the filter emits a real top-level `<h2>` (visually hidden,
  carrying the id and anchor) *next to* the visible label div, which is marked
  `aria-hidden="true"` so the text is not announced twice.
- **`\subsection` is illegal inside the `cvsection` list environment.** The filter
  converts `###`/`####` to `\cvsubsection`/`\cvsubsubsection` for LaTeX.
- **No tables inside a CV section.** A `longtable` inside the list environment
  breaks LaTeX; this is why Experience is plain lines, not the markdown table it
  used to be.
- **Section labels are placed via `\item[…]` and a redefined `\makelabel`,** not
  `\llap` — `\llap` pushed them off the left edge of the page.

---

## 5. The projects system

Each project is one file, `projects/<slug>.qmd`:

```yaml
---
title: "Monte Carlo Methods"
description: "One sentence. Shown on the listing card."
date: 2025-09-01          # term taught; drives sort order
weight: 3                 # how often it is featured on the home page
categories: ["course notes", "JHU", "probability"]
image: ../images/projects/foo.svg   # or a remote URL
links:
  - text: "Course notes"
    href: "https://..."
---

Prose.
```

- `links:` is rendered as a row of pill buttons by `_filters/project-links.lua`.
  Content files carry no markup for it.
- `projects/_metadata.yml` applies that filter and shared page settings to the
  whole directory.
- **Categories** are a flat vocabulary mixing kind (`app`, `course notes`,
  `problem sets`, `course design`, `formalization`, `OER`, `expository`), venue
  (`JHU`, `Northwestern`, `UWO`, `Mathcamp`) and one topic. Reuse existing terms;
  check `projects/index.html`'s category list before inventing a new one.
- **`weight:`** controls the home page's featured-project rotation (see §5.1).
  It has no effect on the Projects listing, which always shows everything.
- **Images.** Every project cover is local, generated by
  `_scripts/make_covers.py` into `images/projects/`. Two kinds:
  **real figures** (`FIGURES` in that script) that draw the mathematics the
  project is about — the Penrose tribar for sheaf cohomology, a trefoil for
  knots, the Weierstrass function, an icosahedron, the Riemann surface of the
  square root, a Monte Carlo estimate of pi — and **typographic covers**
  (`COVERS`) for projects with no natural figure. The script is seeded, so
  re-running it is a no-op; output is committed and is not part of the Quarto
  build.
- **No project hot-links a remote image, and none should.** Nine used to pull
  from Wikimedia Commons; they broke on the published site and were replaced by
  the generated figures above. Remote art is also third-party and can change or
  vanish, and one 13.5 MB animated GIF slipped in that way and simply failed to
  render. If you ever do add one, check the size first
  (`curl -so /dev/null -w '%{size_download}'`) and its licence.

### 5.1 Featured-project weighting

The home page draws one project at random, with probability proportional to
`weight:`:

| `weight` | meaning |
|---|---|
| `0` | never featured — still listed on the Projects page |
| absent or `1` | the default |
| `n` | `n` times as likely to be drawn as a `weight: 1` project |

Weights are relative, not percentages, so they do not need to sum to anything.
The current spread is 5 for the two apps, 3 for flagship course notes, 2 for
substantial course redesigns, 1 for individual Mathcamp classes, and 0 for the
two grab-bag index pages (`mathcamp-assorted`, `expository-notes`). These are a
starting point — Apurva tunes them.

**Blog posts use the identical mechanism.** `_scripts/build_home_cards.py` scans
`projects/*.qmd` *and* `math-blog/posts/**/*.qmd`, drops everything at weight 0,
and embeds both lists as JSON. The draw happens in the browser on each page load;
the highest-weighted item of each kind is baked into the HTML as the
no-JavaScript fallback. A non-numeric weight logs a warning and falls back to 1;
a negative one is clamped to 0.

Post filenames contain spaces, so hrefs and image paths are percent-encoded by
the generator. Post `image:` paths are frontmatter-relative and get rewritten
relative to the site root.

The card reads from disk and makes **no network request** — no fetch, no
scraping of rendered listings, no `weights.json`. It therefore works offline and
under `quarto preview`. Keep it that way; the data it needs is all local.

### Adding a project

Create the `.qmd`. Nothing else. The listing, the category filter, and the home
page's featured-project rotation all pick it up on the next render.

---

## 6. The blog

The blog ("Second Drafts") lives under `math-blog/` in this repo. It was
originally a separate repository, `git@github.com:apurvanakade/math-blog.git`,
which still exists as a read-only archive (see below).

### Why the directory is called `math-blog`

Because it keeps every published URL byte-identical.
`math-blog/posts/maths/bayes-theorem.qmd` renders to
`docs/math-blog/posts/maths/bayes-theorem.html`, served at
`apurvanakade.github.io/math-blog/posts/maths/bayes-theorem.html` — exactly where
it was before. **No redirects were needed and none exist.** Do not "tidy" this
directory to `blog/` or `writing/` without generating a full redirect map first;
renaming it silently breaks every link ever shared to a post.

### The GitHub Pages precedence trap

A project site at `apurvanakade.github.io/math-blog/` (served from the old
`math-blog` repo) **takes precedence over a `math-blog/` folder in this user
site**. So the merged copy stays invisible until GitHub Pages is disabled on the
old repo. If a change to a post appears to have no effect on the live site, this
is almost certainly why — check that first.

### The archive repo

`/Users/apurvanakade/Github/math-blog` is a read-only archive; do not edit it.
Post history lives only there — the content came across as a file copy, so
`git log` on a post in this repo starts at the merge.

It also holds one post with no counterpart here: `posts/scribbles/begin-again`,
whose source was deleted but whose rendered HTML is still in that repo's `docs/`.
Recover it from there if it is ever wanted.

### Structure

Section landing pages (`math-blog/maths/index.qmd`) are separate from the posts
(`math-blog/posts/maths/*.qmd`); that is inherited from the standalone blog and
was kept so relative image paths did not have to change. Post images live under
`math-blog/maths/images/` and `math-blog/scribbles/images/`, referenced from
posts as `../../maths/images/foo.png`.

`math-blog/posts/*/_metadata.yml` attaches the back-link include for each
subtree. `math-blog/_metadata.yml` carries the kernel, freeze and execute
settings for the whole subtree (see §2).

### Post frontmatter

```yaml
---
title: Bayes Theorem
description: "One sentence. Shown on the listing cards."
date: 2025-06-02
weight: 1                 # 0 = never featured on the home page
author: Apurva Nakade
categories: [probability, visualization]
image: "../../maths/images/bayes.png"
---
```

Listing pages depend on `title`, `date`, `description`, `categories` and `image`;
missing metadata degrades the cards. **Quarto does not excerpt the post body** —
a post with no `description:` renders a card with no text at all, so every post
carries one. Any listing meant to show them must also name `description` in its
`fields:`. `weight` drives the home page draw (§5.1) —
the same mechanism as projects, now reading straight off disk.

### Drafts

`math-blog/drafts/*.qmd` render and publish but appear in no listing. That was
true of the standalone blog too and was preserved deliberately. They are
reachable by anyone with the URL — treat them as public.

## 7. Theme

```
_theme/base.scss    typography, layout, components (shared)
_theme/light.scss   light palette
_theme/dark.scss    dark palette
```

Layered over Bootstrap bases in `_quarto.yml`:
`light: [cosmo, base, light]`, `dark: [cyborg, base, dark]`.

- Body text is **Source Serif 4**; headings, navbar, UI and tabular figures are
  **Inter**. Both are loaded from Google Fonts via `_includes/fonts.html`.
- Palettes are exposed as CSS custom properties (`--site-ink`, `--site-muted`,
  `--site-accent`, `--site-rule`, `--site-surface`, `--site-shadow`,
  `--site-thumb-bg`, `--site-sans`). **Component rules in `base.scss` must use
  those variables, never literal colours** — that is what keeps one rule working
  in both schemes.
- Bootstrap's own `.card` background does not follow our palette; card components
  need an explicit `background: var(--site-surface)` or they render mid-grey in
  dark mode.

### Constraints — do not regress

- **Card art must keep its content centred on both axes.** Thumbnails are drawn
  with `object-fit: cover`, and the crop aspect swings from taller-than-wide (a
  three-column grid on a narrow screen) to about 2:1 (the home card). Only the
  centre survives every case, so text in `_scripts/make_covers.py` is centred
  horizontally *and* vertically. Left- or bottom-anchored text gets sliced off.
- **Never set a `height` on `.quarto-grid-item .card-img-top` or its `img`.**
  Each listing declares its own `image-height` (190px for projects, 250px for the
  blog), which Quarto writes as an inline style on the `<img>`. A competing
  height on the wrapper makes card titles overlap the image. Style
  `object-fit`, `width` and `background` only, and let the listing own the height.

---

## 8. Redirects

The 2026 reorganisation changed some URLs. `_scripts/write_redirects.py` writes
meta-refresh stubs after each render:

| Old | New |
|---|---|
| `notes.html` | `projects/index.html` |
| `rec letters.html` | `rec-letters.html` |
| `teaching statement.html` | `teaching-statement.html` |

The script refuses to overwrite a page Quarto actually rendered. Add to the
`REDIRECTS` dict whenever a page moves.

---

## 9. Content conventions

- **Filenames**: lowercase, hyphenated, no spaces.
- **Math**: `$…$` inline, `$$…$$` display. Avoid `\begin{equation}` — it does not
  round-trip cleanly through the CV filter.
- **Images** in prose always get a width: `![](path){width="40%"}`.
- **Em dashes** are written `---` in source.
- Section headers are `##` / `###`. Do not use `{-}` to hide sections from the
  TOC any more; the listing and CV layouts handle their own navigation.

---

## 10. Known constraints

Standing facts about this repo that are easy to trip over and are not obvious
from the files themselves. Each one is described in full in the section named.

- **The merged blog is shadowed until GitHub Pages is disabled on the old
  `math-blog` repo** (§6). This is the first thing to check if an edit to a post
  has no visible effect on the live site.
- **`_freeze/` must stay committed** (§2). Without it, a machine without the
  `myenv` Jupyter kernel cannot build the site.
- **`docs/` is gitignored, local build output** (§2). It is not committed and
  has no effect on the published site — only a push to `2026-quarto` (or a
  manual workflow run) does. Never hand-edit it.
- **Deploys come from `2026-quarto`, not the default branch** (§2).
  `2023-quarto` is GitHub's default branch for this repo but publishes nothing.
- **Pages is set to "GitHub Actions", not "Deploy from a branch"** (§2). The
  workflow uploads an artifact; it never writes `gh-pages`. Flipping that
  setting back to a branch source stops publishing silently.
- **The `math-blog/` directory name is load-bearing** (§6). It is what keeps
  every published post URL unchanged; renaming it breaks every shared link.
- **All cover art is local and generated** (§5). Nothing hot-links a remote
  image any more; `_scripts/make_covers.py` is the only source of
  `images/projects/*.svg`.
