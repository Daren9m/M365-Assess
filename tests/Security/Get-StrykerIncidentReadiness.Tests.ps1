BeforeDiscovery {
    # Nothing needed at discovery time
}

Describe 'Get-StrykerIncidentReadiness' {
    BeforeAll {
        . "$PSScriptRoot/../../src/M365-Assess/Orchestrator/AssessmentHelpers.ps1"

        function Get-MgContext { return @{ TenantId = 'test-tenant-id'; AuthType = 'Delegated' } }
        function global:Update-CheckProgress { param($CheckId, $Setting, $Status) }

        Mock Import-Module { }

        # Mock Graph calls for admin role checks
        Mock Get-MgDirectoryRole {
            return @(
                [PSCustomObject]@{ Id = 'ga-role-id'; DisplayName = 'Global Administrator'; RoleTemplateId = '62e90394-69f5-4237-9190-012177145e10' }
            )
        }
        Mock Get-MgDirectoryRoleMemberAsUser {
            return @(
                [PSCustomObject]@{
                    Id                = 'user-1'
                    DisplayName       = 'Admin One'
                    UserPrincipalName = 'admin1@contoso.com'
                    SignInActivity    = @{
                        LastSignInDateTime                = (Get-Date).AddDays(-10)
                        LastNonInteractiveSignInDateTime   = (Get-Date).AddDays(-5)
                    }
                    OnPremisesSyncEnabled = $false
                }
            )
        }

        # Mock CA policies
        Mock Get-MgIdentityConditionalAccessPolicy {
            return @(
                [PSCustomObject]@{
                    DisplayName   = 'Require MFA for admins'
                    State         = 'enabled'
                    Conditions    = @{
                        Users = @{
                            IncludeRoles    = @('62e90394-69f5-4237-9190-012177145e10')
                            ExcludeUsers    = @()
                            ExcludeGroups   = @()
                        }
                    }
                    GrantControls = @{
                        BuiltInControls        = @('mfa')
                        AuthenticationStrength = $null
                    }
                }
            )
        }

        # Mock Intune checks
        Mock Invoke-MgGraphRequest { return @{ value = @() } }

        # Mock service principal check
        Mock Get-MgServicePrincipal { return @() }

        . "$PSScriptRoot/../../src/M365-Assess/Security/Get-StrykerIncidentReadiness.ps1"
    }

    It 'Should produce a non-empty settings list' {
        $settings.Count | Should -BeGreaterThan 0
    }

    It 'Should have required properties on all settings' {
        foreach ($s in $settings) {
            $s.PSObject.Properties.Name | Should -Contain 'Category'
            $s.PSObject.Properties.Name | Should -Contain 'Setting'
            $s.PSObject.Properties.Name | Should -Contain 'Status'
        }
    }

    It 'Should include Stale Admin Detection category' {
        $categories = $settings | Select-Object -ExpandProperty Category -Unique
        $categories | Should -Contain 'Stale Admin Detection'
    }

    AfterAll {
        Remove-Item Function:\Update-CheckProgress -ErrorAction SilentlyContinue
    }
}
