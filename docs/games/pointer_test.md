# Pointer Test (`pointer_test`)

Type: 2D. Players: 1 to 4. Input: pointer (yaw and pitch), button A, button B. Code: `scripts/game/pointer_test/`.
General requirements: `docs/GAME_REQUIREMENTS.md`. System requirement: REQ-T2.

## Goal

Not a game. It is a tool. Each player aims a cursor at a ring on the TV and presses A. The error in pixels shows
the drift, the range and the delay of gyro pointing.

## Gaps and exceptions

| General ID | Kind | Note |
|------------|------|------|
| REQ-GM-34 | Exception | There is no winner and no end. The test runs until the player leaves. |
| REQ-GM-35 | Exception | There is no countdown. There is no race. |
| REQ-GM-62 | Gap | Test 5 in `docs/DEVICE_TEST.md` covers it. |
| REQ-GM-47a, 47b, 47d, 47e, 47f, REQ-GM-49 | Gap | The cursors and rings are not restyled yet: no dark outline, thin lines. The HUD and the menus use the shell (REQ-GM-45). The restyle is planned for a later pull request (REQ-FL-49). The tile shows the old look. |

## Requirements

| ID | Requirement | Status | Check |
|----|-------------|--------|-------|
| REQ-PT-1 | The cursor of each player follows the yaw and pitch of the phone, in the color of the player. | Done | smoke_tv |
| REQ-PT-2 | A turns the phone to the left: the cursor goes left. | Done | smoke_tv |
| REQ-PT-3 | A press of A records the distance from the ring. A hit is 90 px or closer. A hit moves the ring to the next place. | Done | Device |
| REQ-PT-4 | B recenters the pointer of that player. | Done | Device |
