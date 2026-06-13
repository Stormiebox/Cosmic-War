# Changelog

All notable changes to **Cosmic War** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v3.0.0] - (CURRENT PROJECT VERSION - NO RELEASE DATE YET!)
### **The Arsenal Update**
*The most massive expansion to Cosmic War yet, introducing mercenary enlistment, warbonds, brand new contract missions, horrifying new events like the Eclipse Vanguard, and a completely rebalanced war economy.*

### UI & Codex
- **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.

### Bug Fixes & Compliance
- **Performance & TPS Optimization:** Drastically reduced server load during late-game and high-intensity scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s to 60.0s) into 5 major mission and background scripts (`cw_breakthrough`, `cw_forcerecon`, `cw_frontlinesiege`, `cw_highvaluedefection`, `rebuildstations`). These scripts previously looped 60 times a second without throttling.
- **UI Polish:** Faction names will no longer display raw translator comments (e.g., `/* faction name */`) inside the Galactic Politics tab.
- **Multiplayer Synchronization:** Replaced all instances of `math.random` with Avorion's deterministic `random()` engine to prevent massive multiplayer client/server desyncs when generating loot, stats, and enemies.
- **Vanilla Override Fixes:** Removed `math.random` calls in `cw_militaryoutpost.lua` to ensure deterministic generation.
- **Missing AI Scripts (Ghost AI Bug):** Fixed a critical issue where Flagships generated during *Stranded Flagship* and *Decapitation Strike* events were assigned a missing vanilla script (`story/boss.lua`). They now properly inject the new `ai/dreadnoughtboss.lua` behavior script.

### Additions
- **Dynamic Territory Expansion:** Factions can now actively capture enemy sectors and shift Galaxy Map borders mathematically in the background without causing Sector Alive performance drain! Conquests are automatically broadcast to the Galactic News Network.
- **AI Troop Transports:** Massive, heavily shielded AI transports will now spawn during sector sieges and attempt to physically board and capture defending stations.
- **Mercenary Enlistment**: Dock at Military Outposts to officially enlist in a faction's war effort as a privateer.
- **Warbonds**: Purchase Warbonds from Trading Posts that dynamically mature when the geopolitical war state resolves.
- **Abandon Mission Penalties**: Abandoning a War Contract now incurs a massive reputation penalty with the contracting faction.
- **Enhanced Payouts**: The base payout of all War Contract missions has been significantly buffed.
- **5 New War Contracts**:
  - Assassinate Flag Officer
  - Supply Line Raid
  - Propaganda Broadcast
  - Prisoner of War Extraction
  - Minefield Deployment
- **5 New War Zone Events**:
  - Station Siege Blockades
  - The Eclipse Vanguard Invasion
  - Capital Ship Duels
  - Distress Beacon Traps
  - Orbital Planetary Bombardment
- **Vault Events API Integration**: Wars are now seamlessly tracked and registered into the Cosmic Vault News framework via `cosmic_war_declaration`.
- Fully integrated with the Cosmic Vault API framework.
- Swept codebase for legacy callbacks and implemented safe guard fallbacks.