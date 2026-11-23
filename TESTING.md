# Testing

Safety: never run Tunic or any disk/BCD/GRUB script on a host. VM only. Checkpoint before every run, restore after.

## Lab VM (Hyper-V)

Decided 2026-11-23: Hyper-V Gen 2. Why: its Secure Boot uses Microsoft's real UEFI CA certificates, so shim/GRUB results match real PCs; scripting is PowerShell like Tunic.

Host needs: Windows 10/11 Pro, Enterprise or Education; virtualization on in firmware; ~140 GB free.

1. Enable Hyper-V (admin PowerShell, then reboot):
   `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`
2. Download a Windows 11 ISO (Enterprise 90-day evaluation from the Microsoft Evaluation Center is fine). Create the VM:
   `.\test\lab\new-lab-vm.ps1 -WindowsIso C:\path\to\Win11.iso`
   On a Windows Server host there is no 'Default Switch': create one and pass `-Switch <name>`.
   Check the Secure Boot template took: `(Get-VMFirmware tunic-lab).SecureBootTemplate` → `MicrosoftUEFICertificateAuthority`. If not, stop: Linux will not boot and results are meaningless.
   This sets: Gen 2/UEFI, Secure Boot with "Microsoft UEFI Certificate Authority" template, vTPM, 4 CPU, 12 GB static RAM, 128 GB disk, Guest Service Interface.
3. Start the VM (`Start-VM tunic-lab; vmconnect localhost tunic-lab`), press a key to boot the DVD, install Windows to the whole disk with a local account. Default layout (EFI, MSR, C:, Recovery) is expected.
4. Inside the VM, admin PowerShell:
   - `manage-bde -status C:` → must say "Fully Decrypted" for the baseline. If not: `manage-bde -off C:` and wait.
   - `Confirm-SecureBootUEFI` → `True`.
   - `Get-Partition` → record the layout in the run log.
5. Shut down the VM, eject the DVD (`Set-VMDvdDrive -VMName tunic-lab -Path $null`), take the clean checkpoint:
   `Checkpoint-VM -Name tunic-lab -SnapshotName clean-win11`

Restore before every run: `Restore-VMCheckpoint -VMName tunic-lab -Name clean-win11 -Confirm:$false`

### Coverage gaps of this lab

- Hyper-V disks are SCSI (`/dev/sda`). The NVMe naming bug (architecture.md #2) will NOT reproduce here. Needs real NVMe hardware or a QEMU VM with an NVMe disk.
- Hyper-V has no legacy BIOS with Windows 11 (Gen 1 VMs can't run Win11). The BIOS/MBR matrix row needs a Gen 1 VM with Windows 10, if in scope.

## Phase 2 baseline: upstream, unchanged

Goal: record what upstream does today. No code changes.

Per run (22.04 first, then 24.04):

1. Restore `clean-win11`, start the VM.
2. Copy upstream source into the VM. On the host, from the repo root:
   `git archive --format=zip -o $env:TEMP\tunic-upstream.zip 2e6b687`
   `Copy-VMFile tunic-lab -SourcePath $env:TEMP\tunic-upstream.zip -DestinationPath C:\tunic\tunic-upstream.zip -CreateFullPath -FileSource Host`
   (Archive goes to TEMP, not the repo, so it can't be committed.)
   In the VM: `Expand-Archive C:\tunic\tunic-upstream.zip C:\tunic\src`
3. In the VM, download the ISO into `~\Downloads` (Tunic auto-lists any ISO there; upstream's built-in list is all EOL):
   - 22.04: latest `ubuntu-22.04.*-desktop-amd64.iso` from https://releases.ubuntu.com/22.04/
   - 24.04: latest `ubuntu-24.04.*-desktop-amd64.iso` from https://releases.ubuntu.com/24.04/
   Check it: `Get-FileHash <iso>` vs that folder's `SHA256SUMS`.
4. Pre-shrink C: by 40 GB inside the VM. Why: upstream's shrink never runs (architecture.md #1), so without free space the install has nowhere to go.
   `$p = Get-Partition -DriveLetter C; Resize-Partition -DriveLetter C -Size ($p.Size - 40GB)`
5. Take a run checkpoint so the run can be repeated: shut down, `Checkpoint-VM -Name tunic-lab -SnapshotName pre-<version>`, start.
6. Admin PowerShell in the VM: `C:\tunic\src\test\tunic.bat`. Choose the ISO by its volume label, "Install Linux alongside Windows", Linux size 40, password `tunic-test`.
7. Watch from the VM console and record each step in the run log (template below). Note screenshots for any failure.
8. Afterwards: does Windows still boot (from the firmware boot menu if GRUB fails)?

Expected (from code reading, to confirm):
- 22.04: GRUB menu appears; Secure Boot may stop at shim/MokManager (architecture.md #3); if it boots, Ubiquity installs unattended.
- 24.04: GRUB menu appears; installer ignores the preseed → manual installer or live desktop.

## Unit tests

Pester 5, pure logic only (no disk access). Run on Windows: `Invoke-Pester test/unit`. CI (`.github/workflows/ci.yml`) runs them on every push under Windows PowerShell 5.1, plus a parse check of every `.ps1`.

## Test matrix (definition of done)

| Scenario | Firmware | Expected | Last result |
| --- | --- | --- | --- |
| Dual boot, Ubuntu 24.04 | UEFI + SB | Both OSes boot from GRUB; Windows intact | not run |
| Dual boot, Ubuntu 26.04 | UEFI + SB | Same | not run |
| BitLocker / Device Encryption on (any state, incl. suspended) | UEFI + SB | Refuses before touching the disk, with decrypt steps (ADR 0004) | not run |
| Too little free space | UEFI | Refuses before touching disk | not run |
| Cancel mid-install | UEFI | Windows still boots | not run |
| Legacy BIOS / MBR | BIOS | Clear "not supported" | not run |

## Run log

Copy this block per run, newest first.

```
### YYYY-MM-DD - <scenario> - <tunic commit> - <ISO file name>
VM: tunic-lab, checkpoint <name>, Secure Boot on/off, BitLocker on/off
Partitions before: ...
Steps:
- checks:            pass/fail + message
- download/ISO:      ...
- GRUB install:      ...
- reboot -> GRUB:    menu shown? which entry?
- shim/Secure Boot:  booted / MokManager / blocked (message)
- installer:         unattended / manual / live desktop / error (message)
- final boot Linux:  ...
- final boot Windows: ...
Partitions after: ...
Result: PASS / FAIL
Notes:
```

_No runs yet._
