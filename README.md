# 🌌 Cosmic War

*A complete overhaul to diplomacy, fleet battles, and faction tension in Avorion.*

![Version](https://img.shields.io/badge/version-4.0.0-6f42c1?style=flat-square)
![Avorion](https://img.shields.io/badge/Avorion-2.5.13-2f81f7?style=flat-square)
![License](https://img.shields.io/badge/license-GPLv3-informational?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=flat-square)
![Requires](https://img.shields.io/badge/requires-Core%204-success?style=flat-square)

**Current release: v4.0.0** - a complete overhaul: four new systems and a full numbers-and-balance pass.

> [!TIP]
> New here? [`PLAYER_GUIDE.md`](https://github.com/Stormiebox/Cosmic-War/wiki/Players-Guide-A-Living-Conflict) is a friendly gameplay tour. [`WIKI.md`](https://github.com/Stormiebox/Cosmic-War/wiki/Features-and-Enhancements) has the full technical reference with exact numbers.

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

### 🆕 New in v4.0.0
- **War Score & Attrition:** every war keeps a real scoreboard now - hover a conflict in the Galactic Politics tab to see who's winning. Long wars trend toward peace on their own, and decisive wars can end outright with real consequences for the loser.
- **Intelligence Network:** recon-flavored War Contracts bank Intel you can spend with `/cosmicwarintel` to preview a rival faction's next expansion move.
- **Humanitarian Contracts:** Relief Convoy missions and a new Sanctions Relief option at Trading Posts give Famine a real player-facing way down, not just up.
- **Coalition Ceasefires:** when the Eclipse becomes a serious threat, every warring faction galaxy-wide gets pulled into a temporary truce.

</details>

---

## ⚙️ Requirements

- **Avorion 1.0+**
- **Required mods:**
  - **Cosmic Vault** - shared faction API and data contracts, required by every Cosmic mod.
  - **Cosmic Overhaul**
  - **Cosmic Chronicles**
  - **Cosmic Ascendancy**

`modinfo.lua` itself only enforces Vault, Overhaul, and Chronicles - the Core 4 (Overhaul, War, Chronicles, Ascendancy) deliberately never cross-declare each other there, since Avorion treats a mutual dependency as a circular-load error. Ascendancy is required through Cosmic War's Steam Workshop "Require Items" listing instead, the same way the rest of the Core 4 already require each other. The Eclipse faction's hardcoded stances and the Eclipse Sanitization Protocol both depend on Ascendancy content being present.

---

## 🚀 Installation

1. Place the extracted `Cosmic War` folder in your Avorion mods directory:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install the required dependencies: Cosmic Vault, Cosmic Overhaul, Cosmic Chronicles, Cosmic Ascendancy.
3. Launch Avorion, go to **Settings -> Mods**, and enable **Cosmic War**.
4. Restart the game or dedicated server when prompted.

---

## 📚 Documentation & Diagnostics

| Document | For | Covers |
|---|---|---|
| [`PLAYER_GUIDE.md`](https://github.com/Stormiebox/Cosmic-War/wiki/Players-Guide-A-Living-Conflict) | Players | A friendly, gameplay-focused walkthrough of every feature. |
| [`WIKI.md`](https://github.com/Stormiebox/Cosmic-War/wiki/Features-and-Enhancements) | Anyone who wants the exact numbers | Full mechanics, scaling equations, and background systems. |
| **Cosmic Codex** *(in-game)* | Players | Deep lore, stat blocks, and dynamic features, without tabbing out. |

**Chat commands:**

| Command | Who | Does |
|---|---|---|
| `/cosmicwarstatus` | Server operators | Live health and activity readout of the background simulation. |
| `/cosmicwarbounties` | Any player | Check your active Bounty License and the top of the galaxy-wide bounty board without opening the UI. |

---

<div align="center">

**🌌 Cosmic War** — part of the [Cosmic Series](https://github.com/Stormiebox) · built by **Stormbox**

</div>
