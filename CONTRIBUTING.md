# Contributing to Sababi

Sababi is a game for the TV (Godot 4.7, GDScript) with a phone as the controller. The repository is public so that people can read it and help. **The owner, Alon Yampolski, keeps all the rights** (see `LICENSE`): the code is not open source, and you may not copy, fork for your own product, or distribute it. You may fork it on GitHub to prepare a contribution.

## Before your first pull request

1. Read `LICENSE` and `CLA.md`.
2. Write this sentence in your first pull request, with your full name: **"I, <your full name>, have read the Sababi Contributor License Agreement (CLA.md) and I agree to it."** The owner does not merge a pull request from someone who did not.
3. Do not add code, art, sound, fonts or text of another maker unless its license allows a free app that is shipped in a store. If you add one, name its source and license in the pull request and add a row to `docs/THIRD_PARTY.md`. Say in the pull request when an AI tool made a part of your work.

## How to work

- Read `README.md` first, then the requirements of the area you change (`docs/`, and `docs/games/<id>.md` for a game).
- Change the documents and the tests in the same pull request as the code (`CLAUDE.md`, "Docs and tests stay aligned").
- Every text that a player sees is a row of `assets/lang/strings.csv`, in English and Hebrew, never a text in the code.
- Run the tests that your change touches and `gdlint scripts tests tools` before you send the pull request (`tests/run_one.sh tests/<name>.gd`). You do not need to run the whole suite.
- A privacy or legal text, a store text and `LICENSE`, `CLA.md`, `CONTRIBUTING.md` and `CONTRIBUTORS.md` are changed by the owner only.
- Keep a pull request small and about one thing, and say what you tested.

The owner keeps the copyright of the whole project, including your accepted contributions (CLA.md). You are named in `CONTRIBUTORS.md` for each accepted contribution, unless you ask not to be. The owner decides what is merged and may decline a pull request without a reason.
