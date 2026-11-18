---
name: pr-submit
description: Create or update a GitHub pull request for the Sababi project with a structured description, after the repository gates pass. Use when a change to the repository is done and its checks pass (CLAUDE.md).
---

Create or update a pull request. CLAUDE.md asks for it when the work is done and the checks pass; the user does not have to ask.
GitHub access: use the `mcp__github__*` tools (load them with `ToolSearch`) when `gh` is not logged in, which is usual in cloud sessions. `gh` is the same operation on the owner's Mac. Where this file says `gh <x>`, do the same with the tool that works.
The PR owner is `sw-developer` (or the agent that made the change). The `code-reviewer` agent does step 4 of section 4, and `localization-reviewer` prepares the string list when `strings.csv` changed.
Do not ask before creating the PR, updating its title or body, or posting the review comment of step 4 (CLAUDE.md, "Pull requests": Alon, 2026-10-29).

## 1. Gates (stop when one fails)

1. Access: the account for this repo is `alonzo86` (remote `git@github-personal:alonzo86/remote-play.git`). If `gh auth status` fails, use the
   `mcp__github__*` tools; do not stop and do not ask the user to log in unless no tool works. Never use another account.
2. Run the `run-tests` skill: the suites that your change touches pass and `gdlint scripts tests tools` is clean. Do not run the full coverage (`tools/coverage.sh`) unless the user told you to.
   Report the real numbers. Do not create the PR when one fails. Do not report a pass for a check that did not run.
3. The `sync-docs` skill was run: the PR body will have the section "Docs and tests aligned" (see section 3). Do not create the PR without it.
4. The branch is the one the session gave you, and the changes are committed and pushed. Requirements files changed with the behavior (REQ-GM-5).

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

## Docs and tests aligned
What the change removed or renamed, the files searched (`sync-docs` step 2), the documents and tests changed, and the hits left on purpose
(history, owner-only text) with the reason.

## Coverage
Say that the full coverage was not run (CLAUDE.md), or, when the user asked for it, the total line coverage and the lowest modules
(from `tools/coverage.sh`). Name any module set aside in `tools/coverage/exclusions.txt`, with the reason.

## How to Test
Steps for a reviewer, from the tests the user listed. Add the on-device steps from `docs/MANUAL_TESTS.md` that apply.
```

How to compute the stats, from `git diff --numstat <target>...HEAD`:
- modules lines = added + deleted in `scripts/`, `android/` and `tools/`. tests lines = added + deleted in `tests/`.
- Modules % = modules / (modules + tests) * 100. Tests % = 100 - Modules %. Docs and assets are not counted.

End the body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## 4. Show, confirm, publish

1. Do not wait for a yes (CLAUDE.md, Alon): the title and body follow section 3, and the owner can edit the PR afterwards. Create it now.
2. A) `gh pr create --repo owner/repo --base <target> --head <branch> --title ... --body-file <temp file>`.
   B) `gh pr edit <n> --title ... --body-file <temp file>`.
   Use a temp file for the body to avoid escaping problems. Delete it after.
3. Subscribe to the PR (`mcp__claude-code-remote__subscribe_pr_activity`) so its comments and reviews wake the session. After each push, check the state of the GitHub Actions run (CLAUDE.md, "Continuous integration").
4. Run the `review` skill on the PR with `code-reviewer` (a separate agent, not the author) and post its findings as one comment (see that skill). This is required for every PR (CLAUDE.md).
   Add `security-reviewer` when the change touches network input, saved files, permissions, the camera or privacy data, and `localization-reviewer` / `license-reviewer` when they apply.
   Do not fix the findings yourself as the reviewer. The owner of the PR (`sw-developer`) addresses every finding with a fix or a justification and posts one summary comment; the reviewer then reviews again (at most 2 cycles, then `software-architect` decides; CLAUDE.md "Pull requests").
5. Continue to the merge and the closing of the issues (CLAUDE.md "Finishing work without the owner"). Do not stop after step 4.
6. Tell the user the PR link, the review result, what is merged and closed, and the exact action for the owner when something is left.
