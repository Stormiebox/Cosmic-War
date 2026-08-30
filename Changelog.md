# Changelog

All notable changes to **Cosmic War** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v3.3.4]

### 🪲 Bug Fixes

- [Bugfix] **Warbond Purchase Server Crash (`cosmicwarbridge.lua:97`):** Fixed a fatal `attempt to call global 'Server' (a nil value)` error triggered when a player interacted with the "Purchase Warbonds" option at a Trading Post. The `CosmicWarBridge.getWarHeatSnapshot()` function was calling `Server()` unconditionally, which returns `nil` in all client-side execution contexts. Added an `if not onServer() then return {}, 0 end` guard at the top of the function to make it safe when evaluated on the client.
- [Bugfix] **Warbond Dialog Flow Rearchitected (`tradingpost.lua`):** The underlying architectural issue was that `TradingPost.onPurchaseWarbondsInteraction()` — a `ScriptUI` interaction callback which always executes on the client — was directly calling `CosmicWarBridge.getFactionWarHeat()` to determine which dialog to show. Any bridge function that transitively calls `Server()` will crash in this context. Reworked the flow to use the correct Avorion client/server RPC pattern: the interaction handler now dispatches `invokeServerFunction("requestWarbondDialog")`, the server evaluates war heat and dispatches `invokeClientFunction(player, "showWarbondDialog", showBuy)`, and the client-side callback calls `ScriptUI():showDialog()` with the correct dialog. Both new RPC functions are registered with `callable(TradingPost, ...)`.

### 🪲 Bug Fixes

- [Bugfix] **Bounty Payout Server Crash:** Fixed a severe runtime error in the sector thread where destroying a bounty target would crash the background simulation. The script incorrectly attempted to execute `hasScript()` directly on the base Faction class instead of casting it to a Player or Alliance entity. Bounties will now correctly attach the tracker script and pay out their rewards without crashing.
- [Bugfix] **Dynamic War Event Crashes:** Fixed a critical structural vulnerability affecting multiple dynamic events (`cw_armsdeal.lua`, `cw_blockade.lua`, `cw_strandedflagship.lua`, `cw_distress_beacon_trap.lua`, `cw_diplomaticsabotage.lua`, `cw_refugeeconvoy.lua`). Missing `galaxy.lua` includes for `Balancing_GetPirateLevel` and unprotected dereferencing of missing/destroyed Faction objects were causing immediate SIGSEGV/thread crashes when these events attempted to spawn in the background.

## [v3.3.2]

### 🪲 Bug Fixes

- [Bugfix] **Frontline Siege Contract:** Fixed a bug where the mission would soft-lock and fail to complete if the target Forward Operating Base (FOB) was boarded/captured rather than explicitly destroyed, or if wreckage data lingered in the engine.
- [Bugfix] **Sensor Deployment Contract:** Added a physical HUD navigation beacon at the center of the sector `(0, 0, 0)` so players know exactly where to deploy the stealth buoy, resolving confusion caused by the lack of a coordinate grid.

## [v3.3.1]

### 🪲 Bug Fixes

- [Bugfix] **Bounty Payout Sector Crash:** Fixed a critical server crash triggered by an invalid sector object property when a player enters a sector where an active bounty is placed on the controlling faction.
- [Bugfix] **Sensor Deployment Contract:** Fixed a script error in the Sensor Deployment war contract that prevented the mission from correctly validating the player's distance when deploying the stealth buoy.
- [Bugfix] **Background Script Architecture:** Corrected namespace declarations and wrapper bindings across multiple background simulation scripts (Diplomacy, Expansion) that were previously preventing them from executing properly.
- [Bugfix] **Script Optimization:** Cleaned up dead code and unused variables in faction generation scripts to streamline processing.

## [v3.3.0] War Contracts & Bounties Expansion

### 🚀 War Contracts Expansion

- [New] **Sector Raid:** Wipe out key hostile infrastructure or civilian vessels deep in enemy territory.
- [New] **Hunter Killer:** Hunt down a specialized enemy fleet causing problems for the allied faction.
- [New] **Resource Heist:** Infiltrate a hostile sector and forcefully harvest a massive amount of valuable resources.
- [New] **Distraction Carnage:** Draw massive enemy fleets to your location and survive a grueling 5-minute ambush.
- [New] **Black Box Retrieval:** Locate the wreckage of a destroyed prototype flagship deep in enemy space and extract its black box data before salvage crews strip it.
- [New] **Blockade Runner:** Break through a heavily fortified blockade to deliver emergency supplies to a covert listening post.
- [New] **Champion Duel:** Answer the call of an arrogant enemy commander and face off against a massively scaled Champion in a 1-on-1 duel.
- [New] **Sensor Deployment:** Sneak into the dead center of 3 distinct hostile sectors to deploy stealth sensor buoys.

### 💰 War Bounty Revamp

- [New] **Bounty Licenses:** The passive global war bounty system has been entirely overhauled into an interactive "Bounty License" mechanic.
- [New] **Per-Kill Payouts:** After securing your first kill against a faction with a global bounty, you will receive a 45-minute active Bounty License.
- [New] **Hunting Quotas:** You can now hunt and destroy up to 15 military targets under a single license. The license explicitly warns you every 5 minutes before expiration.
- [New] **Dynamic Reward Scaling:** The base credit reward scales strictly by distance from the core. Destroying standard military ships pays out the base reward, Dreadnoughts and Bosses pay out 5x, and Stations pay out 10x!
- [Update] **Civilian Immunity:** You can no longer farm bounties by destroying defenseless mining, trading, or civil transport ships. Only military and infrastructure targets yield payouts.
- [Update] **Galactic Politics UI:** The `[!]` tag has been replaced with `[BOUNTY]`. Hover tooltips now accurately display the "Per-Kill" value rather than a flat lump-sum.
- [Update] **HUD Alerts:** Jumping into an enemy sector that currently has an active global bounty will instantly push a text alert to your HUD, notifying you that the sector is an active warzone with high payouts.

### 🪲 Bug Fixes

- [Bugfix] **Small Tweaks & Fixes:** Various small bugfixes and tweaks across various War Contracts to ensure multiplayer and alliance compatibility.

## [v3.2.0]

### 🛠️ Architecture & Optimization

- [Optimized] **Progressive Materialization:** Completely overhauled the `cw_siege_injector_persistent.lua` API. When background sieges are mathematically won by a faction, they no longer force the server to physically load the sector into memory to flip the station ownership (which caused massive server stutters).
- [Feature] **Lazy Loading API:** Siege victories are now queued mathematically. When a player jumps into the conquered sector, the game seamlessly intercepts the loading screen and instantly hands the sector over to the victor. Zero stutter!

### 🚀 Mission Enhancements

- [Enhanced] **Deploy Minefield:** Improved the "Deploy Minefield" War Contract when jumping into an empty target sector. The mission now immediately spawns a hostile interceptor wave and provides explicit on-screen timer instructions (250s) to keep players engaged while the minefield deploys.
- [Polish] **Bulletin Board:** Fixed an ugly formatting issue across all War Contracts where the bulletin board would display unresolved `(${location.x}:${location.y})` variables instead of generic flavor text before the mission was accepted.

## [v3.1.2]

### 🪲 Bug Fixes

- [Bugfix] **Infinite Subspace Tear:** Fixed an oversight where the experimental Subspace Tear (Rift Hazard) generated during a War Crime event lacked a termination condition. It would permanently drain shields in the sector until manually deleted. The hazard now correctly dissipates once the primary target structure is destroyed and the anomaly is contained!
- [Bugfix] **Hazard Target Detection:** Fixed a logic oversight in `cw_rift_hazard.lua` where the hazard only scanned for Entities typed as Stations. It will now properly detect and deal damage to "Protection Platforms" (typed as Ships).

## [v3.1.1]

### 🪲 Bug Fixes

- [Bugfix] **Convoi Distress Signal API Error:** Fixed a critical server crash in `convoidistresssignal.lua` where `getMissionLocation()` was improperly called on the server environment. It has been safely bypassed by reading the global target coordinates, restoring the distress call event back to full functionality.

## [v3.1.0]

### ⭐ Features

- **Distress Call Escalation:** If you ignore an NPC distress call for too long, there is a chance the attackers will establish a permanent Pirate Forward Operating Base (FOB) in that sector, turning it into a hazard zone!
- **Bounty Hunter Ambush:** If you gain terrible reputation with a military faction during wartime, they might dispatch a small elite bounty hunter squad to ambush you directly in hyperspace upon entering a new sector!
- **Refugee Convoy Gratefulness:** Successfully escorting a refugee convoy to safety now grants a 1-hour minor buff called "Hero of the People", granting +10% trade prices at that faction's stations.
- **Galactic Politics Sabotage:** *(Requires Cosmic Overhaul)* You can now pay a 5,000,000 Credits bribe to the Smuggler's Market to intentionally lower the relationship between two random NPC factions, sparking proxy wars!

## [v3.0.12]

### 🪲 Bug Fixes

- [Bugfix] **Fire Rate API Error:** Fixed a core mathematical error across multiple missions (Eclipse Vanguard, Decapitation Strike, Frontline Siege) where extreme `FireRate` multipliers were being accidentally applied as flat additive numbers instead of percentages, preventing those bosses from properly scaling their weapon attack speeds.
- [Bugfix] **Volatile Shield API Error:** Discovered and fixed a critical bug in `cw_eclipse_vanguard.lua`, `cw_refugeeconvoy.lua`, and `siegeevent.lua` where the `shieldMaxDurability` property was manually modified to boost boss shields. Due to engine architecture, this caused the shields to instantly wipe themselves to 0 upon taking any block damage. They have been swapped to the stable `addBaseMultiplier` API.

## [v3.0.11]

### Fixed, Changed & Balanced

- [Bugfix] **Alliance UI Cosmetic Fix**: Fixed a minor logic flaw in `galacticpolitics_tab.lua` where Player Alliances were incorrectly labeled as "Player Factions" in the diplomacy tooltips.
- [Changed] **Multiplayer UI Bloat Reduction**: The Galactic Politics conflict tracker will no longer display single-player factions to prevent the UI from becoming unreadable on heavily populated multiplayer servers. The tracker now exclusively tracks NPC Factions and Player Alliances.
- [Balance] **Mercenary Payout Nerf**: Heavily reduced the base payout for destroying ships (from 25,000 to 10,000) and stations (from 250,000 to 100,000) while enlisted as a mercenary to prevent game-breaking wealth generation at the galactic core.
- [Balance] **Hybrid Captain Scaling (Synergy)**: Enlisted ship payouts now scale dynamically based on the commanding Captain's Tier and Level, directly synergizing with the overarching Cosmic scaling logic!
- [Balance] **Mercantile Trait Nerf**: Reduced the payout multiplier of Mercantile factions from 3x (300%) down to 1.5x (150%).
- [Balance] **High-Profile Bounty Nerf**: Reduced the completion multiplier for confirming high-profile bounties on Stations (from 5x to 3x) and Bosses/Battleships (from 3x to 2x).

## [v3.0.10]

### Fixed & Refactored

- **Architecture Audit & Cleanup (Part 2)**: This update is a follow-up to the v3.0.9 release, catching 13 background and entity scripts that were missed during the initial audit.
- **Event Routing Desync Fix**: Widespread architectural violation resolved. Previously, scripts like `cosmicwardiplomacy.lua`, `cosmicwarnews.lua`, and `cosmicwarcontroller.lua` were defining global wrappers for standard engine callbacks (`initialize`, `updateServer`, `getUpdateInterval`), which shadowed the native namespace hooks and caused catastrophic event routing failures under the hood. All illegal global wrappers have been permanently stripped. These scripts now natively bind to the Avorion engine via their official module namespaces as intended.
- **Namespace Injection Compliance**: Repositioned `getUpdateInterval` within `rebuildstations.lua` to be properly encapsulated inside its module namespace, ensuring correct VFS overwrite behavior.

## [v3.0.9]

### Fixed

- Fixed a massive oversight affecting almost all War Contract missions where destroyed target ships were still being counted as "alive" because the game engine preserved their tracking tags on the resulting wreckages. The tracking scripts now explicitly verify if the entities are living Ships or Stations, allowing missions to finally complete successfully!
- **Silent Event Failures**: Fixed a major engine-level bug where 5 major events (Fleet Clash, Arms Deal, Diplomatic Sabotage, Refugee Convoy, and Stranded Flagship) would trigger their notification but fail to spawn any ships. Global wrappers for delayed engine callbacks have been correctly injected, restoring these events to full functionality.
- **RPC Desync**: Corrected a namespace architecture violation in `cw_eclipse_vanguard.lua` where an RPC client-call was being bound to a local table without an engine-level namespace declaration. The script is now properly namespaced, ensuring the cinematic banner triggers correctly on the client side without silent UI failures.

## [v3.0.8]

### Changed

- Nerfed Shield Jammer (Electronic Warfare) event deployment chance from 35% to 10% during Sieges, and from 50% to 15% during Fleet Clashes.
- Nerfed Shield Jammer debuff duration from 20 seconds to 10 seconds.

### Fixed

- Corrected a critical namespace bug inside `cw_shieldjammer.lua` that completely blocked the Avorion engine from triggering the script's `terminate()` routine, leading to shields permanently remaining at 0 for the remainder of the instance.

## [v3.0.7]

### 🐛 Bug Fixes

- [Bugfix] **Linux Case Sensitivity:** Fixed a critical crash on Linux dedicated servers where `cw_wreckagefield.lua` and `siegeevent.lua` incorrectly requested a lowercase `include("sectorgenerator")` instead of the strictly capitalized vanilla path.

## [v3.0.6]

### 🐛 Bug Fixes

- [Bugfix] **Bounty Payout Crash:** Fixed a critical server crash in `cw_bountypayouts.lua` when attempting to award bounties for destroying boss entities. The script incorrectly referenced an `isBoss` property on the entity object directly instead of using the API-compliant `entity:getValue("is_boss")` method.

## [v3.0.5]

### 🐛 Bug Fixes & 🛠️ Optimization

- [Bugfixed] **API Property Integrity:** Fixed a script-breaking error during the Refugee Convoy (`cw_refugeeconvoy.lua`) and Siege (`siegeevent.lua`) events where scripts were improperly assigning a read-only `maxDurability` property and a non-existent `shieldMaximum` property on ships, causing fatal exceptions. Hull scaling has been corrected to use the officially supported `maxDurabilityFactor` API under the `Durability` component, and shield scaling correctly utilizes `shieldMaxDurability`.

## [v3.0.4]

### 🐛 Bug Fixes & 🛠️ Optimization

- [Bugfixed] **Dreadnought Boss Target Errors:** Fixed a critical server log spam and stutter issue where the Dreadnought Boss (`dreadnoughtboss.lua`) was attempting to check the AI property `isAttacking` instead of the correct native API `isAttackingSomething`. This resulted in the boss repeatedly failing to evaluate targets properly during an attack and throwing errors twice per second.
- [Optimized] **Battlefield HUD Sync:** The Cinematic Battlefield HUD now accurately reads absolute `startTime` data provided by the newly updated Cosmic Vault API. This guarantees flawlessly synchronized visual siege progression for players who jump into a contested sector mid-siege, removing the previous visual glitch where the bar would mistakenly assume the siege had just begun.

## [v3.0.3]

### 🐛Bug Fixes, ⚖️Balancing and ⚙️Adjustments

- [Bugfixed] **Event Scheduler Desync:** Fixed an issue where spontaneous event timers (Fleet Clashes, Refugee Convoys, etc.) were reliant on server tick accumulation, which caused timers to stall or desync when the server lagged. Event timers now utilize persistent, absolute `Player().playtime` stamps to ensure flawless timer continuation and pacing even across server restarts and lag spikes.
- [Bugfixed] **Siege Weather Memory Leak:** Fixed a critical issue where the dynamic Eclipse weather applied during Sieges was never properly cleared when the event concluded because the script's `onRemove` callback was not exposed to the engine API. Siege Weather now correctly dissipates when the event ends, preventing massive visual bloat and sector bloat.
- [Bugfixed] **Eclipse Vanguard Shield Bug:** Fixed a syntax error where the Vanguard Boss was assigned a non-existent `shieldMultiplier` property instead of correctly multiplying its actual `shieldMaxDurability`, leaving it vulnerable. Also reduced its FireRate multiplier from 500x down to a safer 50x to prevent massive server-side packet spam and simulation freezing.
- [Balancing] **Siege Troop Transports:** Troop Transport boarding timers now scale dynamically with the defending station's max durability. Instead of a flat 60 seconds to board, transports now require an additional 1 second per 100,000 HP of the station's hull (capped at 5 minutes), giving defenders realistic time windows to defend massive fortified citadels before they are annexed.
- [Balancing] **Dynamic War Economy Scaling:** Freelance Mercenary Payouts and High-Profile War Bounties are no longer flat rates! Both systems have been completely rebalanced to scale exponentially based on the faction's distance to the Galactic Core. Fighting for an Outer Rim faction will still yield standard rates, but shedding blood for inner-core empires will yield massive payouts scaling up to **26x** the base rate.
- [Changed] **Living Galaxy Simulation Rates:** The default CCM configuration values governing background simulations (Diplomacy, Ceasefires, Bounties, News, Trade Sanctions) have been heavily rebalanced. Previously, the simulation evaluated only 10 faction pairs every 20 minutes, which resulted in a stagnant galaxy where wars rarely broke out organically. The new default intervals have been lowered to **5-10 minutes**, and the default faction pairing batch has been increased to **50**. *Note: These are just the new out-of-the-box defaults to provide a truly living, breathing galaxy; players can still freely adjust these timers themselves via the CCM menu!*

## [v3.0.2]

### 🐛 Bug Fixes & 🛠️ Optimization

- [Bugfixed] **War Contract Diplomacy Exploit:** Fixed a major exploit where players with "Excellent" standing could accept War Contracts against a faction, fly into the sector, and destroy the mission targets without retaliation. Accepting *any* of the 14 War Contracts is now explicitly treated as an act of war: it will instantly plummet your reputation with the target faction by `-200,000`, forcing an immediate hostile state. A high-priority UI warning and in-game chat notification have been added to prevent players from accidentally declaring war.

## [v3.0.1]

### 🐛 Bug Fixes & 🛠️ Optimization

- [Bugfixed] **Instance Crash:** Fixed a critical bug causing single-player instances and dedicated servers to crash via `EXCEPTION_ACCESS_VIOLATION`. The `CosmicVaultTask.RunAsync` coroutine wrapper was improperly used inside background war simulation scripts (`cosmicwarceasefires.lua`, `cosmicwardiplomaticsanctions.lua`, `cosmicwarbounties.lua`) without a pumping mechanism, causing dangling threads to violate memory boundaries when garbage collected. These have been rewritten to execute safely and synchronously.

## [v3.0.0]

### **The Arsenal Update**

*The most massive expansion to Cosmic War yet, introducing mercenary enlistment, warbonds, brand new contract missions, horrifying new events like the Eclipse Vanguard, and a completely rebalanced war economy.*

### ✨ New Features & 📦 Content Additions

- [Feature] **War Heat Frontline Sieges:** When a faction's War Heat drops to critical levels (`relations <= -80000`), they will now actively spawn heavy strike fleets (Frontline Sieges) directly into hostile sectors to assault enemy targets dynamically.
- [Feature] **PvP & Alliance Integration:** Reputation shifts are now actively mirrored onto the player's active Alliance! No more swapping to personal ships to commit war crimes without implicating your alliance. All PvP logic is handled safely through the core `CosmicVaultFaction` API.
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

- [Optimized] **Massive Fleet Performance Scaling:** Heavily reduced the background tick frequency (`getUpdateInterval`) of all 6 Cosmic War specific contracts (Frontline Siege, Propaganda, etc.) from checking every 1.0 seconds to 5.0 seconds. This drastically reduces CPU overhead for busy multiplayer servers with huge player fleets.
- [Optimized] **Performance & TPS Optimization:** Drastically reduced server load during late-game and high-intensity scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s to 60.0s) into 5 major mission and background scripts (`cw_breakthrough`, `cw_forcerecon`, `cw_frontlinesiege`, `cw_highvaluedefection`, `rebuildstations`). These scripts previously looped 60 times a second without throttling.
- [Bugfixed] **Truthiness Logic Stabilized:** Applied strict explicit float comparisons (`> 0.5`) inside `galacticpolitics_tab.lua` to resolve truthiness evaluation bugs that could destabilize the UI when sorting zero-values.
- [Bugfixed] **Architecture Flaws:** Fixed a critical architecture flaw where `cosmicwartraits.lua` exposed a global `initialize()` wrapper, preventing vanilla server initialization when included.
- [Bugfixed] **Engine Crash Fixes:** Fixed multiple API Avorion Indexes across various scripts that could cause C++ attempt to index or attempt to call engine crashes (e.g. corrected stat modifiers, entity bias functions, invalid faction setters, removed native calls to non-existent functions, and corrected C++ matching distance checks).
- [Bugfixed] **Hardened Faction Relations:** Migrated over 15 mission/event scripts to use the hardened `CosmicVaultFaction.changeRelations()` API, removing dangerous `math.max` fallback logic that could crash the engine on boundary overflows.
- [Bugfixed] **Mission Trigger Logic:** Fixed `cw_deploy_mines.lua` trigger condition not incrementing the deployment counter, and `cw_propaganda_broadcast.lua` evaluating every server tick instead of every second. Both missions now progress and complete properly.
- [Bugfixed] **Mission Generation Locks:** Fixed `cw_forcerecon.lua` "Force Recon" mission soft-locking due to a missing station script (`sensorarray.lua`). The mission now correctly generates a Military Outpost as the covert listening post.
- [Bugfixed] **Targeting Parsing:** Fixed `dreadnoughtboss.lua` incorrectly parsing varargs into a table when fetching enemies, resulting in incomplete target lists.

- [Bugfixed] **Cosmic Codex Loading Crash:** Fixed missing global definitions (e.g. `entities`, `rangeType`) in the codex files that prevented the encyclopedia from loading correctly and crashed the UI.
- [Bugfixed] **Missing AI Scripts (Ghost AI Bug):** Fixed a critical issue where Flagships generated during *Stranded Flagship* and *Decapitation Strike* events were assigned a missing vanilla script (`story/boss.lua`). They now properly inject the new `ai/dreadnoughtboss.lua` behavior script.
- [Bugfixed] **Multiplayer Synchronization:** Replaced all instances of `math.random` with Avorion's deterministic `random()` engine (including `cw_militaryoutpost.lua`) to prevent massive multiplayer client/server desyncs when generating loot, stats, and enemies.
- [Bugfixed] **UI Polish:** Faction names will no longer display raw translator comments (e.g., `/* faction name */`) inside the Galactic Politics tab.

- [Bugfixed] **VFS Compliance:** Stripped redundant global wrapper functions from namespaced scripts to prevent silent double-execution logic loops and engine crashes.
