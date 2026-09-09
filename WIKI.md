# ⚙️ Cosmic War - Technical Wiki

Full technical reference for **Cosmic War**, the faction-conflict simulation module in the **Cosmic** mod series. Current release: **v4.0.0**.

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

**Primary file:** `data/scripts/server/background/cosmicwardiplomacy.lua` (attached via `data/scripts/galaxy/server.lua`)

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

**Primary files:** `data/scripts/entity/bulletinboardmissions.lua` and all 27 `cw_*.lua` files in `data/scripts/player/missions/`

**What it does:**
Injects custom, scaled combat missions into Avorion's native Bulletin Board pools based on the War Heat between a station's owner and its rival faction. All 27 War Contracts are clickable and completable from the bulletin board.

**Available contracts:**

- **War Heat > 0.15:** *Force Recon* (scout a hostile listening post) and *Sensor Deployment* (deploy stealth buoys in 3 hostile sectors).
- **War Heat > 0.25:** *Border Skirmish* (eliminate a border patrol).
- **War Heat > 0.35:** *Resource Sabotage* (destroy a mining operation), *Resource Heist* (steal resources from enemy territory), *Deploy Minefield* (deploy and defend a minefield), and *Scorched Earth* (strip-mine enemy territory and keep what you take, extended pass).
- **War Heat > 0.45:** *Interception* (destroy an enemy supply convoy), *Breakthrough* (defend an allied convoy), *Sector Raid* (wipe out enemy infrastructure), *Black Box Retrieval* (extract data from a destroyed prototype), *Propaganda Broadcast* (hack a comms array), and *Deniable Raid* (a pirate-flagged raid with no fingerprints, extended pass).
- **War Heat > 0.60:** *Frontline Siege* (assault a scaled enemy FOB), *Hunter Killer* (hunt a specialized fleet), *Distraction Carnage* (survive a 5-minute ambush), *Shield Breaker* (destroy an enemy Planetary Defense Generator, extended pass), and *Prize Crew* (capture an enemy escort ship intact, extended pass).
- **War Heat > 0.80:** *High-Value Extraction* (holdout survival for a defector), *Assassinate General* (kill a high-ranking target), *Supply Line Raid* (destroy logistics hubs), *Blockade Runner* (deliver supplies through a blockade), and *Subspace Containment*.
- **War Heat = 1.00:** *Decapitation Strike* (Flagship boss fight), *Extract POW* (rescue prisoners from a guarded facility), and *Champion Duel* (1-on-1 with a scaled boss).
- **War Score 150-249, giver ahead (extended pass):** *Decisive Push* — deliver the final blow to a war that's already nearly decided, gated on War Score rather than War Heat.

</details>

### 💰 13b) Warbonds (War Financing)

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/entity/merchants/tradingpost.lua` (purchase, cash-out, and Sanctions Relief dialogs and RPCs), `data/scripts/player/cosmicwar_warbonds.lua` (per-player bond tracking and maturity resolution).

**What it does:** A faction actively at war (War Heat ≥ 0.25) sells Warbonds at its Trading Posts — a Standard bond at 10,000,000 Cr or a Premium bond at 50,000,000 Cr, capped at 250,000,000 Cr held per faction per player, and 1,000,000,000 Cr total across all players combined per faction (`cw_warbond_pool_<factionIndex>`, freed back up as bonds mature).

**Maturity (v4.0.0):** once War Heat returns to 0 and stays there for 2 hours, `CW_Warbonds.checkWarbondStatus()` resolves the bond against the faction's Famine Score delta between purchase and maturity — `payoutMultiplier = (1.0 - min(1.0, max(0, famineDelta) / 150)) * 3.0`, giving a smooth 0%–300% return rather than the pre-v4.0.0 binary (300% or total loss).

**Famine delta, war-caused only (extended pass):** the raw famine delta above is adjusted by subtracting any Humanitarian Contract relief applied during the hold (`CosmicWarBridge.getFamineReliefApplied()`, snapshotted at purchase and re-read at maturity) — otherwise a player could buy a bond, then personally fly that same faction's Relief Convoy/Medical Airlift/Diplomatic Aid Package to manufacture a "the war went well" reading regardless of the war's actual outcome. Relief actions still reduce the faction's live Famine Score everywhere else; they just can't be read as a war outcome for bond-payout purposes.

**Early cash-out (v4.0.0):** `CW_Warbonds.cashOutEarly(factionIndex)`, exposed via a new "Cash Out Warbonds Early" Trading Post interaction, lets a player exit before maturity for a flat 40% — previously bonds had no exit before the war fully resolved.

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

### 🕵️ 17) Intelligence Network

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/lib/cosmicwarbridge.lua` (`grantIntel`/`getIntel`/`spendIntel`/`findExpansionCandidate`), `data/scripts/commands/cosmicwarintel.lua`, plus completion hooks in `cw_forcerecon.lua`, `cw_sensor_deployment.lua`, `cw_black_box_retrieval.lua`.

**What it does:** Completing Force Recon (+25), Sensor Deployment (+35), or Black Box Retrieval (+30) banks Intel Points against the scouted faction, tracked per-player. `/cosmicwarintel` with no argument lists your current Intel by faction; `/cosmicwarintel <faction name>` spends 50 Intel to preview an Imperialist faction's likely next expansion heading — a live query of the same directional-walk algorithm that drives real expansion (see the Dynamic Territory Expansion entry above), seeded deterministically per 15-minute window so every player asking about the same faction in that window sees the same answer. A non-Imperialist faction still consumes the Intel but honestly reports it has no discernible expansion pattern.

</details>

### 🤝 18) Humanitarian Contracts

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/player/missions/cw_relief_convoy.lua`, `data/scripts/player/missions/cw_medical_airlift.lua`, `data/scripts/player/missions/cw_scorched_earth.lua`, `data/scripts/entity/merchants/tradingpost.lua` (Sanctions Relief and Diplomatic Aid Package interactions), `data/scripts/server/background/cosmicwardiplomaticsanctions.lua` (immunity check), `data/scripts/lib/cosmicwarbridge.lua` (`recordFamineReliefApplied`/`getFamineReliefApplied`).

**What it does:** Non-combat, non-warlike mechanics give a faction's Famine Score a real player-facing path downward — previously Famine only ever accumulated (siege losses, Cosmic Ascendancy's World Eater, Cosmic Chronicles' stock-market rolls), with Chronicles' own market events the only existing decay path.

- **Relief Convoy:** a bulletin-board mission gated on Famine Score (≥50, "Struggling" or worse) rather than War Heat. Gather 3,000–8,000 units of a distance-tiered raw material and deliver it to the giver's own sector. Completion reduces that faction's Famine Score by 20 (reduced from 40 during the extended pass, to match Cosmic Chronicles' own decay-event convention rather than standing as the largest single decay value in the suite) and pays `50,000 + famineScore·800` credits plus 8,000 reputation. No war declaration, no assigned enemy, no abandon penalty.
- **Medical Airlift** *(extended pass)*: a second, Famine ≥100 ("Severe Famine") variant — a smaller, faster delivery (1,200–3,000 units) for a bigger single-shot reduction (-35 Famine) and a higher payout (`100,000 + famineScore·1,000` plus 10,000 reputation). Never competes with Relief Convoy's own ≥50 bulletin slot.
- **Scorched Earth** *(extended pass)*: the combat-side mirror — a War Contract (0.35 War Heat gate) that strip-mines a quota of ore from enemy territory and lets the player keep it, applying +20 Famine to the target faction rather than reducing it. No delivery back to the giver; denying the enemy the resources is the mission.
- **Sanctions Relief:** an instant 8,000,000 Cr Trading Post transaction (mirroring the Warbonds dialog flow), available whenever a faction's relations with its registered enemy are at or below the rivalry threshold — the exact condition Diplomatic Sanctions pressure itself checks. Grants 2 hours of immunity from that pressure.
- **Diplomatic Aid Package** *(extended pass)*: an instant 6,000,000 Cr Trading Post donation reducing Famine by 20, for players who'd rather pay than fly a Relief Convoy run. Gated on the same Famine ≥50 threshold.

**Famine relief tracking (extended pass):** every mechanic above that reduces Famine also calls `CosmicWarBridge.recordFamineReliefApplied(factionIndex, amount)` — a running, never-reset total Warbonds reads at purchase and maturity so its famine-outcome-scaled payout can't be gamed by pairing a bond with the very relief action that would guarantee it a maximum return (see Warbonds, above).

</details>

### ⚔️ 19) War Score & Attrition

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/lib/cosmicwarbridge.lua` (`recordWarScoreKill`/`recordWarScoreTerritory`/`getWarScore`), `data/scripts/sector/cw_bountypayouts.lua`, `data/scripts/entity/ai/trooptransport.lua`, `data/scripts/player/cw_siege_injector_persistent.lua`, `data/scripts/server/background/cosmicwarceasefires.lua`, `data/scripts/player/ui/galacticpolitics_tab.lua`.

**What it does:** A legible, per-conflict scoreboard replacing "who's winning this war" as a mental calculation from the raw relations number. Tracks net kills (1 point each, any valid military kill between two factions actually at war, credited to whichever side didn't lose the unit regardless of who landed the blow, capped at ±100 toward the combined score — extended pass, see below) and net territory (25 points each, station captures, uncapped) per faction pair. Visible by hovering a conflict row in the Galactic Politics tab, alongside progress toward the 250-point Decisive Victory threshold; also shown live in the Battlefield HUD during an active siege (extended pass).

**Kill-contribution cap (extended pass):** kills are credited for any valid military kill galaxy-wide, including ambient AI-vs-AI combat from this mod's own background events, not just player action — so kill volume alone could reach 250 far faster than 10 net territory swings, the opposite of the stated intent that territory should outweigh a kill streak. Kills' contribution to the combined score is now capped at ±100, so a real territory swing is always required to actually trigger Decisive Victory.

**Feeds two mechanics:**

- **War Exhaustion:** ceasefire chance rises +3% per full day a war has been active, capped at +30%.
- **Decisive Victory:** once a pair's War Score magnitude reaches 250, the war ends outright regardless of the normal détente roll — the losing side takes a 15-point Famine Score penalty, relations are forced to a solid peace level, the pair's War Score resets to zero, and a "Decisive Victory" article publishes to the Galactic News Network.

</details>

### 🌑 20) Coalition Ceasefires

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/server/background/cosmicwarceasefires.lua`, `data/scripts/sector/cosmicwarcontroller.lua`.

**What it does:** Generalizes the single-pair "Eclipse Sanitization Protocol" into a galaxy-wide mechanic. Once Cosmic Ascendancy's Eclipse Threat Economy (`eclipse_threat`) crosses 5,000 (on its 0–10,000 scale) while the Eclipse is fully awake, every currently-warring AI faction pair galaxy-wide is pulled into a 1-hour temporary truce: relations pushed clear of the rivalry threshold, and new escalation suppressed for the affected pair for the duration. Runs on its own 30-minute cooldown, independent of the normal per-pair ceasefire roll. Scoped to factions actually at war ("affected factions"), with galaxy-wide reach rather than proximity-limited.

</details>

### 🛡️ 21) Planetary Defense Generators & Shield Breaker

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/entity/cw_planetary_defense.lua`, `data/scripts/server/background/cosmicwardefensegenerators.lua`, `data/scripts/player/cw_siege_injector_persistent.lua`, `data/scripts/player/missions/cw_shieldbreaker.lua`.

**What it does:** `cw_planetary_defense.lua` has always been a correct, working script — while active, it projects invincibility over every other station in its sector — but nothing anywhere ever actually attached it to a station, despite being documented as a real siege mechanic in the in-game Codex and `PLAYER_GUIDE.md`. `cosmicwardefensegenerators.lua` closes that gap: a faction under meaningful threat (War Heat ≥0.35) gets a rolling per-pass chance to commission one at its own home sector, tracked as a plain flag (`faction:cw_defense_generator_sector`) rather than a physical entity. The station itself is lazily materialized the first time any player physically enters that sector (`cw_siege_injector_persistent.lua`), the same progressive-materialization pattern this mod already uses for background-resolved sieges — no sector ever needs to be loaded just to place a station in it.

**Shield Breaker:** a War Contract (0.60 War Heat) built on top of this. Only offered when the target enemy actually has a generator commissioned — the mission reads the exact flagged sector directly, so it's never offered with no valid target to send the player to. Destroying it clears the flag (so the faction can be commissioned a new one in the future) and credits a War Score kill.

**Known limitation:** if a generator is destroyed by any means other than this exact mission (e.g. incidental combat during an unrelated event), the flag is not automatically cleared, so that faction won't be re-commissioned another this save. A deliberate scope boundary, not a bug — see Changelog.md.

</details>

### 🏁 22) Salvage Race

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/player/missions/cw_salvagerace.lua`.

**What it does:** A War Contract (0.35 War Heat) spawning a wreckage field, rival scavenger ships, and a defensive patrol at a hostile sector. The player must salvage a quota of a distance-tiered raw material within a 5-minute window before the contract fails — "before it despawns" urgency via a real timeout, not just flavor text. Reward scales with the giver/enemy pair's current `CosmicWarBridge.getWarScore()` margin, up to +50% — the first contract to tie its payout directly to that scoreboard.

</details>

### 🏴‍☠️ 23) Deniable Raid

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/player/missions/cw_deniableraid.lua`.

**What it does:** A War Contract (0.45 War Heat) always flagged as pirate activity, regardless of whether the giver has a real registered enemy — unlike Border Skirmish, which only falls back to a pirate target when no real enemy exists, deniability is the entire premise here, not a fallback for a missing target. If the giver does have a real registered enemy, the raid banks 20 Intel against that enemy via `CosmicWarBridge.grantIntel()`, extending Intel-earning beyond the three dedicated 0.15-tier recon missions.

</details>

### 🏆 24) Decisive Push

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/player/missions/cw_decisivepush.lua`.

**What it does:** The first War Contract gated on War Score itself rather than raw War Heat. Only offered once a faction pair's War Score is 150–249 with the giver ahead — close to, but short of, the 250-point Decisive Victory threshold. Completing it destroys a defended fleet and credits a 25-point territory-weight War Score contribution (`CosmicWarBridge.recordWarScoreTerritory`), the same weight a real station capture gets — giving players direct agency to finish a war that's already nearly decided instead of only ever waiting on the background roll.

</details>

### 🚢 25) Prize Crew

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/player/missions/cw_prizecrew.lua`.

**What it does:** Capture an enemy escort ship intact instead of destroying it. Reduce the flagged target below 25% hull while it's still alive, and a scripted prize crew flips its `factionIndex` to the giver faction — the same mechanism `trooptransport.lua` already uses to capture stations, retargeted at a Ship. Destroying the target outright instead of disabling it fails the contract (checked every tick via a dedicated failure trigger).

> [!NOTE]
> This deliberately does NOT use vanilla's `Boarding` component or `AIState.Boarding` — ship-level capture through that system has never been resolved anywhere in this workspace, and this mission sidesteps that uncertainty entirely by reusing this mod's own already-proven station-capture mechanism (direct `factionIndex` reassignment) against a Ship instead. Only the target *type* is new; the underlying mechanism shipped and has been correct since the base v4.0.0 pass.

</details>

### 🏘️ 26) Refugee Resettlement

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/player/missions/cw_refugeeresettlement.lua`.

**What it does:** The first tie between Humanitarian Contracts and territorial Expansion Momentum. Gated on Famine ≥50 and the giver faction having the Imperialist trait, the delivery destination is a sector the faction is actively expanding toward (`CosmicWarBridge.findExpansionCandidate()` — the same directional walk the Imperialist trait's own organic growth and the Intelligence Network's preview both already use), rather than the giver's own sector like Relief Convoy. Successful delivery directly settles that sector for the faction via `CosmicVaultTerritory.expandToSector()` if it's still unclaimed — a guaranteed, player-assisted expansion rather than leaving it to the organic roll's own chance.

</details>

### 🌌 27) Dynamic Wartime Subspace Corridors

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/server/background/cosmicwarsubspacecorridors.lua`, `data/scripts/player/cw_siege_injector_persistent.lua`.

**What it does:** At maximum War Heat (1.00 — the same rare threshold gating Decapitation Strike/Champion Duel/Extract POW), a war has a rolling per-pass chance to tear open a genuine subspace wormhole connecting the two factions' home sectors. Feasibility confirmed against vanilla: `Sector():createWormHole(x, y, color, size)` is the same native convenience function vanilla's own galaxy generation uses, gated by `SectorGenerator:wormHoleAllowed(from, to)` — the same passability/barrier check vanilla's own wormhole network construction runs, called live against a freshly-constructed `SectorGenerator` instance rather than only at map-generation time.

**Permanent by design, not timed:** removing a spawned entity later would require that exact sector to be loaded again at the expiry moment — the same "can't touch an unloaded sector" constraint this mod's entire territory system already exists to avoid. Once torn, a corridor stays open for the rest of the save, framed as a lasting scar the war left in subspace rather than a cosmetic, temporary effect.

**Materialization:** only a flag pair is set when a corridor is granted (`cw_corridor_at_<x>:<y>` reverse-lookup keys at both endpoints); the actual wormhole entities are lazily created the first time a player is physically present at either endpoint sector, same pattern as Planetary Defense Generators above.

</details>

### 💰 28) Live Battlefield Salvage Markets

<details>
<summary><b>Click to expand details</b></summary>

**Primary files:** `data/scripts/events/siegeevent.lua`, `data/scripts/entity/merchants/tradingpost.lua`.

**What it does:** A 40% chance any physical siege (`SiegeEvent.startSiege`) spawns a temporary "Black Market Salvage Post" — a `tradingpost.lua`-based station owned by the defending faction, flagged `cw_salvage_market` — offering a new "Sell Salvage For A Premium" interaction that buys the player's entire raw-material hold in one transaction at a flat rate well above ordinary trade value (5-1,500 Cr/unit depending on material, Iron cheapest through Avorion most valuable). Framed as the defenders' desperation for liquidity mid-siege. Cleans itself up once every player leaves the sector (`deleteonplayersleft.lua`, the same cleanup this mod already uses for other temporary siege-adjacent structures).

</details>

### 🤝 29) Alliance War Councils

<details>
<summary><b>Click to expand details</b></summary>

**Primary file:** `data/scripts/lib/cosmicwarbridge.lua`.

**What it does:** Intel banking (`grantIntel`/`getIntel`/`spendIntel`) now resolves to a player's Player Alliance when they belong to one, instead of always the individual player — co-belligerent Alliance members now scout as one shared intelligence apparatus (a single pooled `/cosmicwarintel` balance per scouted faction) instead of each independently tracking their own in isolation. Built on Cosmic Vault v3.8.0's new generic ledger primitive (`CosmicVaultFaction.grantLedger`/etc.), which accepts either a `Player()` or an `Alliance()` transparently since both expose the same `getValue`/`setValue` interface. War Score itself needed no change here — it was already a per-faction-pair scoreboard visible to every player regardless of Alliance membership, not a per-player one.

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

Cosmic War requires the base game plus the full Core 4 + Vault suite:

- **Avorion** 1.0+
- **Cosmic Vault** (shared faction index API and data contracts, required by every Cosmic mod)
- **Cosmic Overhaul**
- **Cosmic Chronicles**
- **Cosmic Ascendancy**

`modinfo.lua` itself only declares Vault, Overhaul, and Chronicles: the Core 4 (Overhaul, War, Chronicles, Ascendancy) deliberately never cross-declare each other there, since Avorion's dependency resolver flags a mutual/circular requirement as a load error. Ascendancy is enforced instead through Cosmic War's Steam Workshop "Require Items" listing, the same mechanism the other Core 4 mods already use for each other. The Eclipse faction's hardcoded Imperialist/Vengeful stance and the Eclipse Sanitization Protocol ceasefire event both depend on Ascendancy content and assume it's present; `eclipse_fully_awake` still gates them, but as the game-state check it always was (the Eclipse's own multi-stage awakening, most galaxies won't reach early) rather than an "is the mod even installed" guard.

### Compatibility Intent

- Built to coexist with Cosmic Overhaul; bridge-style integration avoids hard coupling to it.
- For large custom stacks, verify load order and check server startup logs.

---

## 🛠️ Installation & Troubleshooting

### 🛠️ Installation

1. Place the folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install Cosmic Vault, Cosmic Overhaul, Cosmic Chronicles, and Cosmic Ascendancy.
3. Enable **Cosmic War** under **Settings -> Mods**.
4. Restart the game or server.

### 🛠️ Troubleshooting Checklist

- [ ] Confirm the mod is active in your Avorion mod settings.
- [ ] Confirm Cosmic Vault, Cosmic Overhaul, Cosmic Chronicles, and Cosmic Ascendancy are installed.
- [ ] Review the latest client/server logs for early startup warnings.
- [ ] Validate load order if running a heavily modified stack.
- [ ] Use `/cosmicwarstatus` in-game for operational diagnostics.
- [ ] Use `/cosmicwarbounties` in-game to check your active Bounty License and the top of the bounty board.

---

## 📈 Development Status

Cosmic War is at **v4.0.0**, a complete overhaul following the War Contracts & Bounties Expansion (v3.3.0) and the incremental hardening releases through v3.4.5. Current work focuses on:

- A legible, per-conflict War Score replacing raw relations numbers as the way players read "who's winning."
- Famine as a two-way lever (Humanitarian Contracts) rather than a one-way accumulator.
- Deeper Cosmic Ascendancy integration (Coalition Ceasefires) now that the dependency is guaranteed present.
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
