# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-05-12
### Added & Removed
- Cosmic Overhaul synergy bridge modules for prediction-aware overlays:
  - `data/scripts/lib/cosmicwareconomybridge.lua`
  - `data/scripts/lib/cosmicwarcaptainbridge.lua`
- Simulation command overlay wrappers for cross-mod prediction integration (REMOVED):
  - `data/scripts/player/background/simulation/tradecommand.lua`
  - `data/scripts/player/background/simulation/scoutcommand.lua`
  - `data/scripts/player/background/simulation/travelcommand.lua`
  - `data/scripts/player/background/simulation/refinecommand.lua`
  - `data/scripts/player/background/simulation/minecommand.lua`
  - `data/scripts/player/background/simulation/salvagecommand.lua`
- New MCM integration page in `modconfig.lua`:
  - **Bridge Integration**
    - `enableEconomyBridge` (default: true)
    - `enableCaptainBridge` (default: true)

### Changed
- `data/scripts/lib/cosmicwarconfig.lua` now exposes and validates bridge toggles:
  - `enableEconomyBridge`
  - `enableCaptainBridge`
- Bridge behavior is now admin-gated at runtime:
  - Economy bridge returns neutral multipliers when disabled.
  - Captain bridge returns unmodified predictions when disabled.
- Added maintainability comments in simulation wrappers to document non-invasive composition intent with Cosmic Overhaul command logic.

### Compatibility
- Integration follows post-original-call wrapper composition and avoids direct edits to Cosmic Overhaul command internals.
- Prediction metadata remains namespaced under `prediction.mcm.cosmicWar` to reduce collision risk in mixed mod stacks.

### QA Notes
- Static QA completed: file integrity, wrapper consistency, config plumbing, and diff-level validation.
- Runtime/in-game verification matrix was intentionally deferred by user request and should be executed before production/stable release builds.

## [0.4.1] - 2026-05-09
### Fixed
- Hardened `/cosmicwarstatus` command against early server lifecycle timing:
  - Added `Galaxy()` availability guard.
  - Added callable guard for `galaxy.getFactions` to avoid nil-method runtime errors.
  - Returns graceful status messages instead of throwing stack traces when the galaxy API is not fully ready.
- Hardened faction fetch paths in background systems:
  - `data/scripts/server/background/cosmicwarbounties.lua`
  - `data/scripts/server/background/cosmicwarceasefires.lua`
  - Both now verify `galaxy.getFactions` is callable before use.

### Changed
- Updated documentation to reflect lifecycle-safe command behavior and stability hardening in war background loops.
- Validation pass confirms current runtime status is stable with latest logs (Cosmic War + Cosmic Overhaul).

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
