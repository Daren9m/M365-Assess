# M365 Assess — Project Conventions

> Shared environment, PowerShell rules, and coding standards are inherited from the parent `../CLAUDE.md`.
> This file contains project-specific conventions only.

- **Testing**: Pester 5.x with CI integration

## Project Structure

Standalone scripts organized by domain. Each script is self-contained — no module import needed.
Common/ helpers can be called directly (`.\Common\Connect-Service.ps1 -Service Graph`) or dot-sourced.

## Development Pipeline

### For new scripts or major changes — follow all phases:

**Phase 1 — Research, Design & Development (PARALLEL)**

These activities are independent and MUST be run in parallel using the Agent tool whenever possible:

- **Research** — Use `subagent_type=Explore` agents to investigate codebase patterns, existing scripts, helper functions, and API surfaces. Launch multiple explore agents simultaneously for different aspects (e.g., one for related scripts, one for Common/ helpers, one for similar patterns).
- **Architect** (`/design`) — Design doc with params, output type, services needed. Can run alongside research agents.
- **Developer** — Implement per approved design. Run syntax parse check after writing.

> **Parallelism rules:**
> - Research agents run in the background (`run_in_background: true`) when the main thread has other work to do

**Phase 2 — Quality Gates (SEQUENTIAL, after Phase 1 is complete)**

These run as final checks after all development work is done:

1. **QA** (`/review`) — Lint changed files with PSScriptAnalyzer. Smoke test: `Get-Command`, `Get-Help`.
2. **Gatekeeper** (`/validate`) — Verify cmdlet names and API calls against Microsoft docs.

> QA and Gatekeeper may run in parallel with **each other** since both are read-only, but both must wait until all code changes are finalized.

### For small fixes and tweaks — just make the change and lint:
- Skip the pipeline for single-line fixes, renames, CSS tweaks, etc.
- Run PSScriptAnalyzer on the changed file if it's a `.ps1`

## Testing Policy

- **Unit tests (Pester):** Run after writing or modifying collectors. Each security collector should have a corresponding `.Tests.ps1` file under `tests/`. CI runs all Pester tests automatically on push.
- **Smoke tests:** Parse validation and `Get-Help` checks run via `tests/Smoke/Script-Validation.Tests.ps1` for all scripts.
- **Live tenant testing:** Primary integration validation method. Unit tests catch regressions; live tests validate real API behavior.

## Coding Standards

Detailed rules are in `.claude/rules/powershell.md` and `.claude/rules/pester.md`.
