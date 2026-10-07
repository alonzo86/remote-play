# Remote Play: notes for Claude

Godot 4.7 project (GDScript): a TV app and a phone controller app. Read `README.md` first.

## Rules for this repository

- Each game has a requirements file `docs/games/<id>.md`. All games also follow `docs/GAME_REQUIREMENTS.md`.
  Change the requirements file in the same commit as the behavior (REQ-GM-5). Use the `add-minigame` skill for new games.
- Run the `run-tests` skill before a commit. Do not report a pass for a check that did not run.
- Work on the branch the session gives you. Create a pull request only when the user asks for one.

## Pull requests

- After you create a pull request, always run the `review` skill on it, and post the findings as one comment on the pull request.
  End the comment with the Claude Code footer. If there are no findings, post a short comment that says so, and list what you checked.
- Do not fix the findings of that review unless the user asks. Tell the user what you found.
- The review comment is also required for later pull requests, not only for the first one.
