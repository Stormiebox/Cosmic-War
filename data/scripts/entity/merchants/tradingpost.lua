package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_tradingpost_initUI = TradingPost.initUI

function TradingPost.initUI()
    if cw_tradingpost_initUI then cw_tradingpost_initUI() end
    ScriptUI():registerInteraction("Purchase Warbonds"%_t, "onPurchaseWarbondsInteraction")
    ScriptUI():registerInteraction("Broker Sanctions Relief"%_t, "onSanctionsReliefInteraction")
    ScriptUI():registerInteraction("Cash Out Warbonds Early"%_t, "onCashOutWarbondsInteraction")
end

-- v4.0.0: the one-way lock-in Warbonds had until now -- wait for the war to fully
-- resolve, however long that takes, for whatever the famine-scaled payout happens to be.
-- Cashing out early at this same faction's Trading Post pays a flat 40% -- a real
-- penalty versus holding to maturity (up to 300%), but strictly better than what a
-- catastrophic famine swing can leave a held bond worth, and gives the player an actual
-- exit instead of no choice at all.
function TradingPost.onCashOutWarbondsInteraction()
    invokeServerFunction("requestCashOutDialog")
end

function TradingPost.requestCashOutDialog()
    if onClient() then invokeServerFunction("requestCashOutDialog") return end
    local player = Player(callingPlayer)
    if not player then return end

    local factionIndex = Entity().factionIndex
    local hasBond = false
    if player:hasScript("cosmicwar_warbonds.lua") then
        local status, amount = player:invokeFunction("cosmicwar_warbonds.lua", "getBondAmount", factionIndex)
        hasBond = status == 0 and amount and amount > 0
    end
    invokeClientFunction(player, "showCashOutDialog", hasBond)
end

function TradingPost.showCashOutDialog(hasBond)
    if hasBond then
        ScriptUI():showDialog(TradingPost.makeCashOutDialog())
    else
        ScriptUI():showDialog(TradingPost.makeNoBondDialog())
    end
end

function TradingPost.makeCashOutDialog()
    local dialog = {}
    dialog.text = "You currently hold Warbonds with us. Cashing out now, before the war resolves, pays a flat 40% return -- less than a full maturity payout could earn, but guaranteed, and yours immediately."%_t
    dialog.answers = {
        {answer = "Cash out now (40%)"%_t, onSelect = "cashOutWarbonds"},
        {answer = "I'll wait it out."%_t}
    }
    return dialog
end

function TradingPost.makeNoBondDialog()
    local dialog = {}
    dialog.text = "You don't currently hold any Warbonds with us."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function TradingPost.cashOutWarbonds()
    if onClient() then invokeServerFunction("cashOutWarbonds") return end
    local player = Player(callingPlayer)
    if not player then return end
    if not player:hasScript("cosmicwar_warbonds.lua") then return end

    local factionIndex = Entity().factionIndex
    local status, payout, err = player:invokeFunction("cosmicwar_warbonds.lua", "cashOutEarly", factionIndex)
    if status == 0 and payout then
        player:receive("Early Warbond Cash-Out", payout)
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 0, "Bond cashed out. %1% Credits transferred immediately."%_T, createMonetaryString(payout))
    else
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, "You don't have an active Warbond with us to cash out."%_t)
    end
end

-- v4.0.0 Humanitarian Contracts, part 2: a flat-fee diplomatic transaction that shields
-- this faction from Diplomatic Sanctions pressure (cosmicwardiplomaticsanctions.lua) for
-- 2 hours -- the "broker an end to sanctions" idea from the overhaul plan, implemented
-- as an instant Trading Post transaction (mirroring Warbonds' own dialog flow) rather
-- than a full travel mission, since sanctions pressure isn't a discrete on/off state to
-- go "resolve" at a location -- it's an ongoing background roll this cleanly interrupts.
local SANCTIONS_RELIEF_COST = 8000000
local SANCTIONS_RELIEF_DURATION = 7200

function TradingPost.onSanctionsReliefInteraction()
    invokeServerFunction("requestSanctionsReliefDialog")
end

function TradingPost.requestSanctionsReliefDialog()
    if onClient() then invokeServerFunction("requestSanctionsReliefDialog") return end
    -- Check the exact condition cosmicwardiplomaticsanctions.lua itself gates on (an
    -- active enemy with relations at or below the rivalry threshold), rather than a War
    -- Heat proxy -- sanctions can already be rolling well before heat climbs to any
    -- particular fraction, since heat only starts rising once relations cross this same
    -- threshold in the first place.
    local faction = Faction(Entity().factionIndex)
    local eligible = false
    if faction then
        local enemyIdx = faction:getValue("enemy_faction") or 0
        if enemyIdx > 0 then
            local rel = faction:getRelations(enemyIdx) or 0
            local CosmicWarConfig = include("cosmicwarconfig")
            local threshold = (CosmicWarConfig.get() or {}).rivalryThreshold or -45000
            eligible = rel <= threshold
        end
    end
    invokeClientFunction(Player(callingPlayer), "showSanctionsReliefDialog", eligible)
end

function TradingPost.showSanctionsReliefDialog(eligible)
    if eligible then
        ScriptUI():showDialog(TradingPost.makeSanctionsReliefDialog())
    else
        ScriptUI():showDialog(TradingPost.makeNoSanctionsDialog())
    end
end

function TradingPost.makeSanctionsReliefDialog()
    local dialog = {}
    dialog.text = "The economic pressure from this war is crushing us. If you can broker a diplomatic reprieve on our behalf, we can weather the sanctions for a while."%_t
    dialog.answers = {
        {answer = "Broker Sanctions Relief (8,000,000 Cr)"%_t, onSelect = "buySanctionsRelief"},
        {answer = "Not right now."%_t}
    }
    return dialog
end

function TradingPost.makeNoSanctionsDialog()
    local dialog = {}
    dialog.text = "We are not currently under enough diplomatic pressure to need this kind of help."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function TradingPost.buySanctionsRelief()
    if onClient() then invokeServerFunction("buySanctionsRelief") return end

    local player = Player(callingPlayer)
    if not player then return end

    local canPay, msg = player:canPay(SANCTIONS_RELIEF_COST)
    if not canPay then
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, msg)
        return
    end

    player:pay("Sanctions Relief Brokerage"%_t, SANCTIONS_RELIEF_COST)

    local faction = Faction(Entity().factionIndex)
    if faction then
        faction:setValue("cw_sanctions_immune_until", Server().unpausedRuntime + SANCTIONS_RELIEF_DURATION)
    end

    player:sendChatMessage(Entity().translatedTitle or Entity().name, 0, "Agreement reached. We won't forget this."%_t)
end

function TradingPost.onPurchaseWarbondsInteraction()
    -- Heat must be evaluated server-side; Server() is not available in UI context.
    invokeServerFunction("requestWarbondDialog")
end

function TradingPost.requestWarbondDialog()
    if onClient() then invokeServerFunction("requestWarbondDialog") return end
    local entity = Entity()
    local CosmicWarBridge = include("cosmicwarbridge")
    local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
    local showBuy = heat >= 0.25
    invokeClientFunction(Player(callingPlayer), "showWarbondDialog", showBuy)
end

function TradingPost.showWarbondDialog(showBuy)
    if showBuy then
        ScriptUI():showDialog(TradingPost.makeBuyDialog())
    else
        ScriptUI():showDialog(TradingPost.makeNoWarDialog())
    end
end

function TradingPost.makeBuyDialog()
    local dialog = {}
    dialog.text = "Our economy is strained by the current war effort. We are issuing high-yield Warbonds to independent captains to fund our military campaigns. Once this conflict resolves, your bonds mature at a rate that reflects how costly the war was for us: up to 300% value if we come through it strong, scaling down toward nothing if we're left broken."%_t
    dialog.answers = {
        {answer = "Purchase Standard Warbond (10,000,000 Cr)"%_t, onSelect = "buyStandardBond"},
        {answer = "Purchase Premium Warbond (50,000,000 Cr)"%_t, onSelect = "buyPremiumBond"},
        {answer = "I'm not interested in financing a war."%_t}
    }
    return dialog
end

function TradingPost.makeNoWarDialog()
    local dialog = {}
    dialog.text = "We are currently experiencing an era of peace. We are not issuing any military warbonds at this time."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function TradingPost.buyStandardBond()
    if onClient() then invokeServerFunction("buyStandardBond") return end
    TradingPost.processPurchase(10000000)
end

function TradingPost.buyPremiumBond()
    if onClient() then invokeServerFunction("buyPremiumBond") return end
    TradingPost.processPurchase(50000000)
end

-- v4.0.0: per-player cap (250M, unchanged) prevents one player from dumping unlimited
-- credits into a single faction; this global pool cap is new and prevents an entire
-- multiplayer server from doing the same thing collectively -- 1B per faction, roughly
-- 4 maxed-out individual investors' worth of headroom before the faction stops issuing.
local WARBOND_GLOBAL_POOL_CAP = 1000000000

function TradingPost.processPurchase(amount)
    local player = Player(callingPlayer)
    if not player then return end

    local factionIndex = Entity().factionIndex

    if player:hasScript("cosmicwar_warbonds.lua") then
        local status, currentBonds = player:invokeFunction("cosmicwar_warbonds.lua", "getBondAmount", factionIndex)
        currentBonds = currentBonds or 0
        if currentBonds + amount > 250000000 then
            player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, "We cannot issue you any more warbonds. You have reached the maximum investment cap (250,000,000 Cr)."%_t)
            return
        end
    end

    local server = Server()
    local poolKey = "cw_warbond_pool_" .. tostring(factionIndex)
    local currentPool = server:getValue(poolKey) or 0
    if currentPool + amount > WARBOND_GLOBAL_POOL_CAP then
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, "Our war chest cannot accept any more warbond investment right now -- too many captains have already bought in. Try again once some bonds have matured."%_t)
        return
    end

    local canPay, msg = player:canPay(amount)
    if not canPay then
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, msg)
        return
    end

    player:pay("Warbond Purchase"%_t, amount)
    server:setValue(poolKey, currentPool + amount)

    if not player:hasScript("cosmicwar_warbonds.lua") then
        -- addScriptOnce is deferred (like removeScript), so the script is not actually attached
        -- yet this tick. Calling invokeFunction("addBond", ...) immediately below would silently
        -- miss it on a player's very first Warbond purchase, dropping the payment with no bond
        -- ever recorded. Push the credit to the next tick instead of round-tripping same-tick.
        player:addScriptOnce("data/scripts/player/cosmicwar_warbonds.lua")
        deferredCallback(0.1, "deferredAddBond", player.index, Entity().factionIndex, amount)
    else
        player:invokeFunction("cosmicwar_warbonds.lua", "addBond", Entity().factionIndex, amount)
    end

    player:sendChatMessage(Entity().translatedTitle or Entity().name, 0, "Thank you for your investment. Support our frontlines to ensure your bonds mature.")
end

function TradingPost.deferredAddBond(playerIndex, factionIndex, amount)
    local player = Player(playerIndex)
    if not player then return end
    player:invokeFunction("cosmicwar_warbonds.lua", "addBond", factionIndex, amount)
end
callable(TradingPost, "buyStandardBond")
callable(TradingPost, "buyPremiumBond")
callable(TradingPost, "requestWarbondDialog")
callable(TradingPost, "showWarbondDialog")
callable(TradingPost, "requestSanctionsReliefDialog")
callable(TradingPost, "showSanctionsReliefDialog")
callable(TradingPost, "buySanctionsRelief")
callable(TradingPost, "requestCashOutDialog")
callable(TradingPost, "showCashOutDialog")
callable(TradingPost, "cashOutWarbonds")
