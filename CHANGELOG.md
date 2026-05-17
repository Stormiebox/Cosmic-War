# Changelog

## [1.0.2] - 2026-05-17

### Fixed
- Fixed `/cosmicwarstatus` incorrectly returning `"Galaxy API not ready"` in stable server runtime.
- Removed reliance on invalid `Galaxy():getFactions()` checks in affected scripts.

### Changed
- Standardized Cosmic War faction enumeration to:
  - `Server():getValue("factions")`
  - `Faction(index)` resolution
- Applied command/runtime hardening in `data/scripts/commands/cosmicwarstatus.lua`:
  - Added cached server runtime usage (`local now = server.unpausedRuntime or 0`) for bounty expiry comparisons.

### Script Coverage Updated
- `data/scripts/commands/cosmicwarstatus.lua`
- `data/scripts/server/background/cosmicwarbounties.lua`
- `data/scripts/server/background/cosmicwarceasefires.lua`
- `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`
- `data/scripts/server/background/cosmicwarnews.lua`
- `data/scripts/lib/cosmicwarbridge.lua`

### Notes
- This release is a patch-level stability/compatibility update.
- Versioning remains **1.0.2** (no major or minor feature expansion in this cycle).
