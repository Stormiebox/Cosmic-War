# ⚔️ 🌌 Cosmic War - Player Guide

![Version](https://img.shields.io/badge/version-4.0.0-6f42c1?style=flat-square)
![Avorion](https://img.shields.io/badge/Avorion-2.5.13-2f81f7?style=flat-square)

Welcome to **Cosmic War**! This guide covers War Heat, faction traits, mercenary contracts, invasions, and everything else you'll run into while the galaxy tears itself apart. Current release: **v4.0.0**.

> [!TIP]
> For exact numbers and mechanic-by-mechanic detail, see [`WIKI.md`](https://github.com/Stormiebox/Cosmic-War/wiki/Features-and-Enhancements). See [`README.md`](https://github.com/Stormiebox/Cosmic-War) for installation.

---

## 📑 Table of Contents

- [War Heat System](#-war-heat-system)
- [Dynamic Faction Traits](#-dynamic-faction-traits)
- [Mercenary Contracts](#-mercenary-contracts)
- [Dreadnought Invasions](#-dreadnought-invasions)
- [Galactic Politics & Bounty Licenses](#-galactic-politics--bounty-licenses)
- [War Score & Attrition](#-war-score--attrition)
- [Dynamic Territory Expansion](#-dynamic-territory-expansion)
- [Intelligence Network](#-intelligence-network)
- [Humanitarian Contracts](#-humanitarian-contracts)
- [Coalition Ceasefires](#-coalition-ceasefires)
- [Planetary Defense Generators & Shield Breaker](#-planetary-defense-generators--shield-breaker)
- [Salvage Race](#-salvage-race)
- [Deniable Raid](#-deniable-raid)
- [Decisive Push](#-decisive-push)
- [Prize Crew](#-prize-crew)
- [Refugee Resettlement](#-refugee-resettlement)
- [Subspace Corridors](#-subspace-corridors)
- [Live Battlefield Salvage Markets](#-live-battlefield-salvage-markets)
- [Alliance War Councils](#-alliance-war-councils)
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
- **Mercantile:** pays 1.5x the standard bounty and War Contract payout to mercenaries fighting on its behalf.
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
- **Resource ops:** steal resources from enemy territory (*Resource Heist*), destroy enemy mining operations (*Resource Sabotage*), race a battlefield wreckage field before it's cleared (*Salvage Race*), or strip-mine and keep enemy resources outright (*Scorched Earth*).
- **Assassination & duels:** hunt down enemy commanders (*Hunter Killer*), or answer the call for a 1-on-1 duel with a scaled Champion (*Champion Duel*).
- **Deniable & decisive ops:** fly under a pirate flag for a raid that can't trace back to the faction hiring you (*Deniable Raid*), break an enemy's Planetary Defense Generator (*Shield Breaker*), capture an enemy escort ship intact instead of destroying it (*Prize Crew*), or personally deliver the final blow to a war that's already nearly won (*Decisive Push*).
- Completing a contract pays a large bounty and boosts your reputation with the hiring faction, while wrecking it with the target.
- 27 War Contracts are live and clickable on the bulletin board.

</details>

## 💰 Warbonds

<details>
<summary><b>Click to expand</b></summary>

Prefer financing a war over fighting it yourself? Any faction actively at war sells Warbonds at its Trading Posts.

### ⚙️ Mechanics

- **Purchase:** a Standard Warbond costs 10,000,000 Cr, a Premium one 50,000,000 Cr. You can hold up to 250,000,000 Cr in bonds with a single faction, and each faction's Trading Post stops selling once its total investment from all players combined hits 1,000,000,000 Cr.
- **Maturity:** once the war you invested in fully resolves and stays resolved for 2 hours, your bonds pay out — anywhere from nothing up to 300%, scaled by how costly the war actually was for that faction (its Famine Score at maturity versus when you bought in, not counting any famine relief you personally delivered them). A faction that came through strong pays out big; one that was left broken pays out little or nothing.
- **Cash out early (v4.0.0):** don't want to wait out a war that's clearly going badly? Return to the same Trading Post and cash out immediately for a flat 40% — less than a good maturity payout, but guaranteed, and yours right away instead of locked in for however long the war drags on.

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

- View every active war, alliance, and War Heat level in a sortable table (Faction A, Faction B, Bounty, War Heat, Famine, Status, Relations). Hover a row for your own banked Intel against either faction, right alongside the rest.
- **Bounty Licenses:** a faction offering a bounty against an enemy shows it in the dedicated Bounty column. Hover a row for the exact per-kill credit reward. Destroying your first valid target against that faction activates a 45-minute License covering up to 15 kills, with a warning every 5 minutes as it winds down.
- **Reward scaling:** standard military kills pay the base rate, Dreadnoughts and bosses pay 5x, and stations pay 10x.
- **Your License, always visible:** the tab header shows your own License's target, kills, and time remaining without digging through chat history.
- **`/cosmicwarbounties`:** new in v3.4.0. Shows your own License at a glance, then lists the 10 highest-paying active War Bounties galaxy-wide with offering faction, target, reward per kill, and time to expiry - handy when you just want the numbers without opening the UI.
- **Covert funding:** as a wealthy player, you can secretly fund rebellions or donate credits to a faction's war effort, shaping the outcome without firing a shot.

</details>

## ⚔️ War Score & Attrition

<details>
<summary><b>Click to expand</b></summary>

New in v4.0.0. Every active war now keeps score, so "who's winning" is something you can actually check instead of guessing from a relations number.

### ⚙️ Mechanics

- Hover a conflict row in the Galactic Politics tab to see which side is currently ahead and how close the war is to ending outright, tallied from kills and captured stations (a captured station counts for a lot more than a single kill, and always matters more than kills alone - see below). Active sieges also show the current War Score right in the Battlefield HUD.
- **War Exhaustion:** the longer a war drags on, the more likely both sides are to accept a ceasefire.
- **Decisive Victory:** if one side pulls decisively ahead (Score of 250+), the war can end outright - the loser takes a real economic hit and a forced peace, and the Galactic News Network reports it. Kills alone can never single-handedly force this; a real territorial swing always has to be part of it.

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

## 🕵️ Intelligence Network

<details>
<summary><b>Click to expand</b></summary>

New in v4.0.0. Recon-flavored War Contracts now pay off in more than just credits.

### ⚙️ Mechanics

- Completing Force Recon, Sensor Deployment, or Black Box Retrieval banks Intel against the faction you scouted.
- Check what you've gathered with `/cosmicwarintel`, or spend 50 Intel against a specific faction with `/cosmicwarintel <faction name>` to get a scouting report on their likely next expansion target - handy for beating them to a border sector, or just knowing where the frontier is about to move.

</details>

## 🤝 Humanitarian Contracts

<details>
<summary><b>Click to expand</b></summary>

New in v4.0.0. Not every way to get involved in a war has to involve pulling a trigger.

### ⚙️ Mechanics

- **Relief Convoy:** a bulletin-board mission that appears at any faction going through a serious famine (Struggling or worse). Gather raw materials and deliver them directly to the faction - no combat, no war declaration, just a solid payout and a real reputation boost for helping people who actually need it.
- **Medical Airlift:** a faster, higher-paying emergency version of Relief Convoy that appears once a faction's famine reaches full-blown crisis (Severe Famine). Smaller cargo run, bigger payoff, bigger dent in their suffering.
- **Scorched Earth:** the other side of the coin - a War Contract that sends you to strip-mine resources out of enemy territory. You keep everything you mine, and denying it to them hurts their people as much as helping a starving faction helps.
- **Diplomatic Aid Package:** would rather just write a check? Trading Posts now let you donate credits directly to buy down a struggling faction's famine, no cargo run required.
- **Broker Sanctions Relief:** an option at Trading Posts. Pay a flat fee to buy a struggling faction two hours of relief from the economic sanctions grinding them down.

</details>

## 🌑 Coalition Ceasefires

<details>
<summary><b>Click to expand</b></summary>

New in v4.0.0. Some threats are bigger than any one war.

### ⚙️ Mechanics

- When the Eclipse becomes a serious galaxy-wide threat, every faction currently at war gets pulled into a temporary truce - galaxy-wide, not just nearby the danger.
- Old grudges resume once the immediate crisis passes, but for a while, everyone has bigger problems than each other.

</details>

## 🛡️ Planetary Defense Generators & Shield Breaker

<details>
<summary><b>Click to expand</b></summary>

A faction under real pressure can now build a genuine Planetary Defense Generator at its home sector - while it stands, every other station in that sector is invincible, forcing an attacker to take it down first.

### ⚙️ Mechanics

- A threatened faction (meaningful War Heat) has a rolling chance to commission one over time - you'll find out it exists when you actually see it in their home sector.
- **Shield Breaker:** a new War Contract offered only against a faction that actually has one commissioned - fly there and destroy it to open the sector up.

</details>

## 🏁 Salvage Race

<details>
<summary><b>Click to expand</b></summary>

A recent battle left valuable wreckage drifting in hostile territory - but you're not the only one who wants it.

### ⚙️ Mechanics

- Reach the wreckage field and salvage a quota of raw materials within 5 minutes before rival scavengers and enemy patrols clear it out.
- Pays more the more lopsided the fight behind it was.

</details>

## 🏴‍☠️ Deniable Raid

<details>
<summary><b>Click to expand</b></summary>

Sometimes a faction needs something done that can't trace back to them - so you fly under a pirate flag instead.

### ⚙️ Mechanics

- Always pirate-flagged, even if the faction hiring you has a real war going with someone else.
- If they do have a real enemy, the raid turns up real intelligence you can bank against them.

</details>

## 🏆 Decisive Push

<details>
<summary><b>Click to expand</b></summary>

Some wars are already all but won - this contract lets you personally deliver the final blow.

### ⚙️ Mechanics

- Only appears once a war is already close to a Decisive Victory (see War Score & Attrition above).
- Winning it counts as a major blow toward actually ending that war outright.

</details>

## 🚢 Prize Crew

<details>
<summary><b>Click to expand</b></summary>

Not every enemy ship needs to end up as scrap - some are worth capturing instead.

### ⚙️ Mechanics

- Reduce a designated enemy escort ship below 25% hull without finishing it off.
- Once it's disabled and you're still there, a prize crew flies over and brings it into the giver faction's own fleet.
- Destroy the target instead of disabling it, and the contract fails - a wreck is worthless to them.

</details>

## 🏘️ Refugee Resettlement

<details>
<summary><b>Click to expand</b></summary>

A starving, expansionist faction wants to give their people a real fresh start - not just supplies, an actual new home.

### ⚙️ Mechanics

- Only offered by struggling Imperialist factions. The delivery target is a real sector they're actively eyeing for expansion.
- Successful delivery doesn't just pay you and cut their Famine Score - it actually settles that sector for them, if no one's beaten them to it.

</details>

## 🌌 Subspace Corridors

<details>
<summary><b>Click to expand</b></summary>

The most brutal wars can leave more than just scars on the factions fighting them.

### ⚙️ Mechanics

- At a war's absolute worst (maximum War Heat), there's a rare chance a genuine subspace wormhole tears open connecting the two capitals directly.
- It's permanent once it happens - a real shortcut left behind by the war, for good.

</details>

## 💰 Live Battlefield Salvage Markets

<details>
<summary><b>Click to expand</b></summary>

Desperate times call for desperate trading posts.

### ⚙️ Mechanics

- Some physical sieges see the defending faction open a temporary black-market post right in the war zone.
- It buys your raw materials at a steep premium over the going rate for as long as the siege - and the post - lasts.

</details>

## 🤝 Alliance War Councils

<details>
<summary><b>Click to expand</b></summary>

Fighting alongside your Player Alliance now means fighting with shared intelligence, not separate notebooks.

### ⚙️ Mechanics

- If you're in a Player Alliance, your banked Intel (see Intelligence Network above) is now shared with your whole Alliance instead of tracked separately per member.
- Any member's recon missions contribute to, and any member can spend from, the same pool.

</details>

## 🆘 Random Encounters

<details>
<summary><b>Click to expand</b></summary>

Wars don't just affect stations and Dreadnoughts. They displace civilians and litter the galaxy with hazards you'll stumble into while exploring.

### ⚙️ What You Might Run Into

- **Refugee Convoys:** civilian ships fleeing violence occasionally hail you in deep space. Escort survivors to safety for a reputation boost and a direct "Hero of the People" credit reward (v4.0.0), and there's a 25% chance they tip you off to a hidden resource stash.
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

---

<div align="center">

[⬆ Back to top](https://github.com/Stormiebox/Cosmic-War/wiki/Players-Guide-A-Living-Conflict) · [🌌 README](https://github.com/Stormiebox/Cosmic-War) · [⚙️ Wiki](https://github.com/Stormiebox/Cosmic-War/wiki/Features-and-Enhancements)

</div>
