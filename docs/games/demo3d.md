# 3D Demo (`demo3d`)

Type: 3D. Players: 1 to 4. Input: tilt. Code: `scripts/game/demo3d/`.
General requirements: `docs/GAME_REQUIREMENTS.md`.

## Goal

A template for new 3D games. Each phone tilts a sphere on a square floor. There is no goal.
Copy the folder, and the requirements file, to start a new 3D game.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-21, REQ-GM-22 | Gap | The code does not remove the sphere of a player who leaves. |
| REQ-GM-34, REQ-GM-35 | Exception | No winner, no countdown. |
| REQ-GM-43 | Exception | No haptic feedback. |
| REQ-GM-62 | Exception | A template. No device test. |
| REQ-GM-47a, 47c, 47d, 47e, 47g, 47h, REQ-GM-49 | Gap | The spheres have no outline mesh (`add_outlined_mesh`) and the floor color is not checked against REQ-GM-47e. The HUD and the menus use the shell (REQ-GM-45). The restyle is planned for a later pull request (REQ-FL-49). The marble race is the example for a new game. |

## Requirements

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-D3-1 | One sphere for each player, in the slot color, on a floor with a clear edge. | Done | smoke_tv |
| REQ-D3-2 | Tilt right moves the sphere to the right on the screen. | Done | smoke_tv |
| REQ-D3-3 | The sphere cannot leave the floor. | Done | Open (no test) |
