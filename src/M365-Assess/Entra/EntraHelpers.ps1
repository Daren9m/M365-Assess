# -------------------------------------------------------------------
# Entra ID -- Helper Functions
# Extracted from Get-EntraSecurityConfig.ps1 (#256)
# -------------------------------------------------------------------
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# Helper to detect emergency access (break-glass) accounts by naming convention
function Get-BreakGlassAccounts {
    [CmdletBinding()]
    param([array]$Users)
    $patterns = @('break.?glass', 'emergency.?access', 'breakglass', 'emer.?admin')
    $regex = ($patterns | ForEach-Object { "($_)" }) -join '|'
    @($Users | Where-Object {
        $_['displayName'] -match $regex -or $_['userPrincipalName'] -match $regex
    })
}
