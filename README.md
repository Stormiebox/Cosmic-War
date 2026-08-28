# 🌌 Cosmic War

*A complete overhaul to diplomacy, fleet battles, and faction tension in Avorion.*

## 📖 Overview
**Cosmic War** transforms the static political landscape of Avorion into a living, breathing geopolitical simulation. Factions now actively track "War Heat" with their neighbors through skirmishes, intercepts, and trait differences. When tensions boil over, they will declare full-scale war, launching massive, dynamically scaled Dreadnought invasions to systematically capture enemy territory and physically expand their borders on the Galaxy Map.

Players are not just bystanders—you can actively influence these conflicts! Fund rebellions via the Galactic Politics UI, answer distress beacons, claim massive Bounty Licenses, or sign up as a mercenary and take on 22 different highly scaled War Contracts.

---

## ✨ Key Features
<details>
<summary><b>Click to expand full feature list</b></summary>

### ⚔️ Dynamic Geopolitics
- **War Heat System:** Factions passively build tension and declare war dynamically based on borders and traits.
- **Dynamic Faction Traits:** AI factions spawn with 9 distinct, mechanically active behavioral traits (e.g., *Imperialist*, *Vengeful*, *Mercantile*, *Xenophobic*).
- **Dormant Trait Revival:** 4 previously unused vanilla traits (`Active/Passive`, `Strict/Forgiving`, `Smart/Dumb`, `Sadistic/Sympathetic`) have been reactivated for deeper AI decision-making.

### 🛡️ Tactical Warfare & Sieges
- **Dynamic Invasions:** Fully simulated fleet invasions featuring mathematical scaling that perfectly matches 100% of the target sector's defensive strength.
- **Siege Dreadnoughts:** Colossal invasion flagships spawn with a 5x shield multiplier to tank station point-defense arrays.
- **Electronic Warfare:** Invasions have a 50% chance to deploy a Shield Jammer, instantly pinning ALL defending shields (including yours!) to 0 for the first 20 seconds of an ambush.
- **Planetary Defense Grids:** Certain sectors feature Planetary Shield Generators that render all allied stations 100% invincible until destroyed.

### 💰 Mercenary Operations
- **Galactic Politics UI:** A new, highly detailed UI tab to track all active conflicts, ceasefires, and faction relations galaxy-wide.
- **Bounty Licenses:** Factions actively offering a Bounty License against their enemies will have a `[BOUNTY]` tag in the UI. Taking down your first target activates a time-sensitive 45-minute hunting license for massive payouts!
- **Dynamic War Contracts:** Over 20 entirely new mercenary missions dynamically injected into Bulletin Boards based on the sector's current War Heat (e.g., *Force Recon*, *Resource Heist*, *Blockade Runner*, *Distraction Carnage*, *Decapitation Strike*).

### 🚀 Dynamic Galaxy Expansion
- **Territory Expansion:** Factions seamlessly expand their borders by launching troop transports to physically board and capture enemy stations.
- **Background Conquests:** Contested zones feature hidden siege timers, natively flipping ownership mathematically behind the scenes without the massive lag of keeping sectors loaded.
- **War Casualties & Events:** Discover refugee convoys fleeing the violence, or answer distress beacons from destroyed prototype flagships.

### 🌌 Synergy & DLC Interoperability (Audit 3.0+)
- **Economy Warfare (Cosmic Vault):** Market collapses and starvation can trigger desperate invasions as factions with massive Famine Scores assault their wealthy neighbors.
- **Weather-Assisted Boarding:** Use hazards to your advantage! If a DarkMatterFog or IonStorm hits a sector, the defending station's boarding defense multiplier drops by 50%.
- **Weaponized Subspace Tears (Rift DLC):** At Critical War Heat, warring factions may detonate experimental subspace weapons, tearing the fabric of space and unleashing localized Rift hazards.
- **Subspace Containment Contracts:** When a rift tears in a warzone, factions issue high-paying War Contracts to secure emerged Ancient Tech platforms.
</details>

---

## ⚙️ Requirements
- **Avorion v2.0+**
- **Dependencies:** This mod is part of the broader Cosmic Suite and relies on shared architecture.
  - **Cosmic Vault** (Required API Framework)
  - **Cosmic Overhaul**
  - **Cosmic Chronicles**
  - **Cosmic Ascendancy**

---

## 🚀 Installation
1. Place the extracted `Cosmic War` folder in your Avorion mods directory:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Install all required dependencies (Cosmic Vault, Overhaul, Chronicles, Ascendancy).
3. Launch Avorion, go to **Settings -> Mods**, and enable **Cosmic War**.
4. Restart the game or dedicated server when prompted.

---

## 📚 Documentation & Diagnostics
- **In-Game Lore:** All deep lore, stat blocks, and dynamic features are fully integrated into the in-game **Cosmic Codex**. You do not need to tab out to learn!
- **Offline Guides:** Check the included `WIKI.md` and `PLAYER_GUIDE.md` files in the mod folder for a complete breakdown of mechanics, scaling equations, and background systems.
- **Diagnostics:** Server Operators can use the `/cosmicwarstatus` command in chat to view live diagnostic health and activity readouts of the background simulation.
