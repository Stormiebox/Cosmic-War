# Cosmic War

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Cosmic War** is part of the *Cosmic* mod series and focuses on dynamic faction relations, rivalry escalation, persistent war pressure between AI factions, and conquest-oriented galaxy conflict dynamics.

It is designed to complement **Cosmic Overhaul** while remaining fully standalone.

---

## 🚀 Current Version (0.4.0)

This version expands Cosmic War’s runtime architecture into a broader war and politics simulation:

* **Extended Faction Initialization** (`data/scripts/server/factions.lua`)
  * Wraps `initializeAIFaction(...)`
  * Applies war/diplomatic trait pressure
  * Stores persistent variables: `cw_enabled`, `cw_war_bias`, `cw_diplomatic_polarity`
* **Sector War-Pressure Runtime**
  * `data/scripts/sector/init.lua`
  * `data/scripts/sector/cosmicwarcontroller.lua`
* **Player-Attached Diplomacy Drift**
  * `data/scripts/player/init.lua`
  * `data/scripts/player/background/cosmicwardiplomacy.lua`
* **Server-Side Systems**
  * News/bulletins: `cosmicwarnews.lua`
  * Diplomatic sanctions: `cosmicwardiplomaticsanctions.lua`
  * Ceasefire / détente handling: `cosmicwarceasefires.lua`
  * Bounty generation for active rivalries: `cosmicwarbounties.lua`
* **Quality-of-Life War Cleanup & Hooks**
  * `temporarydefender.lua`
  * `rebuildstations.lua`
* **Commands & Configuration**
  * Status command: `/cosmicwarstatus` via `cosmicwarstatus.lua`
  * Centralized tunable config library: `cosmicwarconfig.lua`
  * MCM schema for in-game tuning: `modconfig.lua`

---

## 📦 Required Dependencies

Cosmic War uses **Mod Configuration Menu (MCM)** as a required dependency. This dependency is strictly declared in `modinfo.lua`.
* **Workshop ID:** `3674093144`

---

## 🌐 Multiplayer / Dedicated Server Notes

Avorion runs gameplay scripts server-side even in singleplayer (local hosted server model), so Cosmic War systems are designed for server execution and synchronize naturally with clients.

* `serverSideOnly = false` remains intentional because entity, sector, and player script paths are expected on both sides in Avorion’s script architecture.
* Core war state updates are performed on server contexts (`updateServer`, server init hooks).

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