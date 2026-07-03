package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_tradingpost_initUI = initUI

function initUI()
    if cw_tradingpost_initUI then cw_tradingpost_initUI() end
    ScriptUI():registerInteraction("Purchase Warbonds"%_t, "onPurchaseWarbondsInteraction")
end

function onPurchaseWarbondsInteraction()
    local entity = Entity()
    local cw_success = true; include("cosmicwarbridge")
    if cw_success and CosmicWarBridge then
        local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
        if heat < 0.25 then
            ScriptUI():showDialog(makeNoWarDialog())
            return
        end
    end
    
    ScriptUI():showDialog(makeBuyDialog())
end

function makeBuyDialog()
    local dialog = {}
    dialog.text = "Our economy is strained by the current war effort. We are issuing high-yield Warbonds to independent captains to fund our military campaigns. If our faction successfully resolves this conflict in our favor, your investment will mature at 300% value. If we lose... your bonds become worthless."%_t
    dialog.answers = {
        {answer = "Purchase Standard Warbond (10,000,000 Cr)"%_t, onSelect = "buyStandardBond"},
        {answer = "Purchase Premium Warbond (50,000,000 Cr)"%_t, onSelect = "buyPremiumBond"},
        {answer = "I'm not interested in financing a war."%_t}
    }
    return dialog
end

function makeNoWarDialog()
    local dialog = {}
    dialog.text = "We are currently experiencing an era of peace. We are not issuing any military warbonds at this time."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function buyStandardBond()
    if onClient() then invokeServerFunction("buyStandardBond") return end
    processPurchase(10000000)
end

function buyPremiumBond()
    if onClient() then invokeServerFunction("buyPremiumBond") return end
    processPurchase(50000000)
end

function processPurchase(amount)
    local player = Player(callingPlayer)
    if not player then return end
    
    local canPay, msg = player:canPay(amount)
    if not canPay then
        player:sendChatMessage(Entity().name, 1, msg)
        return
    end
    
    player:pay("Warbond Purchase"%_t, amount)
    
    if not player:hasScript("cosmicwar_warbonds.lua") then
        player:addScriptOnce("data/scripts/player/cosmicwar_warbonds.lua")
    end
    
    -- Save the bond data to the player script
    player:invokeFunction("cosmicwar_warbonds.lua", "addBond", Entity().factionIndex, amount)
    
    player:sendChatMessage(Entity().name, 0, "Thank you for your investment. Support our frontlines to ensure your bonds mature.")
end
callable(nil, "buyStandardBond")
callable(nil, "buyPremiumBond")
