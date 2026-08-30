package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_tradingpost_initUI = TradingPost.initUI

function TradingPost.initUI()
    if cw_tradingpost_initUI then cw_tradingpost_initUI() end
    ScriptUI():registerInteraction("Purchase Warbonds"%_t, "onPurchaseWarbondsInteraction")
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
    dialog.text = "Our economy is strained by the current war effort. We are issuing high-yield Warbonds to independent captains to fund our military campaigns. If our faction successfully resolves this conflict in our favor, your investment will mature at 300% value. If we lose... your bonds become worthless."%_t
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

function TradingPost.processPurchase(amount)
    local player = Player(callingPlayer)
    if not player then return end
    
    if player:hasScript("cosmicwar_warbonds.lua") then
        local status, currentBonds = player:invokeFunction("cosmicwar_warbonds.lua", "getBondAmount", Entity().factionIndex)
        currentBonds = currentBonds or 0
        if currentBonds + amount > 250000000 then
            player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, "We cannot issue you any more warbonds. You have reached the maximum investment cap (250,000,000 Cr)."%_t)
            return
        end
    end
    
    local canPay, msg = player:canPay(amount)
    if not canPay then
        player:sendChatMessage(Entity().translatedTitle or Entity().name, 1, msg)
        return
    end
    
    player:pay("Warbond Purchase"%_t, amount)
    
    if not player:hasScript("cosmicwar_warbonds.lua") then
        player:addScriptOnce("data/scripts/player/cosmicwar_warbonds.lua")
    end
    
    -- Save the bond data to the player script
    player:invokeFunction("cosmicwar_warbonds.lua", "addBond", Entity().factionIndex, amount)
    
    player:sendChatMessage(Entity().translatedTitle or Entity().name, 0, "Thank you for your investment. Support our frontlines to ensure your bonds mature.")
end
callable(TradingPost, "buyStandardBond")
callable(TradingPost, "buyPremiumBond")
callable(TradingPost, "requestWarbondDialog")
callable(TradingPost, "showWarbondDialog")
