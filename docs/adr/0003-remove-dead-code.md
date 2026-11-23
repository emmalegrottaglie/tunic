# 0003: Remove dead rewrite stubs, broken CI and the old VirtualBox lab

- Status: accepted
- Date: 2026-11-23
- Decided by: Emma

(0001 and 0002 are reserved for the installer and scope decisions named in the brief.)

## Context

Phase 1 recon (`docs/architecture.md`) found that only `tunic.ps1` + `files/` ship, wrapped by NSIS. Everything else that looks like code is unused:

- `main.go`, `Makefile`, `test.mk`: Go rewrite stub. It downloads upstream's 0.2.4 exe and has an inverted error check (runs it only if the download fails).
- `run.py`, `setup.py`: Python/GTK rewrite stub. `setup.py` was copied from another project ("halo") and fails with a NameError (`DEBUG` undefined) when run.
- `.github/workflows/CI.yml`: runs `go test` (no tests exist) on the retired `windows-2019` image.
- `test/test-loop.sh`, `test/test-setup.ps1`, `test/test-setup.bat`: VirtualBox lab built on Microsoft's "MSEdge Win10" image, whose download URL is dead. Replaced by the Hyper-V lab (`test/lab/`, TESTING.md).

## Options considered

1. Keep them: no work, but they mislead readers about the stack and the build, and CI shows a false status.
2. Move them to an `attic/` folder: keeps them visible, same confusion.
3. Delete them: git history keeps them (`git show 2e6b687:<path>`).

## Decision

Option 3. Delete. Also drop `tunic` (Go binary) and `*.ova` from `.gitignore`.

Kept: `tunic.ps1`, `files/`, `tunic.nsi`, `build.ps1`, `test/tunic.bat`, `test/allow.ps1`, and upstream's `doc/` (author's notes, including `doc/junk/`).

## Consequences

- No CI until Phase 4 adds Pester tests on a Windows runner.
- Diff against upstream grows; anyone wanting the Go/Python experiments finds them in upstream or history.
