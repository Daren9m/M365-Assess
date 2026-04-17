BeforeDiscovery {
    # Nothing needed at discovery time
}

Describe 'Get-DnsSecurityConfig' {
    BeforeAll {
        # Stub the progress function so Add-Setting's guard passes
        function global:Update-CheckProgress {
            param($CheckId, $Setting, $Status)
        }

        # Stub EXO/DNS cmdlets so Mock can find them
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        # Mock accepted domains with one authoritative domain
        Mock Get-AcceptedDomain {
            return @([PSCustomObject]@{
                DomainName = 'contoso.com'
                DomainType = 'Authoritative'
            })
        }

        # Mock cross-platform DNS resolution for SPF, DMARC, and MX
        Mock Resolve-DnsRecord {
            param($Name, $Type)
            if ($Name -eq 'contoso.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{
                    Strings = @('v=spf1 include:spf.protection.outlook.com -all')
                })
            }
            if ($Name -eq '_dmarc.contoso.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{
                    Strings = @('v=DMARC1; p=reject; rua=mailto:dmarc@contoso.com')
                })
            }
            if ($Name -eq 'contoso.com' -and $Type -eq 'MX') {
                return @([PSCustomObject]@{
                    NameExchange = 'contoso-com.mail.protection.outlook.com'
                    Preference   = 10
                })
            }
            return $null
        }

        # Mock Get-Command for Update-CheckProgress guard
        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress') {
                return [PSCustomObject]@{ Name = 'Update-CheckProgress' }
            }
            return $null
        }

        # DKIM is now checked via try/catch instead of Get-Command guard
        Mock Get-DkimSigningConfig {
            return @([PSCustomObject]@{
                Domain  = 'contoso.com'
                Enabled = $true
            })
        }

        # Run the collector by dot-sourcing it
        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'Returns a non-empty settings list' {
        $settings.Count | Should -BeGreaterThan 0
    }

    It 'All settings have required properties' {
        foreach ($s in $settings) {
            $s.PSObject.Properties.Name | Should -Contain 'Category'
            $s.PSObject.Properties.Name | Should -Contain 'Setting'
            $s.PSObject.Properties.Name | Should -Contain 'Status'
            $s.PSObject.Properties.Name | Should -Contain 'CurrentValue'
            $s.PSObject.Properties.Name | Should -Contain 'RecommendedValue'
            $s.PSObject.Properties.Name | Should -Contain 'CheckId'
        }
    }

    It 'All Status values are valid' {
        $validStatuses = @('Pass', 'Fail', 'Warning', 'Review', 'Info', 'N/A', 'Skipped')
        foreach ($s in $settings) {
            $s.Status | Should -BeIn $validStatuses `
                -Because "Setting '$($s.Setting)' has status '$($s.Status)'"
        }
    }

    It 'All non-empty CheckIds follow naming convention' {
        $withCheckId = $settings | Where-Object { $_.CheckId -and $_.CheckId.Trim() -ne '' }
        $withCheckId.Count | Should -BeGreaterThan 0
        foreach ($s in $withCheckId) {
            $s.CheckId | Should -Match '^[A-Z]+(-[A-Z0-9]+)+-\d{3}(\.\d+)?$' `
                -Because "CheckId '$($s.CheckId)' should follow convention"
        }
    }

    It 'All CheckIds use the DNS- prefix' {
        $withCheckId = $settings | Where-Object { $_.CheckId -and $_.CheckId.Trim() -ne '' }
        foreach ($s in $withCheckId) {
            $s.CheckId | Should -Match '^DNS-' `
                -Because "CheckId '$($s.CheckId)' should start with DNS-"
        }
    }

    It 'SPF check passes for properly configured domain' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
    }

    It 'DKIM check passes for properly configured domain' {
        $check = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
    }

    It 'DMARC check passes for domain with p=reject' {
        $check = $settings | Where-Object { $_.Setting -eq 'DMARC Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
    }

    It 'MX check passes when MX points to Exchange Online' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
        $check.CurrentValue | Should -Match 'Exchange Online'
    }

    It 'Produces exactly 4 settings (SPF, DKIM, DMARC, MX)' {
        $settings.Count | Should -Be 4
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - Missing Records' {
    BeforeAll {
        function global:Update-CheckProgress {
            param($CheckId, $Setting, $Status)
        }

        # Stub EXO/DNS cmdlets so Mock can find them
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        Mock Get-AcceptedDomain {
            return @([PSCustomObject]@{
                DomainName = 'example.com'
                DomainType = 'Authoritative'
            })
        }

        # No DNS records found
        Mock Resolve-DnsRecord {
            return $null
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Get-DkimSigningConfig') {
                return [PSCustomObject]@{ Name = 'Get-DkimSigningConfig' }
            }
            if ($Name -eq 'Update-CheckProgress') {
                return [PSCustomObject]@{ Name = 'Update-CheckProgress' }
            }
            return $null
        }

        Mock Get-DkimSigningConfig {
            return @()
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'SPF check fails when no SPF record exists' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Fail'
    }

    It 'DKIM check fails when not configured' {
        $check = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Fail'
    }

    It 'DMARC check fails when no DMARC record exists' {
        $check = $settings | Where-Object { $_.Setting -eq 'DMARC Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Fail'
    }

    It 'MX check fails when no MX record exists' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Fail'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - Third-party MX relay' {
    BeforeAll {
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        Mock Get-AcceptedDomain {
            return @([PSCustomObject]@{
                DomainName = 'fabrikam.com'
                DomainType = 'Authoritative'
            })
        }

        Mock Resolve-DnsRecord {
            param($Name, $Type)
            if ($Name -eq 'fabrikam.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') })
            }
            if ($Name -eq '_dmarc.fabrikam.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject;') })
            }
            if ($Name -eq 'fabrikam.com' -and $Type -eq 'MX') {
                # MX points to Proofpoint, not Exchange Online
                return @([PSCustomObject]@{
                    NameExchange = 'fabrikam.com.pphosted.com'
                    Preference   = 10
                })
            }
            return $null
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress') {
                return [PSCustomObject]@{ Name = 'Update-CheckProgress' }
            }
            return $null
        }

        Mock Get-DkimSigningConfig {
            return @([PSCustomObject]@{ Domain = 'fabrikam.com'; Enabled = $true })
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'MX check warns when MX points to a third-party relay' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Warning'
        $check.CurrentValue | Should -Match 'pphosted'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - .onmicrosoft.com filtering' {
    BeforeAll {
        function global:Update-CheckProgress {
            param($CheckId, $Setting, $Status)
        }

        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        # Return one real domain plus one Microsoft-managed .onmicrosoft.com domain
        Mock Get-AcceptedDomain {
            return @(
                [PSCustomObject]@{ DomainName = 'contoso.com'; DomainType = 'Authoritative' }
                [PSCustomObject]@{ DomainName = 'contoso.onmicrosoft.com'; DomainType = 'Authoritative' }
            )
        }

        Mock Resolve-DnsRecord {
            param($Name, $Type)
            if ($Name -eq 'contoso.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') })
            }
            if ($Name -eq '_dmarc.contoso.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject; rua=mailto:dmarc@contoso.com') })
            }
            return $null
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress') {
                return [PSCustomObject]@{ Name = 'Update-CheckProgress' }
            }
            return $null
        }

        Mock Get-DkimSigningConfig {
            return @([PSCustomObject]@{ Domain = 'contoso.com'; Enabled = $true })
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'should produce a Pass verdict when the real domain passes (not penalized for .onmicrosoft.com)' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check.Status | Should -Be 'Pass'
    }

    It 'should report 1/1 in CurrentValue -- .onmicrosoft.com excluded from domain count' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check.CurrentValue | Should -Match '1/1'
    }

    It 'should not attempt DNS resolution for .onmicrosoft.com' {
        Should -Invoke Resolve-DnsRecord -ParameterFilter { $Name -like '*onmicrosoft*' } -Times 0 -Exactly
    }

    It 'DKIM check passes for the real domain only' {
        $check = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $check.Status | Should -Be 'Pass'
    }

    It 'DMARC check passes for the real domain only' {
        $check = $settings | Where-Object { $_.Setting -eq 'DMARC Records' }
        $check.Status | Should -Be 'Pass'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - SERVFAIL zone detection' {
    BeforeAll {
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }
        function Test-DnsZoneAvailable { }

        Mock Get-AcceptedDomain {
            return @(
                [PSCustomObject]@{ DomainName = 'healthy.com';  DomainType = 'Authoritative' }
                [PSCustomObject]@{ DomainName = 'broken.com'; DomainType = 'Authoritative' }
            )
        }

        # Test-DnsZoneAvailable returns $false only for broken.com
        Mock Test-DnsZoneAvailable {
            param($Name, $Server)
            return $Name -ne 'broken.com'
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress')    { return [PSCustomObject]@{ Name = 'Update-CheckProgress' } }
            if ($Name -eq 'Test-DnsZoneAvailable')   { return [PSCustomObject]@{ Name = 'Test-DnsZoneAvailable' } }
            return $null
        }

        Mock Resolve-DnsRecord {
            param($Name, $Type)
            if ($Name -eq 'healthy.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') })
            }
            if ($Name -eq '_dmarc.healthy.com' -and $Type -eq 'TXT') {
                return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject;') })
            }
            if ($Name -eq 'healthy.com' -and $Type -eq 'MX') {
                return @([PSCustomObject]@{ NameExchange = 'healthy-com.mail.protection.outlook.com'; Preference = 10 })
            }
            return $null
        }

        Mock Get-DkimSigningConfig {
            return @([PSCustomObject]@{ Domain = 'healthy.com'; Enabled = $true })
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'Emits DNS-ZONE-001 Fail finding for the broken zone' {
        $check = $settings | Where-Object { $_.Setting -eq 'DNS Zone Health' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Fail'
        $check.CurrentValue | Should -Match 'broken.com'
    }

    It 'DNS-ZONE-001 CheckId follows naming convention' {
        $check = $settings | Where-Object { $_.Setting -eq 'DNS Zone Health' }
        $check.CheckId | Should -Match '^DNS-ZONE-001'
    }

    It 'Broken domain is excluded from SPF check results' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.CurrentValue | Should -Not -Match 'broken.com'
    }

    It 'Healthy domain still passes all checks' {
        $spf   = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $dkim  = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $dmarc = $settings | Where-Object { $_.Setting -eq 'DMARC Records' }
        $mx    = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $spf.Status   | Should -Be 'Pass'
        $dkim.Status  | Should -Be 'Pass'
        $dmarc.Status | Should -Be 'Pass'
        $mx.Status    | Should -Be 'Pass'
    }

    It 'SPF count reflects evaluated domains only (excludes broken zone)' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check.CurrentValue | Should -Match '1/1'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - Null MX (RFC 7505) and defensive lockdown' {
    BeforeAll {
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        Mock Get-AcceptedDomain {
            return @(
                # Sending domain: full EXO config
                [PSCustomObject]@{ DomainName = 'send.com';   DomainType = 'Authoritative' }
                # Parked/non-sending domain: null SPF + null MX + DMARC reject
                [PSCustomObject]@{ DomainName = 'parked.com'; DomainType = 'Authoritative' }
            )
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress') { return [PSCustomObject]@{ Name = 'Update-CheckProgress' } }
            return $null  # Test-DnsZoneAvailable returns $null -> SERVFAIL pre-pass skipped
        }

        Mock Resolve-DnsRecord {
            param($Name, $Type)
            switch ("$Name|$Type") {
                'send.com|TXT'          { return @([PSCustomObject]@{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') }) }
                '_dmarc.send.com|TXT'   { return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject;') }) }
                'send.com|MX'           { return @([PSCustomObject]@{ NameExchange = 'send-com.mail.protection.outlook.com'; Preference = 10 }) }
                'parked.com|TXT'        { return @([PSCustomObject]@{ Strings = @('v=spf1 -all') }) }
                '_dmarc.parked.com|TXT' { return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject;') }) }
                'parked.com|MX'         { return @([PSCustomObject]@{ NameExchange = '.'; Preference = 0 }) }
                default                 { return $null }
            }
        }

        Mock Get-DkimSigningConfig {
            return @([PSCustomObject]@{ Domain = 'send.com'; Enabled = $true })
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'MX check passes when parked domain has RFC 7505 null MX' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
    }

    It 'MX CurrentValue notes the null MX (non-sending) domain' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check.CurrentValue | Should -Match 'null MX'
    }

    It 'Parked domain is excluded from DKIM evaluation' {
        $check = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
        # Only send.com evaluated: 1/1
        $check.CurrentValue | Should -Match '1/1'
    }

    It 'SPF check passes (null SPF v=spf1 -all is a valid SPF record)' {
        $check = $settings | Where-Object { $_.Setting -eq 'SPF Records' }
        $check.Status | Should -Be 'Pass'
    }

    It 'Emits DNS-LOCKDOWN-001 Pass for fully locked-down parked domain' {
        $check = $settings | Where-Object { $_.Setting -eq 'Non-Sending Domain Lockdown' }
        $check | Should -Not -BeNullOrEmpty
        $check.Status | Should -Be 'Pass'
        $check.CurrentValue | Should -Match 'parked.com'
    }

    It 'DNS-LOCKDOWN-001 CheckId follows naming convention' {
        $check = $settings | Where-Object { $_.Setting -eq 'Non-Sending Domain Lockdown' }
        $check.CheckId | Should -Match '^DNS-LOCKDOWN-001'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DnsSecurityConfig - Partial lockdown (null MX but no null SPF)' {
    BeforeAll {
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }
        function Get-AcceptedDomain { }
        function Resolve-DnsRecord { }
        function Get-DkimSigningConfig { }

        Mock Get-AcceptedDomain {
            # Domain has null MX but normal SPF (not a null/defensive SPF)
            return @([PSCustomObject]@{ DomainName = 'partial.com'; DomainType = 'Authoritative' })
        }

        Mock Get-Command {
            param($Name, $ErrorAction)
            if ($Name -eq 'Update-CheckProgress') { return [PSCustomObject]@{ Name = 'Update-CheckProgress' } }
            return $null
        }

        Mock Resolve-DnsRecord {
            param($Name, $Type)
            switch ("$Name|$Type") {
                'partial.com|TXT'          { return @([PSCustomObject]@{ Strings = @('v=spf1 include:spf.protection.outlook.com -all') }) }
                '_dmarc.partial.com|TXT'   { return @([PSCustomObject]@{ Strings = @('v=DMARC1; p=reject;') }) }
                'partial.com|MX'           { return @([PSCustomObject]@{ NameExchange = '.'; Preference = 0 }) }
                default                    { return $null }
            }
        }

        Mock Get-DkimSigningConfig {
            return @()
        }

        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"
        . "$PSScriptRoot/../../src/M365-Assess/Exchange-Online/Get-DnsSecurityConfig.ps1"
    }

    It 'MX still passes for null MX domain' {
        $check = $settings | Where-Object { $_.Setting -eq 'MX Records' }
        $check.Status | Should -Be 'Pass'
    }

    It 'DNS-LOCKDOWN-001 is NOT emitted without null SPF' {
        $check = $settings | Where-Object { $_.Setting -eq 'Non-Sending Domain Lockdown' }
        $check | Should -BeNullOrEmpty
    }

    It 'DKIM check fails because SPF is not null (domain appears to send but has no DKIM)' {
        $check = $settings | Where-Object { $_.Setting -eq 'DKIM Signing' }
        $check.Status | Should -Be 'Fail'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}
