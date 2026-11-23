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
