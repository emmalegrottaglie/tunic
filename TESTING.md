# Testing

Safety: never run Tunic or any disk/BCD/GRUB script on a host. VM only. Snapshot before every run, restore after.

## Lab VM (Phase 2 — not built yet)

Target: Windows 11, UEFI + Secure Boot + TPM 2.0, single-partition disk ≥120 GB, 4+ GB RAM.
Hypervisor: pending Emma's choice (Hyper-V Gen 2 or VirtualBox 7+).

Steps: _to be written when the VM is built._ Upstream's `test/test-loop.sh` (VirtualBox, MS "MSEdge Win10" image) is stale: image URL is dead and it targets Win10.

## Test matrix

| Scenario | Firmware | Expected | Last result |
| --- | --- | --- | --- |
| Dual boot, Ubuntu 24.04 | UEFI + SB | Both OSes boot from GRUB; Windows intact | not run |
| Dual boot, Ubuntu 26.04 | UEFI + SB | Same | not run |
| BitLocker enabled | UEFI + SB | Detected; clear warning or safe handling, no lockout | not run |
| Too little free space | UEFI | Refuses before touching disk | not run |
| Cancel mid-install | UEFI | Windows still boots | not run |
| Legacy BIOS / MBR | BIOS | Clear "not supported" | not run |

Baseline (Phase 2): upstream unchanged with 22.04, then 24.04.

## Run log

_None yet._
