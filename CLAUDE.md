# Sababi: notes for Claude

Godot 4.7 project (GDScript): a TV app and a phone controller app. Read `README.md` first.

## Rules for this repository

- Each game has a requirements file `docs/games/<id>.md`. All games also follow `docs/GAME_REQUIREMENTS.md`.
  Change the requirements file in the same commit as the behavior (REQ-GM-5). Use the `add-minigame` skill for new games.
- Do not run the whole test suite after every change. Run the touched suites (`run-tests` skill, step 2a) and `gdlint` before you submit a pull request. The whole suite (`tests/run_all.sh`, step 2b) runs only when the user asks or when the QA engineer (`.claude/agents/qa.md`) decides that the change needs it (for example a change of the net, the input, a shared module or the test tooling). Run a single test or check while you work only when it is needed. Do not report a pass for a check that did not run.
- Every text the user sees is a row of `assets/lang/strings.csv` (key, English, Hebrew, where, notes). The code uses the key (`connect.join`),
  never the English text. A new text adds its row in the same commit (FD-24, REQ-FL-63), with a short `where` (the screen and the place
  where the text shows). When the use of a text changes, change its `where` in the same commit. The file is UTF-8 with a byte order mark (Excel needs it for the Hebrew): keep the mark when you write the file.
- Every new or changed string is reviewed by the `localization-reviewer` (a new row, or a change in the English, the Hebrew or the key). A pull
  request that adds or changes strings lists each row (key, old text, new text, in both languages) in its description, and the `review`
  skill reports a change of strings that has no such list. Do not change the text of a row that is already in the app on your own: ask
  first, unless the user's request or an issue gives the new text. The rules for Hebrew text and for what only a native Hebrew reader
  can confirm are in `.claude/agents/localization-reviewer.md`.
- Do not decide on your own what the user sees (for example cutting or shortening text, hiding information). Ask the user first.
- Continuous integration (Alon, 2026-11-18): GitHub Actions (`.github/workflows/ci.yml`) is the CI that gives the signal. It runs on GitHub's own runners (`ubuntu-latest`; free for a public repository, owner, 2026-11-18); CircleCI stays disabled, so ignore it. Check the state of the Actions run of your pull request after each push (the jobs `lint`, `test` and `pixels`; `coverage` only reports): read it with the GitHub tools (`mcp__github__pull_request_read` `get_check_runs`, `mcp__github__actions_list`, `mcp__github__get_job_logs`; the log can be too large to show, then read it from the saved file). A failed job is a failed check: fix it, or when it also fails on `main` file an issue and say so in the pull request (it does not block the merge). A job that stays queued for a long time is not a failure of the change: say so, tell the user, and do not file an issue. Do not report a pass for a run that did not finish. The checks you run yourself (touched suites and `gdlint`) still come first: they are the gate for creating the pull request. The Actions run is also checked before the merge. A change that touches only Markdown, `docs/` or `.claude/` starts no `lint`, `test` or `pixels` job (the job `changes` decides): there is nothing to read, so say in the pull request that it needed no CI run, and do not wait for one.
- Work on the branch the session gives you. For a delegated sweep of issues, one `claude/issue-<n>-<name>` branch per pull request is allowed
  (worktrees may be used); the session branch is for work in a single pull request. When the user's request is a change to the repository, Claude creates the pull request when the work is done and the checks pass (Alon).

## Docs and tests stay aligned (Alon)

- A change is not finished, and its issue is not closed, until every document and test that it makes wrong is updated in the same pull
  request. Run the `sync-docs` skill (`.claude/skills/sync-docs/SKILL.md`) after the code works and before `pr-submit`: list what the
  change removed or renamed, search the whole repository for it, and update the requirements, plans, manual and automated test files,
  strings, tests and `README.md`. The PR description has the section "Docs and tests aligned".
- `code-reviewer` repeats the search and reports a stale hit as a finding. `qa` checks the test side. `project-manager` does not close an
  issue whose PR has no such section.
- The privacy notice, store texts and legal texts are owner only: the PR names what is out of date and carries the label `needs-owner`.

## Third-party libraries and resources

- Any library, plugin, addon, font, sound, image, model or other resource that another maker owns needs a row in `docs/THIRD_PARTY.md`,
  its license text next to the file and a license that allows a free app that is shipped in a store, in the same commit that adds it. The
  full list of what to add (items 1 to 5) is in `.claude/agents/license-reviewer.md`.
- Check the license before you add the resource, and say in the commit or pull request which license it has. Do not add a resource
  with no license, or with a license that does not allow a free app that is shipped in a store. Ask the user when you are not sure.
- `license-reviewer` (`.claude/agents/license-reviewer.md`) checks every PR that adds or changes such a resource. A license that is not
  permissive, not clear or missing is left for the owner.

## Tests and coverage

- Every module (each script file in `scripts/`) needs at least 80% line coverage. CI runs only the `unit` suites (tier column of `tests/suites.txt`) and the pixel checks, and it only reports the coverage: it never fails on it. **Do not run the full coverage (`tools/coverage.sh`, about 20 minutes) on your own.** Run it only when the user explicitly tells you to. Say in the pull request that the full coverage was not run. When the user asks for it: `GODOT=<path> tools/coverage.sh`, it fails when a module is below 80%; say the total and the lowest modules. A new test suite is added to `tests/suites.txt` only.
  New or changed code comes with its tests in the same change.
- `qa` and `automation-developer` do a test check for every implementation and every bug fix, without being asked (their agent files).
- Write tests that matter. A test checks a behavior: an input and the result, an error case, a state change, a rule from a
  requirements file. It must fail when that behavior breaks. Do not write a test only to run lines or to raise the number
  (a call without an assertion, a copy of the code in the test). If code has no behavior worth a test, say so and do not test it.
- A module that needs extremely hard work to test today (it needs a real device or an external service) may be set aside:
  add `path | reason` to `tools/coverage/exclusions.txt`, with what is missing. Tell the user in the pull request. Take the line
  away when the module has tests. Do not lower the 80%, and do not set a module aside only because tests are some work.
- Change code so it can be tested when that is a small, honest change (for example `Role.pick()`). Do not add code only for tests.

## Pull requests

- Before you create a pull request: the suites that your change touches pass and `gdlint` is clean. Do not run the full
  coverage unless the user told you to (see "Tests and coverage"). Do not create the pull request when a check fails.
- After you create a pull request, and also a later one, always run the `review` skill on it, and post the findings as one comment on the pull request.
  The reviewer (`code-reviewer`) posts without asking the user first. End the comment with the Claude Code footer. If there are no
  findings, post a short comment that says so, and list what you checked.
- Review cycle (decision of the owner). (1) `sw-developer` owns the pull request and acts on a review comment as soon as it is
  posted: it addresses every finding, whatever its importance, with a fix or with a justification (the finding is wrong or should not be
  fixed, with evidence). (2) When it has addressed all of them, it posts one summary comment on the pull request: for each finding the fix
  (commit) or the justification. (3) Only after that summary comment does `code-reviewer` review again: it checks each fix and decides if
  each justification holds, and posts the result. (4) When `sw-developer` and `code-reviewer` agree that every finding is resolved, the pull
  request is merged by `sw-developer` once the checks are green and the PR has no merge conflict. A pull request that adds or changes
  strings also needs `localization-reviewer` to end its PR comment with "Strings: approved" (see "Rules for this repository"). Alon decided
  that this is full automation: nobody waits for the owner except in the cases of step (5) and the cases below.
  (5) One cycle is steps 1 to 3. When the two still disagree after 2 cycles, the pull request is left for the owner: `sw-developer`
  posts a comment that states what the disagreement is (the finding, the fix or justification, the reviewer's objection) and nobody merges.
  The reviewer never fixes a finding. Tell the user what the review found.
  Automatic decisions (Alon):
  - Disagreement after 2 cycles: `software-architect` decides as a tiebreaker and posts the decision as a comment (the finding, both
    positions, the decision, why). It is final. A disagreement about what the user sees (cut or hidden information) still goes to the owner.
  - Strings that need a decision (a new text for a row already in the app, a "Strings: not approved"): `product-engineer` and
    `localization-reviewer` decide with the rules of this file (kid-friendly, short, no cut information). Each such change is listed in the
    PR description and in the open `localization` issue so the owner can revert it. A text the owner wrote is never changed this way.
  - Protocol: a change of `scripts/core/protocol.gd` is merged when `docs/PROTOCOL.md`, the `VERSION` bump (when incompatible) and the
    protocol tests match, and the old and the new version are tested together (the `change-protocol` skill).
  - Failing whole suite (when `qa` decided to run it): `qa` triages each failure. A failure that the PR caused goes back to `sw-developer`.
    A failure that also fails on `main` is filed as an issue and does not block the merge.
  - New third-party resource: `license-reviewer` checks it (see "Third-party libraries and resources"); a permissive license is merged
    when everything is aligned.
  Automatic decisions so that agents can run unattended (Alon):
  - Closing issues: an agent closes an issue when its content is applied in a merged pull request; it comments with the PR number. This
    is part of finishing the work (see "Finishing work without the owner"), not an option. When the only thing left is a `Device`
    test, the issue is not closed: it gets the label `needs-device` and one comment (the manual test and steps). The agent that records
    the passing result (`qa`, `device-test` skill) closes the issue in the same turn. A duplicate or an obsolete issue is closed at once
    with a comment that links the issue that replaces it or the rule that makes it obsolete.
    A point that only a native Hebrew reader can confirm goes in a manual test step, not in an open issue and not in a blocking state.
  - Open design rows ("Decision to confirm" in a requirements file): `product-engineer` decides them by the rules of this project and
    records the decision in the requirements file and in the PR description. Alon can revert it with a comment. A row about what the user
    sees (cut or hidden information) still goes to the owner.
  - The Summary table and the table "Tests to run, in order" of `docs/MANUAL_TESTS.md`: `sw-developer` edits the tables (not the rules) in
    the same pull request as the behavior change, as REQ-GM-62 says.
  Cases that stop an automatic merge and are left for the owner (the list is closed: nothing else stops a merge):
  - a decision that the tiebreaker may not take (see above);
  - a license that is not permissive or not clear;
  - a change of the privacy notice, a store text or a legal text, unless the PR only applies text or a decision that the owner already
    gave in an issue or PR comment (the PR links that comment and says "applies the owner's decision of <date>");
  - a change of a rule in CLAUDE.md or of an agent file or a skill file, unless the PR only applies lines that the owner approved in an
    issue or PR comment (same link rule);
  - a PR that changes the status of a requirement to done or verified while its test is not Pass. A requirement that stays `Device` does
    not stop a merge.
  The agent states the case in one PR comment that says what the owner has to do (one sentence), adds the label `needs-owner` to the PR,
  and tells the user. It does not wait: it goes on with the other work (see "Finishing work without the owner").

## Finishing work without the owner

The owner wants the agents to carry every task to its end: code, tests, review, merge, issues. The task is finished only when the list
below is true. A turn must not end with "waiting" or "ready for review" unless the open item is an owner case (above), a `Device` test or a
question that only the owner can answer.

1. **GitHub access.** In a cloud session `gh` is usually not logged in; use the GitHub tools (`mcp__github__*`: create/merge/update pull
   request, `pull_request_read`, `add_issue_comment`, `issue_read`, `issue_write`, `list_issues`, `pull_request_review_write`, and
   `mcp__claude-code-remote__subscribe_pr_activity`). If they are deferred, load them with `ToolSearch` (`select:<names>`). On the
   owner's Mac `gh` is allowed. Use whichever works, do not stop because one is missing, and never use another account. A subagent has
   these tools only when its agent file lists them in `tools:` (see `docs/AGENTS.md`, "Tools the agents need"); when it has not, it
   names the next step in its result and the main session does that step at once, without asking the user.
2. **The PR owner runs the loop to the end, in the same turn.** After the checks pass: create the PR (no confirmation; `pr-submit`),
   subscribe to its activity, run the review (`code-reviewer` as a separate agent, not by the author), answer every finding, post the
   summary comment, run the re-review, get "Strings: approved" and "License: approved" when they apply, and merge when it is allowed.
   When a step needs another agent, call that agent and wait for its result; do not stop and report the next step to the user.
3. **Events wake the owner.** A subscribed PR delivers comments, reviews and CI to the session. Act on each at once. The checks the agents
   run themselves and the state of the Actions run are the gate (see "Rules for this repository", Continuous integration).
4. **Close the issues.** After the merge: every issue the PR resolves is closed with a comment (PR number, what changed, tests run).
   An issue that waits for a device gets `needs-device`; a PR or issue that waits for the owner gets `needs-owner`. Open follow-ups are
   filed as issues, never left as text in a PR.
5. **Do not leave a state that only the owner can read.** Every blocked item has a label (`needs-owner`, `needs-device`, `blocked`
   with the reason in a comment). `project-manager` keeps these labels true and gives the owner one list: `needs-owner` first, then
   `needs-device` in the order of "Tests to run, in order".
6. **Split work so that the owner's part is small.** When one part of a task needs the owner (a legal text, a device test, a rule of
   this file), do the rest and merge it; ask the owner about that part only, in its own PR or comment. A stack of PRs is merged leaf
   first into its parent branch; only the root waits.
7. **Report at the end.** The last message to the user says what is merged, which issues are closed, and the short list of what is left
   for the owner with the exact action (merge this PR, run test N, answer this question).

## Agents and workflows

The agents are in `.claude/agents/`. Use them for the steps below when the task is large enough to need a role. A small, clear change may be done by one agent (`sw-developer`) or by the main session. Every agent follows the rules of this file. Only `sw-developer` merges a pull request, and only under the rules of "Pull requests". Agents finish their work as "Finishing work without the owner" says. The same flows as diagrams are in `docs/AGENTS.md`.

| Flow | Order of the agents |
|------|---------------------|
| New feature or game | `product-engineer` (requirements, `docs/games/<id>.md`) -> `ui-ux-designer` (mock, tile, Figma; the user approves the look) -> `software-architect` (only for a change across modules, the protocol or the network) -> `sw-developer` (code) -> `automation-developer` (missing and changed tests, test list in the PR) -> `qa` (test check against the requirement IDs, manual steps, open tests) -> `localization-reviewer` (strings list) -> `code-reviewer` |
| Bug fix | `qa` (reproduce, steps, issue) -> `sw-developer` (fix with the requirement and a test that fails before the fix) -> `automation-developer` (missing and changed tests, always) -> `qa` (test check, test list in the PR) -> `code-reviewer` |
| Planning | `product-engineer` (what and why) and `software-architect` (how, phases, risks) -> a plan in `docs/*_PLAN.md` or an issue; the user decides |
| Testing | `automation-developer` (headless tests, `docs/AUTOMATED_TESTS.md`) and `qa` (manual tests, results the user reports, issues from test notes) |
| Documentation | the agent that owns the area writes it: `product-engineer` (requirements), `software-architect` (plans, `docs/PROTOCOL.md`), `ui-ux-designer` (design system), `release-engineer` (export, `docs/THIRD_PARTY.md`), `qa` (manual tests). The `code-reviewer` checks that docs match the code |
| Pull request | `sw-developer` owns it until it is merged and its issues are closed. After it is created, the `code-reviewer` (a separate agent, never the author) runs the `review` skill and posts the comment. A finding is fixed, or moved to a follow-up issue, or answered in a PR comment with the reason (false positive or not worth a fix). After each fix the owner comments what was resolved. The review cycle and the merge rules are in "Pull requests" |
| Finish and sweep | `project-manager`: after a merge or on request, closes resolved, duplicate and obsolete issues, keeps `needs-owner` / `needs-device` / `blocked` labels true, splits issues so the owner's part is small, and posts the owner list |
| Security-relevant change (network input, saved files, permissions, privacy) | `security-reviewer` runs next to `code-reviewer` and ends its comment with "Security: approved" or findings |
| Build, export, CI | `release-engineer` |
| A new third-party resource | `license-reviewer` (with `release-engineer` for the export presets) |

## Manual tests (for the user)

- Every note in a test result that describes a problem or a change request (also on a step that passes) triggers, in the same turn: a change of the requirements (marked "Planned (issue #N)" until the code is built) and a GitHub issue, unless an issue for it exists. Look in the open issues first. Do not fix the issue unless the user asks. When a note is unclear or conflicts with a requirement or another test, ask the user and put the question in the issue.

- Every manual step has a clear pass or fail criterion (a number with a limit, an exact text, an object that is visible or not). Write no step that asks for a feeling ("too slow", "easy to read"). A step checks one thing (at most two linked things): split it with letters (3a, 3b) when it checks more. When you revise a step that has a recorded result, copy the result to the new steps unless what is checked changed.

- A manual step never needs more than 2 phones (owner decision, 2026-11-17, issue #457: "Add a rule to not write tests that require more then 2 phones").

- What a machine can check is in `docs/AUTOMATED_TESTS.md` (how to run it on the Mac, and which manual steps it replaced). When a manual step can be
  done by a headless test, write the test, add it to `tests/suites.txt`, and move the step: remove it from `docs/MANUAL_TESTS.md`, keep the numbers of the other steps, and add an `A-<test>-<item>` row there.

- The tests that need real devices (phones, a TV or a TV box, a remote, a camera) are in `docs/MANUAL_TESTS.md`: the steps, a result for
  every step, the run log, and the evidence (photos, videos, logs in `docs/evidence/`). Claude cannot run them. Which tests are open, in which order to run them, and what each one asks of the user are in the Summary table and the table "Tests to run, in order" of that file and in the Sababi Test Tracker.
- Claude never marks a manual test as passed. When the user reports a result, Claude writes it in `docs/MANUAL_TESTS.md` (the result of the
  step, the run ID, the evidence path, the measured values), then updates the Summary table there and the table "Tests to run, in order". Use the `device-test` skill.
- A requirement with the status `Device` is not done until its test is Pass. Do not say that a feature is verified on a device before that.
- A change that needs a device check adds or changes its test in the same commit (REQ-GM-62) and adds it to the Summary table.
  Every pull request lists the manual tests that are still open for its change (taken from the Summary table of `docs/MANUAL_TESTS.md`).
