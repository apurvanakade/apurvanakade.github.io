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
| `index.qmd`, `references.qmd`, `rec-letters.qmd` | `_quarto.yml` |
| `teaching-portfolio.qmd` | `_includes/portfolio-preamble.tex` |
| `courses/**/*.qmd` | `courses/_metadata.yml` |
| `projects/*.qmd` (frontmatter + prose) | `_theme/*.scss`, `_theme/*.css` |
| `projects/index.qmd` | `_filters/*.lua` |
| `CV.qmd`, `cv/*.qmd` | `_includes/*.html`, `_includes/*.ejs` |
| `blog/index.qmd`, `blog/*.qmd` | `_scripts/*.py` |
| `blog/drafts/*.qmd` | `cv/preamble.tex` |
| `styles.css` (personal CSS overrides) | `projects/_metadata.yml` |
| | `blog/_metadata.yml`, `blog/drafts/_metadata.yml` |
| | `blog/_includes/*.html` |
| | `CLAUDE.md`, `.claude/**` |

`_extensions/apurvanakade/mathviz/` belongs to neither column: it is an
installed upstream release, overwritten by `_scripts/update-mathviz.sh` on the
next render. Nobody edits it (see §6, "mathviz").

**Consequences for Claude:**

- Content files stay *prose plus minimal YAML*. No raw HTML, no `::: {.div}`
  wrappers, no shortcodes, no chrome. If a page needs structure, add it in a Lua
  filter or an include — never inline in a content file. **One exception:
  `<iframe>` embeds in blog posts.** Apurva embeds YouTube videos, Visual Math
  Lab apps and the like by pasting the embed code those sites hand out; the
  theme makes it fit (§7). The one thing to set is `height=` in pixels.
- `styles.css` is Apurva's scratch space. Never write to it. All generated CSS
  goes in `_theme/`.
- Anything in `_includes/` that says `GENERATED` is overwritten on every render.
  Change the generator in `_scripts/`, not the output.

---

## 2. Build & deploy

```bash
make build     # quarto render --to html --output-dir docs/   (local only, gitignored)
make pdfs      # CV and teaching portfolio PDFs into _pdf/ (local only)
make cv        # just the CV's PDF; `make portfolio` likewise
make clean     # rm -rf docs/
make covers    # regenerate the SVG project, course and blog formula covers (rarely needed)
make update-mathviz  # force a check for a newer mathviz release
make release   # fast-forward main to origin/develop and push: publishes the site
quarto preview # local live preview (not in the makefile)
```

There is no test suite and no linter. **Verification is visual**: render, serve
`docs/` on a local port, and screenshot with Playwright (installed) in both
colour schemes before claiming a style change works. Quarto's dark mode is a
manual toggle — click `.quarto-color-scheme-toggle`, don't rely on
`prefers-color-scheme`.

`quarto render` runs two pre-render hooks defined in `_quarto.yml`:

- **pre-render** `_scripts/update-mathviz.sh` → installs the latest mathviz
  release into `_extensions/` (§6, "mathviz")
- **pre-render** `_scripts/build_home_cards.py` → writes `_includes/home-cards.html`

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
  through all of the above end to end: worktree, PR, a review by a fresh
  agent that has not seen the session (its prompt is
  `.claude/skills/ship-pr/maintainer-review.md`; Copilot does not review
  here), check, merge, cleanup, and always a final `make release`, even for a
  repo-only change, so `main` never lags `develop`. When a rule here changes, update it there
  too. `.claude/settings.json` pre-approves the commands it runs (PR create,
  diff, comment, review API calls, check and `--merge`, pushes to `origin`, `make release`) and denies
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
blog/index.qmd                  all posts, grid listing
blog/<post>.qmd                 every post, beside the listing
blog/drafts/*.qmd               rendered and published, but not listed anywhere
blog/images/                    every post's and draft's images, one flat folder
CV.qmd                          assembles cv/*.qmd; renders to HTML *and* PDF
cv/<section>.qmd                one CV section per file
teaching-portfolio.qmd          teaching philosophy, courses, development; HTML *and* PDF
rec-letters.qmd                 recommendation-letter instructions and checklist
_pdf/                           gitignored; local PDFs from `make pdfs` (§4)
references.qmd
courses/index.qmd               table listing of the course pages
courses/<course>/index.qmd      one course: overview, outline, links
courses/<course>/*.qmd          further pages (exams, project)
courses/<course>/*.pdf          syllabus and project slides, as-is
```

Navbar: **Home · Projects · Blog · Teaching ▾ · CV**. `Teaching` is a dropdown
holding the teaching portfolio, course pages,
recommendation-letter instructions, and references.

**There is no sidebar for the blog subtree, deliberately.** The blog index
already carries a grid listing plus a categories rail, and every post has a
back-link, so a sidebar would be a column of duplicate navigation. The standalone blog used an explicit sidebar file list in its
`_quarto.yml` and it had gone stale — it still pointed at a post deleted months
earlier. Listings cannot rot that way. If a sidebar is ever wanted again, note
that Quarto rejects `auto:` globs combined with a `href:` on the same section.

### Course pages

`courses/` holds public copies of Canvas course sites (Discrete Mathematics,
Monte Carlo Methods, Introduction to Computational Mathematics, Foundational
Mathematics of AI, Graph Theory), linked from each course's "Sample
materials" heading in `teaching-portfolio.qmd`. Those links are absolute
`https://apurvanakade.github.io/courses/...` URLs so they also work in the
PDF. They are copies, not
mirrors: content was pulled once from the JHU Canvas API and rewritten as
plain `.qmd`, and nothing syncs them. The Canvas page style is not reproduced.

**What may be copied over, and what may not.** These pages are public, and the
Canvas sites they come from were not:

- **Never**: homework, quiz, exam, practice-exam or solution files (or links
  to them); TA or student names, emails, photos or bios; project group rosters;
  Zoom links, room numbers, office-hour tables; links into Canvas, Gradescope,
  zyBooks, Microsoft Forms or SharePoint folders (they need a JHU login).
- **Yes**: Apurva's OneNote class-note share links (`1drv.ms`; Apurva accepts
  that they may stop working), course descriptions, outlines and schedules,
  exam topic lists and policies, project guidelines, project ideas, and
  project *titles* without the students' names. Syllabi and project slides are kept as the
  original PDFs, after checking their text for names other than Apurva's.

`courses/index.qmd` lists them as cards through a custom listing template,
`_includes/course-cards.ejs`, which reuses the home page's `.home-card`
styles. Each card's cover is `images/courses/<folder>.svg`, a real figure
drawn by `_scripts/make_covers.py` (`COURSE_FIGURES`), so a new course needs a
new entry there. Those covers are referenced only from the template, where
Quarto cannot discover them, so `_quarto.yml` names `images/courses/*.svg` in
`resources:`. The template's output is read as Markdown, so its lines are not
indented (an indented line becomes a code block). The term badge is the
page's `subtitle:`, and the course code is read off the start of its
`description:` ("EN.553.171 at Johns Hopkins: ..."), so keep descriptions in
that shape.

`_filters/course-page.lua` (applied by `courses/_metadata.yml`) turns three
shapes into page furniture: the bullet list before the first `##` becomes
pill buttons (an item that opens with a link becomes a pill, the rest of the
item its note); a table whose first column is "Exam" with a "Date" column
becomes date tiles ("Monday, October 5" is split into weekday, month and day);
and in a table whose first column is "Week", rows mentioning an exam are
highlighted and rows with an empty week (a break) are greyed. Those rows are
marked by an empty span in the first cell and styled with `tr:has(...)`,
because Quarto rebuilds some tables after the filter runs (the Graph Theory
schedule, with math and links in its cells) and drops classes on the `<tr>`.

Each course's `index.qmd` carries `subtitle:` (the term) and `date:` (the
term's start) for the cards and their sort. That date is not a
publication date, so `courses/_metadata.yml` adds the body class
`course-page` and `_theme/base.scss` hides the title block's "Published" line
for it.

The Canvas API token lives in the gitignored file `canvas API token` at the
repo root (host `jhu.instructure.com`; `canvas.jhu.edu` refuses API calls).
Never commit it or copy it into another file.

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

**The PDF is local only: never committed, never published, never linked.**
CI renders HTML only, so it needs no LaTeX install (TinyTeX's install step
queried GitHub's API and failed deploys on its anonymous rate limit), and the
site offers no PDF download, so there is no committed PDF to keep in step with
every edit. `make cv` (or `make pdfs`, for both PDFs) renders `CV.qmd` to
PDF with the local LaTeX and copies it into the gitignored `_pdf/` folder,
which Quarto skips because of its leading underscore, so a full render does
not delete it. The HTML format sets `format-links: false`, or Quarto would add
an "Other Formats" link to a PDF that is not on the site. Do not remove `pdf`
from `CV.qmd`'s formats; `make cv` depends on it.

**The HTML CV adds three things the PDF does not** (all configured at the top
of `cv.lua`): Experience and Education are drawn as a timeline, one dot per
entry in the colour of the institution the entry names (`INSTITUTIONS`; an
entry naming none, or several, gets a hollow dot); Teaching's course lists
become one row per term with a chip per course, read from `#### Term`
headings or from "Course, Term" items, plus a link to the teaching portfolio;
and Conferences Attended shows its first five entries with the rest behind a
`<details>` toggle. The LaTeX branch returns before any of this, so `make cv`
output is unaffected. Each `###` in a CV section is wrapped in a `<section>`
by Pandoc, so every `h3` is its section's first child; the space between
sub-groups is therefore set on `section.level3`, not on the `h3`.

Entries in `BOLD_SECTIONS` (Course Design & Materials) are set in bold in
both formats, because each one is a title with a line of detail beneath it;
the HTML needs `.cv-entry-text strong a { font-weight: inherit }`, since
Bootstrap resets links to weight 400.

**So the content convention is: one entry per paragraph, year last, after a comma.**
Write `Faculty Forward Fellowship, JHU, 2025` and the layout takes care of itself.
Set `cv-layout: false` in frontmatter to switch the filter off.

### The teaching portfolio

`teaching-portfolio.qmd` is built the same way as the CV (HTML in CI, a local-only PDF by
`make portfolio`, no PDF link), but does **not** use
`_filters/cv.lua`. Its `##` sections are Teaching philosophy, Courses,
Awards and grants, Professional development, Mentoring and academic
service, and Syllabi and sample materials. Courses, awards, professional
development and service repeat what the CV says, so a change to one of
those in `cv/*.qmd` is made in the portfolio too. There is no
separate teaching statement page: its prose lives in Teaching philosophy and
Professional development; its old URLs are not redirected (§8). Under Courses each
`###` is an institution and period ("Northwestern University, 2021-2023"),
and each course is a `####` under it, holding a pipe table
(Semester · Student level · Students · TAs · Course rating · Instructor rating)
followed by `#####` notes and a `##### Selected student comments` list. The
extra level is for the TOC: `toc-depth: 3` stops at the institutions, since
one line per course made the sidebar run off the screen. The tables are why
the portfolio does not use `cv.lua`: the CV's `cvsection` list environment
cannot hold a table (see below). The ratings
and quotes are copied by hand from the evaluation PDFs in the
`apurvanakade/PDFs` repo; a semester with several sections shows the
response-weighted mean, and each rating carries its own scale (`/ 5` at JHU,
`/ 6` at Northwestern, `/ 7` at Western Ontario) because the institutions'
scales differ. The questions and scales are explained once, in a footnote on
the first table's "Course rating" header, which HTML renders at the end of the
page and LaTeX at the foot of that page. Its PDF
layout lives in `_includes/portfolio-preamble.tex`: `\needspace` before each
heading so a course title is never stranded above a page break, `titlesec`
setting the institution (`\subsubsection`) a size up and turning `####` and
`#####` (LaTeX's `\paragraph` and `\subparagraph`, run-in headings by
default) into display headings so a table or list can start below them, and
`\LTleft=0pt` so tables sit flush with the prose rather than centred at
differing widths.

**The portfolio's visuals all come from `_filters/portfolio.lua`**, named in
the page's `filters:`, so the `.qmd` stays headings, pipe tables and lists.
It reads the course tables and builds, for HTML and LaTeX alike: a summary
band above the first `##` (courses, students, universities, first year, median
JHU instructor rating since `CURRENT_ROLE_START`), a dot chart of every
semester's instructor rating as a percentage of its scale at the top of
`## Courses` (in HTML its hover tooltip is a small inline script, because an
SVG `<title>` shows only after a second's rest and never on touch), an institution badge and muted code in each course `####`
(parsed from its trailing "(Institution, code)"), and quote cards from the
list under `##### Selected student comments`. HTML alone also gets rating bars
in the tables, pill links from `##### Sample materials`, a link card to the
matching `projects/` page (`COURSE_PROJECTS` in the filter; title, image and
description are read from that page's frontmatter), and icon tiles from the
first list in `## Teaching philosophy` whose items all open with a **bold
label** (icons chosen by `TILE_ICONS`). A heading or list that does not match
these shapes is left as it is. So the content conventions are: write a course
heading as `#### Name (Institution, code)` under its institution's `###`
(the filter's `COURSE_LEVEL` and `NOTE_LEVEL`), with the institution spelled as in
`INSTITUTIONS`, keep the table's column names, and end each comment with
`(Term)` after the closing quotation mark. Mathcamp is the exception: one
`#### Classes (Mathcamp)` holds every Mathcamp class, one row each, in a table with a Class column and no student or rating columns
(there is no evaluation data). Its `INSTITUTIONS` entry is marked
`program = true` so the summary band's "courses" and "universities" counts
leave it out. Under Courses, `portfolio.css` sizes the `h3` institution,
`h4` course and `h5` notes itself, because the theme's `h5` is larger than
its `h4`.

Its HTML styles are `_theme/portfolio.css`, which the filter attaches to this
page alone as an HTML dependency, so they never reach another page; the LaTeX
side (colours, `\instbadge`, the `portfolioquote` and `portfoliostats`
boxes) is in `_includes/portfolio-preamble.tex`. Every HTML class the
filter emits starts with `portfolio-` (BEM-style parts, as in
`portfolio-chart__tip`), so no rule from Bootstrap, Quarto or mathviz (whose
classes start with `vm-` or `ojs-`) can reach these elements, and none of
these rules can reach theirs. Keep that prefix on any class added here. Course
tables are wrapped in `div.portfolio-course__table` rather than given a class,
because Quarto drops the classes of a table whose header holds a footnote; the
wrapper also lets a table scroll sideways on a phone. The `portfolio-inst-*`
classes land on each course's `<section>` too (Pandoc's `section-divs`), so
they set only custom properties and never a visible style.

Institution colours are the site-wide tokens described in §7; in the chart
each institution also has its own marker shape and a labelled band.

### The recommendation-letter checklist

`rec-letters.qmd` keeps its checklist as plain Markdown task-list items
(`- [ ]`), which `base.scss` lines up with a hanging indent. It has no PDF
version, by Apurva's choice: the page is the only copy.

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
  The label is `\smash`ed: a label that wraps (Grants & Awards, Course
  Design & Materials) otherwise gives the first line its depth and pushes the
  section's first entry down below the label.

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
  whole directory, and includes `_includes/projects.html`, a small script
  that adds `inst-chip` classes to the JHU, Northwestern, UWO and Mathcamp category
  chips (a chip carries only its text, so CSS cannot select it) and splits
  the listing's category rail into Kind, Venue and Topic groups. A category
  in neither its `KIND` nor its `VENUE` list is a topic.
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
*and* `blog/*.qmd`, drops everything at weight 0, and embeds both
lists as JSON. The highest-weighted item of each kind is baked into the HTML as
the no-JavaScript fallback. A non-numeric weight logs a warning and falls back to
1; a negative one is clamped to 0.

Hrefs and image paths are percent-encoded by the generator, in case a filename ever contains a space. Post `image:` paths are frontmatter-relative and get rewritten
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

The blog ("Sh*tty First Drafts") lives under `blog/` in this repo. It was
originally a separate repository, `git@github.com:apurvanakade/math-blog.git`,
which still exists as a read-only archive (see below). There the name was
that site's navbar brand; here the brand is "Apurva Nakade", so the name
lives in `blog/index.qmd`'s `title:`, and the navbar item stays "Blog".

### URLs and the GitHub Pages precedence trap

Posts are served directly under `/blog/`: `blog/ln-series.qmd` renders to
`apurvanakade.github.io/blog/ln-series.html`. Earlier layouts
(`/math-blog/...`, `/blog/posts/maths/...`, `/blog/posts/math/...`,
`/blog/math/...`, `/blog/scribbles/...`) were
renamed without redirects (§8), so those URLs 404. Renaming a directory or post
again would break every link shared since, so leave the names alone.

GitHub serves a project site (a repo named `blog` with Pages on) at
`apurvanakade.github.io/blog/`, and a project site takes precedence over a
folder of the same name in this user site. **No repo named `blog` may have
Pages enabled**, or it silently shadows every post. Pages is also off on the
old `math-blog` archive repo; nothing here lives at `/math-blog/` any more, so
that one is harmless either way.

### The archive repo

`/Users/apurvanakade/Github/math-blog` is a read-only archive; do not edit it.
Post history lives only there — the content came across as a file copy, so
`git log` on a post in this repo starts at the merge.

It also holds one post with no counterpart here: `posts/scribbles/begin-again` (its path there),
whose source was deleted but whose rendered HTML is still in that repo's `docs/`.
Recover it from there if it is ever wanted.

### Structure

The blog is flat: every post is `blog/<post>.qmd`, beside the one listing,
`blog/index.qmd`. There are no sections; a post's subject is carried by its
`categories:`, which the listing's rail filters on. All images, for posts and
drafts, live in one flat `blog/images/`, referenced as `images/foo.png` from a
post and `../images/foo.png` from a draft.

`blog/_metadata.yml` sets `echo: false`, the back-link include
(`blog/_includes/back-to-blog.html`) and the giscus config for the whole
subtree, `index.qmd` and drafts included. The back-link's `href` is the
root-relative `/blog/`, so the one include is right from a draft one folder
down too; Quarto rewrites it to a relative path. The index therefore sets
`comments: false`, and `body-classes: blog-index`, which `base.scss` uses to
hide the inherited `.post-backlink` (Quarto concatenates `include-before-body`
lists, so a page cannot replace an inherited include, only hide it).

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
  `_quarto.yml` or `blog/_metadata.yml` would make every page download
  them. Currently only `nth-fibonacci.qmd` opts in.
- **mathviz's theme is the site's palette** (§7), as on Monte-Carlo-Methods,
  so a chart or panel matches the page with no bridging, and a post moved
  between sites looks the same on each.
- **Writing a chart.** Follow Monte-Carlo-Methods' CLAUDE.md ("Figures"): a
  `vmTheme` / `chartColors` pair per page, a `VM.plotting.persistentPlot()`
  per chart made in a setup cell, trace colours from `chartColors.*` never
  literals, and `VM.plotting.plotWithLegend` for any chart with a legend.

### Post frontmatter

```yaml
---
title: "Random points in a triangle"
description: "One sentence. Shown on the listing cards."
date: 2025-05-12
weight: 1                 # 0 = never drawn for the home page's random pick
author: Apurva Nakade
categories: [randomness, triangles]
image: "images/random-points-triangle.png"
---
```

An essay's cover (a post about teaching, learning or the like, rather than a
piece of mathematics) is a public-domain image (a painting, engraving,
photo or logo from Wikimedia Commons, saved to `blog/images/`), never
AI-generated art. It is also shown in the post as a captioned figure, after
the first paragraph rather than above it, at
`{width="85%" fig-align="center" fig-alt="..."}`, with the caption naming
the work and linking its Commons page. That follows Substack: the reader
meets the text before the picture, and the inset marks the image as
decorative. `base.scss` centres the caption of any centred figure.

A post with no natural figure uses its formula as its cover:
`_scripts/make_equation_covers.py` typesets each formula in `COVERS` with the
local LaTeX (`latex` + `dvisvgm --no-fonts`, so glyphs become paths) onto a
soft gradient panel, writing `blog/images/<slug>-equation.svg`.
Output is committed. Never write a formula cover as SVG `<text>`: that is
how `f(s1, ..., sn) != 0` ended up on the cards.

Listing pages depend on `title`, `date`, `description`, `categories` and `image`;
missing metadata degrades the cards. **Quarto does not excerpt the post body** —
a post with no `description:` renders a card with no text at all, so every post
carries one. Any listing meant to show them must also name `description` in its
`fields:`. `weight` drives the home page draw (§5.1) —
the same mechanism as projects, now reading straight off disk.

### Comments

Posts carry a [giscus](https://giscus.app) comment box, set by the
`comments:` key in `blog/_metadata.yml`, and switched off again by
`blog/index.qmd` and `blog/drafts/_metadata.yml`. It is on posts and nowhere else, by
Apurva's choice: not on listing pages, drafts, projects, courses or the
personal pages (CV, portfolio, references, rec letters). Threads are GitHub
Discussions on this repo, in the **Announcements** category, whose
announcement format lets only maintainers and the giscus app open a thread, so
readers can reply but cannot start stray threads. The repo and category ids
are written out rather than left for Quarto to look up, because that lookup
calls GitHub's API at render time and CI is rate-limited (the same failure
that ruled out TinyTeX, §4). Commenting needs a GitHub account; reading does
not. `mapping: pathname` keys each thread to the post's URL, so renaming a
post orphans its comments: one more reason to keep URLs stable (§8). The
`light`/`dark_dimmed` giscus themes follow the colour toggle through Quarto's
own script. Every page carries that script's inert stub, so a `grep giscus`
of `docs/` matches pages without comments.

### Drafts

`blog/drafts/*.qmd` render and publish but appear in no listing. That was
true of the standalone blog too and was preserved deliberately. Quarto's
listing glob `*.qmd` also matches files in subfolders, so `blog/index.qmd`
excludes `drafts/**` explicitly. A draft with `draft: true` in its frontmatter
is published as an empty page instead (Quarto's default draft mode). They are
reachable by anyone with the URL — treat them as public.

## 7. Theme

```
_theme/base.scss    typography, layout, components (shared)
_theme/light.scss   light-scheme extras (the hover-shadow colour)
_theme/dark.scss    dark-scheme extras (shadow colour, light backing for figures)
_theme/portfolio.css  teaching portfolio only (§4); not part of the theme
```

Layered over mathviz's Quarto theme in `_quarto.yml`:
`light: [mathviz-light, base, light]`, `dark: [mathviz-dark, base, dark]`
(the first is `_extensions/apurvanakade/mathviz/theme/mathviz-*.scss`).
**The palette is mathviz's, not this site's**, because Apurva publishes posts
on several mathviz sites (Monte-Carlo-Methods, Visual Math Lab) and keeping a
second colour scheme in step was a maintenance burden. It is this site's
original palette (warm neutrals, deep teal accent, charcoal dark theme),
moved into mathviz's `src/css/tokens.css` so every mathviz site shares it. A
new mathviz release re-colours this site on the next render. There is no Bootswatch base
(cosmo/cyborg used to sit under the theme), so a Bootstrap component whose
default fill is light in both schemes needs a `--vm-*` rule in `base.scss`,
as `.input-group-text` (the listing's sort and filter boxes) has. mathviz's
theme also sets a few Bootstrap variables without `!default`
(`$border-radius`, 8px; `$code-color`, the muted text colour), so a
`!default` in `base.scss` cannot change them; change them upstream.

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
- Colours are mathviz's runtime tokens: `--vm-text`, `--vm-text-soft`,
  `--vm-accent`, `--vm-on-accent`, `--vm-border`, `--vm-bg` (page and card
  fill), `--vm-surface` (panels, chips, thumbnail backing). The one site token
  left is `--site-shadow`, the card hover-lift colour, because `--vm-shadow`
  is a whole `box-shadow`, not a colour. **Component rules in `base.scss` and
  `portfolio.css` must use those variables, never literal colours** (that is
  what keeps one rule working in both schemes), and never redefine a `--vm-*`
  token, or the site drifts from mathviz again. To change a colour, change it
  in mathviz upstream. There is no font variable: with a single family, Bootstrap's
  `$font-family-base` covers every element and components need no
  `font-family` of their own.
- Bootstrap's own `.card` background does not follow our palette; card components
  need an explicit `background: var(--vm-bg)` or they render mid-grey in
  dark mode.
- **Institution colours are site-wide tokens** in `base.scss`, on `body` with
  dark overrides on `body.quarto-dark`, used by the portfolio, the CV
  timeline and the Projects category chips; the portfolio PDF repeats them in
  `_includes/portfolio-preamble.tex`. JHU and Northwestern use official
  colours: `--chip-*` (badges, chips) JHU Heritage Blue and Northwestern
  Purple, `--inst-*` (marks) JHU Spirit Blue and Northwestern Purple (Purple
  30 in dark mode). Western is **gold**, not its own purple: Western Purple
  `#4F2683` is indistinguishable from Northwestern Purple `#4E2A84`, teal is
  ruled out because it is the accent, and orange (its earlier colour) sat too
  close to Mathcamp's red. Gold is too pale for white text, so its chips take
  dark text, and the light-mode mark is a darker gold (`#B8860B`) to stay
  visible on the page. Canada/USA Mathcamp is a fourth
  "institution", in its own red `#EB0A2D` (from mathcamp.org; `#F4707F` in
  dark mode), and colours its CV timeline dots, its Projects chip and its
  portfolio badge; anything new that colour-codes classes by where they were
  taught uses `--inst-mc` / `--chip-mc-*` for Mathcamp ones. Every use also
  names the institution in text or shape.
- **One rule for every embed.** `main iframe` in `base.scss` makes any
  `<iframe>` 85% of the column and centred, matching a post's inset opening
  figure (§6), so none overflows a phone, with a `--vm-border` border. Its
  `width=` is ignored; its height is its own `height=`, in pixels (383 suits
  a 16:9 video at that width; a Visual Math Lab app's Share
  dialog measures its own). `height="100%"` does not work, because in a
  flowing column it has nothing to resolve against and collapses to 150px.
  There are no per-site rules; keep it that way.
- **Every content table has a tinted header row** (`main .table > thead`),
  so course schedules, the portfolio's tables and any new table match.
- **Grid cards show the date above the title.** Quarto puts it in a footer
  with `flex-grow: 10`; `base.scss` moves it up with `order: -1` and
  `flex: none`.

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
  The wrapper does need `flex: none`: the card is a flex column, and without
  it the wrapper shrank to about 160px and cropped the bottom of every
  thumbnail.

---

## 8. Redirects

There are none, by Apurva's choice. Pages that moved in the 2026
reorganisation (`notes.html`, `rec letters.html`, `teaching statement.html`,
`teaching-statement.html`, every post under `/math-blog/`, now under
`/blog/`, everything under `/blog/maths/` and `/blog/posts/maths/`, and every
post under `/blog/posts/`, `/blog/math/` or `/blog/scribbles/`, now directly
under `/blog/`) now 404 at their old addresses. Do not add a redirect
mechanism back unless asked. A page moved from here on breaks its
old links, so prefer keeping URLs stable.

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

- **No repo named `blog` may have GitHub Pages on** (§6). Its project site
  would take precedence over this site's `/blog/` and shadow every post.
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
- **The `blog/` directory name is load-bearing** (§6). It is the post URLs;
  renaming it breaks every shared link.
- **No PDF is committed or published** (§4). `make pdfs` writes them to
  the gitignored `_pdf/` rather than the repo root, because a full
  `quarto render` deletes a `CV.pdf` or `teaching-portfolio.pdf` left at the
  root (both pages have a PDF format, and Quarto clears their old output).
- **All cover art is local** (§5). Nothing hot-links a remote image any
  more; `_scripts/make_covers.py` is the only source of
  `images/projects/*.svg`; the `*.png` covers are committed screenshots.
