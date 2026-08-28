# ⚙️ Cosmic War - Detailed Features

Welcome to the **Cosmic War** official wiki! This page contains the full, detailed documentation for the faction-conflict simulation module in the **Cosmic** mod series.

---

## 📑 Table of Contents

- [Mod Identity & Design Goals](#mod-identity--design-goals)
- [Architecture Summary](#architecture-summary)
- [Full Feature Breakdown](#full-feature-breakdown)
- [Server & Performance Guidelines](#server--performance-guidelines)
- [Dependencies & Compatibility](#dependencies--compatibility)
- [Installation & Troubleshooting](#installation--troubleshooting)
- [Development Status](#development-status)

---

## 🧬 Mod Identity & Design Goals

**Primary Focus:** Living, persistent AI faction politics and war-state simulation.

**Core Goals:**

1. **Active Politics:** Make galaxy politics feel dynamic and alive instead of static.
2. **Sustained Cycles:** Produce meaningful war and cooling cycles over long campaign sessions via scripts properly attached to the global `Galaxy` loop.
3. **Player Visibility:** Surface war-state consequences directly to players via news broadcasts, bounties, and sanctions pressure.
4. **Configurability:** Remain highly configurable and server-operator friendly through the Cosmic Configuration Menu.
5. **Safe Compatibility:** Preserve ecosystem compatibility by favoring non-invasive wrappers and safety guards over hard overwrites.

---

## 🏗️ Architecture Summary

The mod utilizes a layered simulation model to bring the galaxy to life:

1. **Faction-Level Baseline Traits:** Seeded and maintained to define AI personality.
2. **Sector-Level Pressure Loops:** Dynamically escalate local rivalries.
3. **Global Diplomacy Drift:** Keeps galactic politics moving naturally over time.
4. **War-Side Effects:** Systems like sanctions, bounties, bulletins, and ceasefires create visible, actionable outcomes.
5. **Cross-Mod Bridges (Optional):** Influences command prediction overlays when combined with other Cosmic mods.
6. **Dynamic Invasions & Scaling:** Vanilla invasions spawn a static number of small ships. **Cosmic War** introduces advanced mathematical scaling:
   - **Strength Matching:** Invasions analyze the total combined Omicron and Volume of all defending stations and ships in the sector, dynamically adjusting the invading fleet's size and ship volume to match **100%** of the defending force.
   - **Siege Dreadnoughts:** Large invasions spawn specialized Dreadnoughts with 5x shield multipliers to survive station point defense.
   - **Shield Jamming (Surprise Attacks):** Invasions have a 50% chance to deploy Electronic Warfare, instantly locking all defending (including player and alliance) shields to `0` for the first 20 seconds of the assault!
   - **Cinematic Battlefield HUD:** Entering a contested War Zone attaches a 100% split Red/Blue UI Bar to your screen, visually tracking the siege duration and dramatically broadcasting Sector captures or defenses.

*This architecture produces a cyclical macro behavior pattern:*
**Tension → War Pressure → Side Effects → Détente Potential → Re-escalation.**

---

## ⚙️ Full Feature Breakdown

### ⚔️ 1) War-Oriented AI Faction Seeding

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/factions.lua`

**What it does:**
Injects and maintains faction-level war metadata and Custom Traits for AI factions so behavior trends are less random and more identity-driven over time. Factions dynamically analyze their vanilla generation parameters (e.g., `greedy`, `aggressive`) to assign one of 9 distinct Custom Traits.

**The 9 Dynamic Traits:**

- **Warmonger / Pacifist / Isolationist / Opportunist:** Core stances that heavily influence War Heat buildup and ceasefire likelihood.
- **Imperialist:** Frequently claims empty sectors and natively constructs new outposts.
- **Entrenched:** Fortifies existing territory by continuously constructing defensive stations.
- **Mercantile:** Pays triple (3x) standard rates for all mercenary contracts (Bounties & War Contracts).
- **Vengeful:** Absolutely refuses to negotiate ceasefires once a war begins.
- **Xenophobic:** Relations naturally decay with all known factions, guaranteeing eventual unprovoked wars.

**Dormant Trait Revival:**
Cosmic War officially reactivates 4 unused vanilla traits (`Sadistic/Sympathetic`, `Strict/Forgiving`, `Smart/Dumb`, `Active/Passive`).

- **Active/Passive:** Dictates how frequently a faction will attempt territory expansions.
- **Strict/Forgiving:** Modifies their likelihood to accept peace treaties or hold eternal grudges.
- **Smart/Dumb:** Dictates their strategic intelligence when declaring wars against superior forces.
- **Sadistic/Sympathetic:** Determines whether they offer bonus payouts—or severe penalties—for mercenaries destroying unarmed civilian ships.

**Typical Stored Values:**

- `cw_enabled`
- `cw_war_bias`
- `cw_diplomatic_polarity`
- Trait indices via Cosmic Vault API (`cw_imperialist`, etc.)

**Gameplay Impact:**

- AI factions have vastly differing, mechanically-backed personalities.
- Rivalries become more coherent in long campaigns.
- Better continuity between isolated events and long-term politics.
- The UI seamlessly renders these traits natively via the `CosmicVaultFaction` API.

</details>

### ⚔️ 2) Sector War-Pressure Controller

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/sector/init.lua`
- `data/scripts/sector/cosmicwarcontroller.lua`

**What it does:**
Runs periodic sector-level scans and applies pressure to selected faction pairs when local conflict conditions align.

**Behavior Goals:**

- Encourage natural hotspot emergence.
- Avoid spam via spacing/cooldown logic.
- Prevent every loaded sector from escalating identically.

**Gameplay Impact:**

- Frontlines and contested regions emerge organically.
- Different sectors can diverge into quiet vs. volatile states.

</details>

### 🤝 3) Persistent Diplomacy Drift

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/player/init.lua`
- `data/scripts/player/background/cosmicwardiplomacy.lua`

**What it does:**
Periodically evaluates random/eligible faction-pair subsets and nudges diplomacy over time.

**Why it matters:**
Without drift, diplomacy can remain too static between discrete scripted events.

**Gameplay Impact:**

- Politics evolve continuously.
- Rivalry maintenance feels systemic, not scripted-only.

</details>

### ⚔️ 4) War News / Broadcast Layer

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwarnews.lua`

**What it does:**
Publishes periodic war bulletins to improve player awareness of macro conflict shifts.

**Implementation Style:**

- Collects currently hot conflicts.
- Chooses one using stable randomization.
- Broadcasts informational message server-wide.

**Gameplay Impact:**

- Players can react strategically to political shifts.
- Background simulation becomes visible and actionable.

</details>

### 5) Diplomatic Sanctions Pressure

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`

**What it does:**
Applies sanction-like pressure behavior tied to entrenched rivalries and hostile diplomatic states.

**Gameplay Impact:**

- Wars have economic/diplomatic consequences, not only combat outcomes.
- Political hostility influences broader strategic conditions.

</details>

### 6) Ceasefire / Détente Logic

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwarceasefires.lua`

**What it does:**
Allows conditional de-escalation when hostility recovers and ceasefire chance criteria are met.

**Gameplay Impact:**

- Conflict cycles can resolve naturally.
- The galaxy does not lock permanently into one escalated state.

</details>

### ⚔️ 7) War Bounty Generation (Bounty Licenses)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/server/background/cosmicwarbounties.lua`
- `data/scripts/sector/cw_bountypayouts.lua`
- `data/scripts/player/background/cw_bounty_tracker.lua`

**What it does:**
Transforms the global geopolitical state into highly interactive hunting licenses. When a faction has an active global bounty against their enemy, destroying your first valid military target (Ship, Station, Boss) automatically provisions a **Bounty License** to the player or alliance.

**Mechanics:**

- **Hunting Quota:** The license tracks progress (e.g. 0/15) across all sectors.
- **Expiration:** You have a strict time limit (45 minutes) to complete the quota, with HUD notifications every 5 minutes.
- **Dynamic Payouts:** Base rewards scale based on distance from the core. Standard military ships pay out 1x, Dreadnoughts and Bosses pay out 5x, and Stations pay out 10x.
- **Civilian Immunity:** Bounties only trigger on military targets; defenseless mining and cargo ships are ignored.

**Gameplay Impact:**

- Gives players direct, massive incentives to participate in active wars.
- Provides engaging, on-screen progression metrics (HUD alerts, UI trackers) rather than passive, invisible logic.

</details>

### 8) Runtime Cleanup / Compatibility Hooks

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/sector/factionwar/temporarydefender.lua`
- `data/scripts/sector/background/rebuildstations.lua`

**What it does:**
Adds lifecycle-safe wrappers in selected war-adjacent paths to reduce stale wartime leftovers and transition artifacts.

**Gameplay Impact:**

- Cleaner war transitions.
- Lower chance of lingering war-state artifacts.

</details>

### 🎖️ 9) Admin / Diagnostics Command

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/commands/cosmicwarstatus.lua`

**Command:** `/cosmicwarstatus`

**What it provides:**

- Quick status and health visibility.
- Easier balancing and debug workflows.
- Sanity checks for running servers.

**Stability Hardening:**
The command path includes readiness guards (e.g., galaxy API availability checks) for safer early lifecycle behavior.
</details>

### 🚀 10) Dynamic Territory Sieges & AI Boarding

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/lib/cosmicvaultterritory.lua` (via Cosmic Vault)
- `data/scripts/events/siegeevent.lua`
- `data/scripts/entity/ai/trooptransport.lua`

**What it does:**
Allows factions to actively conquer enemy sectors and permanently expand their borders on the Galaxy Map. By utilizing mathematically abstracted background timers, the server naturally shifts influence without keeping thousands of sectors loaded (avoiding the "Sector Alive" crash trap).

**Gameplay Impact:**

- **Background Conquests:** Contested zones have a hidden siege timer. If time runs out, the station flips ownership mathematically.
- **Physical Sieges:** If a player enters a contested zone, the engine triggers a Siege Event.
- **Troop Transports:** Three massive, heavily shielded AI transports will warp in and charge the defending station. If they survive the station's point-defense for 60 seconds (scaling up to 5 minutes based on the station's hull HP) at close range, they physically board and capture the station!
- **Dynamic Borders:** Once a station flips ownership, the Galaxy Map influence border naturally expands.
- **Zero-Stutter Performance:** Built on the V4 Progressive Materialization architecture, all background station flips and territory expansions are queued globally. When a player jumps in, the queue is instantaneously executed during the loading screen, completely eliminating the massive server lag spikes caused by native background sector loading.

</details>

### 11) Stability Hardening

<details>
<summary><b>Click to expand details</b></summary>

Recent iterations include:

- Safer startup behavior during early server lifecycles by waiting for the **Cosmic Vault** `factions_ready` flag before running simulation steps.
- Absolute abandonment of expensive `Galaxy():getFactions()` loops in favor of the performant, shared Cosmic Vault index cache (`Server():getValue("factions")`).
- Corrected global simulation attachment (`galaxy/init.lua` instead of `server/init.lua`).
- Defensive checks in background loops.

**Gameplay/Ops Impact:**

- Fewer nil-method crashes at startup.
- Stronger behavior in heavily modded stacks.

</details>

### 🔗 12) Cosmic Overhaul Synergy (Bridge Layer)

<details>
<summary><b>Click to expand details</b></summary>

**Primary bridge files:**

- `data/scripts/lib/cosmicwareconomybridge.lua`
- `data/scripts/lib/cosmicwarcaptainbridge.lua`

**Typical wrapper targets (when present in the load stack):**
Command prediction hooks in simulation scripts (e.g., trade, scout, travel, refine, mine, salvage variants).

**Design Intent:**

- Emphasizes non-invasive composition over hard overwrites.
- The original prediction path runs first.
- The bridge applies bounded post-processing only when enabled and when the context is valid.
- Graceful no-op fallback occurs when disabled or when missing context.

**High-Level Effect:**

- Command planning outputs can reflect war-heat pressure more clearly.
- Baseline behavior is safely preserved when bridge toggles are disabled.

</details>

### ⚔️ 13) Dynamic War Contracts (Missions)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/entity/bulletinboardmissions.lua`
- `data/scripts/player/missions/cw_forcerecon.lua`
- `data/scripts/player/missions/cw_borderskirmish.lua`
- `data/scripts/player/missions/cw_resourcesabotage.lua`
- `data/scripts/player/missions/cw_interception.lua`
- `data/scripts/player/missions/cw_breakthrough.lua`
- `data/scripts/player/missions/cw_frontlinesiege.lua`
- `data/scripts/player/missions/cw_highvaluedefection.lua`
- `data/scripts/player/missions/cw_decapitationstrike.lua`

**What it does:**
Injects custom, highly-scaled combat missions directly into Avorion's native Bulletin Board mission pools based on the current macro-level **War Heat** between the station's owner and their rival faction.

**Available Contracts:**

- **War Heat > 0.15:** *Force Recon* (Scout a hostile listening post) & *Sensor Deployment* (Sneak into the dead center of 3 hostile sectors).
- **War Heat > 0.25:** *Border Skirmish* (Eliminate an enemy border patrol).
- **War Heat > 0.35:** *Resource Sabotage* (Destroy an enemy mining operation), *Resource Heist* (Infiltrate and steal large quantities of resources), & *Deploy Minefield* (Deploy and defend a minefield).
- **War Heat > 0.45:** *Interception* (Destroy enemy supply convoy), *Breakthrough* (Defend allied supply convoy), *Sector Raid* (Wipe out enemy infrastructure), *Black Box Retrieval* (Extract data from a destroyed prototype), & *Propaganda Broadcast* (Hack comms array).
- **War Heat > 0.60:** *Frontline Siege* (Assault a dynamically scaled enemy FOB), *Hunter Killer* (Hunt a specialized fleet), & *Distraction Carnage* (Survive a massive 5-minute ambush).
- **War Heat > 0.80:** *High-Value Extraction* (Holdout survival for defector), *Assassinate General* (Kill a high-ranking target), *Supply Line Raid* (Destroy logistics hubs), & *Blockade Runner* (Deliver supplies through a heavy blockade).
- **War Heat = 1.00:** *Decapitation Strike* (Ultra-hard Flagship Boss), *Extract POW* (Rescue prisoners from a heavily guarded facility), & *Champion Duel* (1-on-1 duel with a scaled boss).

</details>

### ⚔️ 14) Dynamic War Events (Flashpoints)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/player/eventscheduler.lua`
- `data/scripts/events/cw_fleetclash.lua`
- `data/scripts/events/cw_refugeeconvoy.lua`
- `data/scripts/events/cw_strandedflagship.lua`
- `data/scripts/events/cw_armsdeal.lua`
- `data/scripts/events/cw_diplomaticsabotage.lua`

**What it does:**
Injects new spontaneous events into Avorion's global event scheduler. As players explore the galaxy, they will encounter live warzones, covert operations, and distress calls directly tied to the macro political simulation.

**Available Events:**

- **Fleet Clash (Heat > 0.60):** Massive enemy strike fleets jump into active AI sectors.
- **Refugee Convoy (Heat > 0.40):** Civilian freighters are ambushed by hunter fleets.
- **Stranded Flagship (Heat > 0.80):** A severely damaged dreadnought boss is discovered vulnerable, with a repair fleet en route.
- **Arms Deal (Heat > 0.20):** An illegal weapon transaction occurs, dropping high-rarity turrets if interrupted.
- **Diplomatic Sabotage (Heat > 0.20):** Extremists attack a peace envoy. Saving the envoy provides massive reputation.

</details>

### 🤝 15) Galactic Politics Tab (UI)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `data/scripts/player/ui/galacticpolitics_tab.lua`
- `data/scripts/player/init.lua`

**What it does:**
Adds a fully featured, interactive intelligence UI tab to the native Player Window, giving players unprecedented visibility into the macro-geopolitical state of the galaxy.

**Key Features:**

- **Active Conflict Tracking:** Displays a real-time, sortable list of all active AI wars, skirmishes, and ceasefires across the galaxy.
- **Interactive Column Sorting:** Click on any column header (Faction A, Faction B, War Heat, Status, Relations) to instantly sort the intelligence data ascending or descending.
- **Strategic Filtering:** Use the dropdown menu to filter the list by "All", "Active Conflicts", "Ceasefires Only", or factions with "Active Bounties".
- **Immersive Relation Toggle:** A checkbox allows players to switch between raw numeric relation values and immersive diplomatic descriptors (e.g., "Allied", "Confrontational", "All-Out War").
- **Strategic Tooltips:** Hovering over any conflict reveals deep intelligence, including internal Faction Indices, AI Traits (Aggressive, Peaceful, Wealthy, etc.), exact numerical player relations, and the exact credit payout of active War Bounties.
- **Bounty Indicators:** Factions with active bounties placed against them display a clear `[!]` indicator next to their name.
- **Color-Coded Standing:** Faction names are dynamically colored based on your personal reputation with them, allowing you to instantly spot when your allies are under attack.
- **Legend & Summary:** A clean bottom panel explains the color-coding system and provides a brief summary of how the Cosmic War simulation operates in the background.

**Gameplay Impact:**

- Transforms invisible background math into actionable intelligence.
- Allows players to strategically hunt for lucrative war bounties, intercept conflicts involving their allies, or identify highly volatile regions to exploit.

</details>

### 🆘 16) War Casualties & Events

<details>
<summary><b>Click to expand details</b></summary>

**What it does:**
Injects immersive background events related to the ongoing galactic conflict, making the universe feel alive and reacting to the violence around you.

**Key Features:**

- **Refugee Convoys:** Civilian ships fleeing warzones will occasionally hail you in deep space. Donating supplies or credits grants massive reputation boosts. They also have a 25% chance to upload the exact coordinates of a massive hidden resource stash directly to your galaxy map.
- **Distress Beacons:** Wreckages of destroyed ships may broadcast an active distress signal. Interacting with the beacon to download logs and "Answer the Call" triggers a dynamic rescue (or ambush) scenario. Be warned: If you simply salvage the wreck without answering the beacon, it will permanently lock out the interaction!

**Gameplay Impact:**

- Provides dynamic, narrative-driven events outside of standard missions.
- Offers alternative, peaceful routes to gain massive faction standing via charity.

</details>

---

## 🌐 Server & Performance Guidelines

### 🌐 Multiplayer / Dedicated Server Behavior

- Avorion's simulation is server-authoritative. **Cosmic War** logic is predominantly server-side with synchronization-aware behavior implemented where needed.
- Global background loops (like news, sanctions, and ceasefires) are strictly attached to the `Galaxy()` component to ensure proper headless execution.
- In mixed mod stacks, maintain consistent configuration and load order. Validate logs at startup to catch any issues early.

### 🛡️ Performance & Safety Notes

- Interval-driven loops are strictly favored over heavy per-frame (`update()`) logic to maintain server TPS.
- Defensive nil and callable checks are heavily used in high-risk lifecycle paths.
- Debug logging is toggleable via the CCM config to reduce noise and overhead in live production environments.

---

## Dependencies & Compatibility

### Required Mods

- Avorion
- Cosmic Series (Overhaul, Chornicles & Ascendancy)
- **Cosmic Vault** (Provides the underlying faction index API and shared data contracts).

### Compatibility Intent

- Built to seamlessly coexist with **Cosmic Overhaul**.
- Bridge-style integration explicitly avoids hard coupling to external mods.
- For large custom stacks, always verify your load order and check the server startup logs.

---

## 🛠️ Installation & Troubleshooting

### 🛠️ Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install all Cosmic Series Mods (Vault, Overhaul, Chronicles & Ascendancy)
3. Enable **Cosmic War** in **Settings -> Mods**.
4. Restart the game or server.

### 🛠️ Troubleshooting Checklist

- [ ] Confirm the mod is active in your Avorion mod settings.
- [ ] Confirm All Cosmic Series mods except Cosmic Starfall are installed.
- [ ] Review the latest client/server logs for any early startup warnings.
- [ ] Validate your load order if running in a heavily modified stack.
- [ ] Use `/cosmicwarstatus` in-game for quick operational diagnostics.

---

## 📈 Development Status

**Cosmic War** remains an actively iterated **WIP** with ongoing balancing and long-session validation.

The current architectural direction is heavily focused on:

- Resilient lifecycle behavior.
- Highly configurable war simulation.
- Stable, predictable coexistence with broader **Cosmic** series mod stacks.

---

## 🔗 Cosmic Series Integration & Audit 3.0 Updates

<details>
<summary><b>Click to expand</b></summary>

### 📖 Cosmic Codex Integration

All deep lore, stat blocks, and dynamic recipes have been fully integrated into the in-game **Cosmic Codex**. You no longer need to tab out of the game to read these features; they will natively update and unlock inside your Codex UI as you progress!

### 🔒 Network Safety & Anti-Cheat

- **Math.Random Fix:** We systematically replaced all unstable Lua `math.random` calls with Avorion's deterministic `random():getInt()` generation sequence. This guarantees 100% synchronization on Multiplayer Dedicated Servers and prevents cascading desyncs during massive fleet spawns.
- **Callable Validation:** UI and background scripts have been fully hardened. Malicious clients can no longer spoof "free" remote calls; the server actively verifies execution contexts before processing any requests, sealing multiple Arbitrary Code Execution (ACE) vulnerabilities.
- **Diplomacy Thread Safety:** Background diplomacy threads have been fully synchronized with the main Avorion engine, permanently eliminating `EXCEPTION_ACCESS_VIOLATION` server hangs during massive sector relation updates.

### 🛠️ Vanilla Bug Fixes

- **Scout Mission Fix:** We patched a massive, long-standing vanilla bug where Scout Missions would completely skip and ignore Faction Headquarters sectors because the native dialogue trees were missing the template definition.

### 🌌 Cosmic Vault Synergy

- **Deep Economy Warfare:** Market collapses and starvation natively trigger desperation invasions via the Cosmic Vault Economy simulation! Factions with 100+ Famine Scores will launch massive assaults on wealthy neighbors to survive.
- **Weather-Assisted Boarding:** The CosmicVaultWeather API allows players to utilize weather events for sieges. If a DarkMatterFog or IonStorm hits a sector, the defending station's boarding defense multiplier is slashed by 50%!
- **Commodore Siege Leadership:** If you are defending an allied faction's sector during a siege and ultimately fail, parking a ship with a Commodore captain in the sector will reduce the economic Famine penalty inflicted on the defenders.

### 🚀 Synergy Update (Rift DLC & More)

- **Wartime Propaganda Beacons**: There is a 5% chance for a narrative Cosmic Chronicles beacon to dynamically spawn after a siege resolves, immortalizing the battle.
- **Inherent Imperialism**: The Eclipse (Ascendancy) faction is now hardcoded as Imperialist and Vengeful. They will relentlessly expand their territory and will absolutely never accept ceasefires.
- **Wartime Shortages:** The destruction of supply convoys will cause massive shortages in military and medical goods at Trading Posts and Equipment Docks. If you are a trader, you can make billions smuggling these goods to desperate stations!
- **Weaponized Subspace Tears:** At Critical War Heat, warring factions may detonate experimental subspace weapons, tearing the fabric of space and unleashing localized Rift hazards.
- **Dynamic Frontline Sieges:** When a war reaches its absolute boiling point, factions will proactively spawn massive siege fleets directly into their rival's occupied sectors, creating dynamic combat hazards outside of normal missions.
- **Alliance PvP Repercussions:** Triggering a diplomatic incident or destroying civilian convoys will permanently damage relations not just for you, but dynamically spread the consequences to your active Player Alliance.
- **War Contracts - Subspace Containment:** When a rift tears in a warzone, factions will issue high-paying War Contracts to secure emerged Ancient Tech platforms and contain the anomaly.

</details>
