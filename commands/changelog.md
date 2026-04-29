---
description: Generate an engaging changelog entry from recent merges to main
argument-hint: [--since=<git-rev>]
---

Generate a changelog entry by reading recent merge commits and synthesising narrative entries.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --is-inside-work-tree`. If not inside a git repo, respond: "Not in a git repository — /changelog needs git history to work from." Stop here.

2. **Determine the lower bound (`--since`).**
   - If `$ARGUMENTS` contains `--since=<rev>`, use that revision.
   - Else read `docs/changelog.md`. The newest entry's footer should record its source commit on a line like `Source: [#N](url) · <short-hash>`. Use that hash as the lower bound.
   - Else default to `HEAD~20`.

3. **List merges.** Run `git log --merges <since>..HEAD --pretty=format:'%H|%s|%ai|%an'`. If the list is empty, respond: "No new merges since `<since>`. Nothing to add to the changelog." Stop here.

4. **Enrich each merge.** For each merge commit:
   - Parse the PR number from the subject (`Merge pull request #N` or trailing `(#N)`).
   - If a PR number is found and `gh` is installed (`gh --version`): run `gh pr view <N> --json title,body,mergedAt,author,url`.
   - If `gh` is unavailable or the call fails: fall back to `git show --stat <hash>` for the diff summary and commit body.
   - Look in `docs/plans/` for a markdown file matching the PR number (e.g. `N-*.md`) or a slug derived from the PR title. If found, read it for additional motivation.

5. **Synthesise.** Write one H3 markdown section per merge (group closely related merges only when they're obviously part of the same release). Each section:
   - Heading naming the change in human terms — not the PR title verbatim.
   - One opening sentence on *why* this matters to a reader.
   - 2–4 bullets covering what changed, anything observable to users, any caveat.
   - Footer line: `Source: [#N](pr-url) · <short-hash>` (omit the PR link if no PR was found).

   Tone: confident, narrative, slightly informal. No marketing fluff. No emoji.

6. **Write.** Prepend the new content under a `## YYYY-MM-DD` heading (today's date) at the top of `docs/changelog.md`. If the file doesn't exist, create it with a `# Changelog` H1 header first. Newest dated section sits above any existing dated sections.

7. **Report.** Tell the user how many entries were added, the path written to, and (if `gh` was unavailable) that synthesis used commit messages only.

## Degradations

- **No git repo** → step 1 abort with friendly message.
- **No merges in range** → step 3 no-op with friendly message.
- **`gh` missing or unauthenticated** → fall back to commit-message-only synthesis; mention this in the final report.
- **`docs/changelog.md` missing** → create it with the `# Changelog` header.
