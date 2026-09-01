# 🌌 Cosmic War

*A complete overhaul to diplomacy, fleet battles, and faction tension in Avorion.*

**Current release: v3.4.0** - a UI-polish and bugfix pass following the War Contracts & Bounties Expansion.

---

## 📖 Overview

**Cosmic War** turns Avorion's static political landscape into a living geopolitical simulation. Factions track War Heat with their neighbors through skirmishes, intercepts, and trait differences. When tensions boil over, they declare full-scale war and launch dynamically scaled Dreadnought invasions to capture enemy territory and physically expand their borders on the Galaxy Map.

Players aren't bystanders. Fund rebellions through the Galactic Politics UI, answer distress beacons, claim Bounty Licenses, or sign up as a mercenary and take on 22 War Contracts.

---

## ✨ Key Features

<details>
<summary><b>Click to expand full feature list</b></summary>

### ⚔️ Dynamic Geopolitics
- **War Heat System:** factions build tension and declare war dynamically based on borders and traits.
- **Dynamic Faction Traits:** AI factions spawn with 9 mechanically active behavioral traits (*Imperialist*, *Vengeful*, *Mercantile*, *Xenophobic*, and more).
- **Dormant Trait Revival:** 4 previously unused vanilla traits (`Active/Passive`, `Strict/Forgiving`, `Smart/Dumb`, `Sadistic/Sympathetic`) are back in play for deeper AI decisions.

### 🛡️ Tactical Warfare & Sieges
- **Dynamic Invasions:** fleet invasions scale mathematically to match 100% of the target sector's defensive strength.
- **Siege Dreadnoughts:** invasion flagships spawn with a 5x shield multiplier to tank station point-defense arrays.
- **Electronic Warfare:** sieges have a 35% chance and open fleet clashes a 15% chance to deploy a Shield Jammer, pinning all defending shields (including yours) to 0 for 10 seconds.
- **Planetary Defense Grids:** some sectors run Planetary Shield Generators that make every allied station invincible until the generator falls.

### 💰 Mercenary Operations
- **Galactic Politics UI:** a detailed tab tracking every active conflict, ceasefire, and faction relation galaxy-wide, with a dedicated sortable Bounty column and your own License status right in the header.
- **`/cosmicwarbounties` chat command:** new in v3.4.0. Check your active Bounty License and the top of the galaxy-wide bounty board without opening the UI.
- **Bounty Licenses:** destroy your first target against a faction with an active bounty to start a 45-minute, 15-kill hunting license for major payouts.
- **Dynamic War Contracts:** 22 mercenary missions injected into Bulletin Boards based on the sector's current War Heat (*Force Recon*, *Resource Heist*, *Blockade Runner*, *Distraction Carnage*, *Decapitation Strike*, and more), all clickable and completable as of v3.4.0.

### 🚀 Dynamic Galaxy Expansion
- **Territory Expansion:** factions expand their borders by launching troop transports to physically board and capture enemy stations.
- **Background Conquests:** contested zones carry hidden siege timers, flipping ownership mathematically without the performance cost of keeping every sector loaded.
- **War Casualties & Events:** stumble across refugee convoys fleeing violence, wreckage fields, bounty hunter ambushes, or distress beacons from destroyed prototype flagships.

### 📰 Galactic News Network
- **Live war coverage:** bounty postings and completions, ceasefires, war declarations, and sector conquests all publish to the Galactic News Network.
- **Bounty & ceasefire coverage:** new in v3.4.0. Fully completing a War Bounty License and factions reaching an actual ceasefire now generate their own news articles, closing the loop on two milestones that used to be visible only in local chat.

</details>

---

## ⚙️ Requirements

- **Avorion 1.0+**
- **Hard dependencies** (enforced by `modinfo.lua`):
  - **Cosmic Vault** - shared faction API and data contracts, required by every Cosmic mod.
  - **Cosmic Overhaul**
  - **Cosmic Chronicles**

Cosmic Ascendancy is not required to run Cosmic War. A few features (the Eclipse faction's hardcoded stances, the Eclipse Sanitization Protocol) reference Ascendancy content and light up automatically if you also happen to have it installed - everything else works without it.

---

## 🚀 Installation

1. Place the extracted `Cosmic War` folder in your Avorion mods directory:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install the required dependencies: Cosmic Vault, Cosmic Overhaul, Cosmic Chronicles.
3. Launch Avorion, go to **Settings -> Mods**, and enable **Cosmic War**.
4. Restart the game or dedicated server when prompted.

---

## 📚 Documentation & Diagnostics

- **In-Game Lore:** deep lore, stat blocks, and dynamic features live in the in-game **Cosmic Codex** - no need to tab out to learn the mod.
- **Offline Guides:** the included `WIKI.md` (technical reference) and `PLAYER_GUIDE.md` (gameplay-focused) cover the full mechanics, scaling equations, and background systems.
- **Diagnostics:** server operators can run `/cosmicwarstatus` in chat for a live health and activity readout of the background simulation.
- **Bounty Board:** any player can run `/cosmicwarbounties` in chat to check their active Bounty License and the top of the galaxy-wide bounty board without opening the UI.
