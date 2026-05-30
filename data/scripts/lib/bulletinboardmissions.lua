package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("stringutility")
include("randomext")

if onServer() then
    local function createCosmicWarContract()
        local entity = Entity()
        if not entity or not entity.factionIndex then return end

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
        end

        if heat < 0.15 then return end

        local missions = {}

        if heat >= 0.15 then
            table.insert(missions, {
                title = "War Contract: Force Recon"%_T,
                desc = "Tensions are rising. We need a discreet captain to scout a hostile sector and gather intel."%_T,
                script = "data/scripts/player/missions/cw_forcerecon.lua",
                msg = "This is a reconnaissance operation. Get in, gather the intel, and get out in one piece."%_T
            })
        end

        if heat >= 0.25 then
            table.insert(missions, {
                title = "War Contract: Border Skirmish"%_T,
                desc = "Border disputes are getting violent. Intercept and eliminate an enemy border patrol."%_T,
                script = "data/scripts/player/missions/cw_borderskirmish.lua",
                msg = "Take out their patrol. We need to show them we won't be intimidated."%_T
            })
        end

        if heat >= 0.35 then
            table.insert(missions, {
                title = "War Contract: Resource Sabotage"%_T,
                desc = "A hostile mining operation is extracting resources in contested space. Put an end to it."%_T,
                script = "data/scripts/player/missions/cw_resourcesabotage.lua",
                msg = "Crippling their resource flow now will save our fleets later. Destroy those miners."%_T
            })
        end

        if heat >= 0.45 then
            table.insert(missions, {
                title = "War Contract: Interception"%_T,
                desc = "Conflict has intensified. Intercept hostile supply movement in nearby sectors."%_T,
                script = "data/scripts/player/missions/cw_interception.lua",
                msg = "We need skilled captains to strike enemy supply lines immediately."%_T
            })
            table.insert(missions, {
                title = "War Contract: Breakthrough"%_T,
                desc = "We have a critical supply convoy moving through contested space. Defend them until they can jump."%_T,
                script = "data/scripts/player/missions/cw_breakthrough.lua",
                msg = "Our convoy is vulnerable. We need a capable escort to ensure they make it."%_T
            })
        end

        if heat >= 0.60 then
            table.insert(missions, {
                title = "War Contract: Frontline Siege"%_T,
                desc = "The enemy has established a Forward Operating Base. We need it destroyed."%_T,
                script = "data/scripts/player/missions/cw_frontlinesiege.lua",
                msg = "Command has authorized a strike on an enemy FOB. Are you ready to lead the assault?"%_T
            })
        end

        if heat >= 0.80 then
            table.insert(missions, {
                title = "War Contract: High-Value Extraction"%_T,
                desc = "A high-ranking enemy officer is defecting to our side. We need you to extract them safely."%_T,
                script = "data/scripts/player/missions/cw_highvaluedefection.lua",
                msg = "This is a highly classified operation. Extract the defector at all costs. Expect heavy resistance."%_T
            })
        end

        if heat >= 1.00 then
            table.insert(missions, {
                title = "War Contract: Decapitation Strike"%_T,
                desc = "The enemy Flagship has entered the sector. This is our chance to end the war."%_T,
                script = "data/scripts/player/missions/cw_decapitationstrike.lua",
                msg = "Warning: This is a suicide mission. The enemy Flagship is heavily armed and escorted. Do not accept unless you have a fleet."%_T
            })
        end

        local pick = missions[random():getInt(1, #missions)]

        return {
            brief = pick.title,
            description = pick.desc,
            difficulty = "Extreme"%_T,
            script = pick.script,
            arguments = { entity.factionIndex },
            msg = pick.msg,
            onAccept = [[
            local self, playerIndex = ...
            local player = Player(playerIndex)
            local faction = Faction(self.arguments[1])
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
        }
    end

    -- Inject the mission generator into station categories that make sense for war contracts
    table.insert(BulletinBoardMissions.generators["Military"], createCosmicWarContract)
    table.insert(BulletinBoardMissions.generators["Factory"], createCosmicWarContract)
    table.insert(BulletinBoardMissions.generators["Trade"], createCosmicWarContract)
    table.insert(BulletinBoardMissions.generators["Consumer"], createCosmicWarContract)
end
