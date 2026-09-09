package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- v4.0.0: cached at initialize() rather than re-read from a live Entity()/Faction()
-- inside onDelete() -- Avorion_Modding_Codex.md's onRemove()-vs-onDelete() entry warns
-- that late-lifecycle Entity()/Faction() reads aren't reliably safe, and vanilla's own
-- jumprangeboost.lua caches its entity id for the same reason rather than trusting a
-- fresh lookup that deep into teardown.
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

-- v4.0.0: was onRemove(), which fires whenever the script is detached from the
-- object -- not only when the object itself is destroyed. onDelete() is the hook that
-- actually means the generator is gone for good (Avorion_Modding_Codex.md's
-- onRemove()-vs-onDelete() entry). This also closes the respawn loop: every real
-- destruction path now clears the commissioning faction's flag here, not only Shield
-- Breaker's own explicit clear on mission completion.
function onDelete()
    if onServer() then
        local sector = Sector()
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

        local ownerFaction = myFactionIndex and myFactionIndex > 0 and Faction(myFactionIndex)
        local cv_news = include("cosmicvaultnews")
        cv_news.publishArticle({
            title = "Planetary Defense Generator Destroyed",
            content = "The Planetary Defense Generator shielding " .. (ownerFaction and ownerFaction.name or "a faction") .. "'s home sector has been destroyed. Every station there now stands defenseless.",
            category = "Military"
        })

        -- Clear the commissioning faction's flag so cosmicwardefensegenerators.lua can
        -- roll it a new one in the future -- generically, for ANY destruction path, not
        -- only Shield Breaker's own mission completion. Both clears are idempotent, so
        -- this is safe to run whichever one fires first.
        if myFactionIndex and myFactionIndex > 0 and homeSectorX and homeSectorY then
            local faction = Faction(myFactionIndex)
            if faction and faction:getValue("cw_defense_generator_sector") == (homeSectorX .. ":" .. homeSectorY) then
                faction:setValue("cw_defense_generator_sector", nil)
            end
        end
    end
end
