--[[
    Lyra Macro & Strategy Library (LyraMacroLib)

    Solo strategy playback confirms each local tower's state before advancing.
    Cash changes are used only to wait for an unaffordable action, never as
    proof that a placement, upgrade, or sell reached the intended tower.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_MACRO_LIBRARY_URL = "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua"
local DEFAULT_UI_LIBRARY_URL = "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraV2.lua"
local DEFAULT_STRATEGY_FOLDER = "LyraStrategies"
local MAP_SCAN_LIMIT = 2500
local LOBBY_PLACE_ID = 113331026373939
local MATCH_PLACE_ID = 133260551256133

local MAP_NAME_KEYS = {
    currentmap = true,
    gamemap = true,
    loadedmap = true,
    map = true,
    mapid = true,
    mapname = true,
    maptitle = true,
    mission = true,
    missionname = true,
    selectedmap = true,
    stage = true,
    stagename = true,
}

local GENERIC_MAP_NAMES = {
    active = true,
    activemap = true,
    current = true,
    currentmap = true,
    default = true,
    difficulty = true,
    gamemap = true,
    get = true,
    info = true,
    load = true,
    loaded = true,
    loadedmap = true,
    lobby = true,
    map = true,
    mapfolder = true,
    mapname = true,
    mapmodel = true,
    mapselect = true,
    mapselection = true,
    maps = true,
    mapvote = true,
    mapvoting = true,
    mode = true,
    ["nil"] = true,
    none = true,
    paths = true,
    select = true,
    selected = true,
    selectedmap = true,
    set = true,
    skip = true,
    start = true,
    terrain = true,
    towers = true,
    unknown = true,
    vote = true,
    votemap = true,
    votingmap = true,
    waypoints = true,
}

local MAP_CONTAINER_NAMES = {
    "CurrentMap",
    "GameMap",
    "LoadedMap",
    "Map",
    "MapFolder",
    "MapModel",
    "Maps",
    "SelectedMap",
}

local DYNAMIC_CONTAINER_NAMES = {
    cameras = true,
    characters = true,
    enemies = true,
    mobs = true,
    npcs = true,
    players = true,
    projectiles = true,
    troops = true,
    towers = true,
    units = true,
}

local MAP_FINGERPRINT_PART_LIMIT = 500
local CHAIN_COA_INTERVAL = 10.2
local CHAIN_COA_REQUIRED_TOWERS = 3
local CHAIN_COA_MIN_UPGRADE = 3
local CHAIN_COA_RETRY_DELAY = 0.75
local CHAIN_COA_POLL_INTERVAL = 0.15
local PRIVATE_SERVER_REFRESH_INTERVAL = 0.5
local PRIVATE_SERVER_ELEVATOR_POLL_INTERVAL = 0.03
local PRIVATE_SERVER_ENTRY_RETRY_INTERVAL = 0.1
local PRIVATE_SERVER_CHAT_STATUS_TIMEOUT = 1
local PRIVATE_SERVER_FLOODCHECK_BASE_COOLDOWN = 3
local PRIVATE_SERVER_FLOODCHECK_MAX_COOLDOWN = 30
local PRIVATE_SERVER_START_RETRY_INTERVAL = 0.2
local PRIVATE_SERVER_START_TIMEOUT = 35
local MODE_VOTE_RETRY_INTERVAL = 0.25
local MODE_VOTE_RETRY_TIMEOUT = 10
local RECORD_PLACEMENT_CONFIRM_TIMEOUT = 1
local REPLAY_CONFIRM_TIMEOUT = 3
local REPLAY_ACCEPTED_RECOVERY_TIMEOUT = 8
local REPLAY_CONFIRM_POLL_INTERVAL = 0.05
local REPLAY_RETRY_INTERVAL = 0.75
local REPLAY_PLACEMENT_MATCH_RADIUS = 8
local DEFAULT_MAX_TOWER_UPGRADE = 5
local PRIVATE_SERVER_MARKER_NAMES = {
    "IsPrivateServer",
    "PrivateServer",
    "PrivateServerEnabled",
    "VIPServer",
}

local TRACKED_ABILITIES = {
    callofarms = "Call Of Arms",
    mafiacall = "Mafia Call",
    overcharge = "Overcharge",
}

local COA_TOWER_NAMES = {
    commander = true,
    lifeguard = true,
}

local COA_ATTRIBUTE_NAMES = {
    "Troop",
    "Tower",
    "TowerName",
    "Unit",
    "UnitName",
    "Skin",
    "SkinName",
}

local LocalPlayer = Players.LocalPlayer
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local TowersFolder = workspace:FindFirstChild("Towers")

local LyraMacro = {
    SpawnedTowers = {},
    SpawnedTowerUpgradeLevels = {},
    KnownTowerTroops = {},
    KnownTowerUpgradeLevels = {},
    CallOfArmsTowerCache = {},
    NextTowerIndex = 0,
    SelectedLoadout = {},
    SelectedMode = "Normal",
    SelectedMap = "",
    SelectedPrivateServerLinkCode = nil,
    PrivateServerStatusProvider = nil,
    IsRecording = false,
    RecordedStrategy = {},
    RecordedTowerIndexes = {},
    RecordedTowerUpgradeLevels = {},
    PendingRecordedPlacements = {},
    RecordingSeenTowers = {},
    RecordingConnections = {},
    NextRecordedTowerIndex = 0,
    LastStrategyExport = nil,
    LastDetectedMapSource = nil,
    SelectedMapFingerprint = "",
    SelectedMapFingerprintSource = nil,
    SelectedMapFingerprintPartCount = 0,
    AutoRecordOnTeleport = false,
    AutoRecordTeleportArmed = false,
    AutoRecordLibraryUrl = nil,
    AutoRecordTimeout = 45,
    LastDetectedElevator = nil,
    PendingElevatorReplay = nil,
    PendingLegacyReplayFingerprint = nil,
    ChainCOAEnabled = false,
    ChainCOAInterval = CHAIN_COA_INTERVAL,
    ChainCOANextIndex = 0,
    ChainCOASeenTowers = {},
    _chainCOAToken = 0,
    _chainCOAConnections = {},
    _resultsWatchToken = 0,
    _chatFloodcheckCount = 0,
    _chatFloodcheckedUntil = 0,
    _chatMessageResults = {},
    _chatStatusConnection = nil,
    _lastChatFloodcheckAt = -math.huge,
    _lastPrivateServerCommand = nil,
    _lastPrivateServerMessageId = nil,
    StrategyLogger = nil,
    _recordHookInstalled = false,
    _originalNamecall = nil,
    _remoteObservationQueue = {},
    _remoteObservationWorkerRunning = false,
}

local function getValueKind(value)
    if typeof then
        return typeof(value)
    end

    return type(value)
end

local function roundNumber(value)
    if value >= 0 then
        return math.floor(value * 1000 + 0.5) / 1000
    end

    return math.ceil(value * 1000 - 0.5) / 1000
end

local function formatNumber(value)
    local formatted = string.format("%.3f", value)
    formatted = formatted:gsub("(%..-)0+$", "%1")
    formatted = formatted:gsub("%.$", "")
    return formatted
end

local function formatLuaValue(value)
    local valueType = type(value)
    local valueKind = getValueKind(value)

    if valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "number" then
        return formatNumber(value)
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueKind == "CFrame" then
        local components = { value:GetComponents() }

        for index, component in ipairs(components) do
            components[index] = formatNumber(component)
        end

        return "CFrame.new(" .. table.concat(components, ", ") .. ")"
    end

    return "nil"
end

local function formatField(key, value)
    return key .. " = " .. formatLuaValue(value)
end

local function formatRecordedStep(step)
    local fields = {
        formatField("action", step.action),
    }

    if step.action == "place" then
        table.insert(fields, formatField("troop", step.troop))
        if type(step.skin) == "string" and step.skin ~= "" then
            table.insert(fields, formatField("skin", step.skin))
        end
        table.insert(fields, formatField("x", step.x))
        table.insert(fields, formatField("y", step.y))
        table.insert(fields, formatField("z", step.z))

        if step.rotation then
            table.insert(fields, formatField("rotation", step.rotation))
        end
    elseif step.action == "mode" then
        table.insert(fields, formatField("mode", step.mode))

        if step.confirmed ~= nil then
            table.insert(fields, formatField("confirmed", step.confirmed))
        end
    elseif step.action == "upgrade" or step.action == "sell" then
        table.insert(fields, formatField("tower", step.tower))

        if step.action == "upgrade" and type(step.level) == "number" then
            table.insert(fields, formatField("level", step.level))
        end
    elseif step.action == "ability" then
        table.insert(fields, formatField("tower", step.tower))
        table.insert(fields, formatField("ability", step.ability))
    elseif step.action == "skip" and step.label then
        table.insert(fields, formatField("label", step.label))
    end

    return "{ " .. table.concat(fields, ", ") .. " }"
end

local function describeStrategyStep(step)
    if step.action == "place" then
        local skinSuffix = type(step.skin) == "string" and step.skin ~= "" and " [" .. step.skin .. "]" or ""
        return "PLACE " .. tostring(step.troop) .. skinSuffix
    elseif step.action == "upgrade" then
        return "UPGRADE TOWER #" .. tostring(step.tower)
    elseif step.action == "sell" then
        return "SELL TOWER #" .. tostring(step.tower)
    elseif step.action == "mode" then
        return "VOTE " .. tostring(step.mode)
    elseif step.action == "skip" then
        return "SKIP WAVE"
    elseif step.action == "ability" then
        return "ACTIVATE " .. tostring(step.ability) .. " ON TOWER #" .. tostring(step.tower)
    end

    return string.upper(tostring(step.action or "UNKNOWN"))
end

local function appendRecordedStrategyLines(lines, strategy)
    table.insert(lines, "local Strategy = {")

    for _, step in ipairs(strategy) do
        table.insert(lines, "    " .. formatRecordedStep(step) .. ",")
    end

    table.insert(lines, "}")
end

local function stripByteOrderMark(source)
    if type(source) == "string" and source:sub(1, 3) == "\239\187\191" then
        return source:sub(4)
    end

    return source
end

local function getCacheBustedUrlPrefix(url)
    local separator = url:find("?", 1, true) and "&t=" or "?t="
    return url .. separator
end

local function sanitizeFileName(value)
    local fileName = tostring(value or ""):gsub("[^%w%._%-]", "_")
    fileName = fileName:gsub("_+", "_")
    fileName = fileName:gsub("^_+", ""):gsub("_+$", "")

    if fileName == "" then
        return "LyraRecordedStrategy"
    end

    return fileName
end

local function getRecordingTimestamp()
    local dated, timestamp = pcall(function()
        return os.date("!%Y%m%d_%H%M%S")
    end)

    if dated and type(timestamp) == "string" and timestamp ~= "" then
        return timestamp
    end

    return tostring(os.time())
end

local function joinFilePath(folder, fileName)
    if type(folder) ~= "string" or folder == "" then
        return fileName
    end

    return folder .. "/" .. fileName
end

local function normalizeLookupKey(value)
    return tostring(value or ""):lower():gsub("[%s_%-%.:]", "")
end

local function isMapNameKey(value)
    local lookupKey = normalizeLookupKey(value)

    if MAP_NAME_KEYS[lookupKey] then
        return true
    end

    return lookupKey:find("map", 1, true) ~= nil
        and (
            lookupKey:find("name", 1, true) ~= nil
            or lookupKey:find("title", 1, true) ~= nil
            or lookupKey:find("current", 1, true) ~= nil
            or lookupKey:find("selected", 1, true) ~= nil
            or lookupKey:find("label", 1, true) ~= nil
        )
end

local function trimString(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeMapCandidate(value)
    if type(value) ~= "string" then
        return nil
    end

    local candidate = trimString(value)
    candidate = candidate:gsub("^Current%s+[Mm]ap%s*[:%-]%s*", "")
    candidate = candidate:gsub("^Selected%s+[Mm]ap%s*[:%-]%s*", "")
    candidate = candidate:gsub("^Loaded%s+[Mm]ap%s*[:%-]%s*", "")
    candidate = candidate:gsub("^[Mm]ap%s*[Nn]ame%s*[:%-]%s*", "")
    candidate = candidate:gsub("^[Mm]ap%s*[:%-]%s*", "")
    candidate = trimString(candidate:gsub("[%s%p]+$", ""))

    if candidate == "" or #candidate > 80 or candidate:find("[\r\n]") then
        return nil
    end

    local lookupKey = normalizeLookupKey(candidate)

    if GENERIC_MAP_NAMES[lookupKey] or #lookupKey < 3 or not candidate:match("[%w]") then
        return nil
    end

    return candidate
end

local function safeGetChildren(instance)
    local ok, children = pcall(function()
        return instance:GetChildren()
    end)

    if ok and type(children) == "table" then
        return children
    end

    return {}
end

local function safeGetDescendants(instance)
    local ok, descendants = pcall(function()
        return instance:GetDescendants()
    end)

    if ok and type(descendants) == "table" then
        return descendants
    end

    return {}
end

local function getInstanceName(instance)
    local ok, name = pcall(function()
        return instance.Name
    end)

    if ok and type(name) == "string" then
        return name
    end

    return nil
end

local function instanceIsA(instance, className)
    local ok, isClass = pcall(function()
        return instance:IsA(className)
    end)

    return ok and isClass
end

local function safeFindFirstChild(instance, childName)
    local ok, child = pcall(function()
        return instance:FindFirstChild(childName)
    end)

    if ok then
        return child
    end

    return nil
end

local function readInstanceValue(instance)
    local ok, value = pcall(function()
        return instance.Value
    end)

    if ok then
        return value
    end

    return nil
end

local function readInstanceText(instance)
    if not (
        instanceIsA(instance, "TextLabel")
        or instanceIsA(instance, "TextButton")
        or instanceIsA(instance, "TextBox")
    ) then
        return nil
    end

    local ok, text = pcall(function()
        return instance.Text
    end)

    if ok then
        return text
    end

    return nil
end

local function findMapNameInValue(value, depth, preferred, source, visited)
    if depth > 4 then
        return nil
    end

    if type(value) == "string" then
        local candidate = normalizeMapCandidate(value)

        if candidate and preferred then
            return candidate, source
        end

        return nil
    end

    local valueKind = getValueKind(value)

    if valueKind == "Instance" then
        local instanceName = getInstanceName(value)
        local hasMapName = preferred or isMapNameKey(instanceName)
        local instanceValue = readInstanceValue(value)

        if instanceValue ~= nil then
            local candidate, valueSource = findMapNameInValue(instanceValue, depth + 1, hasMapName, source .. ".Value", visited)

            if candidate then
                return candidate, valueSource
            end
        end

        if getValueKind(instanceValue) == "Instance" then
            local candidate = normalizeMapCandidate(getInstanceName(instanceValue))

            if candidate and hasMapName then
                return candidate, source .. ".Value.Name"
            end
        end

        local text = readInstanceText(value)

        if text then
            local candidate = normalizeMapCandidate(text)

            if candidate and (hasMapName or text:lower():find("map", 1, true)) then
                return candidate, source .. ".Text"
            end
        end

        local gotAttributes, attributes = pcall(function()
            return value:GetAttributes()
        end)

        if gotAttributes and type(attributes) == "table" then
            for attributeName, attributeValue in pairs(attributes) do
                if isMapNameKey(attributeName) then
                    local candidate = normalizeMapCandidate(attributeValue)

                    if candidate then
                        return candidate, source .. ".Attributes." .. tostring(attributeName)
                    end
                end
            end
        end

        return nil
    end

    if type(value) ~= "table" then
        return nil
    end

    visited = visited or {}

    if visited[value] then
        return nil
    end

    visited[value] = true

    for key, childValue in pairs(value) do
        local childPreferred = preferred or isMapNameKey(key)
        local candidate, childSource = findMapNameInValue(childValue, depth + 1, childPreferred, source .. "." .. tostring(key), visited)

        if candidate then
            return candidate, childSource
        end
    end

    return nil
end

local function findMapNameInInstanceMetadata(instance, source)
    local candidate, candidateSource = findMapNameInValue(instance, 0, false, source, {})

    if candidate then
        return candidate, candidateSource
    end

    for _, child in ipairs(safeGetChildren(instance)) do
        local childName = getInstanceName(child)

        if isMapNameKey(childName) then
            candidate, candidateSource = findMapNameInValue(child, 0, true, source .. "." .. childName, {})

            if candidate then
                return candidate, candidateSource
            end
        end
    end

    return nil
end

local function findMapNameInContainer(instance, source)
    local candidate, candidateSource = findMapNameInInstanceMetadata(instance, source)

    if candidate then
        return candidate, candidateSource
    end

    candidate = normalizeMapCandidate(getInstanceName(instance))

    if candidate then
        return candidate, source .. ".Name"
    end

    for _, child in ipairs(safeGetChildren(instance)) do
        local childName = getInstanceName(child)

        candidate, candidateSource = findMapNameInInstanceMetadata(child, source .. "." .. tostring(childName))

        if candidate then
            return candidate, candidateSource
        end

        if instanceIsA(child, "Folder") or instanceIsA(child, "Model") then
            candidate = normalizeMapCandidate(childName)

            if candidate then
                return candidate, source .. "." .. childName .. ".Name"
            end
        end
    end

    return nil
end

local function scanDescendantsForMapName(root, rootName)
    local descendants = safeGetDescendants(root)
    local scanned = 0

    for _, instance in ipairs(descendants) do
        scanned += 1

        if scanned > MAP_SCAN_LIMIT then
            break
        end

        local instanceName = getInstanceName(instance)
        local source = rootName .. "." .. tostring(instanceName)

        if isMapNameKey(instanceName) then
            local candidate, candidateSource = findMapNameInValue(instance, 0, true, source, {})

            if candidate then
                return candidate, candidateSource
            end
        end

        local text = readInstanceText(instance)

        if text and text:lower():find("map", 1, true) then
            local candidate = normalizeMapCandidate(text)

            if candidate then
                return candidate, source .. ".Text"
            end
        end
    end

    return nil
end

local function detectMapFromRoot(root, rootName)
    for _, containerName in ipairs(MAP_CONTAINER_NAMES) do
        local container = safeFindFirstChild(root, containerName)

        if container then
            local candidate, source = findMapNameInContainer(container, rootName .. "." .. containerName)

            if candidate then
                return candidate, source
            end
        end
    end

    return scanDescendantsForMapName(root, rootName)
end

local function remoteRouteLooksMapRelated(args)
    for index = 1, math.min(#args, 4) do
        local value = args[index]

        if type(value) == "string" then
            local lookupKey = normalizeLookupKey(value)

            if MAP_NAME_KEYS[lookupKey]
                or lookupKey:find("map", 1, true)
                or lookupKey:find("mission", 1, true)
                or lookupKey:find("stage", 1, true)
            then
                return true
            end
        end
    end

    return false
end

local function detectMapFromRemoteArgs(args)
    if not remoteRouteLooksMapRelated(args) then
        return nil
    end

    return findMapNameInValue(args, 0, true, "RemoteFunction", {})
end

local function isDynamicContainer(instance)
    local instanceName = getInstanceName(instance)

    if not instanceName then
        return false
    end

    return DYNAMIC_CONTAINER_NAMES[normalizeLookupKey(instanceName)] == true
end

local function getInstanceParent(instance)
    local ok, parent = pcall(function()
        return instance.Parent
    end)

    if ok then
        return parent
    end

    return nil
end

local function isUnderDynamicContainer(instance, root)
    local current = instance

    while current and current ~= root do
        if isDynamicContainer(current) then
            return true
        end

        current = getInstanceParent(current)
    end

    return false
end

local function fingerprintNumber(value)
    return formatNumber(roundNumber(value))
end

local function rollingHash(value)
    local hash = 5381

    for index = 1, #value do
        hash = (hash * 33 + value:byte(index)) % 2147483647
    end

    return tostring(hash)
end

local function getMapRootCandidateScore(instance)
    if isDynamicContainer(instance) then
        return -1, 0
    end

    local instanceName = getInstanceName(instance) or ""
    local lookupKey = normalizeLookupKey(instanceName)
    local score = 0
    local partCount = 0

    if lookupKey:find("map", 1, true)
        or lookupKey:find("terrain", 1, true)
        or lookupKey:find("path", 1, true)
        or lookupKey:find("stage", 1, true)
    then
        score += 200
    end

    if instanceIsA(instance, "Model") or instanceIsA(instance, "Folder") then
        score += 25
    end

    for _, descendant in ipairs(safeGetDescendants(instance)) do
        if isUnderDynamicContainer(descendant, instance) then
            continue
        end

        local descendantName = getInstanceName(descendant) or ""
        local descendantKey = normalizeLookupKey(descendantName)

        if instanceIsA(descendant, "BasePart") then
            partCount += 1
            score += 3
        end

        if descendantKey:find("waypoint", 1, true)
            or descendantKey:find("path", 1, true)
            or descendantKey:find("road", 1, true)
            or descendantKey:find("track", 1, true)
        then
            score += 15
        end

        if partCount >= MAP_FINGERPRINT_PART_LIMIT then
            break
        end
    end

    return score, partCount
end

local function findBestMapFingerprintRoot()
    for _, containerName in ipairs(MAP_CONTAINER_NAMES) do
        local container = safeFindFirstChild(workspace, containerName)

        if container and not isDynamicContainer(container) then
            local score, partCount = getMapRootCandidateScore(container)

            if partCount > 0 then
                return container, "workspace." .. containerName, score, partCount
            end
        end
    end

    local bestRoot = nil
    local bestSource = nil
    local bestScore = -1
    local bestPartCount = 0

    for _, child in ipairs(safeGetChildren(workspace)) do
        if not isDynamicContainer(child) and (instanceIsA(child, "Model") or instanceIsA(child, "Folder")) then
            local score, partCount = getMapRootCandidateScore(child)

            if partCount > 0 and score > bestScore then
                bestRoot = child
                bestSource = "workspace." .. tostring(getInstanceName(child))
                bestScore = score
                bestPartCount = partCount
            end
        end
    end

    if bestRoot then
        return bestRoot, bestSource, bestScore, bestPartCount
    end

    return workspace, "workspace", 0, 0
end

local function collectFingerprintParts(root)
    local lines = {}
    local partCount = 0

    for _, instance in ipairs(safeGetDescendants(root)) do
        if isUnderDynamicContainer(instance, root) then
            continue
        end

        if instanceIsA(instance, "BasePart") then
            local ok, descriptor = pcall(function()
                local position = instance.Position
                local size = instance.Size
                return table.concat({
                    getInstanceName(instance) or "",
                    tostring(instance.ClassName),
                    fingerprintNumber(position.X),
                    fingerprintNumber(position.Y),
                    fingerprintNumber(position.Z),
                    fingerprintNumber(size.X),
                    fingerprintNumber(size.Y),
                    fingerprintNumber(size.Z),
                }, "|")
            end)

            if ok and descriptor then
                table.insert(lines, descriptor)
                partCount += 1
            end

            if partCount >= MAP_FINGERPRINT_PART_LIMIT then
                break
            end
        end
    end

    table.sort(lines)
    return lines, partCount
end

local function buildMapFingerprint()
    local root, source = findBestMapFingerprintRoot()
    local lines, partCount = collectFingerprintParts(root)

    if partCount == 0 then
        return nil, source, 0
    end

    local fingerprintBody = table.concat(lines, "\n")
    return rollingHash(fingerprintBody) .. "-" .. tostring(partCount), source, partCount
end

local function cloneStrategy(strategy)
    local copiedStrategy = {}

    for index, step in ipairs(strategy) do
        local copiedStep = {}

        for key, value in pairs(step) do
            copiedStep[key] = value
        end

        copiedStrategy[index] = copiedStep
    end

    return copiedStrategy
end

local function getUniqueTroopNames(values)
    local troopNames = {}
    local seen = {}

    if type(values) ~= "table" then
        return troopNames
    end

    for _, value in pairs(values) do
        local troopName = type(value) == "string" and value or (type(value) == "table" and value.Name)
        local lookupKey = normalizeLookupKey(troopName)

        if type(troopName) == "string" and troopName ~= "" and lookupKey ~= "" and not seen[lookupKey] then
            seen[lookupKey] = true
            table.insert(troopNames, troopName)
        end
    end

    return troopNames
end

local function getStrategyTroopNames(strategy)
    local troopNames = {}
    local seen = {}

    if type(strategy) ~= "table" then
        return troopNames
    end

    for _, step in ipairs(strategy) do
        local troopName = step.action == "place" and step.troop or nil
        local lookupKey = normalizeLookupKey(troopName)

        if type(troopName) == "string" and troopName ~= "" and lookupKey ~= "" and not seen[lookupKey] then
            seen[lookupKey] = true
            table.insert(troopNames, troopName)
        end
    end

    return troopNames
end

local function loadoutsMatch(left, right)
    local leftNames = getUniqueTroopNames(left)
    local rightNames = getUniqueTroopNames(right)

    if #leftNames ~= #rightNames then
        return false
    end

    local rightLookup = {}

    for _, troopName in ipairs(rightNames) do
        rightLookup[normalizeLookupKey(troopName)] = true
    end

    for _, troopName in ipairs(leftNames) do
        if not rightLookup[normalizeLookupKey(troopName)] then
            return false
        end
    end

    return true
end

local function appendLoadoutLines(lines, loadout)
    table.insert(lines, "local StrategyLoadout = {")

    for _, troopName in ipairs(loadout) do
        table.insert(lines, "    " .. formatLuaValue(troopName) .. ",")
    end

    table.insert(lines, "}")
end

local function readEquippedTroops(timeout)
    local cacheModule = ReplicatedStorage:FindFirstChild("Client")
    cacheModule = cacheModule and cacheModule:FindFirstChild("Modules")
    cacheModule = cacheModule and cacheModule:FindFirstChild("Universal")
    cacheModule = cacheModule and cacheModule:FindFirstChild("Utilities")
    cacheModule = cacheModule and cacheModule:FindFirstChild("Cache")

    if not cacheModule then
        return nil, "Could not find the Equipped.Troops cache module."
    end

    local loaded, cacheFactoryOrError = pcall(require, cacheModule)

    if not loaded and type(getloadedmodules) == "function" then
        for _, loadedModule in ipairs(getloadedmodules()) do
            if loadedModule.Name == "Cache" and loadedModule:IsA("ModuleScript") then
                local retried, retryResult = pcall(require, loadedModule)

                if retried then
                    loaded = true
                    cacheFactoryOrError = retryResult
                    break
                end
            end
        end
    end

    if not loaded then
        return nil, "Could not load the Equipped.Troops cache: " .. tostring(cacheFactoryOrError)
    end

    local cacheFactory = cacheFactoryOrError

    local requested, cacheValue = pcall(function()
        return cacheFactory("Equipped.Troops"):Get()
    end)

    if not requested then
        return nil, "Could not request Equipped.Troops: " .. tostring(cacheValue)
    end

    if type(cacheValue) == "table" and type(cacheValue.andThen) ~= "function" then
        return cacheValue
    end

    local resolvedValue
    local resolvedError
    local settled = false
    local subscribed, subscribeError = pcall(function()
        cacheValue:andThen(function(value)
            resolvedValue = value
            settled = true
        end, function(reason)
            resolvedError = reason
            settled = true
        end)
    end)

    if not subscribed then
        return nil, "Could not read Equipped.Troops: " .. tostring(subscribeError)
    end

    local deadline = os.clock() + (timeout or 5)

    while not settled and os.clock() < deadline do
        task.wait()
    end

    if not settled then
        return nil, "Timed out waiting for Equipped.Troops."
    end

    if resolvedError then
        return nil, "Could not read Equipped.Troops: " .. tostring(resolvedError)
    end

    return resolvedValue
end

local function waitForEquippedTroops(expectedLoadout, timeout)
    local deadline = os.clock() + (timeout or 5)

    while os.clock() < deadline do
        local currentLoadout = readEquippedTroops(1)

        if currentLoadout and loadoutsMatch(currentLoadout, expectedLoadout) then
            return true
        end

        task.wait(0.1)
    end

    return false
end

local function getCashValue()
    local cash = LocalPlayer:WaitForChild("Cash")

    assert(
        cash:IsA("IntValue") or cash:IsA("NumberValue"),
        "[LyraMacro] Players.LocalPlayer.Cash must be an IntValue or NumberValue."
    )

    return cash
end

local function getTowersFolder()
    TowersFolder = TowersFolder or workspace:WaitForChild("Towers")
    return TowersFolder
end

local function isCallOfArmsIdentifier(value)
    local lookupKey = normalizeLookupKey(value)

    return COA_TOWER_NAMES[lookupKey]
        or lookupKey == "callofarms"
        or lookupKey:find("commander", 1, true) ~= nil
        or lookupKey:find("lifeguard", 1, true) ~= nil
end

local function hasCallOfArmsAttributes(instance)
    local gotAttributes, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if not gotAttributes or type(attributes) ~= "table" then
        return false
    end

    for _, attributeValue in pairs(attributes) do
        if isCallOfArmsIdentifier(attributeValue) then
            return true
        end
    end

    return false
end

local function isCallOfArmsTower(tower, knownTroopType)
    if isCallOfArmsIdentifier(knownTroopType) or isCallOfArmsIdentifier(getInstanceName(tower)) or hasCallOfArmsAttributes(tower) then
        return true
    end

    for _, attributeName in ipairs(COA_ATTRIBUTE_NAMES) do
        local gotAttribute, attributeValue = pcall(function()
            return tower:GetAttribute(attributeName)
        end)

        if gotAttribute and isCallOfArmsIdentifier(attributeValue) then
            return true
        end
    end

    for _, descendant in ipairs(safeGetDescendants(tower)) do
        if isCallOfArmsIdentifier(getInstanceName(descendant)) or hasCallOfArmsAttributes(descendant) then
            return true
        end

        if instanceIsA(descendant, "StringValue") then
            local value = readInstanceValue(descendant)

            if isCallOfArmsIdentifier(value) then
                return true
            end
        elseif instanceIsA(descendant, "ObjectValue") then
            local value = readInstanceValue(descendant)

            if getValueKind(value) == "Instance" and isCallOfArmsIdentifier(getInstanceName(value)) then
                return true
            end
        end
    end

    return false
end

local function readAttribute(instance, attributeName)
    local gotAttribute, attributeValue = pcall(function()
        return instance:GetAttribute(attributeName)
    end)

    if gotAttribute then
        return attributeValue
    end

    return nil
end

local function isTowerOwnedByLocalPlayer(tower)
    local owner = safeFindFirstChild(tower, "Owner")
    local ownerValue = owner and readInstanceValue(owner)

    if ownerValue == LocalPlayer then
        return true
    end

    return tonumber(ownerValue) == LocalPlayer.UserId
end

local function getTowerReplicator(tower)
    return safeFindFirstChild(tower, "TowerReplicator")
end

local function getTowerUpgradeLevel(tower)
    local replicator = getTowerReplicator(tower)

    if not replicator then
        return nil
    end

    local upgrade = readAttribute(replicator, "Upgrade")

    if upgrade == nil then
        local upgradeValue = safeFindFirstChild(replicator, "Upgrade")
        upgrade = upgradeValue and readInstanceValue(upgradeValue)
    end

    return tonumber(upgrade)
end

local function getTowerMaximumUpgrade(tower)
    local replicator = getTowerReplicator(tower)
    local maximumKeys = {
        "MaxUpgrade",
        "MaxLevel",
        "MaximumUpgrade",
    }
    local instances = { tower }

    if replicator then
        table.insert(instances, 1, replicator)
    end

    for _, instance in ipairs(instances) do
        for _, key in ipairs(maximumKeys) do
            local maximum = tonumber(readAttribute(instance, key))

            if maximum then
                return maximum, true
            end

            local maximumValue = safeFindFirstChild(instance, key)
            maximum = maximumValue and tonumber(readInstanceValue(maximumValue))

            if maximum then
                return maximum, true
            end
        end
    end

    return DEFAULT_MAX_TOWER_UPGRADE, false
end

local function getTowerWorldPosition(tower)
    if instanceIsA(tower, "BasePart") then
        local gotPosition, position = pcall(function()
            return tower.Position
        end)

        if gotPosition then
            return position
        end
    end

    if instanceIsA(tower, "Model") then
        local gotPivot, pivot = pcall(function()
            return tower:GetPivot()
        end)

        if gotPivot then
            return pivot.Position
        end
    end

    for _, descendant in ipairs(safeGetDescendants(tower)) do
        if instanceIsA(descendant, "BasePart") then
            local gotPosition, position = pcall(function()
                return descendant.Position
            end)

            if gotPosition then
                return position
            end
        end
    end

    return nil
end

local function snapshotTowers(towersFolder)
    local snapshot = {}

    for _, tower in ipairs(safeGetChildren(towersFolder)) do
        snapshot[tower] = true
    end

    return snapshot
end

local function copyTowerSnapshot(snapshot)
    local copy = {}

    for tower in pairs(snapshot or {}) do
        copy[tower] = true
    end

    return copy
end

local function isDirectTowerChild(tower, towersFolder)
    local gotParent, parent = pcall(function()
        return tower.Parent
    end)

    return gotParent and parent == towersFolder
end

local function getTowerDistanceFrom(tower, expectedPosition)
    if getValueKind(expectedPosition) ~= "Vector3" then
        return nil
    end

    local towerPosition = getTowerWorldPosition(tower)

    if not towerPosition then
        return nil
    end

    local gotDistance, distance = pcall(function()
        return (towerPosition - expectedPosition).Magnitude
    end)

    return gotDistance and distance or nil
end

local function createPlacementTracker(towersFolder, existingTowers)
    local tracker = {
        Candidates = {},
        CandidateSet = {},
        Connection = nil,
        TowersFolder = towersFolder,
    }

    tracker.Track = function(tower)
        if tower and not existingTowers[tower] and not tracker.CandidateSet[tower] then
            tracker.CandidateSet[tower] = true
            table.insert(tracker.Candidates, tower)
        end
    end

    local connected, connection = pcall(function()
        return towersFolder.ChildAdded:Connect(tracker.Track)
    end)

    if connected then
        tracker.Connection = connection
    end

    -- Catch anything added between the snapshot and the ChildAdded connection.
    for _, tower in ipairs(safeGetChildren(towersFolder)) do
        tracker.Track(tower)
    end

    return tracker
end

local function stopPlacementTracker(tracker)
    if tracker and tracker.Connection then
        pcall(function()
            tracker.Connection:Disconnect()
        end)
        tracker.Connection = nil
    end
end

local function trackPlacementResponse(tracker, response)
    if not tracker then
        return
    end

    if getValueKind(response) == "Instance" then
        local candidate = response

        while candidate and candidate ~= tracker.TowersFolder do
            local gotParent, parent = pcall(function()
                return candidate.Parent
            end)

            if not gotParent then
                break
            end

            if parent == tracker.TowersFolder then
                tracker.Track(candidate)
                break
            end

            candidate = parent
        end

        return
    end

    if type(response) == "table" then
        for _, key in ipairs({ "Tower", "Troop", "Instance", "Model" }) do
            if response[key] ~= nil then
                trackPlacementResponse(tracker, response[key])
            end
        end
    end
end

local function findNewTowerCandidate(towersFolder, existingTowers, expectedPosition, trackedCandidates)
    local candidates = {}
    local candidateSet = {}

    local function consider(tower)
        if not tower or existingTowers[tower] or candidateSet[tower] or not isDirectTowerChild(tower, towersFolder) then
            return
        end

        candidateSet[tower] = true
        table.insert(candidates, tower)
    end

    for _, tower in ipairs(trackedCandidates or {}) do
        consider(tower)
    end

    for _, tower in ipairs(safeGetChildren(towersFolder)) do
        consider(tower)
    end

    if #candidates == 1 then
        -- Strategy replay is solo-only. The exact ChildAdded instance is safe even
        -- before its Owner/TowerReplicator metadata finishes replicating.
        return candidates[1]
    end

    local closestOwnedTower
    local closestOwnedDistance
    local closestTower
    local closestDistance

    for _, tower in ipairs(candidates) do
        local distance = getTowerDistanceFrom(tower, expectedPosition)
        local comparisonDistance = distance or (REPLAY_PLACEMENT_MATCH_RADIUS * 2)

        if not closestDistance or comparisonDistance < closestDistance then
            closestTower = tower
            closestDistance = comparisonDistance
        end

        if isTowerOwnedByLocalPlayer(tower)
            and (not closestOwnedDistance or comparisonDistance < closestOwnedDistance) then
            closestOwnedTower = tower
            closestOwnedDistance = comparisonDistance
        end
    end

    return closestOwnedTower or closestTower
end

local function waitForNewTowerCandidate(towersFolder, existingTowers, expectedPosition, trackedCandidates, timeout)
    local deadline = os.clock() + (timeout or REPLAY_CONFIRM_TIMEOUT)

    while os.clock() < deadline do
        local tower = findNewTowerCandidate(towersFolder, existingTowers, expectedPosition, trackedCandidates)

        if tower then
            return tower
        end

        task.wait(REPLAY_CONFIRM_POLL_INTERVAL)
    end

    return findNewTowerCandidate(towersFolder, existingTowers, expectedPosition, trackedCandidates)
end

local function waitForCondition(timeout, predicate)
    local deadline = os.clock() + (timeout or REPLAY_CONFIRM_TIMEOUT)

    while os.clock() < deadline do
        if predicate() then
            return true
        end

        task.wait(REPLAY_CONFIRM_POLL_INTERVAL)
    end

    return predicate()
end

local function waitForCashChange(cash, observedValue, timeout)
    return waitForCondition(timeout or REPLAY_RETRY_INTERVAL, function()
        return cash.Value ~= observedValue
    end)
end

local function remoteResponseWasAccepted(response)
    if response == true or getValueKind(response) == "Instance" then
        return true
    end

    return type(response) == "table"
        and (response.Success == true or response.Successful == true or response.Ok == true)
end

local function remoteResponseWasRejected(response)
    if response == false then
        return true
    end

    if type(response) == "table" then
        return response.Success == false or response.Successful == false or response.Ok == false
    end

    return false
end

local function isCallOfArmsTowerStunned(tower)
    local replicator = getTowerReplicator(tower)
    local stuns = replicator and safeFindFirstChild(replicator, "Stuns")

    if not stuns then
        return false
    end

    if readAttribute(stuns, "1") == true then
        return true
    end

    local stunFlag = safeFindFirstChild(stuns, "1")
    return stunFlag and readInstanceValue(stunFlag) == true or false
end

local function getCallOfArmsTowerReadiness(tower, knownUpgradeLevel)
    local upgrade = getTowerUpgradeLevel(tower) or tonumber(knownUpgradeLevel)

    if upgrade and upgrade < CHAIN_COA_MIN_UPGRADE then
        return false, "needs upgrade"
    end

    if isCallOfArmsTowerStunned(tower) then
        return false, "stunned"
    end

    return true
end

function LyraMacro:ActivateAbilityForTower(tower, abilityName)
    assert(tower and tower.Parent, "[LyraMacro] Cannot activate an ability for a missing tower.")

    local canonicalAbilityName = TRACKED_ABILITIES[normalizeLookupKey(abilityName)] or tostring(abilityName or "")
    assert(canonicalAbilityName ~= "", "[LyraMacro] Ability name is required.")

    return RemoteFunction:InvokeServer("Troops", "Abilities", "Activate", {
        Name = canonicalAbilityName,
        Troop = tower,
    })
end

function LyraMacro:ActivateAbility(towerIndex, abilityName)
    local targetTower = self.SpawnedTowers[towerIndex]
    assert(
        targetTower and targetTower.Parent,
        "[LyraMacro] Cannot activate an ability for tower #" .. tostring(towerIndex) .. "; it is missing or was sold."
    )

    self:ActivateAbilityForTower(targetTower, abilityName)
    print("[LyraMacro] Activated " .. tostring(abilityName) .. " for tower #" .. tostring(towerIndex) .. ".")
end

function LyraMacro:_getCallOfArmsTowers()
    local callOfArmsTowers = {}
    local now = os.clock()

    for _, tower in ipairs(getTowersFolder():GetChildren()) do
        local knownTroopType = self.KnownTowerTroops[tower]
        local cacheEntry = self.CallOfArmsTowerCache[tower]
        local isCallOfArms

        if knownTroopType then
            isCallOfArms = isCallOfArmsIdentifier(knownTroopType)
        elseif cacheEntry and now - cacheEntry.CheckedAt < 0.5 then
            isCallOfArms = cacheEntry.IsCallOfArms
        else
            isCallOfArms = isCallOfArmsTower(tower)
            self.CallOfArmsTowerCache[tower] = {
                CheckedAt = now,
                IsCallOfArms = isCallOfArms,
            }
        end

        -- Lyra replay is solo-only. Known macro placements remain trustworthy even
        -- when this game does not replicate a direct Owner child on tower skins.
        if tower.Parent and isCallOfArms then
            table.insert(callOfArmsTowers, tower)
        end
    end

    return callOfArmsTowers
end

function LyraMacro:_clearChainCOAConnections()
    for _, connection in ipairs(self._chainCOAConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    self._chainCOAConnections = {}
end

function LyraMacro:SetChainCOA(enabled)
    enabled = enabled == true

    if enabled and game.PlaceId ~= MATCH_PLACE_ID then
        return false, "Chain COA can only run in match place " .. tostring(MATCH_PLACE_ID) .. "."
    end

    self.ChainCOAEnabled = enabled
    self._chainCOAToken += 1
    self:_clearChainCOAConnections()

    if not enabled then
        table.clear(self.ChainCOASeenTowers)
        print("[LyraMacro] Chain COA disabled.")
        return true, "Chain COA disabled."
    end

    local recorderInstalled, recorderMessage = self:_installRecorder()

    if not recorderInstalled then
        warn("[LyraMacro] Chain COA could not watch new tower placements: " .. tostring(recorderMessage))
    end

    self.ChainCOANextIndex = 0
    local chainToken = self._chainCOAToken
    local rosterChanged = true
    local towersFolder = getTowersFolder()
    self.ChainCOASeenTowers = snapshotTowers(towersFolder)

    local function markRosterChanged(tower)
        self.CallOfArmsTowerCache[tower] = nil
        rosterChanged = true
    end

    table.insert(self._chainCOAConnections, towersFolder.ChildAdded:Connect(function(tower)
        markRosterChanged(tower)
        task.delay(0.25, function()
            if self.ChainCOAEnabled and self._chainCOAToken == chainToken then
                markRosterChanged(tower)
            end
        end)
    end))
    table.insert(self._chainCOAConnections, towersFolder.ChildRemoved:Connect(markRosterChanged))

    print("[LyraMacro] Chain COA armed. Waiting for " .. tostring(CHAIN_COA_REQUIRED_TOWERS) .. " detected, upgrade-ready Commander/Lifeguard towers, then rotating Call Of Arms every " .. tostring(self.ChainCOAInterval) .. " seconds.")

    task.spawn(function()
        local towerOrder = {}
        local nextTowerOrder = 0
        local lastActivatedTower
        local nextActivationAt
        local activationInFlight = false
        local rotationActive = false
        local lastStatus = ""

        local function reportStatus(message)
            if message ~= lastStatus then
                print("[LyraMacro] " .. message)
                lastStatus = message
            end
        end

        local function getReadyRoster()
            local allTowers = self:_getCallOfArmsTowers()
            local readyTowers = {}
            local states = {
                NeedsUpgrade = 0,
                Stunned = 0,
            }

            for _, tower in ipairs(allTowers) do
                if not towerOrder[tower] then
                    nextTowerOrder += 1
                    towerOrder[tower] = nextTowerOrder
                    rosterChanged = true
                end

                local ready, reason = getCallOfArmsTowerReadiness(tower, self.KnownTowerUpgradeLevels[tower])

                if ready then
                    table.insert(readyTowers, tower)
                elseif reason == "needs upgrade" then
                    states.NeedsUpgrade += 1
                elseif reason == "stunned" then
                    states.Stunned += 1
                end
            end

            table.sort(readyTowers, function(left, right)
                return towerOrder[left] < towerOrder[right]
            end)

            return allTowers, readyTowers, states
        end

        local function getNextTower(readyTowers)
            local previousIndex

            if lastActivatedTower then
                for index, tower in ipairs(readyTowers) do
                    if tower == lastActivatedTower then
                        previousIndex = index
                        break
                    end
                end
            end

            local nextIndex

            if previousIndex then
                nextIndex = previousIndex % #readyTowers + 1
            else
                nextIndex = self.ChainCOANextIndex % #readyTowers + 1
            end

            self.ChainCOANextIndex = nextIndex
            return readyTowers[nextIndex]
        end

        while self.ChainCOAEnabled and self._chainCOAToken == chainToken and game.PlaceId == MATCH_PLACE_ID do
            local callOfArmsTowers, readyTowers, states = getReadyRoster()

            if #callOfArmsTowers < CHAIN_COA_REQUIRED_TOWERS then
                reportStatus("Chain COA has " .. tostring(#callOfArmsTowers) .. "/" .. tostring(CHAIN_COA_REQUIRED_TOWERS) .. " detected Commander/Lifeguard towers.")
                rotationActive = false
                lastActivatedTower = nil
                self.ChainCOANextIndex = 0
                nextActivationAt = nil
                task.wait(CHAIN_COA_POLL_INTERVAL)
            elseif #readyTowers < CHAIN_COA_REQUIRED_TOWERS then
                local waiting = {}

                if states.NeedsUpgrade > 0 then
                    table.insert(waiting, tostring(states.NeedsUpgrade) .. " need upgrade " .. tostring(CHAIN_COA_MIN_UPGRADE))
                end
                if states.Stunned > 0 then
                    table.insert(waiting, tostring(states.Stunned) .. " stunned")
                end

                reportStatus("Chain COA is waiting for " .. tostring(CHAIN_COA_REQUIRED_TOWERS) .. " ready commanders (" .. tostring(#readyTowers) .. " ready; " .. table.concat(waiting, ", ") .. ").")
                rotationActive = false
                lastActivatedTower = nil
                self.ChainCOANextIndex = 0
                nextActivationAt = nil
                task.wait(CHAIN_COA_POLL_INTERVAL)
            else
                if not rotationActive then
                    rotationActive = true
                    nextActivationAt = os.clock()
                    reportStatus("Chain COA detected " .. tostring(#readyTowers) .. " ready commanders; starting stable rotation.")
                elseif rosterChanged then
                    print("[LyraMacro] Chain COA roster changed; preserving the next activation slot.")
                end

                rosterChanged = false
                local now = os.clock()
                local waitTime = (nextActivationAt or now) - now

                if waitTime > 0 then
                    task.wait(math.min(waitTime, CHAIN_COA_POLL_INTERVAL))
                elseif activationInFlight then
                    task.wait(0.05)
                else
                    local targetTower = getNextTower(readyTowers)
                    local scheduledAt = os.clock()

                    lastActivatedTower = targetTower
                    nextActivationAt = scheduledAt + self.ChainCOAInterval
                    activationInFlight = true

                    task.spawn(function()
                        local activated, responseOrError = pcall(function()
                            assert(
                                self.ChainCOAEnabled and self._chainCOAToken == chainToken and targetTower.Parent,
                                "The selected commander is no longer available."
                            )

                            return self:ActivateAbilityForTower(targetTower, "Call Of Arms")
                        end)

                        activationInFlight = false

                        if not activated or remoteResponseWasRejected(responseOrError) then
                            if self.ChainCOAEnabled and self._chainCOAToken == chainToken then
                                nextActivationAt = math.min(nextActivationAt or math.huge, os.clock() + CHAIN_COA_RETRY_DELAY)
                            end

                            warn("[LyraMacro] Chain COA skipped a rejected commander activation: " .. tostring(responseOrError))
                        else
                            print(
                                "[LyraMacro] Chain COA activated commander slot "
                                    .. tostring(towerOrder[targetTower] or "?")
                                    .. "; next activation in "
                                    .. tostring(self.ChainCOAInterval)
                                    .. " seconds."
                            )
                        end
                    end)
                end
            end
        end

        if self._chainCOAToken == chainToken then
            self:_clearChainCOAConnections()
        end
    end)

    return true, "Chain COA enabled."
end

-- Sets the starting troop configuration. Lobby selection is intentionally separate.
function LyraMacro:Loadout(...)
    self.SelectedLoadout = { ... }
    print("[LyraMacro] Loadout configured: " .. table.concat(self.SelectedLoadout, ", "))
end

function LyraMacro:GetStrategyLoadout(strategy)
    return getStrategyTroopNames(strategy)
end

function LyraMacro:GetRecordedLoadout()
    return self:GetStrategyLoadout(self.RecordedStrategy)
end

function LyraMacro:SyncLobbyLoadout(loadout)
    if game.PlaceId ~= LOBBY_PLACE_ID then
        return false, "Troop loadouts can only be changed in lobby place " .. tostring(LOBBY_PLACE_ID) .. "."
    end

    local desiredLoadout = getUniqueTroopNames(loadout)

    if #desiredLoadout > 5 then
        return false, "This strategy uses " .. tostring(#desiredLoadout) .. " towers, but the lobby loadout only supports five."
    end

    local equippedLoadout, equippedError = readEquippedTroops()

    if not equippedLoadout then
        return false, equippedError
    end

    local currentLoadout = getUniqueTroopNames(equippedLoadout)

    for _, troopName in ipairs(currentLoadout) do
        RemoteEvent:FireServer("Inventory", "Execute", "Troops", "Remove", {
            Name = troopName,
        })
        task.wait(0.15)
    end

    if #currentLoadout > 0 then
        if not waitForEquippedTroops({}, 5) then
            return false, "Timed out while clearing the current lobby loadout."
        end
    end

    for _, troopName in ipairs(desiredLoadout) do
        RemoteEvent:FireServer("Inventory", "Execute", "Troops", "Add", {
            Name = troopName,
        })
        task.wait(0.15)
    end

    if not waitForEquippedTroops(desiredLoadout, 5) then
        return false, "Timed out while equipping the strategy loadout."
    end

    self.SelectedLoadout = getUniqueTroopNames(desiredLoadout)
    print("[LyraMacro] Lobby loadout synchronized: " .. table.concat(self.SelectedLoadout, ", "))

    return true, self.SelectedLoadout
end

function LyraMacro:PrepareStrategyLoadout(strategy, options)
    options = options or {}
    local loadout = options.Loadout or self:GetStrategyLoadout(strategy)

    return self:SyncLobbyLoadout(loadout)
end

function LyraMacro:Mode(modeName)
    self.SelectedMode = modeName
    print("[LyraMacro] Mode configured: " .. modeName)
end

function LyraMacro:VoteMode(modeName, confirmed)
    self:Mode(modeName)
    print("[LyraMacro] Voting for difficulty: " .. tostring(modeName))

    local deadline = os.clock() + MODE_VOTE_RETRY_TIMEOUT
    local attempt = 0
    local lastError = "The difficulty vote was not attempted."

    while os.clock() < deadline do
        attempt += 1

        local invoked, responseOrError = pcall(function()
            -- Preserve the recorded call exactly; nil means there was no fourth argument.
            if confirmed == nil then
                return RemoteFunction:InvokeServer("Difficulty", "Vote", modeName)
            end

            return RemoteFunction:InvokeServer("Difficulty", "Vote", modeName, confirmed)
        end)

        if invoked and responseOrError ~= false then
            print("[LyraMacro] Difficulty vote accepted (attempt " .. tostring(attempt) .. ").")
            return responseOrError
        end

        lastError = invoked and "The difficulty server rejected the vote." or tostring(responseOrError)
        print(
            "[LyraMacro] Difficulty vote is waiting for player data (attempt "
                .. tostring(attempt)
                .. "): "
                .. tostring(lastError)
        )
        task.wait(MODE_VOTE_RETRY_INTERVAL)
    end

    error(
        "[LyraMacro] Difficulty vote for "
            .. tostring(modeName)
            .. " failed after "
            .. tostring(MODE_VOTE_RETRY_TIMEOUT)
            .. " seconds: "
            .. tostring(lastError),
        2
    )
end

local function normalizePrivateServerLinkCode(value)
    if value == nil then
        return nil
    end

    local linkCode = trimString(value)
    return linkCode ~= "" and linkCode or nil
end

function LyraMacro:SetPrivateServerLinkCode(linkCode)
    self.SelectedPrivateServerLinkCode = normalizePrivateServerLinkCode(linkCode)

    if self.SelectedPrivateServerLinkCode then
        print("[LyraMacro] Private server link code configured.")
    else
        print("[LyraMacro] Private server link code cleared.")
    end

    return self.SelectedPrivateServerLinkCode
end

function LyraMacro:SetPrivateServerStatusProvider(provider)
    assert(
        provider == nil or type(provider) == "function",
        "[LyraMacro] Private server status provider must be a function or nil."
    )

    self.PrivateServerStatusProvider = provider
end

local function isReplicatedPrivateServerMarker(value)
    if value == true then
        return true
    end

    if type(value) == "string" then
        local normalized = normalizeLookupKey(value)
        return normalized == "true" or normalized == "private" or normalized == "vip"
    end

    return false
end

function LyraMacro:IsPrivateServer()
    if type(self.PrivateServerStatusProvider) == "function" then
        local checked, isPrivate = pcall(self.PrivateServerStatusProvider)

        if checked then
            return isPrivate == true
        end

        warn("[LyraMacro] Private server status provider failed: " .. tostring(isPrivate))
        return false
    end

    for _, root in ipairs({ LocalPlayer, ReplicatedStorage, workspace }) do
        for _, markerName in ipairs(PRIVATE_SERVER_MARKER_NAMES) do
            if isReplicatedPrivateServerMarker(readAttribute(root, markerName)) then
                return true
            end

            local marker = safeFindFirstChild(root, markerName)

            if marker and isReplicatedPrivateServerMarker(readInstanceValue(marker)) then
                return true
            end
        end
    end

    return false
end

function LyraMacro:ShouldUsePrivateServerWorkflow()
    if type(self.SelectedPrivateServerLinkCode) == "string" and self.SelectedPrivateServerLinkCode ~= "" then
        return true, "configured privateServerLinkCode"
    end

    if self:IsPrivateServer() then
        return true, "replicated private-server status"
    end

    return false, "private-server status is unavailable and no privateServerLinkCode is configured"
end

function LyraMacro:GameInfo(mapName, privateServerLinkCodeOrOptions, maybeOptions)
    local options
    local privateServerLinkCode

    if type(privateServerLinkCodeOrOptions) == "table" then
        options = privateServerLinkCodeOrOptions
        privateServerLinkCode = options.PrivateServerLinkCode
    else
        privateServerLinkCode = privateServerLinkCodeOrOptions
        options = type(maybeOptions) == "table" and maybeOptions or {}

        if privateServerLinkCode == nil then
            privateServerLinkCode = options.PrivateServerLinkCode
        end
    end

    local normalizedMapName = normalizeMapCandidate(mapName) or tostring(mapName or "")
    self.SelectedMap = normalizedMapName
    self.LastDetectedMapSource = options.Source or "manual"
    self:SetPrivateServerLinkCode(privateServerLinkCode)
    print("[LyraMacro] Match configured for map: " .. normalizedMapName)
end

-- Clears only this strategy's stable tower IDs for a fresh solo match.
function LyraMacro:RemoveIndex()
    table.clear(self.SpawnedTowers)
    table.clear(self.SpawnedTowerUpgradeLevels)
    table.clear(self.KnownTowerTroops)
    table.clear(self.KnownTowerUpgradeLevels)
    table.clear(self.CallOfArmsTowerCache)
    self.NextTowerIndex = 0
    print("[LyraMacro] Tower tracking reset.")
end

function LyraMacro:Ready()
    print("[LyraMacro] Strategy match starting.")
end

local function getTeleportQueueFunction()
    if type(queue_on_teleport) == "function" then
        return queue_on_teleport
    end

    if type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
        return syn.queue_on_teleport
    end

    return nil
end

local function getTextChatMessageStatusName(message)
    local gotStatus, status = pcall(function()
        return message and message.Status
    end)

    if not gotStatus or status == nil then
        return nil
    end

    local gotName, name = pcall(function()
        return status.Name
    end)

    if gotName and type(name) == "string" then
        return name
    end

    local statusText = tostring(status)
    return statusText:match("%.([%w_]+)$") or statusText
end

local function getTextChatMessageId(message)
    local gotMessageId, messageId = pcall(function()
        return message and message.MessageId
    end)

    if gotMessageId and type(messageId) == "string" and messageId ~= "" then
        return messageId
    end

    return nil
end

local function getTextChatMessageMetadata(message)
    local gotMetadata, metadata = pcall(function()
        return message and message.Metadata
    end)

    return gotMetadata and type(metadata) == "string" and metadata or ""
end

local function isTextChatMessageFromLocalPlayer(message)
    local gotTextSource, textSource = pcall(function()
        return message and message.TextSource
    end)

    if not gotTextSource or not textSource then
        return nil
    end

    local gotUserId, userId = pcall(function()
        return textSource.UserId
    end)

    return gotUserId and userId == LocalPlayer.UserId
end

local function isFloodcheckedChatMessage(message, statusName)
    if statusName == "Floodchecked" then
        return true
    end

    return normalizeLookupKey(getTextChatMessageMetadata(message)):find("floodchecked", 1, true) ~= nil
end

local function textChannelCanSendForLocalPlayer(channel)
    for _, source in ipairs(safeGetChildren(channel)) do
        if instanceIsA(source, "TextSource") then
            local gotUserId, userId = pcall(function()
                return source.UserId
            end)

            if gotUserId and userId == LocalPlayer.UserId then
                local gotCanSend, canSend = pcall(function()
                    return source.CanSend
                end)

                return not gotCanSend or canSend ~= false
            end
        end
    end

    return nil
end

local function getTextChatChannelCandidates(textChatService)
    local candidates = {}
    local seen = {}

    local function addCandidate(channel, requireConfirmedSendable)
        if not instanceIsA(channel, "TextChannel") or seen[channel] then
            return
        end

        local canSend = textChannelCanSendForLocalPlayer(channel)

        if canSend == false or (requireConfirmedSendable and canSend ~= true) then
            return
        end

        seen[channel] = true
        table.insert(candidates, channel)
    end

    local textChannels = safeFindFirstChild(textChatService, "TextChannels")

    if textChannels then
        addCandidate(safeFindFirstChild(textChannels, "RBXGeneral"), false)
        addCandidate(safeFindFirstChild(textChannels, "General"), false)
    end

    local inputBarConfiguration = safeFindFirstChild(textChatService, "ChatInputBarConfiguration")
    local gotTargetChannel, targetChannel = pcall(function()
        return inputBarConfiguration and inputBarConfiguration.TargetTextChannel
    end)

    if gotTargetChannel then
        addCandidate(targetChannel, false)
    end

    if textChannels then
        for _, channel in ipairs(safeGetChildren(textChannels)) do
            addCandidate(channel, true)
        end
    end

    return candidates
end

function LyraMacro:_getPrivateChatFloodcheckRemaining()
    return math.max(0, (tonumber(self._chatFloodcheckedUntil) or 0) - os.clock())
end

function LyraMacro:_markPrivateChatFloodchecked(source)
    local now = os.clock()

    if now - (tonumber(self._lastChatFloodcheckAt) or -math.huge) > 0.25 then
        self._chatFloodcheckCount = math.min((tonumber(self._chatFloodcheckCount) or 0) + 1, 8)
    end

    self._lastChatFloodcheckAt = now

    local cooldown = math.min(
        PRIVATE_SERVER_FLOODCHECK_BASE_COOLDOWN * (2 ^ math.max(0, self._chatFloodcheckCount - 1)),
        PRIVATE_SERVER_FLOODCHECK_MAX_COOLDOWN
    )
    self._chatFloodcheckedUntil = math.max(tonumber(self._chatFloodcheckedUntil) or 0, now + cooldown)

    warn(
        "[LyraMacro] Roblox chat floodchecked "
            .. tostring(self._lastPrivateServerCommand or "a private-server command")
            .. "; pausing !refresh for "
            .. tostring(cooldown)
            .. " seconds ("
            .. tostring(source or "TextChatMessageStatus")
            .. ")."
    )

    return cooldown
end

function LyraMacro:_clearPrivateChatFloodcheck(messageId)
    if messageId and self._lastPrivateServerMessageId and messageId ~= self._lastPrivateServerMessageId then
        return
    end

    self._chatFloodcheckCount = 0
    self._chatFloodcheckedUntil = 0
end

function LyraMacro:_ensurePrivateChatStatusObserver()
    local textChatService
    pcall(function()
        textChatService = game:GetService("TextChatService")
    end)

    if not textChatService or self._chatStatusConnection then
        return textChatService
    end

    local connected, connection = pcall(function()
        return textChatService.MessageReceived:Connect(function(message)
            local statusName = getTextChatMessageStatusName(message)
            local messageId = getTextChatMessageId(message)
            local fromLocalPlayer = isTextChatMessageFromLocalPlayer(message)

            if fromLocalPlayer == true and messageId then
                self._chatMessageResults[messageId] = statusName
            end

            if isFloodcheckedChatMessage(message, statusName) then
                self:_markPrivateChatFloodchecked("Roblox.MessageStatus.Warning.Floodchecked")
            elseif statusName == "Success" and fromLocalPlayer == true then
                self:_clearPrivateChatFloodcheck(messageId)
            end
        end)
    end)

    if connected then
        self._chatStatusConnection = connection
    end

    return textChatService
end

function LyraMacro:_waitForPrivateChatStatus(message, floodcheckAtBeforeSend)
    local messageId = getTextChatMessageId(message)
    local deadline = os.clock() + PRIVATE_SERVER_CHAT_STATUS_TIMEOUT

    while os.clock() < deadline do
        local statusName = getTextChatMessageStatusName(message)
        local observedStatus = messageId and self._chatMessageResults[messageId]

        if observedStatus and observedStatus ~= "Sending" then
            return observedStatus
        end

        if statusName and statusName ~= "Sending" then
            return statusName
        end

        if (tonumber(self._lastChatFloodcheckAt) or -math.huge) > floodcheckAtBeforeSend then
            return "Floodchecked"
        end

        task.wait(0.05)
    end

    return getTextChatMessageStatusName(message) or "Sending"
end

function LyraMacro:_sendPrivateServerCommand(command, options)
    options = type(options) == "table" and options or {}
    local privateWorkflowEnabled, privateWorkflowReason = self:ShouldUsePrivateServerWorkflow()

    if not privateWorkflowEnabled then
        return false, "Private-server commands are disabled: " .. tostring(privateWorkflowReason) .. "."
    end

    if type(command) ~= "string" or command == "" then
        return false, "A chat command is required."
    end

    local floodcheckRemaining = self:_getPrivateChatFloodcheckRemaining()

    if floodcheckRemaining > 0 and options.IgnoreFloodcheckCooldown ~= true then
        return false,
            "Roblox chat is floodchecked; retry in " .. string.format("%.1f", floodcheckRemaining) .. " seconds.",
            "Floodchecked"
    end

    local textChatService = self:_ensurePrivateChatStatusObserver()

    local sendFailures = {}

    if textChatService then
        for _, channel in ipairs(getTextChatChannelCandidates(textChatService)) do
            table.clear(self._chatMessageResults)
            self._lastPrivateServerCommand = command
            self._lastPrivateServerMessageId = nil
            local floodcheckAtBeforeSend = tonumber(self._lastChatFloodcheckAt) or -math.huge
            local sent, messageOrError = pcall(function()
                return channel:SendAsync(command)
            end)

            if sent then
                local messageId = getTextChatMessageId(messageOrError)
                self._lastPrivateServerMessageId = messageId
                local statusName = self:_waitForPrivateChatStatus(messageOrError, floodcheckAtBeforeSend)

                if statusName == "Success" then
                    self:_clearPrivateChatFloodcheck(messageId)
                    return true, "TextChatService/" .. tostring(getInstanceName(channel) or "TextChannel"), statusName
                end

                if statusName == "Sending" then
                    if options.RequireFinalStatus == true then
                        return false,
                            tostring(getInstanceName(channel) or "TextChannel") .. " did not return a final message status.",
                            statusName
                    end

                    return true, "TextChatService/" .. tostring(getInstanceName(channel) or "TextChannel"), statusName
                end

                if statusName == "Floodchecked" then
                    if (tonumber(self._lastChatFloodcheckAt) or -math.huge) <= floodcheckAtBeforeSend then
                        self:_markPrivateChatFloodchecked("TextChatMessageStatus.Floodchecked")
                    end

                    return false, "Roblox chat floodchecked " .. command .. ".", statusName
                end

                table.insert(
                    sendFailures,
                    tostring(getInstanceName(channel) or "TextChannel") .. " returned " .. tostring(statusName or "no message status")
                )
            else
                table.insert(
                    sendFailures,
                    tostring(getInstanceName(channel) or "TextChannel") .. " failed: " .. tostring(messageOrError)
                )

                if normalizeLookupKey(messageOrError):find("floodcheck", 1, true) then
                    self:_markPrivateChatFloodchecked("TextChannel:SendAsync error")
                    return false, "Roblox chat floodchecked " .. command .. ".", "Floodchecked"
                end
            end
        end
    end

    local legacyChat = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    local sayMessageRequest = legacyChat and legacyChat:FindFirstChild("SayMessageRequest")

    if sayMessageRequest and instanceIsA(sayMessageRequest, "RemoteEvent") then
        local sent, sendError = pcall(function()
            sayMessageRequest:FireServer(command, "All")
        end)

        if sent then
            return true, "legacy chat", "Unknown"
        end

        table.insert(sendFailures, "legacy chat failed: " .. tostring(sendError))
    end

    if #sendFailures > 0 then
        return false, table.concat(sendFailures, "; ")
    end

    return false, "No sendable Roblox chat channel is available."
end

function LyraMacro:_startPrivateServerElevator()
    local deadline = os.clock() + PRIVATE_SERVER_START_TIMEOUT
    local attempt = 0
    local lastError = "No !start attempt was made."

    while game.PlaceId == LOBBY_PLACE_ID and os.clock() < deadline do
        attempt += 1
        print("[LyraMacro] Sending !start attempt #" .. tostring(attempt) .. ".")

        local started, startMessage, statusName = self:_sendPrivateServerCommand("!start", {
            IgnoreFloodcheckCooldown = true,
            RequireFinalStatus = true,
        })

        if started then
            return true, startMessage, attempt
        end

        lastError = startMessage
        local retryDelay = PRIVATE_SERVER_START_RETRY_INTERVAL

        if statusName == "Floodchecked" then
            retryDelay = math.max(retryDelay, self:_getPrivateChatFloodcheckRemaining())
        end

        local timeRemaining = deadline - os.clock()

        if timeRemaining <= 0 then
            break
        end

        task.wait(math.min(retryDelay, timeRemaining))
    end

    return false, lastError, attempt
end

local function getElevatorMapTitle(elevator)
    if getValueKind(elevator) ~= "Instance" then
        return nil
    end

    local gotTitle, title = pcall(function()
        local state = elevator:FindFirstChild("State")
        local map = state and state:FindFirstChild("Map")
        local mapTitle = map and map:FindFirstChild("Title")

        if not mapTitle then
            return nil
        end

        if mapTitle:IsA("ValueBase") then
            return tostring(mapTitle.Value)
        end

        return tostring(mapTitle.Text)
    end)

    if gotTitle and type(title) == "string" and trimString(title) ~= "" then
        return trimString(title)
    end

    return nil
end

function LyraMacro:FindElevatorForMap(mapName)
    local targetMapKey = normalizeLookupKey(mapName)

    if targetMapKey == "" then
        return nil, "A map name is required to select an elevator."
    end

    local elevators = workspace:FindFirstChild("Elevators")

    if not elevators then
        return nil, "workspace.Elevators is not available."
    end

    local elevatorChildren = safeGetChildren(elevators)

    for _, elevator in ipairs(elevatorChildren) do
        local elevatorMapTitle = getElevatorMapTitle(elevator)

        if elevatorMapTitle and normalizeLookupKey(elevatorMapTitle) == targetMapKey then
            return elevator, elevatorMapTitle
        end
    end

    return nil,
        "No elevator currently has map "
            .. tostring(mapName)
            .. " after checking "
            .. tostring(#elevatorChildren)
            .. " elevators."
end

function LyraMacro:EnterElevatorForMap(mapName, options)
    options = options or {}

    if game.PlaceId ~= LOBBY_PLACE_ID then
        return false, "Elevators can only be entered from lobby place " .. tostring(LOBBY_PLACE_ID) .. "."
    end

    local elevator = options.Elevator
    local elevatorMapTitle

    if elevator then
        elevatorMapTitle = getElevatorMapTitle(elevator)

        local elevators = workspace:FindFirstChild("Elevators")
        local belongsToElevators = false

        if elevators then
            local checkedParent, isDescendant = pcall(function()
                return elevator:IsDescendantOf(elevators)
            end)
            belongsToElevators = checkedParent and isDescendant
        end

        if not belongsToElevators or normalizeLookupKey(elevatorMapTitle) ~= normalizeLookupKey(mapName) then
            return false, "The selected elevator no longer has map " .. tostring(mapName) .. "."
        end
    else
        elevator, elevatorMapTitle = self:FindElevatorForMap(mapName)
    end

    if not elevator then
        return false, elevatorMapTitle
    end

    local character = LocalPlayer.Character

    if not character then
        return false, "The local character is not available for elevator entry."
    end

    local lift = elevator:FindFirstChild("Lift")
    local liftMain = lift and lift:FindFirstChild("Main")
    local touch = elevator:FindFirstChild("Touch")

    if options.TeleportImmediately == true then
        -- Match the lobby controller's order: touch first, server entry second,
        -- then move into Lift.Main only after the server accepts the request.
        local destination = touch or liftMain

        if destination then
            local movedImmediately, moveError = pcall(function()
                local heightOffset = destination == touch and 3 or 5
                character:PivotTo(destination.CFrame + Vector3.new(0, heightOffset, 0))
            end)

            if not movedImmediately then
                return false, "Could not teleport into elevator for " .. tostring(elevatorMapTitle) .. ": " .. tostring(moveError)
            end

            if destination == touch then
                task.wait()
            end
        end
    end

    if options.UseTouch ~= false then
        if not touch then
            return false, "The selected elevator is missing its Touch part."
        end

        local movedToTouch, moveError = pcall(function()
            character:PivotTo(touch.CFrame + Vector3.new(0, 3, 0))
        end)

        if not movedToTouch then
            return false, "Could not move to elevator for " .. tostring(elevatorMapTitle) .. ": " .. tostring(moveError)
        end

        -- Preserve the game controller's normal touch-first behavior for manual entry.
        task.wait(0.35)

        if self.AutoRecordTeleportArmed then
            return true, elevatorMapTitle
        end
    end

    local args = {
        "Elevators",
        "Enter",
        elevator,
    }
    local invoked, acceptedOrError = pcall(function()
        return RemoteFunction:InvokeServer(unpack(args))
    end)

    if not invoked then
        return false, "Could not enter elevator for " .. tostring(elevatorMapTitle) .. ": " .. tostring(acceptedOrError)
    end

    if acceptedOrError ~= true then
        return false, "The elevator server rejected entry for " .. tostring(elevatorMapTitle) .. "."
    end

    if liftMain then
        pcall(function()
            character:PivotTo(liftMain.CFrame + Vector3.new(0, 5, 0))
        end)
    end

    return true, elevatorMapTitle
end

function LyraMacro:_autoEnterPendingReplay(replay)
    task.spawn(function()
        local lastRefreshAt = -math.huge
        local lastRefreshError
        local lastEntryAttemptAt = -math.huge
        local lastEntryError
        local lockedElevator
        local announcedPrivateWorkflow = false

        while self.PendingElevatorReplay == replay and game.PlaceId == LOBBY_PLACE_ID and not self.AutoRecordTeleportArmed do
            local privateServer, privateServerReason = self:ShouldUsePrivateServerWorkflow()

            if privateServer and not announcedPrivateWorkflow then
                announcedPrivateWorkflow = true
                print("[LyraMacro] Private server elevator workflow enabled by " .. tostring(privateServerReason) .. ".")
            end

            local elevator = lockedElevator

            if elevator and normalizeLookupKey(getElevatorMapTitle(elevator)) ~= normalizeLookupKey(replay.TargetMap) then
                elevator = nil
                lockedElevator = nil
            end

            if not elevator then
                elevator = self:FindElevatorForMap(replay.TargetMap)
            end

            local refreshDue = not elevator
                and privateServer
                and os.clock() - lastRefreshAt >= PRIVATE_SERVER_REFRESH_INTERVAL
                and self:_getPrivateChatFloodcheckRemaining() <= 0

            if refreshDue then
                -- Close the small race where a refreshed map appears immediately
                -- before the next command would otherwise refresh past it.
                elevator = self:FindElevatorForMap(replay.TargetMap)
                refreshDue = not elevator
            end

            if elevator then
                lockedElevator = elevator
            end

            if refreshDue then
                lastRefreshAt = os.clock()

                local refreshed, refreshMessage = self:_sendPrivateServerCommand("!refresh")

                if refreshed then
                    print(
                        "[LyraMacro] Sent !refresh via "
                            .. tostring(refreshMessage)
                            .. " while waiting for "
                            .. tostring(replay.TargetMap)
                            .. "."
                    )
                    lastRefreshError = nil
                elseif refreshMessage ~= lastRefreshError then
                    warn("[LyraMacro] Could not send private-server refresh: " .. tostring(refreshMessage))
                    lastRefreshError = refreshMessage
                end
            end

            local entered = false
            local elevatorMapTitle

            if lockedElevator and os.clock() - lastEntryAttemptAt >= PRIVATE_SERVER_ENTRY_RETRY_INTERVAL then
                lastEntryAttemptAt = os.clock()

                -- Avoid the lobby Touch controller here: its wrapper misbinds the raw
                -- RemoteFunction and errors before the normal server entry is reached.
                entered, elevatorMapTitle = self:EnterElevatorForMap(replay.TargetMap, {
                    Elevator = lockedElevator,
                    TeleportImmediately = true,
                    UseTouch = false,
                })

                if entered then
                    lastEntryError = nil
                else
                    if elevatorMapTitle ~= lastEntryError then
                        warn("[LyraMacro] Elevator entry retry: " .. tostring(elevatorMapTitle))
                        lastEntryError = elevatorMapTitle
                    end

                    if normalizeLookupKey(getElevatorMapTitle(lockedElevator)) ~= normalizeLookupKey(replay.TargetMap) then
                        lockedElevator = nil
                    end
                end
            end

            if entered then
                print("[LyraMacro] Entered elevator for " .. tostring(elevatorMapTitle) .. ".")

                if privateServer then
                    print("[LyraMacro] Elevator entry confirmed; sending !start now.")
                    local started, startMessage, startAttempts = self:_startPrivateServerElevator()

                    if started then
                        print(
                            "[LyraMacro] Sent !start via "
                                .. tostring(startMessage)
                                .. " immediately after elevator entry (attempt "
                                .. tostring(startAttempts)
                                .. ")."
                        )
                    else
                        warn(
                            "[LyraMacro] Could not confirm private-server !start after "
                                .. tostring(startAttempts)
                                .. " attempts: "
                                .. tostring(startMessage)
                        )
                    end
                end

                return
            end

            task.wait(privateServer and PRIVATE_SERVER_ELEVATOR_POLL_INTERVAL or 1)
        end
    end)
end

function LyraMacro:_getAutoRecordTeleportSource(mapTitle)
    local libraryUrl = self.AutoRecordLibraryUrl or DEFAULT_MACRO_LIBRARY_URL
    local timeout = math.max(10, math.floor(tonumber(self.AutoRecordTimeout) or 45))
    local lines = {
        "if game.PlaceId ~= " .. tostring(MATCH_PLACE_ID) .. " then",
        "    warn(\"[LyraMacro] Auto-record skipped: this is not the match place.\")",
        "    return",
        "end",
        "",
        "local hasSharedEnvironment = type(getgenv) == \"function\"",
        "if hasSharedEnvironment then",
        "    getgenv().LyraMacroAutoUI = false",
    }

    if mapTitle then
        table.insert(lines, "    getgenv().LyraMacroMapName = " .. formatLuaValue(mapTitle))
    end

    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local loaded, LyraMacro = pcall(function()")
    table.insert(lines, "    return loadstring(game:HttpGet(" .. formatLuaValue(getCacheBustedUrlPrefix(libraryUrl)) .. " .. tostring(os.time())))()")
    table.insert(lines, "end)")
    table.insert(lines, "")
    table.insert(lines, "if not loaded then")
    table.insert(lines, "    warn(\"[LyraMacro] Auto-record bootstrap failed: \" .. tostring(LyraMacro))")
    table.insert(lines, "    return")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "task.spawn(function()")
    table.insert(lines, "    local started, message = LyraMacro:StartRecordingWhenMapReady({ Timeout = " .. tostring(timeout) .. " })")
    table.insert(lines, "    if not started then")
    table.insert(lines, "        warn(\"[LyraMacro] Auto-record was not started: \" .. tostring(message))")
    table.insert(lines, "        return")
    table.insert(lines, "    end")
    table.insert(lines, "    LyraMacro:CreateRecorderWindow()")
    table.insert(lines, "end)")

    return table.concat(lines, "\n")
end

function LyraMacro:_queueAutoRecordAfterTeleport(mapTitle)
    local queueTeleport = getTeleportQueueFunction()

    if not queueTeleport then
        return false, "Your executor does not expose queue_on_teleport, so recording cannot continue into the match server."
    end

    local queued, queueError = pcall(queueTeleport, self:_getAutoRecordTeleportSource(mapTitle))

    if not queued then
        return false, "Could not queue auto-recording: " .. tostring(queueError)
    end

    self.AutoRecordTeleportArmed = true
    self.LastDetectedElevator = mapTitle
    print("[LyraMacro] Elevator map detected: " .. tostring(mapTitle) .. ". Auto-recording is queued for the match server.")

    return true, mapTitle
end

function LyraMacro:_getStrategyReplayTeleportSource(replay, mapTitle)
    local libraryUrl = replay.LibraryUrl or DEFAULT_MACRO_LIBRARY_URL
    local timeout = math.max(10, math.floor(tonumber(replay.Timeout) or 45))
    local lines = {
        "if game.PlaceId ~= " .. tostring(MATCH_PLACE_ID) .. " then",
        "    warn(\"[LyraMacro] Strategy replay skipped: this is not the match place.\")",
        "    return",
        "end",
        "",
        "local hasSharedEnvironment = type(getgenv) == \"function\"",
        "if hasSharedEnvironment then",
        "    getgenv().LyraMacroAutoUI = false",
    }

    if mapTitle then
        table.insert(lines, "    getgenv().LyraMacroMapName = " .. formatLuaValue(mapTitle))
    end

    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local loaded, LyraMacro = pcall(function()")
    table.insert(lines, "    return loadstring(game:HttpGet(" .. formatLuaValue(getCacheBustedUrlPrefix(libraryUrl)) .. " .. tostring(os.time())))()")
    table.insert(lines, "end)")
    table.insert(lines, "")
    table.insert(lines, "if not loaded then")
    table.insert(lines, "    warn(\"[LyraMacro] Strategy replay bootstrap failed: \" .. tostring(LyraMacro))")
    table.insert(lines, "    return")
    table.insert(lines, "end")
    table.insert(lines, "")

    appendRecordedStrategyLines(lines, replay.Strategy)
    table.insert(lines, "")
    table.insert(lines, "local completed, message = LyraMacro:RunWhenMapReady(Strategy, " .. formatLuaValue(replay.ExpectedFingerprint) .. ", { Timeout = " .. tostring(timeout) .. " })")
    table.insert(lines, "if not completed then")
    table.insert(lines, "    warn(\"[LyraMacro] Strategy replay was not started: \" .. tostring(message))")
    table.insert(lines, "end")
    table.insert(lines, "return Strategy")

    return table.concat(lines, "\n")
end

function LyraMacro:_queueStrategyReplayAfterTeleport(replay, mapTitle)
    local queueTeleport = getTeleportQueueFunction()

    if not queueTeleport then
        return false, "Your executor does not expose queue_on_teleport, so strategy replay cannot continue into the match server."
    end

    local queued, queueError = pcall(queueTeleport, self:_getStrategyReplayTeleportSource(replay, mapTitle))

    if not queued then
        return false, "Could not queue strategy replay: " .. tostring(queueError)
    end

    self.AutoRecordTeleportArmed = true
    self.LastDetectedElevator = mapTitle
    self.PendingElevatorReplay = nil
    print("[LyraMacro] Elevator map detected: " .. tostring(mapTitle) .. ". Strategy replay is queued for the match server.")

    return true, mapTitle
end

function LyraMacro:_observeElevatorEnter(args)
    if game.PlaceId ~= LOBBY_PLACE_ID then
        return
    end

    if (not self.AutoRecordOnTeleport and not self.PendingElevatorReplay) or self.AutoRecordTeleportArmed then
        return
    end

    if normalizeLookupKey(args[1]) ~= "elevators" or normalizeLookupKey(args[2]) ~= "enter" then
        return
    end

    local mapTitle = getElevatorMapTitle(args[3])

    if not mapTitle then
        warn("[LyraMacro] Elevator entered, but State.Map.Title was not available.")
        return
    end

    self:_setDetectedMap(mapTitle, "elevator", true)

    if self.PendingElevatorReplay then
        local queued, queueMessage = self:_queueStrategyReplayAfterTeleport(self.PendingElevatorReplay, mapTitle)

        if not queued then
            warn("[LyraMacro] " .. queueMessage)
        end

        return
    end

    local queued, queueMessage = self:_queueAutoRecordAfterTeleport(mapTitle)

    if not queued then
        warn("[LyraMacro] " .. queueMessage)
    end
end

function LyraMacro:QueueStrategyAfterElevator(strategy, expectedFingerprint, options)
    options = options or {}

    if game.PlaceId ~= LOBBY_PLACE_ID then
        return false, "Strategy replay can only be queued in lobby place " .. tostring(LOBBY_PLACE_ID) .. "."
    end

    if type(strategy) ~= "table" then
        return false, "Strategy replay requires a table of recorded steps."
    end

    local loadoutReady, loadoutMessage = self:PrepareStrategyLoadout(strategy, options)

    if not loadoutReady then
        return false, loadoutMessage
    end

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        return false, recorderMessage
    end

    local targetMap = normalizeMapCandidate(options.MapName or self.SelectedMap)
    self.PendingElevatorReplay = {
        Strategy = cloneStrategy(strategy),
        ExpectedFingerprint = type(expectedFingerprint) == "string" and expectedFingerprint or nil,
        LibraryUrl = options.LibraryUrl,
        Timeout = options.Timeout or self.AutoRecordTimeout,
        TargetMap = targetMap,
    }
    self.AutoRecordTeleportArmed = false

    if targetMap and options.AutoEnter ~= false then
        self:_autoEnterPendingReplay(self.PendingElevatorReplay)
        print("[LyraMacro] Strategy replay armed. Waiting for an elevator with map " .. targetMap .. ".")
        return true, "Waiting to enter the elevator for " .. targetMap .. "."
    end

    print("[LyraMacro] Strategy replay armed. Enter the elevator for the recorded map to continue after teleport.")

    return true, "Enter the elevator for the recorded map to queue strategy replay."
end

function LyraMacro:SetAutoRecordOnTeleport(enabled, options)
    options = options or {}
    enabled = enabled == true

    if enabled and game.PlaceId ~= LOBBY_PLACE_ID then
        return false, "Elevator auto-recording can only be armed in lobby place " .. tostring(LOBBY_PLACE_ID) .. "."
    end

    self.AutoRecordOnTeleport = enabled
    self.AutoRecordTeleportArmed = false
    self.LastDetectedElevator = nil

    if type(options.LibraryUrl) == "string" and options.LibraryUrl ~= "" then
        self.AutoRecordLibraryUrl = options.LibraryUrl
    end

    if tonumber(options.Timeout) then
        self.AutoRecordTimeout = math.max(10, math.floor(tonumber(options.Timeout)))
    end

    if not enabled then
        print("[LyraMacro] Elevator auto-recording disabled.")
        return true, "Elevator auto-recording disabled."
    end

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        self.AutoRecordOnTeleport = false
        return false, recorderMessage
    end

    print("[LyraMacro] Elevator auto-recording enabled. Enter an elevator to queue the recorder for the selected map.")
    return true, "Enter an elevator to queue recording for its selected map."
end

function LyraMacro:StartRecordingWhenMapReady(options)
    options = options or {}

    if self.IsRecording then
        return true, "Recording is already active."
    end

    local timeout = math.max(1, tonumber(options.Timeout) or self.AutoRecordTimeout or 45)
    local pollInterval = math.max(0.1, tonumber(options.PollInterval) or 0.25)
    local settleTime = math.max(0, tonumber(options.SettleTime) or 1)
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        local fingerprint = self:DetectMapFingerprint({ Force = true, Silent = true })

        if fingerprint then
            if settleTime > 0 then
                task.wait(settleTime)
            end

            return self:StartRecording()
        end

        task.wait(pollInterval)
    end

    return false, "Timed out waiting for the destination map to load."
end

function LyraMacro:RunWhenMapReady(strategy, expectedFingerprint, options)
    options = options or {}

    if game.PlaceId ~= MATCH_PLACE_ID then
        return false, "Strategy replay must run in match place " .. tostring(MATCH_PLACE_ID) .. "."
    end

    if type(strategy) ~= "table" then
        return false, "Strategy replay requires a table of recorded steps."
    end

    local timeout = math.max(1, tonumber(options.Timeout) or self.AutoRecordTimeout or 45)
    local pollInterval = math.max(0.1, tonumber(options.PollInterval) or 0.25)
    local settleTime = math.max(0, tonumber(options.SettleTime) or 1)
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        local fingerprint = self:DetectMapFingerprint({ Force = true, Silent = true })

        if fingerprint then
            if settleTime > 0 then
                task.wait(settleTime)
            end

            local skipMapCheck = type(getgenv) == "function" and getgenv().LyraMacroSkipMapCheck == true

            if type(expectedFingerprint) == "string" and expectedFingerprint ~= "" and not skipMapCheck then
                local matches = self:AssertMapFingerprint(expectedFingerprint, { Silent = true, WarnOnly = true })

                if not matches then
                    return false, "The destination map does not match this recorded strategy."
                end
            end

            local ran, runError = pcall(function()
                self:Run(strategy)
            end)

            if not ran then
                return false, runError
            end

            return true
        end

        task.wait(pollInterval)
    end

    return false, "Timed out waiting for the destination map to load."
end

function LyraMacro:_setDetectedMap(mapName, source, force)
    local normalizedMapName = normalizeMapCandidate(mapName)

    if not normalizedMapName then
        return nil
    end

    if self.SelectedMap ~= "" and self.SelectedMap ~= normalizedMapName and self.LastDetectedMapSource == "manual" and not force then
        return self.SelectedMap, self.LastDetectedMapSource
    end

    if self.SelectedMap == normalizedMapName and self.LastDetectedMapSource then
        return self.SelectedMap, self.LastDetectedMapSource
    end

    self.SelectedMap = normalizedMapName
    self.LastDetectedMapSource = source or "detected"
    print("[LyraMacro] Detected map: " .. normalizedMapName .. " (" .. self.LastDetectedMapSource .. ")")

    return self.SelectedMap, self.LastDetectedMapSource
end

function LyraMacro:DetectMap(options)
    options = options or {}

    if self.SelectedMap ~= "" and not options.Force then
        return self.SelectedMap, self.LastDetectedMapSource or "configured"
    end

    if type(getgenv) == "function" then
        local override = normalizeMapCandidate(getgenv().LyraMacroMapName)

        if override then
            return self:_setDetectedMap(override, "manual override", true)
        end
    end

    local roots = {
        { Root = workspace, Name = "workspace" },
        { Root = ReplicatedStorage, Name = "ReplicatedStorage" },
    }

    local gotPlayerGui, playerGui = pcall(function()
        return LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 1)
    end)

    if gotPlayerGui and playerGui then
        table.insert(roots, { Root = playerGui, Name = "PlayerGui" })
    end

    local gotCoreGui, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)

    if gotCoreGui and coreGui then
        table.insert(roots, { Root = coreGui, Name = "CoreGui" })
    end

    for _, rootInfo in ipairs(roots) do
        local mapName, source = detectMapFromRoot(rootInfo.Root, rootInfo.Name)

        if mapName then
            return self:_setDetectedMap(mapName, source, true)
        end
    end

    if not options.Silent then
        warn("[LyraMacro] Could not detect the map name. Set getgenv().LyraMacroMapName before loading LyraMacroLib to force it.")
    end

    return nil, "not found"
end

function LyraMacro:DetectMapFingerprint(options)
    options = options or {}

    if self.SelectedMapFingerprint ~= "" and not options.Force then
        return self.SelectedMapFingerprint, self.SelectedMapFingerprintSource, self.SelectedMapFingerprintPartCount
    end

    local fingerprint, source, partCount = buildMapFingerprint()

    if not fingerprint then
        if not options.Silent then
            warn("[LyraMacro] Could not build a map fingerprint from workspace.")
        end

        return nil, source or "not found", partCount or 0
    end

    self.SelectedMapFingerprint = fingerprint
    self.SelectedMapFingerprintSource = source
    self.SelectedMapFingerprintPartCount = partCount

    print("[LyraMacro] Map fingerprint: " .. fingerprint .. " (" .. tostring(source) .. ", " .. tostring(partCount) .. " parts)")

    return fingerprint, source, partCount
end

function LyraMacro:AssertMapFingerprint(expectedFingerprint, options)
    options = options or {}

    if type(expectedFingerprint) ~= "string" or expectedFingerprint == "" then
        return true
    end

    if game.PlaceId == LOBBY_PLACE_ID then
        self.PendingLegacyReplayFingerprint = expectedFingerprint
        print("[LyraMacro] Strategy fingerprint check deferred until the elevator teleports to the match.")
        return true, nil, "lobby deferred"
    end

    local currentFingerprint, source = self:DetectMapFingerprint({ Force = true, Silent = options.Silent })

    if currentFingerprint == expectedFingerprint then
        return true, currentFingerprint, source
    end

    local message = "[LyraMacro] Current map fingerprint does not match this recorded strategy. Expected "
        .. tostring(expectedFingerprint)
        .. ", got "
        .. tostring(currentFingerprint)
        .. "."

    if options.WarnOnly then
        warn(message)
        return false, currentFingerprint, source
    end

    error(message, 2)
end

function LyraMacro:_appendRecordedStep(step)
    table.insert(self.RecordedStrategy, step)
    print("[LyraMacro] Recorded step #" .. #self.RecordedStrategy .. ": " .. step.action)
end

function LyraMacro:_bindRecordedTower(pendingPlacement, tower)
    if not pendingPlacement or pendingPlacement.Resolved or not tower then
        return nil
    end

    local existingIndex = self.RecordedTowerIndexes[tower]

    if existingIndex and existingIndex ~= pendingPlacement.TowerIndex then
        return nil
    end

    pendingPlacement.Resolved = true
    self.RecordedTowerIndexes[tower] = pendingPlacement.TowerIndex
    self.RecordedTowerUpgradeLevels[tower] = 0
    self.KnownTowerUpgradeLevels[tower] = 0

    if type(pendingPlacement.TroopType) == "string" and pendingPlacement.TroopType ~= "" then
        self.KnownTowerTroops[tower] = pendingPlacement.TroopType
    end

    for index = #self.PendingRecordedPlacements, 1, -1 do
        if self.PendingRecordedPlacements[index] == pendingPlacement then
            table.remove(self.PendingRecordedPlacements, index)
            break
        end
    end

    print("[LyraMacro] Recorded tower #" .. tostring(pendingPlacement.TowerIndex) .. " bound to its placement.")
    return pendingPlacement.TowerIndex
end

function LyraMacro:_trackNextRecordedTower(troopType, position, existingTowers, matchedTower)
    self.NextRecordedTowerIndex += 1

    local towerIndex = self.NextRecordedTowerIndex
    local towersFolder = getTowersFolder()
    local pendingPlacement = {
        TowerIndex = towerIndex,
        TroopType = troopType,
        Position = position,
        TowersFolder = towersFolder,
        ExistingTowers = existingTowers or {},
        Resolved = false,
    }
    table.insert(self.PendingRecordedPlacements, pendingPlacement)

    local immediateTower = matchedTower or findNewTowerCandidate(towersFolder, existingTowers, position)

    if immediateTower then
        self:_bindRecordedTower(pendingPlacement, immediateTower)
        return towerIndex
    end

    task.spawn(function()
        local tower = waitForNewTowerCandidate(towersFolder, existingTowers, position)

        if not self.IsRecording or pendingPlacement.Resolved then
            return
        end

        if not tower then
            warn("[LyraMacro] Could not match recorded placement #" .. tostring(towerIndex) .. " to a local tower.")
            return
        end

        self:_bindRecordedTower(pendingPlacement, tower)
    end)

    return towerIndex
end

function LyraMacro:_prepareChainCOAObservation(args)
    if not self.ChainCOAEnabled then
        return nil
    end

    if normalizeLookupKey(args[1]) ~= "troops" then
        return nil
    end

    local actionKey = normalizeLookupKey(args[2])

    if actionKey == "place" then
        local placementInfo = type(args[4]) == "table" and args[4] or {}
        local placementOptions = type(args[5]) == "table" and args[5] or {}
        local troopType = args[3]

        if not isCallOfArmsIdentifier(troopType) then
            troopType = placementOptions.Type or placementOptions.Name
        end

        if not isCallOfArmsIdentifier(troopType) then
            return nil
        end

        local towersFolder = getTowersFolder()

        return {
            Kind = "place",
            Token = self._chainCOAToken,
            TroopType = tostring(troopType),
            Position = placementInfo.Position or args[6],
            TowersFolder = towersFolder,
            ExistingTowers = copyTowerSnapshot(self.ChainCOASeenTowers),
        }
    end

    if actionKey == "upgrade" and normalizeLookupKey(args[3]) == "set" then
        local upgradeInfo = type(args[4]) == "table" and args[4] or {}
        local tower = upgradeInfo.Troop

        if not tower then
            return nil
        end

        local knownTroopType = self.KnownTowerTroops[tower]

        if not isCallOfArmsIdentifier(knownTroopType) and not isCallOfArmsTower(tower, knownTroopType) then
            return nil
        end

        return {
            Kind = "upgrade",
            Token = self._chainCOAToken,
            Tower = tower,
        }
    end

    if actionKey == "sell" then
        local sellInfo = type(args[3]) == "table" and args[3] or {}

        return {
            Kind = "sell",
            Token = self._chainCOAToken,
            Tower = sellInfo.Troop,
        }
    end

    return nil
end

function LyraMacro:_completeChainCOAObservation(observation, remoteResults)
    if not observation or observation.Token ~= self._chainCOAToken then
        return
    end

    local response = remoteResults and remoteResults[1]

    if remoteResponseWasRejected(response) then
        return
    end

    if observation.Kind == "place" then
        local tower = waitForNewTowerCandidate(
            observation.TowersFolder,
            observation.ExistingTowers,
            observation.Position,
            nil,
            REPLAY_CONFIRM_TIMEOUT
        )

        if not tower or observation.Token ~= self._chainCOAToken then
            return
        end

        self.ChainCOASeenTowers[tower] = true
        self.KnownTowerTroops[tower] = observation.TroopType
        self.KnownTowerUpgradeLevels[tower] = getTowerUpgradeLevel(tower) or 0
        self.CallOfArmsTowerCache[tower] = nil
        print(
            "[LyraMacro] Chain COA linked "
                .. tostring(getInstanceName(tower) or "tower")
                .. " skin to "
                .. tostring(observation.TroopType)
                .. "."
        )
        return
    end

    local tower = observation.Tower

    if not tower then
        return
    end

    if observation.Kind == "sell" then
        if tower.Parent == nil or remoteResponseWasAccepted(response) then
            self.KnownTowerTroops[tower] = nil
            self.KnownTowerUpgradeLevels[tower] = nil
            self.CallOfArmsTowerCache[tower] = nil
        end
        return
    end

    local replicatedLevel = getTowerUpgradeLevel(tower)
    local previousLevel = tonumber(self.KnownTowerUpgradeLevels[tower]) or 0
    local accepted = remoteResponseWasAccepted(response)
        or (replicatedLevel and replicatedLevel > previousLevel)

    if accepted then
        self.KnownTowerUpgradeLevels[tower] = replicatedLevel or (previousLevel + 1)
        print(
            "[LyraMacro] Chain COA tracked commander upgrade "
                .. tostring(self.KnownTowerUpgradeLevels[tower])
                .. "."
        )
    end
end

function LyraMacro:_getRecordedTowerIndex(tower)
    if not tower then
        return nil
    end

    local towerIndex = self.RecordedTowerIndexes[tower]

    if not towerIndex and isDirectTowerChild(tower, getTowersFolder()) then
        local closestPending
        local closestDistance

        for _, pendingPlacement in ipairs(self.PendingRecordedPlacements) do
            if not pendingPlacement.Resolved and not pendingPlacement.ExistingTowers[tower] then
                local distance = getTowerDistanceFrom(tower, pendingPlacement.Position)
                local comparisonDistance = distance or (REPLAY_PLACEMENT_MATCH_RADIUS * 2)

                if not closestDistance or comparisonDistance < closestDistance then
                    closestPending = pendingPlacement
                    closestDistance = comparisonDistance
                end
            end
        end

        if closestPending then
            towerIndex = self:_bindRecordedTower(closestPending, tower)
        end
    end

    if not towerIndex then
        warn("[LyraMacro] Could not bind a tower action to any successful recorded placement.")
    end

    return towerIndex
end

function LyraMacro:_recordRemoteInvoke(args, remoteResults)
    if not self.IsRecording then
        return
    end

    if remoteResults and remoteResponseWasRejected(remoteResults[1]) then
        print("[LyraMacro] Ignored a rejected remote action while recording.")
        return
    end

    local category = args[1]
    local action = args[2]
    local categoryKey = normalizeLookupKey(category)
    local actionKey = normalizeLookupKey(action)
    local remoteMapName, remoteMapSource = detectMapFromRemoteArgs(args)

    if remoteMapName then
        self:_setDetectedMap(remoteMapName, remoteMapSource, false)
    end

    if categoryKey == "waves" and actionKey == "skip" then
        self:_appendRecordedStep({
            action = "skip",
        })
        return
    end

    if categoryKey == "difficulty" and actionKey == "vote" then
        local modeName = args[3]

        if type(modeName) ~= "string" then
            warn("[LyraMacro] Ignored difficulty vote because no mode name was found.")
            return
        end

        self.SelectedMode = modeName
        self:_appendRecordedStep({
            action = "mode",
            mode = modeName,
            confirmed = args[4],
        })
        return
    end

    if categoryKey ~= "troops" then
        return
    end

    if actionKey == "abilities" and normalizeLookupKey(args[3]) == "activate" then
        local abilityInfo = args[4] or {}
        local abilityName = TRACKED_ABILITIES[normalizeLookupKey(abilityInfo.Name)]

        if not abilityName then
            return
        end

        local towerIndex = self:_getRecordedTowerIndex(abilityInfo.Troop)

        if towerIndex then
            self:_appendRecordedStep({
                action = "ability",
                tower = towerIndex,
                ability = abilityName,
            })
        end

        return
    end

    if action == "Place" then
        local placementInfo = args[4] or {}
        local placementOptions = type(args[5]) == "table" and args[5] or {}
        local troopType = placementOptions.Type or args[3]
        local skin = placementOptions.Skin
        local position = placementInfo.Position or args[6]

        if type(troopType) ~= "string" or troopType == "" then
            warn("[LyraMacro] Ignored place action because no troop type was found.")
            return
        end

        if getValueKind(position) ~= "Vector3" then
            warn("[LyraMacro] Ignored place action because no Vector3 position was found.")
            return
        end

        if type(skin) ~= "string" or skin == "" then
            skin = "Default"
        end

        local towersFolder = getTowersFolder()
        local existingTowers = copyTowerSnapshot(self.RecordingSeenTowers)
        local placedTower = waitForNewTowerCandidate(
            towersFolder,
            existingTowers,
            position,
            nil,
            RECORD_PLACEMENT_CONFIRM_TIMEOUT
        )

        if not placedTower then
            warn("[LyraMacro] Ignored a place remote because the server did not create a new tower.")
            return
        end

        self.RecordingSeenTowers[placedTower] = true

        self:_appendRecordedStep({
            action = "place",
            troop = troopType,
            skin = skin,
            x = roundNumber(position.X),
            y = roundNumber(position.Y),
            z = roundNumber(position.Z),
            rotation = placementInfo.Rotation,
        })
        self:_trackNextRecordedTower(troopType, position, existingTowers, placedTower)
    elseif action == "Upgrade" and args[3] == "Set" then
        local upgradeInfo = args[4] or {}
        local towerIndex = self:_getRecordedTowerIndex(upgradeInfo.Troop)

        if towerIndex then
            local recordedLevel = (tonumber(self.RecordedTowerUpgradeLevels[upgradeInfo.Troop]) or 0) + 1
            self.RecordedTowerUpgradeLevels[upgradeInfo.Troop] = recordedLevel
            self.KnownTowerUpgradeLevels[upgradeInfo.Troop] = recordedLevel
            self:_appendRecordedStep({
                action = "upgrade",
                tower = towerIndex,
                level = recordedLevel,
            })
        end
    elseif action == "Sell" then
        local sellInfo = args[3] or {}
        local towerIndex = self:_getRecordedTowerIndex(sellInfo.Troop)

        if towerIndex then
            self:_appendRecordedStep({
                action = "sell",
                tower = towerIndex,
            })
        end
    end
end

function LyraMacro:_processRemoteObservation(args, remoteResults)
    local categoryKey = normalizeLookupKey(args[1])
    local actionKey = normalizeLookupKey(args[2])
    local chainObservation = self:_prepareChainCOAObservation(args)

    -- Queue teleport continuation only after the elevator server confirms entry.
    if categoryKey == "elevators" and actionKey == "enter" and remoteResults[1] == true then
        self:_observeElevatorEnter(args)
    end

    self:_completeChainCOAObservation(chainObservation, remoteResults)

    if self.ChainCOAEnabled and categoryKey == "troops" and actionKey == "place" then
        for tower in pairs(snapshotTowers(getTowersFolder())) do
            self.ChainCOASeenTowers[tower] = true
        end
    end

    local recorded, recordError = pcall(function()
        self:_recordRemoteInvoke(args, remoteResults)
    end)

    if not recorded then
        warn("[LyraMacro] Failed to record remote call: " .. tostring(recordError))
    end
end

function LyraMacro:_queueRemoteObservation(args, remoteResults)
    table.insert(self._remoteObservationQueue, {
        Args = args,
        Results = remoteResults,
    })

    if self._remoteObservationWorkerRunning then
        return
    end

    self._remoteObservationWorkerRunning = true
    task.defer(function()
        while #self._remoteObservationQueue > 0 do
            local observation = table.remove(self._remoteObservationQueue, 1)
            local processed, processError = pcall(function()
                self:_processRemoteObservation(observation.Args, observation.Results)
            end)

            if not processed then
                warn("[LyraMacro] Failed to process a remote observation: " .. tostring(processError))
            end
        end

        self._remoteObservationWorkerRunning = false
    end)
end

function LyraMacro:_installRecorder()
    if self._recordHookInstalled then
        return true
    end

    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        return false, "Your executor does not expose hookmetamethod/getnamecallmethod, so remote recording is unavailable."
    end

    local oldNamecall
    local recorderNamecall = function(remote, ...)
        local method = getnamecallmethod()

        if method ~= "InvokeServer" or remote ~= RemoteFunction then
            return oldNamecall(remote, ...)
        end

        -- Do not run Instance namecalls before forwarding this call. Some executors
        -- leak nested namecall state and can otherwise dispatch the wrong method.
        local args = table.pack(...)
        local remoteResults = table.pack(oldNamecall(remote, ...))
        self:_queueRemoteObservation(args, remoteResults)

        return table.unpack(remoteResults, 1, remoteResults.n)
    end

    if type(newcclosure) == "function" then
        recorderNamecall = newcclosure(recorderNamecall)
    end

    oldNamecall = hookmetamethod(game, "__namecall", recorderNamecall)
    self._originalNamecall = oldNamecall
    self._recordHookInstalled = true

    return true
end

function LyraMacro:_watchForMatchResults(watchToken)
    task.spawn(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 30)
        local gameGui = playerGui and (playerGui:FindFirstChild("GameGui") or playerGui:WaitForChild("GameGui", 60))
        local results = gameGui and (gameGui:FindFirstChild("Results") or gameGui:WaitForChild("Results", 60))

        if not results then
            return
        end

        if self._resultsWatchToken ~= watchToken or not self.IsRecording then
            return
        end

        local function finishRecording()
            if self._resultsWatchToken ~= watchToken or not self.IsRecording then
                return
            end

            if self.ChainCOAEnabled then
                self:SetChainCOA(false)
            end

            print("[LyraMacro] Results are visible. Stopping and exporting the recorded strategy.")
            self:StopRecording()
        end

        if results.Visible then
            finishRecording()
            return
        end

        local connection
        connection = results:GetPropertyChangedSignal("Visible"):Connect(function()
            if results.Visible then
                if connection then
                    connection:Disconnect()
                end

                finishRecording()
            end
        end)

        table.insert(self.RecordingConnections, connection)
    end)
end

function LyraMacro:StartRecording()
    if self.IsRecording then
        return true, "Recording is already active."
    end

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        warn("[LyraMacro] " .. recorderMessage)
        return false, recorderMessage
    end

    table.clear(self.RecordedStrategy)
    table.clear(self.RecordedTowerIndexes)
    table.clear(self.RecordedTowerUpgradeLevels)
    table.clear(self.PendingRecordedPlacements)
    self.RecordingSeenTowers = snapshotTowers(getTowersFolder())
    table.clear(self.RecordingConnections)
    self.NextRecordedTowerIndex = 0
    self.SelectedMapFingerprint = ""
    self.SelectedMapFingerprintSource = nil
    self.SelectedMapFingerprintPartCount = 0

    if self.LastDetectedMapSource ~= "manual" and self.LastDetectedMapSource ~= "manual override" then
        self.SelectedMap = ""
        self.LastDetectedMapSource = nil
    end

    self.IsRecording = true
    self._resultsWatchToken += 1
    self:DetectMap({ Silent = true })
    self:DetectMapFingerprint({ Silent = true, Force = true })
    self:_watchForMatchResults(self._resultsWatchToken)

    print("[LyraMacro] Strategy recording started.")
    return true
end

function LyraMacro:StopRecording()
    if not self.IsRecording then
        return self:GetRecordedStrategy(), self:GetRecordedStrategyScriptSource(), self.LastStrategyExport
    end

    self.IsRecording = false
    self._resultsWatchToken += 1

    for _, connection in ipairs(self.RecordingConnections) do
        connection:Disconnect()
    end

    table.clear(self.RecordingConnections)
    table.clear(self.PendingRecordedPlacements)
    table.clear(self.RecordingSeenTowers)

    if self.SelectedMap == "" then
        self:DetectMap({ Silent = true })
    end

    self:DetectMapFingerprint({ Silent = true, Force = true })

    local recordedStrategy = self:GetRecordedStrategy()
    local actionCounts = {
        ability = 0,
        mode = 0,
        place = 0,
        sell = 0,
        skip = 0,
        upgrade = 0,
    }
    local upgradesMissingLevel = 0

    for _, step in ipairs(recordedStrategy) do
        if actionCounts[step.action] ~= nil then
            actionCounts[step.action] += 1
        end

        if step.action == "upgrade" and type(step.level) ~= "number" then
            upgradesMissingLevel += 1
        end
    end

    local exportResult = self:SaveRecordedStrategy()
    local strategySource = exportResult.Source

    print("[LyraMacro] Strategy recording stopped. Recorded " .. #recordedStrategy .. " steps.")
    print(
        "[LyraMacro] Recorder integrity: "
            .. tostring(actionCounts.place)
            .. " placements, "
            .. tostring(actionCounts.upgrade)
            .. " upgrades, "
            .. tostring(actionCounts.sell)
            .. " sells, "
            .. tostring(actionCounts.ability)
            .. " abilities, "
            .. tostring(actionCounts.skip)
            .. " skips, "
            .. tostring(actionCounts.mode)
            .. " mode votes."
    )

    if upgradesMissingLevel > 0 then
        warn(
            "[LyraMacro] Recorder integrity warning: "
                .. tostring(upgradesMissingLevel)
                .. " upgrade actions are missing levels."
        )
    end

    print(strategySource)

    if exportResult.Saved then
        print("[LyraMacro] Saved recorded strategy to " .. exportResult.Path)
    else
        warn("[LyraMacro] " .. exportResult.Message)
    end

    if type(setclipboard) == "function" then
        pcall(setclipboard, strategySource)
    end

    return recordedStrategy, strategySource, exportResult
end

function LyraMacro:GetRecordedStrategy()
    return cloneStrategy(self.RecordedStrategy)
end

function LyraMacro:GetRecordedStrategySource()
    local lines = {}
    appendRecordedStrategyLines(lines, self.RecordedStrategy)
    return table.concat(lines, "\n")
end

function LyraMacro:GetRecordedStrategyScriptSource(options)
    options = options or {}

    local macroLibraryUrl = options.LibraryUrl or DEFAULT_MACRO_LIBRARY_URL
    local lines = {
        "-- Generated by Lyra Strategy Recorder.",
        "-- Execute this file to replay the recorded strategy.",
        "",
        "local previousAutoUI",
        "local hasSharedEnvironment = type(getgenv) == \"function\"",
        "",
        "if hasSharedEnvironment then",
        "    previousAutoUI = getgenv().LyraMacroAutoUI",
        "    getgenv().LyraMacroAutoUI = false",
        "end",
        "",
        "local loadedMacro, LyraMacro = pcall(function()",
        "    return loadstring(game:HttpGet(" .. formatLuaValue(getCacheBustedUrlPrefix(macroLibraryUrl)) .. " .. tostring(os.time())))()",
        "end)",
        "",
        "if hasSharedEnvironment then",
        "    getgenv().LyraMacroAutoUI = previousAutoUI",
        "end",
        "",
        "assert(loadedMacro, LyraMacro)",
        "",
    }

    if type(self.SelectedMap) == "string" and self.SelectedMap ~= "" then
        local gameInfoOptions = "{ Source = " .. formatLuaValue(self.LastDetectedMapSource or "recorded") .. " }"

        if type(self.SelectedPrivateServerLinkCode) == "string" and self.SelectedPrivateServerLinkCode ~= "" then
            table.insert(lines, "LyraMacro:GameInfo(" .. formatLuaValue(self.SelectedMap) .. ", " .. formatLuaValue(self.SelectedPrivateServerLinkCode) .. ", " .. gameInfoOptions .. ")")
        else
            table.insert(lines, "LyraMacro:GameInfo(" .. formatLuaValue(self.SelectedMap) .. ", " .. gameInfoOptions .. ")")
        end

        table.insert(lines, "")
    end

    if type(self.SelectedMapFingerprint) == "string" and self.SelectedMapFingerprint ~= "" then
        table.insert(lines, "local RecordedMapFingerprint = " .. formatLuaValue(self.SelectedMapFingerprint))
    else
        table.insert(lines, "local RecordedMapFingerprint = nil")
    end

    appendRecordedStrategyLines(lines, self.RecordedStrategy)
    table.insert(lines, "")
    appendLoadoutLines(lines, self:GetRecordedLoadout())
    table.insert(lines, "")
    table.insert(lines, "if game.PlaceId == " .. tostring(LOBBY_PLACE_ID) .. " then")
    table.insert(lines, "    local queued, message = LyraMacro:QueueStrategyAfterElevator(Strategy, RecordedMapFingerprint, { LibraryUrl = " .. formatLuaValue(macroLibraryUrl) .. ", Loadout = StrategyLoadout })")
    table.insert(lines, "    assert(queued, message)")
    table.insert(lines, "    return Strategy")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local completed, message = LyraMacro:RunWhenMapReady(Strategy, RecordedMapFingerprint)")
    table.insert(lines, "assert(completed, message)")
    table.insert(lines, "return Strategy")

    return table.concat(lines, "\n")
end

function LyraMacro:SaveRecordedStrategy(options)
    options = options or {}

    local scriptSource = self:GetRecordedStrategyScriptSource(options)
    local folder = options.Folder

    if folder == nil then
        folder = DEFAULT_STRATEGY_FOLDER
    end

    local fileName = options.FileName

    if type(fileName) ~= "string" or fileName == "" then
        local mapPart = ""

        if type(self.SelectedMap) == "string" and self.SelectedMap ~= "" then
            mapPart = "_" .. sanitizeFileName(self.SelectedMap)
        elseif type(self.SelectedMapFingerprint) == "string" and self.SelectedMapFingerprint ~= "" then
            mapPart = "_MapFingerprint_" .. sanitizeFileName(self.SelectedMapFingerprint)
        end

        fileName = "LyraRecordedStrategy" .. mapPart .. "_" .. getRecordingTimestamp() .. ".lua"
    else
        fileName = sanitizeFileName(fileName)

        if fileName:lower():sub(-4) ~= ".lua" then
            fileName = fileName .. ".lua"
        end
    end

    local filePath = joinFilePath(folder, fileName)
    local result = {
        Saved = false,
        Path = filePath,
        Source = scriptSource,
        Message = "writefile is unavailable; copied runnable strategy to clipboard instead.",
    }

    if type(writefile) ~= "function" then
        self.LastStrategyExport = result
        return result
    end

    if type(folder) == "string" and folder ~= "" and type(makefolder) == "function" then
        pcall(makefolder, folder)
    end

    local wrote, writeError = pcall(writefile, filePath, scriptSource)

    if not wrote and type(folder) == "string" and folder ~= "" then
        filePath = fileName
        wrote, writeError = pcall(writefile, filePath, scriptSource)
    end

    result.Path = filePath

    if wrote then
        result.Saved = true
        result.Message = "Saved runnable strategy to " .. filePath
    else
        result.Message = "failed to save strategy file: " .. tostring(writeError)
    end

    self.LastStrategyExport = result
    return result
end

function LyraMacro:_loadLyraUI(libraryUrl)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is unavailable in this environment."
    end

    local fetched, source = pcall(function()
        return game:HttpGet(libraryUrl)
    end)

    if not fetched or type(source) ~= "string" or source == "" then
        return nil, "failed to fetch LyraV2.lua: " .. tostring(source)
    end

    source = stripByteOrderMark(source)

    local chunk, compileError = loadstring(source)

    if not chunk then
        return nil, "failed to compile LyraV2.lua: " .. tostring(compileError)
    end

    local loaded, result = pcall(chunk)

    if not loaded or not result then
        return nil, "failed to run LyraV2.lua: " .. tostring(result)
    end

    return result
end

function LyraMacro:_createFallbackRecorderWindow(reason)
    local parent = game:GetService("CoreGui")
    local parentReady = pcall(function()
        return parent.Name
    end)

    if not parentReady then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local existing = parent:FindFirstChild("LyraMacroRecorder")

    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LyraMacroRecorder"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "RecorderFrame"
    frame.Size = UDim2.new(0, 280, 0, 120)
    frame.Position = UDim2.new(0, 18, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Lyra Strategy Recorder"
    title.TextColor3 = Color3.fromRGB(245, 245, 250)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -20, 0, 34)
    status.Position = UDim2.new(0, 10, 0, 36)
    status.BackgroundTransparency = 1
    status.Text = reason and ("Fallback UI: " .. tostring(reason)) or "Ready to record."
    status.TextColor3 = Color3.fromRGB(170, 170, 180)
    status.TextSize = 11
    status.Font = Enum.Font.Gotham
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "RecordButton"
    button.Size = UDim2.new(1, -20, 0, 34)
    button.Position = UDim2.new(0, 10, 1, -44)
    button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    button.BorderSizePixel = 0
    button.Text = "Record Strategy"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
    button.Font = Enum.Font.GothamMedium
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button

    local isRecording = false

    button.MouseButton1Click:Connect(function()
        if isRecording then
            local recordedStrategy, _, exportResult = self:StopRecording()
            isRecording = false
            button.Text = "Record Strategy"
            button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            status.Text = "Recorded " .. tostring(#recordedStrategy) .. " steps. " .. (exportResult and exportResult.Message or "Strategy copied to clipboard.")
            return
        end

        local started, message = self:StartRecording()

        if not started then
            status.Text = message or "Strategy recording could not be started."
            return
        end

        isRecording = true
        button.Text = "Stop Recording"
        button.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        status.Text = "Recording mode votes, placements, upgrades, sells, and wave skips."
    end)

    self.RecorderWindow = screenGui
    warn("[LyraMacro] Lyra UI failed to load; opened fallback recorder UI instead. " .. tostring(reason))

    return screenGui
end

function LyraMacro:CreateRecorderWindow(config)
    config = config or {}

    if config.PrivateServerLinkCode ~= nil then
        self:SetPrivateServerLinkCode(config.PrivateServerLinkCode)
    end

    if self.RecorderWindow then
        return self.RecorderWindow
    end

    local LyraUI = config.LyraUI

    if not LyraUI then
        local libraryUrl = config.LibraryUrl or getCacheBustedUrlPrefix(DEFAULT_UI_LIBRARY_URL) .. tostring(os.time())
        local loadError

        LyraUI, loadError = self:_loadLyraUI(libraryUrl)

        if not LyraUI and not config.LibraryUrl then
            LyraUI, loadError = self:_loadLyraUI(DEFAULT_UI_LIBRARY_URL)
        end

        if not LyraUI then
            return self:_createFallbackRecorderWindow(loadError)
        end
    end

    local created, windowOrError = pcall(function()
        local window = LyraUI:CreateWindow({
            Name = config.Name or "Lyra Strategy Recorder",
            Subtitle = config.Subtitle or "Macro Tools",
            Icon = config.Icon or "radio-tower",
        })

        local strategyTab = window:CreateTab({
            Name = config.TabName or "Strategy",
            Icon = config.TabIcon or "list-checks",
        })
        local descriptionLabel = strategyTab:CreateLabel("Record mode votes, placements, upgrades, sells, and wave skips.")
        strategyTab:CreateToggle("Auto-record after elevator", self.AutoRecordOnTeleport, function(enabled)
            if not enabled then
                self:SetAutoRecordOnTeleport(false)
                return
            end

            local armed, message = self:SetAutoRecordOnTeleport(true)

            if armed then
                descriptionLabel.UpdateText("Elevator watcher armed. Enter an elevator to record its selected map.")
                window:Notify("Elevator Watcher Armed", message, 4)
                return
            end

            descriptionLabel.UpdateText(message or "Elevator auto-recording could not be enabled.")
            window:Notify("Elevator Watcher Unavailable", message or "Your executor cannot queue scripts across teleports.", 4)
        end)

        strategyTab:CreateTextbox("Private server link code", self.SelectedPrivateServerLinkCode or "Optional privateServerLinkCode", function(linkCode)
            local configuredCode = self:SetPrivateServerLinkCode(linkCode)

            if configuredCode then
                descriptionLabel.UpdateText("Private server link code will be included in the next AutoStrategy export.")
                window:Notify("Private Server Code Set", "The next AutoStrategy will include the configured link code.", 3)
            else
                descriptionLabel.UpdateText("Private server link code cleared. AutoStrategy exports will use the standard format.")
            end
        end)

        strategyTab:CreateToggle("Chain COA", self.ChainCOAEnabled, function(enabled)
            local chained, message = self:SetChainCOA(enabled)

            if chained then
                if enabled then
                    descriptionLabel.UpdateText("Chain COA waits for 3 detected, level 3 commanders, then rotates Call Of Arms every 10.2 seconds.")
                    window:Notify("Chain COA Enabled", message, 4)
                end

                return
            end

            descriptionLabel.UpdateText(message or "Chain COA could not be enabled.")
            window:Notify("Chain COA Unavailable", message or "Start Chain COA from a match.", 4)
        end)


        local isRecording = self.IsRecording
        local recordButton

        task.spawn(function()
            local deadline = os.clock() + (tonumber(config.AutoDetectTimeout) or 60)

            while (not self.RecorderWindow or self.RecorderWindow == window) and os.clock() < deadline do
                local mapName, mapSource = self:DetectMap({ Force = true, Silent = true })

                if mapName then
                    descriptionLabel.UpdateText("Detected map: " .. mapName .. " (" .. tostring(mapSource) .. ")")
                    return
                end

                task.wait(1)
            end
        end)

        strategyTab:CreateButton("Detect Map", function()
            local mapName, mapSource = self:DetectMap({ Force = true, Silent = true })

            if mapName then
                descriptionLabel.UpdateText("Detected map: " .. mapName .. " (" .. tostring(mapSource) .. ")")
                window:Notify("Map Detected", mapName, 3)
                return
            end

            local fingerprint, fingerprintSource, partCount = self:DetectMapFingerprint({ Force = true })

            if fingerprint then
                descriptionLabel.UpdateText("Map fingerprint: " .. fingerprint .. " (" .. tostring(partCount) .. " parts)")
                window:Notify("Map Fingerprinted", tostring(fingerprintSource), 4)
                return
            end

            descriptionLabel.UpdateText("Map not detected. Set getgenv().LyraMacroMapName before loading the recorder.")
            window:Notify("Map Not Detected", "No name or stable fingerprint was found.", 4)
        end)

        recordButton = strategyTab:CreateButton(isRecording and "Stop Recording" or "Record Strategy", function()
            if isRecording then
                local recordedStrategy, _, exportResult = self:StopRecording()
                isRecording = false
                recordButton.UpdateButtonText("Record Strategy")
                descriptionLabel.UpdateText("Recorded " .. tostring(#recordedStrategy) .. " steps. " .. (exportResult and exportResult.Message or "Strategy copied to clipboard."))
                window:Notify("Recording Stopped", exportResult and exportResult.Message or ("Recorded " .. tostring(#recordedStrategy) .. " strategy steps."), 4)
                return
            end

            local started, message = self:StartRecording()

            if not started then
                window:Notify("Recorder Unavailable", message or "Strategy recording could not be started.", 4)
                return
            end

            isRecording = true
            recordButton.UpdateButtonText("Stop Recording")
            descriptionLabel.UpdateText("Recording mode votes, placements, upgrades, sells, and wave skips.")
            window:Notify("Recording Started", "Your strategy actions are now being recorded.", 3)
        end)

        if config.Strategy then
            strategyTab:CreateButton(config.RunButtonText or "Run Demo Strategy", function()
                task.spawn(function()
                    self:Run(config.Strategy)
                end)
            end)
        end

        self.RecorderWindow = window
        window:Notify("Lyra UI Library", "Strategy recorder loaded.", 4)

        return window
    end)

    if not created then
        return self:_createFallbackRecorderWindow(windowOrError)
    end

    return windowOrError
end

function LyraMacro:Place(troopType, x, y, z, rotation, skin)
    local position = Vector3.new(x, y, z)
    rotation = rotation or CFrame.new()
    skin = type(skin) == "string" and skin ~= "" and skin or "Default"
    local towersFolder = getTowersFolder()
    local attempt = 0

    while true do
        attempt += 1
        local existingTowers = snapshotTowers(towersFolder)
        local placementTracker = createPlacementTracker(towersFolder, existingTowers)
        local cash = getCashValue()
        local cashBeforeRequest = cash.Value
        local invoked, responseOrError = pcall(function()
            return RemoteFunction:InvokeServer(
                "Troops",
                "Place",
                troopType,
                {
                    Rotation = rotation,
                    Position = position,
                },
                {
                    Type = troopType,
                    Skin = skin,
                },
                position
            )
        end)

        if invoked then
            trackPlacementResponse(placementTracker, responseOrError)
        end

        if not invoked then
            stopPlacementTracker(placementTracker)
            error("[LyraMacro] Place " .. tostring(troopType) .. " failed: " .. tostring(responseOrError), 2)
        end

        local confirmationTimeout = remoteResponseWasRejected(responseOrError)
            and REPLAY_CONFIRM_POLL_INTERVAL
            or REPLAY_CONFIRM_TIMEOUT
        local placedTower = waitForNewTowerCandidate(
            towersFolder,
            existingTowers,
            position,
            placementTracker.Candidates,
            confirmationTimeout
        )

        local cashAfterRequest = cash.Value
        local requestWasAccepted = remoteResponseWasAccepted(responseOrError)
            or (tonumber(cashAfterRequest) and tonumber(cashBeforeRequest) and cashAfterRequest < cashBeforeRequest)

        if not placedTower and requestWasAccepted then
            print("[LyraMacro] Place " .. tostring(troopType) .. " was accepted; reconciling the replicated tower.")
            placedTower = waitForNewTowerCandidate(
                towersFolder,
                existingTowers,
                position,
                placementTracker.Candidates,
                REPLAY_ACCEPTED_RECOVERY_TIMEOUT
            )
        end

        stopPlacementTracker(placementTracker)

        if placedTower then
            self.NextTowerIndex += 1
            self.SpawnedTowers[self.NextTowerIndex] = placedTower
            self.SpawnedTowerUpgradeLevels[self.NextTowerIndex] = getTowerUpgradeLevel(placedTower) or 0
            self.KnownTowerUpgradeLevels[placedTower] = self.SpawnedTowerUpgradeLevels[self.NextTowerIndex]
            self.KnownTowerTroops[placedTower] = troopType
            print("[LyraMacro] Registered tower #" .. self.NextTowerIndex .. " (" .. tostring(troopType) .. " / " .. skin .. ").")
            return placedTower
        end

        if requestWasAccepted then
            error("[LyraMacro] Place " .. tostring(troopType) .. " was accepted but its new workspace.Towers child did not replicate within " .. tostring(REPLAY_ACCEPTED_RECOVERY_TIMEOUT) .. " seconds. Replay stopped before issuing a duplicate placement.", 2)
        end

        print("[LyraMacro] Place " .. tostring(troopType) .. " is pending (attempt " .. tostring(attempt) .. ", cash " .. tostring(cash.Value) .. "); retrying shortly.")
        waitForCashChange(cash, cash.Value, REPLAY_RETRY_INTERVAL)
    end
end

function LyraMacro:Upgrade(towerIndex, expectedLevel)
    local targetTower = self.SpawnedTowers[towerIndex]
    assert(
        targetTower and targetTower.Parent,
        "[LyraMacro] Cannot upgrade tower #" .. tostring(towerIndex) .. "; it is missing or was sold."
    )

    local targetLevel = tonumber(expectedLevel)
    local attempt = 0

    local function rememberConfirmedLevel(fallbackLevel)
        local replicatedLevel = getTowerUpgradeLevel(targetTower)
        local confirmedLevel = tonumber(replicatedLevel) or tonumber(fallbackLevel)

        if confirmedLevel then
            self.SpawnedTowerUpgradeLevels[towerIndex] = math.max(
                tonumber(self.SpawnedTowerUpgradeLevels[towerIndex]) or 0,
                confirmedLevel
            )
            self.KnownTowerUpgradeLevels[targetTower] = self.SpawnedTowerUpgradeLevels[towerIndex]
        end

        return confirmedLevel
    end

    while true do
        attempt += 1
        local replicatedLevelBeforeRequest = getTowerUpgradeLevel(targetTower)
        local trackedLevelBeforeRequest = tonumber(self.SpawnedTowerUpgradeLevels[towerIndex]) or 0
        local levelBeforeRequest = replicatedLevelBeforeRequest or trackedLevelBeforeRequest
        local maximumLevel, hasKnownMaximumLevel = getTowerMaximumUpgrade(targetTower)

        if replicatedLevelBeforeRequest then
            self.SpawnedTowerUpgradeLevels[towerIndex] = replicatedLevelBeforeRequest
        end

        if targetLevel and levelBeforeRequest and levelBeforeRequest >= targetLevel then
            if levelBeforeRequest == targetLevel then
                print("[LyraMacro] Tower #" .. towerIndex .. " is already at recorded upgrade level " .. tostring(targetLevel) .. ".")
                return
            end

            error("[LyraMacro] Tower #" .. tostring(towerIndex) .. " is already level " .. tostring(levelBeforeRequest) .. ", beyond recorded target level " .. tostring(targetLevel) .. ". Replay stopped to prevent further desync.", 2)
        end

        if not targetLevel
            and hasKnownMaximumLevel
            and replicatedLevelBeforeRequest
            and replicatedLevelBeforeRequest >= maximumLevel then
            print("[LyraMacro] Tower #" .. towerIndex .. " is already fully upgraded; skipping the legacy upgrade step.")
            return
        end

        local cash = getCashValue()
        local cashBeforeRequest = cash.Value
        local invoked, responseOrError = pcall(function()
            return RemoteFunction:InvokeServer(
                "Troops",
                "Upgrade",
                "Set",
                {
                    Troop = targetTower,
                }
            )
        end)

        if not invoked then
            error("[LyraMacro] Upgrade tower #" .. tostring(towerIndex) .. " failed: " .. tostring(responseOrError), 2)
        end

        local function reachedRecordedLevel()
            local currentLevel = getTowerUpgradeLevel(targetTower)

            if targetLevel then
                return currentLevel and currentLevel >= targetLevel
            end

            return currentLevel and currentLevel > levelBeforeRequest
        end

        local cashAfterRequest = cash.Value
        local requestWasAccepted = remoteResponseWasAccepted(responseOrError)
            or (tonumber(cashAfterRequest) and tonumber(cashBeforeRequest) and cashAfterRequest < cashBeforeRequest)

        if requestWasAccepted and replicatedLevelBeforeRequest == nil then
            local confirmedLevel = rememberConfirmedLevel(targetLevel or (levelBeforeRequest + 1))
            print(
                "[LyraMacro] Upgraded tower #"
                    .. tostring(towerIndex)
                    .. " immediately (server-confirmed; tracking level "
                    .. tostring(confirmedLevel or "unknown")
                    .. ")."
            )
            return
        end

        local confirmationTimeout = remoteResponseWasRejected(responseOrError)
            and REPLAY_CONFIRM_POLL_INTERVAL
            or REPLAY_CONFIRM_TIMEOUT
        local upgraded = waitForCondition(confirmationTimeout, reachedRecordedLevel)

        if upgraded then
            rememberConfirmedLevel(targetLevel or (levelBeforeRequest + 1))
            print("[LyraMacro] Upgraded tower #" .. towerIndex .. ".")
            return
        end

        cashAfterRequest = cash.Value
        requestWasAccepted = requestWasAccepted
            or (tonumber(cashAfterRequest) and tonumber(cashBeforeRequest) and cashAfterRequest < cashBeforeRequest)

        if requestWasAccepted then
            if replicatedLevelBeforeRequest == nil then
                local confirmedLevel = rememberConfirmedLevel(targetLevel or (levelBeforeRequest + 1))
                print(
                    "[LyraMacro] Upgraded tower #"
                        .. tostring(towerIndex)
                        .. " (server-confirmed; tracking level "
                        .. tostring(confirmedLevel or "unknown")
                        .. ")."
                )
                return
            end

            print("[LyraMacro] Upgrade tower #" .. tostring(towerIndex) .. " was accepted; reconciling its replicated level.")

            if waitForCondition(REPLAY_ACCEPTED_RECOVERY_TIMEOUT, reachedRecordedLevel) then
                rememberConfirmedLevel(targetLevel or (levelBeforeRequest + 1))
                print("[LyraMacro] Upgraded tower #" .. towerIndex .. ".")
                return
            end

            error("[LyraMacro] Upgrade tower #" .. tostring(towerIndex) .. " was accepted but did not reach recorded level " .. tostring(targetLevel or "next") .. " within " .. tostring(REPLAY_ACCEPTED_RECOVERY_TIMEOUT) .. " seconds. Replay stopped before issuing a duplicate upgrade.", 2)
        end

        print("[LyraMacro] Upgrade tower #" .. towerIndex .. " is pending (attempt " .. tostring(attempt) .. ", cash " .. tostring(cash.Value) .. "); retrying shortly.")
        waitForCashChange(cash, cash.Value, REPLAY_RETRY_INTERVAL)
    end
end

function LyraMacro:Sell(towerIndex)
    local targetTower = self.SpawnedTowers[towerIndex]
    assert(
        targetTower and targetTower.Parent,
        "[LyraMacro] Cannot sell tower #" .. tostring(towerIndex) .. "; it is missing or already sold."
    )

    local attempt = 0

    while targetTower.Parent do
        attempt += 1
        local cash = getCashValue()
        local invoked, responseOrError = pcall(function()
            return RemoteFunction:InvokeServer(
                "Troops",
                "Sell",
                {
                    Troop = targetTower,
                }
            )
        end)

        if not invoked then
            error("[LyraMacro] Sell tower #" .. tostring(towerIndex) .. " failed: " .. tostring(responseOrError), 2)
        end

        local confirmationTimeout = remoteResponseWasRejected(responseOrError)
            and REPLAY_CONFIRM_POLL_INTERVAL
            or REPLAY_CONFIRM_TIMEOUT

        if waitForCondition(confirmationTimeout, function()
            return targetTower.Parent == nil
        end) then
            break
        end

        if remoteResponseWasAccepted(responseOrError) and waitForCondition(REPLAY_ACCEPTED_RECOVERY_TIMEOUT, function()
            return targetTower.Parent == nil
        end) then
            break
        end

        print("[LyraMacro] Sell tower #" .. towerIndex .. " is pending (attempt " .. tostring(attempt) .. "); retrying the same tower reference shortly.")
        waitForCashChange(cash, cash.Value, REPLAY_RETRY_INTERVAL)
    end

    -- Keep IDs stable: selling #1 never changes the ID of tower #2.
    self.SpawnedTowers[towerIndex] = nil
    self.SpawnedTowerUpgradeLevels[towerIndex] = nil
    self.KnownTowerUpgradeLevels[targetTower] = nil
    print("[LyraMacro] Sold tower #" .. towerIndex .. ".")
end

function LyraMacro:SkipWave()
    local invoked, responseOrError = pcall(function()
        return RemoteFunction:InvokeServer("Waves", "Skip")
    end)

    if not invoked or responseOrError == false then
        error("[LyraMacro] Recorded wave skip was rejected: " .. tostring(responseOrError), 2)
    end

    print("[LyraMacro] Skipped wave.")
end

local function makeGuiDraggable(handle, target)
    handle.Active = true

    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    local function updatePosition(input)
        local camera = workspace.CurrentCamera
        local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local delta = input.Position - dragStart
        local targetSize = target.AbsoluteSize
        local minX = math.min(0, viewportSize.X - targetSize.X)
        local maxX = math.max(0, viewportSize.X - targetSize.X)
        local minY = math.min(0, viewportSize.Y - targetSize.Y)
        local maxY = math.max(0, viewportSize.Y - targetSize.Y)
        local nextX = math.clamp(startPosition.X + delta.X, minX, maxX)
        local nextY = math.clamp(startPosition.Y + delta.Y, minY, maxY)

        target.Position = UDim2.fromOffset(
            nextX + target.AnchorPoint.X * targetSize.X,
            nextY + target.AnchorPoint.Y * targetSize.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = target.AbsolutePosition

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            updatePosition(input)
        end
    end)
end

function LyraMacro:CreateStrategyLogger()
    local parent = game:GetService("CoreGui")
    local parentReady = pcall(function()
        return parent.Name
    end)

    if not parentReady then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local existing = parent:FindFirstChild("LyraAutoStrategies")

    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LyraAutoStrategies"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 1000000
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = parent

    local topBanner = Instance.new("Frame")
    topBanner.Name = "TopBanner"
    topBanner.Position = UDim2.fromOffset(0, 0)
    topBanner.Size = UDim2.new(0, 370, 0, 42)
    topBanner.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
    topBanner.BackgroundTransparency = 0
    topBanner.BorderSizePixel = 0
    topBanner.ZIndex = 100000
    topBanner.Parent = screenGui

    local topBannerCorner = Instance.new("UICorner")
    topBannerCorner.CornerRadius = UDim.new(0, 6)
    topBannerCorner.Parent = topBanner

    local topBannerText = Instance.new("TextLabel")
    topBannerText.Size = UDim2.new(1, -24, 1, 0)
    topBannerText.Position = UDim2.new(0, 12, 0, 0)
    topBannerText.BackgroundTransparency = 1
    topBannerText.Text = "LYRA AUTOSTRATEGIES"
    topBannerText.TextColor3 = Color3.fromRGB(240, 244, 255)
    topBannerText.TextSize = 14
    topBannerText.Font = Enum.Font.MontserratBold
    topBannerText.TextXAlignment = Enum.TextXAlignment.Left
    topBannerText.ZIndex = 100001
    topBannerText.Parent = topBanner

    local frame = Instance.new("Frame")
    frame.Name = "ActionLog"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, 0, 0, 52)
    frame.Size = UDim2.new(0, 400, 0, 360)
    frame.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
    frame.BackgroundTransparency = 0.36
    frame.BorderSizePixel = 0
    frame.ZIndex = 1000
    frame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = frame

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundColor3 = Color3.fromRGB(20, 29, 39)
    header.BackgroundTransparency = 0.22
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 1001
    header.Parent = frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 6)
    headerCorner.Parent = header

    local headerText = Instance.new("TextLabel")
    headerText.Size = UDim2.new(1, -20, 1, 0)
    headerText.Position = UDim2.new(0, 10, 0, 0)
    headerText.BackgroundTransparency = 1
    headerText.Text = "LYRA AUTOSTRATEGIES"
    headerText.TextColor3 = Color3.fromRGB(240, 244, 255)
    headerText.TextSize = 14
    headerText.Font = Enum.Font.MontserratBold
    headerText.TextXAlignment = Enum.TextXAlignment.Left
    headerText.ZIndex = 1002
    headerText.Parent = header

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Actions"
    scroll.Position = UDim2.new(0, 8, 0, 44)
    scroll.Size = UDim2.new(1, -16, 1, -52)
    scroll.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
    scroll.BackgroundTransparency = 0.48
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(95, 180, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 1001
    scroll.Parent = frame

    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 5)
    scrollCorner.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = scroll

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)

    makeGuiDraggable(header, frame)

    self.StrategyLogger = {
        Gui = screenGui,
        Frame = frame,
        Header = header,
        TopBanner = topBanner,
        Scroll = scroll,
        Layout = layout,
        Entries = 0,
    }

    return self.StrategyLogger
end

function LyraMacro:LogStrategyAction(message)
    local logger = self.StrategyLogger

    if not logger or not logger.Gui or not logger.Gui.Parent then
        logger = self:CreateStrategyLogger()
    end

    logger.Entries += 1

    local entry = Instance.new("TextLabel")
    entry.Name = "Action" .. tostring(logger.Entries)
    entry.Size = UDim2.new(1, 0, 0, 32)
    entry.BackgroundColor3 = Color3.fromRGB(30, 42, 56)
    entry.BackgroundTransparency = 0.46
    entry.BorderSizePixel = 0
    entry.Text = tostring(logger.Entries) .. ". " .. tostring(message)
    entry.TextColor3 = Color3.fromRGB(232, 239, 250)
    entry.TextSize = 12
    entry.Font = Enum.Font.MontserratBold
    entry.TextWrapped = true
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.TextYAlignment = Enum.TextYAlignment.Center
    entry.LayoutOrder = logger.Entries
    entry.ZIndex = 1002
    entry.Parent = logger.Scroll

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 4)
    entryCorner.Parent = entry

    task.defer(function()
        if logger.Scroll and logger.Scroll.Parent then
            logger.Scroll.CanvasPosition = Vector2.new(0, math.max(0, logger.Layout.AbsoluteContentSize.Y - logger.Scroll.AbsoluteWindowSize.Y + 12))
        end
    end)
end

local function validateStrategyActions(strategy)
    local highestIndex = 0

    for index in pairs(strategy) do
        if type(index) == "number" and index >= 1 and index % 1 == 0 then
            highestIndex = math.max(highestIndex, index)
        end
    end

    for index = 1, highestIndex do
        assert(
            type(strategy[index]) == "table",
            "[LyraMacro] Strategy action #" .. tostring(index) .. " is missing or is not a table. Replay cannot continue across a sparse action queue."
        )
    end

    return highestIndex
end

function LyraMacro:Run(strategy)
    assert(type(strategy) == "table", "[LyraMacro] Strategy must be a table of step tables.")
    local actionCount = validateStrategyActions(strategy)

    if game.PlaceId == LOBBY_PLACE_ID then
        local expectedFingerprint = self.PendingLegacyReplayFingerprint
        self.PendingLegacyReplayFingerprint = nil

        if expectedFingerprint then
            local queued, queueMessage = self:QueueStrategyAfterElevator(strategy, expectedFingerprint)

            if not queued then
                error(queueMessage, 2)
            end

            return
        end

        error("[LyraMacro] Strategy replay must be started from the match, or include a recorded map fingerprint to queue through an elevator.", 2)
    end

    self:RemoveIndex()
    self:Ready()
    self:CreateStrategyLogger()
    self:LogStrategyAction("STRATEGY STARTED - " .. tostring(actionCount) .. " ACTIONS")

    for stepNumber = 1, actionCount do
        local step = strategy[stepNumber]
        local action = step.action
        assert(type(action) == "string", "[LyraMacro] Step " .. stepNumber .. " has no action.")
        local actionDescription = describeStrategyStep(step)
        self:LogStrategyAction(tostring(stepNumber) .. "/" .. tostring(actionCount) .. "  " .. actionDescription)

        local executed, actionError = xpcall(function()
            if action == "skip" then
                self:SkipWave()
            elseif action == "mode" then
                self:VoteMode(step.mode, step.confirmed)
            elseif action == "place" then
                self:Place(step.troop, step.x, step.y, step.z, step.rotation, step.skin)
            elseif action == "upgrade" then
                self:Upgrade(step.tower, step.level)
            elseif action == "sell" then
                self:Sell(step.tower)
            elseif action == "ability" then
                self:ActivateAbility(step.tower, step.ability)
            else
                error("[LyraMacro] Unknown action: " .. action)
            end
        end, debug.traceback)

        if not executed then
            error("[LyraMacro] Strategy step " .. tostring(stepNumber) .. " (" .. actionDescription .. ") failed: " .. tostring(actionError), 0)
        end
    end

    print("[LyraMacro] Strategy completed.")
    self:LogStrategyAction("STRATEGY COMPLETED")
end

local function shouldAutoOpenRecorderWindow()
    if type(getgenv) ~= "function" then
        return true
    end

    return getgenv().LyraMacroAutoUI ~= false
end

if shouldAutoOpenRecorderWindow() then
    task.defer(function()
        local createdWindow, err = pcall(function()
            LyraMacro:CreateRecorderWindow()
        end)

        if not createdWindow then
            warn("[LyraMacro] Failed to open recorder UI: " .. tostring(err))
        end
    end)
end

return LyraMacro
