# Cosmic War

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Cosmic War** is part of the *Cosmic* mod series and focuses on dynamic faction relations, rivalry escalation, persistent war pressure between AI factions, and conquest-oriented galaxy conflict dynamics.

It is designed to complement **Cosmic Overhaul** while remaining fully standalone.

---

## 🚀 Current Version (0.4.0)

Cosmic War turns background faction diplomacy into an active, persistent conflict layer that evolves while you play.

### What this mod actually does:

**1. War-Focused AI Faction Setup**
* **Files:** `data/scripts/server/factions.lua`
* **Mechanic:** On AI faction creation and initialization, Cosmic War injects a war-oriented personality pressure. It stores persistent per-faction values (`cw_enabled`, `cw_war_bias`, `cw_diplomatic_polarity`).
* **Gameplay Impact:** The galaxy starts with clearer, established geopolitical personalities instead of flat or purely random faction behavior.

**2. Sector War-Pressure Escalation**
* **Files:** `data/scripts/sector/init.lua`, `data/scripts/sector/cosmicwarcontroller.lua`
* **Mechanic:** Periodically evaluates local sector conditions and pushes likely conflict pairs toward active rivalry, utilizing spacing and cooldowns to avoid event spam.
* **Gameplay Impact:** Hot sectors become politically unstable and can easily snowball into recurring conflict zones.

**3. Ongoing Diplomacy Drift**
* **Files:** `data/scripts/player/init.lua`, `data/scripts/player/background/cosmicwardiplomacy.lua`
* **Mechanic:** Continuously evaluates faction-pair relations and nudges diplomacy over time. Sets and maintains enemy targeting metadata where rivalries deepen.
* **Gameplay Impact:** Wars feel persistent and systemic instead of acting as isolated, one-off events.

**4. War News & Bulletin Layer**
* **Files:** `data/scripts/server/background/cosmicwarnews.lua`
* **Mechanic:** Broadcasts war-state updates to the player.
* **Gameplay Impact:** Provides better situational awareness, making conflicts feel “alive” and trackable across the galaxy.

**5. Diplomatic Sanctions System**
* **Files:** `data/scripts/server/background/cosmicwardiplomaticsanctions.lua`
* **Mechanic:** Factions locked in deep rivalries can receive economic penalties (sanction pressure).
* **Gameplay Impact:** Long wars carry a strategic and economic cost, adding depth beyond just combat noise.

**6. Ceasefire & Détente System**
* **Files:** `data/scripts/server/background/cosmicwarceasefires.lua`
* **Mechanic:** Rivalries can cool off when relations recover above a certain threshold, utilizing chance-based détente resolution. This clears enemy links when ceasefire conditions are met.
* **Gameplay Impact:** Conflict cycles can resolve naturally, allowing galaxy politics to shift and settle over time.

**7. War Bounty Generation**
* **Files:** `data/scripts/server/background/cosmicwarbounties.lua`
* **Mechanic:** Creates time-limited bounty states tied to active enemy factions (`cw_bounty_enemy`, `cw_bounty_reward`, `cw_bounty_expires`).
* **Gameplay Impact:** Adds emergent, lucrative incentives for players to engage in active faction wars.

**8. War Cleanup & Compatibility Hooks**
* **Files:** `data/scripts/sector/factionwar/temporarydefender.lua`, `data/scripts/sector/background/rebuildstations.lua`
* **Mechanic:** Adds behavior wrappers to keep the conflict flow clean and prevent stale states in specific war-related engine paths.
* **Gameplay Impact:** Ensures better runtime stability and significantly reduces leftover wartime clutter.

**9. Player Commands & Tuning Controls**
* **Files:** `data/scripts/commands/cosmicwarstatus.lua`, `data/scripts/lib/cosmicwarconfig.lua`, `modconfig.lua`
* **Mechanic:** Exposes the `/cosmicwarstatus` command and bridges the simulation to the Mod Configuration Menu (MCM).
* **Gameplay Impact:** You can inspect, debug, and tune the war simulation behavior directly in-game without hard-editing scripts.

### TL;DR
Cosmic War makes faction politics dynamic and persistent:
* Factions become more distinct in their war behaviors.
* Rivalries escalate into meaningful conflict pressure.
* Wars can organically create economic sanctions and player bounties.
* Ceasefires can happen naturally when diplomacy recovers.
* Players get better visibility and configuration controls over the sandbox.

In short: **The galaxy feels less static and more like an evolving geopolitical war sandbox.**

---

## 📦 Required Dependencies

Cosmic War uses **Mod Configuration Menu (MCM)** as a required dependency. This dependency is strictly declared in `modinfo.lua`.
* **Workshop ID:** `3674093144`

---

## 🌐 Multiplayer / Dedicated Server Notes

Avorion runs gameplay scripts server-side even in singleplayer (local hosted server model), so Cosmic War systems are designed for server execution and synchronize naturally with clients.

* `serverSideOnly = false` remains intentional because entity, sector, and player script paths are expected on both sides in Avorion’s script architecture.
* Core war state updates are performed safely on server contexts (`updateServer`, server init hooks).

---

## ⚙️ Design & Compatibility Notes

* Uses `include()` (Avorion-compatible) instead of `require()`.
* Preserves upstream behavior via wrappers rather than outright replacing vanilla logic.
* Keeps update frequency conservative to drastically reduce server overhead.
* Uses persistent faction values to guarantee save-game continuity and allow for future expansion.
* Built to coexist natively with **Cosmic Overhaul** without direct hard coupling.

---

## 📥 Installation

1. Place the mod folder into your Avorion mods directory:
   * **Windows:** `%AppData%\Avorion\mods\`
   * **Linux:** `~/.avorion/mods/`
2. Launch the game and enable it via **Settings -> Mods**.