BeforeAll {
    . (Join-Path $PSScriptRoot '../../scripts/Test-CollectorReadOnly.ps1')
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}

Describe 'Test-CollectorReadOnly' {

    Context 'when scanning the current collector folders' {
        It 'should return zero violations' {
            $result = Test-CollectorReadOnly -RepoRoot $script:repoRoot
            if ($result.Count -gt 0) {
                $detail = $result | ForEach-Object { "  $($_.Cmdlet) at $($_.File):$($_.Line)" }
                $msg = "Read-only guardrail violations:`n$($detail -join [Environment]::NewLine)"
                throw $msg
            }
            $result.Count | Should -Be 0
        }
    }

    Context 'when scanning a fixture with a tenant-mutating cmdlet' {
        BeforeAll {
            $script:violator = Join-Path $TestDrive 'Set-Violator.ps1'
            Set-Content -Path $script:violator -Value @'
[CmdletBinding()]
param()
Set-MgUser -UserId 'deadbeef' -DisplayName 'should fail'
'@
        }

        It 'should flag the Set-MgUser call' {
            $result = Test-CollectorReadOnly -Path $script:violator
            $result.Count | Should -BeGreaterThan 0
            $result[0].Cmdlet | Should -Be 'Set-MgUser'
            $result[0].Reason | Should -Match "Mutating verb 'Set-'"
        }
    }

    Context 'when scanning a fixture with each forbidden verb' {
        It 'should flag <Cmdlet>' -ForEach @(
            @{ Cmdlet = 'New-MgServicePrincipal' }
            @{ Cmdlet = 'Remove-MgUser' }
            @{ Cmdlet = 'Update-MgGroup' }
            @{ Cmdlet = 'Grant-CsTeamsAppPermission' }
            @{ Cmdlet = 'Revoke-MgUserSignInSession' }
            @{ Cmdlet = 'Disable-MgUser' }
            @{ Cmdlet = 'Enable-MgUser' }
            @{ Cmdlet = 'Add-MgGroupMember' }
        ) {
            $fixture = Join-Path $TestDrive "verb-$($Cmdlet).ps1"
            Set-Content -Path $fixture -Value "$Cmdlet -Foo bar"
            $result = Test-CollectorReadOnly -Path $fixture
            $result.Count | Should -Be 1
            $result[0].Cmdlet | Should -Be $Cmdlet
        }
    }

    Context 'when scanning a fixture with allowlisted cmdlets' {
        It 'should not flag <Cmdlet>' -ForEach @(
            @{ Cmdlet = 'Add-Setting' }
            @{ Cmdlet = 'Add-SecuritySetting' }
            @{ Cmdlet = 'Add-Member' }
            @{ Cmdlet = 'New-Object' }
            @{ Cmdlet = 'Set-Variable' }
            @{ Cmdlet = 'Remove-Item' }
            @{ Cmdlet = 'Update-CheckProgress' }
            @{ Cmdlet = 'New-CimSession' }
        ) {
            $fixture = Join-Path $TestDrive "allow-$($Cmdlet).ps1"
            Set-Content -Path $fixture -Value "$Cmdlet -Foo bar"
            $result = Test-CollectorReadOnly -Path $fixture
            $result.Count | Should -Be 0
        }
    }

    Context 'when scanning a fixture with Invoke-MgGraphRequest' {
        It 'should flag -Method <Method>' -ForEach @(
            @{ Method = 'POST' }
            @{ Method = 'PATCH' }
            @{ Method = 'DELETE' }
            @{ Method = 'PUT' }
            @{ Method = 'post' }
        ) {
            $fixture = Join-Path $TestDrive "graph-$($Method).ps1"
            Set-Content -Path $fixture -Value "Invoke-MgGraphRequest -Uri '/me' -Method '$Method' -Body @{}"
            $result = Test-CollectorReadOnly -Path $fixture
            $result.Count | Should -Be 1
            $result[0].Cmdlet | Should -Match 'Invoke-MgGraphRequest'
            $result[0].Reason | Should -Match 'Tenant-mutating Graph method'
        }

        It 'should not flag -Method GET' {
            $fixture = Join-Path $TestDrive 'graph-GET.ps1'
            Set-Content -Path $fixture -Value "Invoke-MgGraphRequest -Uri '/me' -Method GET"
            $result = Test-CollectorReadOnly -Path $fixture
            $result.Count | Should -Be 0
        }

        It 'should not flag a call without -Method (defaults to GET)' {
            $fixture = Join-Path $TestDrive 'graph-default.ps1'
            Set-Content -Path $fixture -Value "Invoke-MgGraphRequest -Uri '/me'"
            $result = Test-CollectorReadOnly -Path $fixture
            $result.Count | Should -Be 0
        }
    }
}
