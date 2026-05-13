# Cosmic War - Detailed Features

This page contains the full, detailed documentation for **Cosmic War**, the faction-conflict simulation module in the Cosmic mod series.

Cosmic War is designed to:
- run standalone, and
- synergize with **Cosmic Overhaul** through optional bridge behavior where available.

---

## Mod Identity & Design Goals

**Primary focus:** Living, persistent AI faction politics and war-state simulation.

**Core goals:**
1. Make galaxy politics feel active instead of static.
2. Produce sustained war/cooling cycles over long sessions.
3. Surface war-state consequences to players (news, bounties, sanctions pressure).
4. Remain configurable and server-operator friendly through MCM.
5. Preserve compatibility by favoring non-invasive wrappers and safe guards.

---

## Architecture Summary

Cosmic War uses a layered simulation model:

1. **Faction-level baseline traits** are seeded/maintained.
2. **Sector-level pressure loops** escalate local rivalries.
3. **Global diplomacy drift** keeps politics moving over time.
4. **War-side effects** (sanctions, bounties, bulletins, ceasefires) create visible outcomes.
5. **Optional cross-mod bridges** can influence command prediction overlays when enabled.

This produces cyclical macro behavior:
- tension → war pressure → side effects → détente potential → re-escalation.

---

## Full Feature Breakdown

## 1) War-Oriented AI Faction Seeding
**Primary file:** `data/scripts/server/factions.lua`

### What it does
Injects and maintains faction-level war metadata for AI factions so behavior trends are less random and more identity-driven over time.

### Typical stored values (examples)
- `cw_enabled`
- `cw_war_bias`
- `cw_diplomatic_polarity`
- rivalry target helpers used by downstream systems

### Gameplay impact
- AI factions feel less interchangeable.
- Rivalries become more coherent in long campaigns.
- Better continuity between isolated events and long-term politics.

---

## 2) Sector War-Pressure Controller
**Primary files:**
- `data/scripts/sector/init.lua`
- `data/scripts/sector/cosmicwarcontroller.lua`

### What it does
Runs periodic sector-level scans and applies pressure to selected faction pairs when local conflict conditions align.

### Behavior goals
- Encourage natural hotspot emergence.
- Avoid spam via spacing/cooldown logic.
- Prevent every loaded sector from escalating identically.

### Gameplay impact
- Frontlines and contested regions emerge organically.
- Different sectors can diverge into quiet vs. volatile states.

---

## 3) Persistent Diplomacy Drift
**Primary files:**
- `data/scripts/player/init.lua`
- `data/scripts/player/background/cosmicwardiplomacy.lua`

### What it does
Periodically evaluates random/eligible faction-pair subsets and nudges diplomacy over time.

### Why it matters
Without drift, diplomacy can remain too static between discrete scripted events.

### Gameplay impact
- Politics evolve continuously.
- Rivalry maintenance feels systemic, not scripted-only.

---

## 4) War News / Broadcast Layer
**Primary file:** `data/scripts/server/background/cosmicwarnews.lua`

### What it does
Publishes periodic war bulletins to improve player awareness of macro conflict shifts.

### Implementation style
- Collects currently hot conflicts.
- Chooses one using stable randomization.
- Broadcasts informational message server-wide.

### Gameplay impact
- Players can react strategically to political shifts.
- Background simulation becomes visible and actionable.

---

## 5) Diplomatic Sanctions Pressure
**Primary file:** `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`

### What it does
Applies sanction-like pressure behavior tied to entrenched rivalries and hostile diplomatic states.

### Gameplay impact
- Wars have economic/diplomatic consequences, not only combat outcomes.
- Political hostility influences broader strategic conditions.

---

## 6) Ceasefire / Détente Logic
**Primary file:** `data/scripts/server/background/cosmicwarceasefires.lua`

### What it does
Allows conditional de-escalation when hostility recovers and ceasefire chance criteria are met.

### Gameplay impact
- Conflict cycles can resolve naturally.
- The galaxy does not lock permanently into one escalated state.

---

## 7) War Bounty Generation
**Primary file:** `data/scripts/server/background/cosmicwarbounties.lua`

### What it does
Creates time-bound bounty opportunities linked to active faction rivalries.

### Typical stored value pattern
- target faction id
- reward value
- expiration runtime

### Gameplay impact
- Gives players direct incentives to engage with active wars.
- Converts geopolitical state into mission-like opportunities.

---

## 8) Runtime Cleanup / Compatibility Hooks
**Primary files:**
- `data/scripts/sector/factionwar/temporarydefender.lua`
- `data/scripts/sector/background/rebuildstations.lua`

### What it does
Adds lifecycle-safe wrappers in selected war-adjacent paths to reduce stale wartime leftovers and transition artifacts.

### Gameplay impact
- Cleaner war transitions.
- Lower chance of lingering war-state artifacts.

---

## 9) Admin/Diagnostics Command
**Primary file:** `data/scripts/commands/cosmicwarstatus.lua`

### Command
- `/cosmicwarstatus`

### What it provides
- quick status/health visibility
- easier balancing/debug workflows
- sanity checks for running servers

### Stability hardening
Command path includes readiness guards (e.g., galaxy API availability checks) for safer early lifecycle behavior.

---

## 10) MCM Configuration Integration
**Primary files:**
- `modconfig.lua`
- `data/scripts/lib/cosmicwarconfig.lua`
- `modinfo.lua`

### Dependency
- **Mod Configuration Menu (MCM)** (required)

### Config groups currently exposed

#### War Pressure
- `sectorPressureInterval`
- `sectorPressureChance`
- `sectorPressureMinSpacing`

#### Diplomacy
- `diplomacyInterval`
- `diplomacyPairSteps`
- `rivalryThreshold`

#### Diagnostics
- `debugLogs`

### Config handling notes
- Numeric values are clamped to safe ranges.
- Percent slider values are normalized for simulation use.
- Config bridge returns defaults if MCM/config context is unavailable.

---

## 11) Stability Hardening
Recent iterations include:
- safer startup behavior during early server lifecycle
- callable guards around faction-fetch paths
- defensive checks in background loops

### Gameplay/ops impact
- fewer nil-method crashes at startup
- stronger behavior in heavily modded stacks

---

## 12) Cosmic Overhaul Synergy (Bridge Layer)
**Primary bridge files:**
- `data/scripts/lib/cosmicwareconomybridge.lua`
- `data/scripts/lib/cosmicwarcaptainbridge.lua`

**Typical wrapper targets (when present in stack):**
- command prediction hooks in simulation scripts (trade/scout/travel/refine/mine/salvage variants)

### Design intent
- non-invasive composition over hard overwrite
- original prediction path runs first
- bridge applies bounded post-processing only when enabled and context is valid
- graceful no-op fallback when disabled or missing context

### High-level effect
- command planning outputs can reflect war-heat pressure more clearly
- baseline behavior is preserved when bridge toggles are disabled

---

## Multiplayer / Dedicated Server Behavior

- Avorion simulation is server-authoritative.
- Cosmic War logic is predominantly server-side with synchronization-aware behavior where needed.
- In mixed mod stacks, keep configuration/load order consistent and validate logs at startup.

---

## Performance & Safety Notes

- Interval-driven loops are favored over per-frame heavy logic.
- Defensive nil/callable checks are used in high-risk lifecycle paths.
- Debug logging is toggleable via config to reduce noise and overhead in production environments.

---

## Dependency & Compatibility

## Required
- Avorion
- Mod Configuration Menu (MCM)

## Compatibility intent
- Built to coexist with Cosmic Overhaul.
- Bridge-style integration aims to avoid hard coupling.
- For large stacks, verify load order and startup logs.

---

## Installation

1. Place folder in:
   - Windows: `%AppData%\Avorion\mods\`
   - Linux: `~/.avorion/mods/`
2. Ensure MCM is installed/enabled.
3. Enable Cosmic War in **Settings -> Mods**.
4. Restart game/server.

---

## Troubleshooting Checklist

1. Confirm mod is enabled in Avorion mod settings.
2. Confirm MCM dependency is enabled and loaded.
3. Review latest client/server logs for early startup warnings.
4. Validate load order in large mod stacks.
5. Use `/cosmicwarstatus` for quick operational diagnostics.

---

## Development Status

Cosmic War remains an actively iterated WIP with ongoing balancing and long-session validation.

The current architecture is focused on:
- resilient lifecycle behavior,
- configurable war simulation,
- and stable coexistence with broader Cosmic-series mod stacks.
