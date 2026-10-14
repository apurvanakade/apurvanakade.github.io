---
name: ship-pr
description: Take a finished change to apurvanakade.github.io all the way to the live site -- commit on a branch in its own worktree, verify, open a pull request into develop, have a fresh maintainer agent review it, triage its findings, wait for the check, merge, fast-forward main (which publishes), and clean up. Use when asked to commit, push, open a PR, ship, land, merge, publish or release a change in this repository.
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
Do step 1 (CV), commit, `git push origin develop`, then skip to step 8
(release). Every run ends with a release, repo-only changes included, so
`main` never lags `develop` and the site is always re-rendered.

Anything touching `_quarto.yml`, `_theme/`, `_filters/`, `_includes/`,
`_scripts/`, `_extensions/`, `.github/` or an OJS cell is **not** small,
however few lines. Carry on.

If a PR number was given, skip to step 4 (unless it already has a
maintainer review, in which case skip to step 6).

## 1. PDFs

Nothing to rebuild. The CV and portfolio PDFs are local-only
(`make pdfs` into the gitignored `_pdf/`) and are never committed or
published (CLAUDE.md §4).

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

## 4. Maintainer review

Copilot does not review PRs here, so every PR gets a local review from an
agent that has not seen this session. It is a gate for the merge.

1. Spawn a fresh `general-purpose` agent (the Agent tool, not a fork, so it
   starts without this session's context) with the prompt in
   [maintainer-review.md](maintainer-review.md), filling in the PR number and
   the worktree path. Add nothing about the change: the point is a reviewer
   who knows the codebase but not the reasoning behind this work, the way a
   maintainer reading the PR cold would. Run it in the foreground; the next
   step needs its answer.
2. Post its findings on the PR as one review, so they become threads. Write
   the payload to the scratchpad and send it:

   ```sh
   gh api repos/apurvanakade/apurvanakade.github.io/pulls/<N>/reviews --input review.json
   ```

   with `{"event": "COMMENT", "body": "Local maintainer review.\n\n<VERDICT line>", "comments": [{"path": ..., "line": ..., "side": "RIGHT", "body": "**<severity>**: <comment>"}, ...]}`.
   A finding whose line isn't part of the diff can't be an inline comment
   (the API rejects the whole review); put it in `body` instead, as
   `` `path:line` -- comment ``. With no findings, post the verdict alone.
   A body finding has no thread to reply to or resolve, so step 5 must still
   fix or decline it and answer it with one PR comment
   (`gh pr comment <N> --body ...`) covering every body finding.

## 5. Triage every finding

```sh
gh pr view <N> --comments
gh api repos/apurvanakade/apurvanakade.github.io/pulls/<N>/comments   # inline
```

The agent read CLAUDE.md, but it can still be wrong: check each finding
against the code. For each unresolved thread:

- **Valid**: fix it. If it points at `_extensions/apurvanakade/mathviz/**`,
  it belongs in apurvanakade/mathviz: tell the user rather than editing the
  installed copy.
- **Contradicts CLAUDE.md, wrong, or already handled**: decline it.

Reply to every thread with one line saying what was done or why not:

```sh
gh api repos/apurvanakade/apurvanakade.github.io/pulls/<N>/comments/<id>/replies -f body="..."
```

Then resolve it (`resolveReviewThread` GraphQL mutation; get thread ids from
`pullRequest.reviewThreads`). Commit the fixes on the same branch and
`git push`; the check re-runs. The review is not repeated on the fixes.

## 6. Checks

```sh
gh pr checks <N> --watch
```

`pr-check.yml` renders the whole site. If it fails, read the log
(`gh run view <run-id> --log-failed`). A transient network error (a 403 or
timeout from GitHub's API, a mathviz fetch) gets one `gh run rerun --failed`;
anything else is fixed on the branch, pushed, and waited on again.

## 7. Merge into develop

Only when every check is green and every review thread has a reply:

```sh
gh pr merge <N> --merge
git -C ~/Github/apurvanakade.github.io pull --ff-only
```

`--merge`, not `--squash`: it keeps the branch's history on `develop`.

## 8. Release: fast-forward main (always)

Every run ends here, whatever the change. From the `develop` folder:

```sh
make release    # git fetch origin && git push origin origin/develop:main
```

Then watch the deploy: `gh run list -b main -L1`, `gh run watch <id>`. A
transient failure gets one rerun; otherwise report it. If the push is refused
as non-fast-forward, the histories have diverged: on `develop`,
`git merge -s ours origin/main`, push, and retry.

## 9. Clean up

Stop the worktree's preview if one is running. If
`git -C ../apurvanakade.github.io-<slug> status --short` lists a modified
tracked file, stop: that is unmerged work. Otherwise:

```sh
git worktree remove --force ../apurvanakade.github.io-<slug>
git branch -d <branch>
git push origin --delete <branch>
```

## Report

Say what shipped: the PR link (or the direct push), the maintainer
review's findings fixed or declined (with the reason), anything left open, and whether the deploy succeeded.
