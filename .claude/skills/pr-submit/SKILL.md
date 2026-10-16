---
name: pr-submit
description: Create or update a GitHub pull request for the Sababi project with a structured description, after the repository gates pass. Use only when the user asks for a pull request (CLAUDE.md).
---

Create or update a pull request. Do it only when the user asks for one.
Ask before each step that publishes: creating the PR, updating its title or body, and posting a comment.

## 1. Gates (stop when one fails)

1. `gh auth status`: the account for this repo is `alonzo86` (remote `git@github-personal:alonzo86/remote-play.git`). If it is not logged in,
   ask the user to run `gh auth login`. Never use another account.
2. Run the `run-tests` skill: tests pass, `gdlint scripts tests tools` is clean, and `GODOT=<path> tools/coverage.sh` reports every module at 80% or more.
   Report the real numbers. Do not create the PR when one fails. Do not report a pass for a check that did not run.
3. The branch is the one the session gave you, and the changes are committed and pushed. Requirements files changed with the behavior (REQ-GM-5).

## 2. Gather the inputs

Ask only for what is not already clear:
- A) create a new PR, or B) update an existing one (the PR number).
- Branch (default: the current branch) and target branch (default: the repository default branch, `main`).
- Issue number (optional). If given and the user agrees, fetch it with `gh issue view <n> --repo owner/repo --json title,body,labels,state`
  and pre-fill the title, the linked issue and the description. Show the values and let the user edit them.
- Title (optional). Description (optional). Default for A: the user gives it, or leave the placeholder. Default for B: keep the existing description.
- Whether to write the "How to Test" section, and the list of tests.

## 3. Compose the PR

Title: `[#<ISSUE_NUMBER>] <short description>`. Leave out the prefix when no issue is linked.

Body:

```
## Linked Issue
Closes #<ISSUE_NUMBER>        (remove this section when there is no issue)

## Description
<the user's text, or "To be filled by the developer.">

## Resolution
- The root cause (for a bug) and how the change fixes it. High level: the "why" and "how".

### Files Modified
- Stats: modules X%, tests Y%.
- A table with the columns "File" (file name only), "+", "-", "Description" (one sentence).
  Leave out files with minor changes (formatting, comments) and test updates, and say so in a footnote.

### Changes
What changed and how, in a few lines.

## Coverage
Total line coverage and the lowest modules (from `tools/coverage.sh`). Name any module set aside in
`tools/coverage/exclusions.txt`, with the reason.

## How to Test
Steps for a reviewer, from the tests the user listed. Add the on-device steps from `docs/MANUAL_TESTS.md` that apply.
```

How to compute the stats, from `git diff --numstat <target>...HEAD`:
- modules lines = added + deleted in `scripts/`, `android/` and `tools/`. tests lines = added + deleted in `tests/`.
- Modules % = modules / (modules + tests) * 100. Tests % = 100 - Modules %. Docs and assets are not counted.

End the body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## 4. Show, confirm, publish

1. Show the title and the full body. Wait for a clear yes.
2. A) `gh pr create --repo owner/repo --base <target> --head <branch> --title ... --body-file <temp file>`.
   B) `gh pr edit <n> --title ... --body-file <temp file>`.
   Use a temp file for the body to avoid escaping problems. Delete it after.
3. Bind the PR with the app's PR tools (`get_status`, then `bind_pr` if needed) and read its CI. Do not poll CI yourself.
4. Run the `review` skill on the PR and post its findings as one comment (see that skill). This is required for every PR (CLAUDE.md).
   Do not fix the findings unless the user asks. Tell the user what you found.
5. Tell the user the PR link, the review result and any module set aside.
