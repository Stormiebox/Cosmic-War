# Cosmic War
*Current Version: v2.0.2*

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

- **Dynamic Escalation:** Replaces the static vanilla war system with a fluid "War Heat" spectrum.
- **Deep Economy Impacts:** Wars drain military station stocks (War Profiteering), allowing smugglers to reap massive profits.
- **Functional War Bounties:** Track, hunt, and destroy targeted faction ships/stations to instantly cash in massive credit bounties and trigger Galactic News broadcasts of your success.
- **Persistent Flashpoints:** Introduces fleet clashes, wreckage fields, civilian blockades, and elite headhunter hit-squads.
- **Galactic News Integration:** Broadcasts shifting borders, blockades, and ceasefires natively to the Cosmic Vault News API.
- **Modular Ecosystem:** Runs 100% standalone, but features seamless "soft-bridges" that naturally hook into Cosmic Overhaul, Cosmic Starfall, and Cosmic Chronicles.

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
- See `Cosmic_War_CHANGELOG.md` for detailed project change history.

