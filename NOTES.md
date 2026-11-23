# Work log

Dated log: what was done, why, result, open questions. Newest first.
Brief: "Tunic Fork: Coding Agent Handoff" (Claude Docs).

## 2026-11-23 — Dead code removed, BitLocker refusal

**Decisions (Emma):** delete dead code; refuse when C: is encrypted.

**Done**
- ADR 0003: deleted Go/Python stubs, Makefile, broken CI, old VirtualBox lab. Kept upstream `doc/`.
- ADR 0004: `tunic.ps1` refuses unless C: is fully decrypted. Checked in `checks` (GUI) and before `install-grub` / `full-disk` verbs. Fails safe if the state can't be read.
- Why "fully decrypted", not "protection off": suspended BitLocker still leaves data encrypted, so GRUB still can't read the ISO.
- `tunic.ps1` can be dot-sourced without running (for Pester).
- `test/unit/encryption.Tests.ps1` + new CI (`ci.yml`, windows-latest, Windows PowerShell 5.1): parse check + Pester.
- ADR numbers 0001/0002 left for the installer and scope ADRs named in the brief.

**Not verified yet**
- No PowerShell in this container (downloading it was blocked). CI run 1 (commit 2df7a09): parse check OK, Pester 13/13 passed on Windows PowerShell 5.1. Bumped checkout to v5 (Node 20 deprecation warning).
- CIM call and "InvalidNamespace" handling need a real run: lab VM with BitLocker on, then off.

## 2026-11-23 — Phase 2 prep (lab not yet built)

**Decision:** Hyper-V Gen 2 for the lab (Emma). Why: real Microsoft UEFI CA Secure Boot, so shim results match real PCs; PowerShell scripting. Recorded in TESTING.md.

**Done**
- `test/lab/new-lab-vm.ps1`: creates the VM (Gen 2, Secure Boot with third-party CA template, vTPM, 12 GB static RAM, 128 GB disk). Not executed; no PowerShell in this container, so not even syntax-checked.
- TESTING.md: host setup, VM build, clean checkpoint, exact Phase 2 baseline procedure, run-log template.

**Why these choices**
- Secure Boot template "Microsoft UEFI Certificate Authority": the default template trusts only Windows and would fail every Linux boot, a false result.
- 12 GB RAM, static: GRUB boots casper with `toram`, which copies the ISO into RAM. 24.04 desktop ISO is ~6 GB, so upstream's "4 GB RAM" claim likely fails. Static so Tunic's RAM check sees the real figure. To verify in the baseline.
- Baseline pre-shrinks C: by 40 GB by hand, because upstream's shrink never runs (architecture.md #1). Otherwise every run fails for a known reason and hides the 24.04 behaviour.
- Baseline uses upstream source at `2e6b687` via `git archive`, not the 0.2.4 release exe, because the fork builds on the source.

**Coverage gaps (lab can't test)**
- NVMe disk naming bug: Hyper-V disks are SCSI. Needs real hardware or QEMU with NVMe.
- Legacy BIOS: Gen 1 VMs can't run Windows 11.

**Next (Emma, on a Windows host)**: build the lab, run both baselines, fill TESTING.md run log. Then Phase 2 checkpoint review.

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
- ~~Hypervisor for lab~~ → Hyper-V (answered 2026-11-23).
- ~~Delete dead code?~~ → yes (ADR 0003).
- ~~BitLocker?~~ → refuse (ADR 0004).
