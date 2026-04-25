<#
.SYNOPSIS
    Verifies M365-Assess collector folders contain no tenant-mutating cmdlet calls.
.DESCRIPTION
    M365-Assess promises strictly read-only operation against the target tenant.
    This script enforces that promise by AST-scanning collector folders for
    cmdlets whose verbs suggest mutation, plus Invoke-MgGraphRequest calls using
    non-GET methods.

    Allowlist below carves out cmdlets that match a forbidden verb but operate
    locally (Add-Member for PSObject shaping, New-Object for .NET types, etc.)
    and the collector contract (Add-Setting, Add-SecuritySetting). Add new
    entries with a one-line justification.

    Setup/ and Common/ folders are intentionally excluded -- they host the
    consent helpers and shared utilities, which may legitimately mutate state.
.PARAMETER RepoRoot
    Repository root. Defaults to the parent of the script's directory.
.PARAMETER Path
    Optional list of paths (files or folders) to scan instead of the default
    collector folders. Used by tests to verify the script catches deliberate
    violations.
.EXAMPLE
    PS> ./scripts/Test-CollectorReadOnly.ps1
    Scans the default collector folders. Prints violations and exits 1, or
    prints a green confirmation and exits 0.
.EXAMPLE
    PS> ./scripts/Test-CollectorReadOnly.ps1 -Path ./tests/Fixtures/violator.ps1
    Scans a specific file (used by tests).
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSCommandPath)),

    [Parameter()]
    [string[]]$Path
)

function Test-CollectorReadOnly {
    [CmdletBinding()]
    [OutputType([psobject[]])]
    param(
        [Parameter()]
        [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSCommandPath)),

        [Parameter()]
        [string[]]$Path
    )

    # Forbidden cmdlet verbs -- any cmdlet whose verb matches one of these is a
    # violation unless the full cmdlet name appears in $allowedCmdlets below.
    $forbiddenVerbs = @(
        'Set', 'New', 'Remove', 'Update',
        'Grant', 'Revoke', 'Disable', 'Enable', 'Add'
    )

    # Cmdlets whose name starts with a forbidden verb but do not mutate the
    # M365 tenant. Keep narrow; document each entry.
    $allowedCmdlets = @(
        'Add-Setting'                  # collector contract -- emits a finding
        'Add-SecuritySetting'          # collector contract -- emits a finding
        'Add-Member'                   # local PSObject shaping
        'Add-Type'                     # in-process .NET type loading
        'Add-Content'                  # local file write (output paths)
        'New-Object'                   # local .NET object instantiation
        'New-TimeSpan'                 # local timespan construction
        'New-Guid'                     # local guid generation
        'New-Variable'                 # local PS variable
        'New-PSSession'                # local PS remoting (EXO transport)
        'New-PesterConfiguration'      # test config (test scripts only)
        'New-Item'                     # local file/folder creation (output)
        'New-CimSession'               # local Windows CIM/WMI session (Get-LocalAdmins)
        'Remove-CimSession'            # local Windows CIM/WMI session cleanup
        'Remove-Item'                  # local file/temp-file cleanup
        'Remove-Variable'              # local PS variable
        'Set-Variable'                 # local PS variable
        'Set-StrictMode'               # local PS strict mode
        'Set-Location'                 # local working directory
        'Set-Content'                  # local file write (output)
        'Set-Item'                     # local file/registry/env write
        'Update-TypeData'              # local PS type metadata
        'Update-CheckProgress'         # project-internal progress callback (Common/Show-CheckProgress.ps1)
        'Enable-PSBreakpoint'          # local debug
        'Disable-PSBreakpoint'         # local debug
    )

    $forbiddenGraphMethods = @('POST', 'PATCH', 'DELETE', 'PUT')

    # Collector folders relative to repo root. SharePoint work lives in
    # Collaboration; there is no top-level SharePoint folder.
    $defaultCollectorFolders = @(
        'src/M365-Assess/Entra'
        'src/M365-Assess/Security'
        'src/M365-Assess/Exchange-Online'
        'src/M365-Assess/Purview'
        'src/M365-Assess/Intune'
        'src/M365-Assess/PowerBI'
        'src/M365-Assess/Collaboration'
        'src/M365-Assess/ActiveDirectory'
        'src/M365-Assess/Inventory'
    )

    if ($Path) {
        $scanPaths = $Path
    }
    else {
        $scanPaths = $defaultCollectorFolders | ForEach-Object {
            Join-Path -Path $RepoRoot -ChildPath $_
        }
    }

    $files = New-Object -TypeName System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($p in $scanPaths) {
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            $files.Add((Get-Item -LiteralPath $p))
        }
        elseif (Test-Path -LiteralPath $p -PathType Container) {
            $found = Get-ChildItem -LiteralPath $p -Recurse -Filter '*.ps1' -File
            foreach ($f in $found) { $files.Add($f) }
        }
        else {
            Write-Warning "Path not found: $p"
        }
    }

    $violations = New-Object -TypeName System.Collections.Generic.List[psobject]

    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors
        )
        if ($errors -and $errors.Count -gt 0) {
            Write-Warning "Parse errors in $($file.FullName): $($errors[0].Message)"
            continue
        }

        $commands = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true)

        foreach ($cmd in $commands) {
            $nameElement = $cmd.CommandElements[0]
            if ($nameElement -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
                continue
            }
            $name = $nameElement.Value

            # Forbidden-verb match
            if ($name -match '^([A-Z][a-z]+)-[A-Z][a-zA-Z]+$') {
                $verb = $Matches[1]
                if ($forbiddenVerbs -contains $verb -and $allowedCmdlets -notcontains $name) {
                    $violations.Add([pscustomobject]@{
                            File   = $file.FullName
                            Line   = $cmd.Extent.StartLineNumber
                            Column = $cmd.Extent.StartColumnNumber
                            Cmdlet = $name
                            Reason = "Mutating verb '$verb-' not in allowlist"
                        })
                    continue
                }
            }

            # Special case: Invoke-MgGraphRequest -Method <forbidden>
            if ($name -eq 'Invoke-MgGraphRequest') {
                $methodValue = $null
                $elements = $cmd.CommandElements
                for ($i = 1; $i -lt $elements.Count - 1; $i++) {
                    $el = $elements[$i]
                    if ($el -is [System.Management.Automation.Language.CommandParameterAst] `
                            -and $el.ParameterName -ieq 'Method') {
                        $next = $elements[$i + 1]
                        if ($next -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                            $methodValue = $next.Value
                        }
                        break
                    }
                }
                if ($methodValue -and $forbiddenGraphMethods -contains $methodValue.ToUpperInvariant()) {
                    $violations.Add([pscustomobject]@{
                            File   = $file.FullName
                            Line   = $cmd.Extent.StartLineNumber
                            Column = $cmd.Extent.StartColumnNumber
                            Cmdlet = "$name -Method $methodValue"
                            Reason = "Tenant-mutating Graph method"
                        })
                }
            }
        }
    }

    return $violations.ToArray()
}

# Script-level invocation. When dot-sourced (Pester tests), the function is
# registered but the wrapper below is skipped.
if ($MyInvocation.InvocationName -ne '.') {
    $params = @{}
    if ($PSBoundParameters.ContainsKey('RepoRoot')) { $params.RepoRoot = $RepoRoot }
    if ($PSBoundParameters.ContainsKey('Path'))     { $params.Path     = $Path }

    $result = Test-CollectorReadOnly @params

    if ($null -eq $result -or $result.Count -eq 0) {
        Write-Host '[Test-CollectorReadOnly] Clean -- no mutating cmdlet calls found in collector folders.' -ForegroundColor Green
        exit 0
    }

    Write-Host "[Test-CollectorReadOnly] $($result.Count) violation(s) found:" -ForegroundColor Red
    $rootForRel = if ($PSBoundParameters.ContainsKey('RepoRoot')) { $RepoRoot } else { (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
    foreach ($v in $result) {
        $relativeFile = $v.File.Replace($rootForRel, '').TrimStart('\', '/')
        Write-Host ("  {0}:{1}:{2}  {3}  -- {4}" -f $relativeFile, $v.Line, $v.Column, $v.Cmdlet, $v.Reason) -ForegroundColor Yellow
    }
    exit 1
}
