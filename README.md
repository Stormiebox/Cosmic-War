# Cosmic War

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Cosmic War** is part of the *Cosmic* mod series and focuses on dynamic faction relations, rivalry escalation, persistent war pressure, and galaxy-wide conflict simulation between AI factions.

It is designed to complement **Cosmic Overhaul** while remaining standalone.

---

## Project Status

> **Work in Progress (WIP)**
Cosmic War is currently under active stress-testing in long-form playthroughs (including alongside Cosmic Overhaul).
It is available on GitHub first and not yet considered final-release stable for Steam Workshop publication.

---

## Overview

Vanilla faction diplomacy can feel static over long sessions. Cosmic War introduces a persistent geopolitical simulation layer that:

- gives factions stronger strategic identity,
- escalates rivalries into active pressure,
- creates war-side effects (sanctions, bounties, news),
- and allows eventual cooling/ceasefire cycles.

The result is a galaxy that feels less frozen and more like a living political sandbox.

---

## Full Feature Rundown (Detailed)

---

### 1) War-Oriented AI Faction Seeding

**Files:** `data/scripts/server/factions.lua`

**What it does:**
On AI faction creation/initialization, Cosmic War injects persistent faction-level war personality values (e.g. war bias / polarity style markers) used by downstream systems.

**Why it matters:**
Without this layer, faction conflict behavior trends can be flatter and less coherent.

**Gameplay impact:**
- More distinctive faction personalities.
- Better long-term conflict identity across the galaxy.

---

### 2) Sector War-Pressure Controller

**Files:** `data/scripts/sector/init.lua`, `data/scripts/sector/cosmicwarcontroller.lua`

**What it does:**
Runs periodic sector-level pressure logic that evaluates local conflict conditions and applies rivalry pressure between likely opposing factions. Uses spacing/cooldown limits to avoid event spam.

**Key controls (MCM-backed):**
- pressure interval,
- trigger chance,
- minimum spacing.

**Gameplay impact:**
- Conflict hotspots emerge naturally.
- “Quiet sectors” and “active fronts” diverge more clearly over time.

---

### 3) Persistent Diplomacy Drift

**Files:** `data/scripts/player/init.lua`, `data/scripts/player/background/cosmicwardiplomacy.lua`

**What it does:**
Periodically evaluates faction pair states and nudges diplomacy trajectories over time. Helps sustain rivalry progression and enemy-target continuity where appropriate.

**Gameplay impact:**
- Diplomacy evolves continuously, not only via isolated events.
- Long wars feel systemic and persistent.

---

### 4) War News / Situation Awareness Layer

**Files:** `data/scripts/server/background/cosmicwarnews.lua`

**What it does:**
Produces war-state updates to make conflict developments visible to players instead of hidden in background simulation only.

**Gameplay impact:**
- Better awareness of macro-level conflict shifts.
- Easier strategic reaction by players.

---

### 5) Diplomatic Sanctions System

**Files:** `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`

**What it does:**
Applies economic pressure dynamics to entrenched rivalries via sanction-like behavior.

**Gameplay impact:**
- Wars have meaningful non-combat consequences.
- Economic and diplomatic states are more tightly coupled.

---

### 6) Ceasefire / Détente Resolution

**Files:** `data/scripts/server/background/cosmicwarceasefires.lua`

**What it does:**
When hostility recovers above configured thresholds, rivalries can de-escalate through chance/condition-based détente logic and clean state transitions.

**Gameplay impact:**
- Conflicts can resolve organically.
- Galaxy politics can cycle, reset, and re-form naturally.

---

### 7) War Bounty Generation

**Files:** `data/scripts/server/background/cosmicwarbounties.lua`

**What it does:**
Creates time-bound bounty opportunities connected to active enemy-war states (persistent values for target, reward, and expiry).

**Gameplay impact:**
- Adds direct player incentive to engage with active wars.
- War zones become lucrative gameplay opportunities.

---

### 8) Cleanup & Compatibility Hooks

**Files:** `data/scripts/sector/factionwar/temporarydefender.lua`, `data/scripts/sector/background/rebuildstations.lua`

**What it does:**
Adds lifecycle wrappers/hooks to reduce stale wartime leftovers and improve behavior consistency in specific war-related engine paths.

**Gameplay impact:**
- Cleaner runtime conflict transitions.
- Lower risk of persistent stale war artifacts.

---

### 9) Admin/Debug Command Support

**Files:** `data/scripts/commands/cosmicwarstatus.lua`

**What it does:**
Provides `/cosmicwarstatus` command pathway for diagnostics/inspection of active Cosmic War simulation state.

**Gameplay impact:**
- Easier operational visibility for testing/admin workflows.
- Better debugging support during balancing iterations.

---

### 10) MCM Configuration Integration (Required Dependency)

**Files:** `modconfig.lua`, `data/scripts/lib/cosmicwarconfig.lua`, `modinfo.lua`

**What it does:**
Uses **Mod Configuration Menu (MCM)** for in-game tuning of key war simulation parameters.

**Current configurable groups:**
- **War Pressure**
  - `sectorPressureInterval`
  - `sectorPressureChance`
  - `sectorPressureMinSpacing`
- **Diplomacy**
  - `diplomacyInterval`
  - `diplomacyPairSteps`
  - `rivalryThreshold`
- **Bridge Integration**
  - `enableEconomyBridge`
  - `enableCaptainBridge`
- **Diagnostics**
  - `debugLogs`

**Implementation details:**
- MCM values are read through `cosmicwarconfig.lua`.
- Numeric values are clamped to safe ranges.
- Percent sliders are normalized where needed for simulation math.
- Bridge toggles are read as booleans and applied as runtime gates.

**Gameplay impact:**
- Rapid balancing without hard-editing scripts.
- Better server operator control over simulation intensity.
- Enables safe opt-in/opt-out of cross-mod prediction influence in mixed stacks.

---

### 11) Stability Hardening (Early Init / Lifecycle Safety)

**Recent hardening focus includes:**
- Safer startup behavior when server API readiness is still in flux.
- Additional guards in background systems to avoid early nil-method issues.

**Gameplay impact:**
- Fewer initialization-time errors.
- Better resilience on heavily modded server stacks.

---

### 12) Cosmic Overhaul Synergy Bridges (Prediction Overlay Layer)

**Files:**
- `data/scripts/lib/cosmicwareconomybridge.lua`
- `data/scripts/lib/cosmicwarcaptainbridge.lua`
- `data/scripts/player/background/simulation/tradecommand.lua`
- `data/scripts/player/background/simulation/scoutcommand.lua`
- `data/scripts/player/background/simulation/travelcommand.lua`
- `data/scripts/player/background/simulation/refinecommand.lua`
- `data/scripts/player/background/simulation/minecommand.lua`
- `data/scripts/player/background/simulation/salvagecommand.lua`

**What it does:**
Adds a non-invasive post-processing bridge layer that composes with simulation command prediction flows to reflect Cosmic War pressure/heat in command planning outputs.

**Bridge behavior summary:**
- **Economy Bridge**
  - Applies bounded multipliers to trade-facing prediction values (profit/risk style metrics).
  - Neutral output (1.0 multipliers) when disabled via MCM.
- **Captain Bridge**
  - Modifies prediction objects based on faction war-heat context.
  - Returns unmodified predictions when disabled via MCM.

**Composition strategy (important for compatibility):**
- Wrappers call original command prediction methods first.
- Bridge transforms are applied only after a valid prediction is returned.
- If expected faction context is absent, wrapper exits cleanly and returns original prediction.
- Metadata is attached in namespaced form (e.g. `prediction.mcm.cosmicWar`) to reduce collision risk.

**Gameplay impact:**
- Better strategic readability when operating in active conflict zones.
- Prediction outputs better reflect macro political pressure from Cosmic War simulation.
- Preserves baseline command behavior when bridge toggles are off.

---

## TL;DR Gameplay Summary

Cosmic War turns faction politics into a continuous strategic layer:

- Factions become more war-distinct.
- Rivalries escalate in active sectors.
- Wars generate economic pressure and bounty opportunities.
- Ceasefires can occur naturally as diplomacy recovers.
- Command planning can reflect war pressure more clearly when bridge modules are enabled.
- Admins can tune behavior live through MCM.

---

## Dependencies

### Required
- **Avorion**
- **Mod Configuration Menu (MCM)**
  - Workshop ID: `3674093144`
  - Declared in `modinfo.lua`

---

## Multiplayer / Dedicated Server Notes

- Avorion gameplay simulation is server-authoritative (including local singleplayer host model).
- Cosmic War systems are designed around server-side updates with client synchronization where needed.
- `serverSideOnly = false` is intentional due to mixed script context requirements in Avorion’s architecture.
- In mixed mod stacks, ensure consistent mod configuration across client/server where applicable.

---

## Design / Technical Notes

- Uses Avorion-compatible `include()` loading patterns.
- Uses wrappers/hook-style integration to preserve vanilla or already-overridden behavior where possible.
- Uses conservative interval-driven background systems to minimize overhead.
- Stores persistent faction war state values for save continuity and future feature expansion.
- Cross-mod synergy layer uses post-original-call wrappers rather than hard overwrites of foreign mod internals.

---

## Installation

1. Place the mod folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Ensure dependency mod (**MCM**) is installed and enabled.
3. Enable Cosmic War in **Settings -> Mods**.
4. Restart game/server as needed.

---

## Compatibility

- Built to coexist with **Cosmic Overhaul** without direct hard-coupling.
- Cross-mod prediction synergy is toggleable through MCM:
  - `enableEconomyBridge`
  - `enableCaptainBridge`
- If running large mod stacks, validate load order and monitor logs during early startup.
- Runtime integration should be verified in your target load order before declaring stable release readiness.

---

## QA / Validation Notes

- Current pass included static QA and cross-file consistency review for bridge wrappers, config toggles, and compatibility composition patterns.
- Full runtime/in-game matrix testing (all toggle combinations, load-order permutations, and long-session soak) remains recommended before final Workshop release.

---

## Development Status Note

Cosmic War is currently in active development and stress testing.
Public Workshop release is planned once long-session stability and balance targets are fully met.
