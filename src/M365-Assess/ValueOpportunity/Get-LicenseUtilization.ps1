<#
.SYNOPSIS
    Collects license assignment and utilization data across the tenant.
.DESCRIPTION
    Queries assigned vs. available license counts for each SKU and cross-references
    active usage signals to identify unused or underutilized seat allocations.
    Results are stored in the assessment security-config store for use by the
    Analyze-ValueOpportunity engine.

    Requires: Graph (Organization.Read.All)
.PARAMETER SecurityConfig
    The assessment security-config hashtable produced by Initialize-SecurityConfig.
.PARAMETER AdoptionAccumulator
    Optional hashtable accumulating adoption signals from preceding collectors.
.EXAMPLE
    PS> .\ValueOpportunity\Get-LicenseUtilization.ps1 -SecurityConfig $config
    Collects license utilization for the connected tenant.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [hashtable]$SecurityConfig,

    [Parameter()]
    [hashtable]$AdoptionAccumulator
)

# Implementation provided by Task 4 (Get-LicenseUtilization collector)
Write-Verbose 'Get-LicenseUtilization: collector not yet implemented.'
