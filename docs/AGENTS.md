# Agents and workflows

The agents are defined in `.claude/agents/` (one file each). The rules for using them are in `CLAUDE.md`, section "Agents and workflows". This page shows the same flows as diagrams. A small, clear change may skip steps: one agent (`sw-developer`) or the main session can do it.

Only `sw-developer` merges a pull request, and only under the rules of "Pull requests" in `CLAUDE.md`. No agent marks a manual test as passed. The owner decides at every "Owner" box; the cases that stop an automatic merge are listed under "Pull request and review".

## Roles

| Agent | Role | Writes |
|-------|------|--------|
| `product-engineer` | requirements, game specs, issues | documents, issues |
| `software-architect` | design, protocol, plans | plan and decision documents |
| `ui-ux-designer` | look, mocks, tiles, Figma | mocks, design documents, Figma |
| `sw-developer` | code, owns the pull request and merges it when the review agrees | code, tests, documents |
| `automation-developer` | headless tests, suites | `tests/`, `tools/`, automated-test documents |
| `qa` | test plans, manual tests, issues from test notes | manual-test documents, issues |
| `localization-reviewer` | English and Hebrew rows, string list | approved string rows |
| `release-engineer` | build, export, CI | `tools/`, export, CI documents |
| `license-reviewer` | license of every third-party resource, documents and About pages agree | license documents, About rows |
| `code-reviewer` | review with the `review` skill, checks the answers | comments only, never merges |
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
    DEV --> LIC{New third-party<br/>resource?}
    LIC -- yes --> LR[license-reviewer]
    LIC -- no --> PR
    LR --> PR
    LOC --> PR
    PR --> REV[code-reviewer<br/>review skill, one comment]
    REV --> FIX[sw-developer<br/>resolve every finding<br/>see Pull request and review]
    FIX --> REV
    REV --> MRG[sw-developer merges<br/>checks green, no conflict]
    MRG --> U2{{Owner runs device tests<br/>and reports results}}
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
    REV --> MRG[sw-developer merges<br/>checks green, no conflict]
    MRG --> U1{{Owner retests on a device<br/>if the requirement is Device}}
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
    OWN -- export, CI --> RE[release-engineer]
    OWN -- licenses --> LR[license-reviewer]
    OWN -- strings --> LOC[localization-reviewer]
    PE --> CR[code-reviewer<br/>checks docs match the code]
    SA --> CR
    UX --> CR
    QA --> CR
    RE --> CR
    LR --> CR
    LOC --> CR
```

## Pull request and review

Rules from "Pull requests" in `CLAUDE.md` (decision of the owner, 2026-10-29).

```mermaid
sequenceDiagram
    participant D as sw-developer (owner of the PR)
    participant R as code-reviewer
    participant L as localization-reviewer
    participant A as software-architect
    participant O as Owner
    D->>D: touched suites + gdlint pass
    D->>R: PR is created, run the review skill
    R->>D: one review comment (posted without asking)
    opt strings changed
        L->>D: PR comment ending "Strings: approved"
    end
    loop at most 2 cycles
        D->>D: address every finding: fix, follow-up issue, or justification
        D->>R: one summary comment (fix or justification per finding)
        R->>D: checks each fix, decides if each justification holds
    end
    alt all findings resolved, checks green, no conflict
        D->>D: merge
    else still disagree after 2 cycles
        D->>A: comment: the finding, both positions
        A->>D: tiebreaker decision with reasons (final)
        D->>D: merge
    else disagreement about what the user sees
        D->>O: left for the owner
    end
```

Cases that stop an automatic merge and are left for the owner:

```mermaid
flowchart LR
    S{Case} --> A1[A decision the tiebreaker may not take]
    S --> A2[A license that is not permissive or not clear]
    S --> A3[A change of the privacy notice, a store text or a legal text]
    S --> A4[A change of a rule in CLAUDE.md or of an agent or skill file]
    S --> A5[A requirement with status Device marked done by the PR]
    A1 --> O{{Claude states the case in a PR comment<br/>and tells the owner}}
    A2 --> O
    A3 --> O
    A4 --> O
    A5 --> O
```

## Build, export, CI, third-party resources

```mermaid
flowchart TD
    N([Need]) --> T{Type}
    T -- build or export --> RE[release-engineer<br/>build-deploy skill, patch manifest, export]
    T -- CI --> C[release-engineer<br/>unit suites + pixels only,<br/>no costly jobs without asking]
    T -- new library, font, sound, image --> LR[license-reviewer<br/>license name and version]
    LR --> P{Permissive license?}
    P -- yes --> AL[Align THIRD_PARTY.md, license file,<br/>export presets, About page, REQ-P6,<br/>privacy notice]
    AL --> RE2[release-engineer<br/>export presets if needed]
    P -- missing, unclear, copyleft,<br/>non-commercial --> O{{Owner decides}}
    RE --> O2{{Owner deploys to devices}}
```
