# Changelog

All notable changes to **Cosmic War** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v3.0.0] - UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)
### **The Arsenal Update**
*The most massive expansion to Cosmic War yet, introducing mercenary enlistment, warbonds, brand new contract missions, horrifying new events like the Eclipse Vanguard, and a completely rebalanced war economy.*

### ✨ New Features & 📦 Content Additions
- [Feature] **Dynamic Territory Expansion:** Factions can now actively capture enemy sectors and shift Galaxy Map borders mathematically in the background without causing Sector Alive performance drain! Conquests are automatically broadcast to the Galactic News Network.
- [Feature] **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.
- [Feature] **Deep Economy Warfare:** Introduced `CosmicWarBridge.forceDeclareWar()`, natively bridging the Cosmic Vault Economy simulation with the diplomatic war simulation. Market collapses and starvation can now directly trigger desperation invasions for survival!
- [Feature] **Weather-Assisted Boarding:** Injected the `CosmicVaultWeather` API directly into frontline siege logic. If a `DarkMatterFog` or `IonStorm` rolls into the sector during a siege, the defending station's boarding defense multiplier is slashed by 50%, allowing players to strategically use weather to capture fortresses!
- [Feature] **Vault Events API Integration:** Wars are now seamlessly tracked and registered into the Cosmic Vault News framework via `cosmic_war_declaration`.
- [Feature] **Cosmic Vault API Framework:** Fully integrated with the Cosmic Vault API framework. Swept codebase for legacy callbacks and implemented safe guard fallbacks.
- [Feature] **Formalized Custom Traits System:** Converted the old string-based "Stances" (Warmonger, Pacifist, Isolationist, Opportunist) into a formal custom trait system powered by Cosmic Vault. Traits now display beautifully in the vanilla UI with detailed tooltips!
- [Feature] **Dormant Vanilla Trait Activation:** Successfully revived 4 unused vanilla traits (Sadistic/Sympathetic, Strict/Forgiving, Smart/Dumb, Active/Passive) and integrated them directly into the background simulation engine. These traits now actively influence mercenary payouts, expansion rates, and diplomatic war calculations!
- [Feature] **Dark Matter Fog Integration:** `siegeevent.lua` now natively interfaces with the Cosmic Vault Weather API. When The Eclipse faction launches a siege, they will instantly blanket the battlefield in Dark Matter Fog, cutting defender sensor and jump ranges in half.
- [Feature] **Planetary Defense Grid:** `cw_planetary_defense.lua` added to grant sector-wide invincibility to stations.
- [Feature] **Cinematic Battlefield HUD:** Active War Zones and Sieges now feature a sleek 100% split Top-Screen Red/Blue bar HUD tracking live siege durations. Displays dramatic border flip text flashes on successful captures or defenses.
- [Feature] **Dynamic Invasion Scaling:** `cw_fleetclash.lua` and `siegeevent.lua` now mathematically calculate the total combined Volume/Omicron of all defending ships and stations, dynamically spawning equivalent fleets to perfectly match (100%) the defender's strength! No more weak vanilla nuisance invasions.
- [Feature] **Electronic Warfare (Shield Jammer):** 50% chance for invaders dropping into a sector to activate an EMP burst, permanently pinning all defending (and player!) shields to 0 durability for a massive 60-second surprise attack window.
- [Feature] **Deep Wiki Integration:** Injected 11 combat event features into the Cosmic Codex, fully explaining War Heat, Diplomacy Drift, Contracts, and Flashpoints natively in-game.
- [Feature] **Mercenary Enlistment:** Dock at Military Outposts to officially enlist in a faction's war effort as a privateer.
- [Feature] **Warbonds:** Purchase Warbonds from Trading Posts that dynamically mature when the geopolitical war state resolves.
- [Feature] **Wartime Propaganda Beacons:** Added Wartime Propaganda Beacons dynamically spawning after sieges (Cosmic Chronicles synergy).
- [Content] **9 Dynamic Faction Traits:** Added 5 brand new, mechanically active traits alongside the original 4 stances: Imperialist, Entrenched, Vengeful, Mercantile, and Xenophobic.
- [Content] **Siege Dreadnoughts & Transports:** Invader Troop Transports now spawn with a `10x` multiplier to base shields and attempt to physically board and capture defending stations. If invading heavily fortified sectors, heavily shielded "Siege Dreadnoughts" will actively spawn to escort them.
- [Content] **5 New War Contracts:** Assassinate Flag Officer, Supply Line Raid, Propaganda Broadcast, Prisoner of War Extraction, Minefield Deployment.
- [Content] **5 New War Zone Events:** Station Siege Blockades, The Eclipse Vanguard Invasion, Capital Ship Duels, Distress Beacon Traps, Orbital Planetary Bombardment.
- [Content] **Weaponized Subspace Tears:** At Critical War Heat, warring factions may detonate experimental subspace weapons, tearing the fabric of space and unleashing localized Rift hazards.
- [Content] **War Contracts - Subspace Containment:** When a rift tears in a warzone, factions will issue high-paying War Contracts to secure emerged Ancient Tech platforms and contain the anomaly.

### ⚙️ Changed & ⚖️ Balanced
- [Changed] **Centralized Radio Chatter:** Neutralized the `radiochatter.lua` script inside Cosmic War. All custom ambient lore and war chatter lines have been seamlessly migrated and centralized within the Cosmic Chronicles mod to prevent duplicate hooks and improve integration.
- [Changed] **Diplomacy AI Trait Integration:** Refactored `factions.lua` to intelligently derive all 9 traits from vanilla parameters (e.g. `greedy > 0.7`) during faction generation. Maintains a 30% forceful injection chance to ensure extreme trait variance across the galaxy.
- [Changed] **Core Dependencies:** Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements.
- [Changed] **Unified News API:** Refactored multiple legacy news broadcasting systems to securely pass through the new `CosmicVaultNews.publishArticle` architecture.
- [Changed] **Dependency Update:** Now explicitly requires Cosmic Vault library hooks for all faction modifications.
- [Balanced] **Commodore Siege Leadership:** Defending a siege with a Commodore captain in the sector will reduce the faction's Famine Score penalty from +5 down to +2 if the sector is ultimately lost.
- [Balanced] **Refugee Crisis Buff:** Refugee Freighters now correctly scale with a massive invisible 10x shield/durability buff to survive pirate assaults long enough for the player to intercept.
- [Balanced] **Mercantile War Contracts:** Updated all War Contracts to also give 3x bonus payout if a `Mercantile` faction is the mission giver.
- [Balanced] **Abandon Mission Penalties:** Abandoning a War Contract now incurs a massive reputation penalty with the contracting faction.
- [Balanced] **Enhanced Payouts:** The base payout of all War Contract missions has been significantly buffed.
- [Balanced] **Electronic Warfare (Shield Jammer):** Shield Jammer event chance nerfed to 35% and now completely ignores stations protected by a Planetary Defense Grid.
- [Balanced] **Famine Penalty Reduction:** The base Famine Score penalty applied to a faction for losing a sector siege has been drastically reduced from +20 down to +5 to prevent instant economic cascade failures during massive border wars.
- [Balanced] **Galactic Turn Synchronization:** `diplomacyInterval`, `newsInterval`, `sanctionsInterval`, `ceasefireInterval`, and `bountyInterval` have all been strictly aligned to 1200s (20 minutes). This ensures that major war-heat shifts and background diplomacy execute seamlessly during a synchronized "Galactic Turn" to drastically improve server TPS.
- [Balanced] **Eclipse Diplomacy Stances:** Hardcoded Imperialist and Vengeful diplomatic traits onto The Eclipse (Cosmic Ascendancy synergy).

### 🐛 Bug Fixes & 🛠️ Optimization
- [Optimized] **Performance & TPS Optimization:** Drastically reduced server load during late-game and high-intensity scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s to 60.0s) into 5 major mission and background scripts (`cw_breakthrough`, `cw_forcerecon`, `cw_frontlinesiege`, `cw_highvaluedefection`, `rebuildstations`). These scripts previously looped 60 times a second without throttling.
- [Bugfixed] **Truthiness Logic Stabilized:** Applied strict explicit float comparisons (`> 0.5`) inside `galacticpolitics_tab.lua` to resolve truthiness evaluation bugs that could destabilize the UI when sorting zero-values.
- [Bugfixed] **Architecture Flaws:** Fixed a critical architecture flaw where `cosmicwartraits.lua` exposed a global `initialize()` wrapper, preventing vanilla server initialization when included.
- [Bugfixed] **Engine Crash Fixes:** Fixed multiple API Avorion Indexes across various scripts that could cause C++ attempt to index or attempt to call engine crashes (e.g. corrected stat modifiers, entity bias functions, invalid faction setters, removed native calls to non-existent functions, and corrected C++ matching distance checks).
- [Bugfixed] **Hardened Faction Relations:** Migrated over 15 mission/event scripts to use the hardened `CosmicVaultFaction.changeRelations()` API, removing dangerous `math.max` fallback logic that could crash the engine on boundary overflows.
- [Bugfixed] **Mission Trigger Logic:** Fixed `cw_deploy_mines.lua` trigger condition not incrementing the deployment counter, and `cw_propaganda_broadcast.lua` evaluating every server tick instead of every second. Both missions now progress and complete properly.
- [Bugfixed] **Mission Generation Locks:** Fixed `cw_forcerecon.lua` "Force Recon" mission soft-locking due to a missing station script (`sensorarray.lua`). The mission now correctly generates a Military Outpost as the covert listening post.
- [Bugfixed] **Targeting Parsing:** Fixed `dreadnoughtboss.lua` incorrectly parsing varargs into a table when fetching enemies, resulting in incomplete target lists.
- [Bugfixed] **Diplomacy Engine Crash:** Fixed `EXCEPTION_ACCESS_VIOLATION` caused by processing relation changes on asynchronous background threads. Diplomacy calculations now run safely synchronously on the main thread.
- [Bugfixed] **Cosmic Codex Loading Crash:** Fixed missing global definitions (e.g. `entities`, `rangeType`) in the codex files that prevented the encyclopedia from loading correctly and crashed the UI.
- [Bugfixed] **Missing AI Scripts (Ghost AI Bug):** Fixed a critical issue where Flagships generated during *Stranded Flagship* and *Decapitation Strike* events were assigned a missing vanilla script (`story/boss.lua`). They now properly inject the new `ai/dreadnoughtboss.lua` behavior script.
- [Bugfixed] **Multiplayer Synchronization:** Replaced all instances of `math.random` with Avorion's deterministic `random()` engine (including `cw_militaryoutpost.lua`) to prevent massive multiplayer client/server desyncs when generating loot, stats, and enemies.
- [Bugfixed] **UI Polish:** Faction names will no longer display raw translator comments (e.g., `/* faction name */`) inside the Galactic Politics tab.
