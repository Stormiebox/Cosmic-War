# ⚔️ 🌌 Cosmic War - Player Guide

Welcome to **Cosmic War**! This guide covers War Heat, faction traits, mercenary contracts, invasions, and everything else you'll run into while the galaxy tears itself apart. Current release: **v3.4.0**.

---

## 📑 Table of Contents

- [War Heat System](#-war-heat-system)
- [Dynamic Faction Traits](#-dynamic-faction-traits)
- [Mercenary Contracts](#-mercenary-contracts)
- [Dreadnought Invasions](#-dreadnought-invasions)
- [Galactic Politics & Bounty Licenses](#-galactic-politics--bounty-licenses)
- [Dynamic Territory Expansion](#-dynamic-territory-expansion)
- [Random Encounters](#-random-encounters)
- [Suite Integration](#-suite-integration)

---

## ⚔️ War Heat System

<details>
<summary><b>Click to expand</b></summary>

Factions are no longer static. They actively build tension with their neighbors.

### ⚙️ Mechanics

- Every faction has a War Heat meter with each bordering faction.
- Border skirmishes, intercepted traders, and differing traits (Aggressive vs. Peaceful) passively raise War Heat over time.
- Once War Heat reaches 100%, a formal Declaration of War goes out on the Galactic News Network.
- Warring factions actively send fleets to destroy each other's stations and claim territory.

</details>

## 🎭 Dynamic Faction Traits

<details>
<summary><b>Click to expand</b></summary>

Factions spawn with distinct Custom Traits that shape their behavior, diplomacy, and the background simulation. Hover over a faction in the Galactic Politics tab to see its traits.

### ⚙️ Mechanics

- **Warmonger / Pacifist / Isolationist / Opportunist:** standard behavioral traits controlling how aggressively a faction builds War Heat or seeks ceasefires.
- **Imperialist:** claims empty or uncharted sectors and builds new outposts.
- **Entrenched:** fortifies its core territory with dense defensive networks instead of expanding outward.
- **Vengeful:** never accepts a ceasefire once war breaks out. Wars against a Vengeful empire end only when one side is gone.
- **Mercantile:** pays 3x the standard bounty and War Contract payout to mercenaries fighting on its behalf.
- **Xenophobic:** relations with every known neighbor decay continuously, guaranteeing eventual unprovoked wars.

</details>

## 🎖️ Mercenary Contracts

<details>
<summary><b>Click to expand</b></summary>

Profit from the chaos by signing up as a mercenary.

### ⚙️ Mechanics

- Check the Bulletin Board in any warring faction's territory for Mercenary Contracts.
- **Defensive contracts:** protect a sector from an incoming invasion fleet, or break through a blockade to deliver supplies (*Blockade Runner*).
- **Offensive contracts:** join an invasion fleet against an enemy station, or wipe out infrastructure (*Sector Raid*).
- **Special operations:** locate a destroyed flagship's black box (*Black Box Retrieval*), deploy stealth buoys (*Sensor Deployment*), or draw enemy fleets into a 5-minute ambush (*Distraction Carnage*).
- **Resource ops:** steal resources from enemy territory (*Resource Heist*) or destroy enemy mining operations (*Resource Sabotage*).
- **Assassination & duels:** hunt down enemy commanders (*Hunter Killer*), or answer the call for a 1-on-1 duel with a scaled Champion (*Champion Duel*).
- Completing a contract pays a large bounty and boosts your reputation with the hiring faction, while wrecking it with the target.
- All 22 War Contracts are live and clickable on the bulletin board as of v3.4.0.

</details>

## 🛡️ Dreadnought Invasions

<details>
<summary><b>Click to expand</b></summary>

During an active war, factions launch invasion fleets that mathematically scale to match 100% of the target sector's defensive strength.

### ⚔️ Combat Mechanics

- **Electronic Warfare (Shield Jammer):** siege invasions have a 35% chance, and open fleet clashes a 15% chance, to activate an EMP burst on arrival. If you see the warning text, all defending shields, including yours, are pinned to 0 durability for 10 seconds. Survive the window.
- **Siege Dreadnoughts:** invasions are spearheaded by Dreadnoughts, capital ships with a 5x shield multiplier built to tank station point defense.
- **Breaking Planetary Defenses:** if a Planetary Shield Generator is present, destroy it first. Every other station in the sector stays invincible while it stands.
- **Cinematic Battlefield HUD:** a contested sector displays a split blue/red progress bar tracking the time left before the sector flips ownership.
- Dreadnoughts take real work to kill. Bring high-Omicron weapons or specialized torpedoes for their boosted shields.
- An unstopped invasion fleet will systematically destroy every station in the sector.

</details>

## 🌐 Galactic Politics & Bounty Licenses

<details>
<summary><b>Click to expand</b></summary>

Open the Galactic Politics tab to track every known faction's status, or type `/cosmicwarbounties` in chat for the same information without leaving what you're doing.

### ⚙️ Features

- View every active war, alliance, and War Heat level in a sortable table (Faction A, Faction B, Bounty, War Heat, Famine, Status, Relations).
- **Bounty Licenses:** a faction offering a bounty against an enemy shows it in the dedicated Bounty column. Hover a row for the exact per-kill credit reward. Destroying your first valid target against that faction activates a 45-minute License covering up to 15 kills, with a warning every 5 minutes as it winds down.
- **Reward scaling:** standard military kills pay the base rate, Dreadnoughts and bosses pay 5x, and stations pay 10x.
- **Your License, always visible:** the tab header shows your own License's target, kills, and time remaining without digging through chat history.
- **`/cosmicwarbounties`:** new in v3.4.0. Shows your own License at a glance, then lists the 10 highest-paying active War Bounties galaxy-wide with offering faction, target, reward per kill, and time to expiry - handy when you just want the numbers without opening the UI.
- **Covert funding:** as a wealthy player, you can secretly fund rebellions or donate credits to a faction's war effort, shaping the outcome without firing a shot.

</details>

## 🚀 Dynamic Territory Expansion

<details>
<summary><b>Click to expand</b></summary>

Factions actively conquer enemy sectors and permanently expand their borders on the Galaxy Map.

### ⚙️ Mechanics

- **Background conquests:** contested zones carry a hidden siege timer. If it runs out with no player intervention, the station flips ownership and the faction's borders expand.
- **Physical sieges:** entering a contested zone triggers a live Siege Event.
- **Troop transports:** three heavily shielded AI transports warp in and charge the defending station. They need 60 seconds of unbroken point-defense survival at close range to board it, longer against tougher stations (up to 5 minutes for the toughest), and once that window closes they capture the station.
- **Zero-stutter performance:** background station flips are queued and executed instantly during your loading screen when you jump into the affected sector, so there's no lag spike from the game loading it in the background.

</details>

## 🆘 Random Encounters

<details>
<summary><b>Click to expand</b></summary>

Wars don't just affect stations and Dreadnoughts. They displace civilians and litter the galaxy with hazards you'll stumble into while exploring.

### ⚙️ What You Might Run Into

- **Refugee Convoys:** civilian ships fleeing violence occasionally hail you in deep space. Donate supplies or credits for a solid reputation boost, and there's a 25% chance they tip you off to a hidden resource stash.
- **Distress Beacons:** wreckage may broadcast a distress signal. Interact with it to download logs and "Answer the Call," triggering a rescue or ambush. Salvage the wreck without answering first and you lose the interaction for good.
- **Fleet Clashes and blockades:** active warzones can drop an enemy strike fleet or blockade fleet into a sector you're passing through, no warning beyond what you see on arrival.
- **Bounty hunter ambushes:** tank your reputation with a military faction during wartime and they may dispatch an elite squad to intercept you the next time you jump into a new sector.
- **Wreckage fields:** some sectors show the aftermath of a recent clash: several wrecks worth salvaging, no combat attached.

</details>

## 🔗 Suite Integration

<details>
<summary><b>Click to expand</b></summary>

Cosmic War is built to run alongside the rest of the Cosmic suite, and several features only make sense in that context.

- **Cosmic Codex:** every mechanic in this guide is also documented in-game, unlocking naturally in your Codex as you encounter each feature.
- **Weather-assisted boarding:** a DarkMatterFog or IonStorm rolling into a sector during a siege cuts the defending station's boarding resistance in half. Time your attacks around the weather.
- **Commodore siege leadership:** keeping a ship with a Commodore captain in a sector helps soften the economic hit if the siege is ultimately lost.
- **Weaponized Subspace Tears:** at the highest War Heat, warring factions may tear open a localized Rift hazard. A follow-up *Subspace Containment* contract appears to secure the site once it does.
- **Wartime Propaganda Beacons:** roughly 1 in 20 resolved sieges leaves behind a narrative beacon from Cosmic Chronicles.
- **Alliance consequences:** starting a diplomatic incident or destroying civilian convoys damages relations for your whole Player Alliance, not just you personally - there's no ducking the fallout by switching to a personal ship.

</details>
