# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-05-09
### Added
- Mod Configuration Menu (MCM) schema: `modconfig.lua` (war pressure, diplomacy, diagnostics options).
- Centralized config bridge: `data/scripts/lib/cosmicwarconfig.lua`.
- Server command registration in server init: `/cosmicwarstatus` via `server:addCommand(...)`.
- War & politics background systems:
  - `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`
  - `data/scripts/server/background/cosmicwarceasefires.lua`
  - `data/scripts/server/background/cosmicwarbounties.lua`
- Compatibility and behavior wrappers for related runtime paths:
  - `data/scripts/sector/factionwar/temporarydefender.lua`
  - `data/scripts/sector/background/rebuildstations.lua`

### Changed
- Full QA and code hardening pass across all current Cosmic War runtime scripts.
- Switched Mod Configuration Menu (MCM) from an optional to a required dependency. `modinfo.lua` now strictly requires workshop ID `3674093144` (`min = "1.0.0"`).
- Updated `README.md` to reflect new dependency requirements and the expanded 0.4.0 architecture scope.

## [0.3.0] - 2026-05-02
### Added
- Sector-level Cosmic War controller:
  - `data/scripts/sector/init.lua`
  - `data/scripts/sector/cosmicwarcontroller.lua`
- New runtime war-pressure behavior:
  - Scans active ship factions in loaded sectors.
  - Picks likely conflict pairs based on relations and war-bias metadata.
  - Periodically worsens relations for selected pairs.
- New/updated faction values:
  - `cw_target_faction`
  - `enemy_faction` (paired target updates)

## [0.2.0] - 2026-04-25
### Added
- Established standalone Cosmic War mod structure (kept independent from Cosmic Overhaul internals).
- Server-side faction initialization extension that wraps `initializeAIFaction(...)`, applies war-focused trait bias, and stores persistent faction metadata (`cw_enabled`, `cw_war_bias`, `cw_diplomatic_polarity`).
- Optional framework dependency compatibility declarations (no hard integration yet) for Mod Configuration Menu, Lua JSON Library, and AzimuthLib.

## [0.1.0] - 2026-04-18
### Added
- Initial project scaffold including `modinfo.lua`, `main.lua`, `data/scripts/server/factions.lua`, and `README.md`.