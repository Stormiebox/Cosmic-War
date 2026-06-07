# Changelog

All notable changes to **Cosmic War** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-06-07

### Fixed
- **Engine Bootstrap Compliance:** Removed invalid `initialize()` wrappers from `player/init.lua` and `sector/init.lua`. Avorion expects these to be global execution scripts. This resolves a fatal bug where the core `cosmicwarcontroller.lua` and UI tabs completely failed to load on fresh saves.
- **Architectural Overhaul (Event Scheduler):** Fixed a massive, silent game-breaking bug where the mod entirely overwrote the vanilla `player/init.lua` and `player/eventscheduler.lua` files. This previously resulted in the total deletion of all vanilla player scripts and disabled all vanilla events (pirate attacks, Xsotan spawns, etc.).
  - The Event Scheduler has been rewritten into a standalone `cw_eventscheduler.lua` module that safely attaches to the player and runs strictly parallel to the vanilla game, guaranteeing that dynamic war flashpoints actually trigger.
- **Architectural Overhaul (War Contracts):** Fixed a major bug where the `bulletinboardmissions.lua` library was completely unhooked and relying on deprecated Avorion 1.0 architecture. War Contracts literally never spawned.
  - All 8 War Contract mission scripts have been completely modernized with inline `getBulletin()` functions.
  - Wrote a safe, compliant hook into `data/scripts/entity/missionbulletins.lua` that seamlessly injects War Contracts into the vanilla dynamic mission generation pool based entirely on local faction War Heat.
- **Event Spawning Typo:** Fixed a massive crash across all 5 dynamic space events (`cw_fleetclash.lua`, `cw_armsdeal.lua`, `cw_diplomaticsabotage.lua`, `cw_strandedflagship.lua`, `cw_refugeeconvoy.lua`) where the script attempted to call `generator:createPositionInSector()` instead of Avorion's native `generator:getPositionInSector()`. Events will now correctly spawn their ships instead of instantly aborting.
- **Library Include Bug:** Fixed a critical bug across all dynamic war events and missions where they would crash upon triggering (`attempt to index upvalue 'CosmicWarBridge' (a boolean value)`). This was caused by `cosmicwarbridge.lua`, `cosmicwarcaptainbridge.lua`, and `cosmicwareconomybridge.lua` missing their `return` statements, causing Avorion's `include()` function to return `true` instead of the actual library table.
- **Mission Initialization Crash:** Fixed a critical bug where War Contracts passed plain integers into Avorion's core `structuredmission.lua` framework instead of the required parameter tables. This previously caused the background server VM to crash silently whenever a War Contract attempted to spawn on a bulletin board.
- **Mission Spawning Typo:** Fixed a critical bug across all 8 War Contracts where `SectorGenerator:createPositionInSector()` was called instead of the native `SectorGenerator:getPositionInSector()`. This caused a silent server crash when generating mission enemies, resulting in completely empty sectors upon arrival.
- **Mission Client Loop Crashes:** Fixed an invalid Lua syntax error (`#Sector():getEntitiesByScriptValue`) in `cw_borderskirmish.lua` and `cw_resourcesabotage.lua` that attempted to index a userdata tuple as a table. This caused the client UI to crash repeatedly (`attempt to get length of a nil value`) when arriving at the mission sector.
- **Client-Side Mission Execution Crash (`12ClientPlayer`):** Fixed a massive game-breaking bug across all 8 War Contracts where entering a mission sector caused a fatal UI crash. Avorion's engine naturally executes the `onTargetLocationEntered` and `onTargetLocationArrivalConfirmed` hooks on both the client and server. The mission files were missing their `if onClient() then return end` safety guards, causing the client to illegally attempt to use `SectorGenerator()` to natively spawn ships into the local simulation.

### Added
- **Functional War Bounties:** The War Bounty system is now fully functional. A new lightweight sector script (`cw_bountypayouts.lua`) tracks player kills and actively cashes in active faction bounties.
  - Sinking a standard ship pays 1x the bounty. Bosses pay 3x. Stations pay 5x!
  - Collecting a bounty clears it to prevent farming, acting as a true "High-Profile Hit".
  - Instantly hooks into Galactic News to broadcast a "War Bounty Claimed" alert to all players.
- **Galactic News Integration:** All 5 dynamic space events now fully integrate with the Galactic News Network, pushing live, localized conflict reports to the server whenever a flashpoint erupts.
- **War Contract Icons:** All 8 War Contracts now correctly display high-quality thematic mission icons on the bulletin board UI (Shield, Crosshairs, Radar, etc.) instead of blank textures.
- **Ecosystem Soft Bridges:** Implemented 4 massive new features designed to work beautifully standalone or synergize with the full Cosmic Series (Overhaul, Starfall, Chronicles).
- **War Profiteering (Economy Hooks):** At Critical War Heat, military goods naturally bleed out from stations to simulate consumption. Soft bridges to Cosmic Overhaul to create massive profiteering margins and to Cosmic Chronicles for news alerts.
- **Wreckage Fields:** New dynamic event spawns 4-9 wrecked capital ships to simulate recent fleet clashes. Scavengers can loot these fields for scrap and Cosmic Overhaul Black Boxes.
- **Trade Interdiction Blockades:** New dynamic event spawns Hostile NPC military squads at jump-gate distances in warring sectors to harass neutral traders and players.
- **Elite Headhunters (Mercenary Alignment):** Dropping below -80000 relations with an actively warring faction will dispatch Elite Headhunters against you. Soft-bridges to Cosmic Starfall to dynamically equip them with devastating heavy subsystems.
- **Expanded Radio Chatter:** Injected 40 brand new, highly thematic background radio chatter lines to civilian, military, and freighter ships. These lines subtly hint at the broader Cosmic ecosystem and developer lore, and have been fully localized into all 7 supported languages.

### Removed
- **Texture Folder:** All textures were removed and migrated into `Cosmic Vault`.

## [1.7.0] - 2026-06-04

### Added
- **Galactic Politics Tab:** Added a new tab to the player window that displays active galactic conflicts, including faction names, war heat, status, and relations.
  - **Player Relation Colors:** Faction names are dynamically color-coded based on the player's personal standing with each faction.
  - **Strategic Tooltips:** Hovering over a conflict now reveals internal Faction Indices, AI Traits (Aggressive, Wealthy, Peaceful, etc.), exact numerical player relations, and active War Bounties.
  - **War Bounties Indicator:** Factions with active bounties placed against them now display a `[!]` indicator next to their name.
  - **Immersive Relation Text:** Added a "Numeric Relations" checkbox. Players can now toggle between seeing raw relation numbers or immersive diplomatic states (e.g., "Allied", "Confrontational", "All-Out War").
  - **Interactive Column Sorting:** Added clickable column headers (Faction A, Faction B, War Heat, Status, Relations) to instantly sort the list ascending or descending.
  - **Conflict Filters:** Added a dropdown to instantly filter the list by "All", "Active Conflicts", "Ceasefires Only", or "Active Bounties".
  - **Legend & Summary Panel:** Added a bottom UI panel that clearly explains the color-coding, bounty indicators, and how the Cosmic War simulation operates in the background.
- **Localization Expansion:** Fully localized the new Galactic Politics Tab and its interactive features into all 7 supported languages (German, Russian, Portuguese, French, Japanese, Spanish, and Chinese).

## [1.6.0] - 2026-05-30 - In Sync With Cosmic Overhaul v4.0.0 Update

### Added
- **Localization Expansion:** Added proper translation support for the new Diplomatic Sanctions system messages across all 7 supported languages.

### Fixed
- **Mission Spawn Crash:** Fixed a critical bug in `cw_resourcesabotage.lua` where a missing enemy faction would cause a silent crash during sector generation.
- **Phantom Event Crash:** Fixed a critical issue in `eventscheduler.lua` where dynamic events (Fleet Clashes, Arms Deals, etc.) failed to trigger because they were trying to attach to a non-existent vanilla script wrapper (`sectoreventstarter`).
- **Brittle Rebuild API:** Fixed a silent failure in `rebuildstations.lua` where the script relied on private vanilla variables. It now correctly uses standard C++ bindings to identify controlling factions and properly clamp station rebuilding during active wars.
- **Array Traversal Bias:** Fixed a massive simulation bias in `cosmicwarbounties.lua` and `cosmicwardiplomaticsanctions.lua`. Previous deduplication logic prevented newer factions from ever issuing bounties or paying sanctions. Every faction now evaluates these actions independently.
- **Engine Payment Crash:** Fixed a silent engine error in `cosmicwardiplomaticsanctions.lua` where the script attempted to pass negative numbers to `Faction:receive()`. It now safely uses `Faction:pay()` to ensure reliable deductions.

### Added
- **Ecosystem Soft Bridges:** Implemented 4 massive new features designed to work beautifully standalone or synergize with the full Cosmic Series (Overhaul, Starfall, Chronicles).
- **War Profiteering (Economy Hooks):** At Critical War Heat, military goods naturally bleed out from stations to simulate consumption. Soft bridges to Cosmic Overhaul to create massive profiteering margins and to Cosmic Chronicles for news alerts.
- **Wreckage Fields:** New dynamic event spawns 4-9 wrecked capital ships to simulate recent fleet clashes. Scavengers can loot these fields for scrap and Cosmic Overhaul Black Boxes.
- **Trade Interdiction Blockades:** New dynamic event spawns Hostile NPC military squads at jump-gate distances in warring sectors to harass neutral traders and players.
- **Elite Headhunters (Mercenary Alignment):** Dropping below -80000 relations with an actively warring faction will dispatch Elite Headhunters against you. Soft-bridges to Cosmic Starfall to dynamically equip them with devastating heavy subsystems.

### Removed
- **Dead Code:** Removed leftover and commented-out diplomacy loop attachments from `player/init.lua` to keep the player execution context pristine.

## [1.5.0] - 2026-05-24

### Fixed

- **Invisible Factions (Pirates & Xsotan):** Fixed a major blind spot where dynamically generated high-ID factions (such as Pirates, Xsotan, and DLC factions) were invisible to the background war simulation. `Cosmic War` will now dynamically self-heal and force-register these factions into the global Vault index the moment they are encountered!
- **Global Conflict Tracking:** Background scripts (`cosmicwarnews`, `cosmicwarbounties`, and `/cosmicwarstatus`) will now correctly report, track, and broadcast events involving Pirate and Xsotan factions.
- **Localization:** Fixed several localization strings that were not being properly translated due to incorrect syntax (`%_t` vs. `%_T`).
- **Mission Descriptions:** Updated mission descriptions to use the new localization syntax.
- **String Arguments:** Fixed several instances where string arguments were not being passed correctly to localization functions, leading to untranslated text.
- **Dialogue System:** Fixed an issue where the dialogue system would sometimes fail to display mission-specific dialogue due to incorrect string formatting. This primarily affected mission acceptance and completion messages.
- **Mission Generation:** Fixed an issue where certain mission types (e.g., "Operation: Force Recon") would fail to generate due to incorrect parameter passing to the mission generation function.
- **Mission Generation (Operation: Resource Sabotage):** Fixed an issue where "Operation: Resource Sabotage" missions would sometimes fail to generate due to an invalid target entity type.
- **Mission Generation (Operation: Interception):** Fixed an issue where "Operation: Interception" missions would sometimes fail to generate due to an invalid target entity type. This could lead to missions being offered but immediately failing upon acceptance.
- **Mission Generation (Operation: Breakthrough):** Fixed an issue where "Operation: Breakthrough" missions would sometimes fail to generate due to an invalid target entity type.
- **Mission Generation (Operation: Frontline Siege):** Fixed an issue where "Operation: Frontline Siege" missions would sometimes fail to generate due to an invalid target entity type.

## [1.4.0] - 2026-05-24

### Fixed

- **Mid-Game Save Compatibility:** Added a self-healing retrofit loop to the background war simulation. If the mod is installed on an existing save or server, it will now automatically detect older AI factions missing their Cosmic War metadata (`cw_enabled`, `cw_war_bias`, etc.) and safely initialize them on the fly.
- **Diagnostics Command:** Fixed an issue where `/cosmicwarstatus` would report `0` active AI factions and `0` rivalries when loaded into an existing galaxy.

## [1.3.0] - 2026-05-24

### Fixed

- **Decapitation Strike (Server Freeze):** Fixed a critical issue where the Flagship Dreadnought attempted to generate at 500,000x normal scale, which would immediately exhaust memory and freeze dedicated servers.
- **Decapitation Strike (Diplomacy Crash):** Resolved a silent Lua crash triggered upon defeating the boss, caused by an invalid `RelationChangeType` enum.
- **Dynamic Events (VM Crashes):** Fixed multiple Global Sector Events (`cw_refugeeconvoy.lua`, `cw_diplomaticsabotage.lua`) crashing silently due to using `Player()` calls from a background VM. Converted these to `Sector():broadcastChatMessage()`.
- **Localization Syntax Errors:** Fixed several line-break formatting errors (`% \n _t`) that prevented Avorion's translation engine from scraping and translating strings properly.
- **Translation Mappings:** Cleaned up `template.pot` and all language `.po` files to correctly point to the newly restructured `events/` and `player/missions/` paths.

### Changed

- **Workspace Cleanup:** Physically removed duplicate legacy event and mission scripts from the `data/scripts/entity/` folder to reduce mod bloat and prevent script overlap confusion.

## [1.2.0] - 2026-05-18

### Added

- **Early-Conflict Missions:** Added three new dynamic contracts for early war escalation (Heat 0.15 - 0.35):
  - _Operation: Force Recon_ (Heat > 0.15): Scout a hostile listening post without being destroyed.
  - _Operation: Border Skirmish_ (Heat > 0.25): Intercept and eliminate a small enemy border patrol.
  - _Operation: Resource Sabotage_ (Heat > 0.35): Cripple the enemy's economy by destroying a mining operation.
- **Dynamic War Events (Flashpoints):** Injected five brand new, heat-scaling random events into the global exploration pool. You will now stumble upon live conflict scenarios while traveling through space:
  - _Fleet Clash Flashpoint_ (Heat > 0.60): A massive enemy invasion fleet jumps into an active AI-controlled sector.
  - _Refugee Convoy Interception_ (Heat > 0.40): Protect a fleeing civilian convoy from a ruthless hunter fleet until their hyperdrives charge.
  - _The Stranded Flagship_ (Heat > 0.80): Stumble upon a heavily damaged Dreadnought boss and destroy it before its repair fleet arrives!
  - _Black Market Arms Deal_ (Heat > 0.20): Intercept a covert arms deal to secure high-rarity Exceptional/Exotic turrets.
  - _Diplomatic Sabotage_ (Heat > 0.20): Defend a peace envoy from extremist saboteurs attempting to prevent a ceasefire.

### Changed

- **Bulletin Board Refactor:** Completely removed the custom ticking loop in `bulletinboard.lua`. Cosmic War now seamlessly injects its dynamic contracts directly into Avorion's native `bulletinboardmissions.lua` pool. This improves background performance and correctly triggers custom dialogue messages when players accept war contracts.

## [1.1.0] - 2026-05-18

### Added

- **Dynamic War Contracts:** Added five brand new, heat-scaling combat missions dynamically injected into station Bulletin Boards:
  - _Operation: Interception_ (Offense, Heat > 0.45): Intercept an enemy supply convoy.
  - _Operation: Breakthrough_ (Defense, Heat > 0.45): Protect an allied convoy while its hyperdrive spools.
  - _Operation: Frontline Siege_ (Escalation, Heat > 0.60): Destroy a heavily-scaled enemy Forward Operating Base (FOB) that actively calls in reinforcements.
  - _Operation: High-Value Extraction_ (Survival, Heat > 0.80): Survive waves of elite hunters while a high-ranking enemy officer defects.
  - _Operation: Decapitation Strike_ (Climax, Heat = 1.00): Face an astronomically scaled enemy Flagship Dreadnought. Destroying it instantly forces a ceasefire and resets relations between the two warring factions.

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
- Updated Avorion localization tags in `cosmicwarnews.lua` to correctly use strict `%_t` syntax and named template variables (`%1%`, etc.).
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


