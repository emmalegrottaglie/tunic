# Pester 5 tests for the BitLocker refusal (ADR 0004).
# Run on Windows: Invoke-Pester test/unit
# Pure logic only: nothing here touches disks, BitLocker or boot config.

BeforeAll {
    . "$PSScriptRoot/../../tunic.ps1"
}

Describe 'getEncryptionBlocker' {
    It 'allows a fully decrypted drive' {
        getEncryptionBlocker 0 'C' | Should -BeNullOrEmpty
    }

    It 'allows a system without BitLocker' {
        getEncryptionBlocker $null 'C' | Should -BeNullOrEmpty
    }

    It 'refuses conversion status <status>' -ForEach @(
        @{ status = 1 }, @{ status = 2 }, @{ status = 3 },
        @{ status = 4 }, @{ status = 5 }, @{ status = 99 }
    ) {
        $msg = getEncryptionBlocker $status 'C'
        $msg | Should -Match 'cannot install Linux from an encrypted drive'
        $msg | Should -Match 'manage-bde -off C:'
    }
}

Describe 'checkEncryption' {
    It 'passes when the drive is decrypted' {
        Mock getConversionStatus { 0 }
        checkEncryption | Should -BeNullOrEmpty
    }

    It 'refuses when the drive is encrypted' {
        Mock getConversionStatus { 1 }
        checkEncryption | Should -Match 'is encrypted'
    }

    It 'refuses (fails safe) when the state cannot be read' {
        Mock getConversionStatus { throw 'Access denied' }
        checkEncryption | Should -Match 'Could not check'
    }
}

Describe 'assertNotEncrypted' {
    It 'throws when encrypted' {
        Mock getConversionStatus { 1 }
        { assertNotEncrypted } | Should -Throw
    }

    It 'does nothing when decrypted' {
        Mock getConversionStatus { 0 }
        { assertNotEncrypted } | Should -Not -Throw
    }
}

Describe 'getConversionStatus' {
    BeforeAll {
        # In-memory CIM object (no WMI call), so Invoke-CimMethod's typed -InputObject binds.
        $script:vol = New-CimInstance -ClientOnly -Namespace 'root/CIMV2/Security/MicrosoftVolumeEncryption' `
            -ClassName Win32_EncryptableVolume -Property @{ DriveLetter = 'C:' }
    }

    BeforeEach {
        Mock is64BitProcess { $true }
        Mock Get-CimInstance { $script:vol }
    }

    It 'returns the status when the call succeeds' {
        Mock Invoke-CimMethod { [pscustomobject]@{ ReturnValue = 0; ConversionStatus = 1 } }
        getConversionStatus 'C' | Should -Be 1
    }

    It 'returns $null when BitLocker is not installed (InvalidNamespace)' {
        Mock Get-CimInstance {
            $ex = [System.Exception]::new('Invalid namespace')
            Add-Member -InputObject $ex -NotePropertyName NativeErrorCode -NotePropertyValue 'InvalidNamespace'
            throw $ex
        }
        getConversionStatus 'C' | Should -BeNullOrEmpty
    }

    It 'throws on any other CIM error' {
        Mock Get-CimInstance { throw 'Access denied' }
        { getConversionStatus 'C' } | Should -Throw
    }

    It 'throws when the drive has no volume instance' {
        Mock Get-CimInstance { }
        { getConversionStatus 'C' } | Should -Throw '*No BitLocker volume information*'
    }

    It 'throws when GetConversionStatus fails' {
        Mock Invoke-CimMethod { [pscustomobject]@{ ReturnValue = 2150694912; ConversionStatus = $null } }
        { getConversionStatus 'C' } | Should -Throw '*0x80310000*'
    }

    It 'throws when no status comes back' {
        Mock Invoke-CimMethod { [pscustomobject]@{ ReturnValue = 0; ConversionStatus = $null } }
        { getConversionStatus 'C' } | Should -Throw
    }

    It 'refuses in a 32-bit process, before calling CIM' {
        Mock is64BitProcess { $false }
        { getConversionStatus 'C' } | Should -Throw '*64-bit*'
        Should -Invoke Get-CimInstance -Times 0 -Exactly
    }
}

Describe 'drive letter' {
    It 'uses the system drive, not HOMEDRIVE' {
        $global:letter | Should -Be $env:SystemDrive[0]
    }
}
