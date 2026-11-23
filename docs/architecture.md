# Tunic architecture (as inherited from upstream)

Phase 1 recon of `mikeslattery/tunic` @ `2e6b687` (2023-08-28). Read-only; nothing here was run.
Corrected 2026-11-23 after an independent review (see NOTES.md). Function names are used instead of line numbers, which drift.

## What actually ships

`tunic.exe` = an NSIS self-extractor around `tunic.ps1` + `files/`. Nothing else in the repo is part of the product.

| Path | Role | Status |
| --- | --- | --- |
| `tunic.ps1` (1249 lines) | Entire product: checks, WinForms GUI, shrink C:, download ISO, install GRUB, write preseed, reboot | Live |
| `files/grub.cfg` | GRUB menu: loopback-boots the ISO's `casper/vmlinuz` with `automatic-ubiquity` + preseed | Live |
| `files/preseed.cfg` | Ubiquity/d-i preseed **template**; PowerShell `$( )` expressions expanded at runtime | Live |
| `files/distros.ps1` | Hardcoded ISO list (Mint 19.3, Ubuntu + flavors 18.04/19.10) | Live, all EOL |
| `files/tunic-logo.ico` | Icon | Live |
| `tunic.nsi` | NSIS script: extracts to `%TEMP%\Tunic`, runs `tunic.ps1` hidden via 64-bit PowerShell | Build |
| `build.ps1` | Installs Chocolatey + NSIS, runs `tunic.ps1 noop` (syntax check), `makensis tunic.nsi` | Build |
| `main.go`, `Makefile`, `test.mk` | Abandoned Go rewrite stub: downloads upstream 0.2.4 exe and runs it | Deleted (ADR 0003) |
| `run.py`, `setup.py` | Abandoned Python/GTK rewrite; `setup.py` is copy-paste from another project ("halo"), won't run | Deleted (ADR 0003) |
| `.github/workflows/CI.yml` | `make utest` → `go test` on `windows-2019` (no tests exist; runner image retired) | Deleted (ADR 0003) |
| `test/test-setup.ps1`, `test/test-loop.sh` | VirtualBox lab using MS "MSEdge Win10" VM (download URL dead) | Deleted (ADR 0003); replaced by `test/lab/` |
| `doc/` | Upstream docs (FAQ, TODO, security, references) | Reference only |

## Install flow (`tunic.ps1`, GUI path)

1. **`checks`** — admin, 64-bit OS, ≥3.5 GB RAM, 64-bit PowerShell, then refuses unless the system drive is fully decrypted (ADR 0004), Windows major ≥10, battery warning, pending-reboot check (installs `Test-PendingReboot` from PSGallery at runtime), Windows Update busy, refuses MBR. The system drive is `$env:SystemDrive` (upstream used `HOMEDRIVE`, which can be a mapped network drive).
2. **`initData`** — loads `distros.ps1`; also mounts any `~\Downloads\*.iso` to offer it by volume label; reads Windows user's full name/username/hostname.
3. **GUI** — install type (dual boot / erase disk / custom), distro, username/password/fullname/hostname, disclaimer checkbox. Dual boot → second page with sizes + helper buttons (cleanmgr, defrag, diskmgmt, disable swap, WinDirStat).
4. **`defrag`** (dual boot only) — hibernation + Fast Startup off, `Optimize-Volume -Defrag`.
5. **`repartition`** (dual boot only) — `Resize-Partition` on C: to leave `linuxSize` GB free.
6. **`guiDownloadIso`** — BITS download to `~\Downloads\<file>.iso`. No checksum.
7. **`installGrub`**
   - Mounts ESP as `S:` (hardcoded).
   - Downloads `grub-2.04-for-windows.zip` from ftp.gnu.org into `C:\ProgramData\tunic`, runs `grub-install.exe --no-nvram --target=x86_64-efi` onto the ESP (`S:\EFI\grub\grubx64.efi`, `S:\boot\grub\`).
   - If Secure Boot on: downloads `shimx64.efi.signed` from the pop-os/iso repo's unpinned `master` branch to `S:\EFI\grub\shimx64.efi`. Despite the repo, it is Ubuntu's shim: version 15.7, Canonical vendor certificate (verified from the file).
   - Copies `files/grub.cfg`; writes `grub.var.cfg` with the ISO path.
   - BCD: backs up to `bcd-before.bak`, `bcdedit /copy {bootmgr}`, points it at shim or grub, puts it **first** in `{fwbootmgr}` displayorder, saves id to `bcd.id`.
   - Expands `files/preseed.cfg` → `C:\ProgramData\tunic\preseed.cfg` (contains the **plaintext password**).
8. **Reboot** → firmware boots GRUB → GRUB finds ISO on NTFS C:, loopback-boots casper with `file=/isodevice/ProgramData/tunic/preseed.cfg automatic-ubiquity iso-scan/filename=... toram`.
9. **Ubiquity** runs unattended: `partman-auto` with `biggest_free` (dual) or whole disk; `atomic` recipe; locale/timezone/user from preseed; reboots.

CLI verbs (`tunic.ps1 <verb>`): `download-iso`, `enable-swap`, `disable-swap`, `install-grub` (disabled: it never loaded user data, so it wrote a first-in-boot-order entry with no ISO path and an empty password), `tz`, `full-disk` (test path: hardcoded Mint 19.3, password `tunic`), `defrag`, `preseed` (prints expanded preseed), `hidden`, `uninstall`, `noop`. There is no non-GUI dual-boot path.

## Ubuntu 24.04+ breakage (the core problem)

- `grub.cfg` passes `automatic-ubiquity` and a d-i preseed. 24.04 desktop has no Ubiquity; its installer (a Flutter UI from the `ubuntu-desktop-provision` repo, shipped as the `ubuntu-desktop-bootstrap` snap, on a Subiquity backend) takes an **autoinstall** YAML instead. Verified in canonical/subiquity docs: autoinstall works on Ubuntu Desktop 23.04+; preseeds belong to debian-installer. Preseed is ignored → at best a manual installer, at worst a live session.
- `preseed.cfg` is d-i/partman syntax; must be rewritten as autoinstall (`storage`, `identity`, `locale`, `timezone`, `keyboard`, `late-commands`).
- Whether casper on 24.04/26.04 still honours `iso-scan/filename` + `toram` from a loopback NTFS ISO: **verify in Phase 2**.

## Other defects found (not yet fixed — Phase 4 candidates)

| # | Where | Problem | Impact |
| --- | --- | --- | --- |
| 1 | `repartition` | Typo `$linusSizeNum` vs `$linuxSizeNum` → `$shrinkBy` = −gap, so C: is **never shrunk** | Dual boot relies on pre-existing free space only |
| 2 | `preseed.cfg` (`partman-auto/disk`) | Target disk = `/dev/sd<a+diskNumber>` | Wrong on NVMe (`/dev/nvme0n1`), i.e. most Win11 machines |
| 3 | `installGrub` | The shim is Canonical's (15.7), so it only trusts Canonical-signed loaders. GNU `grubx64.efi` is unsigned and has no `.sbat` section → rejected under Secure Boot (MokManager or failure). Whether shim 15.7 is SBAT-revoked by current Windows updates: unverified. Fix direction: use Canonical-signed shim + grub from the target Ubuntu release | Secure Boot path likely broken |
| 4 | `grub.cfg` | GRUB reads the ISO from NTFS C:. With BitLocker/Device Encryption on (default on many Win11 devices) GRUB cannot read C: | Fixed: refuses unless fully decrypted (ADR 0004) |
| 5 | `preseed.cfg` | Plaintext user password left in `C:\ProgramData\tunic\preseed.cfg` | Security |
| 6 | `downloadIso` | No checksum/signature verification; HTTP URLs | Integrity |
| 7 | `installGrub` / `uninstall` | ESP hardcoded to `S:`; dev-only `Z:\Downloads` cache path | Collisions |
| 8 | `checks` | `die` calls `$form.close()` inside the form's Shown handler; whether that reliably ends the dialog is unverified, and `initFields` keeps going after it. Mitigated for encryption by a re-check before the first disk change. No Windows 11 / TPM awareness | Error handling |
| 9 | `distros.ps1` | All entries EOL; URLs likely dead | Nothing installable |
| 10 | Build/CI | CI runs Go tests that don't exist on a retired runner; Go/Python stubs confuse the build | Fixed: deleted (ADR 0003); new Pester CI |
| 11 | `installGrub` | `grub-2.04-for-windows.zip` from ftp.gnu.org: no signature check; its exe runs as admin and writes to the ESP | Security: unverified code run as admin |
| 12 | `installGrub` | Shim downloaded from an unpinned `master` branch of a third-party repo, no hash check, written to the ESP | Security: boot chain from a moving source |
| 13 | `checks` | `install-script Test-PendingReboot`: unpinned PSGallery script, run as admin on every launch | Security: unpinned code run as admin |
| 14 | `getLinuxTimeZone` | `windowsZones.xml` from unicode-org/cldr `master`, unpinned, no hash | Integrity (data only) |
| 15 | top of script | Drive letter from `HOMEDRIVE` (can be a mapped drive) | Fixed: `$env:SystemDrive` |

## Upstream activity

- Last commit 2023-08-28 (docs only); last code change 2020-08. 49 commits total.
- 9 open issues (newest: #20 "Abandoned?", 2024-03-18), 0 open PRs.
- Conclusion: dormant. Fork is justified.
