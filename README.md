# Cosmic War

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Cosmic War** is the geopolitical conflict layer of the Cosmic series for Avorion.

It focuses on:
- dynamic faction rivalry escalation,
- persistent diplomacy drift,
- war-side effects (news, sanctions, bounties, ceasefires),
- and configurable long-session faction conflict simulation.

It is designed to run standalone and to synergize with **Cosmic Overhaul**.

---

## Full Documentation

For complete feature and architecture details, see:

- **`Cosmic_War_Wiki.md`**

---

## Quick Highlights

- Sector war-pressure controller for emergent conflict hotspots.
- Persistent diplomacy movement so politics evolve over time.
- Broadcast/news and bounty generation to expose macro war states to players.
- MCM-driven tuning for pressure, diplomacy, and diagnostics behavior.

---

## Installation

1. Place folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Ensure required dependency is installed:
   - **Mod Configuration Menu (MCM)**
3. Enable **Cosmic War** in **Settings -> Mods**.
4. Restart game/server as needed.

---

## Compatibility Snapshot

- Intended to coexist with Cosmic Overhaul.
- `serverSideOnly = false` (intentional for mixed script-context behavior).
- For dependency and compatibility specifics, see `modinfo.lua`.

---

## Operational Notes

- Use `/cosmicwarstatus` for runtime diagnostics visibility.
- In large mod stacks, validate load order and check logs during startup.
- See `CHANGELOG.md` for detailed project change history.
