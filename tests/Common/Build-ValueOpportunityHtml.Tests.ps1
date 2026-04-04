BeforeAll {
    . "$PSScriptRoot/../../src/M365-Assess/Common/Build-ValueOpportunityHtml.ps1"

    # Stub Get-SvgDonut if not already loaded
    if (-not (Get-Command -Name Get-SvgDonut -ErrorAction SilentlyContinue)) {
        function Get-SvgDonut { param($Percentage, $CssClass, $Size, $StrokeWidth) return "<svg class='donut-stub'>$Percentage%</svg>" }
    }
    # Stub ConvertTo-HtmlSafe if not already loaded
    if (-not (Get-Command -Name ConvertTo-HtmlSafe -ErrorAction SilentlyContinue)) {
        function ConvertTo-HtmlSafe { param([string]$Text) return [System.Net.WebUtility]::HtmlEncode($Text) }
    }
}

Describe 'Build-ValueOpportunityHtml' {

    Context 'when given a mixed adoption analysis' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 67
                LicensedFeatureCount = 3
                AdoptedFeatureCount  = 1
                PartialFeatureCount  = 1
                GapCount             = 1
                CategoryBreakdown    = @(
                    @{ Category = 'Identity & Access'; Licensed = 2; Adopted = 1; Partial = 0; NotAdopted = 1; Unknown = 0; Pct = 50 }
                    @{ Category = 'Email Security';    Licensed = 1; Adopted = 0; Partial = 1; NotAdopted = 0; Unknown = 0; Pct = 100 }
                )
                Roadmap = @{
                    'Quick Win' = @(
                        [PSCustomObject]@{ FeatureId = 'f2'; FeatureName = 'Block Legacy Auth'; Category = 'Identity & Access'; AdoptionScore = 0; ReadinessState = 'Ready'; Blockers = ''; EffortTier = 'Quick Win'; LearnUrl = 'https://learn.microsoft.com/test' }
                    )
                    'Medium'    = @()
                    'Strategic' = @()
                }
                GapMatrix           = @(
                    @{ Category = 'Identity & Access'; Adopted = 1; Partial = 0; NotAdopted = 1; Unknown = 0 }
                )
                NotLicensedFeatures = @()
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should return a non-empty HTML string' {
            $script:html | Should -Not -BeNullOrEmpty
        }

        It 'Should wrap content in a section details element' {
            $script:html | Should -Match "class='section'"
        }

        It 'Should include the Value Opportunity heading' {
            $script:html | Should -Match 'Value Opportunity'
        }

        It 'Should include the adoption donut via stub' {
            $script:html | Should -Match 'donut-stub'
        }

        It 'Should embed the overall adoption percentage in the donut' {
            $script:html | Should -Match '67%'
        }

        It 'Should include the Licensed Features stat card label' {
            $script:html | Should -Match 'Licensed Features'
        }

        It 'Should include the correct licensed feature count' {
            $script:html | Should -Match "value-stat-value'>3"
        }

        It 'Should include the correct adopted count (adopted + partial)' {
            # AdoptedFeatureCount(1) + PartialFeatureCount(1) = 2
            $script:html | Should -Match "value-stat-value'>2"
        }

        It 'Should include the correct gap count' {
            # GapCount = 1
            $script:html | Should -Match "value-stat-value'>1"
        }

        It 'Should include the hero summary sentence' {
            $script:html | Should -Match 'uses 2 of 3 licensed features \(67%\)'
        }

        It 'Should include the Category Breakdown heading' {
            $script:html | Should -Match 'Category Breakdown'
        }

        It 'Should include category row elements' {
            $script:html | Should -Match "class='value-category-row'"
        }

        It 'Should HTML-encode ampersands in category names' {
            $script:html | Should -Match 'Identity &amp; Access'
        }

        It 'Should include the quick wins callout' {
            $script:html | Should -Match 'Quick Wins'
        }

        It 'Should include the quick wins feature name in the table' {
            $script:html | Should -Match 'Block Legacy Auth'
        }

        It 'Should include the Adoption Roadmap heading' {
            $script:html | Should -Match 'Adoption Roadmap'
        }

        It 'Should include a roadmap tier summary with count' {
            $script:html | Should -Match 'Quick Wins \(1\)'
        }

        It 'Should not include the Not Licensed section when no unlicensed features exist' {
            $script:html | Should -Not -Match 'Not Licensed'
        }
    }

    Context 'when adoption is 0% with all gaps' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 0
                LicensedFeatureCount = 2
                AdoptedFeatureCount  = 0
                PartialFeatureCount  = 0
                GapCount             = 2
                CategoryBreakdown    = @(
                    @{ Category = 'Identity'; Licensed = 2; Adopted = 0; Partial = 0; NotAdopted = 2; Unknown = 0; Pct = 0 }
                )
                Roadmap = @{
                    'Quick Win' = @(
                        [PSCustomObject]@{ FeatureId = 'f1'; FeatureName = 'MFA'; Category = 'Identity'; AdoptionScore = 0; ReadinessState = 'Ready'; Blockers = ''; EffortTier = 'Quick Win'; LearnUrl = 'https://test' }
                        [PSCustomObject]@{ FeatureId = 'f2'; FeatureName = 'CA Policy'; Category = 'Identity'; AdoptionScore = 0; ReadinessState = 'Ready'; Blockers = ''; EffortTier = 'Quick Win'; LearnUrl = 'https://test' }
                    )
                    'Medium'    = @()
                    'Strategic' = @()
                }
                GapMatrix           = @()
                NotLicensedFeatures = @()
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should show 0% in the donut' {
            $script:html | Should -Match '0%'
        }

        It 'Should show 0 adopted in the hero summary' {
            $script:html | Should -Match 'uses 0 of 2 licensed features \(0%\)'
        }

        It 'Should show the roadmap tier with the correct item count' {
            $script:html | Should -Match 'Quick Wins \(2\)'
        }

        It 'Should list both feature names in the roadmap' {
            $script:html | Should -Match 'MFA'
            $script:html | Should -Match 'CA Policy'
        }
    }

    Context 'when adoption is 100% with no gaps' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 100
                LicensedFeatureCount = 1
                AdoptedFeatureCount  = 1
                PartialFeatureCount  = 0
                GapCount             = 0
                CategoryBreakdown    = @(
                    @{ Category = 'Identity'; Licensed = 1; Adopted = 1; Partial = 0; NotAdopted = 0; Unknown = 0; Pct = 100 }
                )
                Roadmap = @{ 'Quick Win' = @(); 'Medium' = @(); 'Strategic' = @() }
                GapMatrix           = @()
                NotLicensedFeatures = @()
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should show 100% in the donut' {
            $script:html | Should -Match '100%'
        }

        It 'Should not include the Adoption Roadmap heading when roadmap is empty' {
            $script:html | Should -Not -Match 'Adoption Roadmap'
        }

        It 'Should not include the quick wins callout when no quick wins exist' {
            # Quick Wins callout references callout-tip class
            $script:html | Should -Not -Match 'callout-tip'
        }
    }

    Context 'when not-licensed features exist' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 100
                LicensedFeatureCount = 1
                AdoptedFeatureCount  = 1
                PartialFeatureCount  = 0
                GapCount             = 0
                CategoryBreakdown    = @(
                    @{ Category = 'Identity'; Licensed = 1; Adopted = 1; Partial = 0; NotAdopted = 0; Unknown = 0; Pct = 100 }
                )
                Roadmap = @{ 'Quick Win' = @(); 'Medium' = @(); 'Strategic' = @() }
                GapMatrix           = @()
                NotLicensedFeatures = @(
                    [PSCustomObject]@{ FeatureId = 'f99'; FeatureName = 'Premium Feature'; Category = 'Security'; EffortTier = 'Medium'; RequiredServicePlans = @('ATP_ENTERPRISE') }
                )
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should include the Not Licensed section heading' {
            $script:html | Should -Match 'Not Licensed'
        }

        It 'Should include the feature count in the Not Licensed heading' {
            $script:html | Should -Match 'Not Licensed \(1 features\)'
        }

        It 'Should list the premium feature name' {
            $script:html | Should -Match 'Premium Feature'
        }

        It 'Should list the required service plan' {
            $script:html | Should -Match 'ATP_ENTERPRISE'
        }

        It 'Should include the Upsell Opportunities callout' {
            $script:html | Should -Match 'Upsell Opportunities'
        }
    }

    Context 'when roadmap contains medium and strategic tiers' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 33
                LicensedFeatureCount = 3
                AdoptedFeatureCount  = 1
                PartialFeatureCount  = 0
                GapCount             = 2
                CategoryBreakdown    = @()
                Roadmap = @{
                    'Quick Win' = @()
                    'Medium'    = @(
                        [PSCustomObject]@{ FeatureId = 'm1'; FeatureName = 'SSPR'; Category = 'Identity'; AdoptionScore = 10; ReadinessState = 'Partial'; Blockers = 'License'; EffortTier = 'Medium'; LearnUrl = '' }
                    )
                    'Strategic' = @(
                        [PSCustomObject]@{ FeatureId = 's1'; FeatureName = 'PIM'; Category = 'Identity'; AdoptionScore = 5; ReadinessState = 'NotReady'; Blockers = 'P2 required'; EffortTier = 'Strategic'; LearnUrl = '' }
                    )
                }
                GapMatrix           = @()
                NotLicensedFeatures = @()
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should include Medium Effort tier in roadmap' {
            $script:html | Should -Match 'Medium Effort \(1\)'
        }

        It 'Should include Strategic tier in roadmap' {
            $script:html | Should -Match 'Strategic \(1\)'
        }

        It 'Should include feature names for each tier' {
            $script:html | Should -Match 'SSPR'
            $script:html | Should -Match 'PIM'
        }

        It 'Should include blockers in roadmap rows' {
            $script:html | Should -Match 'P2 required'
        }

        It 'Should not include Quick Wins tier when it is empty' {
            $script:html | Should -Not -Match 'Quick Wins \('
        }
    }

    Context 'when a quick wins feature has no LearnUrl' {
        BeforeAll {
            $script:analysis = @{
                OverallAdoptionPct   = 0
                LicensedFeatureCount = 1
                AdoptedFeatureCount  = 0
                PartialFeatureCount  = 0
                GapCount             = 1
                CategoryBreakdown    = @()
                Roadmap = @{
                    'Quick Win' = @(
                        [PSCustomObject]@{ FeatureId = 'f1'; FeatureName = 'No Link Feature'; Category = 'Identity'; AdoptionScore = 0; ReadinessState = 'Ready'; Blockers = ''; EffortTier = 'Quick Win'; LearnUrl = '' }
                    )
                    'Medium'    = @()
                    'Strategic' = @()
                }
                GapMatrix           = @()
                NotLicensedFeatures = @()
            }
            $script:html = Build-ValueOpportunityHtml -Analysis $script:analysis
        }

        It 'Should still render the feature row' {
            $script:html | Should -Match 'No Link Feature'
        }

        It 'Should not include a learn-more link when LearnUrl is empty' {
            $script:html | Should -Not -Match 'Learn more'
        }
    }
}
