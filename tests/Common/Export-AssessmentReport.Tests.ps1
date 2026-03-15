Describe 'Export-AssessmentReport HTML structure' {
    BeforeAll {
        # Read the raw script source to verify embedded HTML/CSS/JS patterns.
        # Full execution requires a live assessment folder with CSV data, so we
        # verify the template strings are present in the script source instead.
        $scriptPath = "$PSScriptRoot/../../Common/Export-AssessmentReport.ps1"
        $html = Get-Content -Path $scriptPath -Raw
    }

    Context 'Expand/Collapse All buttons' {
        It 'Should include expand/collapse buttons in section panels' {
            $html | Should -Match 'expand-all-btn'
            $html | Should -Match 'collapse-all-btn'
            $html | Should -Match 'collector-detail'
        }

        It 'Should render expand/collapse buttons only for sections with multiple collectors' {
            $html | Should -Match "sectionCollectors\.Count -gt 1"
        }

        It 'Should include matrix-controls CSS class' {
            $html | Should -Match 'matrix-controls'
        }

        It 'Should hide matrix-controls in print media' {
            # Verify the print media block suppresses the buttons
            $html | Should -Match '\.matrix-controls \{ display: none; \}'
        }

        It 'Should wire expand button to open collector-detail panels in parent section' {
            $html | Should -Match "expand-all-btn"
            $html | Should -Match "d\.open = true"
        }

        It 'Should wire collapse button to close collector-detail panels in parent section' {
            $html | Should -Match "collapse-all-btn"
            $html | Should -Match "d\.open = false"
        }

        It 'Should use btn.closest to scope to parent section' {
            $html | Should -Match "btn\.closest\('\.section'\)"
        }
    }
}
