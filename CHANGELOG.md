# Changelog

## [1.1.0] - 2026-05-18

### Added
- **Dynamic War Contracts:** Added five brand new, heat-scaling combat missions dynamically injected into station Bulletin Boards:
  - *Operation: Interception* (Offense, Heat > 0.45): Intercept an enemy supply convoy.
  - *Operation: Breakthrough* (Defense, Heat > 0.45): Protect an allied convoy while its hyperdrive spools.
  - *Operation: Frontline Siege* (Escalation, Heat > 0.60): Destroy a heavily-scaled enemy Forward Operating Base (FOB) that actively calls in reinforcements.
  - *Operation: High-Value Extraction* (Survival, Heat > 0.80): Survive waves of elite hunters while a high-ranking enemy officer defects.
  - *Operation: Decapitation Strike* (Climax, Heat = 1.00): Face an astronomically scaled enemy Flagship Dreadnought. Destroying it instantly forces a ceasefire and resets relations between the two warring factions.

### Changed
- **Architecture Update:** Migrated background script initialization from `data/scripts/server/init.lua` to `data/scripts/galaxy/init.lua`. This perfectly aligns with Avorion's modern component architecture, ensuring the macro war simulation safely and correctly attaches to the global `Galaxy` object.
- Cosmic War now formally consumes the **Cosmic Vault Faction Index API** (`factions` and `factions_ready`) to dramatically reduce expensive API loops and guarantee consistency across all modules.

### Fixed
- Fixed a C++ Engine crash where background scripts attempted to pass Lua tables directly into `Server():setValue()`. Shared caches (like faction indices and heat snapshots) are now safely encoded and decoded as comma-separated strings.
- Fixed an issue where background scripts crashed with an `attempt to index upvalue 'CosmicWarConfig' (a boolean value)` error by ensuring the config library explicitly returns its table.
- Fixed a critical bug in `cosmicwardiplomacy.lua` that was still attempting to use the broken vanilla `Galaxy():getFactions()` API. It now safely reads from the centralized Cosmic Vault faction index.
- Background scripts and the `/cosmicwarstatus` command now gracefully halt and inform the user if the server is still compiling the faction index, preventing startup errors.

## [1.0.3] - 2026-05-17

### Added
- Sector War Pressure controller now accounts for `EntityType.Station` presence, ensuring sectors with only stations still contribute to active frontlines.

### Changed
- Refactored background scripts (`cosmicwarnews.lua`, `cosmicwarceasefires.lua`, and `cosmicwarstatus.lua`) to correctly track and filter mirrored rivalries, preventing mutual conflicts from being evaluated or displayed twice.
- Updated Avorion localization tags in `cosmicwarnews.lua` to correctly use strict `%_t` syntax and named template variables (`${factionA}`, etc.).
- Standardized safe `getCfg()` fallback wrappers across background scripts.

### Fixed
- Removed a redundant root `main.lua` file to resolve a startup absolute path warning on server logs.
- Fixed a formatting bug in the fallback logging (`cwlog`) that caused literal string tokens (`%s`, `%i`) to print instead of their variable values.

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
