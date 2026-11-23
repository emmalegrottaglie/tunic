# Work log

Dated log: what was done, why, result, open questions. Newest first.
Brief: "Tunic Fork: Coding Agent Handoff" (Claude Docs).

## 2026-11-23 — Phase 0 + Phase 1

**Done**
- Phase 0: fork already exists (`emmalegrottaglie/tunic`, identical to upstream `2e6b687`). Added `NOTES.md`, `TESTING.md`, `docs/adr/`, `docs/architecture.md`.
- Phase 1: read every file; mapped flow, build and defects → `docs/architecture.md`. Checked upstream issues/PRs.

**Deviations from brief (and why)**
- Branch is `claude/artifact-session-kty600`, not `dev`: the cloud session may only push to its assigned branch. Can merge into `dev` later.
- New docs go in `docs/` (per brief). Upstream's `doc/` left untouched to keep the diff against upstream small.

**Key findings**
- Product = `tunic.ps1` + `files/`, wrapped by NSIS (`build.ps1`, `tunic.nsi`). Go/Python/Makefile/CI are dead rewrite stubs.
- 24.04 blocker confirmed by code: GRUB boots with `automatic-ubiquity` + d-i preseed; 24.04 needs autoinstall YAML.
- Dual-boot shrink never runs (typo bug, see architecture.md #1). Upstream dual boot only worked with pre-existing free space.
- NVMe disk naming, Secure Boot shim, and BitLocker/Device Encryption are each likely to break Win11 installs independently of the installer swap.
- Upstream dormant: last code change 2020-08, issue #20 "Abandoned?" unanswered.

**Facts table updates (for the brief)**
- Activity → dormant (above).
- Build process → NSIS self-extractor; see architecture.md.
- Ubuntu 24.04+ → confirmed incompatible at the GRUB/preseed layer; casper loopback still to verify.
- Requirements → code checks RAM ≥3.5 GB, Windows major ≥10 (Win11 passes), GPT/UEFI only.

**Blocked**
- Phase 2 needs a Windows 11 VM with UEFI/Secure Boot/TPM. Not possible in this cloud container (no hypervisor, no Windows). Must run on Emma's machine or a nested-virt host.

**Open questions for Emma**
- Hypervisor for lab (Hyper-V vs VirtualBox)? Determines TESTING.md steps.
- OK to delete dead Go/Python stubs and broken CI in Phase 4 (separate commit + ADR)?
- BitLocker/Device Encryption: refuse, or guide user to suspend/decrypt? (affects test matrix row 3)
