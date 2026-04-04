<#
.SYNOPSIS
    End-to-end pipeline integration tests for Value Opportunity collectors.
.DESCRIPTION
    Runs all 4 Value Opportunity functions in sequence with real sku-feature-map.json
    data and mock tenant licenses/signals to verify the full pipeline works correctly.
#>

BeforeAll {
    $voDir = "$PSScriptRoot/../../src/M365-Assess/ValueOpportunity"
    . "$voDir/Get-LicenseUtilization.ps1"
    . "$voDir/Get-FeatureAdoption.ps1"
    . "$voDir/Get-FeatureReadiness.ps1"
    . "$voDir/Measure-ValueOpportunity.ps1"

    $mapPath = "$PSScriptRoot/../../src/M365-Assess/controls/sku-feature-map.json"
    $script:featureMap = Get-Content $mapPath -Raw | ConvertFrom-Json
}

Describe 'Value Opportunity Pipeline Integration' {
    BeforeAll {
        $script:tenantLicenses = @{
            ActiveServicePlans = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]@('AAD_PREMIUM', 'EXCHANGE_S_ENTERPRISE', 'SHAREPOINTENTERPRISE', 'TEAMS1'),
                [System.StringComparer]::OrdinalIgnoreCase
            )
        }

        $script:signals = @{}
        $script:signals['ENTRA-MFA-001.1'] = @{ Status = 'Pass'; Setting = 'MFA'; CurrentValue = 'Enabled'; Category = 'Identity' }
        $script:signals['ENTRA-MFA-002.1'] = @{ Status = 'Pass'; Setting = 'MFA'; CurrentValue = 'Enabled'; Category = 'Identity' }
        $script:signals['CA-MFA-ADMIN-001.1'] = @{ Status = 'Pass'; Setting = 'CA'; CurrentValue = 'On'; Category = 'Identity' }
        $script:signals['CA-LEGACY-001.1'] = @{ Status = 'Fail'; Setting = 'CA'; CurrentValue = 'Off'; Category = 'Identity' }
        $script:signals['DNS-DMARC-001.1'] = @{ Status = 'Fail'; Setting = 'DMARC'; CurrentValue = 'None'; Category = 'Email' }

        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "vo-pipeline-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        $script:license = Get-LicenseUtilization -TenantLicenses $script:tenantLicenses -FeatureMap $script:featureMap
        $script:adoption = Get-FeatureAdoption -AdoptionSignals $script:signals -LicenseUtilization $script:license -FeatureMap $script:featureMap -AssessmentFolder $script:tempDir
        $script:readiness = Get-FeatureReadiness -LicenseUtilization $script:license -FeatureAdoption $script:adoption -FeatureMap $script:featureMap
        $script:result = Measure-ValueOpportunity -LicenseUtilization $script:license -FeatureAdoption $script:adoption -FeatureReadiness $script:readiness -FeatureMap $script:featureMap
    }

    AfterAll {
        if (Test-Path $script:tempDir) {
            Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should detect licensed features based on tenant service plans' {
        $script:result.LicensedFeatureCount | Should -BeGreaterThan 0
    }

    It 'Should have non-zero adoption when signals exist' {
        ($script:result.AdoptedFeatureCount + $script:result.PartialFeatureCount) | Should -BeGreaterThan 0
    }

    It 'Should produce category breakdown' {
        $script:result.CategoryBreakdown.Count | Should -BeGreaterThan 0
    }

    It 'Should have a valid overall adoption percentage' {
        $script:result.OverallAdoptionPct | Should -BeGreaterOrEqual 0
        $script:result.OverallAdoptionPct | Should -BeLessOrEqual 100
    }

    It 'Should identify not-licensed features for plans the tenant lacks' {
        $script:result.NotLicensedFeatures.Count | Should -BeGreaterThan 0
    }

    It 'Should produce roadmap entries for gaps' {
        $totalRoadmap = ($script:result.Roadmap['Quick Win'].Count + $script:result.Roadmap['Medium'].Count + $script:result.Roadmap['Strategic'].Count)
        $totalRoadmap | Should -BeGreaterThan 0
    }
}
