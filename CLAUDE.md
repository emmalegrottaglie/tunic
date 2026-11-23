# Working rules for Claude on this repo

Tunic fork: installs Ubuntu alongside Windows 11 from inside Windows. It repartitions disks and rewrites boot config, so mistakes can destroy data.

## Triple-check every coding claim and change (Emma, 2026-11-23)

Before stating a fact about code, recommending an approach, or calling work done, check it three ways:

1. **Correct**: verified against the actual code, official docs, or a test run, never from memory alone. If it can't be verified, say "unverified" and how to verify it.
2. **Good practice**: matches current best practice for the language/tool (PowerShell, GRUB, Ubuntu autoinstall, GitHub Actions). Flag shortcuts as shortcuts.
3. **Secure**: no new security flaws. Check at least:
   - secrets/passwords never in plaintext files, logs, commits or CI output
   - downloads verified (HTTPS + checksum/signature)
   - no injection: user input never evaluated as code (`Invoke-Expression`, `ExpandString`, shell strings)
   - fail safe: unknown state → stop before touching disk or boot config
   - least privilege, pinned versions for actions and dependencies

For non-trivial changes, also get an independent review (fresh subagent or `/code-review`) given the code, not my conclusions.

## Hard safety rules (from the handoff brief)

- Never run Tunic or anything touching disks, partitions, BCD, UEFI or GRUB on a host. VM only, checkpoint first.
- Never commit ISOs, VM images, credentials or personal data.
- No pushes or PRs to upstream (`mikeslattery/tunic`) without Emma's approval. Work in the fork.
- Ambiguous or risky step → stop and ask; log the question in `NOTES.md`.

## Documentation

Record what was done and why: `NOTES.md` (dated log), `docs/adr/` (decisions), `docs/architecture.md`, `TESTING.md`. Commit messages say why.
