# ⚔️ 🌌 Cosmic War - Detailed Mechanics

Welcome to the **Cosmic War** official player guide! This page covers War Heat, Diplomacy, Mercenary Contracts, and Dreadnought Invasions.

---

## 📑 Table of Contents
- ⚔️ War Heat System
- 🎭 Dynamic Faction Traits
- 🎖️ Mercenary Contracts
- 🛡️ Dreadnought Invasions
- 🌐 Galactic Politics
- 🌌 Cosmic Vault Synergy

---

## ⚔️ War Heat System
<details>
<summary><b>Click to expand</b></summary>

Factions are no longer static. They actively build tension with their neighbors.

### ⚙️ Mechanics
- Every faction has a "War Heat" meter with bordering factions.
- Border skirmishes, intercepted traders, and differing traits (Aggressive vs Peaceful) passively increase War Heat over time.
- Once War Heat reaches 100%, a formal Declaration of War is broadcast on the Galactic News Network.
- Warring factions will actively dispatch fleets to destroy each other's stations and claim territory.
</details>

## 🎭 Dynamic Faction Traits
<details>
<summary><b>Click to expand</b></summary>

Factions are no longer generic entities; they now spawn with distinct **Custom Traits** that drastically alter their behavior, diplomacy, and the background simulation! You can view a faction's traits by hovering over them in the Diplomacy UI.

### ⚙️ Mechanics
- **Warmonger / Pacifist / Isolationist / Opportunist:** Standard behavioral traits that dictate how aggressively they build War Heat or seek ceasefires.
- **Imperialist:** These factions aggressively expand their borders! You will often see them claiming empty or uncharted sectors and constructing new outposts.
- **Entrenched:** Rather than expanding outward, these factions heavily fortify their core territory, continuously building dense networks of defensive stations near their home sector.
- **Vengeful:** Do not anger them! If you or an AI faction go to war with a Vengeful empire, their pride prevents them from accepting ceasefires—wars are fought to the bitter end.
- **Mercantile:** Profit is paramount. If you sign a Mercenary Contract to fight *for* a Mercantile faction, they will gladly pay you **3x the standard bounty payout** for every enemy ship and station you destroy. Same effect applies to War Contracts!
- **Xenophobic:** Extremely dangerous. They experience a continuous, severe degradation in relations with all known neighbors, rendering alliances impossible and guaranteeing eventual unprovoked wars.
</details>

## 🎖️ Mercenary Contracts
<details>
<summary><b>Click to expand</b></summary>

Profit from the chaos by signing up as a mercenary.

### ⚙️ Mechanics
- Check the Bulletin Board in any warring faction's territory to find Mercenary Contracts.
- **Defensive Contracts:** Protect a sector from an incoming invasion fleet.
- **Offensive Contracts:** Join an invasion fleet and assist in destroying an enemy station.
- **Assassination:** Hunt down specific enemy commanders behind enemy lines.
- Completing contracts pays massive bounties and significantly boosts your reputation with the hiring faction (while devastating your reputation with the target).
</details>

## 🛡️ Dreadnought Invasions
<details>
<summary><b>Click to expand</b></summary>

During an active war, factions will launch massive invasion fleets. These fleets mathematically scale their size to exactly match **100%** of the defensive strength of the target sector!

### ⚔️ Combat Mechanics
- **Electronic Warfare (Shield Jammer):** When an invasion drops into a sector, there is a 50% chance they activate an EMP. If you see the yellow warning text, **ALL** defending shields (including yours!) are pinned to 0 durability for 20 seconds. Survive the ambush!
- **Siege Dreadnoughts:** Invasions are spearheaded by **Dreadnoughts**, colossal capital ships spawned with a massive 5x multiplier to their shields to tank station point-defense arrays.
- **Cinematic Battlefield HUD:** While in an actively contested sector, your screen will display a cinematic 100% split Blue/Red progress bar tracking the exact remaining time until the sector flips ownership.
- Dreadnoughts cannot be destroyed quickly. You will need high Omicron weapons or specialized torpedoes to bring down their boosted shields.
- If an invasion fleet is not stopped, they will systematically destroy every station in the sector, effectively wiping it off the map.
</details>

## 🌐 Galactic Politics
<details>
<summary><b>Click to expand</b></summary>

Use the new Galactic Politics UI tab to track the status of all known factions.

### ⚙️ Features
- View all active wars, alliances, and War Heat levels.
- **Covert Funding:** As a wealthy player, you can secretly fund rebellions or donate credits to a faction's war effort, directly influencing the outcome of the war without firing a shot.
</details>

## 🚀 Dynamic Territory Expansion
<details>
<summary><b>Click to expand</b></summary>

Factions can now actively conquer enemy sectors and permanently expand their borders on the Galaxy Map.

### ⚙️ Mechanics
- **Background Conquests:** Contested zones have a hidden siege timer. If time runs out and no player intervenes, the station flips ownership mathematically, expanding the faction's borders naturally.
- **Physical Sieges:** If a player enters a contested zone, a Siege Event is triggered!
- **Troop Transports:** Three massive, heavily shielded AI transports will warp in and charge the defending station. If they survive the station's point-defense for 60 seconds (scaling up to 5 minutes based on the station's hull HP) at close range, they physically board and capture the station!
</details>


---

## 🔗 Cosmic Series Integration & Audit 3.0 Updates
<details>
<summary><b>Click to expand</b></summary>

During the Cosmic Series Final QA Audit (v3.0+), several massive backend systems were standardized across all mods:

### 📖 Cosmic Codex Integration
All deep lore, stat blocks, and dynamic recipes have been fully integrated into the in-game **Cosmic Codex**. You no longer need to tab out of the game to read these features; they will natively update and unlock inside your Codex UI as you progress!

### 🔒 Network Safety & Anti-Cheat
- **Math.Random Fix:** We systematically replaced all unstable Lua `math.random` calls with Avorion's deterministic `random():getInt()` generation sequence. This guarantees 100% synchronization on Multiplayer Dedicated Servers and prevents cascading desyncs during massive fleet spawns.
- **Callable Validation:** UI and background scripts have been fully hardened. Malicious clients can no longer spoof "free" remote calls; the server actively verifies execution contexts before processing any requests, sealing multiple Arbitrary Code Execution (ACE) vulnerabilities.

### 🛠️ Vanilla Bug Fixes
- **Scout Mission Fix:** We patched a massive, long-standing vanilla bug where Scout Missions would completely skip and ignore Faction Headquarters sectors because the native dialogue trees were missing the template definition.
</details>


---

### Diplomacy Thread Safety
Background diplomacy threads have been fully synchronized with the main Avorion engine, permanently eliminating `EXCEPTION_ACCESS_VIOLATION` server hangs during massive sector relation updates.

### Breaking Planetary Defenses
If you see a Planetary Shield Generator during an invasion, destroy it immediately! All other stations are invincible until it falls.

## 🌌 Cosmic Vault Synergy
- **Deep Economy Warfare:** Market collapses and starvation natively trigger desperation invasions via the Cosmic Vault Economy simulation! Factions with 100+ Famine Scores will launch massive assaults on wealthy neighbors to survive.
- **Weather-Assisted Boarding:** The CosmicVaultWeather API allows players to utilize weather events for sieges. If a DarkMatterFog or IonStorm hits a sector, the defending station's boarding defense multiplier is slashed by 50%!
- **Commodore Siege Leadership:** If you are defending an allied faction's sector during a siege and ultimately fail, parking a ship with a Commodore captain in the sector will reduce the economic Famine penalty inflicted on the defenders.

## Synergy Update
- **Wartime Propaganda Beacons**: There is a 5% chance for a narrative Cosmic Chronicles beacon to dynamically spawn after a siege resolves, immortalizing the battle.
- **Inherent Imperialism**: The Eclipse (Ascendancy) faction is now hardcoded as Imperialist and Vengeful. They will relentlessly expand their territory and will absolutely never accept ceasefires.
- **Wartime Shortages:** The destruction of supply convoys will cause massive shortages in military and medical goods at Trading Posts and Equipment Docks. If you are a trader, you can make billions smuggling these goods to desperate stations!
- **Weaponized Subspace Tears:** At Critical War Heat, warring factions may detonate experimental subspace weapons, tearing the fabric of space and unleashing localized Rift hazards.
- **Dynamic Frontline Sieges:** When a war reaches its absolute boiling point, factions will proactively spawn massive siege fleets directly into their rival's occupied sectors, creating dynamic combat hazards outside of normal missions.
- **Alliance PvP Repercussions:** Be careful who you anger! Triggering a diplomatic incident or destroying civilian convoys will permanently damage relations not just for you, but dynamically spread the consequences to your active Player Alliance.
- **War Contracts - Subspace Containment:** When a rift tears in a warzone, factions will issue high-paying War Contracts to secure emerged Ancient Tech platforms and contain the anomaly.
