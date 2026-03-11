# Compliance Overview XLSX Export

> **Date**: 2026-03-11
> **Scope**: New script to export compliance matrix data as a formatted XLSX file

## Overview

Add `Common/Export-ComplianceMatrix.ps1` that generates a two-sheet XLSX file from assessment results, providing the compliance overview data in a format suitable for sharing with clients, auditors, and management.

## Architecture

### New File

`Common/Export-ComplianceMatrix.ps1` — standalone script, also callable from the report generator.

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `AssessmentFolder` | string | Yes | Path to the assessment output folder |
| `TenantName` | string | No | Tenant name for the output filename |

### Sheet 1 — Compliance Matrix

One row per automated check with columns:

- **CheckId** — Framework-agnostic identifier (e.g., ENTRA-ADMIN-001)
- **Setting** — What was checked
- **Category** — Setting category
- **Status** — Pass / Fail / Warning / Review
- **Source** — Collector name (Entra, ExchangeOnline, Defender, SharePoint, Teams)
- **Remediation** — Remediation guidance text
- **CIS E3-L1, CIS E3-L2, CIS E5-L1, CIS E5-L2** — CIS control ID if check belongs to that profile
- **NIST 800-53, NIST CSF, ISO 27001, STIG, PCI DSS, CMMC, HIPAA, CISA SCuBA, SOC 2** — Framework control IDs from registry

Sorted by CheckId. Auto-filter enabled on all columns.

### Sheet 2 — Summary

One row per framework showing:

| Column | Description |
|--------|-------------|
| Framework | Display name (e.g., "NIST 800-53 Rev 5") |
| Total Mapped | Number of checks that map to this framework |
| Pass | Count of passing checks |
| Fail | Count of failing checks |
| Warning | Count of warning checks |
| Review | Count of review checks |
| Pass Rate % | Pass / Total Mapped as percentage |

### Dependency Handling

- Requires the `ImportExcel` PowerShell module (no Excel installation needed)
- If `ImportExcel` is not available: log a warning and return without error
- No attempt to auto-install — just skip gracefully

### Integration Points

**Standalone usage:**
```powershell
.\Common\Export-ComplianceMatrix.ps1 -AssessmentFolder .\M365-Assessment\Assessment_20260311_033912_dzmlab
```

**Auto-called from report generator:**
- `Export-AssessmentReport.ps1` calls `Export-ComplianceMatrix.ps1` after building the compliance HTML
- Passes `$AssessmentFolder` and `$TenantName`
- Wrapped in try/catch so XLSX failure never blocks the HTML report

### Output

`_Compliance-Matrix_{tenant}.xlsx` saved in the assessment output folder alongside the HTML report.

### Data Flow

1. Script loads control registry via `Import-ControlRegistry.ps1`
2. Scans assessment folder for security config CSVs (files with CheckId + Status columns)
3. For each row with a non-empty CheckId, looks up registry entry for framework mappings
4. Builds finding objects with all framework columns
5. Exports Sheet 1 (matrix) and Sheet 2 (summary) via ImportExcel
