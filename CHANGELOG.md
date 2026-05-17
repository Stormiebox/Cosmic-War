# Changelog

## [1.0.2] - 2026-05-17

### Fixed
- Resolved `/cosmicwarstatus` always returning `"Galaxy API not ready"` by removing invalid `Galaxy():getFactions()` dependency.
- Updated faction enumeration to use server-side faction index storage:
  - `Server():getValue("factions")`
  - `Faction(index)` resolution

### Changed
- Applied runtime hardening in `data/scripts/commands/cosmicwarstatus.lua`:
  - Cached runtime timestamp via `local now = server.unpausedRuntime or 0`
  - Reused cached timestamp for active bounty expiry checks.

### Compatibility Hardening
- Standardized faction collection across affected Cosmic War background scripts to avoid `galaxy.getFactions` reliance:
  - `data/scripts/server/background/cosmicwarbounties.lua`
  - `data/scripts/server/background/cosmicwarceasefires.lua`
  - `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`
  - `data/scripts/server/background/cosmicwarnews.lua`

### Notes
- This is a patch-level stability update focused on API correctness and runtime resilience.
