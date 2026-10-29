# Agents and workflows

The agents are defined in `.claude/agents/` (one file each). The rules for using them are in `CLAUDE.md`, section "Agents and workflows". This page shows the same flows as diagrams. A small, clear change may skip steps: one agent (`sw-developer`) or the main session can do it.

No agent merges a pull request. No agent marks a manual test as passed. The user decides at every "User" box.

## Roles

| Agent | Role | Writes |
|-------|------|--------|
| `product-engineer` | requirements, game specs, issues | documents, issues |
| `software-architect` | design, protocol, plans | plan and decision documents |
| `ui-ux-designer` | look, mocks, tiles, Figma | mocks, design documents, Figma |
| `sw-developer` | code, owns the pull request | code, tests, documents |
| `automation-developer` | headless tests, suites | `tests/`, `tools/`, automated-test documents |
| `qa` | test plans, manual tests, issues from test notes | manual-test documents, issues |
| `localization-reviewer` | English and Hebrew rows, string list | approved string rows |
| `release-engineer` | build, export, CI, licenses | `tools/`, export, CI, license documents |
| `code-reviewer` | review with the `review` skill | comments only |
| `design-reviewer` | independent critique of screens | nothing |

## New feature or game

```mermaid
flowchart TD
    U0([User asks]) --> PE[product-engineer<br/>requirements, docs/games/id.md]
    PE --> UX[ui-ux-designer<br/>mock, tile, Figma]
    UX --> U1{User approves<br/>the look?}
    U1 -- no --> UX
    U1 -- yes --> X{Change across modules,<br/>protocol or network?}
    X -- yes --> SA[software-architect<br/>plan, PROTOCOL.md]
    X -- no --> DEV
    SA --> DEV[sw-developer<br/>code + docs]
    DEV --> AUTO[automation-developer<br/>headless tests]
    AUTO --> QA[qa<br/>manual steps, open tests list]
    DEV --> LOC[localization-reviewer<br/>string list for the PR]
    QA --> PR[sw-developer<br/>opens the PR]
    LOC --> PR
    PR --> REV[code-reviewer<br/>review skill, one comment]
    REV --> FIX[sw-developer<br/>fix, follow-up issue,<br/>or documented reason]
    FIX --> REV
    REV --> U2{{User reviews strings,<br/>runs device tests, merges}}
```

## Bug fix

```mermaid
flowchart TD
    U0([Bug report or test note]) --> QA[qa<br/>reproduce, steps, issue]
    QA --> PE[product-engineer<br/>requirement change<br/>Planned issue N]
    PE --> DEV[sw-developer<br/>fix + test that fails before the fix]
    DEV --> GAP{Test gap<br/>is large?}
    GAP -- yes --> AUTO[automation-developer<br/>more tests]
    GAP -- no --> PR
    AUTO --> PR[sw-developer<br/>opens the PR]
    PR --> REV[code-reviewer]
    REV --> FIX[sw-developer<br/>resolve each finding<br/>and comment what was resolved]
    FIX --> REV
    REV --> U1{{User merges}}
```

## Planning

```mermaid
flowchart LR
    U0([User idea]) --> PE[product-engineer<br/>what and why]
    U0 --> SA[software-architect<br/>how, phases, risks]
    PE --> PLAN[Plan in docs/*_PLAN.md<br/>or an issue]
    SA --> PLAN
    PLAN --> U1{{User decides}}
    U1 -- approved --> FEAT[New feature flow<br/>one PR per phase]
```

## Testing

```mermaid
flowchart TD
    REQ[Requirement or code change] --> Q{What checks it?}
    Q -- a machine --> AUTO[automation-developer<br/>suite in tests/suites.txt<br/>A-test-item row]
    Q -- a device or a person --> QA[qa<br/>manual steps with pass/fail criteria]
    AUTO --> RUN[Run the touched suites + gdlint<br/>no full coverage unless the user asks]
    QA --> U1{{User runs the device test<br/>and reports the result}}
    U1 --> QA2[qa<br/>writes result, evidence, run log]
    QA2 --> NOTE{Note on a step?}
    NOTE -- yes --> PE[product-engineer + qa<br/>requirement change + issue]
    NOTE -- step can be automated --> AUTO
```

## Documentation

```mermaid
flowchart LR
    CH[Change] --> OWN{Area}
    OWN -- requirements, games --> PE[product-engineer]
    OWN -- plans, protocol --> SA[software-architect]
    OWN -- design system, tiles --> UX[ui-ux-designer]
    OWN -- manual tests --> QA[qa]
    OWN -- export, licenses --> RE[release-engineer]
    OWN -- strings --> LOC[localization-reviewer]
    PE --> CR[code-reviewer<br/>checks docs match the code]
    SA --> CR
    UX --> CR
    QA --> CR
    RE --> CR
    LOC --> CR
```

## Pull request and review

```mermaid
sequenceDiagram
    participant D as sw-developer (owner)
    participant R as code-reviewer
    participant U as User
    D->>D: touched suites + gdlint pass
    D->>U: PR (strings listed, open manual tests, coverage not run)
    D->>R: run the review skill
    R->>U: one comment with the findings
    loop every finding
        alt real problem
            D->>D: fix it
        else out of scope
            D->>D: open a follow-up issue
        else false positive or not worth it
            D->>R: written reason in a PR comment
        end
        D->>U: PR comment: what was resolved
        R->>R: check the resolution
    end
    U->>U: review strings, device tests, merge
```

## Build, export, CI, third-party resources

```mermaid
flowchart TD
    N([Need]) --> RE[release-engineer]
    RE --> T{Type}
    T -- build or export --> B[build-deploy skill<br/>patch manifest, export]
    T -- CI --> C[unit suites + pixels only<br/>do not add costly jobs]
    T -- new library, font, sound, image --> L[check the license<br/>THIRD_PARTY.md, license file,<br/>About page, REQ-P6, privacy notice]
    L --> U1{{User confirms when unsure}}
    B --> U2{{User deploys to devices}}
```
