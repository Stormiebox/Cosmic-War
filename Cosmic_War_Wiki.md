# Cosmic War - Detailed Features
*Current Version: v2.0.2*

Welcome to the **Cosmic War** official wiki! This page contains the full, detailed documentation for the faction-conflict simulation module in the **Cosmic** mod series.

**Cosmic War** is designed to:

- Run seamlessly as a standalone module.
- Synergize with **Cosmic Overhaul** through optional bridge behaviors where available.

---

## Table of Contents

- [Mod Identity & Design Goals](#mod-identity--design-goals)
- [Architecture Summary](#architecture-summary)
- [Full Feature Breakdown](#full-feature-breakdown)
- [Server & Performance Guidelines](#server--performance-guidelines)
- [Dependencies & Compatibility](#dependencies--compatibility)
- [Installation & Troubleshooting](#installation--troubleshooting)
- [Development Status](#development-status)

---

## Mod Identity & Design Goals

**Primary Focus:** Living, persistent AI faction politics and war-state simulation.

**Core Goals:**

1. **Active Politics:** Make galaxy politics feel dynamic and alive instead of static.
2. **Sustained Cycles:** Produce meaningful war and cooling cycles over long campaign sessions via scripts properly attached to the global `Galaxy` loop.
3. **Player Visibility:** Surface war-state consequences directly to players via news broadcasts, bounties, and sanctions pressure.
4. **Configurability:** Remain highly configurable and server-operator friendly through the Mod Configuration Menu (MCM).
5. **Safe Compatibility:** Preserve ecosystem compatibility by favoring non-invasive wrappers and safety guards over hard overwrites.

---

## Architecture Summary

The mod utilizes a layered simulation model to bring the galaxy to life:

1. **Faction-Level Baseline Traits:** Seeded and maintained to define AI personality.
2. **Sector-Level Pressure Loops:** Dynamically escalate local rivalries.
3. **Global Diplomacy Drift:** Keeps galactic politics moving naturally over time.
4. **War-Side Effects:** Systems like sanctions, bounties, bulletins, and ceasefires create visible, actionable outcomes.
5. **Cross-Mod Bridges (Optional):** Influences command prediction overlays when combined with other Cosmic mods.

*This architecture produces a cyclical macro behavior pattern:*
**Tension → War Pressure → Side Effects → Détente Potential → Re-escalation.**

---

## Full Feature Breakdown

### 1) War-Oriented AI Faction Seeding

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/factions.lua`

**What it does:**
Injects and maintains faction-level war metadata for AI factions so behavior trends are less random and more identity-driven over time.

**Typical Stored Values:**

- `cw_enabled`
- `cw_war_bias`
- `cw_diplomatic_polarity`
- Rivalry target helpers used by downstream systems.

**Gameplay Impact:**

- AI factions feel less interchangeable.
- Rivalries become more coherent in long campaigns.
- Better continuity between isolated events and long-term politics.

</details>

### 2) Sector War-Pressure Controller

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

### 3) Persistent Diplomacy Drift

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

### 4) War News / Broadcast Layer

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

### 7) War Bounty Generation

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**
- `data/scripts/server/background/cosmicwarbounties.lua`
- `data/scripts/sector/cw_bountypayouts.lua`

**What it does:**
Creates time-bound bounty opportunities linked to active faction rivalries, and actively pays players who assassinate targeted ships.

**Typical Stored Value Pattern:**

- Target faction ID.
- Reward value.
- Expiration runtime.

**Functional Payouts:**
- Actively listens to sector combat via `onDestroyed`.
- When a player destroys an enemy with an active bounty, the system deposits the reward (scaled 3x for bosses, 5x for stations) into the player's bank, clears the bounty to prevent farming, and broadcasts a "War Bounty Claimed" Galactic News report.

**Gameplay Impact:**

- Gives players direct incentives to engage with active wars.
- Converts geopolitical state into mission-like opportunities.

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

### 9) Admin / Diagnostics Command

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

### 10) MCM Configuration Integration

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**

- `modconfig.lua`
- `data/scripts/lib/cosmicwarconfig.lua`
- `modinfo.lua`

**Dependency:**
Requires the **Mod Configuration Menu (MCM)**.

**Config Groups Currently Exposed:**

- **War Pressure:** `sectorPressureInterval`, `sectorPressureChance`, `sectorPressureMinSpacing`
- **Diplomacy:** `diplomacyInterval`, `diplomacyPairSteps`, `rivalryThreshold`
- **Diagnostics:** `debugLogs`

**Config Handling Notes:**

- Numeric values are clamped to safe ranges.
- Percent slider values are normalized for simulation use.
- Config bridge returns defaults if MCM/config context is unavailable.

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

### 12) Ecosystem Synergy (Soft Bridges)

Cosmic War adheres to a strict "Standalone but Synergistic" philosophy. It requires nothing but the Cosmic Vault to function, but it includes blind hooks that naturally interface with the rest of the Cosmic Series if installed:

- **War Profiteering (Overhaul + Chronicles):** At Critical War Heat, factions naturally consume their station stocks of Military Goods. If Cosmic Overhaul is installed, this artificial deficit triggers massive Smuggler/Merchant hazard-pay multipliers. Cosmic Chronicles detects the deficit and broadcasts a "Wartime Shortage" news flash.
- **Wreckage Fields (Overhaul + Chronicles):** Spawns dense capital ship graveyards after high-heat battles. Cosmic Overhaul's Scavenger logic natively detects these as high-value Black Box loot tables, while Chronicles reports the graveyard's discovery.
- **Elite Headhunters (Starfall):** Angering a warring faction to extreme levels (-80000 relations) spawns Elite Hit-Squads. The script attempts a soft-bridge to Cosmic Starfall to dynamically equip the squad with devastating heavy subsystems. If Starfall isn't present, they spawn as standard vanilla military ships.

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

### 13) Dynamic War Contracts (Missions)

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

- **War Heat > 0.15:** *Force Recon* (Scout a hostile listening post).
- **War Heat > 0.25:** *Border Skirmish* (Eliminate an enemy border patrol).
- **War Heat > 0.35:** *Resource Sabotage* (Destroy an enemy mining operation).
- **War Heat > 0.45:** *Interception* (Destroy enemy supply convoy) & *Breakthrough* (Defend allied supply convoy).
- **War Heat > 0.60:** *Frontline Siege* (Assault a dynamically scaled enemy Forward Operating Base).
- **War Heat > 0.80:** *High-Value Extraction* (Holdout survival while an enemy defector charges their hyperdrive).
- **War Heat = 1.00:** *Decapitation Strike* (Ultra-hard Flagship Boss. Destroying it forces an immediate ceasefire).

</details>

### 14) Dynamic War Events (Flashpoints)

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
Injects new spontaneous events via a dedicated background scheduler (cw_eventscheduler.lua). This standalone module runs strictly parallel to vanilla Avorion, guaranteeing that dynamic war flashpoints seamlessly interweave with standard pirate and Xsotan attacks without breaking any core game files. As players explore the galaxy, they will encounter live warzones, covert operations, and distress calls directly tied to the macro political simulation. These events also seamlessly bridge into the **Cosmic Vault News API**, broadcasting major flashpoints to all players across the galaxy.

**Available Events:**

- **Fleet Clash (Heat > 0.60):** Massive enemy strike fleets jump into active AI sectors.
- **Refugee Convoy (Heat > 0.40):** Civilian freighters are ambushed by hunter fleets.
- **Stranded Flagship (Heat > 0.80):** A severely damaged dreadnought boss is discovered vulnerable, with a repair fleet en route.
- **Arms Deal (Heat > 0.20):** An illegal weapon transaction occurs, dropping high-rarity turrets if interrupted.
- **Diplomatic Sabotage (Heat > 0.20):** Extremists attack a peace envoy. Saving the envoy provides massive reputation.

</details>

### 15) Galactic Politics Tab (UI)

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

### 16) Ambient Radio Chatter

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:**
- `data/scripts/sector/background/radiochatter.lua`

**What it does:**
Injects 40 brand new, highly thematic background radio chatter lines into Avorion's vanilla ambient dialogue pool.

**Key Features:**
- **Thematic Integration:** Lines are dynamically spoken by General Stations, General Ships, Freighters, and Hostile Ships.
- **Lore Bridging:** The chatter subtly references core mechanics from the Cosmic mod series (War Heat, Overhauls, Starfalls, Galactic News) and drops easter eggs related to the developer (Stormbox).
- **Localization:** Fully localized into all 7 supported languages.

**Gameplay Impact:**
- Makes the galaxy feel vastly more alive and reactive to the political background simulation.

</details>

---

## Server & Performance Guidelines

### Multiplayer / Dedicated Server Behavior

- Avorion's simulation is server-authoritative. **Cosmic War** logic is predominantly server-side with synchronization-aware behavior implemented where needed.
- Global background loops (like news, sanctions, and ceasefires) are strictly attached to the `Galaxy()` component to ensure proper headless execution.
- In mixed mod stacks, maintain consistent configuration and load order. Validate logs at startup to catch any issues early.

### Performance & Safety Notes

- Interval-driven loops are strictly favored over heavy per-frame (`update()`) logic to maintain server TPS.
- Defensive nil and callable checks are heavily used in high-risk lifecycle paths.
- Debug logging is toggleable via the MCM config to reduce noise and overhead in live production environments.

---

## Dependencies & Compatibility

### Required Mods

- Avorion
- **Mod Configuration Menu (MCM)**
- **Cosmic Vault** (Provides the underlying faction index API and shared data contracts).

### Compatibility Intent

- Built to seamlessly coexist with **Cosmic Overhaul**.
- Bridge-style integration explicitly avoids hard coupling to external mods.
- For large custom stacks, always verify your load order and check the server startup logs.

---

## Installation & Troubleshooting

### Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Ensure **Mod Configuration Menu (MCM)** is installed and enabled.
3. Enable **Cosmic War** in **Settings -> Mods**.
4. Restart the game or server.

### Troubleshooting Checklist

- [ ] Confirm the mod is active in your Avorion mod settings.
- [ ] Confirm the **MCM** dependency is enabled and loaded before this mod.
- [ ] Review the latest client/server logs for any early startup warnings.
- [ ] Validate your load order if running in a heavily modified stack.
- [ ] Use `/cosmicwarstatus` in-game for quick operational diagnostics.

---

## Development Status

**Cosmic War** remains an actively iterated **WIP** with ongoing balancing and long-session validation.

The current architectural direction is heavily focused on:

- Resilient lifecycle behavior.
- Highly configurable war simulation.
- Stable, predictable coexistence with broader **Cosmic** series mod stacks.
