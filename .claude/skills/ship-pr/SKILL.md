---
name: ship-pr
description: Take a finished change to apurvanakade.github.io all the way to the live site -- rebuild the CV PDF if the CV changed, commit on a branch in its own worktree, verify, open a pull request into develop, wait for the check, merge, fast-forward main (which publishes), and clean up. Use when asked to commit, push, open a PR, ship, land, merge, publish or release a change in this repository.
argument-hint: "[PR number]  (default: open a PR for the current changes)"
---

# Ship a change

A change reaches `develop` through a pull request, and `main` only by
fast-forwarding `develop`; pushing `main` publishes the site. The rules are
CLAUDE.md §2 ("Branches", "Deployment"). Carry the change through every step
below without stopping between them. Never pass `--auto`, `--admin` or
`--squash` to `gh pr merge`, never force-push, and never merge a PR with a
failing check.

## 0. Does it need a PR at all?

Run `git status` and `git diff` (staged and unstaged), and
`git log origin/develop -3` in case it was already pushed.

A **small** change may be committed straight onto `develop`: a wording fix in
prose, a comment, or repo-only files (`CLAUDE.md`, `makefile`, `.claude/**`).
Do step 1 (CV), commit, `git push origin develop`, then skip to step 6
(release) unless the change is repo-only, in which case stop.

Anything touching `_quarto.yml`, `_theme/`, `_filters/`, `_includes/`,
`_scripts/`, `_extensions/`, `.github/` or an OJS cell is **not** small,
however few lines. Carry on.

If a PR number was given, skip to step 4.

## 1. CV PDF

If `CV.qmd` or anything under `cv/` changed, run `make cv` and include the
regenerated `CV.pdf` in the same commit. CI renders HTML only, so a CV edit
without this ships a stale PDF (CLAUDE.md §4).

## 2. Branch and worktree

`~/Github/apurvanakade.github.io` is the long-lived `develop` checkout and
stays on `develop`. Uncommitted changes there move to a worktree:

```sh
git stash push -u -m ship-pr
git worktree add -b <prefix>/<slug> ../apurvanakade.github.io-<slug> develop
git -C ../apurvanakade.github.io-<slug> stash pop
```

Prefixes: `post/`, `project/`, `fix/`, `style/`, `ci/`, `docs/`.

## 3. Verify, commit, open the PR

In the worktree:

- `make build` finishes with no errors.
- A style change is screenshotted in both colour schemes (CLAUDE.md §2,
  "Verification is visual"); a post with OJS cells is loaded in a preview with
  no console errors.
- Content follows CLAUDE.md §9 (no em dashes, image widths, etc.).

Commit with a message saying what changed and why, then:

```sh
git push -u origin <branch>
gh pr create --base develop --title "..." --body "..."
```

The body says what changed, why, and how it was verified, and ends with the
attribution line from the system reminder.

## 4. Checks

```sh
gh pr checks <N> --watch
```

`pr-check.yml` renders the whole site. If it fails, read the log
(`gh run view <run-id> --log-failed`). A transient network error (a 403 or
timeout from GitHub's API, a mathviz fetch) gets one `gh run rerun --failed`;
anything else is fixed on the branch, pushed, and waited on again. If a
review comment arrives, reply to it and fix or decline it against CLAUDE.md.

## 5. Merge into develop

Only when every check is green:

```sh
gh pr merge <N> --merge
git -C ~/Github/apurvanakade.github.io pull --ff-only
```

`--merge`, not `--squash`: it keeps the branch's history on `develop`.

## 6. Release: fast-forward main

From the `develop` folder:

```sh
make release    # git fetch origin && git push origin origin/develop:main
```

Then watch the deploy: `gh run list -b main -L1`, `gh run watch <id>`. A
transient failure gets one rerun; otherwise report it. If the push is refused
as non-fast-forward, the histories have diverged: on `develop`,
`git merge -s ours origin/main`, push, and retry.

## 7. Clean up

Stop the worktree's preview if one is running. If
`git -C ../apurvanakade.github.io-<slug> status --short` lists a modified
tracked file, stop: that is unmerged work. Otherwise:

```sh
git worktree remove --force ../apurvanakade.github.io-<slug>
git branch -d <branch>
git push origin --delete <branch>
```

## Report

Say what shipped: the PR link, whether `CV.pdf` was rebuilt, any review
comments and what was done with them, and whether the deploy succeeded.
