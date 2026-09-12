package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- Cached at initialize() rather than re-read from a live Entity()/Faction() during
-- teardown: late-lifecycle reads of those globals aren't reliably safe, and vanilla's
-- jumprangeboost.lua caches its entity id for the same reason.
local generatorId = nil
local myFactionIndex = nil
local homeSectorX, homeSectorY = nil, nil

-- v4.0.0: only ever grant invincibility to a station that wasn't already invincible,
-- and mark exactly which stations THIS generator protected. Fixes a station that was
-- invincible for an unrelated reason (a vanilla story asset, a DLC entity, another
-- mod's protected structure) getting silently claimed as ours -- and, on removal,
-- getting its real protection stripped by a Cosmic War generator it had nothing to do
-- with.
local function protectStation(entity)
    if not entity.invincible then
        entity.invincible = true
        entity:setValue("cw_pdg_protector_id", generatorId)
    end
end

function initialize()
    if onServer() then
        generatorId = Entity().id
        myFactionIndex = Entity().factionIndex
        homeSectorX, homeSectorY = Sector():getCoordinates()

        -- Ensure the generator itself is always vulnerable to prevent mutual-invincibility exploits
        Entity().invincible = false

        -- Hook into all stations to give them invincibility
        local sector = Sector()
        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            if entity.id ~= generatorId and not entity:hasScript("cw_planetary_defense.lua") then
                protectStation(entity)
            end
        end

        sector:registerCallback("onEntityCreated", "onEntityCreated")

        -- onDestroyed is the callback that means this station was actually blown up.
        -- onDelete() is not: the engine also fires it when the object is deleted for
        -- any other reason, including the sector being saved and dropped from memory,
        -- at which point Sector() is already gone. Vanilla registers self-destruction
        -- the same way (worldboss.lua, asteroidshieldboss.lua).
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onEntityCreated(id)
    local entity = Entity(id)
    if entity and entity.type == EntityType.Station and entity.id ~= generatorId then
        if not entity:hasScript("cw_planetary_defense.lua") then
            protectStation(entity)
        end
    end
end

-- Fires only on genuine destruction, while the sector is still loaded -- so Sector(),
-- the broadcast and the news publish below are all safe here.
function onDestroyed()
    if onServer() then
        local sector = Sector()
        if not sector then return end

        local stations = {sector:getEntitiesByType(EntityType.Station)}

        -- Redundancy Check: Do not drop shields if another generator is active in the sector!
        for _, entity in pairs(stations) do
            if entity.id ~= generatorId and entity:hasScript("cw_planetary_defense.lua") then
                return
            end
        end

        -- Only restore stations THIS generator actually protected -- an
        -- independently-invincible station was never touched by protectStation() above,
        -- so it was never marked and is correctly left alone here.
        for _, entity in pairs(stations) do
            if entity.id ~= generatorId and entity:getValue("cw_pdg_protector_id") == generatorId then
                entity.invincible = false
                entity:setValue("cw_pdg_protector_id", nil)
            end
        end
        sector:broadcastChatMessage("Server", ChatMessageType.Warning, "WARNING: Planetary Shield Generator Destroyed! All stations are now vulnerable!"%_T)

        local ownerFaction = myFactionIndex and myFactionIndex > 0 and Faction(myFactionIndex) or nil

        local cv_news = include("cosmicvaultnews")
        cv_news.publishArticle({
            title = "Planetary Defense Generator Destroyed",
            content = "The Planetary Defense Generator shielding " .. (ownerFaction and ownerFaction.name or "a faction") .. "'s home sector has been destroyed. Every station there now stands defenseless.",
            category = "Military"
        })

        -- Clear the commissioning faction's flag so cosmicwardefensegenerators.lua can
        -- roll it a new one in the future. Shield Breaker clears the same flag on mission
        -- completion; both clears are idempotent, so whichever fires first is fine.
        if ownerFaction and homeSectorX and homeSectorY then
            if ownerFaction:getValue("cw_defense_generator_sector") == (homeSectorX .. ":" .. homeSectorY) then
                ownerFaction:setValue("cw_defense_generator_sector", nil)
            end
        end
    end
end
