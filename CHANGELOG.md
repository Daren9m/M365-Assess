# Changelog

All notable changes to M365 Assess are documented here. This project uses [Conventional Commits](https://www.conventionalcommits.org/).

## [0.8.0] - 2026-03-14

### Added
- Conditional Access policy evaluator collector with 12 CIS 5.2.2.x checks
- 14 Entra/PIM automated CIS checks (identity settings + PIM license-gated)
- DNS security collector with SPF/DKIM/DMARC validation
- Intune security collector (compliance policy + enrollment restrictions)
- 6 Defender and EXO email security checks
- 8 org settings checks (user consent, Forms phishing, third-party storage, Bookings)
- 3 SharePoint/OneDrive checks (B2B integration, external sharing, malware blocking)
- 2 Teams review checks (third-party apps, reporting)
- Report screenshots in README (cover page, executive summary, security dashboard, compliance overview)
- Updated sample report to v0.8.0 with PII-scrubbed Contoso data

### Changed
- Registry expanded to 227 entries with 132 automated checks across 13 frameworks
- Progress display updated to include Intune collector
- 11 manual checks superseded by new automated equivalents

## [0.7.0] - 2026-03-12

### Added
- 8 automated Teams CIS checks (zero new API calls)
- 8 automated Entra/SharePoint CIS checks (2 new API calls)
- Compliance collector with 4 automated Purview CIS checks
- 5 automated EXO/Defender CIS checks
- Expanded automated CIS controls to 82 (55% coverage)

### Fixed
- Handle null `Get-AdminAuditLogConfig` response in Compliance collector

## [0.6.0] - 2026-03-11

### Added
- Multi-framework security scanner with SOC 2 support (13 frameworks total)
- XLSX compliance matrix export (requires ImportExcel module)
- Standardized collector output with CheckId sub-numbering and Info status
- `-SkipDLP` parameter to skip Purview connection

### Changed
- Report UX overhaul: NoBranding switch, donut chart fixes, Teams license skip
- App Registration provisioning scripts moved to `Setup/`
- README restructured into focused documentation files

### Fixed
- Detect missing modules based on selected sections
- Validate wizard output folder to reject UPN and invalid paths

## [0.5.0] - 2026-03-10

### Added
- Security dashboard with Secure Score visualization and Defender controls
- SVG donut charts, horizontal bar charts, and toggle visibility
- Compact chip grid replacing collector status tables

### Changed
- Report UI overhaul with dashboards, hero summary, Inter font
- Restyled Security dashboard to match report layout pattern

### Fixed
- Hybrid sync health shows OFF when sync is disabled
- Dark mode link color readability
- Null-safe compliance policy lookup and ScubaGear error hints

## [0.4.0] - 2026-03-09

### Added
- Light/dark mode with floating toggle, auto-detection, and localStorage persistence
- Connection transparency showing service connection status
- Cloud environment auto-detection (commercial, GCC, GCC High, DoD)
- Device code authentication flow for headless environments
- Tenant-aware output folder naming

### Fixed
- ScubaGear wrong-tenant auth
- Logo visibility in dark mode

## [0.3.0] - 2026-03-08

### Added
- Initial release of M365 Assess
- 8 assessment sections: Tenant, Identity, Licensing, Email, Intune, Security, Collaboration, Hybrid
- Self-contained HTML report with cover page and branding
- CSV export for all collectors
- Interactive wizard for section selection and authentication
- ScubaGear integration for CISA baseline scanning
- Inventory section (opt-in) for M&A due diligence
