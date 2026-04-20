BeforeDiscovery {
    # Nothing needed at discovery time
}

Describe 'Build-DriftHtml' {
    BeforeAll {
        . "$PSScriptRoot/../../src/M365-Assess/Common/Build-DriftHtml.ps1"
    }

    Context 'when DriftReport is empty' {
        It 'should include the no-changes message' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Q1-2026'
            $result | Should -Match 'No changes detected'
        }

        It 'should include the baseline label in the no-changes message' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Q1-2026'
            $result | Should -Match 'Q1-2026'
        }

        It 'should not render the changes table' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Q1-2026'
            $result | Should -Not -Match 'drift-table'
        }
    }

    Context 'when DriftReport has a Regressed change' {
        BeforeAll {
            $script:regressed = [PSCustomObject]@{
                CheckId        = 'ENTRA-MFA-001'
                Setting        = 'MFA Required'
                Section        = 'Identity'
                ChangeType     = 'Regressed'
                PreviousStatus = 'Pass'
                CurrentStatus  = 'Fail'
                PreviousValue  = 'Enabled'
                CurrentValue   = 'Disabled'
            }
            $script:resultRegressed = Build-DriftHtml -DriftReport @($script:regressed) -BaselineLabel 'Q1-2026'
        }

        It 'should include the drift-stat-regressed stat tile' {
            $script:resultRegressed | Should -Match 'drift-stat-regressed'
        }

        It 'should include a drift-row-regressed table row' {
            $script:resultRegressed | Should -Match 'drift-row-regressed'
        }

        It 'should include the Setting name in the table' {
            $script:resultRegressed | Should -Match 'MFA Required'
        }

        It 'should include previous and current status badges' {
            $script:resultRegressed | Should -Match 'Pass'
            $script:resultRegressed | Should -Match 'Fail'
        }
    }

    Context 'when DriftReport has an Improved change' {
        BeforeAll {
            $script:improved = [PSCustomObject]@{
                CheckId        = 'ENTRA-001'
                Setting        = 'MFA for Admins'
                Section        = 'Identity'
                ChangeType     = 'Improved'
                PreviousStatus = 'Fail'
                CurrentStatus  = 'Pass'
                PreviousValue  = 'Disabled'
                CurrentValue   = 'Enabled'
            }
            $script:resultImproved = Build-DriftHtml -DriftReport @($script:improved) -BaselineLabel 'Q1-2026'
        }

        It 'should include the drift-stat-improved stat tile' {
            $script:resultImproved | Should -Match 'drift-stat-improved'
        }

        It 'should include a drift-row-improved table row' {
            $script:resultImproved | Should -Match 'drift-row-improved'
        }
    }

    Context 'sort order: Regressed renders before Improved' {
        BeforeAll {
            $script:mixed = @(
                [PSCustomObject]@{ CheckId = 'A'; Setting = 'Alpha'; Section = 'Sec'; ChangeType = 'Improved';  PreviousStatus = 'Fail'; CurrentStatus = 'Pass'; PreviousValue = ''; CurrentValue = '' }
                [PSCustomObject]@{ CheckId = 'B'; Setting = 'Beta';  Section = 'Sec'; ChangeType = 'Regressed'; PreviousStatus = 'Pass'; CurrentStatus = 'Fail'; PreviousValue = ''; CurrentValue = '' }
            )
            $script:resultMixed = Build-DriftHtml -DriftReport $script:mixed -BaselineLabel 'Q1'
        }

        It 'should render Regressed rows before Improved rows' {
            $regressPos = $script:resultMixed.IndexOf('drift-row-regressed')
            $improvePos = $script:resultMixed.IndexOf('drift-row-improved')
            $regressPos | Should -BeLessThan $improvePos
        }
    }

    Context 'when BaselineLabel contains HTML special characters' {
        It 'should HTML-encode the label' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel '<script>xss</script>'
            $result | Should -Not -Match '<script>'
            $result | Should -Match '&lt;script&gt;'
        }
    }

    Context 'when BaselineTimestamp is provided' {
        It 'should include the formatted date in the header' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Q1' -BaselineTimestamp '2026-01-15T10:30:00Z'
            $result | Should -Match '2026-01-15'
        }
    }

    Context 'when status is unchanged but value changed (Modified)' {
        BeforeAll {
            $script:valueChanged = [PSCustomObject]@{
                CheckId        = 'EXO-001'
                Setting        = 'Audit Retention'
                Section        = 'Exchange'
                ChangeType     = 'Modified'
                PreviousStatus = 'Pass'
                CurrentStatus  = 'Pass'
                PreviousValue  = '90 days'
                CurrentValue   = '180 days'
            }
            $script:resultValue = Build-DriftHtml -DriftReport @($script:valueChanged) -BaselineLabel 'Q1'
        }

        It 'should use drift-value cells instead of status badges' {
            $script:resultValue | Should -Match 'drift-value'
        }

        It 'should display both the previous and current values' {
            $script:resultValue | Should -Match '90 days'
            $script:resultValue | Should -Match '180 days'
        }
    }

    Context 'output structure' {
        It 'should return a string' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Test'
            $result | Should -BeOfType [string]
        }

        It 'should wrap output in the drift-analysis report-page div' {
            $result = Build-DriftHtml -DriftReport @() -BaselineLabel 'Test'
            $result | Should -Match "data-page='drift-analysis'"
        }
    }
}
