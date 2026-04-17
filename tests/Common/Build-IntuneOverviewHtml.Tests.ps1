BeforeAll {
    . "$PSScriptRoot/../../src/M365-Assess/Common/Build-IntuneOverviewHtml.ps1"

    if (-not (Get-Command -Name ConvertTo-HtmlSafe -ErrorAction SilentlyContinue)) {
        function ConvertTo-HtmlSafe { param([string]$Text) return [System.Net.WebUtility]::HtmlEncode($Text) }
    }

    function New-IntuneCheck {
        param(
            [string]$CheckId      = 'INTUNE-COMPLIANCE-001.1',
            [string]$Category     = 'Compliance',
            [string]$Setting      = 'Test Setting',
            [string]$CurrentValue = 'Disabled',
            [string]$Status       = 'Fail',
            [string]$Remediation  = 'Enable the setting.',
            [string]$RiskSeverity = 'High'
        )
        [PSCustomObject]@{
            CheckId      = $CheckId
            Category     = $Category
            Setting      = $Setting
            CurrentValue = $CurrentValue
            Status       = $Status
            Remediation  = $Remediation
            RiskSeverity = $RiskSeverity
        }
    }
}

Describe 'Build-IntuneOverviewHtml' {

    Context 'when no INTUNE-* findings are provided' {
        It 'should return an empty string when Findings is empty' {
            $result = Build-IntuneOverviewHtml -Findings @() -AssessmentFolder ''
            $result | Should -BeNullOrEmpty
        }

        It 'should return an empty string when Findings contain no INTUNE-* CheckIds' {
            $nonIntune = @(
                [PSCustomObject]@{ CheckId = 'CA-MFA-001.1'; Category = 'Identity'; Setting = 'MFA'; Status = 'Pass'; RiskSeverity = 'High' }
            )
            $result = Build-IntuneOverviewHtml -Findings $nonIntune -AssessmentFolder ''
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when INTUNE-* findings are provided without an assessment folder' {
        BeforeAll {
            $script:findings = @(
                New-IntuneCheck -CheckId 'INTUNE-COMPLIANCE-001.1' -Category 'Compliance' -Status 'Fail'
                New-IntuneCheck -CheckId 'INTUNE-SECURITY-001.1'   -Category 'Security'   -Status 'Warning'
                New-IntuneCheck -CheckId 'INTUNE-ENROLLMENT-001.1' -Category 'Enrollment' -Status 'Pass'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:findings -AssessmentFolder ''
        }

        It 'should return a non-empty HTML string' {
            $script:html | Should -Not -BeNullOrEmpty
        }

        It 'should include the section details element' {
            $script:html | Should -Match "id='intune-overview-section'"
        }

        It 'should include the Intune Overview heading' {
            $script:html | Should -Match 'Intune Overview'
        }

        It 'should show N/A for managed devices when no CSV is present' {
            $script:html | Should -Match 'Managed Devices'
            $script:html | Should -Match '>N/A<'
        }

        It 'should include the category coverage grid' {
            $script:html | Should -Match "class='intune-category-grid'"
        }

        It 'should render a card for each category in the findings' {
            $script:html | Should -Match 'Compliance'
            $script:html | Should -Match 'Security'
            $script:html | Should -Match 'Enrollment'
        }

        It 'should include the Intune findings table' {
            $script:html | Should -Match "id='intuneTable'"
        }

        It 'should include a row for each finding' {
            $script:html | Should -Match 'INTUNE-COMPLIANCE-001'
            $script:html | Should -Match 'INTUNE-SECURITY-001'
            $script:html | Should -Match 'INTUNE-ENROLLMENT-001'
        }

        It 'should include status filter chips for each status present' {
            $script:html | Should -Match "data-intune-status='Fail'"
            $script:html | Should -Match "data-intune-status='Warning'"
            $script:html | Should -Match "data-intune-status='Pass'"
        }

        It 'should include the intuneStatusChips chip group container' {
            $script:html | Should -Match "id='intuneStatusChips'"
        }

        It 'should include All and None chip control buttons' {
            $script:html | Should -Match 'rem-intune-all'
            $script:html | Should -Match 'rem-intune-none'
        }

        It 'should include a match count span for the table' {
            $script:html | Should -Match "id='intuneMatchCount'"
        }

        It 'should show 0% checks passing when all findings are non-pass' {
            $allFail = @(
                New-IntuneCheck -Status 'Fail'
                New-IntuneCheck -CheckId 'INTUNE-SECURITY-001.1' -Category 'Security' -Status 'Fail'
            )
            $result = Build-IntuneOverviewHtml -Findings $allFail -AssessmentFolder ''
            $result | Should -Match '>0%<'
        }
    }

    Context 'when findings include only Pass status' {
        BeforeAll {
            $script:passFindings = @(
                New-IntuneCheck -CheckId 'INTUNE-ENCRYPTION-001.1' -Category 'Encryption' -Status 'Pass'
                New-IntuneCheck -CheckId 'INTUNE-FIPS-001.1'       -Category 'FIPS Cryptography' -Status 'Pass'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:passFindings -AssessmentFolder ''
        }

        It 'should show 100% checks passing' {
            $script:html | Should -Match '>100%<'
        }

        It 'should not include a Fail status chip when no failures exist' {
            $script:html | Should -Not -Match "data-intune-status='Fail'"
        }

        It 'should include category cards with pass border class' {
            $script:html | Should -Match 'intune-cat-pass'
        }

        It 'should include Pass status badge in category cards' {
            $script:html | Should -Match "badge-success'>Pass"
        }
    }

    Context 'when findings include Fail and Warning categories' {
        BeforeAll {
            $script:mixed = @(
                New-IntuneCheck -CheckId 'INTUNE-COMPLIANCE-001.1' -Category 'Compliance' -Status 'Fail'
                New-IntuneCheck -CheckId 'INTUNE-COMPLIANCE-001.2' -Category 'Compliance' -Status 'Warning'
                New-IntuneCheck -CheckId 'INTUNE-SECURITY-001.1'   -Category 'Security'   -Status 'Pass'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:mixed -AssessmentFolder ''
        }

        It 'should assign fail border class to a category with at least one Fail' {
            $script:html | Should -Match 'intune-cat-fail'
        }

        It 'should assign pass border class to a category with only Pass' {
            $script:html | Should -Match 'intune-cat-pass'
        }

        It 'should show the Fail category card before the Pass category card (sorted by worst status)' {
            $failIdx = $script:html.IndexOf('intune-cat-fail')
            $passIdx = $script:html.IndexOf('intune-cat-pass')
            $failIdx | Should -BeLessThan $passIdx
        }
    }

    Context 'when INTUNE-INVENTORY-001 CurrentValue contains a device count' {
        BeforeAll {
            $script:invFindings = @(
                New-IntuneCheck -CheckId 'INTUNE-INVENTORY-001.1' -Category 'Inventory' -CurrentValue '247 devices enrolled' -Status 'Pass'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:invFindings -AssessmentFolder ''
        }

        It 'should extract and display the device count from CurrentValue' {
            $script:html | Should -Match '>247<'
        }
    }

    Context 'when CSV files are present in the assessment folder' {
        BeforeAll {
            $script:tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "intune-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
            $null = New-Item -ItemType Directory -Path $script:tempFolder -Force

            # Device summary: 4 devices, 3 compliant = 75%
            @'
DeviceName,ComplianceState,OS
Device01,Compliant,Windows
Device02,Compliant,Windows
Device03,Compliant,iOS
Device04,NonCompliant,Android
'@ | Set-Content -Path (Join-Path $script:tempFolder '13-Device-Summary.csv') -Encoding UTF8

            # Compliance policies: 2 rows
            @'
Name,Platform
Policy1,Windows
Policy2,iOS
'@ | Set-Content -Path (Join-Path $script:tempFolder '14-Compliance-Policies.csv') -Encoding UTF8

            # Config profiles: 3 rows
            @'
Name,Platform
Profile1,Windows
Profile2,Windows
Profile3,iOS
'@ | Set-Content -Path (Join-Path $script:tempFolder '15-Config-Profiles.csv') -Encoding UTF8

            $script:findings = @(
                New-IntuneCheck -CheckId 'INTUNE-COMPLIANCE-001.1' -Category 'Compliance' -Status 'Pass'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:findings -AssessmentFolder $script:tempFolder
        }

        AfterAll {
            if (Test-Path $script:tempFolder) {
                Remove-Item -Path $script:tempFolder -Recurse -Force
            }
        }

        It 'should display the total device count from 13-Device-Summary.csv' {
            $script:html | Should -Match '>4<'
        }

        It 'should display the compliant percentage' {
            $script:html | Should -Match '>75%<'
        }

        It 'should display the compliance policy count' {
            $script:html | Should -Match '>2<'
        }

        It 'should display the config profile count' {
            $script:html | Should -Match '>3<'
        }
    }

    Context 'when Special characters appear in findings' {
        BeforeAll {
            $script:specialFindings = @(
                New-IntuneCheck -CheckId 'INTUNE-SECURITY-001.1' -Category 'Security & Compliance' -Setting "Check <test> & 'verify'" -Status 'Fail' -Remediation 'Use "quotes" & tags'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:specialFindings -AssessmentFolder ''
        }

        It 'should HTML-encode ampersands in category names' {
            $script:html | Should -Match 'Security &amp; Compliance'
        }

        It 'should HTML-encode angle brackets in setting names' {
            $script:html | Should -Match '&lt;test&gt;'
        }

        It 'should HTML-encode double quotes in remediation text' {
            $script:html | Should -Match '&quot;quotes&quot;'
        }
    }

    Context 'when findings include Review and Skipped statuses' {
        BeforeAll {
            $script:miscFindings = @(
                New-IntuneCheck -CheckId 'INTUNE-APPCONTROL-001.1' -Category 'Application Control' -Status 'Review'
                New-IntuneCheck -CheckId 'INTUNE-FIPS-001.1'       -Category 'FIPS Cryptography'   -Status 'Skipped'
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:miscFindings -AssessmentFolder ''
        }

        It 'should include a Review status chip' {
            $script:html | Should -Match "data-intune-status='Review'"
        }

        It 'should render rows with correct data-intune-status attributes' {
            $script:html | Should -Match "data-intune-status='Skipped'"
        }
    }

    Context 'when findings include a check with no Remediation or RiskSeverity' {
        BeforeAll {
            $script:sparse = @(
                [PSCustomObject]@{
                    CheckId      = 'INTUNE-ENROLLMENT-001.1'
                    Category     = 'Enrollment'
                    Setting      = 'Minimal Check'
                    CurrentValue = 'Unknown'
                    Status       = 'Warning'
                    Remediation  = $null
                    RiskSeverity = $null
                }
            )
            $script:html = Build-IntuneOverviewHtml -Findings $script:sparse -AssessmentFolder ''
        }

        It 'should not throw when Remediation is null' {
            { Build-IntuneOverviewHtml -Findings $script:sparse -AssessmentFolder '' } | Should -Not -Throw
        }

        It 'should fall back to Low severity when RiskSeverity is null' {
            $script:html | Should -Match '>Low<'
        }
    }
}
