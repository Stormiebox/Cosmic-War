local VaultNews = include("cosmicvaultnews")
local NewsSchema = include("cosmicvaultnews_schema")

local CosmicWarNews = {}

local PUBLISHER = {
    schemaVersion = 1,
    publisherId = "cosmic_war",
    displayName = "Cosmic War",
    shortName = "WAR",
    color = {r = 1.0, g = 0.35, b = 0.35},
}

local MUTABLE_FIELDS = {
    "title", "content", "category", "topic", "severity", "breaking", "author",
    "location", "audience", "lead", "expiresAt", "provenance",
}

local function stableId(prefix, rawIdentity)
    local hash, hashError = NewsSchema.StableHash(tostring(rawIdentity))
    if hashError then return nil, hashError end
    return prefix .. ":" .. hash, nil
end

local function buildRequest(options)
    if type(options) ~= "table" or type(options.article) ~= "table"
            or options.eventId == nil or type(options.eventType) ~= "string" then
        return nil, "invalid_arguments"
    end
    local eventId, eventError = stableId("war", options.eventId)
    if not eventId then return nil, eventError end
    local threadId
    if options.threadId ~= nil then
        threadId, eventError = stableId("war-thread", options.threadId)
        if not threadId then return nil, eventError end
    end
    local article = options.article
    local location = options.location
    local topic = options.topic or NewsSchema.MapCategory(article.category or "War")
    return {
        schemaVersion = 2,
        publisherId = "cosmic_war",
        eventId = eventId,
        threadId = threadId,
        eventType = options.eventType,
        topic = topic,
        category = article.category or "War",
        severity = options.severity or (article.breaking == true and "critical" or "warning"),
        breaking = article.breaking == true or options.breaking == true,
        title = article.title,
        content = article.content,
        author = article.author or "Cosmic War",
        location = location,
        audience = options.audience or {mode = "galaxy"},
        lead = location and {kind = "location", x = location.x, y = location.y,
            expiresAt = options.expiresAt} or nil,
        expiresAt = options.expiresAt,
        provenance = options.provenance or {
            recordType = "cosmic_war_event",
            sourceRevision = options.sourceRevision or 0,
            sourceState = options.sourceState or "verified",
        },
    }, nil
end

local function ensurePublisher()
    local _, registerError = VaultNews.RegisterPublisher(PUBLISHER)
    return registerError == nil and true or nil, registerError
end

function CosmicWarNews.Publish(options)
    if not onServer() then return nil, "server_only" end
    local ready, publisherError = ensurePublisher()
    if not ready then return nil, publisherError end
    local request, requestError = buildRequest(options)
    if not request then return nil, requestError end
    return VaultNews.Publish(request)
end

function CosmicWarNews.Upsert(options)
    if not onServer() then return nil, "server_only" end
    local ready, publisherError = ensurePublisher()
    if not ready then return nil, publisherError end
    local request, requestError = buildRequest(options)
    if not request then return nil, requestError end
    local articleId = "cosmic_war:" .. request.eventId
    local existing, getError = VaultNews.GetArticle(articleId)
    if not existing and getError == "not_found" then return VaultNews.Publish(request) end
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil, false end
    local patch = {}
    for _, field in ipairs(MUTABLE_FIELDS) do patch[field] = request[field] end
    local updated, updateError = VaultNews.Update(articleId, "cosmic_war", existing.revision, patch)
    return updated, updateError, false
end

function CosmicWarNews.Resolve(rawEventId, outcome, state)
    if not onServer() then return nil, "server_only" end
    local eventId, eventError = stableId("war", rawEventId)
    if not eventId then return nil, eventError end
    local articleId = "cosmic_war:" .. eventId
    local existing, getError = VaultNews.GetArticle(articleId)
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil end
    return VaultNews.Resolve(articleId, "cosmic_war", existing.revision, {
        state = state or "resolved",
        outcome = outcome,
    })
end

function CosmicWarNews.PublishMission(article, missionType, missionData, location, options)
    if type(missionData) ~= "table" then return nil, "invalid_arguments" end
    missionData.custom = missionData.custom or {}
    if type(missionData.custom.newsEventId) ~= "string" then
        local player = Player()
        local server = Server()
        missionData.custom.newsEventId = table.concat({
            "mission", tostring(missionType), tostring(player and player.index or 0),
            tostring(location and location.x or 0), tostring(location and location.y or 0),
            tostring(math.floor(server and server.unpausedRuntime or 0)),
        }, ":")
    end
    options = options or {}
    options.article = article
    options.eventId = missionData.custom.newsEventId
    options.threadId = options.threadId or missionData.custom.newsEventId
    options.eventType = options.eventType or ("war.mission." .. tostring(missionType) .. ".completed")
    options.location = location
    options.provenance = options.provenance or {
        recordType = "war_mission",
        missionType = tostring(missionType),
        sourceRevision = 1,
        sourceState = options.sourceState or "completed",
        playerIndex = Player() and Player().index or 0,
    }
    return CosmicWarNews.Publish(options)
end

return CosmicWarNews
