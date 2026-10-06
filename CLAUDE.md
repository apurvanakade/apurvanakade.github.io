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
| | `CLAUDE.md`, `.claude/**` |

`_extensions/apurvanakade/mathviz/` belongs to neither column: it is an
installed upstream release, overwritten by `_scripts/update-mathviz.sh` on the
next render. Nobody edits it (see §6, "mathviz").

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
make build     # quarto render --to html --output-dir docs/   (local only, gitignored)
make cv        # rebuild CV.pdf with the local LaTeX; commit the result
make clean     # rm -rf docs/
make covers    # regenerate the SVG project covers (rarely needed)
make update-mathviz  # force a check for a newer mathviz release
make release   # fast-forward main to origin/develop and push: publishes the site
quarto preview # local live preview (not in the makefile)
```

There is no test suite and no linter. **Verification is visual**: render, serve
`docs/` on a local port, and screenshot with Playwright (installed) in both
colour schemes before claiming a style change works. Quarto's dark mode is a
manual toggle — click `.quarto-color-scheme-toggle`, don't rely on
`prefers-color-scheme`.

`quarto render` runs three hooks defined in `_quarto.yml`:

- **pre-render** `_scripts/update-mathviz.sh` → installs the latest mathviz
  release into `_extensions/` (§6, "mathviz")
- **pre-render** `_scripts/build_home_cards.py` → writes `_includes/home-cards.html`
- **post-render** `_scripts/write_redirects.py` → writes meta-refresh stubs into `docs/`

The Python hooks need only the standard library; the shell hook needs `git`
and network access, and falls back to the installed copy when offline.

### Execution dependencies

**Nothing executes at render time.** Every code cell on the site is Observable
JS, which runs in the reader's browser. There is no Jupyter kernel, no
`freeze`, and no `_freeze/` directory.

There is **no R dependency** — the two R plots that used to live in `notes.qmd`
were rendered once and committed as `images/projects/*.png` — and **no Python
cell**. Keep it that way: Python would need a kernel in CI and a committed
`_freeze/` cache to avoid one. A computation a post needs runs in the browser; a
fixed figure is rendered once and committed as an image.

### Branches

The same model as Monte-Carlo-Methods and VisualMathLab: **`develop` is where
work lands; `main` is a pointer to the last published state**, and pushing
`main` deploys. `main` is the GitHub default branch.

- **This folder is the long-lived `develop` checkout** and stays on `develop`.
  A feature branch gets a sibling worktree,
  `git worktree add -b <prefix>/<slug> ../apurvanakade.github.io-<slug> develop`,
  with its own `quarto preview --port 4201` (count up). Checking out another
  branch in place rewrites `_quarto.yml`/`_includes/`/`_extensions/`, and a
  running preview then re-renders the whole site.
- **Major changes go through a PR into `develop`**, merged with `--merge` once
  `pr-check.yml` (a full render of the site) is green. It cannot see an OJS
  cell that throws in the browser, so touched pages are checked in a preview
  first. **Small changes may be pushed straight to `develop`**: a wording fix
  in prose, a comment, or repo-only files (`CLAUDE.md`, `makefile`). Anything
  touching `_quarto.yml`, `_theme/`, `_filters/`, `_includes/`, `_scripts/`,
  `_extensions/`, an OJS cell or a workflow is not small, however few lines.
- **Releasing is a fast-forward of `main` to `develop`**: `make release`
  (`git push origin origin/develop:main`, which the remote refuses unless it is
  a fast-forward, so no checkout is needed). Never squash- or merge-commit into
  `main`, and never force-push it: a squash records no parent link back to
  `develop`, so the merge base stops advancing and every later release
  conflicts. If the fast-forward is refused, reconcile once with
  `git merge -s ours origin/main` on `develop`, push, and retry.
- **The `ship-pr` skill** (`.claude/skills/ship-pr/SKILL.md`) carries a change
  through all of the above end to end: `make cv` if the CV changed, worktree,
  PR, check, merge, cleanup, and always a final `make release`, even for a
  repo-only change, so `main` never lags `develop`. When a rule here changes, update it there
  too. `.claude/settings.json` pre-approves the commands it runs (PR create,
  check and `--merge`, pushes to `origin`, `make release`) and denies
  force-pushes and `--admin`/`--squash` merges.
- Pushing `develop` publishes nothing. Neither does any other branch.
- The `2020-bookdown`, `2021-mdbook`, `2022-bookdown`, `blog` and
  `teaching-portfolio` branches are frozen snapshots of earlier versions of
  the site, read by nothing.

### Deployment

Publishing is CI, not `make build`. `.github/workflows/publish.yml` triggers on
a push to **`main`** or a manual `workflow_dispatch`, and:

1. renders the site through the composite action `.github/actions/render`
   (installs Quarto, runs `quarto render --to html`; no LaTeX, no R, no
   Python),
2. uploads `docs/` with `actions/upload-pages-artifact` and publishes it with
   `actions/deploy-pages`.

`.github/workflows/pr-check.yml` runs the same composite on every PR into
`develop` and attaches the rendered site as a downloadable `site` artifact.
The render lives in one composite so the two workflows cannot drift; bump its
Quarto `version:` pin when bumping Quarto locally.

This is GitHub's **native Pages deployment**, matching Settings → Pages →
Source: "GitHub Actions". The site is served from the uploaded artifact.
**Nothing is pushed to a `gh-pages` branch** — that branch is a leftover from a
2023 deployment method, is not read by anything, and can be deleted. Changing
the Pages source back to "Deploy from a branch" would silently stop deploys,
because this workflow never writes a branch. (Monte-Carlo-Methods and
VisualMathLab do publish to `gh-pages`; this site deliberately does not.)

`docs/` is therefore **local build output only** — gitignored, never committed
from a source branch, and never hand-edited. A local `make build` is for
preview; it has no effect on the published site.

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
CV.pdf                          committed; built locally by `make cv`
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
- The PDF gets an automatic `Updated on: <date>` line, the date `make cv` ran.

**The PDF is built locally, not in CI.** CI renders HTML only, so it needs no
LaTeX install (TinyTeX's install step queried GitHub's API and failed deploys
on its anonymous rate limit). `make cv` renders `CV.qmd` to PDF with the local
LaTeX and copies it to `CV.pdf` at the repo root, which is committed;
`resources: [CV.pdf]` in `_quarto.yml` copies it into `docs/`, where the HTML
CV's "Download PDF" link points. So after editing `CV.qmd` or `cv/*.qmd`, run
`make cv` and commit `CV.pdf` with the change, or the PDF goes stale. Do not
remove `pdf` from `CV.qmd`'s formats; `make cv` depends on it.

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
weight: 3                 # odds of being the home page's random pick
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
- **`weight:`** controls the home page's random-pick draw (see §5.1). It has no
  effect on the Projects listing, which always shows everything, and none on the
  two pinned cards, which are named by slug in the generator.
- **Images.** Every project cover is local. Some projects use a **screenshot**
  of the thing itself, committed as `images/projects/<slug>.png`: the two apps
  (`ams-course-explorer`, `visual-math-lab` — the latter a crop of the
  controls and dot grid of the positive-predictive-value app, with the
  analytics dialog dismissed), and a figure or formula from the notes for
  `intro-to-optimization`, `group-cohomology`, `expository-notes` and
  `hitchhikers-guide-algebraic-topology`. Screenshots are downscaled to at
  most 1600px wide, and any wider than 3:2 is padded to 3:2 on its own
  background colour first — a 4:1 formula strip would otherwise be cropped to
  its middle third by the card's `object-fit: cover`. Every other cover is
  generated by `_scripts/make_covers.py` into `images/projects/`. Two kinds:
  **real figures** (`FIGURES` in that script) that draw the mathematics the
  project is about — the Penrose tribar for sheaf cohomology, the Weierstrass function, an icosahedron, the Riemann surface of the
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

### 5.1 The home page's two card sections

`_scripts/build_home_cards.py` writes `_includes/home-cards.html`, which the home
page pulls in via `include-after-body`. It holds two sections:

1. **Featured** — two *fixed* project cards, named by slug in the `PINNED` list
   at the top of the script (currently `ams-course-explorer` and
   `visual-math-lab`, shown in that order). They ignore `weight:` entirely and
   need no JavaScript. To change what is featured, edit `PINNED`. A slug that
   matches no file logs a warning and is skipped rather than failing the build.
2. **A random pick** — one project card and one blog-post card, each drawn in the
   browser on every page load.

Pinned projects are **excluded from the random project pool**, so one page never
shows the same project twice.

#### Weighting the random pick

Items are drawn with probability proportional to `weight:`:

| `weight` | meaning |
|---|---|
| `0` | never drawn — still listed on the Projects page |
| absent or `1` | the default |
| `n` | `n` times as likely to be drawn as a `weight: 1` project |

Weights are relative, not percentages, so they do not need to sum to anything.
The current spread is 3 for flagship course notes, 2 for substantial course
redesigns, 1 for individual Mathcamp classes, and 0 for the two grab-bag index
pages (`mathcamp-assorted`, `expository-notes`). The two apps carry `weight: 5`,
which is now inert — they are pinned. These are a starting point — Apurva tunes
them.

**Blog posts use the identical mechanism.** The script scans `projects/*.qmd`
*and* `math-blog/posts/**/*.qmd`, drops everything at weight 0, and embeds both
lists as JSON. The highest-weighted item of each kind is baked into the HTML as
the no-JavaScript fallback. A non-numeric weight logs a warning and falls back to
1; a negative one is clamped to 0.

Post filenames contain spaces, so hrefs and image paths are percent-encoded by
the generator. Post `image:` paths are frontmatter-relative and get rewritten
relative to the site root.

The cards read from disk and make **no network request** — no fetch, no
scraping of rendered listings, no `weights.json`. They therefore work offline and
under `quarto preview`. Keep it that way; the data they need is all local.

Section chrome is styled by `.home-section` / `.home-section__title` /
`.home-section__note` in `_theme/base.scss`. A pinned card has no eyebrow, so
`.home-card__thumb:first-child` drops the eyebrow's top margin and the thumbnail
sits flush with the card top. The whole card is clickable because the title's
`<a>` gets an `::after` overlay stretched over the card (`position: relative`
on `.home-card`). The random-pick cards' "See all projects" and "Read the blog"
footer links sit above that overlay with `z-index: 1`. Without it, they would
open the card's own page instead. Any other link added inside a card needs the
same treatment.

### Adding a project

Create the `.qmd`. Nothing else. The listing, the category filter, and the home
page's random pick all pick it up on the next render.

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

GitHub Pages is **off** on the old `math-blog` repo, and must stay off. A
project site at `apurvanakade.github.io/math-blog/` served from that repo would
take precedence over the `math-blog/` folder in this user site and silently
shadow every post with the stale archive copy.

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
subtree. `math-blog/_metadata.yml` sets `echo: false` for the whole subtree.

### mathviz

[mathviz](https://github.com/apurvanakade/mathviz) is the chart and panel
library behind Visual Math Lab and the Monte Carlo notes: Plotly charts that
follow the light/dark toggle, `ojs-*` control panels, and numerical helpers
under `window.VM`. This site consumes it the same way Monte-Carlo-Methods does.

- **Install.** `_scripts/update-mathviz.sh` (a copy of Monte-Carlo-Methods'
  hook) installs the newest tagged release into
  `_extensions/apurvanakade/mathviz/` before every render — a full render
  always checks, `quarto preview` at most hourly. A new mathviz release reaches
  this site on the next render. Never edit the installed copy; fix mathviz
  upstream.
- **Opt in per post, not site-wide.** A post that uses `VM` puts
  `filters: [mathviz]` in its frontmatter. The filter loads Plotly (~3.5 MB)
  and math.js from a CDN into the page's `<head>`, so enabling it in
  `_quarto.yml` or `math-blog/_metadata.yml` would make every page download
  them. Currently only `nth-fibonacci.qmd` opts in.
- **Not mathviz's theme.** Monte-Carlo-Methods uses mathviz's SCSS theme; this
  site keeps its own. Instead, `_theme/base.scss` points mathviz's `--vm-*`
  tokens at the `--site-*` palette. They are declared on `body`, not `:root`,
  because mathviz's dark defaults sit on `body.quarto-dark` and a value
  inherited from `:root` would lose to them.
- **Writing a chart.** Follow Monte-Carlo-Methods' CLAUDE.md ("Figures"): a
  `vmTheme` / `chartColors` pair per page, a `VM.plotting.persistentPlot()`
  per chart made in a setup cell, trace colours from `chartColors.*` never
  literals, and `VM.plotting.plotWithLegend` for any chart with a legend.

### Post frontmatter

```yaml
---
title: Bayes Theorem
description: "One sentence. Shown on the listing cards."
date: 2025-06-02
weight: 1                 # 0 = never drawn for the home page's random pick
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

- **One typeface throughout: Inter** (variable, with its optical-size axis) for
  prose, headings, navbar and UI alike; **JetBrains Mono** for code. Both load
  from Google Fonts via `_includes/fonts.html`. The setting deliberately mirrors
  [visualmathlab.com](https://www.visualmathlab.com/) so the two sites feel like
  siblings: 17px body at line-height 1.65, page titles at weight 300 with
  −0.02em tracking, section headings semibold with normal tracking, navbar brand
  at weight 400. An earlier serif-body / sans-heading pairing with bold,
  tightly-tracked headings and tracked-out uppercase labels read as a corporate
  site; do not reintroduce any of those. Category chips are lowercase on a soft
  surface with no border, and the override has to repeat Quarto's own three
  selectors (`.quarto-title .quarto-categories .quarto-category`,
  `.quarto-grid-item .listing-categories .listing-category`,
  `div.quarto-post .listing-categories .listing-category`) because a bare
  `.quarto-category` rule loses on specificity.
- Palettes are exposed as CSS custom properties (`--site-ink`, `--site-muted`,
  `--site-accent`, `--site-rule`, `--site-surface`, `--site-shadow`,
  `--site-thumb-bg`). **Component rules in `base.scss` must use those
  variables, never literal colours** — that is what keeps one rule working in
  both schemes. There is no font variable: with a single family, Bootstrap's
  `$font-family-base` covers every element and components need no
  `font-family` of their own.
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
- **No em dashes** in content, in any form (`---`, `—`, `&mdash;`). Apurva's
  preference: use a colon, semicolon, comma, parentheses or a new sentence.
  This includes frontmatter `description:` text, which also feeds the
  generated home-page cards.
- Section headers are `##` / `###`. Do not use `{-}` to hide sections from the
  TOC any more; the listing and CV layouts handle their own navigation.

---

## 10. Known constraints

Standing facts about this repo that are easy to trip over and are not obvious
from the files themselves. Each one is described in full in the section named.

- **GitHub Pages must stay off on the old `math-blog` repo** (§6). Turning it
  on would shadow every post on this site with the archive copy.
- **mathviz is fetched at render time** (§6). The pre-render hook needs
  network access to update it; offline it builds with the installed copy, and
  on a fresh clone with no copy it fails. `_extensions/` is committed so that
  case does not arise.
- **`docs/` is gitignored, local build output** (§2). It is not committed and
  has no effect on the published site — only a push to `main` (or a
  manual workflow run) does. Never hand-edit it.
- **Deploys come from `main`; work lands on `develop`** (§2). Release with
  `make release`, a fast-forward only. Never squash into or force-push `main`.
- **Pages is set to "GitHub Actions", not "Deploy from a branch"** (§2). The
  workflow uploads an artifact; it never writes `gh-pages`. Flipping that
  setting back to a branch source stops publishing silently.
- **The `math-blog/` directory name is load-bearing** (§6). It is what keeps
  every published post URL unchanged; renaming it breaks every shared link.
- **All cover art is local** (§5). Nothing hot-links a remote image any
  more; `_scripts/make_covers.py` is the only source of
  `images/projects/*.svg`; the `*.png` covers are committed screenshots.
