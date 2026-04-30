---
description: Sweep todos/, open PR comments, and (if available) the Jira queue; rank the top moves
---

Pull from up to three inboxes — `todos/`, open PR comments on the current branch, and the user's Jira queue — categorise each item, rank by leverage, and surface the top three with rationale. Each source degrades gracefully if the underlying tooling isn't configured.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo.

2. **Source 1 — `todos/`.** Always read. Walk the `todos/` directory at the repo root. For each file, treat the filename as the item title and the first paragraph as the description. If `todos/` does not exist, log `(skipping todos/ — directory not present)` and continue.

3. **Source 2 — open PR comments.** If `gh` is installed and authenticated:
   - Detect current branch via `git rev-parse --abbrev-ref HEAD`.
   - Find an open PR for the branch and capture its number plus the `owner/repo` slug: `gh pr view --json number,url,headRepositoryOwner,headRepository 2>/dev/null`. If no open PR, skip silently.
   - Pull review threads with their resolved/unresolved state via the GraphQL API — `gh pr view --json comments,reviews` does **not** expose `isResolved`, so the unresolved filter would silently miss the exact items this skill is meant to surface. Call:
     ```
     gh api graphql -f query='
       query($owner: String!, $repo: String!, $number: Int!) {
         repository(owner: $owner, name: $repo) {
           pullRequest(number: $number) {
             reviewThreads(first: 100) {
               nodes {
                 isResolved
                 comments(first: 50) {
                   nodes { author { login } body path line createdAt url }
                 }
               }
             }
           }
         }
       }' -F owner="<owner>" -F repo="<repo>" -F number=<n>
     ```
     Filter to threads where `isResolved` is `false` and treat each as one triage item (use the first comment's body + path:line as the title context, link to the comment URL).
   - Also pull top-level PR conversation comments via `gh api repos/<owner>/<repo>/issues/<n>/comments` for issue-level remarks not attached to a code line. These have no resolved/unresolved state — include them all and let the user mark anything stale.
   
   If `gh` is not installed or not authenticated, log once: `(skipping PR comments — gh not configured)` and continue.

4. **Source 3 — Jira queue.** Check whether the Atlassian Rovo MCP is configured (presence of `mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql`):
   - **If configured**: query `assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC` (or equivalent). Pull up to 20 issues with summary, status, priority.
   - **If not configured**: ask the user once per session: `No Atlassian MCP detected — skip Jira sweep this session? (y/n)`. Cache the answer. If skipped, do not ask again until next invocation.

5. **Categorise every item** across all sources into one of:
   - **Correctness** — bug, broken behaviour, regression risk
   - **Scope** — feature work, scope clarification, design decision
   - **Cleanup** — refactor, debt, follow-up TODO
   - **Blocked** — waiting on someone or something external
   
   Each item gets exactly one category. If unsure, pick the closer fit and note the ambiguity in the rationale.

6. **Rank by leverage.** For each item, score on:
   - **Cost** — rough effort (S/M/L)
   - **Value** — what does fixing it unblock or improve? (low/med/high)
   - **Decay** — does the cost grow if you wait? (no/some/high)
   
   Top items are high-value, low-cost, decaying. Surface the **top 3** across all sources combined.

7. **Report.** Markdown report with:
   - Total items found per source.
   - Counts per category.
   - The top 3 items, each with: source, title, category, cost/value/decay, one-line rationale, suggested next move.
   - End with: "Consider `/plan <top-item-slug>` to lock in a plan for the top item."

## Degradations

- **No `todos/`, no PR, no Jira** → exit with friendly message: "No inboxes found to triage. Try `/init-workshop` to create `todos/`, or open a PR, or configure the Atlassian MCP."
- **`gh` missing** → log once and skip Source 2.
- **Atlassian MCP missing** → ask once per session; cache the answer.
- **Empty inboxes (configured but nothing to triage)** → report explicitly: "All clear — nothing in any inbox."
