BeforeDiscovery {
    # Nothing needed at discovery time
}

Describe 'Build-RemediationPlanHtml' {
    BeforeAll {
        # Stub Update-CheckProgress globally so Build-SectionHtml.ps1 can load without error
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }

        # ReportHelpers provides ConvertTo-HtmlSafe used inside the function
        . "$PSScriptRoot/../../src/M365-Assess/Common/ReportHelpers.ps1"

        # Build-SectionHtml.ps1 sets variables AND defines Build-RemediationPlanHtml.
        # Stub the variables the script-body references so it does not fail.
        $allCisFindings         = @()
        $SkipComplianceOverview = $false
        $controlRegistry        = @{}
        $issues                 = @()
        $sections               = @()
        $sectionStatusCounts    = @{}
        $QuickScan              = $false

        . "$PSScriptRoot/../../src/M365-Assess/Common/Build-SectionHtml.ps1"
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }

    Context 'when there are no Fail or Warning findings' {
        It 'should return the empty-state placeholder' {
            $result = Build-RemediationPlanHtml -Findings @() -IsQuickScan $false
            $result | Should -Match 'No actionable findings'
        }

        It 'should return the empty-state placeholder when all findings are Pass' {
            $passFindings = @(
                [PSCustomObject]@{ CheckId = 'ID-001'; Setting = 'MFA'; Status = 'Pass'; RiskSeverity = 'High'; Section = 'Identity'; CurrentValue = 'Enabled'; Remediation = 'N/A' }
            )
            $result = Build-RemediationPlanHtml -Findings $passFindings -IsQuickScan $false
            $result | Should -Match 'No actionable findings'
        }
    }

    Context 'when findings include Fail and Warning rows' {
        BeforeAll {
            $script:testFindings = @(
                [PSCustomObject]@{ CheckId = 'DEF-001'; Setting = 'AntiPhish'; Status = 'Warning'; RiskSeverity = 'Medium'; Section = 'Security'; CurrentValue = 'Default'; Remediation = 'Enable strict preset policy' }
                [PSCustomObject]@{ CheckId = 'ID-002';  Setting = 'MFA';       Status = 'Fail';    RiskSeverity = 'Critical'; Section = 'Identity'; CurrentValue = 'Disabled'; Remediation = 'Set-MsolUser -UserPrincipalName user@domain.com -StrongAuthenticationRequirements ...' }
                [PSCustomObject]@{ CheckId = 'EXO-001'; Setting = 'DMARC';     Status = 'Pass';    RiskSeverity = 'High';    Section = 'Email';    CurrentValue = 'Pass';     Remediation = '' }
                [PSCustomObject]@{ CheckId = 'ID-003';  Setting = 'AdminMFA';  Status = 'Fail';    RiskSeverity = 'High';    Section = 'Identity'; CurrentValue = '3 admins no MFA'; Remediation = 'Enforce MFA for all admin roles' }
            )
        }

        It 'should exclude Pass-status findings from the output' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Not -Match 'DMARC'
        }

        It 'should include Fail findings in the output' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match 'MFA'
        }

        It 'should sort Critical findings before High findings in row order' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            # Critical row class must appear before the first High row class in the HTML
            $critPos = $result.IndexOf("remediation-row-critical")
            $highPos = $result.IndexOf("remediation-row-high")
            $critPos | Should -BeLessThan $highPos
        }

        It 'should render the full remediation text without truncation' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            # The long remediation string must appear in full, not truncated to 200 chars
            $result | Should -Match 'StrongAuthenticationRequirements'
        }

        It 'should include a copy button on every actionable row' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            # 3 actionable findings (2 Fail + 1 Warning) -> 3 copy buttons
            $copyButtonCount = ([regex]::Matches($result, 'copyRemediation\(this\)')).Count
            $copyButtonCount | Should -Be 3
        }

        It 'should display correct Critical count in stats row' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match 'remediation-stat-critical'
            $result | Should -Match '<span class=.stat-num.>1</span>'
        }

        It 'should display correct High count in stats row' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match 'remediation-stat-high'
            $result | Should -Match '<span class=.stat-num.>1</span>'
        }

        It 'should include severity filter select element' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match 'remSeverityFilter'
        }

        It 'should include section filter select when multiple sections present' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match 'remSectionFilter'
        }

        It 'should add data-severity attribute to each row for JS filtering' {
            $result = Build-RemediationPlanHtml -Findings $script:testFindings -IsQuickScan $false
            $result | Should -Match "data-severity='Critical'"
            $result | Should -Match "data-severity='High'"
        }
    }

    Context 'when IsQuickScan is true' {
        It 'should include the QuickScan context note' {
            $finding = @(
                [PSCustomObject]@{ CheckId = 'ID-001'; Setting = 'MFA'; Status = 'Fail'; RiskSeverity = 'Critical'; Section = 'Identity'; CurrentValue = 'Off'; Remediation = 'Enable MFA' }
            )
            $result = Build-RemediationPlanHtml -Findings $finding -IsQuickScan $true
            $result | Should -Match 'Quick Scan mode'
        }

        It 'should not include the QuickScan note when IsQuickScan is false' {
            $finding = @(
                [PSCustomObject]@{ CheckId = 'ID-001'; Setting = 'MFA'; Status = 'Fail'; RiskSeverity = 'Critical'; Section = 'Identity'; CurrentValue = 'Off'; Remediation = 'Enable MFA' }
            )
            $result = Build-RemediationPlanHtml -Findings $finding -IsQuickScan $false
            $result | Should -Not -Match 'Quick Scan mode'
        }
    }

    Context 'when only one section is present' {
        It 'should not render the section filter select' {
            $findings = @(
                [PSCustomObject]@{ CheckId = 'ID-001'; Setting = 'MFA';      Status = 'Fail'; RiskSeverity = 'Critical'; Section = 'Identity'; CurrentValue = 'Off'; Remediation = 'Enable MFA' }
                [PSCustomObject]@{ CheckId = 'ID-002'; Setting = 'AdminMFA'; Status = 'Fail'; RiskSeverity = 'High';     Section = 'Identity'; CurrentValue = 'Off'; Remediation = 'Enforce admin MFA' }
            )
            $result = Build-RemediationPlanHtml -Findings $findings -IsQuickScan $false
            $result | Should -Not -Match 'remSectionFilter'
        }
    }
}
