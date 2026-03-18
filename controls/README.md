# Control Registry

The control registry maps security checks to compliance frameworks. It is a **committed data artifact** consumed from the upstream [CheckID](https://github.com/Galvnyz/CheckID) project.

## Data Flow

```
CheckID repo (source of truth)
  └─ data/registry.json
  └─ data/frameworks/*.json
       │
       ▼  CI fetches from pinned CheckID release tag
M365-Assess repo
  └─ controls/registry.json        ← committed for offline use
  └─ controls/frameworks/*.json    ← committed for offline use
       │
       ▼  loaded at runtime
  Common/Import-ControlRegistry.ps1
```

**Key points:**
- `registry.json` and framework JSONs are committed so `git clone` works offline
- CI compares against the pinned CheckID release and warns if updates are available
- To add or modify controls, make changes in the [CheckID](https://github.com/Galvnyz/CheckID) repo and cut a new release

## Files

| File | Purpose |
|------|---------|
| `registry.json` | 233 security checks with framework mappings (CIS, NIST, SOC 2, ISO, STIG, PCI, CMMC, HIPAA, CISA SCuBA) |
| `frameworks/cis-m365-v6.json` | CIS profile definitions (E3/E5, L1/L2 groupings) |
| `frameworks/nist-800-53-r5.json` | NIST 800-53 Rev 5 control mappings |
| `frameworks/soc2-tsc.json` | SOC 2 Trust Services Criteria mappings |

## Updating Registry Data

1. Update controls in the [CheckID](https://github.com/Galvnyz/CheckID) repo
2. Cut a new CheckID release (e.g., `v1.3.0`)
3. Update the `TAG` variable in `.github/workflows/ci.yml` to the new tag
4. CI will detect the diff and flag it; copy the updated files into a PR

## Runtime Usage

```powershell
# Import-ControlRegistry loads registry.json and framework definitions
. ./Common/Import-ControlRegistry.ps1
$lookup = Import-ControlRegistry -ControlsPath ./controls
$lookup['ENTRA-MFA-001']  # Returns check metadata with framework mappings
```
