# Tunic fork - Hyper-V test lab
# Creates the Windows 11 test VM described in TESTING.md.
# Runs on the HOST. It only creates a VM and a new .vhdx file; it never touches host disks,
# partitions, BCD or firmware. Tunic itself must only ever run INSIDE the VM.

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

param(
    [Parameter(Mandatory)] [string] $WindowsIso,          # Windows 11 ISO (e.g. Enterprise evaluation)
    [string] $Name        = 'tunic-lab',
    [string] $VmRoot      = "$env:PUBLIC\Documents\Hyper-V\tunic-lab",
    [int64]  $DiskBytes   = 128GB,                        # brief: >= 120 GB
    [int64]  $MemoryBytes = 12GB,                         # see NOTES.md: casper 'toram' copies the ISO into RAM
    [int]    $Cpus        = 4,
    [string] $Switch      = 'Default Switch'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WindowsIso -PathType Leaf)) { throw "ISO not found: $WindowsIso" }
if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "VM '$Name' already exists. Remove it first or pass -Name." }

New-Item -ItemType Directory -Force -Path $VmRoot | Out-Null
$vhd = Join-Path $VmRoot "$Name.vhdx"
if (Test-Path -LiteralPath $vhd) { throw "Disk already exists: $vhd" }

# Everything below creates resources that did not exist before (checked above).
# On failure, remove only those, so a rerun starts clean.
try {
    # Gen 2 = UEFI. SCSI disk (shows as /dev/sda in Linux - see TESTING.md coverage gaps).
    New-VM -Name $Name -Generation 2 -MemoryStartupBytes $MemoryBytes `
        -NewVHDPath $vhd -NewVHDSizeBytes $DiskBytes -SwitchName $Switch -Path $VmRoot | Out-Null

    # Static memory: Tunic checks total RAM, and dynamic memory can under-report it.
    Set-VM -Name $Name -ProcessorCount $Cpus -StaticMemory -AutomaticCheckpointsEnabled $false

    # Secure Boot with the third-party CA, like a real OEM PC. The default 'MicrosoftWindows'
    # template only trusts Windows and would block any Linux shim, giving a false failure.
    Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

    # TPM 2.0 (Windows 11 requirement; also enables BitLocker test scenarios).
    Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector
    Enable-VMTPM -VMName $Name

    # Lets the host push files into the guest with Copy-VMFile.
    Enable-VMIntegrationService -VMName $Name -Name 'Guest Service Interface'

    $dvd = Add-VMDvdDrive -VMName $Name -Path $WindowsIso -Passthru
    Set-VMFirmware -VMName $Name -FirstBootDevice $dvd
} catch {
    Write-Warning "VM creation failed: $_  Removing the partly created VM '$Name' and its disk."
    if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { Remove-VM -Name $Name -Force }
    if (Test-Path -LiteralPath $vhd) { Remove-Item -LiteralPath $vhd -Force }
    throw
}

Write-Host "Created VM '$Name'. Next: TESTING.md, 'Lab VM' step 3 (install Windows)."
