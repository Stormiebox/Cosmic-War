package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("stringutility")

-- namespace BulletinBoard

local __CW_old_BulletinBoard_getDisplayedBulletins = BulletinBoard.getDisplayedBulletins

local function hasSyntheticWarBulletin(bulletins)
    for _, b in pairs(bulletins or {}) do
        if type(b) == "table" and b.cwSynthetic then
            return true
        end
    end
    return false
end

function BulletinBoard.getDisplayedBulletins(...)
    local bulletins = {}
    if __CW_old_BulletinBoard_getDisplayedBulletins then
        bulletins = __CW_old_BulletinBoard_getDisplayedBulletins(...) or {}
    end

    if not onServer() then
        return bulletins
    end

    if hasSyntheticWarBulletin(bulletins) then
        return bulletins
    end

    local entity = Entity()
    if not entity or not entity.factionIndex then
        return bulletins
    end

    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
    end

    if heat < 0.45 then
        return bulletins
    end

    local reward = math.floor(25000 + heat * 50000)
    local title = "War Contract: Interception" % _t
    local description = "Conflict has intensified. Intercept hostile supply movement in nearby sectors." % _t

    table.insert(bulletins, {
        brief = title,
        description = description,
        reward = reward,
        cwSynthetic = true
    })

    return bulletins
end
