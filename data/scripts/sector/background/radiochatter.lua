local cw_old_RadioChatter_initialize = RadioChatter.initialize
function RadioChatter.initialize(...)
    if cw_old_RadioChatter_initialize then cw_old_RadioChatter_initialize(...) end
    if onServer() then return end

    local generalStationChatter = {
        "Did you catch the latest broadcast on the Galactic News network? War tensions are rising in the neighboring sectors."%_t,
        "I swear, these recent overhauls to the hyperdrive systems have made my ship run smoother than ever!"%_t,
        "Security update: Headhunter hit-squads have been reported in the area. Please ensure your bounties are paid in full."%_t,
        "The chroniclers are saying that this era of galactic politics will be remembered for centuries."%_t,
        "If you ever meet a rogue engineer named Stormbox, buy him a drink. I heard he basically rewired the entire galaxy's framework!"%_t,
        "Attention: All civilian traffic must detour around the new wreckage field in sector ${LN3}. Salvage crews are already en route."%_t,
        "Ever since the stars started falling, I've had this terrible feeling that we're being watched by something ancient."%_t,
        "A refugee convoy just docked at bay ${N}. They say their home was caught in a massive fleet clash."%_t,
        "We are currently experiencing a shortage of military-grade targeting systems due to the ongoing border skirmishes."%_t,
        "Remember, war profiteering is entirely legal as long as the local bureaucrats get their cut!"%_t
    }

    local generalShipChatter = {
        "I've been reading the historical chronicles lately... makes you realize how small we really are in this war."%_t,
        "You hear about that legendary pilot, Stormbox? They say he flies a ship made entirely of anomalous, overhauled tech."%_t,
        "My sensors keep picking up strange readings. Could just be interference, or maybe another catastrophic stellar event."%_t,
        "I wouldn't jump to the outer rim right now. The war heat is off the charts out there."%_t,
        "Thank the stars for the automated news broadcasts. Without them, we'd never know which trade routes were blockaded!"%_t,
        "Ever since the new galactic regulations, I've had to replace every single sub-system on my ship. Good thing it runs better now."%_t,
        "Just saw a massive fleet dropping out of hyperspace. Looks like diplomatic relations are finally boiling over."%_t,
        "If we get interdicted by headhunters, I'm ejecting the cargo and blaming it on you."%_t,
        "Did you see that stranded flagship earlier? Looked like it had been drifting since the last great conflict."%_t,
        "Keep your transponder active. You don't want the local military mistaking us for blockade runners."%_t
    }

    local freighterChatter = {
        "Hauling military supplies into a warzone... The pay better be worth the risk of being intercepted."%_t,
        "I heard Stormbox pays double for high-grade processors. Let's make a detour to his station."%_t,
        "War is good for business, sure, but I'd rather not end up as a wreckage field for some salvage crew to pick clean."%_t,
        "If the galactic news is right, the trade route through sector ${N2}:${N} is completely blockaded by hostile forces."%_t,
        "We need to offload these weapons before a ceasefire is declared, otherwise prices will plummet!"%_t,
        "A smuggler told me they managed to bypass the blockade. Sounds like a good way to get vaporized."%_t,
        "Are you sure these coordinates from the old chronicles are safe? I'm not looking to become a footnote in history."%_t,
        "The latest sweeping overhauls to customs are making it really hard to falsify our cargo manifests."%_t,
        "Another stellar anomaly means another shortage of rare minerals. Time to hike up our prices!"%_t,
        "Just keep the engines hot and the comms silent. I don't want any diplomatic sabotage fleets spotting us."%_t
    }

    local hostileShipChatter = {
        "Your name just popped up on the galactic bounty boards. Time to collect!"%_t,
        "The war heat is peaking, and you just jumped into the wrong sector, friend."%_t,
        "Stormbox sends his regards. Say goodbye to your hull integrity!"%_t,
        "This sector is under military blockade! Turn back or be destroyed!"%_t,
        "Your presence here is a diplomatic incident waiting to happen. We're going to make sure it doesn't."%_t,
        "The chroniclers will remember you as just another piece of debris!"%_t,
        "We don't care about your trade routes. This is a warzone, and you're the enemy."%_t,
        "Target locked. Prepare to experience a catastrophic event of your own!"%_t,
        "We've got orders to leave no survivors in this fleet clash. You're first."%_t,
        "Even a complete ship overhaul can't save you from what we're about to do to it!"%_t
    }

    RadioChatter.addStationChatter(generalStationChatter)
    RadioChatter.addShipChatter(generalShipChatter)

    for _, line in pairs(freighterChatter) do
        table.insert(RadioChatter.FreighterChatter, line)
    end

    RadioChatter.addHostileShipChatter(hostileShipChatter)
end


function initialize(...)
    if RadioChatter.initialize then return RadioChatter.initialize(...) end
end