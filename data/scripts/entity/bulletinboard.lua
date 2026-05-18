package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("stringutility")

-- namespace BulletinBoard

local __CW_old_BulletinBoard_updateServer = BulletinBoard.updateServer
BulletinBoard._cw_timeSinceLastCheck = 0

local function hasSyntheticWarBulletin()
    -- BulletinBoard.bulletins is the vanilla table storing all active missions
    for _, b in pairs(BulletinBoard.bulletins or {}) do
        if type(b) == "table" and b.cw_synthetic then
            return true
        end
    end
    return false
end

function BulletinBoard.updateServer(timeStep)
    if __CW_old_BulletinBoard_updateServer then
        __CW_old_BulletinBoard_updateServer(timeStep)
    end

    BulletinBoard._cw_timeSinceLastCheck = BulletinBoard._cw_timeSinceLastCheck + timeStep

    -- Check every 15 minutes (900 seconds) to match standard bulletin refresh rates
    if BulletinBoard._cw_timeSinceLastCheck > 900 then
        BulletinBoard._cw_timeSinceLastCheck = 0
        BulletinBoard.postWarContract()
    end
end

function BulletinBoard.postWarContract()
    if hasSyntheticWarBulletin() then return end

    local entity = Entity()
    if not entity or not entity.factionIndex then return end

    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
    end

    if heat < 0.45 then return end

    local missions = {
        {
            title = "War Contract: Interception" % _t,
            desc = "Conflict has intensified. Intercept hostile supply movement in nearby sectors." % _t,
            script = "data/scripts/player/missions/cw_interception.lua",
            msg = "We need skilled captains to strike enemy supply lines immediately." % _t,
            minHeat = 0.45
        },
        {
            title = "War Contract: Breakthrough" % _t,
            desc = "We have a critical supply convoy moving through contested space. Defend them until they can jump." %
                _t,
            script = "data/scripts/player/missions/cw_breakthrough.lua",
            msg = "Our convoy is vulnerable. We need a capable escort to ensure they make it." % _t,
            minHeat = 0.45
        }
    }

    if heat >= 0.60 then
        table.insert(missions, {
            title = "War Contract: Frontline Siege" % _t,
            desc = "The enemy has established a Forward Operating Base. We need it destroyed." % _t,
            script = "data/scripts/player/missions/cw_frontlinesiege.lua",
            msg = "Command has authorized a strike on an enemy FOB. Are you ready to lead the assault?" % _t,
            minHeat = 0.60
        })
    end

    if heat >= 0.80 then
        table.insert(missions, {
            title = "War Contract: High-Value Extraction" % _t,
            desc = "A high-ranking enemy officer is defecting to our side. We need you to extract them safely." % _t,
            script = "data/scripts/player/missions/cw_highvaluedefection.lua",
            msg = "This is a highly classified operation. Extract the defector at all costs. Expect heavy resistance." %
                _t,
            minHeat = 0.80
        })
    end

    if heat >= 1.00 then
        table.insert(missions, {
            title = "War Contract: Decapitation Strike" % _t,
            desc = "The enemy Flagship has entered the sector. This is our chance to end the war." % _t,
            script = "data/scripts/player/missions/cw_decapitationstrike.lua",
            msg =
            "Warning: This is a suicide mission. The enemy Flagship is heavily armed and escorted. Do not accept unless you have a fleet." %
            _t,
            minHeat = 1.00
        })
    end

    local pick = missions[random():getInt(1, #missions)]

    BulletinBoard.postBulletin({
        brief = pick.title,
        description = pick.desc,
        difficulty = "Extreme" % _t,
        script = pick.script,
        arguments = { entity.factionIndex },
        msg = pick.msg,
        cw_synthetic = true
    })
end
