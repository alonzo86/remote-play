# Remote Play: notes for Claude

Godot 4.7 project (GDScript): a TV app and a phone controller app. Read `README.md` first.

## Rules for this repository

- Each game has a requirements file `docs/games/<id>.md`. All games also follow `docs/GAME_REQUIREMENTS.md`.
  Change the requirements file in the same commit as the behavior (REQ-GM-5). Use the `add-minigame` skill for new games.
- Run the `run-tests` skill before a commit. Do not report a pass for a check that did not run.
- Work on the branch the session gives you. Create a pull request only when the user asks for one.

## Tests and coverage

- Every module (each script file in `scripts/`) needs at least 80% line coverage. Check it with `GODOT=<path> tools/coverage.sh`
  before you create a pull request. The script fails when a module is below 80%. CI runs the same check (job `coverage`).
  New or changed code comes with its tests in the same change. Say the total and the lowest modules in the pull request.
- Write tests that matter. A test checks a behavior: an input and the result, an error case, a state change, a rule from a
  requirements file. It must fail when that behavior breaks. Do not write a test only to run lines or to raise the number
  (a call without an assertion, a copy of the code in the test). If code has no behavior worth a test, say so and do not test it.
- A module that needs extremely hard work to test today (it needs a real device or an external service) may be set aside:
  add `path | reason` to `tools/coverage/exclusions.txt`, with what is missing. Tell the user in the pull request. Take the line
  away when the module has tests. Do not lower the 80%, and do not set a module aside only because tests are some work.
- Change code so it can be tested when that is a small, honest change (for example `Role.pick()`). Do not add code only for tests.

## Pull requests

- Before you create a pull request: the tests pass, `gdlint` is clean, and `tools/coverage.sh` reports every module at 80% or more
  (see "Tests and coverage"). Do not create the pull request when it does not.
- After you create a pull request, always run the `review` skill on it, and post the findings as one comment on the pull request.
  End the comment with the Claude Code footer. If there are no findings, post a short comment that says so, and list what you checked.
- Do not fix the findings of that review unless the user asks. Tell the user what you found.
- The review comment is also required for later pull requests, not only for the first one.
