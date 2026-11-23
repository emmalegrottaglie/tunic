# 0004: Refuse to run when the Windows drive is encrypted

- Status: accepted
- Date: 2026-11-23
- Decided by: Emma

## Context

GRUB loads the Ubuntu ISO and the installer config straight from the NTFS C: drive. GRUB cannot read a BitLocker-encrypted volume, and suspending protection does not help: the data stays encrypted. Many Windows 11 PCs ship with Device Encryption (BitLocker) on by default.

Upstream only showed a warning, and only when protection was "On", so a suspended or in-progress volume passed silently. Result: a reboot into a GRUB that can't find the ISO.

## Options considered

1. Warn and continue (upstream): leads to a broken boot.
2. Guide the user to suspend BitLocker: doesn't work, data is still encrypted.
3. Stage the ISO on a new unencrypted partition: works, but adds partitioning risk and complexity. Possible later.
4. Refuse with clear steps to decrypt: safe, simple, user stays in control of their data.

## Decision

Option 4. Refuse unless C: is fully decrypted.

- Check: `Win32_EncryptableVolume.GetConversionStatus()` (CIM) on the system drive (`$env:SystemDrive`). Covers both BitLocker and Device Encryption and every state: encrypted, encrypting, decrypting, paused.
- Treated as "not encrypted" only when the BitLocker namespace does not exist (edition without BitLocker), and only in a 64-bit process (a 32-bit process can't see the namespace, so it is refused).
- Everything else unknown → refuse (fail safe): any other CIM error, no volume instance for the drive, a non-zero `ReturnValue`, no status returned.
- Runs in `checks` before anything is downloaded, again in the GUI right before the first disk change, and before the `full-disk` command line verb. (`install-grub` verb is disabled.)
- Message tells the user to save the recovery key, turn encryption off, wait for full decryption, rerun.

## Consequences

- Users with encryption on must decrypt first (can take hours) and re-enable it later themselves. Linux will not be encrypted by Tunic.
- `tunic.ps1` can now be dot-sourced without running (for Pester).
- Test matrix row "BitLocker enabled" now expects: refuses before touching the disk.
- Not yet verified on a real Windows install: the CIM call and the "InvalidNamespace" value need a run in the Hyper-V lab (TESTING.md). Unit tests mock the CIM calls.

## Revision 2026-11-23

An independent review found the first version passed (instead of refusing) when the volume instance was missing, when `GetConversionStatus` failed, and when `HOMEDRIVE` pointed at another drive; and the GUI only checked at startup. All fixed as above.
