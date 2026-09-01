# ⚙️ Cosmic War - Technical Wiki

Full technical reference for **Cosmic War**, the faction-conflict simulation module in the **Cosmic** mod series. Current release: **v3.4.0**.

---

## 📑 Table of Contents

- [Mod Identity & Design Goals](#mod-identity--design-goals)
- [Architecture Summary](#architecture-summary)
- [Full Feature Breakdown](#full-feature-breakdown)
- [Server & Performance Guidelines](#server--performance-guidelines)
- [Dependencies & Compatibility](#dependencies--compatibility)
- [Installation & Troubleshooting](#installation--troubleshooting)
- [Development Status](#development-status)
- [Engine Hardening & Cross-Mod Integration](#engine-hardening--cross-mod-integration)

---

## 🧬 Mod Identity & Design Goals

**Primary focus:** living, persistent AI faction politics and war-state simulation.

**Core goals:**

1. **Active politics** - make galaxy politics feel dynamic instead of static.
2. **Sustained cycles** - produce meaningful war and cooling cycles over long campaign sessions through scripts attached to the global `Galaxy` loop.
3. **Player visibility** - surface war-state consequences to players through news broadcasts, bounties, and sanctions pressure.
4. **Configurability** - stay server-operator friendly through the Cosmic Configuration Menu (CCM).
5. **Safe compatibility** - favor non-invasive wrappers and safety guards over hard overwrites.

---

## 🏗️ Architecture Summary

The mod layers several simulation systems on top of vanilla Avorion:

1. **Faction-level baseline traits** - seeded and maintained to define AI personality.
2. **Sector-level pressure loops** - escalate local rivalries.
3. **Global diplomacy drift** - keeps galactic politics moving over time.
4. **War-side effects** - sanctions, bounties, bulletins, and ceasefires create visible, actionable outcomes.
5. **Cross-mod bridges** - influence command prediction overlays when Cosmic Overhaul is present.
6. **Dynamic invasions & scaling** - vanilla invasions spawn a fixed number of small ships; Cosmic War replaces this with:
   - **Strength matching:** invasions total the Omicron and volume of every defending station and ship in the sector, then scale the invading fleet to match 100% of that strength.
   - **Siege Dreadnoughts:** large invasions spawn Dreadnoughts with a 5x shield multiplier to survive point-defense fire.
   - **Shield jamming:** sieges have a 35% chance and fleet clashes a 15% chance to deploy Electronic Warfare, pinning all defending (including player) shields to 0 for 10 seconds.
   - **Cinematic Battlefield HUD:** entering a contested war zone attaches a split red/blue bar tracking siege duration, with border-flip text on capture or defense.

This produces a cycle: **tension, war pressure, side effects, détente potential, re-escalation.**

---

## ⚙️ Full Feature Breakdown

### ⚔️ 1) War-Oriented AI Faction Seeding

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/factions.lua`

**What it does:**
Injects and maintains faction-level war metadata and Custom Traits for AI factions, so behavior trends are identity-driven rather than random. Factions analyze their vanilla generation parameters (e.g. `greedy`, `aggressive`) to assign one of 9 Custom Traits.

**The 9 traits:**

- **Warmonger / Pacifist / Isolationist / Opportunist:** core stances that shape War Heat buildup and ceasefire likelihood.
- **Imperialist:** frequently claims empty sectors and builds new outposts.
- **Entrenched:** fortifies existing territory with defensive stations.
- **Mercantile:** pays 3x the standard rate for mercenary contracts (bounties and War Contracts alike).
- **Vengeful:** refuses to negotiate ceasefires once a war begins.
- **Xenophobic:** relations decay with every known faction, guaranteeing eventual unprovoked wars.

**Dormant trait revival:**
Cosmic War reactivates 4 unused vanilla traits: `Sadistic/Sympathetic`, `Strict/Forgiving`, `Smart/Dumb`, `Active/Passive`.

- **Active/Passive:** governs how often a faction attempts territory expansion.
- **Strict/Forgiving:** governs willingness to accept peace or hold a grudge.
- **Smart/Dumb:** governs strategic judgment when declaring war against superior forces.
- **Sadistic/Sympathetic:** governs bonus payouts (or penalties) for mercenaries who destroy unarmed civilian ships.

**Typical stored values:** `cw_enabled`, `cw_war_bias`, `cw_diplomatic_polarity`, plus trait indices exposed through the Cosmic Vault API (`cw_imperialist`, etc.).

**Gameplay impact:** AI factions read as distinct, mechanically-backed personalities, and the vanilla UI renders these traits natively through `CosmicVaultFaction`.

</details>

### ⚔️ 2) Sector War-Pressure Controller

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/sector/init.lua`, `data/scripts/sector/cosmicwarcontroller.lua`

**What it does:**
Runs periodic sector-level scans and applies pressure to selected faction pairs when local conflict conditions align, with spacing and cooldown logic to avoid spamming every loaded sector at once.

**Gameplay impact:** frontlines and contested regions emerge organically instead of escalating uniformly.

</details>

### 🤝 3) Persistent Diplomacy Drift

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/player/init.lua`, `data/scripts/player/background/cosmicwardiplomacy.lua`

**What it does:**
Periodically evaluates a random subset of eligible faction pairs and nudges diplomacy over time, so relations keep moving between discrete scripted events.

</details>

### ⚔️ 4) War News / Broadcast Layer

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwarnews.lua`

**What it does:**
Publishes periodic war bulletins covering the hottest current conflicts, chosen with stable randomization, so background simulation stays visible to players. As of v3.4.0, this layer is joined by two new publishers: completed War Bounty Licenses post under "Bounty Board" once per completed License, and confirmed AI-to-AI ceasefires post under "Politics." Neither is flagged Breaking News, since both are common enough in an active galaxy that flagging every one would defeat the purpose of that flag.

</details>

### 5) Diplomatic Sanctions Pressure

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`

**What it does:** applies sanction-like pressure tied to entrenched rivalries and hostile diplomatic states, so wars carry economic consequences and not just combat outcomes.

</details>

### 6) Ceasefire / Détente Logic

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/server/background/cosmicwarceasefires.lua`

**What it does:** allows conditional de-escalation once hostility recovers and ceasefire chance criteria are met, so the galaxy is not locked permanently into one escalated state. Since v3.4.0, an actual ceasefire between two AI factions (not just an escalation) publishes a "Politics" article on the Galactic News Network.

</details>

### ⚔️ 7) War Bounty Generation (Bounty Licenses)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/server/background/cosmicwarbounties.lua`, `data/scripts/sector/cw_bountypayouts.lua`, `data/scripts/player/background/cw_bounty_tracker.lua`

**What it does:**
Converts the global geopolitical state into interactive hunting licenses. When a faction has an active global bounty against an enemy, destroying the first valid military target (ship, station, or boss) provisions a **Bounty License** to the player or their alliance.

**Mechanics:**

- **Hunting quota:** the License tracks progress (0/15) across all sectors.
- **Expiration:** 45 minutes to complete the quota, with HUD warnings every 5 minutes.
- **Dynamic payouts:** base reward scales with distance from the core. Standard military ships pay 1x, Dreadnoughts and bosses pay 5x, and stations pay 10x.
- **Civilian immunity:** only military and infrastructure targets pay out; defenseless mining and cargo ships do not.
- **One License at a time:** a player (or alliance) holds a single active License. Killing a target under a different faction's bounty while yours is active does not switch you over; finish or wait out the current one first.
- **Completion is now newsworthy:** fully clearing a License's 15-kill quota publishes a "Bounty Board" article naming the collecting captain and the faction they collected against (v3.4.0). Posting a bounty was already public through the mod's "MOST WANTED" articles; this closes the loop by reporting the resolution too.
- **Checking your License:** `/cosmicwarbounties` in chat, or the **Galactic Politics** tab, shows your License's target, kill progress, and time remaining, plus the current galaxy-wide bounty board.

</details>

### 8) Runtime Cleanup / Compatibility Hooks

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/sector/factionwar/temporarydefender.lua`, `data/scripts/sector/background/rebuildstations.lua`

**What it does:** adds lifecycle-safe wrappers in war-adjacent paths to reduce stale wartime leftovers and transition artifacts, lowering the chance of lingering war-state clutter.

</details>

### 🎖️ 9) Admin / Diagnostics Command

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/commands/cosmicwarstatus.lua`

**Command:** `/cosmicwarstatus`

**What it provides:** a quick status and health readout of the background simulation, useful for balancing and debug workflows, with readiness guards (e.g. galaxy API availability checks) for safe early-lifecycle behavior.

</details>

### 💰 9b) Bounty Board Command

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/commands/cosmicwarbounties.lua`

**Command:** `/cosmicwarbounties`

**What it provides:**

- A chat summary of the player's own active Bounty License (target faction, kills/quota, time remaining), or confirmation that none is active.
- A ranked list, highest reward first, of up to the 10 highest-paying active War Bounties galaxy-wide, with offering faction, target faction, reward per kill, and time until expiry.

Added in v3.4.0, backed by a `getStatus()` function on `cw_bounty_tracker.lua` that returns the License's state as plain scalar values, matching the marshaling convention already used by every other `invokeFunction()` call site in the mod. Useful for players who don't want to open the Galactic Politics tab just to check their License or the top of the board.

</details>

### 🚀 10) Dynamic Territory Sieges & AI Boarding

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/lib/cosmicvaultterritory.lua` (via Cosmic Vault), `data/scripts/events/siegeevent.lua`, `data/scripts/entity/ai/trooptransport.lua`

**What it does:**
Lets factions conquer enemy sectors and expand their borders on the Galaxy Map. Background timers flip station ownership mathematically without keeping every contested sector loaded (avoiding the "Sector Alive" performance trap).

**Mechanics:**

- **Background conquests:** contested zones carry a hidden siege timer. If it runs out, the station flips ownership mathematically.
- **Physical sieges:** a player entering a contested zone triggers a Siege Event.
- **Troop transports:** three heavily shielded AI transports warp in and charge the defending station. Base boarding time is 60 seconds at close range, scaling up by 1 second per 100,000 HP of the station's hull and capping at 300 seconds (5 minutes); surviving the station's point defense for that long lets them physically board and capture it.
- **Dynamic borders:** a flipped station expands the faction's Galaxy Map influence naturally.
- **Zero-stutter performance:** background station flips and territory expansions are queued globally and executed instantly during a player's loading screen when they jump into the affected sector, avoiding the lag spikes native background sector loading causes.

</details>

### 11) Stability Hardening

<details>
<summary><b>Click to expand details</b></summary>

Ongoing hardening work includes:

- Waiting for the Cosmic Vault `factions_ready` flag before running simulation steps, for safer startup behavior.
- Replacing expensive `Galaxy():getFactions()` loops with the shared Cosmic Vault index cache (`Server():getValue("factions")`).
- Correct global simulation attachment (`galaxy/init.lua`, not `server/init.lua`).
- Defensive checks in background loops, including the `onServer()` guards described under [Engine Hardening & Cross-Mod Integration](#engine-hardening--cross-mod-integration).

**Impact:** fewer nil-method crashes at startup and steadier behavior in heavily modded stacks.

</details>

### 🔗 12) Cosmic Overhaul Synergy (Bridge Layer)

<details>
<summary><b>Click to expand details</b></summary>

**Primary bridge files:** `data/scripts/lib/cosmicwareconomybridge.lua`, `data/scripts/lib/cosmicwarcaptainbridge.lua`

**Typical wrapper targets:** command prediction hooks in Cosmic Overhaul simulation scripts (trade, scout, travel, refine, mine, salvage variants).

**Design intent:** the original prediction path always runs first; the bridge applies bounded post-processing only when enabled and the context is valid, and falls back to a no-op when disabled or missing context.

**Effect:** command planning can reflect War Heat pressure, and baseline behavior stays intact when bridge toggles are off.

</details>

### ⚔️ 13) Dynamic War Contracts (Missions)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/entity/bulletinboardmissions.lua` and all 22 `cw_*.lua` files in `data/scripts/player/missions/`

**What it does:**
Injects custom, scaled combat missions into Avorion's native Bulletin Board pools based on the War Heat between a station's owner and its rival faction. All 22 War Contracts are clickable and completable from the bulletin board.

**Available contracts:**

- **War Heat > 0.15:** *Force Recon* (scout a hostile listening post) and *Sensor Deployment* (deploy stealth buoys in 3 hostile sectors).
- **War Heat > 0.25:** *Border Skirmish* (eliminate a border patrol).
- **War Heat > 0.35:** *Resource Sabotage* (destroy a mining operation), *Resource Heist* (steal resources from enemy territory), and *Deploy Minefield* (deploy and defend a minefield).
- **War Heat > 0.45:** *Interception* (destroy an enemy supply convoy), *Breakthrough* (defend an allied convoy), *Sector Raid* (wipe out enemy infrastructure), *Black Box Retrieval* (extract data from a destroyed prototype), and *Propaganda Broadcast* (hack a comms array).
- **War Heat > 0.60:** *Frontline Siege* (assault a scaled enemy FOB), *Hunter Killer* (hunt a specialized fleet), and *Distraction Carnage* (survive a 5-minute ambush).
- **War Heat > 0.80:** *High-Value Extraction* (holdout survival for a defector), *Assassinate General* (kill a high-ranking target), *Supply Line Raid* (destroy logistics hubs), and *Blockade Runner* (deliver supplies through a blockade).
- **War Heat = 1.00:** *Decapitation Strike* (Flagship boss fight), *Extract POW* (rescue prisoners from a guarded facility), and *Champion Duel* (1-on-1 with a scaled boss).
- **Rift-dependent:** *Subspace Containment* becomes available when a Weaponized Subspace Tear opens in a warzone (see [Engine Hardening & Cross-Mod Integration](#engine-hardening--cross-mod-integration)).

</details>

### ⚔️ 14) Dynamic War Events (Flashpoints)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/player/cw_eventscheduler.lua` and all 8 scripts it schedules under `data/scripts/events/`

**What it does:**
Injects spontaneous events into a per-player scheduler so players encounter live warzones, covert operations, and distress calls tied to the macro political simulation as they explore.

**Scheduled events:**

- **Fleet Clash (Heat > 0.60):** an enemy strike fleet jumps into an active AI sector.
- **Refugee Convoy (Heat > 0.40):** civilian freighters under attack from a hunter fleet.
- **Stranded Flagship (Heat > 0.80):** a damaged Dreadnought boss found vulnerable, with a repair fleet inbound.
- **Arms Deal (Heat > 0.20):** an illegal weapon transaction that drops high-rarity turrets if interrupted.
- **Diplomatic Sabotage (Heat > 0.20):** extremists attack a peace envoy; saving the envoy grants a large reputation boost.
- **Wreckage Field (no Heat requirement):** a populated AI-owned sector spawns 4-9 wrecks marking a recent battle, a salvage opportunity rather than a combat encounter.
- **Headhunters Ambush (no Heat requirement):** the present player's worst-standing enemy faction dispatches an elite squad to intercept them directly in the sector, matching the "Bounty Hunter Ambush" feature described in the v3.1.0 release.
- **Blockade (no Heat requirement):** an enemy fleet forms up at the edge of a populated, defended sector.

Each entry rolls its own randomized timer window (typically 60 to 240 in-game minutes) independently, so multiple events can be pending at once. As of v3.4.0 all 8 resolve to their full `data/scripts/events/...` path when the scheduler attaches them.

</details>

### 🤝 15) Galactic Politics Tab (UI)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/player/ui/galacticpolitics_tab.lua`, `data/scripts/player/init.lua`

**What it does:**
Adds an interactive intelligence tab to the native Player Window, giving visibility into the macro-geopolitical state of the galaxy.

**Key features:**

- **Your License at a glance:** the header shows the player's own active Bounty License (target, kills, time remaining), sourced from the same lookup as `/cosmicwarbounties`.
- **Active conflict tracking:** a sortable, real-time list of active AI wars, skirmishes, and ceasefires.
- **Dedicated Bounty column:** active War Bounties get their own sortable column showing the higher of either side's reward, instead of an inline `[BOUNTY]` text suffix.
- **Interactive column sorting:** click any column header (Faction A, Faction B, Bounty, War Heat, Famine, Status, Relations) to sort ascending or descending.
- **Strategic filtering:** filter by All, Active Conflicts, Ceasefires Only, or factions with Active Bounties.
- **Relation toggle:** switch between raw numeric relation values and diplomatic descriptors (Allied, Confrontational, All-Out War).
- **Strategic tooltips:** hovering a row reveals internal faction indices, AI traits, exact numeric relations, and exact bounty payouts.
- **Color-coded standing:** faction names are colored by the player's personal reputation with them.
- **Decluttered header layout (v3.4.0):** the title, filter dropdown, numeric-relations checkbox, and refresh button previously shared one width-relative row that could overlap at narrower window sizes. Controls now sit on their own row below the title with fixed left-to-right spacing, removing the overlap entirely.
- **Legend & Summary:** a bottom panel explains the color coding and how the background simulation works, including a pointer to `/cosmicwarbounties`.

</details>

### 🆘 16) War Casualties & Events

<details>
<summary><b>Click to expand details</b></summary>

**What it does:** injects immersive background events tied to the ongoing conflict.

**Key features:**

- **Refugee Convoys:** civilian ships fleeing warzones occasionally hail the player in deep space; donating supplies or credits grants reputation, and there is a 25% chance of a hidden resource stash tip-off.
- **Distress Beacons:** wreckage of destroyed ships may broadcast a distress signal. Interacting with the beacon downloads logs and triggers "Answer the Call," a dynamic rescue (or ambush) scenario. Salvaging the wreck without answering the beacon permanently locks out the interaction.

</details>

---

## 🌐 Server & Performance Guidelines

### 🌐 Multiplayer / Dedicated Server Behavior

- Avorion's simulation is server-authoritative. Cosmic War logic is predominantly server-side, with synchronization-aware behavior where needed.
- Global background loops (news, sanctions, ceasefires) are strictly attached to `Galaxy()` for correct headless execution.
- In mixed mod stacks, keep configuration and load order consistent, and check startup logs for early issues.

### 🛡️ Performance & Safety Notes

- Interval-driven loops are favored over per-frame (`update()`) logic to protect server TPS.
- Nil and callable checks are used heavily in high-risk lifecycle paths.
- Debug logging is toggleable through the CCM config to reduce noise in production.

---

## Dependencies & Compatibility

### Required Mods

Per `modinfo.lua`, Cosmic War declares three hard dependencies plus the base game:

- **Avorion** 1.0+
- **Cosmic Vault** (shared faction index API and data contracts, required by every Cosmic mod)
- **Cosmic Overhaul**
- **Cosmic Chronicles**

**Cosmic Ascendancy is not a hard dependency of Cosmic War.** A handful of features (the Eclipse faction's hardcoded Imperialist/Vengeful stance, the Eclipse Sanitization Protocol ceasefire event) reference Ascendancy content and only activate when it happens to be installed. Everything else in this document works without it.

### Compatibility Intent

- Built to coexist with Cosmic Overhaul; bridge-style integration avoids hard coupling to it.
- For large custom stacks, verify load order and check server startup logs.

---

## 🛠️ Installation & Troubleshooting

### 🛠️ Installation

1. Place the folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install Cosmic Vault, Cosmic Overhaul, and Cosmic Chronicles.
3. Enable **Cosmic War** under **Settings -> Mods**.
4. Restart the game or server.

### 🛠️ Troubleshooting Checklist

- [ ] Confirm the mod is active in your Avorion mod settings.
- [ ] Confirm Cosmic Vault, Cosmic Overhaul, and Cosmic Chronicles are installed.
- [ ] Review the latest client/server logs for early startup warnings.
- [ ] Validate load order if running a heavily modified stack.
- [ ] Use `/cosmicwarstatus` in-game for operational diagnostics.
- [ ] Use `/cosmicwarbounties` in-game to check your active Bounty License and the top of the bounty board.

---

## 📈 Development Status

Cosmic War is at **v3.4.0**, a UI-polish and bugfix release following the War Contracts & Bounties Expansion (v3.3.0). Current work focuses on:

- Resilient lifecycle behavior.
- A highly configurable war simulation.
- Stable coexistence with the rest of the Cosmic suite.

---

## 🔗 Engine Hardening & Cross-Mod Integration

<details>
<summary><b>Click to expand</b></summary>

This section tracks stability work and suite-wide integration points that don't fit neatly into a single feature above. It replaces the older "Audit 3.0" appendix; the content below reflects the mod as of v3.4.0, not a single historical pass.

### 📖 Cosmic Codex Integration

Lore, stat blocks, and dynamic feature explanations are integrated into the in-game **Cosmic Codex**, unlocking natively as the player progresses.

### 🔒 Network Safety

- **Deterministic randomization:** unstable Lua `math.random` calls were replaced with Avorion's deterministic `random():getInt()` sequence throughout the mod, preventing multiplayer client/server desyncs when generating loot, stats, or enemies.
- **Callable validation:** UI and background scripts verify execution context on the server before processing remote calls, closing gaps that let malicious clients spoof free actions.
- **Diplomacy thread safety (v3.0.1):** the background war-simulation scripts (`cosmicwarceasefires.lua`, `cosmicwardiplomaticsanctions.lua`, `cosmicwarbounties.lua`) previously used a `CosmicVaultTask.RunAsync` coroutine wrapper with no pumping mechanism, which could let a dangling thread violate memory boundaries on garbage collection and crash the instance with `EXCEPTION_ACCESS_VIOLATION`. They were rewritten to run synchronously, and this class of crash has not recurred since.

### 🌌 Cosmic Vault Synergy

- **Deep Economy Warfare:** factions with high Famine Scores can launch desperation invasions on wealthy neighbors through the Cosmic Vault Economy simulation.
- **Weather-Assisted Boarding:** a DarkMatterFog or IonStorm rolling into a sector during a siege slashes the defending station's boarding defense multiplier by 50%, through the CosmicVaultWeather API.
- **Commodore Siege Leadership:** if a ship with a Commodore captain is present when a defended sector falls, the resulting Famine Score penalty drops from +5 to +2.
- **Wartime Shortages - currently a no-op:** losing a sector's controlling faction is supposed to drain military and medical goods stock at that faction's `tradingpost.lua` stations. As of v3.4.0, the code correctly checks the real `invokeFunction()` call-status return instead of misreading it as a table, and no longer publishes a false "Wartime Shortage" news article when nothing happened. The drain itself stays inert, though: `decreaseGoods` is not yet a `callable()`-registered function on `TradingPost`, so the call safely no-ops rather than crashing. There's no price or scarcity effect to exploit here yet.

### 🚀 Rift & Suite Synergy

- **Wartime Propaganda Beacons:** a 5% chance for a Cosmic Chronicles narrative beacon to spawn after a siege resolves, carrying `cc_blackbox.lua`.
- **Weaponized Subspace Tears:** at critical War Heat (relations at or below -80000), warring factions may detonate experimental subspace weapons, opening a localized Rift hazard.
- **Subspace Containment:** when a rift tears in a warzone, factions issue the *Subspace Containment* War Contract to secure emerged Ancient Tech platforms and close the anomaly.
- **Alliance PvP repercussions:** reputation shifts from PvP and civilian-convoy destruction propagate to the player's active Alliance, so switching to a personal ship no longer shields the alliance from the consequences.

</details>
