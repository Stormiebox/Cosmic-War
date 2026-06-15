# Changelog

All notable changes to **Cosmic War** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v3.0.0] - (CURRENT PROJECT VERSION - NO RELEASE DATE YET!)
### **The Arsenal Update**
*The most massive expansion to Cosmic War yet, introducing mercenary enlistment, warbonds, brand new contract missions, horrifying new events like the Eclipse Vanguard, and a completely rebalanced war economy.*

### 🚀 Major Overhaul Features
- **Dynamic Territory Expansion:** Factions can now actively capture enemy sectors and shift Galaxy Map borders mathematically in the background without causing Sector Alive performance drain! Conquests are automatically broadcast to the Galactic News Network.
- **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.
- **Vault Events API Integration:** Wars are now seamlessly tracked and registered into the Cosmic Vault News framework via `cosmic_war_declaration`.
- **Cosmic Vault API Framework:** Fully integrated with the Cosmic Vault API framework. Swept codebase for legacy callbacks and implemented safe guard fallbacks.

### ✨ Added
- **Formalized Custom Traits System:** Converted the old string-based "Stances" (Warmonger, Pacifist, Isolationist, Opportunist) into a formal custom trait system powered by Cosmic Vault. Traits now display beautifully in the vanilla UI with detailed tooltips!
- **9 Dynamic Faction Traits:** Added 5 brand new, mechanically active traits alongside the original 4 stances.
  - **Imperialist:** Background simulation dynamically causes them to rapidly claim empty sectors and build natively-generated outposts.
  - **Entrenched:** Background simulation dynamically causes them to heavily fortify their core territory, spawning defensive networks.
  - **Vengeful:** Hooked into the background diplomacy math. Ceasefires are now practically impossible once a war begins.
  - **Mercantile:** Hooked into mercenary missions. Mercenaries fighting for Mercantile factions receive triple (3x) the base "Bounty" and "War Contract" payouts.
  - **Xenophobic:** Forces severe continuous relation degradation with all neighbors, rendering alliances impossible and driving them to unprovoked wars.
- **Dormant Vanilla Trait Activation:** Successfully revived 4 unused vanilla traits (Sadistic/Sympathetic, Strict/Forgiving, Smart/Dumb, Active/Passive) and integrated them directly into the background simulation engine. These traits now actively influence mercenary payouts, expansion rates, and diplomatic war calculations!
- **Dark Matter Fog Integration**: `siegeevent.lua` now natively interfaces with the Cosmic Vault Weather API. When The Eclipse faction launches a siege, they will instantly blanket the battlefield in Dark Matter Fog, cutting defender sensor and jump ranges in half.
- `cw_planetary_defense.lua` added to grant sector-wide invincibility to stations.
- **Cinematic Battlefield HUD:** Active War Zones and Sieges now feature a sleek 100% split Top-Screen Red/Blue bar HUD tracking live siege durations. Displays dramatic border flip text flashes on successful captures or defenses.
- **Dynamic Invasion Scaling:** `cw_fleetclash.lua` and `siegeevent.lua` now mathematically calculate the total combined Volume/Omicron of all defending ships and stations, dynamically spawning equivalent fleets to perfectly match (100%) the defender's strength! No more weak vanilla nuisance invasions.
- **Siege Dreadnoughts & Transports:** Invader Troop Transports now spawn with a `10x` multiplier to base shields. If invading heavily fortified sectors, heavily shielded "Siege Dreadnoughts" will actively spawn to escort them.
- **Electronic Warfare (Shield Jammer):** 50% chance for invaders dropping into a sector to activate an EMP burst, permanently pinning all defending (and player!) shields to 0 durability for a massive 60-second surprise attack window.
- **Refugee Crisis Buff:** Refugee Freighters now correctly scale with a massive invisible 10x shield/durability buff to survive pirate assaults long enough for the player to intercept.
- **Deep Wiki Integration:** Injected 11 combat event features into the Cosmic Codex, fully explaining War Heat, Diplomacy Drift, Contracts, and Flashpoints natively in-game.
- **Mercenary Enlistment:** Dock at Military Outposts to officially enlist in a faction's war effort as a privateer.
- **Warbonds:** Purchase Warbonds from Trading Posts that dynamically mature when the geopolitical war state resolves.
- **5 New War Contracts:**
  - Assassinate Flag Officer
  - Supply Line Raid
  - Propaganda Broadcast
  - Prisoner of War Extraction
  - Minefield Deployment
- **5 New War Zone Events:**
  - Station Siege Blockades
  - The Eclipse Vanguard Invasion
  - Capital Ship Duels
  - Distress Beacon Traps
  - Orbital Planetary Bombardment
- **AI Troop Transports:** Massive, heavily shielded AI transports will now spawn during sector sieges and attempt to physically board and capture defending stations.

### ⚙️ Changed & Balanced

- **Mercantile War Contracts:** Updated all War Contracts to also give 3x bonus payout if a `Mercantile` faction is the mission giver.
- **Diplomacy AI Trait Integration:** Refactored `factions.lua` to intelligently derive all 9 traits from vanilla parameters (e.g. `greedy > 0.7`) during faction generation. Maintains a 30% forceful injection chance to ensure extreme trait variance across the galaxy.
- **Abandon Mission Penalties:** Abandoning a War Contract now incurs a massive reputation penalty with the contracting faction.
- **Enhanced Payouts:** The base payout of all War Contract missions has been significantly buffed.
- Shield Jammer event chance nerfed to 35%.
- Shield Jammer now completely ignores stations protected by a Planetary Defense Grid.
- Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements.

### 🐛 Bug Fixes & Optimization
- **Diplomacy Engine Crash:** Fixed `EXCEPTION_ACCESS_VIOLATION` caused by processing relation changes on asynchronous background threads. Diplomacy calculations now run safely synchronously on the main thread.
- **Cosmic Codex Loading Crash:** Fixed missing global definitions (e.g. `entities`, `rangeType`) in the codex files that prevented the encyclopedia from loading correctly and crashed the UI.
- **Missing AI Scripts (Ghost AI Bug):** Fixed a critical issue where Flagships generated during *Stranded Flagship* and *Decapitation Strike* events were assigned a missing vanilla script (`story/boss.lua`). They now properly inject the new `ai/dreadnoughtboss.lua` behavior script.
- **Performance & TPS Optimization:** Drastically reduced server load during late-game and high-intensity scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s to 60.0s) into 5 major mission and background scripts (`cw_breakthrough`, `cw_forcerecon`, `cw_frontlinesiege`, `cw_highvaluedefection`, `rebuildstations`). These scripts previously looped 60 times a second without throttling.
- **Vanilla Override Fixes:** Removed `math.random` calls in `cw_militaryoutpost.lua` to ensure deterministic generation.
- **Multiplayer Synchronization:** Replaced all instances of `math.random` with Avorion's deterministic `random()` engine to prevent massive multiplayer client/server desyncs when generating loot, stats, and enemies.
- **UI Polish:** Faction names will no longer display raw translator comments (e.g., `/* faction name */`) inside the Galactic Politics tab.
