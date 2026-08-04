--[[
    Lyra Macro & Strategy Library (LyraMacroLib)

    Solo strategy playback confirms each local tower's state before advancing.
    Cash changes are used only to wait for an unaffordable action, never as
    proof that a placement, upgrade, or sell reached the intended tower.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DEFAULT_MACRO_LIBRARY_URL = "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua"
local DEFAULT_UI_LIBRARY_URL = "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraV2.lua"
local DEFAULT_STRATEGY_FOLDER = "LyraStrategies"
local MAP_SCAN_LIMIT = 2500
local LOBBY_PLACE_ID = 113331026373939
local MATCH_PLACE_ID = 133260551256133
-- A user-owned VIP share code is a launcher parameter, not a reserved-server
-- access code. Never pass it to TeleportToPrivateServer/ReservedServerAccessCode.
local PRIVATE_SERVER_RETURN_URL_PREFIX = "https://www.roblox.com/share?code="
local PRIVATE_SERVER_RETURN_URL_SUFFIX = "&type=Server"
local PRIVATE_SERVER_RETURN_DEEP_LINK_PREFIX = "roblox://navigation/share_links?code="
local PRIVATE_SERVER_RETURN_DEEP_LINK_SUFFIX = "&type=Server"
local PRIVATE_SERVER_RETURN_LEGACY_URL_PREFIX = "https://www.roblox.com/games/start?placeId=113331026373939&linkCode="
local PRIVATE_SERVER_RETURN_LEGACY_DEEP_LINK_PREFIX = "roblox://placeId=113331026373939&linkCode="
local PRIVATE_SERVER_LINK_TYPE_SHARE = "share"
local PRIVATE_SERVER_LINK_TYPE_LEGACY = "legacy"
local PRIVATE_SERVER_RETURN_RELAY_MAX_HOPS = 3
local PRIVATE_SERVER_RETURN_RELAY_TTL = 300
local PRIVATE_SERVER_RETURN_PERMISSION_KEY = "__LyraMacroPrivateServerReturnPermissionPrompted"
local PRIVATE_SERVER_RETURN_ROUTE_SETTING = "__LyraMacroPrivateServerReturnRoute"
local ACTIVE_REPLAY_LOCK_KEY = "__LyraMacroActiveReplay"

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
local CHAIN_COA_ACTIVE_DURATION = 6
local CHAIN_COA_HANDOFF_DELAY = 2
local CHAIN_COA_REQUIRED_TOWERS = 3
local CHAIN_COA_MIN_UPGRADE = 2
local CHAIN_COA_RETRY_DELAY = 2
local CHAIN_COA_POLL_INTERVAL = 0.15
local ABILITY_DELAY_FROM_TOWER_PLACEMENT = "tower_placement"
local PRIVATE_SERVER_REFRESH_INTERVAL = 0.5
local PRIVATE_SERVER_ELEVATOR_POLL_INTERVAL = 0.03
local PRIVATE_SERVER_ENTRY_RETRY_INTERVAL = 0.1
local PRIVATE_SERVER_CHAT_STATUS_TIMEOUT = 1
local PRIVATE_SERVER_MARKER_SCAN_INTERVAL = 0.75
local PRIVATE_SERVER_MARKER_SCAN_LIMIT = 96
local PRIVATE_SERVER_MARKER_SCAN_DEPTH = 3
local PRIVATE_SERVER_PUBLIC_SCAN_MAX_PAGES = 20
local PRIVATE_SERVER_PUBLIC_SCAN_RETRY_DELAY = 10
local PRIVATE_SERVER_PUBLIC_SCAN_MAX_RETRY_DELAY = 120
local PRIVATE_SERVER_PUBLIC_SCAN_TIMEOUT = 12
local PRIVATE_SERVER_PUBLIC_ABSENCE_CONFIRMATIONS = 2
local PRIVATE_SERVER_PUBLIC_CONFIRMATION_DELAY = 2
local PRIVATE_SERVER_PUBLIC_MARKER_FALLBACK_DELAY = 3.5
local PRIVATE_SERVER_PUBLIC_SETTLE_TIMEOUT = PRIVATE_SERVER_PUBLIC_SCAN_TIMEOUT * 2
    + PRIVATE_SERVER_PUBLIC_SCAN_RETRY_DELAY
    + 1
local PRIVATE_SERVER_FLOODCHECK_BASE_COOLDOWN = 3
local PRIVATE_SERVER_FLOODCHECK_MAX_COOLDOWN = 30
local PRIVATE_SERVER_START_RETRY_INTERVAL = 0.2
local PRIVATE_SERVER_START_TIMEOUT = 35
local LOBBY_RETURN_MAX_ATTEMPTS = 3
local LOBBY_RETURN_RETRY_DELAY = 2
local LOBBY_RETURN_STATE_TIMEOUT = 10
local LOBBY_RETURN_PENDING_TIMEOUT = 30
local MODE_VOTE_RETRY_INTERVAL = 0.25
local MODE_VOTE_RETRY_TIMEOUT = 10
local RECORD_PLACEMENT_CONFIRM_TIMEOUT = 1
local RECORD_STOP_DRAIN_TIMEOUT = 4
local REPLAY_CONFIRM_TIMEOUT = 3
local REPLAY_ACCEPTED_RECOVERY_TIMEOUT = 8
local REPLAY_CONFIRM_POLL_INTERVAL = 0.05
local REPLAY_RETRY_INTERVAL = 0.75
local REPLAY_PLACEMENT_MATCH_RADIUS = 8
local DEFAULT_MAX_TOWER_UPGRADE = 5
local STRATEGY_PERK_STATUS_ATTEMPTS = 2
local STRATEGY_PERK_STATUS_RETRY_DELAY = 0.15
local STRATEGY_PERK_TOGGLE_SETTLE_TIME = 0.2
local STRATEGY_PERK_TOGGLE_TIMEOUT = 2
local STRATEGY_PERK_TOGGLE_POLL_INTERVAL = 0.1
local STRATEGY_PERK_DEFINITIONS = {
    commando = {
        Tier = "Platinum",
        Troop = "Commando",
        StatusAction = "GetPlatinumPerkStatus",
        ToggleAction = "PlatinumPerks",
    },
    militant = {
        Tier = "Platinum",
        Troop = "Militant",
        StatusAction = "GetPlatinumPerkStatus",
        ToggleAction = "PlatinumPerks",
    },
    sniper = {
        Tier = "Platinum",
        Troop = "Sniper",
        StatusAction = "GetPlatinumPerkStatus",
        ToggleAction = "PlatinumPerks",
    },
    shotgunner = {
        Tier = "Platinum",
        Troop = "Shotgunner",
        StatusAction = "GetPlatinumPerkStatus",
        ToggleAction = "PlatinumPerks",
    },
    minigunner = {
        Tier = "Golden",
        Troop = "Minigunner",
        StatusAction = "GetGoldenPerkStatus",
        ToggleAction = "GoldenPerks",
    },
    soldier = {
        Tier = "Golden",
        Troop = "Soldier",
        StatusAction = "GetGoldenPerkStatus",
        ToggleAction = "GoldenPerks",
    },
    scout = {
        Tier = "Golden",
        Troop = "Scout",
        StatusAction = "GetGoldenPerkStatus",
        ToggleAction = "GoldenPerks",
    },
    pyromancer = {
        Tier = "Golden",
        Troop = "Pyromancer",
        StatusAction = "GetGoldenPerkStatus",
        ToggleAction = "GoldenPerks",
    },
    crookboss = {
        Tier = "Golden",
        Troop = "Crook Boss",
        StatusAction = "GetGoldenPerkStatus",
        ToggleAction = "GoldenPerks",
    },
}
local PRIVATE_SERVER_MARKER_KEYS = {
    isprivateserver = true,
    privateserver = true,
    isvipserver = true,
    vipserver = true,
}

local PRIVATE_SERVER_TYPE_MARKER_KEYS = {
    lobbytype = true,
    serverkind = true,
    servertype = true,
}

local PRIVATE_SERVER_STATE_CONTAINER_KEYS = {
    currentserver = true,
    replicatedstate = true,
    runtimestate = true,
    serverstate = true,
    sessionstate = true,
}

local SERVER_TYPE_DISPLAY_NAMES = {
    nonpublic = "Non-public (Private/Reserved)",
    private = "Private/VIP",
    public = "Public",
    reserved = "Reserved",
    unknown = "Unknown",
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

while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

LocalPlayer:WaitForChild("PlayerGui")

local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local TowersFolder = workspace:FindFirstChild("Towers")

local LyraMacro = {
    SpawnedTowers = {},
    SpawnedTowerPlacedAt = {},
    SpawnedTowerUpgradeLevels = {},
    KnownTowerTroops = {},
    KnownTowerUpgradeLevels = {},
    CallOfArmsTowerCache = {},
    NextTowerIndex = 0,
    SelectedLoadout = {},
    SelectedMode = "Normal",
    SelectedMap = "",
    ManualMapOverrideEnabled = true,
    SelectedPrivateServerLinkCode = nil,
    SelectedPrivateServerLinkType = nil,
    PrivateServerStatusProvider = nil,
    PrivateServerReturnProvider = nil,
    PrivateServerReturnUrl = nil,
    PrivateServerReturnDeepLink = nil,
    PrivateServerReturnPlaceId = nil,
    PrivateServerReturnJobId = nil,
    PrivateServerReturnOriginVerified = false,
    IsRecording = false,
    RecordedStrategy = {},
    RecordedTowerIndexes = {},
    RecordedTowerUpgradeLevels = {},
    RecordedTowerPlacedAt = {},
    RecordedTroopPerks = {},
    PendingRecordedPlacements = {},
    RecordingSeenTowers = {},
    RecordingConnections = {},
    NextRecordedTowerIndex = 0,
    RecordingLastAbilityAt = nil,
    RecordingPerkVerificationError = nil,
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
    ChainCOAActiveDuration = CHAIN_COA_ACTIVE_DURATION,
    ChainCOAHandoffDelay = CHAIN_COA_HANDOFF_DELAY,
    ChainCOARetryDelay = CHAIN_COA_RETRY_DELAY,
    ChainCOANextIndex = 0,
    ChainCOASeenTowers = {},
    _chainCOAInternalAbilityRequests = setmetatable({}, { __mode = "k" }),
    _chainCOAToken = 0,
    _chainCOAConnections = {},
    _resultsWatchToken = 0,
    _strategyResultsWatchToken = 0,
    _strategyResultsConnection = nil,
    _privateServerReturnStarted = false,
    _privateServerReturnToken = 0,
    _privateServerReturnConnections = {},
    _privateServerMarkerLastScanAt = -math.huge,
    _privateServerMarkerContextKey = nil,
    _privateServerMarkerType = nil,
    _privateServerMarkerSource = nil,
    _serverDirectoryContext = nil,
    _chatFloodcheckCount = 0,
    _chatFloodcheckedUntil = 0,
    _chatMessageResults = {},
    _chatStatusConnection = nil,
    _lastChatFloodcheckAt = -math.huge,
    _lastPrivateServerCommand = nil,
    _lastPrivateServerMessageId = nil,
    StrategyLogger = nil,
    _recordHookInstalled = false,
    _recordingSessionToken = 0,
    _recordingStopInProgress = false,
    _originalNamecall = nil,
    _remoteObservationQueue = {},
    _activeRemoteObservation = nil,
    _remoteObservationWorkerRunning = false,
    _replayOwnershipToken = nil,
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

local function normalizeAbilityDelay(value)
    local delay = tonumber(value)

    if not delay or delay ~= delay or delay == math.huge or delay == -math.huge then
        return nil
    end

    return math.max(0, delay)
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
        if step.perk ~= nil then
            table.insert(fields, formatField("perk", step.perk))
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

        local abilityDelay = normalizeAbilityDelay(step.delay)

        if abilityDelay then
            table.insert(fields, formatField("delay", abilityDelay))

            if step.delay_from == ABILITY_DELAY_FROM_TOWER_PLACEMENT then
                table.insert(fields, formatField("delay_from", ABILITY_DELAY_FROM_TOWER_PLACEMENT))
            end
        end
    elseif step.action == "chaincoa" then
        table.insert(fields, formatField("enabled", step.enabled ~= false))
        table.insert(fields, formatField("active_duration", step.active_duration))
        table.insert(fields, formatField("handoff_delay", step.handoff_delay))
        table.insert(fields, formatField("retry_delay", step.retry_delay))
    elseif step.action == "skip" and step.label then
        table.insert(fields, formatField("label", step.label))
    end

    return "{ " .. table.concat(fields, ", ") .. " }"
end

local function describeStrategyStep(step)
    if step.action == "place" then
        local skinSuffix = type(step.skin) == "string" and step.skin ~= "" and " [" .. step.skin .. "]" or ""
        local perkSuffix = type(step.perk) == "string" and " {" .. step.perk .. " perk}"
            or (step.perk == false and " {perk off}" or "")
        return "PLACE " .. tostring(step.troop) .. skinSuffix .. perkSuffix
    elseif step.action == "upgrade" then
        return "UPGRADE TOWER #" .. tostring(step.tower)
    elseif step.action == "sell" then
        return "SELL TOWER #" .. tostring(step.tower)
    elseif step.action == "mode" then
        return "VOTE " .. tostring(step.mode)
    elseif step.action == "skip" then
        return "SKIP WAVE"
    elseif step.action == "ability" then
        local abilityDelay = normalizeAbilityDelay(step.delay)
        local delaySource = step.delay_from == ABILITY_DELAY_FROM_TOWER_PLACEMENT and " from placement" or ""
        local delaySuffix = abilityDelay and " (+" .. formatNumber(abilityDelay) .. "s" .. delaySource .. ")" or ""
        return "ACTIVATE " .. tostring(step.ability) .. " ON TOWER #" .. tostring(step.tower) .. delaySuffix
    elseif step.action == "chaincoa" then
        return (step.enabled == false and "DISABLE" or "ENABLE") .. " CHAIN COA"
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

local function getSharedEnvironment()
    if type(getgenv) ~= "function" then
        return nil
    end

    local available, environment = pcall(getgenv)
    return available and type(environment) == "table" and environment or nil
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

local function getStrategyPerkDefinition(troopName)
    return STRATEGY_PERK_DEFINITIONS[normalizeLookupKey(troopName)]
end

local function normalizeStrategyPerkTier(value)
    local lookupKey = normalizeLookupKey(value)

    if lookupKey == "golden" then
        return "Golden"
    elseif lookupKey == "platinum" then
        return "Platinum"
    end

    return nil
end

local function getStrategyPerkStates(strategy)
    local states = {}
    local statesByTroop = {}

    if type(strategy) ~= "table" then
        return states
    end

    for stepNumber, step in ipairs(strategy) do
        if type(step) ~= "table" then
            return nil, "Strategy step #" .. tostring(stepNumber) .. " is not a table."
        end

        if step.action == "place" then
            local definition = getStrategyPerkDefinition(step.troop)
            local recordedPerk = step.perk

            if recordedPerk ~= nil then
                if not definition then
                    return nil,
                        "Strategy step #"
                            .. tostring(stepNumber)
                            .. " records a perk for unsupported tower "
                            .. tostring(step.troop)
                            .. "."
                end

                local enabled
                local unverified = false

                if recordedPerk == false then
                    enabled = false
                elseif type(recordedPerk) == "string" then
                    local tier = normalizeStrategyPerkTier(recordedPerk)

                    if not tier then
                        if normalizeLookupKey(recordedPerk) == "unverified" then
                            unverified = true
                        else
                            return nil,
                                "Strategy step #"
                                    .. tostring(stepNumber)
                                    .. " has an unknown perk: "
                                    .. tostring(recordedPerk)
                                    .. "."
                        end
                    elseif tier ~= definition.Tier then
                        return nil,
                            tostring(step.troop)
                                .. " cannot use the recorded "
                                .. tostring(tier)
                                .. " perk."
                    else
                        enabled = true
                    end
                else
                    return nil,
                        "Strategy step #"
                            .. tostring(stepNumber)
                            .. " has invalid perk metadata."
                end

                local troopKey = normalizeLookupKey(definition.Troop)
                local existingState = statesByTroop[troopKey]

                if existingState then
                    if not existingState.Unverified and not unverified and existingState.Enabled ~= enabled then
                        return nil,
                            "The strategy records conflicting perk states for "
                                .. tostring(definition.Troop)
                                .. "."
                    elseif existingState.Unverified and not unverified then
                        existingState.Enabled = enabled
                        existingState.Unverified = false
                    end
                else
                    local state = {
                        Definition = definition,
                        Enabled = enabled,
                        Tier = definition.Tier,
                        Troop = definition.Troop,
                        Unverified = unverified,
                    }
                    statesByTroop[troopKey] = state
                    table.insert(states, state)
                end
            end
        end
    end

    return states
end

-- The status remotes report whether a perk is currently enabled. Ownership is
-- checked separately through Inventory.Skins before replay changes this state.
local function queryStrategyPerkStatus(definition)
    local lastError = "The server did not return a Boolean perk status."

    for attempt = 1, STRATEGY_PERK_STATUS_ATTEMPTS do
        local invoked, result = pcall(function()
            return RemoteFunction:InvokeServer("Troops", definition.StatusAction, definition.Troop)
        end)

        if invoked and type(result) == "boolean" then
            return result
        end

        if invoked then
            lastError = "The server returned " .. type(result) .. " instead of a Boolean."
        else
            lastError = tostring(result)
        end

        if attempt < STRATEGY_PERK_STATUS_ATTEMPTS then
            task.wait(STRATEGY_PERK_STATUS_RETRY_DELAY)
        end
    end

    return nil, lastError
end

local function waitForStrategyPerkState(definition, expectedState)
    local deadline = os.clock() + STRATEGY_PERK_TOGGLE_TIMEOUT
    local lastResult

    while os.clock() < deadline do
        local status, statusError = queryStrategyPerkStatus(definition)

        if status == expectedState then
            return true
        end

        lastResult = statusError or status
        task.wait(STRATEGY_PERK_TOGGLE_POLL_INTERVAL)
    end

    return false, lastResult
end

local function getNamedInventoryEntry(inventory, name)
    local wantedKey = normalizeLookupKey(name)

    if type(inventory) ~= "table" or wantedKey == "" then
        return nil
    end

    if inventory[name] ~= nil then
        return inventory[name]
    end

    for entryName, entry in pairs(inventory) do
        if normalizeLookupKey(entryName) == wantedKey then
            return entry
        end
    end

    return nil
end

local function inventoryOwnsTroop(inventory, troopName)
    local entry = getNamedInventoryEntry(inventory, troopName)

    if entry == true then
        return true
    end

    return type(entry) == "table" and entry.Purchased == true
end

local function getCachedStrategyPerkStatus(troopInventory, definition)
    local entry = definition and getNamedInventoryEntry(troopInventory, definition.Troop)

    if type(entry) ~= "table" then
        return nil
    end

    local enabled = entry[definition.ToggleAction]

    if type(enabled) == "boolean" then
        return enabled
    end

    return nil
end

local function inventoryOwnsSkin(skinInventory, troopName, skinName)
    if normalizeLookupKey(skinName) == "default" then
        return true
    end

    local skins = getNamedInventoryEntry(skinInventory, troopName)

    if type(skins) ~= "table" then
        return false
    end

    local wantedSkin = normalizeLookupKey(skinName)

    for entryName, value in pairs(skins) do
        local candidate = type(value) == "string" and value or (type(value) == "table" and value.Name)

        if normalizeLookupKey(candidate) == wantedSkin then
            return true
        end

        if type(entryName) == "string"
            and normalizeLookupKey(entryName) == wantedSkin
            and value ~= false then
            return true
        end
    end

    return false
end

local function getStrategySkinRequirements(strategy)
    local requirements = {}
    local seen = {}

    if type(strategy) ~= "table" then
        return requirements
    end

    for _, step in ipairs(strategy) do
        if step.action == "place"
            and type(step.troop) == "string"
            and type(step.skin) == "string"
            and step.skin ~= ""
            and normalizeLookupKey(step.skin) ~= "default" then
            local requirementKey = normalizeLookupKey(step.troop) .. "|" .. normalizeLookupKey(step.skin)

            if not seen[requirementKey] then
                seen[requirementKey] = true
                table.insert(requirements, {
                    Skin = step.skin,
                    Troop = step.troop,
                })
            end
        end
    end

    return requirements
end

local function getMissingTroopNames(requiredTroops, availableTroops)
    local availableLookup = {}
    local missing = {}

    for _, troopName in ipairs(getUniqueTroopNames(availableTroops)) do
        availableLookup[normalizeLookupKey(troopName)] = true
    end

    for _, troopName in ipairs(getUniqueTroopNames(requiredTroops)) do
        if not availableLookup[normalizeLookupKey(troopName)] then
            table.insert(missing, troopName)
        end
    end

    return missing
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

local function appendClientReadyBootstrapLines(lines)
    table.insert(lines, "if not game:IsLoaded() then")
    table.insert(lines, "    game.Loaded:Wait()")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local Players = game:GetService(\"Players\")")
    table.insert(lines, "local LocalPlayer = Players.LocalPlayer")
    table.insert(lines, "while not LocalPlayer do")
    table.insert(lines, "    task.wait()")
    table.insert(lines, "    LocalPlayer = Players.LocalPlayer")
    table.insert(lines, "end")
    table.insert(lines, "LocalPlayer:WaitForChild(\"PlayerGui\")")
    table.insert(lines, "")
end

local function readCacheValue(cacheKey, timeout)
    local deadline = os.clock() + math.max(0.1, tonumber(timeout) or 5)
    local cacheModule

    repeat
        cacheModule = ReplicatedStorage:FindFirstChild("Client")
        cacheModule = cacheModule and cacheModule:FindFirstChild("Modules")
        cacheModule = cacheModule and cacheModule:FindFirstChild("Universal")
        cacheModule = cacheModule and cacheModule:FindFirstChild("Utilities")
        cacheModule = cacheModule and cacheModule:FindFirstChild("Cache")

        if not cacheModule and os.clock() < deadline then
            task.wait(0.1)
        end
    until cacheModule or os.clock() >= deadline

    if not cacheModule then
        return nil, "Could not find the " .. tostring(cacheKey) .. " cache module."
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
        return nil, "Could not load the " .. tostring(cacheKey) .. " cache: " .. tostring(cacheFactoryOrError)
    end

    local cacheFactory = cacheFactoryOrError

    local requested, cacheValue = pcall(function()
        return cacheFactory(cacheKey):Get()
    end)

    if not requested then
        return nil, "Could not request " .. tostring(cacheKey) .. ": " .. tostring(cacheValue)
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
        return nil, "Could not read " .. tostring(cacheKey) .. ": " .. tostring(subscribeError)
    end

    while not settled and os.clock() < deadline do
        task.wait()
    end

    if not settled then
        return nil, "Timed out waiting for " .. tostring(cacheKey) .. "."
    end

    if resolvedError then
        return nil, "Could not read " .. tostring(cacheKey) .. ": " .. tostring(resolvedError)
    end

    return resolvedValue
end

local function resolveUnverifiedStrategyPerks(perkStates, troopInventory)
    local needsResolution = false

    for _, state in ipairs(perkStates or {}) do
        if state.Unverified then
            needsResolution = true
            break
        end
    end

    if not needsResolution then
        return true
    end

    local inventoryError

    if not troopInventory then
        troopInventory, inventoryError = readCacheValue("Inventory.Troops")
    end

    for _, state in ipairs(perkStates) do
        if state.Unverified then
            local enabled = getCachedStrategyPerkStatus(troopInventory, state.Definition)
            local statusError

            if enabled == nil then
                enabled, statusError = queryStrategyPerkStatus(state.Definition)
            end

            if enabled == nil then
                return false,
                    "Could not resolve the current "
                        .. state.Tier
                        .. " perk state for "
                        .. state.Troop
                        .. ": "
                        .. (inventoryError and ("Inventory.Troops: " .. tostring(inventoryError) .. "; ") or "")
                        .. "status remote: "
                        .. tostring(statusError)
            end

            state.Enabled = enabled
            state.Unverified = false
            warn(
                "[LyraMacro] "
                    .. state.Troop
                    .. " has legacy unverified perk metadata; preserving its current "
                    .. state.Tier
                    .. " perk state ("
                    .. (enabled and "enabled" or "disabled")
                    .. "). Re-record this strategy to store the exact state."
            )
        end
    end

    return true
end

local function readEquippedTroops(timeout)
    return readCacheValue("Equipped.Troops", timeout)
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

local function remoteTextWasRejected(value)
    if type(value) ~= "string" then
        return false
    end

    local lookupKey = normalizeLookupKey(value)

    for _, rejectionWord in ipairs({
        "cannot",
        "cant",
        "failed",
        "failure",
        "notready",
        "rejected",
        "stunned",
        "unavailable",
    }) do
        if lookupKey:find(rejectionWord, 1, true) ~= nil then
            return true
        end
    end

    if lookupKey:find("cooldown", 1, true) ~= nil
        and lookupKey:find("cooldownstarted", 1, true) == nil then
        return true
    end

    if lookupKey:find("error", 1, true) ~= nil
        and lookupKey:find("noerror", 1, true) == nil
        and lookupKey:find("errorfree", 1, true) == nil
        and lookupKey:find("withouterror", 1, true) == nil then
        return true
    end

    local spacedText = " " .. string.lower(value):gsub("[^%w]+", " ") .. " "
    return spacedText:find(" locked ", 1, true) ~= nil
end

local function remoteResponseWasRejected(response)
    if response == false then
        return true
    end

    if remoteTextWasRejected(response) then
        return true
    end

    if type(response) == "table" then
        if response.Success == false
            or response.Successful == false
            or response.Ok == false
            or response[1] == false
            or response.Error ~= nil
            or response.ErrorMessage ~= nil then
            return true
        end

        for _, messageKey in ipairs({ "Message", "Reason", "Result", "Status" }) do
            if remoteTextWasRejected(response[messageKey]) then
                return true
            end
        end
    end

    return false
end

local function remoteResultsWereRejected(remoteResults)
    if type(remoteResults) ~= "table" then
        return remoteResponseWasRejected(remoteResults)
    end

    local resultCount = tonumber(remoteResults.n) or #remoteResults

    -- A leading true/Instance/explicit success table is authoritative. Some
    -- remotes return informational strings (for example cooldown metadata) after it.
    if resultCount > 0 and remoteResponseWasAccepted(remoteResults[1]) then
        return false
    end

    for index = 1, resultCount do
        if remoteResponseWasRejected(remoteResults[index]) then
            return true
        end
    end

    return false
end

local function summarizeRemoteResponse(response)
    if response == nil then
        return "nil"
    end

    if type(response) ~= "table" then
        return tostring(response)
    end

    local entries = {}

    for key, value in pairs(response) do
        if #entries >= 10 then
            table.insert(entries, "...")
            break
        end

        local valueType = type(value)
        local valueKind = getValueKind(value)
        local formattedValue

        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            formattedValue = tostring(value)
        elseif valueKind == "Instance" then
            formattedValue = getInstanceName(value) or "Instance"
        else
            formattedValue = valueKind
        end

        table.insert(entries, tostring(key) .. "=" .. tostring(formattedValue))
    end

    table.sort(entries)
    return "{" .. table.concat(entries, ", ") .. "}"
end

local function summarizeRemoteResults(remoteResults)
    if type(remoteResults) ~= "table" then
        return summarizeRemoteResponse(remoteResults)
    end

    local summaries = {}
    local resultCount = tonumber(remoteResults.n) or #remoteResults

    if resultCount == 0 then
        return "no return values"
    end

    for index = 1, resultCount do
        table.insert(summaries, summarizeRemoteResponse(remoteResults[index]))
    end

    return table.concat(summaries, ", ")
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

    if upgrade == nil then
        return false, "unknown upgrade"
    end

    if upgrade < CHAIN_COA_MIN_UPGRADE then
        return false, "needs upgrade"
    end

    if isCallOfArmsTowerStunned(tower) then
        return false, "stunned"
    end

    return true
end

function LyraMacro:ActivateAbilityForTower(tower, abilityName, options)
    assert(tower and tower.Parent, "[LyraMacro] Cannot activate an ability for a missing tower.")

    local canonicalAbilityName = TRACKED_ABILITIES[normalizeLookupKey(abilityName)] or tostring(abilityName or "")
    assert(canonicalAbilityName ~= "", "[LyraMacro] Ability name is required.")

    local abilityInfo = {
        Name = canonicalAbilityName,
        Troop = tower,
    }

    if type(options) == "table" and options.InternalChainCOA == true then
        self._chainCOAInternalAbilityRequests[abilityInfo] = true
    end

    return RemoteFunction:InvokeServer("Troops", "Abilities", "Activate", abilityInfo)
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

function LyraMacro:SetChainCOA(enabled, options)
    enabled = enabled == true
    options = type(options) == "table" and options or {}

    if enabled and game.PlaceId ~= MATCH_PLACE_ID then
        return false, "Chain COA can only run in match place " .. tostring(MATCH_PLACE_ID) .. "."
    end

    local wasEnabled = self.ChainCOAEnabled
    local configuredActiveDuration = tonumber(options.ActiveDuration)
    local configuredHandoffDelay = tonumber(options.HandoffDelay)
    local configuredRetryDelay = tonumber(options.RetryDelay)

    if configuredActiveDuration then
        self.ChainCOAActiveDuration = math.max(0, configuredActiveDuration)
    end
    if configuredHandoffDelay then
        self.ChainCOAHandoffDelay = math.max(0, configuredHandoffDelay)
    end
    if configuredRetryDelay then
        self.ChainCOARetryDelay = math.max(0, configuredRetryDelay)
    end

    local function recordSettingIfNeeded()
        if self.IsRecording and options.Record ~= false and wasEnabled ~= enabled then
            self:_appendRecordedStep({
                action = "chaincoa",
                enabled = enabled,
                active_duration = self.ChainCOAActiveDuration,
                handoff_delay = self.ChainCOAHandoffDelay,
                retry_delay = self.ChainCOARetryDelay,
            })
        end
    end

    self.ChainCOAEnabled = enabled
    self._chainCOAToken += 1
    self:_clearChainCOAConnections()

    if not enabled then
        table.clear(self.ChainCOASeenTowers)
        recordSettingIfNeeded()
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

    recordSettingIfNeeded()
    print(
        "[LyraMacro] Chain COA armed. Waiting for "
            .. tostring(CHAIN_COA_REQUIRED_TOWERS)
            .. " detected, upgrade-ready Commander/Lifeguard towers. Each accepted activation stays active for "
            .. tostring(self.ChainCOAActiveDuration)
            .. " seconds, followed by a "
            .. tostring(self.ChainCOAHandoffDelay)
            .. " second handoff."
    )

    task.spawn(function()
        local towerOrder = {}
        local nextTowerOrder = 0
        local lastSuccessfulTower
        local pendingTower
        local nextAttemptAt
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
                UnknownUpgrade = 0,
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
                elseif reason == "unknown upgrade" then
                    states.UnknownUpgrade += 1
                end
            end

            table.sort(readyTowers, function(left, right)
                return towerOrder[left] < towerOrder[right]
            end)

            return allTowers, readyTowers, states
        end

        local function getNextTower(readyTowers)
            if pendingTower then
                for _, tower in ipairs(readyTowers) do
                    if tower == pendingTower then
                        return pendingTower
                    end
                end

                pendingTower = nil
            end

            local lastOrder = lastSuccessfulTower and towerOrder[lastSuccessfulTower] or 0

            for _, tower in ipairs(readyTowers) do
                if towerOrder[tower] > lastOrder then
                    return tower
                end
            end

            return readyTowers[1]
        end

        while self.ChainCOAEnabled and self._chainCOAToken == chainToken and game.PlaceId == MATCH_PLACE_ID do
            local callOfArmsTowers, readyTowers, states = getReadyRoster()

            if #callOfArmsTowers < CHAIN_COA_REQUIRED_TOWERS then
                reportStatus(
                    "Chain COA has "
                        .. tostring(#callOfArmsTowers)
                        .. "/"
                        .. tostring(CHAIN_COA_REQUIRED_TOWERS)
                        .. " detected Commander/Lifeguard towers."
                )
                task.wait(CHAIN_COA_POLL_INTERVAL)
            elseif not rotationActive and #readyTowers < CHAIN_COA_REQUIRED_TOWERS then
                local waiting = {}

                if states.NeedsUpgrade > 0 then
                    table.insert(waiting, tostring(states.NeedsUpgrade) .. " need upgrade " .. tostring(CHAIN_COA_MIN_UPGRADE))
                end
                if states.Stunned > 0 then
                    table.insert(waiting, tostring(states.Stunned) .. " stunned")
                end
                if states.UnknownUpgrade > 0 then
                    table.insert(waiting, tostring(states.UnknownUpgrade) .. " missing upgrade state")
                end

                reportStatus(
                    "Chain COA is waiting for "
                        .. tostring(CHAIN_COA_REQUIRED_TOWERS)
                        .. " ready commanders ("
                        .. tostring(#readyTowers)
                        .. " ready; "
                        .. table.concat(waiting, ", ")
                        .. ")."
                )
                task.wait(CHAIN_COA_POLL_INTERVAL)
            elseif #readyTowers == 0 then
                reportStatus("Chain COA is preserving its rotation until a commander becomes ready again.")
                task.wait(CHAIN_COA_POLL_INTERVAL)
            else
                if not rotationActive then
                    rotationActive = true
                    nextAttemptAt = os.clock()
                    reportStatus("Chain COA detected " .. tostring(#readyTowers) .. " ready commanders; starting stable rotation.")
                elseif rosterChanged then
                    print("[LyraMacro] Chain COA roster changed; preserving the rotation and timer.")
                end

                rosterChanged = false
                local now = os.clock()
                local waitTime = (nextAttemptAt or now) - now

                if waitTime > 0 then
                    task.wait(math.min(waitTime, CHAIN_COA_POLL_INTERVAL))
                elseif activationInFlight then
                    task.wait(0.05)
                else
                    local targetTower = getNextTower(readyTowers)

                    if not targetTower then
                        task.wait(CHAIN_COA_POLL_INTERVAL)
                    else
                        pendingTower = targetTower
                        activationInFlight = true

                        task.spawn(function()
                            local attempt = table.pack(pcall(function()
                                assert(
                                    self.ChainCOAEnabled and self._chainCOAToken == chainToken and targetTower.Parent,
                                    "The selected commander is no longer available."
                                )

                                return self:ActivateAbilityForTower(targetTower, "Call Of Arms", {
                                    InternalChainCOA = true,
                                })
                            end))
                            local invoked = attempt[1] == true
                            local attemptCount = attempt.n or #attempt
                            local remoteResults = {
                                n = math.max(0, attemptCount - 1),
                            }

                            for index = 2, attemptCount do
                                remoteResults[index - 1] = attempt[index]
                            end

                            activationInFlight = false

                            if not self.ChainCOAEnabled or self._chainCOAToken ~= chainToken then
                                return
                            end

                            if not invoked or remoteResultsWereRejected(remoteResults) then
                                pendingTower = targetTower.Parent and targetTower or nil
                                nextAttemptAt = os.clock() + self.ChainCOARetryDelay
                                warn(
                                    "[LyraMacro] Chain COA activation was rejected; retrying in "
                                        .. tostring(self.ChainCOARetryDelay)
                                        .. " seconds without advancing the rotation. Response: "
                                        .. summarizeRemoteResults(remoteResults)
                                )
                            else
                                lastSuccessfulTower = targetTower
                                pendingTower = nil
                                self.ChainCOANextIndex = towerOrder[targetTower] or self.ChainCOANextIndex
                                nextAttemptAt = os.clock()
                                    + self.ChainCOAActiveDuration
                                    + self.ChainCOAHandoffDelay
                                print(
                                    "[LyraMacro] Chain COA accepted commander slot "
                                        .. tostring(towerOrder[targetTower] or "?")
                                        .. "; active for "
                                        .. tostring(self.ChainCOAActiveDuration)
                                        .. " seconds, then waiting "
                                        .. tostring(self.ChainCOAHandoffDelay)
                                        .. " seconds before the next commander."
                                )
                            end
                        end)
                    end
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

function LyraMacro:CheckStrategyRequirements(strategy, options)
    options = options or {}

    local perkStates, perkMetadataError = getStrategyPerkStates(strategy)

    if not perkStates then
        return false, perkMetadataError
    end

    local strategyLoadout = self:GetStrategyLoadout(strategy)
    local loadout = getUniqueTroopNames(options.Loadout or strategyLoadout)

    if #loadout > 5 then
        return false,
            "This strategy uses "
                .. tostring(#loadout)
                .. " towers, but the lobby loadout only supports five. AutoStrategy aborted."
    end

    local omittedStrategyTowers = getMissingTroopNames(strategyLoadout, loadout)

    if #omittedStrategyTowers > 0 then
        return false,
            "The configured loadout omits required strategy towers: "
                .. table.concat(omittedStrategyTowers, ", ")
                .. ". AutoStrategy aborted."
    end

    local troopInventory, troopInventoryError = readCacheValue("Inventory.Troops")

    if not troopInventory then
        return false,
            "Could not verify the required towers: "
                .. tostring(troopInventoryError)
                .. " AutoStrategy aborted before changing your loadout."
    end

    local perksResolved, perkResolutionError = resolveUnverifiedStrategyPerks(perkStates, troopInventory)

    if not perksResolved then
        return false,
            tostring(perkResolutionError)
                .. " AutoStrategy aborted before changing your loadout."
    end

    local missingTowers = {}

    for _, troopName in ipairs(loadout) do
        if not inventoryOwnsTroop(troopInventory, troopName) then
            table.insert(missingTowers, troopName)
        end
    end

    local skinRequirements = getStrategySkinRequirements(strategy)
    local missingSkins = {}
    local skinInventory

    if #skinRequirements > 0 or #perkStates > 0 then
        local skinInventoryError
        skinInventory, skinInventoryError = readCacheValue("Inventory.Skins")

        if not skinInventory then
            return false,
                "Could not verify the required skins and perks: "
                    .. tostring(skinInventoryError)
                    .. " AutoStrategy aborted before changing your loadout."
        end

        for _, requirement in ipairs(skinRequirements) do
            if not inventoryOwnsSkin(skinInventory, requirement.Troop, requirement.Skin) then
                table.insert(missingSkins, requirement.Troop .. " [" .. requirement.Skin .. "]")
            end
        end
    end

    local missingPerks = {}

    for _, state in ipairs(perkStates) do
        state.Owned = inventoryOwnsSkin(skinInventory, state.Troop, state.Tier)

        if state.Enabled and not state.Owned then
            table.insert(missingPerks, state.Tier .. " " .. state.Troop)
        end
    end

    local missingEquipped = {}

    if options.RequireEquipped == true then
        local equippedTroops, equippedError = readEquippedTroops()

        if not equippedTroops then
            return false, "Could not verify the equipped strategy towers: " .. tostring(equippedError)
        end

        missingEquipped = getMissingTroopNames(loadout, equippedTroops)
    end

    local problems = {}

    if #missingTowers > 0 then
        table.insert(problems, "Missing required towers: " .. table.concat(missingTowers, ", ") .. ".")
    end

    if #missingSkins > 0 then
        table.insert(problems, "Missing required skins: " .. table.concat(missingSkins, ", ") .. ".")
    end

    if #missingPerks > 0 then
        table.insert(problems, "Missing required perks: " .. table.concat(missingPerks, ", ") .. ".")
    end

    if #missingEquipped > 0 then
        table.insert(problems, "Required towers are not equipped: " .. table.concat(missingEquipped, ", ") .. ".")
    end

    if #problems > 0 then
        return false, table.concat(problems, " ") .. " AutoStrategy aborted before its first action."
    end

    return true, {
        Loadout = loadout,
        PerkStates = perkStates,
    }
end

function LyraMacro:ApplyStrategyPerks(strategy, perkStates)
    if not perkStates then
        local perkMetadataError
        perkStates, perkMetadataError = getStrategyPerkStates(strategy)

        if not perkStates then
            return false, perkMetadataError
        end
    end

    local perksResolved, perkResolutionError = resolveUnverifiedStrategyPerks(perkStates)

    if not perksResolved then
        return false, perkResolutionError
    end

    local needsOwnershipLookup = false

    for _, state in ipairs(perkStates) do
        if state.Owned == nil then
            needsOwnershipLookup = true
            break
        end
    end

    if needsOwnershipLookup then
        local skinInventory, skinInventoryError = readCacheValue("Inventory.Skins")

        if not skinInventory then
            return false, "Could not verify perk ownership: " .. tostring(skinInventoryError)
        end

        for _, state in ipairs(perkStates) do
            state.Owned = inventoryOwnsSkin(skinInventory, state.Troop, state.Tier)
        end
    end

    for _, state in ipairs(perkStates) do
        if state.Enabled and not state.Owned then
            return false, "Missing required perk: " .. state.Tier .. " " .. state.Troop .. "."
        end

        if state.Owned ~= false then
            local currentState, statusError = queryStrategyPerkStatus(state.Definition)

            if currentState == nil then
                return false,
                    "Could not read "
                        .. state.Tier
                        .. " perk state for "
                        .. state.Troop
                        .. ": "
                        .. tostring(statusError)
            end

            if currentState ~= state.Enabled then
                local fired, fireError = pcall(function()
                    RemoteEvent:FireServer("Inventory", "Execute", "Troops", state.Definition.ToggleAction, {
                        Troop = state.Troop,
                        Enabled = state.Enabled,
                    })
                end)

                if not fired then
                    return false,
                        "Could not set "
                            .. state.Tier
                            .. " perk for "
                            .. state.Troop
                            .. ": "
                            .. tostring(fireError)
                end

                task.wait(STRATEGY_PERK_TOGGLE_SETTLE_TIME)

                local confirmed, confirmationError = waitForStrategyPerkState(state.Definition, state.Enabled)

                if not confirmed then
                    return false,
                        "The server did not confirm "
                            .. state.Tier
                            .. " perk for "
                            .. state.Troop
                            .. ": "
                            .. tostring(confirmationError)
                end

                print(
                    "[LyraMacro] "
                        .. (state.Enabled and "Enabled" or "Disabled")
                        .. " "
                        .. state.Tier
                        .. " perk for "
                        .. state.Troop
                        .. "."
                )
            else
                print(
                    "[LyraMacro] "
                        .. state.Tier
                        .. " perk for "
                        .. state.Troop
                        .. " is already "
                        .. (state.Enabled and "enabled" or "disabled")
                        .. "."
                )
            end
        end
    end

    return true
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

    if loadoutsMatch(currentLoadout, desiredLoadout) then
        self.SelectedLoadout = getUniqueTroopNames(desiredLoadout)
        print("[LyraMacro] Lobby loadout already matches the strategy.")
        return true, self.SelectedLoadout
    end

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
        local currentAfterFailure = readEquippedTroops(1)
        local missingAfterFailure = currentAfterFailure and getMissingTroopNames(desiredLoadout, currentAfterFailure) or desiredLoadout

        return false,
            "Could not equip required strategy towers: "
                .. table.concat(missingAfterFailure, ", ")
                .. "."
    end

    self.SelectedLoadout = getUniqueTroopNames(desiredLoadout)
    print("[LyraMacro] Lobby loadout synchronized: " .. table.concat(self.SelectedLoadout, ", "))

    return true, self.SelectedLoadout
end

function LyraMacro:PrepareStrategyLoadout(strategy, options)
    options = options or {}
    local loadout = options.Loadout or self:GetStrategyLoadout(strategy)

    local requirementsReady, requirementsOrError = self:CheckStrategyRequirements(strategy, {
        Loadout = loadout,
    })

    if not requirementsReady then
        return false, requirementsOrError
    end

    local loadoutReady, loadoutOrError = self:SyncLobbyLoadout(requirementsOrError.Loadout)

    if not loadoutReady then
        return false, loadoutOrError
    end

    local perksReady, perksError = self:ApplyStrategyPerks(strategy, requirementsOrError.PerkStates)

    if not perksReady then
        return false, perksError
    end

    return true, loadoutOrError
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

local function normalizePrivateServerLinkType(value)
    if type(value) ~= "string" then
        return nil
    end

    local linkType = string.lower(trimString(value))

    if linkType == PRIVATE_SERVER_LINK_TYPE_SHARE or linkType == "modern" then
        return PRIVATE_SERVER_LINK_TYPE_SHARE
    end

    if linkType == PRIVATE_SERVER_LINK_TYPE_LEGACY
        or linkType == "linkcode"
        or linkType == "privateserverlinkcode" then
        return PRIVATE_SERVER_LINK_TYPE_LEGACY
    end

    return nil
end

local function detectPrivateServerLinkType(value)
    if value == nil then
        return nil
    end

    local linkValue = string.lower(trimString(value))

    if linkValue:find("/share", 1, true)
        or linkValue:find("navigation/share_links", 1, true) then
        return PRIVATE_SERVER_LINK_TYPE_SHARE
    end

    if linkValue:find("privateserverlinkcode=", 1, true)
        or linkValue:find("linkcode=", 1, true) then
        return PRIVATE_SERVER_LINK_TYPE_LEGACY
    end

    return nil
end

local function normalizePrivateServerLinkCode(value)
    if value == nil then
        return nil
    end

    local linkCode = trimString(value)

    local codeFromUrl = linkCode:match("[?&]privateServerLinkCode=([^&#]+)")
        or linkCode:match("[?&]linkCode=([^&#]+)")

    if not codeFromUrl
        and (linkCode:find("/share", 1, true) or linkCode:find("navigation/share_links", 1, true)) then
        local shareType = linkCode:match("[?&]type=([^&#]+)")

        if shareType and string.lower(shareType) ~= "server" then
            return nil
        end

        codeFromUrl = linkCode:match("[?&]code=([^&#]+)")
    end

    if codeFromUrl then
        linkCode = codeFromUrl
    end

    if linkCode == "" or #linkCode > 256 or not linkCode:match("^[%w_%-]+$") then
        return nil
    end

    return linkCode
end

function LyraMacro:SetPrivateServerLinkCode(linkCode, linkType)
    self.SelectedPrivateServerLinkCode = normalizePrivateServerLinkCode(linkCode)
    self.SelectedPrivateServerLinkType = self.SelectedPrivateServerLinkCode
            and (
                normalizePrivateServerLinkType(linkType)
                or detectPrivateServerLinkType(linkCode)
                or PRIVATE_SERVER_LINK_TYPE_SHARE
            )
        or nil

    if self.SelectedPrivateServerLinkCode then
        print(
            "[LyraMacro] Private server "
                .. tostring(self.SelectedPrivateServerLinkType)
                .. " link code configured."
        )
    else
        print("[LyraMacro] Private server link code cleared.")
    end

    return self.SelectedPrivateServerLinkCode, self.SelectedPrivateServerLinkType
end

local function normalizeServerInstanceId(value)
    if type(value) ~= "string" then
        return nil
    end

    local instanceId = trimString(value)

    if instanceId == "" or #instanceId > 256 or not instanceId:match("^[%w_%-]+$") then
        return nil
    end

    return instanceId
end

-- Stores a verified, live lobby instance as a best-effort in-game return route.
-- A user VIP server can restart with a different JobId, so this never replaces
-- the configured share link and is attempted only once before the URL fallback.
function LyraMacro:SetPrivateServerReturnInstance(placeId, jobId)
    if placeId == nil and jobId == nil then
        self.PrivateServerReturnPlaceId = nil
        self.PrivateServerReturnJobId = nil
        self.PrivateServerReturnOriginVerified = false
        return true, "Private-lobby return instance cleared."
    end

    local normalizedPlaceId = tonumber(placeId)
    local normalizedJobId = normalizeServerInstanceId(jobId)

    if normalizedPlaceId ~= LOBBY_PLACE_ID or not normalizedJobId then
        return false, "Private-lobby return instance requires the lobby PlaceId and a valid live JobId."
    end

    self.PrivateServerReturnPlaceId = LOBBY_PLACE_ID
    self.PrivateServerReturnJobId = normalizedJobId
    self.PrivateServerReturnOriginVerified = true
    print("[LyraMacro] Verified private-lobby return instance carried into the match.")

    return true, "Private-lobby return instance configured."
end

function LyraMacro:SetPrivateServerStatusProvider(provider)
    assert(
        provider == nil or type(provider) == "function",
        "[LyraMacro] Private server status provider must be a function or nil."
    )

    self.PrivateServerStatusProvider = provider
end

function LyraMacro:SetPrivateServerReturnProvider(provider)
    assert(
        provider == nil or type(provider) == "function",
        "[LyraMacro] Private server return provider must be a function or nil."
    )

    self.PrivateServerReturnProvider = provider
end

local function isReplicatedPrivateServerMarker(value)
    if value == true then
        return true
    end

    if type(value) == "string" then
        local normalized = normalizeLookupKey(value)
        return normalized == "private"
            or normalized == "privateserver"
            or normalized == "vip"
            or normalized == "vipserver"
    end

    return false
end

local function normalizeProvidedServerType(value)
    if value == true then
        return "private"
    end

    if value == false then
        return "public"
    end

    if type(value) ~= "string" then
        return nil
    end

    local normalized = normalizeLookupKey(value)

    if normalized == "private" or normalized == "privateserver" or normalized == "vip" or normalized == "vipserver" then
        return "private"
    end

    if normalized == "reserved" or normalized == "reservedserver" then
        return "reserved"
    end

    if normalized == "nonpublic" or normalized == "nonpublicserver" then
        return "nonpublic"
    end

    if normalized == "public" or normalized == "publicserver" or normalized == "standard" or normalized == "standardserver" then
        return "public"
    end

    return nil
end

local function readDataModelProperty(propertyName)
    local readable, value = pcall(function()
        return game[propertyName]
    end)

    return readable, value
end

local function getCurrentServerIdentity()
    local placeId = tonumber(game.PlaceId) or 0
    local jobId = type(game.JobId) == "string" and game.JobId or ""
    return placeId, jobId, tostring(placeId) .. ":" .. jobId
end

local function safeGetAttributes(instance)
    local readable, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if readable and type(attributes) == "table" then
        return attributes
    end

    return {}
end

local function getInstancePath(instance)
    local readable, fullName = pcall(function()
        return instance:GetFullName()
    end)

    if readable and type(fullName) == "string" and fullName ~= "" then
        return fullName
    end

    return getInstanceName(instance) or "unknown instance"
end

local function inspectReplicatedServerMarker(instance)
    local instancePath = getInstancePath(instance)

    for attributeName, attributeValue in pairs(safeGetAttributes(instance)) do
        local attributeKey = normalizeLookupKey(attributeName)

        if PRIVATE_SERVER_MARKER_KEYS[attributeKey] and isReplicatedPrivateServerMarker(attributeValue) then
            return "private", "replicated marker " .. instancePath .. "." .. tostring(attributeName)
        end

        if PRIVATE_SERVER_TYPE_MARKER_KEYS[attributeKey] and type(attributeValue) == "string" then
            local markedServerType = normalizeProvidedServerType(attributeValue)

            if markedServerType == "private" or markedServerType == "reserved" or markedServerType == "nonpublic" then
                return markedServerType, "replicated server type " .. instancePath .. "." .. tostring(attributeName)
            end
        end
    end

    local instanceKey = normalizeLookupKey(getInstanceName(instance))
    local instanceValue = readInstanceValue(instance)

    if PRIVATE_SERVER_MARKER_KEYS[instanceKey] and isReplicatedPrivateServerMarker(instanceValue) then
        return "private", "replicated marker " .. instancePath
    end

    if PRIVATE_SERVER_TYPE_MARKER_KEYS[instanceKey] and type(instanceValue) == "string" then
        local markedServerType = normalizeProvidedServerType(instanceValue)

        if markedServerType == "private" or markedServerType == "reserved" or markedServerType == "nonpublic" then
            return markedServerType, "replicated server type " .. instancePath
        end
    end

    return nil
end

local function scanReplicatedServerMarkers()
    local queue = {}
    local visited = {}
    local scannedCount = 0

    local function enqueue(instance, depth)
        if not instance or visited[instance] or scannedCount >= PRIVATE_SERVER_MARKER_SCAN_LIMIT then
            return
        end

        visited[instance] = true
        scannedCount += 1
        table.insert(queue, {
            Instance = instance,
            Depth = depth,
        })
    end

    enqueue(LocalPlayer, 0)
    enqueue(ReplicatedStorage, 0)
    enqueue(workspace, 0)
    enqueue(game, 0)

    local queueIndex = 1

    while queueIndex <= #queue do
        local entry = queue[queueIndex]
        queueIndex += 1

        local markedServerType, markerSource = inspectReplicatedServerMarker(entry.Instance)

        if markedServerType then
            return markedServerType, markerSource
        end

        if entry.Depth < PRIVATE_SERVER_MARKER_SCAN_DEPTH then
            for _, child in ipairs(safeGetChildren(entry.Instance)) do
                local childKey = normalizeLookupKey(getInstanceName(child))

                if
                    PRIVATE_SERVER_MARKER_KEYS[childKey]
                    or PRIVATE_SERVER_TYPE_MARKER_KEYS[childKey]
                    or PRIVATE_SERVER_STATE_CONTAINER_KEYS[childKey]
                then
                    enqueue(child, entry.Depth + 1)
                end
            end
        end
    end

    return nil
end

local function getReplicatedServerMarker(self, contextKey)
    if self._privateServerMarkerContextKey ~= contextKey then
        self._privateServerMarkerContextKey = contextKey
        self._privateServerMarkerType = nil
        self._privateServerMarkerSource = nil
        self._privateServerMarkerLastScanAt = -math.huge
    end

    if self._privateServerMarkerType and self._privateServerMarkerSource then
        return self._privateServerMarkerType, self._privateServerMarkerSource
    end

    if os.clock() - self._privateServerMarkerLastScanAt < PRIVATE_SERVER_MARKER_SCAN_INTERVAL then
        return nil
    end

    self._privateServerMarkerLastScanAt = os.clock()
    local markedServerType, markerSource = scanReplicatedServerMarkers()

    if markedServerType then
        self._privateServerMarkerType = markedServerType
        self._privateServerMarkerSource = markerSource
    end

    return markedServerType, markerSource
end

local function markServerDirectoryFailure(context, failure)
    context.Pending = false
    context.PendingSince = nil
    context.Type = nil
    context.Source = nil
    context.Error = tostring(failure)
    context.FailureCount = (tonumber(context.FailureCount) or 0) + 1

    local retryDelay = math.min(
        PRIVATE_SERVER_PUBLIC_SCAN_RETRY_DELAY * (2 ^ math.min(context.FailureCount - 1, 4)),
        PRIVATE_SERVER_PUBLIC_SCAN_MAX_RETRY_DELAY
    )
    context.RetryAfter = os.clock() + retryDelay
end

function LyraMacro:RefreshServerContext()
    local placeId, jobId, contextKey = getCurrentServerIdentity()
    local context = self._serverDirectoryContext

    if not context or context.Key ~= contextKey then
        context = {
            Key = contextKey,
            PlaceId = placeId,
            JobId = jobId,
            Pending = false,
            Generation = 0,
            FailureCount = 0,
            RetryAfter = -math.huge,
        }
        self._serverDirectoryContext = context
    end

    if context.Type == "public" or context.Type == "nonpublic" then
        return context
    end

    if context.Pending then
        if os.clock() - (tonumber(context.PendingSince) or os.clock()) < PRIVATE_SERVER_PUBLIC_SCAN_TIMEOUT then
            return context
        end

        -- The executor's HttpGet cannot always be cancelled. Invalidate this
        -- generation so a late completion cannot overwrite a newer result.
        context.Generation += 1
        markServerDirectoryFailure(context, "public-server lookup timed out")
        return context
    end

    if os.clock() < (tonumber(context.RetryAfter) or -math.huge) then
        return context
    end

    context.Error = nil

    if placeId <= 0 then
        markServerDirectoryFailure(context, "current PlaceId is unavailable")
        return context
    end

    if jobId == "" then
        markServerDirectoryFailure(context, "current JobId is unavailable")
        return context
    end

    context.Generation += 1
    local generation = context.Generation
    local normalizedJobId = jobId:lower()
    context.Pending = true
    context.PendingSince = os.clock()

    task.delay(PRIVATE_SERVER_PUBLIC_SCAN_TIMEOUT, function()
        if
            self._serverDirectoryContext == context
            and context.Generation == generation
            and context.Pending
        then
            context.Generation += 1
            markServerDirectoryFailure(context, "public-server lookup timed out")
        end
    end)

    task.spawn(function()
        local scanned, resultType, resultSourceOrError = pcall(function()
            local pagesScanned = 0

            for confirmation = 1, PRIVATE_SERVER_PUBLIC_ABSENCE_CONFIRMATIONS do
                local cursor
                local completedPass = false

                for _ = 1, PRIVATE_SERVER_PUBLIC_SCAN_MAX_PAGES do
                    if self._serverDirectoryContext ~= context or context.Generation ~= generation then
                        error("server context changed during public-server lookup")
                    end

                    local query = confirmation % 2 == 0
                            and "excludeFullGames=false&limit=100&sortOrder=Asc"
                        or "sortOrder=Asc&excludeFullGames=false&limit=100"
                    local url = "https://games.roblox.com/v1/games/"
                        .. tostring(placeId)
                        .. "/servers/Public?"
                        .. query

                    if cursor then
                        url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
                    end

                    local response = game:HttpGet(url)
                    local page = HttpService:JSONDecode(response)

                    if
                        type(page) ~= "table"
                        or type(page.data) ~= "table"
                        or (type(page.errors) == "table" and next(page.errors) ~= nil)
                    then
                        error("Roblox returned an invalid public-server response")
                    end

                    pagesScanned += 1

                    for _, server in ipairs(page.data) do
                        if type(server) == "table" and tostring(server.id or ""):lower() == normalizedJobId then
                            return "public", "Roblox public server directory (current JobId listed)"
                        end
                    end

                    local nextCursor = page.nextPageCursor

                    if nextCursor == nil then
                        completedPass = true
                        break
                    end

                    if type(nextCursor) ~= "string" or nextCursor == "" then
                        error("Roblox returned an invalid public-server cursor")
                    end

                    cursor = nextCursor
                end

                if not completedPass then
                    error("public-server pagination exceeded the safe page limit")
                end

                if confirmation < PRIVATE_SERVER_PUBLIC_ABSENCE_CONFIRMATIONS then
                    task.wait(PRIVATE_SERVER_PUBLIC_CONFIRMATION_DELAY)
                end
            end

            return "nonpublic",
                "Roblox public server directory (current JobId absent in "
                    .. tostring(PRIVATE_SERVER_PUBLIC_ABSENCE_CONFIRMATIONS)
                    .. " complete scans, "
                    .. tostring(pagesScanned)
                    .. " pages checked)"
        end)

        if self._serverDirectoryContext ~= context or context.Generation ~= generation then
            return
        end

        context.Pending = false
        context.PendingSince = nil
        context.LastCompletedAt = os.clock()

        if scanned then
            context.Type = resultType
            context.Source = resultSourceOrError
            context.Error = nil
            context.FailureCount = 0
            context.RetryAfter = -math.huge
        else
            markServerDirectoryFailure(context, resultType)
        end
    end)

    return context
end

-- Returns "private", "reserved", "nonpublic", "public", or "unknown",
-- followed by the detection source and (for native VIP servers) owner user ID.
function LyraMacro:GetServerType()
    if type(self.PrivateServerStatusProvider) == "function" then
        local checked, providedStatus = pcall(self.PrivateServerStatusProvider)

        if checked then
            local providedServerType = normalizeProvidedServerType(providedStatus)

            if providedServerType then
                return providedServerType, "custom provider"
            end
        else
            warn("[LyraMacro] Private server status provider failed: " .. tostring(providedStatus))
        end
    end

    -- These properties are marked NotReplicated by Roblox. Read modern and
    -- deprecated aliases independently so executor-specific access failures do
    -- not discard positive evidence from another property. Empty client-side
    -- values are inconclusive and must never be treated as proof of publicness.
    local modernIdReadable, modernId = readDataModelProperty("PrivateServerId")
    local modernOwnerReadable, modernOwner = readDataModelProperty("PrivateServerOwnerId")
    local legacyIdReadable, legacyId = readDataModelProperty("VIPServerId")
    local legacyOwnerReadable, legacyOwner = readDataModelProperty("VIPServerOwnerId")
    local nativeOwners = {
        {
            Readable = modernOwnerReadable,
            Value = modernOwner,
            Source = "DataModel.PrivateServerOwnerId",
        },
        {
            Readable = legacyOwnerReadable,
            Value = legacyOwner,
            Source = "DataModel.VIPServerOwnerId",
        },
    }

    for _, ownerObservation in ipairs(nativeOwners) do
        local ownerUserId = ownerObservation.Readable and tonumber(ownerObservation.Value)

        if ownerUserId and ownerUserId > 0 then
            return "private", ownerObservation.Source, ownerUserId
        end
    end

    local nativePairs = {
        {
            IdReadable = modernIdReadable,
            Id = modernId,
            Source = "DataModel.PrivateServerId",
        },
        {
            IdReadable = legacyIdReadable,
            Id = legacyId,
            Source = "DataModel.VIPServerId",
        },
    }

    local _, _, contextKey = getCurrentServerIdentity()
    local markedServerType, markerSource = getReplicatedServerMarker(self, contextKey)

    for _, nativePair in ipairs(nativePairs) do
        local privateServerId = nativePair.IdReadable and type(nativePair.Id) == "string" and trimString(nativePair.Id)

        if privateServerId and privateServerId ~= "" then
            if markedServerType then
                return markedServerType, markerSource
            end

            -- A positive ID proves this is not public, but the paired owner can
            -- still read as zero in an executor because it is NotReplicated.
            return "nonpublic", nativePair.Source .. " (owner unavailable client-side)"
        end
    end

    local directoryContext = self:RefreshServerContext()

    if directoryContext.Type == "public" then
        if markedServerType then
            return "unknown",
                "conflicting server evidence: "
                    .. tostring(markerSource)
                    .. "; current JobId is listed as public"
        end

        return "public", directoryContext.Source
    end

    if directoryContext.Type == "nonpublic" then
        if markedServerType then
            return markedServerType, markerSource
        end

        return "nonpublic", directoryContext.Source
    end

    if directoryContext.Pending then
        if
            markedServerType
            and os.clock() - (tonumber(directoryContext.PendingSince) or os.clock())
                >= PRIVATE_SERVER_PUBLIC_MARKER_FALLBACK_DELAY
        then
            return markedServerType, markerSource .. " (public-directory verification still pending)"
        end

        return "unknown",
            markedServerType
                    and ("verifying " .. tostring(markerSource) .. " against Roblox public server directory")
                or "checking Roblox public server directory"
    end

    if directoryContext.Error then
        if markedServerType then
            return markedServerType, markerSource .. " (public-directory verification unavailable)"
        end

        return "unknown", "Roblox public server directory unavailable: " .. tostring(directoryContext.Error)
    end

    return "unknown", "private-server evidence unavailable"
end

function LyraMacro:WaitForServerContext(timeout)
    local deadline = os.clock() + math.max(0, tonumber(timeout) or 8)
    local serverType = self:GetServerType()

    while os.clock() < deadline do
        local context = self._serverDirectoryContext

        if serverType ~= "unknown" and not (context and context.Pending) then
            break
        end

        self:RefreshServerContext()
        task.wait(0.05)
        serverType = self:GetServerType()
    end

    return self:GetServerType()
end

function LyraMacro:GetServerTypeDisplayName()
    local serverType, source, ownerUserId = self:GetServerType()
    return SERVER_TYPE_DISPLAY_NAMES[serverType] or "Unknown", source, ownerUserId
end

function LyraMacro:GetServerStatusText()
    local serverType, source, ownerUserId = self:GetServerType()
    local statusText = "Server: " .. (SERVER_TYPE_DISPLAY_NAMES[serverType] or "Unknown")

    if serverType == "private" and ownerUserId then
        if LocalPlayer and tonumber(LocalPlayer.UserId) == ownerUserId then
            statusText ..= " (owned by you)"
        else
            statusText ..= " (owner user ID " .. tostring(ownerUserId) .. ")"
        end
    elseif serverType == "reserved" then
        statusText ..= " (not a user-owned VIP lobby)"
    elseif serverType == "nonpublic" then
        statusText ..= " (VIP/reserved ownership unavailable to this client)"
    elseif serverType == "unknown" then
        statusText ..= " (detection checking or unavailable)"
    end

    return statusText .. ".", source
end

function LyraMacro:IsPrivateServer()
    local serverType = self:GetServerType()
    return serverType == "private" or serverType == "reserved" or serverType == "nonpublic"
end

function LyraMacro:IsUserOwnedPrivateServer()
    local serverType = self:GetServerType()
    return serverType == "private"
end

function LyraMacro:IsReservedServer()
    local serverType = self:GetServerType()
    return serverType == "reserved"
end

function LyraMacro:ShouldUsePrivateServerWorkflow()
    local serverType, source = self:GetServerType()

    if game.PlaceId ~= LOBBY_PLACE_ID then
        return false, "private-server elevator commands are lobby-only"
    end

    if serverType == "private" then
        return true, "detected Private/VIP server via " .. tostring(source)
    end

    if serverType == "nonpublic" then
        return true, "detected non-public lobby via " .. tostring(source)
    end

    if serverType == "reserved" then
        return false, "current server is reserved, not a confirmed Private/VIP lobby"
    end

    if serverType == "public" then
        return false, "current server is public"
    end

    return false, "server type could not be detected via " .. tostring(source)
end

function LyraMacro:GameInfo(mapName, privateServerLinkCodeOrOptions, maybeOptions)
    local options
    local privateServerLinkCode

    if type(privateServerLinkCodeOrOptions) == "table" then
        options = privateServerLinkCodeOrOptions
        privateServerLinkCode = options.PrivateServerLinkCode
            or options.PrivateServerCode
            or options.privateServerLinkCode
            or options.privateServerCode
    else
        privateServerLinkCode = privateServerLinkCodeOrOptions
        options = type(maybeOptions) == "table" and maybeOptions or {}

        if privateServerLinkCode == nil then
            privateServerLinkCode = options.PrivateServerLinkCode
                or options.PrivateServerCode
                or options.privateServerLinkCode
                or options.privateServerCode
        end
    end

    local normalizedMapName = normalizeMapCandidate(mapName) or tostring(mapName or "")
    self.SelectedMap = normalizedMapName
    self.LastDetectedMapSource = options.Source or "manual"
    self:SetPrivateServerLinkCode(
        privateServerLinkCode,
        options.PrivateServerLinkType
            or options.PrivateServerCodeType
            or options.privateServerLinkType
            or options.privateServerCodeType
    )
    print("[LyraMacro] Match configured for map: " .. normalizedMapName)
end

-- Clears only this strategy's stable tower IDs for a fresh solo match.
function LyraMacro:RemoveIndex()
    table.clear(self.SpawnedTowers)
    table.clear(self.SpawnedTowerPlacedAt)
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

local function setPrivateServerReturnRoute(route)
    local marked, markError = pcall(function()
        TeleportService:SetTeleportSetting(PRIVATE_SERVER_RETURN_ROUTE_SETTING, route)
    end)

    if not marked then
        return false, tostring(markError)
    end

    return true
end

local function getPrivateServerReturnRelaySource(linkCode, linkType, attemptsRemaining, expiresAt)
    local lines = {
        "if not game:IsLoaded() then",
        "    game.Loaded:Wait()",
        "end",
        "",
        "local Players = game:GetService(\"Players\")",
        "local LocalPlayer = Players.LocalPlayer",
        "while not LocalPlayer do",
        "    task.wait()",
        "    LocalPlayer = Players.LocalPlayer",
        "end",
        "LocalPlayer:WaitForChild(\"PlayerGui\")",
        "",
        "local LOBBY_PLACE_ID = " .. tostring(LOBBY_PLACE_ID),
        "local PRIVATE_SERVER_LINK_CODE = " .. formatLuaValue(linkCode),
        "local PRIVATE_SERVER_LINK_TYPE = " .. formatLuaValue(linkType),
        "local RELAY_ATTEMPTS_REMAINING = " .. tostring(attemptsRemaining),
        "local RELAY_EXPIRES_AT = " .. tostring(expiresAt),
        "local RETURN_ROUTE_SETTING = " .. formatLuaValue(PRIVATE_SERVER_RETURN_ROUTE_SETTING),
        "local TeleportService = game:GetService(\"TeleportService\")",
        "",
        "if os.time() > RELAY_EXPIRES_AT then",
        "    warn(\"[LyraMacro] Private-lobby return relay expired.\")",
        "    return",
        "end",
        "",
        "if game.PlaceId ~= LOBBY_PLACE_ID then",
        "    warn(\"[LyraMacro] Private-lobby return relay ignored a non-lobby destination.\")",
        "    return",
        "end",
        "",
        "local returnRoute",
        "local routeRead, routeValue = pcall(function()",
        "    return TeleportService:GetTeleportSetting(RETURN_ROUTE_SETTING)",
        "end)",
        "",
        "if routeRead and type(routeValue) == \"string\" and routeValue ~= \"\" then",
        "    returnRoute = routeValue",
        "end",
        "pcall(function()",
        "    TeleportService:SetTeleportSetting(RETURN_ROUTE_SETTING, \"\")",
        "end)",
        "",
        "local previousAutoUI",
        "local hasSharedEnvironment = type(getgenv) == \"function\"",
        "",
        "if hasSharedEnvironment then",
        "    previousAutoUI = getgenv().LyraMacroAutoUI",
        "    getgenv().LyraMacroAutoUI = false",
        "end",
        "",
        "local loaded, LyraMacro = pcall(function()",
        "    return loadstring(game:HttpGet("
            .. formatLuaValue(getCacheBustedUrlPrefix(DEFAULT_MACRO_LIBRARY_URL))
            .. " .. tostring(os.time())))()",
        "end)",
        "",
        "if hasSharedEnvironment then",
        "    getgenv().LyraMacroAutoUI = previousAutoUI",
        "end",
        "",
        "if not loaded then",
        "    warn(\"[LyraMacro] Private-lobby return relay could not load the library: \" .. tostring(LyraMacro))",
        "    return",
        "end",
        "",
        "local serverType, serverSource = LyraMacro:WaitForServerContext("
            .. tostring(PRIVATE_SERVER_PUBLIC_SETTLE_TIMEOUT)
            .. ")",
        "local originRouteJobId = returnRoute and (",
        "    returnRoute:match(\"^captured_instance:(.+)$\")",
        "        or returnRoute:match(\"^trusted_history:(.+)$\")",
        ")",
        "local routeConfirmed = returnRoute == \"configured_link\"",
        "    or (originRouteJobId ~= nil and originRouteJobId == game.JobId)",
        "    or (returnRoute == nil and serverType == \"private\")",
        "",
        "if routeConfirmed and (serverType == \"private\" or serverType == \"nonpublic\") then",
        "    print(\"[LyraMacro] Configured private-lobby arrival confirmed (\" .. tostring(returnRoute) .. \", \" .. tostring(serverType) .. \" via \" .. tostring(serverSource) .. \").\")",
        "    return",
        "end",
        "",
        "warn(\"[LyraMacro] Configured private-lobby arrival was not confirmed (route \" .. tostring(returnRoute) .. \", \" .. tostring(serverType) .. \" via \" .. tostring(serverSource) .. \"); retrying the exact private-server link.\")",
        "",
        "LyraMacro:SetPrivateServerLinkCode(PRIVATE_SERVER_LINK_CODE, PRIVATE_SERVER_LINK_TYPE)",
        "local returned, message = LyraMacro:ReturnToPrivateServer(nil, {",
        "    RelayAttemptsRemaining = RELAY_ATTEMPTS_REMAINING,",
        "    RelayExpiresAt = RELAY_EXPIRES_AT,",
        "    PromptForPermission = false,",
        "})",
        "",
        "if not returned then",
        "    warn(\"[LyraMacro] Private-lobby return relay failed: \" .. tostring(message))",
        "end",
    }

    return table.concat(lines, "\n")
end

local function queuePrivateServerReturnRelay(linkCode, linkType, attemptsRemaining, expiresAt)
    if attemptsRemaining < 0 then
        return false, "private-lobby return relay limit reached"
    end

    local queueTeleport = getTeleportQueueFunction()

    if not queueTeleport then
        return false, "executor does not expose queue_on_teleport"
    end

    local queued, queueError = pcall(
        queueTeleport,
        getPrivateServerReturnRelaySource(linkCode, linkType, attemptsRemaining, expiresAt)
    )

    if not queued or queueError == false then
        return false, tostring(queueError)
    end

    return true
end

local EXECUTOR_URL_LAUNCHER_NAMES = {
    "open_url",
    "openurl",
    "openUrl",
    "openURL",
    "open_uri",
    "openuri",
    "openUri",
    "open_browser",
    "openbrowser",
    "openBrowser",
}

local function getExecutorUrlLaunchers()
    local launchers = {}
    local seenFunctions = {}
    local seenContainers = {}

    local function addContainer(label, container, methodFallback)
        if type(container) ~= "table" or seenContainers[container] then
            return
        end

        seenContainers[container] = true

        for _, functionName in ipairs(EXECUTOR_URL_LAUNCHER_NAMES) do
            local read, candidate = pcall(function()
                return container[functionName]
            end)

            if read and type(candidate) == "function" and not seenFunctions[candidate] then
                seenFunctions[candidate] = true
                table.insert(launchers, {
                    Callback = candidate,
                    CallStyle = methodFallback and "auto" or "function",
                    Name = label .. "." .. functionName,
                    Owner = methodFallback and container or nil,
                    WebOnly = false,
                })
            end
        end
    end

    local function addServiceLauncher(serviceName, methodName, webOnly, deepOnly, dispatchOnly)
        local gotService, service = pcall(function()
            return game:GetService(serviceName)
        end)

        if not gotService or not service then
            return
        end

        local readMethod, callback = pcall(function()
            return service[methodName]
        end)

        if not readMethod or type(callback) ~= "function" or seenFunctions[callback] then
            return
        end

        seenFunctions[callback] = true
        table.insert(launchers, {
            Callback = callback,
            CallStyle = "method",
            Name = serviceName .. "." .. methodName,
            Owner = service,
            WebOnly = webOnly == true,
            DeepOnly = deepOnly == true,
            DispatchOnly = dispatchOnly == true,
        })
    end

    local sharedEnvironment = getSharedEnvironment()
    local currentEnvironment

    if type(getfenv) == "function" then
        local readEnvironment, environment = pcall(getfenv, 0)

        if not readEnvironment or type(environment) ~= "table" then
            readEnvironment, environment = pcall(getfenv)
        end

        if readEnvironment and type(environment) == "table" then
            currentEnvironment = environment
        end
    end

    addContainer("getgenv()", sharedEnvironment)
    addContainer("getfenv(0)", currentEnvironment)
    addContainer("_G", _G)

    for _, namespaceName in ipairs({ "syn", "executor", "fluxus" }) do
        local namespace

        if type(sharedEnvironment) == "table" then
            namespace = sharedEnvironment[namespaceName]
        end
        if type(namespace) ~= "table" and type(currentEnvironment) == "table" then
            namespace = currentEnvironment[namespaceName]
        end
        if type(namespace) ~= "table" and type(_G) == "table" then
            namespace = _G[namespaceName]
        end

        addContainer(namespaceName, namespace, true)
    end

    -- Some executors do not expose an openurl global but can grant access to
    -- Roblox's own browser/linking services. Opiumware protects these methods
    -- behind an explicit native permission prompt handled below.
    addServiceLauncher("BrowserService", "OpenBrowserWindow", true)
    addServiceLauncher("GuiService", "OpenBrowserWindow", true)
    -- DetectUrl feeds an incoming native URI to Roblox's current-client link
    -- handler. Opiumware does not blacklist it, so try it before methods that
    -- open another app/window and confirm success only from teleport state.
    addServiceLauncher("LinkingService", "DetectUrl", false, true, true)
    addServiceLauncher("LinkingService", "OpenUrl", false)

    return launchers
end

local function getExecutorMaliciousOverrideFunction()
    local environments = {}
    local seenEnvironments = {}

    local function addEnvironment(environment)
        if type(environment) == "table" and not seenEnvironments[environment] then
            seenEnvironments[environment] = true
            table.insert(environments, environment)
        end
    end

    addEnvironment(getSharedEnvironment())

    if type(getfenv) == "function" then
        local readEnvironment, environment = pcall(getfenv, 0)

        if not readEnvironment or type(environment) ~= "table" then
            readEnvironment, environment = pcall(getfenv)
        end

        if readEnvironment then
            addEnvironment(environment)
        end
    end

    addEnvironment(_G)

    for _, environment in ipairs(environments) do
        local read, callback = pcall(function()
            return environment.overridemalicious
        end)

        if read and type(callback) == "function" then
            return callback
        end
    end

    return nil
end

local function getPrivateServerReturnPermissionState()
    return getSharedEnvironment() or (type(_G) == "table" and _G or nil)
end

local function privateServerReturnPermissionWasPrompted(macro)
    local permissionState = getPrivateServerReturnPermissionState()

    return macro._privateServerReturnPermissionPrompted == true
        or (permissionState and permissionState[PRIVATE_SERVER_RETURN_PERMISSION_KEY] == true)
end

local function invokeExecutorUrlLauncher(launcher, url)
    if launcher.CallStyle == "method" then
        local invoked, result = pcall(launcher.Callback, launcher.Owner, url)
        return invoked and result ~= false, result
    end

    local invoked, result = pcall(launcher.Callback, url)

    if invoked and result ~= false then
        return true, result
    end

    local firstError = result

    if launcher.Owner then
        local methodInvoked, methodResult = pcall(launcher.Callback, launcher.Owner, url)

        if methodInvoked and methodResult ~= false then
            return true, methodResult
        end

        return false,
            tostring(firstError)
                .. "; method-style call failed: "
                .. tostring(methodResult)
    end

    return false, firstError
end

local function getPrivateServerLaunchCandidates(targets)
    local candidates = {}
    local launchers = getExecutorUrlLaunchers()

    for _, target in ipairs(targets) do
        for _, launcher in ipairs(launchers) do
            if (not launcher.WebOnly or target.IsWeb)
                and (not launcher.DeepOnly or not target.IsWeb) then
                table.insert(candidates, {
                    Kind = target.Kind,
                    Launcher = launcher,
                    Url = target.Url,
                })
            end
        end
    end

    return candidates
end

local function hasPrivateServerUrlFallback(candidates)
    for _, candidate in ipairs(candidates) do
        if not candidate.Launcher.DispatchOnly then
            return true
        end
    end

    return false
end

local function launchPrivateServerUrl(candidates, startIndex)
    local errors = {}
    local candidateCount = #candidates
    local firstIndex = math.clamp(tonumber(startIndex) or 1, 1, candidateCount + 1)

    if candidateCount == 0 then
        return false, "executor does not expose a usable URL or browser launcher", 1
    end

    if firstIndex > candidateCount then
        return false, "all private-server URL and browser launch routes were exhausted", firstIndex
    end

    for candidateIndex = firstIndex, candidateCount do
        local candidate = candidates[candidateIndex]
        local routeMarked, routeMarkError = setPrivateServerReturnRoute("configured_link")
        local launched, result = invokeExecutorUrlLauncher(candidate.Launcher, candidate.Url)

        if launched then
            return true,
                candidate.Launcher.Name
                    .. " using "
                    .. candidate.Kind
                    .. (
                        routeMarked
                            and ""
                            or (" (destination marker unavailable: " .. tostring(routeMarkError) .. ")")
                    ),
                candidateIndex + 1
        end

        if not routeMarked then
            table.insert(
                errors,
                "could not mark the configured-link route: " .. tostring(routeMarkError)
            )
        end

        table.insert(
            errors,
            candidate.Launcher.Name
                .. " rejected "
                .. candidate.Kind
                .. ": "
                .. tostring(result)
        )
    end

    return false, table.concat(errors, "; "), candidateCount + 1
end

local function copyPrivateServerUrl(url)
    local clipboard = type(setclipboard) == "function" and setclipboard
        or (type(toclipboard) == "function" and toclipboard or nil)

    if not clipboard then
        return false
    end

    local copied = pcall(clipboard, url)
    return copied
end

function LyraMacro:GetPrivateServerReturnUrl()
    local linkCode = normalizePrivateServerLinkCode(self.SelectedPrivateServerLinkCode)

    if not linkCode then
        return nil
    end

    local encodedLinkCode = HttpService:UrlEncode(linkCode)

    if self.SelectedPrivateServerLinkType == PRIVATE_SERVER_LINK_TYPE_LEGACY then
        return PRIVATE_SERVER_RETURN_LEGACY_URL_PREFIX .. encodedLinkCode
    end

    return PRIVATE_SERVER_RETURN_URL_PREFIX .. encodedLinkCode .. PRIVATE_SERVER_RETURN_URL_SUFFIX
end

function LyraMacro:GetPrivateServerReturnDeepLink()
    local linkCode = normalizePrivateServerLinkCode(self.SelectedPrivateServerLinkCode)

    if not linkCode then
        return nil
    end

    local encodedLinkCode = HttpService:UrlEncode(linkCode)

    if self.SelectedPrivateServerLinkType == PRIVATE_SERVER_LINK_TYPE_LEGACY then
        return PRIVATE_SERVER_RETURN_LEGACY_DEEP_LINK_PREFIX .. encodedLinkCode
    end

    return PRIVATE_SERVER_RETURN_DEEP_LINK_PREFIX .. encodedLinkCode .. PRIVATE_SERVER_RETURN_DEEP_LINK_SUFFIX
end

local function getPrivateServerReturnLaunchTargets(linkCode, linkType)
    local encodedLinkCode = HttpService:UrlEncode(linkCode)

    if linkType == PRIVATE_SERVER_LINK_TYPE_LEGACY then
        return {
            {
                Kind = "legacy Roblox deep link",
                Url = PRIVATE_SERVER_RETURN_LEGACY_DEEP_LINK_PREFIX .. encodedLinkCode,
                IsWeb = false,
            },
            {
                Kind = "legacy Roblox web link",
                Url = PRIVATE_SERVER_RETURN_LEGACY_URL_PREFIX .. encodedLinkCode,
                IsWeb = true,
            },
        }
    end

    -- Prefer Roblox's native current-client share route, then fall back to its
    -- canonical HTTPS entry point. Never reuse a share token as a legacy
    -- linkCode; they are different identifiers.
    return {
        {
            Kind = "Roblox share deep link",
            Url = PRIVATE_SERVER_RETURN_DEEP_LINK_PREFIX
                .. encodedLinkCode
                .. PRIVATE_SERVER_RETURN_DEEP_LINK_SUFFIX,
            IsWeb = false,
        },
        {
            Kind = "Roblox share web link",
            Url = PRIVATE_SERVER_RETURN_URL_PREFIX
                .. encodedLinkCode
                .. PRIVATE_SERVER_RETURN_URL_SUFFIX,
            IsWeb = true,
        },
    }
end

-- Opiumware intentionally blocks Roblox's URL methods until the user accepts
-- its own native Yes/No security prompt. Ask only when a private return is
-- explicitly configured, remember the answer for this Roblox process, and
-- rebuild the launcher list after the prompt because the earlier reads failed.
function LyraMacro:PreparePrivateServerReturn(options)
    options = options or {}

    local linkCode = normalizePrivateServerLinkCode(self.SelectedPrivateServerLinkCode)

    if not linkCode then
        return false, "No private-server link is configured."
    end

    local linkType = normalizePrivateServerLinkType(self.SelectedPrivateServerLinkType)
        or PRIVATE_SERVER_LINK_TYPE_SHARE
    local targets = getPrivateServerReturnLaunchTargets(linkCode, linkType)
    local candidates = getPrivateServerLaunchCandidates(targets)
    local overrideMalicious = getExecutorMaliciousOverrideFunction()
    local permissionAlreadyPrompted = privateServerReturnPermissionWasPrompted(self)
    local urlFallbackAlreadyAvailable = hasPrivateServerUrlFallback(candidates)

    if #candidates > 0
        and (
            options.PromptForPermission == false
            or not overrideMalicious
            or permissionAlreadyPrompted
            or urlFallbackAlreadyAvailable
        ) then
        return true, "Private-server URL launch is ready.", candidates
    end

    if options.PromptForPermission == false then
        return false, "The executor does not expose an enabled URL launcher."
    end

    local permissionState = getPrivateServerReturnPermissionState()

    if permissionAlreadyPrompted then
        return false, "Opiumware URL permission was already requested but no launcher is enabled."
    end

    if not overrideMalicious then
        return false, "The executor does not expose a usable URL or browser launcher."
    end

    warn(
        "[LyraMacro] Opiumware gates Roblox's protected link methods behind its broad session-wide "
            .. "\"malicious function overrides\" permission. Its native Yes/No prompt is opening now; "
            .. "Yes enables that executor permission for this Roblox session."
    )

    local prompted, promptError = pcall(overrideMalicious)

    if not prompted then
        return false, "Opiumware could not show its URL permission prompt: " .. tostring(promptError)
    end

    -- Opiumware's prompt is synchronous. Mark either Yes or No as answered,
    -- but leave a failed prompt callable so a later attempt can recover.
    self._privateServerReturnPermissionPrompted = true

    if permissionState then
        permissionState[PRIVATE_SERVER_RETURN_PERMISSION_KEY] = true
    end

    candidates = getPrivateServerLaunchCandidates(targets)

    if #candidates == 0 then
        return false, "Opiumware URL permission was declined or its protected link methods remained unavailable."
    end

    if hasPrivateServerUrlFallback(candidates) then
        print("[LyraMacro] Automatic private-lobby URL fallbacks were enabled by the Opiumware confirmation.")
        return true, "Private-server URL launch is ready.", candidates
    end

    warn(
        "[LyraMacro] Opiumware's protected URL fallbacks remain disabled. "
            .. "The current-client private share route is still available."
    )
    return true, "Current-client private-server share routing is ready.", candidates
end

local function getTeleportHistoryPlaceId(entry)
    if type(entry) == "number" or type(entry) == "string" then
        return tonumber(entry)
    end

    if type(entry) ~= "table" then
        return nil
    end

    return tonumber(entry.PlaceId or entry.placeId or entry[1])
end

local function teleportHistoryContainsPlace(history, placeId)
    if type(history) ~= "table" then
        return false
    end

    for _, entry in pairs(history) do
        if getTeleportHistoryPlaceId(entry) == placeId then
            return true
        end
    end

    return false
end

local function tryTrustedLobbyHistoryReturn()
    local readHistory, historyOrError = pcall(function()
        return TeleportService:TeleportedPlacesBackHistory()
    end)

    if not readHistory then
        return false, "Roblox teleport history is unavailable: " .. tostring(historyOrError)
    end

    if not teleportHistoryContainsPlace(historyOrError, LOBBY_PLACE_ID) then
        return false, "Roblox teleport history does not contain the originating lobby"
    end

    local invoked, invokeError = pcall(function()
        TeleportService:TeleportTrustedBackHistory(LOBBY_PLACE_ID)
    end)

    if not invoked then
        return false, "Roblox trusted lobby history rejected the request: " .. tostring(invokeError)
    end

    return true, "Roblox trusted lobby history"
end

function LyraMacro:_clearLobbyReturnConnections()
    for _, connection in ipairs(self._privateServerReturnConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(self._privateServerReturnConnections)
end

function LyraMacro:_cancelLobbyReturn()
    self._privateServerReturnToken += 1
    self._privateServerReturnStarted = false
    self:_clearLobbyReturnConnections()
end

local function findResultsLobbyButton(results)
    if not results then
        return nil
    end

    local fallbackButton

    for _, descendant in ipairs(safeGetDescendants(results)) do
        if descendant:IsA("GuiButton") then
            local nameKey = normalizeLookupKey(descendant.Name)
            local hasLobbyName = nameKey:find("lobby", 1, true) ~= nil
            local hasReturnName = nameKey:find("return", 1, true) ~= nil

            if hasLobbyName and hasReturnName then
                return descendant
            end

            if hasLobbyName then
                fallbackButton = fallbackButton or descendant
            end

            local textCandidates = {}

            if descendant:IsA("TextButton") then
                table.insert(textCandidates, descendant.Text)
            end

            for _, label in ipairs(safeGetDescendants(descendant)) do
                if label:IsA("TextLabel") or label:IsA("TextButton") then
                    table.insert(textCandidates, label.Text)
                end
            end

            for _, text in ipairs(textCandidates) do
                local textKey = normalizeLookupKey(text)

                if textKey == "returntolobby"
                    or (textKey:find("return", 1, true) and textKey:find("lobby", 1, true)) then
                    return descendant
                end
            end
        end
    end

    return fallbackButton
end

local function activateResultsLobbyButton(button)
    if not button then
        return false, "PlayerGui.GameGui.Results has no Return to Lobby button"
    end

    local signals = {
        { Name = "Activated", Signal = button.Activated },
        { Name = "MouseButton1Click", Signal = button.MouseButton1Click },
    }

    if type(getconnections) == "function" then
        for _, signalInfo in ipairs(signals) do
            local gotConnections, connections = pcall(getconnections, signalInfo.Signal)

            if gotConnections and type(connections) == "table" and #connections > 0 then
                if type(firesignal) == "function" then
                    local fired, fireError = pcall(firesignal, signalInfo.Signal)

                    if fired then
                        return true, "Results button " .. signalInfo.Name
                    end

                    return false, tostring(fireError)
                end

                local firedConnection = false

                for _, connection in ipairs(connections) do
                    local fired = pcall(function()
                        if type(connection.Fire) == "function" then
                            connection:Fire()
                            firedConnection = true
                        elseif type(connection.Function) == "function" then
                            task.spawn(connection.Function)
                            firedConnection = true
                        end
                    end)

                    -- Keep any earlier successful connection invocation.
                end

                if firedConnection then
                    return true, "Results button " .. signalInfo.Name
                end
            end
        end
    end

    if type(firesignal) == "function" then
        local fired, fireError = pcall(firesignal, button.Activated)

        if fired then
            return true, "Results button Activated"
        end

        return false, tostring(fireError)
    end

    return false, "executor does not expose firesignal or usable getconnections"
end

function LyraMacro:ReturnToPrivateServer(results, options)
    options = options or {}

    if self._privateServerReturnStarted then
        return true, "Lobby return is already in progress."
    end

    local linkCode = normalizePrivateServerLinkCode(self.SelectedPrivateServerLinkCode)
    local linkType = linkCode
            and (
                normalizePrivateServerLinkType(self.SelectedPrivateServerLinkType)
                or PRIVATE_SERVER_LINK_TYPE_SHARE
            )
        or nil
    local url = linkCode and self:GetPrivateServerReturnUrl() or nil
    local deepLink = linkCode and self:GetPrivateServerReturnDeepLink() or nil
    local destinationName = linkCode and "configured private lobby" or "lobby"
    local usesProvider = linkCode and type(self.PrivateServerReturnProvider) == "function"
    local allowPermissionPrompt = options.PromptForPermission ~= false
    local privatePreparationError
    local privateLaunchCandidates = {}

    if linkCode and not usesProvider then
        if allowPermissionPrompt
            and not privateServerReturnPermissionWasPrompted(self)
            and getExecutorMaliciousOverrideFunction() then
            local prepared, preparationMessage = self:PreparePrivateServerReturn({
                PromptForPermission = true,
            })

            if not prepared then
                privatePreparationError = preparationMessage
                warn(
                    "[LyraMacro] Private-lobby URL preparation did not complete: "
                        .. tostring(preparationMessage)
                )
            end
        end

        privateLaunchCandidates = getPrivateServerLaunchCandidates(
            getPrivateServerReturnLaunchTargets(linkCode, linkType)
        )
    end

    local privateServerReturnPlaceId = tonumber(self.PrivateServerReturnPlaceId)
    local privateServerReturnJobId = normalizeServerInstanceId(self.PrivateServerReturnJobId)
    local verifiedPrivateOrigin = linkCode
        and self.PrivateServerReturnOriginVerified == true
        and privateServerReturnPlaceId == LOBBY_PLACE_ID
        and privateServerReturnJobId ~= nil
    local privateDestinationRelayQueued = false

    if linkCode and not usesProvider then
        local relayAttemptsRemaining = math.clamp(
            math.floor(tonumber(options.RelayAttemptsRemaining) or PRIVATE_SERVER_RETURN_RELAY_MAX_HOPS),
            0,
            PRIVATE_SERVER_RETURN_RELAY_MAX_HOPS
        )
        local relayExpiresAt = math.floor(
            tonumber(options.RelayExpiresAt) or (os.time() + PRIVATE_SERVER_RETURN_RELAY_TTL)
        )

        if relayAttemptsRemaining > 0 and relayExpiresAt > os.time() then
            local relayQueued, relayError = queuePrivateServerReturnRelay(
                linkCode,
                linkType,
                relayAttemptsRemaining - 1,
                relayExpiresAt
            )

            if relayQueued then
                privateDestinationRelayQueued = true
                print(
                    "[LyraMacro] Private-lobby destination verification queued with "
                        .. tostring(relayAttemptsRemaining)
                        .. " hop(s) remaining."
                )
            else
                warn(
                    "[LyraMacro] Private-lobby destination verification could not be queued: "
                        .. tostring(relayError)
                )
            end
        end
    end

    -- Exact share-link routes are always allowed. A captured JobId or Roblox
    -- back-history route is only safe when the queued destination relay can
    -- detect a public arrival and retry the configured share link.
    local originFallbacksAllowed = verifiedPrivateOrigin and privateDestinationRelayQueued
    local internalRouteCount = originFallbacksAllowed and 2 or 0
    local maxAttempts = linkCode and not usesProvider
            and math.max(
                LOBBY_RETURN_MAX_ATTEMPTS,
                internalRouteCount + #privateLaunchCandidates
            )
        or LOBBY_RETURN_MAX_ATTEMPTS

    self:_clearLobbyReturnConnections()
    self._privateServerReturnToken += 1
    local returnToken = self._privateServerReturnToken
    self._privateServerReturnStarted = true
    self.PrivateServerReturnUrl = url
    self.PrivateServerReturnDeepLink = deepLink

    local attempts = 0
    local completed = false
    local retryScheduled = false
    local nextPrivateLaunchCandidate = 1
    local trustedHistoryAttempted = false
    local lobbyInstanceAttempted = false
    local pendingTeleportStateAttempt
    local attemptTeleport
    local scheduleRetry

    local function isCurrentReturn()
        return not completed and self._privateServerReturnToken == returnToken
    end

    local function finishSuccess(source)
        if not isCurrentReturn() then
            return
        end

        completed = true
        self:_clearLobbyReturnConnections()
        print(
            "[LyraMacro] Lobby return started for "
                .. destinationName
                .. " via "
                .. tostring(source)
                .. "."
        )
    end

    local function finishFailure(reason)
        if not isCurrentReturn() then
            return
        end

        completed = true
        self._privateServerReturnStarted = false
        self:_clearLobbyReturnConnections()
        local fallbackMessage = ""

        if linkCode and url and copyPrivateServerUrl(url) then
            fallbackMessage = " The private-lobby URL was copied to the clipboard."
        end

        warn(
            "[LyraMacro] Lobby return to "
                .. destinationName
                .. " failed after "
                .. tostring(attempts)
                .. " attempts: "
                .. tostring(reason)
                .. fallbackMessage
        )
    end

    local function hasRemainingReturnRoute()
        if not linkCode or usesProvider then
            return attempts < maxAttempts
        end

        if nextPrivateLaunchCandidate <= #privateLaunchCandidates then
            return true
        end

        if originFallbacksAllowed and not lobbyInstanceAttempted then
            return true
        end

        if originFallbacksAllowed and not trustedHistoryAttempted then
            return true
        end

        return false
    end

    scheduleRetry = function(reason, failedAttempt)
        if not isCurrentReturn()
            or retryScheduled
            or (failedAttempt and failedAttempt ~= attempts) then
            return
        end

        if attempts >= maxAttempts or not hasRemainingReturnRoute() then
            finishFailure(reason)
            return
        end

        retryScheduled = true
        warn(
            "[LyraMacro] Lobby return attempt "
                .. tostring(attempts)
                .. " failed: "
                .. tostring(reason)
                .. ". Retrying in "
                .. tostring(LOBBY_RETURN_RETRY_DELAY)
                .. " seconds."
        )

        task.delay(LOBBY_RETURN_RETRY_DELAY, function()
            if not isCurrentReturn()
                or (failedAttempt and failedAttempt ~= attempts) then
                return
            end

            if failedAttempt and pendingTeleportStateAttempt == failedAttempt then
                retryScheduled = false
                print(
                    "[LyraMacro] Lobby teleport entered a pending state before the retry; "
                        .. "waiting for it instead of starting a competing route."
                )
                task.delay(LOBBY_RETURN_PENDING_TIMEOUT - LOBBY_RETURN_STATE_TIMEOUT, function()
                    if isCurrentReturn()
                        and attempts == failedAttempt
                        and pendingTeleportStateAttempt == failedAttempt
                        and not retryScheduled then
                        pendingTeleportStateAttempt = nil
                        scheduleRetry(
                            "the late lobby teleport remained pending for "
                                .. tostring(LOBBY_RETURN_PENDING_TIMEOUT)
                                .. " seconds",
                            failedAttempt
                        )
                    end
                end)
                return
            end

            retryScheduled = false
            attemptTeleport()
        end)
    end

    attemptTeleport = function()
        if not isCurrentReturn() then
            return
        end

        attempts += 1
        local attemptNumber = attempts
        local teleportRouteStarted = false
        local externalLaunchStarted = false
        pendingTeleportStateAttempt = nil
        print(
            "[LyraMacro] Returning to "
                .. destinationName
                .. " (attempt "
                .. tostring(attemptNumber)
                .. "/"
                .. tostring(maxAttempts)
                .. ")."
        )

        local invoked, result = pcall(function()
            if usesProvider then
                return self.PrivateServerReturnProvider(url, linkCode, LOBBY_PLACE_ID)
            end

            local privateLaunchError
            local returnButton = not linkCode and findResultsLobbyButton(results) or nil

            local function addPrivateLaunchError(reason)
                if not reason or reason == "" then
                    return
                end

                privateLaunchError = privateLaunchError
                    and (privateLaunchError .. "; " .. tostring(reason))
                    or tostring(reason)
            end

            addPrivateLaunchError(privatePreparationError)

            local function tryReturnButton()
                local activated, activationMethod = activateResultsLobbyButton(returnButton)

                if not activated then
                    addPrivateLaunchError(activationMethod)
                    return false
                end

                return true, activationMethod
            end

            -- The game's Return to Lobby button targets the ordinary lobby. Only
            -- use it when no private share code was configured; otherwise launch
            -- the exact private-server link so a public teleport cannot win first.
            if returnButton and attemptNumber == 1 then
                local activated, activationMethod = tryReturnButton()

                if activated then
                    teleportRouteStarted = true
                    return activationMethod
                end
            end

            if linkCode then
                local launched, launchSource, nextCandidate = launchPrivateServerUrl(
                    privateLaunchCandidates,
                    nextPrivateLaunchCandidate
                )
                nextPrivateLaunchCandidate = nextCandidate

                if launched then
                    teleportRouteStarted = true
                    externalLaunchStarted = true
                    return launchSource
                end

                addPrivateLaunchError(launchSource)

                if originFallbacksAllowed and not lobbyInstanceAttempted then
                    lobbyInstanceAttempted = true
                    local routeMarked, routeMarkError = setPrivateServerReturnRoute(
                        "captured_instance:" .. privateServerReturnJobId
                    )

                    if routeMarked then
                        local instanceStarted, instanceError = pcall(function()
                            TeleportService:TeleportToPlaceInstance(
                                privateServerReturnPlaceId,
                                privateServerReturnJobId,
                                LocalPlayer
                            )
                        end)

                        if instanceStarted then
                            teleportRouteStarted = true
                            return "captured private-lobby instance"
                        end

                        addPrivateLaunchError(
                            "captured private-lobby instance rejected the request: "
                                .. tostring(instanceError)
                        )
                    else
                        addPrivateLaunchError(
                            "captured private-lobby instance was skipped because its destination "
                                .. "marker failed: "
                                .. tostring(routeMarkError)
                        )
                    end
                end

                if originFallbacksAllowed and not trustedHistoryAttempted then
                    trustedHistoryAttempted = true
                    local routeMarked, routeMarkError = setPrivateServerReturnRoute(
                        "trusted_history:" .. privateServerReturnJobId
                    )

                    if routeMarked then
                        local historyStarted, historySource = tryTrustedLobbyHistoryReturn()

                        if historyStarted then
                            teleportRouteStarted = true
                            return historySource
                        end

                        addPrivateLaunchError(historySource)
                    else
                        addPrivateLaunchError(
                            "Roblox trusted lobby history was skipped because its destination "
                                .. "marker failed: "
                                .. tostring(routeMarkError)
                        )
                    end
                end
            end

            if linkCode then
                error(
                    "could not launch the configured private lobby: "
                        .. tostring(privateLaunchError or "no usable Return to Lobby button or URL launcher was found"),
                    0
                )
            end

            print("[LyraMacro] Using direct public TeleportService lobby fallback.")
            teleportRouteStarted = true
            return TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)

        if not invoked or (usesProvider and result == false) then
            local failureReason = invoked and "the configured return provider rejected the request" or result

            if hasRemainingReturnRoute() then
                scheduleRetry(failureReason, attemptNumber)
            else
                finishFailure(failureReason)
            end
            return
        end

        if usesProvider then
            finishSuccess("configured return provider")
            return
        end

        if teleportRouteStarted then
            print(
                "[LyraMacro] Lobby return request dispatched via "
                    .. tostring(result)
                    .. "; waiting for the current client to enter a teleport state."
            )
            task.delay(LOBBY_RETURN_STATE_TIMEOUT, function()
                if isCurrentReturn() and attempts == attemptNumber and not retryScheduled then
                    if pendingTeleportStateAttempt == attemptNumber then
                        task.delay(LOBBY_RETURN_PENDING_TIMEOUT - LOBBY_RETURN_STATE_TIMEOUT, function()
                            if isCurrentReturn()
                                and attempts == attemptNumber
                                and not retryScheduled then
                                pendingTeleportStateAttempt = nil
                                scheduleRetry(
                                    "the lobby teleport remained pending for "
                                        .. tostring(LOBBY_RETURN_PENDING_TIMEOUT)
                                        .. " seconds",
                                    attemptNumber
                                )
                            end
                        end)
                    else
                        local routeKind = externalLaunchStarted and "private-lobby link" or "lobby teleport request"
                        scheduleRetry(
                            "no teleport state was observed after the " .. routeKind .. " was dispatched",
                            attemptNumber
                        )
                    end
                end
            end)
            return
        end
    end

    table.insert(self._privateServerReturnConnections, LocalPlayer.OnTeleport:Connect(function(state, placeId)
        if not isCurrentReturn() or placeId ~= LOBBY_PLACE_ID then
            return
        end

        if state == Enum.TeleportState.Started or state == Enum.TeleportState.WaitingForServer then
            pendingTeleportStateAttempt = attempts
            print("[LyraMacro] Lobby teleport is pending (" .. state.Name .. ").")
        elseif state == Enum.TeleportState.InProgress then
            finishSuccess("TeleportService (" .. state.Name .. ")")
        elseif state == Enum.TeleportState.Failed then
            pendingTeleportStateAttempt = nil
            scheduleRetry("LocalPlayer.OnTeleport reported Failed", attempts)
        end
    end))

    table.insert(self._privateServerReturnConnections, TeleportService.TeleportInitFailed:Connect(function(
        player,
        teleportResult,
        errorMessage,
        placeId
    )
        if not isCurrentReturn() or player ~= LocalPlayer or placeId ~= LOBBY_PLACE_ID then
            return
        end

        pendingTeleportStateAttempt = nil
        scheduleRetry(
            tostring(teleportResult and teleportResult.Name or teleportResult) .. ": " .. tostring(errorMessage),
            attempts
        )
    end))

    attemptTeleport()
    return true, url or tostring(LOBBY_PLACE_ID)
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

local function isLocalPlayerInsideElevator(elevator)
    if getValueKind(elevator) ~= "Instance" then
        return false
    end

    local state = elevator:FindFirstChild("State")
    local playersValue = state and state:FindFirstChild("Players")
    local playerCount

    if playersValue and playersValue:IsA("ValueBase") then
        local readCount, count = pcall(function()
            return tonumber(playersValue.Value)
        end)

        if readCount then
            playerCount = count
        end
    end

    if not playerCount or playerCount <= 0 then
        return false
    end

    local character = LocalPlayer.Character
    local rootPart = character
        and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    local lift = elevator:FindFirstChild("Lift")
    local liftMain = lift and lift:FindFirstChild("Main")

    if not rootPart
        or not rootPart:IsA("BasePart")
        or not liftMain
        or not liftMain:IsA("BasePart") then
        return false
    end

    local measured, relativePosition = pcall(function()
        return liftMain.CFrame:PointToObjectSpace(rootPart.Position)
    end)

    if not measured then
        return false
    end

    local halfSize = liftMain.Size * 0.5
    return math.abs(relativePosition.X) <= halfSize.X + 4
        and math.abs(relativePosition.Z) <= halfSize.Z + 4
        and relativePosition.Y >= -halfSize.Y - 6
        and relativePosition.Y <= halfSize.Y + 14
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
        -- Native private-server properties are not replicated to every client.
        -- A normal type read starts the fallback lookup only when stronger
        -- provider/native evidence did not already settle the answer.
        self:GetServerType()

        local lastRefreshAt = -math.huge
        local lastRefreshError
        local lastEntryAttemptAt = -math.huge
        local lastEntryError
        local lockedElevator
        local announcedPrivateWorkflow = false

        local function startPrivateElevatorAfterJoin(joinDescription)
            local currentServerType = self:GetServerType()
            local directoryContext = self._serverDirectoryContext

            if currentServerType == "unknown" or (directoryContext and directoryContext.Pending) then
                -- Elevator membership is already secure, so this bounded wait
                -- cannot rotate the selected map away while private-server
                -- detection finishes.
                self:WaitForServerContext(PRIVATE_SERVER_PUBLIC_SETTLE_TIMEOUT)
            end

            local privateServer, privateServerReason = self:ShouldUsePrivateServerWorkflow()

            if privateServer and not announcedPrivateWorkflow then
                announcedPrivateWorkflow = true
                print("[LyraMacro] Private server elevator workflow enabled by " .. tostring(privateServerReason) .. ".")
            end

            if not privateServer then
                warn(
                    "[LyraMacro] "
                        .. tostring(joinDescription)
                        .. ", but !start was not sent: "
                        .. tostring(privateServerReason)
                        .. "."
                )
                return false
            end

            print("[LyraMacro] " .. tostring(joinDescription) .. "; sending !start now.")
            local started, startMessage, startAttempts = self:_startPrivateServerElevator()

            if started then
                print(
                    "[LyraMacro] Sent !start via "
                        .. tostring(startMessage)
                        .. " (attempt "
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

            return started
        end

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

            if lockedElevator and isLocalPlayerInsideElevator(lockedElevator) then
                local elevatorMapTitle = getElevatorMapTitle(lockedElevator) or replay.TargetMap
                print(
                    "[LyraMacro] Local player is already inside the elevator for "
                        .. tostring(elevatorMapTitle)
                        .. "."
                )
                self:_setDetectedMap(elevatorMapTitle, "elevator", true)

                local queued, queueMessage = self:_queueStrategyReplayAfterTeleport(
                    replay,
                    elevatorMapTitle
                )

                if not queued then
                    warn("[LyraMacro] " .. tostring(queueMessage))
                    return
                end

                startPrivateElevatorAfterJoin("Existing elevator membership confirmed")
                return
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
                startPrivateElevatorAfterJoin("Elevator entry confirmed")
                return
            end

            task.wait(privateServer and PRIVATE_SERVER_ELEVATOR_POLL_INTERVAL or 1)
        end
    end)
end

function LyraMacro:_getAutoRecordTeleportSource(mapTitle)
    local libraryUrl = self.AutoRecordLibraryUrl or DEFAULT_MACRO_LIBRARY_URL
    local timeout = math.max(10, math.floor(tonumber(self.AutoRecordTimeout) or 45))
    local lines = {}
    appendClientReadyBootstrapLines(lines)
    table.insert(lines, "if game.PlaceId ~= " .. tostring(MATCH_PLACE_ID) .. " then")
    table.insert(lines, "    warn(\"[LyraMacro] Auto-record skipped: this is not the match place.\")")
    table.insert(lines, "    return")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local hasSharedEnvironment = type(getgenv) == \"function\"")
    table.insert(lines, "if hasSharedEnvironment then")
    table.insert(lines, "    getgenv().LyraMacroAutoUI = false")

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
    local lines = {}
    appendClientReadyBootstrapLines(lines)
    table.insert(lines, "if game.PlaceId ~= " .. tostring(MATCH_PLACE_ID) .. " then")
    table.insert(lines, "    warn(\"[LyraMacro] Strategy replay skipped: this is not the match place.\")")
    table.insert(lines, "    return")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "local hasSharedEnvironment = type(getgenv) == \"function\"")
    table.insert(lines, "if hasSharedEnvironment then")
    table.insert(lines, "    getgenv().LyraMacroAutoUI = false")

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

    if replay.PrivateServerReturnPermissionPrompted == true then
        table.insert(lines, "LyraMacro._privateServerReturnPermissionPrompted = true")
        table.insert(lines, "if type(getgenv) == \"function\" then")
        table.insert(
            lines,
            "    getgenv()["
                .. formatLuaValue(PRIVATE_SERVER_RETURN_PERMISSION_KEY)
                .. "] = true"
        )
        table.insert(lines, "end")
        table.insert(lines, "")
    end

    local replayMapName = normalizeMapCandidate(mapTitle or replay.TargetMap)
    local privateServerLinkCode = normalizePrivateServerLinkCode(replay.PrivateServerLinkCode)
    local privateServerLinkType = privateServerLinkCode
            and (
                normalizePrivateServerLinkType(replay.PrivateServerLinkType)
                or detectPrivateServerLinkType(replay.PrivateServerLinkCode)
                or PRIVATE_SERVER_LINK_TYPE_SHARE
            )
        or nil

    if replayMapName then
        if privateServerLinkCode then
            local gameInfoOptions = "{ Source = \"elevator\", PrivateServerLinkType = "
                .. formatLuaValue(privateServerLinkType)
                .. " }"
            table.insert(
                lines,
                "LyraMacro:GameInfo("
                    .. formatLuaValue(replayMapName)
                    .. ", "
                    .. formatLuaValue(privateServerLinkCode)
                    .. ", "
                    .. gameInfoOptions
                    .. ")"
            )
        else
            table.insert(lines, "LyraMacro:GameInfo(" .. formatLuaValue(replayMapName) .. ", { Source = \"elevator\" })")
        end

        table.insert(lines, "")
    elseif privateServerLinkCode then
        table.insert(
            lines,
            "LyraMacro:SetPrivateServerLinkCode("
                .. formatLuaValue(privateServerLinkCode)
                .. ", "
                .. formatLuaValue(privateServerLinkType)
                .. ")"
        )
        table.insert(lines, "")
    end

    local privateServerReturnPlaceId = tonumber(replay.PrivateServerReturnPlaceId)
    local privateServerReturnJobId = normalizeServerInstanceId(replay.PrivateServerReturnJobId)

    if privateServerReturnPlaceId == LOBBY_PLACE_ID and privateServerReturnJobId then
        table.insert(
            lines,
            "local returnInstanceSet, returnInstanceMessage = LyraMacro:SetPrivateServerReturnInstance("
                .. tostring(LOBBY_PLACE_ID)
                .. ", "
                .. formatLuaValue(privateServerReturnJobId)
                .. ")"
        )
        table.insert(lines, "if not returnInstanceSet then")
        table.insert(lines, "    warn(\"[LyraMacro] Private-lobby instance was not restored: \" .. tostring(returnInstanceMessage))")
        table.insert(lines, "end")
        table.insert(lines, "")
    end

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

    if normalizePrivateServerLinkCode(replay.PrivateServerLinkCode) then
        local privateServer, privateServerReason = self:ShouldUsePrivateServerWorkflow()
        local lobbyJobId = normalizeServerInstanceId(game.JobId)

        if privateServer and lobbyJobId then
            replay.PrivateServerReturnPlaceId = LOBBY_PLACE_ID
            replay.PrivateServerReturnJobId = lobbyJobId
            print(
                "[LyraMacro] Carrying the live private-lobby instance into the match as a best-effort return route ("
                    .. tostring(privateServerReason)
                    .. ")."
            )
        elseif privateServer then
            warn("[LyraMacro] Private lobby was detected, but its live JobId could not be captured for return.")
        end
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

    -- A new queue request replaces any older replay immediately. If its
    -- preflight fails, an earlier strategy must not remain armed in the
    -- background and enter an elevator unexpectedly.
    self.PendingElevatorReplay = nil
    self.AutoRecordTeleportArmed = false

    local loadoutReady, loadoutMessage = self:PrepareStrategyLoadout(strategy, options)

    if not loadoutReady then
        return false, loadoutMessage
    end

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        return false, recorderMessage
    end

    local targetMap = normalizeMapCandidate(options.MapName or self.SelectedMap)
    local explicitPrivateServerLink = options.PrivateServerLinkCode
        or options.PrivateServerCode
        or options.privateServerLinkCode
        or options.privateServerCode
    local privateServerLinkValue = explicitPrivateServerLink or self.SelectedPrivateServerLinkCode
    local privateServerLinkCode = normalizePrivateServerLinkCode(privateServerLinkValue)
    local privateServerLinkType = privateServerLinkCode
            and (
                normalizePrivateServerLinkType(
                    options.PrivateServerLinkType
                        or options.PrivateServerCodeType
                        or options.privateServerLinkType
                        or options.privateServerCodeType
                )
                or detectPrivateServerLinkType(privateServerLinkValue)
                or (not explicitPrivateServerLink and self.SelectedPrivateServerLinkType)
                or PRIVATE_SERVER_LINK_TYPE_SHARE
            )
        or nil
    self.PendingElevatorReplay = {
        Strategy = cloneStrategy(strategy),
        ExpectedFingerprint = type(expectedFingerprint) == "string" and expectedFingerprint or nil,
        LibraryUrl = options.LibraryUrl,
        Timeout = options.Timeout or self.AutoRecordTimeout,
        TargetMap = targetMap,
        PrivateServerLinkCode = privateServerLinkCode,
        PrivateServerLinkType = privateServerLinkType,
    }
    self.AutoRecordTeleportArmed = false

    if privateServerLinkCode then
        -- Start the non-blocking lobby classification before Opiumware's
        -- permission dialog and elevator entry. Do not wait here: the exact
        -- share-link route works without the optional captured-JobId fallback.
        self:GetServerType()
        self:SetPrivateServerLinkCode(privateServerLinkCode, privateServerLinkType)

        local returnPrepared, returnPreparationMessage = self:PreparePrivateServerReturn()

        if not returnPrepared then
            warn(
                "[LyraMacro] Automatic private-lobby URL return is not ready: "
                    .. tostring(returnPreparationMessage)
                    .. " The live lobby instance will still be carried as a best-effort in-game fallback."
            )
        end

        self.PendingElevatorReplay.PrivateServerReturnPermissionPrompted =
            privateServerReturnPermissionWasPrompted(self)
    end

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

local function isMatchClientReady()
    local cash = LocalPlayer:FindFirstChild("Cash")

    return game:IsLoaded()
        and LocalPlayer.Parent == Players
        and LocalPlayer:FindFirstChild("PlayerGui") ~= nil
        and cash ~= nil
        and (cash:IsA("IntValue") or cash:IsA("NumberValue"))
        and workspace:FindFirstChild("Towers") ~= nil
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
    local stableFingerprint
    local stableSince

    while os.clock() < deadline do
        if isMatchClientReady() then
            local fingerprint = self:DetectMapFingerprint({ Force = true, Silent = true })
            local now = os.clock()

            if fingerprint ~= stableFingerprint then
                stableFingerprint = fingerprint
                stableSince = fingerprint and now or nil
            end

            if fingerprint and stableSince and now - stableSince >= settleTime then
                return self:StartRecording()
            end
        else
            stableFingerprint = nil
            stableSince = nil
        end

        task.wait(pollInterval)
    end

    return false, "Timed out waiting for the destination client and map to finish loading."
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
    local skipMapCheck = type(getgenv) == "function" and getgenv().LyraMacroSkipMapCheck == true
    local requiresFingerprintMatch = type(expectedFingerprint) == "string"
        and expectedFingerprint ~= ""
        and not skipMapCheck
    local stableFingerprint
    local stableSince
    local sawMismatchedFingerprint = false

    while os.clock() < deadline do
        if isMatchClientReady() then
            local fingerprint = self:DetectMapFingerprint({ Force = true, Silent = true })
            local fingerprintReady = fingerprint ~= nil
                and (not requiresFingerprintMatch or fingerprint == expectedFingerprint)
            local now = os.clock()

            if fingerprint and requiresFingerprintMatch and fingerprint ~= expectedFingerprint then
                sawMismatchedFingerprint = true
            end

            if not fingerprintReady then
                stableFingerprint = nil
                stableSince = nil
            else
                if fingerprint ~= stableFingerprint then
                    stableFingerprint = fingerprint
                    stableSince = now
                end

                if stableSince and now - stableSince >= settleTime then
                    local ran, runError = pcall(function()
                        self:Run(strategy)
                    end)

                    if not ran then
                        return false, runError
                    end

                    return true
                end
            end
        else
            stableFingerprint = nil
            stableSince = nil
        end

        task.wait(pollInterval)
    end

    if sawMismatchedFingerprint then
        return false, "Timed out waiting for the destination map to finish loading and match this recorded strategy."
    end

    return false, "Timed out waiting for the destination client and map to finish loading."
end

function LyraMacro:SetManualMapOverrideEnabled(enabled)
    self.ManualMapOverrideEnabled = enabled ~= false

    if not self.ManualMapOverrideEnabled and self.LastDetectedMapSource == "manual override" then
        self.SelectedMap = ""
        self.LastDetectedMapSource = nil
    end

    print(
        "[LyraMacro] Manual map override "
            .. (self.ManualMapOverrideEnabled and "enabled" or "disabled")
            .. "."
    )
    return self.ManualMapOverrideEnabled
end

function LyraMacro:_setDetectedMap(mapName, source, force)
    local normalizedMapName = normalizeMapCandidate(mapName)

    if not normalizedMapName then
        return nil
    end

    local hasManualMap = self.LastDetectedMapSource == "manual"
        or self.LastDetectedMapSource == "manual override"

    if self.SelectedMap ~= "" and self.SelectedMap ~= normalizedMapName and hasManualMap and not force then
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

    if self.ManualMapOverrideEnabled ~= false and type(getgenv) == "function" then
        local override = normalizeMapCandidate(getgenv().LyraMacroMapName)

        if override then
            return self:_setDetectedMap(override, "manual override", true)
        end
    end

    if self.SelectedMap ~= "" and not options.Force then
        return self.SelectedMap, self.LastDetectedMapSource or "configured"
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

    if not options.Silent then
        print("[LyraMacro] Map fingerprint: " .. fingerprint .. " (" .. tostring(source) .. ", " .. tostring(partCount) .. " parts)")
    end

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

    if remoteResultsWereRejected(remoteResults) then
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

function LyraMacro:_getRecordedTroopPerk(troopType, recordingSessionToken)
    if recordingSessionToken == nil or recordingSessionToken ~= self._recordingSessionToken then
        return nil
    end

    local definition = getStrategyPerkDefinition(troopType)

    if not definition then
        return nil
    end

    local troopKey = normalizeLookupKey(definition.Troop)
    local cachedPerk = self.RecordedTroopPerks[troopKey]

    if cachedPerk ~= nil then
        return cachedPerk
    end

    -- The status RemoteFunction is not consistently available in match servers.
    -- Inventory.Troops replicates the same enabled Boolean and remains readable
    -- there, so record from it first and keep the server query as a fallback.
    local troopInventory, cacheError = readCacheValue("Inventory.Troops", 3)

    if recordingSessionToken ~= self._recordingSessionToken then
        return nil
    end

    local enabled = getCachedStrategyPerkStatus(troopInventory, definition)
    local statusError

    if enabled == nil then
        enabled, statusError = queryStrategyPerkStatus(definition)

        if recordingSessionToken ~= self._recordingSessionToken then
            return nil
        end

        if enabled == nil then
            statusError = "Inventory.Troops: "
                .. tostring(cacheError or (definition.ToggleAction .. " was unavailable"))
                .. "; status remote: "
                .. tostring(statusError)
        end
    else
        print("[LyraMacro] Recording " .. definition.Troop .. " perk state from Inventory.Troops.")
    end

    if enabled == nil then
        local message = "Could not verify "
            .. definition.Tier
            .. " perk status for "
            .. definition.Troop
            .. " while recording: "
            .. tostring(statusError)
        self.RecordingPerkVerificationError = message
        warn(
            "[LyraMacro] "
                .. message
                .. ". Replay will preserve the current perk state; re-record after verification to store it exactly."
        )
        return "Unverified"
    end

    local recordedPerk = enabled and definition.Tier or false
    self.RecordedTroopPerks[troopKey] = recordedPerk

    if enabled then
        print("[LyraMacro] Recording " .. definition.Tier .. " perk for " .. definition.Troop .. ".")
    end

    return recordedPerk
end

function LyraMacro:_recordRemoteInvoke(args, remoteResults, observedAt, recordingSessionToken)
    if recordingSessionToken == nil or recordingSessionToken ~= self._recordingSessionToken then
        return
    end

    local category = args[1]
    local action = args[2]
    local categoryKey = normalizeLookupKey(category)
    local actionKey = normalizeLookupKey(action)

    if categoryKey == "troops"
        and (actionKey == "getgoldenperkstatus" or actionKey == "getplatinumperkstatus") then
        return
    end

    if categoryKey == "troops" and actionKey == "abilities" and normalizeLookupKey(args[3]) == "activate" then
        local abilityInfo = args[4]

        if type(abilityInfo) == "table" and self._chainCOAInternalAbilityRequests[abilityInfo] then
            self._chainCOAInternalAbilityRequests[abilityInfo] = nil
            return
        end
    end

    if remoteResultsWereRejected(remoteResults) then
        print("[LyraMacro] Ignored a rejected remote action while recording.")
        return
    end

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
            local abilityObservedAt = tonumber(observedAt) or os.clock()
            local previousAbilityAt = tonumber(self.RecordingLastAbilityAt)
            local delayAnchor = previousAbilityAt or tonumber(self.RecordedTowerPlacedAt[towerIndex])
            local abilityDelay = delayAnchor
                    and roundNumber(math.max(0, abilityObservedAt - delayAnchor))
                or 0
            local abilityDelayFrom = not previousAbilityAt
                    and delayAnchor
                    and ABILITY_DELAY_FROM_TOWER_PLACEMENT
                or nil

            self:_appendRecordedStep({
                action = "ability",
                tower = towerIndex,
                ability = abilityName,
                delay = abilityDelay,
                delay_from = abilityDelayFrom,
            })
            self.RecordingLastAbilityAt = abilityObservedAt
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

        if recordingSessionToken ~= self._recordingSessionToken then
            return
        end

        if not placedTower then
            warn("[LyraMacro] Ignored a place remote because the server did not create a new tower.")
            return
        end

        self.RecordingSeenTowers[placedTower] = true

        local towerIndex = self:_trackNextRecordedTower(troopType, position, existingTowers, placedTower)
        self.RecordedTowerPlacedAt[towerIndex] = tonumber(observedAt) or os.clock()
        local recordedPerk = self:_getRecordedTroopPerk(troopType, recordingSessionToken)

        if recordingSessionToken ~= self._recordingSessionToken then
            return
        end

        self:_appendRecordedStep({
            action = "place",
            troop = troopType,
            skin = skin,
            perk = recordedPerk,
            x = roundNumber(position.X),
            y = roundNumber(position.Y),
            z = roundNumber(position.Z),
            rotation = placementInfo.Rotation,
        })
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

function LyraMacro:_processRemoteObservation(args, remoteResults, observedAt, recordingSessionToken)
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
        self:_recordRemoteInvoke(args, remoteResults, observedAt, recordingSessionToken)
    end)

    if not recorded then
        warn("[LyraMacro] Failed to record remote call: " .. tostring(recordError))
    end
end

function LyraMacro:_reserveRemoteObservation(args, observedAt, recordingSessionToken)
    local observation = {
        Args = args,
        ObservedAt = observedAt,
        RecordingSessionToken = recordingSessionToken,
        Ready = false,
    }
    table.insert(self._remoteObservationQueue, observation)
    return observation
end

function LyraMacro:_drainRemoteObservations()
    if self._remoteObservationWorkerRunning then
        return
    end

    self._remoteObservationWorkerRunning = true
    task.defer(function()
        while self._remoteObservationQueue[1] and self._remoteObservationQueue[1].Ready do
            local observation = table.remove(self._remoteObservationQueue, 1)
            self._activeRemoteObservation = observation

            if not observation.Skip then
                local processed, processError = pcall(function()
                    self:_processRemoteObservation(
                        observation.Args,
                        observation.Results,
                        observation.ObservedAt,
                        observation.RecordingSessionToken
                    )
                end)

                if not processed then
                    warn("[LyraMacro] Failed to process a remote observation: " .. tostring(processError))
                end
            end

            self._activeRemoteObservation = nil
        end

        self._remoteObservationWorkerRunning = false

        if self._remoteObservationQueue[1] and self._remoteObservationQueue[1].Ready then
            self:_drainRemoteObservations()
        end
    end)
end

function LyraMacro:_completeRemoteObservation(observation, remoteResults, skip)
    observation.Results = remoteResults
    observation.Skip = skip == true
    observation.Ready = true
    self:_drainRemoteObservations()
end

function LyraMacro:_hasPendingRecordingObservation(recordingSessionToken)
    local activeObservation = self._activeRemoteObservation

    if activeObservation and activeObservation.RecordingSessionToken == recordingSessionToken then
        return true
    end

    for _, observation in ipairs(self._remoteObservationQueue) do
        if observation.RecordingSessionToken == recordingSessionToken then
            return true
        end
    end

    return false
end

function LyraMacro:_discardQueuedRecordingObservations(recordingSessionToken)
    local discarded = 0

    for index = #self._remoteObservationQueue, 1, -1 do
        if self._remoteObservationQueue[index].RecordingSessionToken == recordingSessionToken then
            table.remove(self._remoteObservationQueue, index)
            discarded += 1
        end
    end

    if discarded > 0 then
        self:_drainRemoteObservations()
    end

    return discarded
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
        local recordingSessionToken = self.IsRecording and self._recordingSessionToken or nil
        local observedAt = recordingSessionToken and os.clock() or nil
        -- Reserve the queue position before InvokeServer yields so concurrent
        -- responses cannot reorder a placement and its first ability.
        local observation = self:_reserveRemoteObservation(args, observedAt, recordingSessionToken)
        local remoteCall = table.pack(pcall(oldNamecall, remote, ...))

        if not remoteCall[1] then
            self:_completeRemoteObservation(observation, nil, true)
            error(remoteCall[2], 0)
        end

        local remoteResults = table.pack(table.unpack(remoteCall, 2, remoteCall.n))
        self:_completeRemoteObservation(observation, remoteResults, false)

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
                self:SetChainCOA(false, { Record = false })
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

function LyraMacro:_watchForAutoStrategyResults()
    self._strategyResultsWatchToken += 1
    local watchToken = self._strategyResultsWatchToken

    if self._strategyResultsConnection then
        pcall(function()
            self._strategyResultsConnection:Disconnect()
        end)
        self._strategyResultsConnection = nil
    end

    self:_cancelLobbyReturn()

    task.spawn(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 30)
        local gameGui = playerGui and (playerGui:FindFirstChild("GameGui") or playerGui:WaitForChild("GameGui", 60))
        local results = gameGui and (gameGui:FindFirstChild("Results") or gameGui:WaitForChild("Results", 60))

        if self._strategyResultsWatchToken ~= watchToken then
            return
        end

        if not results then
            warn("[LyraMacro] Automatic lobby return could not find PlayerGui.GameGui.Results.")
            return
        end

        local finished = false
        local function returnAfterMatch()
            if finished or self._strategyResultsWatchToken ~= watchToken then
                return
            end

            finished = true

            if self._strategyResultsConnection then
                self._strategyResultsConnection:Disconnect()
                self._strategyResultsConnection = nil
            end

            if self.ChainCOAEnabled then
                self:SetChainCOA(false, { Record = false })
            end

            self:_releaseReplayOwnership()

            print("[LyraMacro] Match results are visible. Starting automatic lobby return.")
            task.defer(function()
                local returned, returnMessage = self:ReturnToPrivateServer(results)

                if not returned then
                    warn("[LyraMacro] Automatic lobby return failed: " .. tostring(returnMessage))
                end
            end)
        end

        if results.Visible then
            returnAfterMatch()
            return
        end

        self._strategyResultsConnection = results:GetPropertyChangedSignal("Visible"):Connect(function()
            if results.Visible then
                returnAfterMatch()
            end
        end)
    end)

    if normalizePrivateServerLinkCode(self.SelectedPrivateServerLinkCode) then
        print("[LyraMacro] Automatic private-lobby return armed for match results.")
    else
        print(
            "[LyraMacro] Automatic Return to Lobby flow armed; the game's route is tried once before the direct public TeleportService fallback."
        )
    end
    return true
end

function LyraMacro:StartRecording()
    if self._recordingStopInProgress then
        return false, "The previous recording is still stopping. Wait for its export to finish."
    end

    if self.IsRecording then
        return true, "Recording is already active."
    end

    if self._activeRemoteObservation
        and self._activeRemoteObservation.RecordingSessionToken ~= nil then
        return false, "The previous recording is still finishing a server action. Try again in a moment."
    end

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        warn("[LyraMacro] " .. recorderMessage)
        return false, recorderMessage
    end

    table.clear(self.RecordedStrategy)
    table.clear(self.RecordedTowerIndexes)
    table.clear(self.RecordedTowerUpgradeLevels)
    table.clear(self.RecordedTowerPlacedAt)
    table.clear(self.RecordedTroopPerks)
    table.clear(self.PendingRecordedPlacements)
    self.RecordingSeenTowers = snapshotTowers(getTowersFolder())
    table.clear(self.RecordingConnections)
    self.NextRecordedTowerIndex = 0
    self.RecordingLastAbilityAt = nil
    self.RecordingPerkVerificationError = nil
    self.SelectedMapFingerprint = ""
    self.SelectedMapFingerprintSource = nil
    self.SelectedMapFingerprintPartCount = 0

    if self.LastDetectedMapSource ~= "manual" and self.LastDetectedMapSource ~= "manual override" then
        self.SelectedMap = ""
        self.LastDetectedMapSource = nil
    end

    self._recordingSessionToken += 1
    self.IsRecording = true

    if self.ChainCOAEnabled then
        self:_appendRecordedStep({
            action = "chaincoa",
            enabled = true,
            active_duration = self.ChainCOAActiveDuration,
            handoff_delay = self.ChainCOAHandoffDelay,
            retry_delay = self.ChainCOARetryDelay,
        })
    end

    self._resultsWatchToken += 1
    self:DetectMap({ Silent = true })
    self:DetectMapFingerprint({ Silent = true, Force = true })
    self:_watchForMatchResults(self._resultsWatchToken)

    print("[LyraMacro] Strategy recording started.")
    return true
end

function LyraMacro:StopRecording()
    if self._recordingStopInProgress then
        while self._recordingStopInProgress do
            task.wait()
        end

        return self:GetRecordedStrategy(), self:GetRecordedStrategyScriptSource(), self.LastStrategyExport
    end

    if not self.IsRecording then
        return self:GetRecordedStrategy(), self:GetRecordedStrategyScriptSource(), self.LastStrategyExport
    end

    self._recordingStopInProgress = true
    local stopResults = table.pack(xpcall(function()
        local recordingSessionToken = self._recordingSessionToken
        self.IsRecording = false

        local drainDeadline = os.clock() + RECORD_STOP_DRAIN_TIMEOUT

        while self:_hasPendingRecordingObservation(recordingSessionToken) and os.clock() < drainDeadline do
            task.wait()
        end

        local observationsDrained = not self:_hasPendingRecordingObservation(recordingSessionToken)

        if not observationsDrained then
            self:_discardQueuedRecordingObservations(recordingSessionToken)
        end

        self._recordingSessionToken += 1
        self.RecordingLastAbilityAt = nil
        self._resultsWatchToken += 1

        if not observationsDrained then
            warn(
                "[LyraMacro] Timed out waiting for the final recorded action; "
                    .. "it was discarded to keep the exported strategy consistent."
            )
        end

        for _, connection in ipairs(self.RecordingConnections) do
            connection:Disconnect()
        end

        table.clear(self.RecordingConnections)
        table.clear(self.PendingRecordedPlacements)
        table.clear(self.RecordingSeenTowers)
        table.clear(self.RecordedTowerPlacedAt)

        if self.SelectedMap == "" then
            self:DetectMap({ Silent = true })
        end

        self:DetectMapFingerprint({ Silent = true, Force = true })

        local recordedStrategy = self:GetRecordedStrategy()
        local actionCounts = {
            ability = 0,
            chaincoa = 0,
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
                .. tostring(actionCounts.chaincoa)
                .. " Chain COA settings, "
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

        if self.RecordingPerkVerificationError then
            warn("[LyraMacro] Recorder perk verification warning: " .. tostring(self.RecordingPerkVerificationError))
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
    end, debug.traceback))
    self._recordingStopInProgress = false

    if not stopResults[1] then
        error(stopResults[2], 0)
    end

    return table.unpack(stopResults, 2, stopResults.n)
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
        "if not game:IsLoaded() then",
        "    game.Loaded:Wait()",
        "end",
        "",
        "local Players = game:GetService(\"Players\")",
        "local LocalPlayer = Players.LocalPlayer",
        "while not LocalPlayer do",
        "    task.wait()",
        "    LocalPlayer = Players.LocalPlayer",
        "end",
        "LocalPlayer:WaitForChild(\"PlayerGui\")",
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
        local gameInfoOptions = "{ Source = " .. formatLuaValue(self.LastDetectedMapSource or "recorded")

        if type(self.SelectedPrivateServerLinkCode) == "string" and self.SelectedPrivateServerLinkCode ~= "" then
            gameInfoOptions = gameInfoOptions
                .. ", PrivateServerLinkType = "
                .. formatLuaValue(self.SelectedPrivateServerLinkType or PRIVATE_SERVER_LINK_TYPE_SHARE)
        end

        gameInfoOptions = gameInfoOptions .. " }"

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
    frame.Size = UDim2.new(0, 280, 0, 140)
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

    local serverStatusText, serverStatusSource = self:GetServerStatusText()
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -20, 0, 54)
    status.Position = UDim2.new(0, 10, 0, 36)
    status.BackgroundTransparency = 1
    status.Text = reason
            and ("Fallback UI: " .. tostring(reason) .. "\n" .. serverStatusText)
        or (serverStatusText .. " Ready to record.")
    status.TextColor3 = Color3.fromRGB(170, 170, 180)
    status.TextSize = 11
    status.Font = Enum.Font.Gotham
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local initialStatusText = status.Text

    task.spawn(function()
        self:WaitForServerContext(PRIVATE_SERVER_PUBLIC_SETTLE_TIMEOUT)

        if status.Parent and status.Text == initialStatusText then
            local refreshedServerStatusText = self:GetServerStatusText()
            status.Text = reason
                    and ("Fallback UI: " .. tostring(reason) .. "\n" .. refreshedServerStatusText)
                or (refreshedServerStatusText .. " Ready to record.")
        end
    end)

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
        status.Text = "Recording placements with skins/perks, upgrades, timed abilities, Chain COA, sells, and wave skips."
    end)

    self.RecorderWindow = screenGui
    print("[LyraMacro] " .. serverStatusText .. " Detection source: " .. tostring(serverStatusSource) .. ".")
    warn("[LyraMacro] Lyra UI failed to load; opened fallback recorder UI instead. " .. tostring(reason))

    return screenGui
end

function LyraMacro:CreateRecorderWindow(config)
    config = config or {}

    local configuredManualMapOverride = config.ManualMapOverrideEnabled

    if configuredManualMapOverride == nil then
        configuredManualMapOverride = config.ManualMapOverride
    end

    if configuredManualMapOverride ~= nil then
        self:SetManualMapOverrideEnabled(configuredManualMapOverride ~= false)
    end

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
        local serverStatusText, serverStatusSource = self:GetServerStatusText()
        local descriptionLabel = strategyTab:CreateLabel("Record mode votes, placements, upgrades, timed abilities, Chain COA, sells, and wave skips.")
        local serverStatusLabel = strategyTab:CreateLabel(serverStatusText)

        task.spawn(function()
            self:WaitForServerContext(PRIVATE_SERVER_PUBLIC_SETTLE_TIMEOUT)

            if serverStatusLabel and type(serverStatusLabel.UpdateText) == "function" then
                local refreshedServerStatusText = self:GetServerStatusText()
                serverStatusLabel.UpdateText(refreshedServerStatusText)
            end
        end)

        print("[LyraMacro] " .. serverStatusText .. " Detection source: " .. tostring(serverStatusSource) .. ".")
        strategyTab:CreateToggle("Manual map override", self.ManualMapOverrideEnabled ~= false, function(enabled)
            local overrideChanged = (self.ManualMapOverrideEnabled ~= false) ~= enabled
            self:SetManualMapOverrideEnabled(enabled)

            if not overrideChanged then
                return
            end

            local mapName, mapSource = self:DetectMap({ Silent = true })

            if enabled and mapSource == "manual override" then
                descriptionLabel.UpdateText("Manual map override: " .. tostring(mapName) .. ".")
                window:Notify("Map Override Enabled", tostring(mapName), 3)
            elseif enabled then
                descriptionLabel.UpdateText(
                    "Manual map override is enabled by default. Set getgenv().LyraMacroMapName to use it; automatic detection remains the fallback."
                )
            else
                descriptionLabel.UpdateText(
                    mapName
                            and ("Manual map override disabled. Detected map: " .. tostring(mapName) .. " (" .. tostring(mapSource) .. ").")
                        or "Manual map override disabled."
                )
            end
        end)
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

        strategyTab:CreateTextbox("Private return link code (optional)", self.SelectedPrivateServerLinkCode or "Not needed for detection", function(linkCode)
            local configuredCode = self:SetPrivateServerLinkCode(linkCode)

            if configuredCode then
                descriptionLabel.UpdateText("Optional return link saved. Private-server detection remains automatic.")
                window:Notify("Private Return Link Set", "Used only to target the same lobby after a match.", 3)
            else
                descriptionLabel.UpdateText("Return link cleared. Private-server detection still runs automatically.")
            end
        end)

        strategyTab:CreateToggle("Chain COA", self.ChainCOAEnabled, function(enabled)
            local chained, message = self:SetChainCOA(enabled)

            if chained then
                if enabled then
                    descriptionLabel.UpdateText("Chain COA waits for 3 detected level 2 Commanders/Lifeguards, checks each remote response, holds for 6 seconds, then uses a 2 second handoff.")
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
            descriptionLabel.UpdateText("Recording placements with skins/perks, upgrades, timed abilities, Chain COA, sells, and wave skips.")
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
        local placementRequestedAt = os.clock()
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
            -- This attempt created the tower; rejected cash-wait retries never
            -- become the placement anchor for its first timed ability.
            self.SpawnedTowerPlacedAt[self.NextTowerIndex] = placementRequestedAt
            self.SpawnedTowerUpgradeLevels[self.NextTowerIndex] = getTowerUpgradeLevel(placedTower) or 0
            self.KnownTowerUpgradeLevels[placedTower] = self.SpawnedTowerUpgradeLevels[self.NextTowerIndex]
            self.KnownTowerTroops[placedTower] = troopType
            print("[LyraMacro] Registered tower #" .. self.NextTowerIndex .. " (" .. tostring(troopType) .. " / " .. skin .. ").")
            return placedTower
        end

        if requestWasAccepted then
            error("[LyraMacro] Place " .. tostring(troopType) .. " was accepted but its new workspace.Towers child did not replicate within " .. tostring(REPLAY_ACCEPTED_RECOVERY_TIMEOUT) .. " seconds. Replay stopped before issuing a duplicate placement.", 2)
        end

        if attempt == 1 or attempt % 10 == 0 then
            warn(
                "[LyraMacro] Place "
                    .. tostring(troopType)
                    .. " received no tower. Server response: "
                    .. summarizeRemoteResponse(responseOrError)
            )
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
    self.SpawnedTowerPlacedAt[towerIndex] = nil
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

local function makeGuiDraggable(handle, target, onDrag)
    handle.Active = true

    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    local activeInputConnection
    local connections = {}

    local function track(connection)
        table.insert(connections, connection)
        return connection
    end

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

        if onDrag and (nextX ~= startPosition.X or nextY ~= startPosition.Y) then
            onDrag()
        end

        target.Position = UDim2.fromOffset(
            nextX + target.AnchorPoint.X * targetSize.X,
            nextY + target.AnchorPoint.Y * targetSize.Y
        )
    end

    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = target.AbsolutePosition

        if activeInputConnection then
            activeInputConnection:Disconnect()
            activeInputConnection = nil
        end

        local changedConnection
        changedConnection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false

                if activeInputConnection == changedConnection then
                    activeInputConnection = nil
                end

                changedConnection:Disconnect()
            end
        end)
        activeInputConnection = changedConnection
    end))

    track(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            updatePosition(input)
        end
    end))

    return function()
        dragging = false

        if activeInputConnection then
            activeInputConnection:Disconnect()
            activeInputConnection = nil
        end

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end

        table.clear(connections)
    end
end

local function clampGuiToViewport(target)
    local camera = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local targetSize = target.AbsoluteSize
    local currentPosition = target.AbsolutePosition
    local minX = math.min(0, viewportSize.X - targetSize.X)
    local maxX = math.max(0, viewportSize.X - targetSize.X)
    local minY = math.min(0, viewportSize.Y - targetSize.Y)
    local maxY = math.max(0, viewportSize.Y - targetSize.Y)
    local nextX = math.clamp(currentPosition.X, minX, maxX)
    local nextY = math.clamp(currentPosition.Y, minY, maxY)

    target.Position = UDim2.fromOffset(
        nextX + target.AnchorPoint.X * targetSize.X,
        nextY + target.AnchorPoint.Y * targetSize.Y
    )
end

local STRATEGY_LOGGER_COLORS = {
    Background = Color3.fromRGB(13, 15, 19),
    Header = Color3.fromRGB(20, 22, 27),
    Card = Color3.fromRGB(27, 30, 36),
    CardStroke = Color3.fromRGB(54, 59, 69),
    Text = Color3.fromRGB(244, 246, 250),
    Muted = Color3.fromRGB(151, 157, 170),
    Faint = Color3.fromRGB(111, 119, 132),
    Lavender = Color3.fromRGB(201, 171, 255),
    Cyan = Color3.fromRGB(112, 203, 239),
    Mint = Color3.fromRGB(91, 224, 168),
    Amber = Color3.fromRGB(239, 197, 105),
    Coral = Color3.fromRGB(255, 123, 120),
}

-- Sprite metadata from tijnepema/lucide-roblox (MIT); Lucide icons are ISC licensed.
-- Keep this subset local because AutoStrategy runs without loading the full Lyra UI.
local STRATEGY_LOGGER_LUCIDE_ICONS = {
    ["arrow-right"] = { 18786021641, 48, 48, 845, 783 },
    ["chevron-up"] = { 18786022917, 48, 48, 294, 833 },
    ["circle-check"] = { 18786022917, 48, 48, 686, 539 },
    ["list-checks"] = { 18786025432, 48, 48, 98, 98 },
    ["mouse-pointer-click"] = { 18786025432, 48, 48, 392, 392 },
    play = { 18786025432, 48, 48, 784, 392 },
    ["radio-tower"] = { 18786025432, 48, 48, 539, 735 },
    terminal = { 18786026913, 48, 48, 196, 735 },
    ["trash-2"] = { 18786026913, 48, 48, 98, 931 },
    ["triangle-alert"] = { 18786026913, 48, 48, 539, 539 },
    upload = { 18786026913, 48, 48, 686, 490 },
    zap = { 18786026913, 48, 48, 588, 882 },
}

local function setStrategyLoggerIcon(icon, iconName)
    if not icon then
        return false
    end

    local resolvedIconName = STRATEGY_LOGGER_LUCIDE_ICONS[iconName] and iconName or "terminal"
    local sprite = STRATEGY_LOGGER_LUCIDE_ICONS[resolvedIconName]

    icon.Image = "rbxassetid://" .. tostring(sprite[1])
    icon.ImageRectSize = Vector2.new(sprite[2], sprite[3])
    icon.ImageRectOffset = Vector2.new(sprite[4], sprite[5])
    icon:SetAttribute("LucideIcon", resolvedIconName)
    return true
end

local function createStrategyLoggerIcon(parent, iconName, properties)
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.ScaleType = Enum.ScaleType.Fit

    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            icon[property] = value
        end
    end

    setStrategyLoggerIcon(icon, iconName)
    icon.Parent = parent
    return icon
end

local function addStrategyLoggerCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function addStrategyLoggerStroke(instance, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = instance
    return stroke
end

local function addStrategyLoggerGradient(instance, firstColor, secondColor, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, firstColor),
        ColorSequenceKeypoint.new(1, secondColor),
    })
    gradient.Rotation = rotation or 0
    gradient.Parent = instance
    return gradient
end

local function getStrategyLoggerAppearance(message)
    local normalized = string.upper(tostring(message))
    local actionText = string.match(normalized, "^%d+%s*/%s*%d+%s+(.+)$") or normalized

    if string.match(normalized, "^STRATEGY FAILED") or string.match(actionText, "^ERROR") then
        return "triangle-alert", STRATEGY_LOGGER_COLORS.Coral
    elseif string.match(normalized, "^STRATEGY COMPLETED") then
        return "circle-check", STRATEGY_LOGGER_COLORS.Mint
    elseif string.match(normalized, "^STRATEGY STARTED") then
        return "play", STRATEGY_LOGGER_COLORS.Lavender
    elseif string.match(actionText, "^ENABLE%s+CHAIN%s+COA")
        or string.match(actionText, "^DISABLE%s+CHAIN%s+COA") then
        return "radio-tower", STRATEGY_LOGGER_COLORS.Mint
    elseif string.match(actionText, "^ACTIVATE%s+") then
        return "zap", STRATEGY_LOGGER_COLORS.Mint
    elseif string.match(actionText, "^PLACE%s+") then
        return "mouse-pointer-click", STRATEGY_LOGGER_COLORS.Lavender
    elseif string.match(actionText, "^UPGRADE%s+") then
        return "upload", STRATEGY_LOGGER_COLORS.Cyan
    elseif string.match(actionText, "^SELL%s+") then
        return "trash-2", STRATEGY_LOGGER_COLORS.Coral
    elseif string.match(actionText, "^SKIP%s+") then
        return "arrow-right", STRATEGY_LOGGER_COLORS.Amber
    elseif string.match(actionText, "^VOTE%s+") then
        return "list-checks", STRATEGY_LOGGER_COLORS.Cyan
    end

    return "terminal", STRATEGY_LOGGER_COLORS.Muted
end

local function parseStrategyLoggerMessage(message)
    local text = tostring(message)
    local stepNumber, totalActions, actionText = string.match(text, "^(%d+)%s*/%s*(%d+)%s+(.+)$")
    local normalized = string.upper(text)
    local startedActions = string.match(normalized, "^STRATEGY STARTED%s*%-%s*(%d+)%s+ACTIONS$")

    return {
        Text = actionText or text,
        Step = tonumber(stepNumber),
        Total = tonumber(totalActions),
        StartedTotal = tonumber(startedActions),
        Completed = string.match(normalized, "^STRATEGY COMPLETED") ~= nil,
        Failed = string.match(normalized, "^STRATEGY FAILED") ~= nil,
    }
end

local function formatStrategyLoggerTime(startedAt)
    local elapsed = math.max(0, math.floor(os.clock() - startedAt))
    local minutes = math.floor(elapsed / 60)
    local seconds = elapsed % 60
    return string.format("%02d:%02d", minutes, seconds)
end

local function setStrategyLoggerProgress(logger, progress)
    if not logger.ProgressFill or not logger.ProgressFill.Parent then
        return
    end

    logger.ProgressFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
end

local function setStrategyLoggerRuntimeStatus(logger, text, iconName, color)
    if logger.LiveText and logger.LiveText.Parent then
        logger.LiveText.Text = text
        logger.LiveText.TextColor3 = color
    end

    if logger.LiveIcon and logger.LiveIcon.Parent then
        setStrategyLoggerIcon(logger.LiveIcon, iconName)
        logger.LiveIcon.ImageColor3 = color
    end
end

local function getStrategyLoggerViewportLayout()
    local camera = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local frameMargin = viewportSize.X < 360 and 8 or 16
    local topMargin = viewportSize.Y < 400 and 8 or 16
    local frameWidth = math.max(1, math.min(430, viewportSize.X - frameMargin * 2))
    local frameHeight = math.max(1, math.min(360, viewportSize.Y - topMargin * 2))

    return {
        Camera = camera,
        FrameMargin = frameMargin,
        TopMargin = topMargin,
        Width = frameWidth,
        Height = frameHeight,
        Compact = frameWidth < 340,
    }
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

    local viewportLayout = getStrategyLoggerViewportLayout()
    local frameWidth = viewportLayout.Width
    local frameHeight = viewportLayout.Height
    local compactLayout = viewportLayout.Compact

    local frame = Instance.new("Frame")
    frame.Name = "ActionLog"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -viewportLayout.FrameMargin, 0, viewportLayout.TopMargin)
    frame.Size = UDim2.fromOffset(frameWidth, frameHeight)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ZIndex = 1000
    frame.Parent = screenGui

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Position = UDim2.fromOffset(7, 8)
    shadow.Size = UDim2.fromScale(1, 1)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.55
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 999
    shadow.Parent = frame
    addStrategyLoggerCorner(shadow, 8)

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Background
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.ZIndex = 1000
    panel.Parent = frame
    addStrategyLoggerCorner(panel, 8)
    addStrategyLoggerStroke(panel, STRATEGY_LOGGER_COLORS.CardStroke, 0.08, 1)

    local topBanner = Instance.new("Frame")
    topBanner.Name = "TopBanner"
    topBanner.Size = UDim2.new(1, 0, 0, 2)
    topBanner.BackgroundColor3 = Color3.new(1, 1, 1)
    topBanner.BorderSizePixel = 0
    topBanner.ZIndex = 1005
    topBanner.Parent = panel
    addStrategyLoggerGradient(
        topBanner,
        STRATEGY_LOGGER_COLORS.Lavender,
        STRATEGY_LOGGER_COLORS.Cyan,
        0
    )

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 54)
    header.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Header
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 1001
    header.Parent = panel

    local brandBadge = Instance.new("Frame")
    brandBadge.Name = "BrandBadge"
    brandBadge.Position = UDim2.fromOffset(14, 13)
    brandBadge.Size = UDim2.fromOffset(28, 28)
    brandBadge.BackgroundColor3 = Color3.new(1, 1, 1)
    brandBadge.BorderSizePixel = 0
    brandBadge.ZIndex = 1002
    brandBadge.Parent = header
    addStrategyLoggerCorner(brandBadge, 6)
    addStrategyLoggerGradient(
        brandBadge,
        STRATEGY_LOGGER_COLORS.Lavender,
        STRATEGY_LOGGER_COLORS.Cyan,
        35
    )

    createStrategyLoggerIcon(brandBadge, "terminal", {
        Name = "BrandIcon",
        Position = UDim2.new(0.5, -8, 0.5, -8),
        Size = UDim2.fromOffset(16, 16),
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 1003,
    })

    local headerText = Instance.new("TextLabel")
    headerText.Name = "Title"
    headerText.Position = UDim2.fromOffset(52, compactLayout and 18 or 10)
    headerText.Size = compactLayout and UDim2.new(1, -130, 0, 17) or UDim2.new(1, -190, 0, 17)
    headerText.BackgroundTransparency = 1
    headerText.Text = "LYRA AUTOSTRATEGIES"
    headerText.TextColor3 = STRATEGY_LOGGER_COLORS.Text
    headerText.TextSize = 11
    headerText.Font = Enum.Font.MontserratBold
    headerText.TextXAlignment = Enum.TextXAlignment.Left
    headerText.TextTruncate = Enum.TextTruncate.AtEnd
    headerText.ZIndex = 1002
    headerText.Parent = header

    local headerSubtitle = Instance.new("TextLabel")
    headerSubtitle.Name = "Subtitle"
    headerSubtitle.Position = UDim2.fromOffset(52, 28)
    headerSubtitle.Size = UDim2.new(1, -190, 0, 14)
    headerSubtitle.BackgroundTransparency = 1
    headerSubtitle.Text = "EXECUTION CONSOLE"
    headerSubtitle.TextColor3 = STRATEGY_LOGGER_COLORS.Faint
    headerSubtitle.TextSize = 9
    headerSubtitle.Font = Enum.Font.Code
    headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    headerSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
    headerSubtitle.Visible = not compactLayout
    headerSubtitle.ZIndex = 1002
    headerSubtitle.Parent = header

    local liveStatus = Instance.new("Frame")
    liveStatus.Name = "LiveStatus"
    liveStatus.AnchorPoint = Vector2.new(1, 0.5)
    liveStatus.Position = UDim2.new(1, -49, 0.5, 0)
    liveStatus.Size = compactLayout and UDim2.fromOffset(24, 24) or UDim2.fromOffset(82, 24)
    liveStatus.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Card
    liveStatus.BorderSizePixel = 0
    liveStatus.ZIndex = 1002
    liveStatus.Parent = header
    addStrategyLoggerCorner(liveStatus, 12)
    addStrategyLoggerStroke(liveStatus, STRATEGY_LOGGER_COLORS.CardStroke, 0.25, 1)

    local liveIcon = createStrategyLoggerIcon(liveStatus, "play", {
        Name = "Icon",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = compactLayout and UDim2.new(0.5, -6, 0.5, 0) or UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        ImageColor3 = STRATEGY_LOGGER_COLORS.Mint,
        ZIndex = 1003,
    })

    local liveText = Instance.new("TextLabel")
    liveText.Name = "Text"
    liveText.Position = UDim2.fromOffset(22, 0)
    liveText.Size = UDim2.new(1, -28, 1, 0)
    liveText.BackgroundTransparency = 1
    liveText.Text = "LIVE"
    liveText.TextColor3 = STRATEGY_LOGGER_COLORS.Mint
    liveText.TextSize = 9
    liveText.Font = Enum.Font.Code
    liveText.TextXAlignment = Enum.TextXAlignment.Left
    liveText.Visible = not compactLayout
    liveText.ZIndex = 1003
    liveText.Parent = liveStatus

    local collapseButton = Instance.new("TextButton")
    collapseButton.Name = "Collapse"
    collapseButton.AnchorPoint = Vector2.new(1, 0.5)
    collapseButton.Position = UDim2.new(1, -12, 0.5, 0)
    collapseButton.Size = compactLayout and UDim2.fromOffset(32, 32) or UDim2.fromOffset(28, 28)
    collapseButton.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Card
    collapseButton.BorderSizePixel = 0
    collapseButton.AutoButtonColor = false
    collapseButton.Text = ""
    collapseButton.ZIndex = 1003
    collapseButton.Parent = header
    addStrategyLoggerCorner(collapseButton, 6)
    addStrategyLoggerStroke(collapseButton, STRATEGY_LOGGER_COLORS.CardStroke, 0.25, 1)

    local collapseIcon = createStrategyLoggerIcon(collapseButton, "chevron-up", {
        Name = "Icon",
        Position = UDim2.new(0.5, -7, 0.5, -7),
        Size = UDim2.fromOffset(14, 14),
        ImageColor3 = STRATEGY_LOGGER_COLORS.Muted,
        ZIndex = 1004,
    })

    local headerDivider = Instance.new("Frame")
    headerDivider.Name = "Divider"
    headerDivider.AnchorPoint = Vector2.new(0, 1)
    headerDivider.Position = UDim2.new(0, 0, 1, 0)
    headerDivider.Size = UDim2.new(1, 0, 0, 1)
    headerDivider.BackgroundColor3 = STRATEGY_LOGGER_COLORS.CardStroke
    headerDivider.BackgroundTransparency = 0.35
    headerDivider.BorderSizePixel = 0
    headerDivider.ZIndex = 1002
    headerDivider.Parent = header

    local content = Instance.new("CanvasGroup")
    content.Name = "Content"
    content.Position = UDim2.fromOffset(0, 54)
    content.Size = UDim2.new(1, 0, 1, -54)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.GroupTransparency = 0
    content.ZIndex = 1001
    content.Parent = panel

    local progressPanel = Instance.new("Frame")
    progressPanel.Name = "Progress"
    progressPanel.Size = UDim2.new(1, 0, 0, 52)
    progressPanel.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Background
    progressPanel.BorderSizePixel = 0
    progressPanel.ZIndex = 1001
    progressPanel.Parent = content

    local statusText = Instance.new("TextLabel")
    statusText.Name = "Status"
    statusText.Position = UDim2.fromOffset(14, 8)
    statusText.Size = UDim2.new(0.6, -14, 0, 17)
    statusText.BackgroundTransparency = 1
    statusText.Text = "WAITING FOR ACTIONS"
    statusText.TextColor3 = STRATEGY_LOGGER_COLORS.Lavender
    statusText.TextSize = 9
    statusText.Font = Enum.Font.Code
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextTruncate = Enum.TextTruncate.AtEnd
    statusText.ZIndex = 1002
    statusText.Parent = progressPanel

    local progressText = Instance.new("TextLabel")
    progressText.Name = "Count"
    progressText.AnchorPoint = Vector2.new(1, 0)
    progressText.Position = UDim2.new(1, -14, 0, 8)
    progressText.Size = UDim2.new(0.4, -14, 0, 17)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0 ACTIONS"
    progressText.TextColor3 = STRATEGY_LOGGER_COLORS.Faint
    progressText.TextSize = 9
    progressText.Font = Enum.Font.Code
    progressText.TextXAlignment = Enum.TextXAlignment.Right
    progressText.TextTruncate = Enum.TextTruncate.AtEnd
    progressText.ZIndex = 1002
    progressText.Parent = progressPanel

    local progressTrack = Instance.new("Frame")
    progressTrack.Name = "Track"
    progressTrack.Position = UDim2.fromOffset(14, 34)
    progressTrack.Size = UDim2.new(1, -28, 0, 4)
    progressTrack.BackgroundColor3 = STRATEGY_LOGGER_COLORS.CardStroke
    progressTrack.BackgroundTransparency = 0.3
    progressTrack.BorderSizePixel = 0
    progressTrack.ClipsDescendants = true
    progressTrack.ZIndex = 1002
    progressTrack.Parent = progressPanel
    addStrategyLoggerCorner(progressTrack, 4)

    local progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.new(1, 1, 1)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 1003
    progressFill.Parent = progressTrack
    addStrategyLoggerCorner(progressFill, 4)
    addStrategyLoggerGradient(
        progressFill,
        STRATEGY_LOGGER_COLORS.Lavender,
        STRATEGY_LOGGER_COLORS.Cyan,
        0
    )

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Actions"
    scroll.Position = UDim2.new(0, 8, 0, 52)
    scroll.Size = UDim2.new(1, -16, 1, -60)
    scroll.BackgroundColor3 = Color3.fromRGB(13, 16, 20)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = STRATEGY_LOGGER_COLORS.Cyan
    scroll.ScrollBarImageTransparency = 0.15
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ZIndex = 1001
    scroll.Parent = content
    addStrategyLoggerCorner(scroll, 6)
    addStrategyLoggerStroke(scroll, STRATEGY_LOGGER_COLORS.CardStroke, 0.45, 1)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 7)
    padding.PaddingRight = UDim.new(0, 7)
    padding.Parent = scroll

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)

    local expandedSize = frame.Size
    local collapsed = false
    local viewportConnection
    local currentCameraConnection
    local ancestryConnection
    local collapseSizeTween
    local collapseContentTween
    local collapseIconTween
    local collapseHoverTween
    local collapseCompletionConnection
    local collapseTransitionToken = 0
    local loggerWasDragged = false

    local function cancelCollapseAnimation()
        if collapseCompletionConnection then
            collapseCompletionConnection:Disconnect()
            collapseCompletionConnection = nil
        end

        for _, tween in ipairs({ collapseSizeTween, collapseContentTween, collapseIconTween }) do
            if tween then
                pcall(function()
                    tween:Cancel()
                end)
            end
        end

        collapseSizeTween = nil
        collapseContentTween = nil
        collapseIconTween = nil
    end

    local function clampLoggerAfterLayout()
        task.defer(function()
            if frame.Parent then
                clampGuiToViewport(frame)
            end
        end)
    end

    local function setCollapsed(nextCollapsed, animate)
        collapsed = nextCollapsed == true
        collapseTransitionToken += 1
        local transitionToken = collapseTransitionToken
        cancelCollapseAnimation()

        content.Visible = true
        collapseButton:SetAttribute("Collapsed", collapsed)
        collapseButton:SetAttribute("Action", collapsed and "Expand console" or "Collapse console")

        local targetSize = collapsed and UDim2.fromOffset(frameWidth, 54) or expandedSize
        local targetTransparency = collapsed and 1 or 0
        local targetRotation = collapsed and 180 or 0

        if not animate then
            frame.Size = targetSize
            content.GroupTransparency = targetTransparency
            content.Visible = not collapsed

            if collapseIcon then
                collapseIcon.Rotation = targetRotation
            end

            clampLoggerAfterLayout()
            return
        end

        local tweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        collapseSizeTween = TweenService:Create(frame, tweenInfo, { Size = targetSize })
        collapseContentTween = TweenService:Create(content, tweenInfo, {
            GroupTransparency = targetTransparency,
        })

        if collapseIcon then
            collapseIconTween = TweenService:Create(collapseIcon, tweenInfo, {
                Rotation = targetRotation,
            })
            collapseIconTween:Play()
        end

        local activeSizeTween = collapseSizeTween
        local completionConnection
        completionConnection = activeSizeTween.Completed:Connect(function(playbackState)
            if completionConnection then
                completionConnection:Disconnect()
            end

            if collapseCompletionConnection == completionConnection then
                collapseCompletionConnection = nil
            end

            if
                collapseTransitionToken ~= transitionToken
                or playbackState ~= Enum.PlaybackState.Completed
            then
                return
            end

            collapseSizeTween = nil
            collapseContentTween = nil
            collapseIconTween = nil
            content.Visible = not collapsed
            clampLoggerAfterLayout()
        end)
        collapseCompletionConnection = completionConnection

        collapseContentTween:Play()
        activeSizeTween:Play()
    end

    local function applyCompactLayout(nextCompactLayout)
        compactLayout = nextCompactLayout
        headerText.Position = UDim2.fromOffset(52, compactLayout and 18 or 10)
        headerText.Size = compactLayout and UDim2.new(1, -130, 0, 17) or UDim2.new(1, -190, 0, 17)
        headerSubtitle.Visible = not compactLayout
        liveStatus.Size = compactLayout and UDim2.fromOffset(24, 24) or UDim2.fromOffset(82, 24)
        collapseButton.Size = compactLayout and UDim2.fromOffset(32, 32) or UDim2.fromOffset(28, 28)

        if liveIcon then
            liveIcon.Position = compactLayout and UDim2.new(0.5, -6, 0.5, 0) or UDim2.new(0, 8, 0.5, 0)
        end

        liveText.Visible = not compactLayout

        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") and string.match(child.Name, "^Action%d+$") then
                local childActionText = child:FindFirstChild("ActionText")
                local childTimestamp = child:FindFirstChild("Timestamp")

                if childActionText then
                    childActionText.Size = compactLayout and UDim2.new(1, -100, 1, 0)
                        or UDim2.new(1, -148, 1, 0)
                end

                if childTimestamp then
                    childTimestamp.Visible = not compactLayout
                end
            end
        end

        local activeLogger = self.StrategyLogger

        if activeLogger and activeLogger.Gui == screenGui then
            activeLogger.CompactLayout = compactLayout
        end
    end

    local function applyViewportLayout()
        local nextLayout = getStrategyLoggerViewportLayout()
        frameWidth = nextLayout.Width
        frameHeight = nextLayout.Height
        expandedSize = UDim2.fromOffset(frameWidth, frameHeight)
        collapseTransitionToken += 1
        cancelCollapseAnimation()
        frame.Size = collapsed and UDim2.fromOffset(frameWidth, 54) or expandedSize
        content.GroupTransparency = collapsed and 1 or 0
        content.Visible = not collapsed

        if collapseIcon then
            collapseIcon.Rotation = collapsed and 180 or 0
        end

        if not loggerWasDragged then
            frame.Position = UDim2.new(1, -nextLayout.FrameMargin, 0, nextLayout.TopMargin)
        end

        applyCompactLayout(nextLayout.Compact)
        clampLoggerAfterLayout()
    end

    local function bindCurrentCamera()
        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end

        local currentCamera = workspace.CurrentCamera

        if currentCamera then
            viewportConnection = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyViewportLayout)
        end

        applyViewportLayout()
    end

    collapseButton.MouseButton1Click:Connect(function()
        setCollapsed(not collapsed, true)
    end)

    collapseButton.MouseEnter:Connect(function()
        if not collapseIcon then
            return
        end

        if collapseHoverTween then
            collapseHoverTween:Cancel()
        end

        collapseHoverTween = TweenService:Create(
            collapseIcon,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = STRATEGY_LOGGER_COLORS.Text }
        )
        collapseHoverTween:Play()
    end)

    collapseButton.MouseLeave:Connect(function()
        if not collapseIcon then
            return
        end

        if collapseHoverTween then
            collapseHoverTween:Cancel()
        end

        collapseHoverTween = TweenService:Create(
            collapseIcon,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = STRATEGY_LOGGER_COLORS.Muted }
        )
        collapseHoverTween:Play()
    end)

    collapseButton:SetAttribute("Collapsed", false)
    collapseButton:SetAttribute("Action", "Collapse console")
    local cleanupDrag = makeGuiDraggable(header, frame, function()
        loggerWasDragged = true
    end)

    self.StrategyLogger = {
        Gui = screenGui,
        Frame = frame,
        Panel = panel,
        Header = header,
        TopBanner = topBanner,
        Scroll = scroll,
        Layout = layout,
        Content = content,
        StatusText = statusText,
        ProgressText = progressText,
        ProgressFill = progressFill,
        LiveText = liveText,
        LiveIcon = liveIcon,
        CollapseButton = collapseButton,
        CollapseIcon = collapseIcon,
        Entries = 0,
        StartedAt = os.clock(),
        TotalActions = nil,
        CurrentStep = 0,
        CurrentRow = nil,
        CompactLayout = compactLayout,
    }

    currentCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCurrentCamera)
    bindCurrentCamera()

    ancestryConnection = screenGui.AncestryChanged:Connect(function(_, nextParent)
        if nextParent then
            return
        end

        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end

        if currentCameraConnection then
            currentCameraConnection:Disconnect()
            currentCameraConnection = nil
        end

        collapseTransitionToken += 1
        cancelCollapseAnimation()

        if collapseHoverTween then
            collapseHoverTween:Cancel()
            collapseHoverTween = nil
        end

        if cleanupDrag then
            cleanupDrag()
            cleanupDrag = nil
        end

        if self.StrategyLogger and self.StrategyLogger.Gui == screenGui then
            self.StrategyLogger = nil
        end

        if ancestryConnection then
            ancestryConnection:Disconnect()
            ancestryConnection = nil
        end
    end)

    return self.StrategyLogger
end

function LyraMacro:LogStrategyAction(message)
    local logger = self.StrategyLogger

    if not logger or not logger.Gui or not logger.Gui.Parent then
        logger = self:CreateStrategyLogger()
    end

    local parsed = parseStrategyLoggerMessage(message)
    local badgeIconName, accentColor = getStrategyLoggerAppearance(message)

    if logger.CurrentRow and logger.CurrentRow.Parent then
        logger.CurrentRow.BackgroundTransparency = 1

        local previousAction = logger.CurrentRow:FindFirstChild("ActionText")
        local previousBadge = logger.CurrentRow:FindFirstChild("TypeBadge")
        local previousAccent = logger.CurrentRow:FindFirstChild("Accent")

        if previousAction then
            previousAction.TextColor3 = STRATEGY_LOGGER_COLORS.Muted
        end

        if previousBadge then
            previousBadge.BackgroundTransparency = 0.84

            local previousIcon = previousBadge:FindFirstChild("Icon")

            if previousIcon and previousIcon:IsA("ImageLabel") then
                previousIcon.ImageTransparency = 0.25
            end
        end

        if previousAccent then
            previousAccent.BackgroundTransparency = 0.45
        end
    end

    if parsed.StartedTotal then
        logger.TotalActions = parsed.StartedTotal
        logger.CurrentStep = 0
        logger.StatusText.Text = "STRATEGY RUNNING"
        logger.StatusText.TextColor3 = STRATEGY_LOGGER_COLORS.Lavender
        logger.ProgressText.Text = "0 / " .. tostring(parsed.StartedTotal) .. " DONE"
        setStrategyLoggerRuntimeStatus(logger, "LIVE", "play", STRATEGY_LOGGER_COLORS.Mint)
        setStrategyLoggerProgress(logger, 0)
    elseif parsed.Step then
        logger.TotalActions = parsed.Total or logger.TotalActions
        logger.CurrentStep = parsed.Step
        logger.StatusText.Text = "RUNNING STEP " .. tostring(parsed.Step)
        logger.StatusText.TextColor3 = STRATEGY_LOGGER_COLORS.Lavender
        setStrategyLoggerRuntimeStatus(logger, "LIVE", "play", STRATEGY_LOGGER_COLORS.Mint)

        if logger.TotalActions then
            local completedActions = math.max(0, parsed.Step - 1)
            logger.ProgressText.Text = tostring(completedActions) .. " / " .. tostring(logger.TotalActions) .. " DONE"
            setStrategyLoggerProgress(logger, completedActions / math.max(logger.TotalActions, 1))
        end
    elseif parsed.Completed then
        logger.CurrentStep = logger.TotalActions or logger.CurrentStep
        logger.StatusText.Text = "STRATEGY COMPLETE"
        logger.StatusText.TextColor3 = STRATEGY_LOGGER_COLORS.Mint
        setStrategyLoggerRuntimeStatus(logger, "DONE", "circle-check", STRATEGY_LOGGER_COLORS.Mint)

        if logger.TotalActions then
            logger.ProgressText.Text = tostring(logger.TotalActions) .. " / " .. tostring(logger.TotalActions) .. " DONE"
        end

        setStrategyLoggerProgress(logger, 1)
    elseif parsed.Failed then
        logger.StatusText.Text = "STRATEGY FAILED"
        logger.StatusText.TextColor3 = STRATEGY_LOGGER_COLORS.Coral
        setStrategyLoggerRuntimeStatus(logger, "ERROR", "triangle-alert", STRATEGY_LOGGER_COLORS.Coral)
    end

    logger.Entries += 1

    local entry = Instance.new("Frame")
    entry.Name = "Action" .. tostring(logger.Entries)
    entry.Size = UDim2.new(1, -14, 0, 50)
    entry.BackgroundColor3 = STRATEGY_LOGGER_COLORS.Card
    entry.BackgroundTransparency = 0.72
    entry.BorderSizePixel = 0
    entry.LayoutOrder = logger.Entries
    entry.ZIndex = 1002
    entry.Parent = logger.Scroll

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.AnchorPoint = Vector2.new(0, 0.5)
    accent.Position = UDim2.new(0, 0, 0.5, 0)
    accent.Size = UDim2.fromOffset(3, 28)
    accent.BackgroundColor3 = accentColor
    accent.BorderSizePixel = 0
    accent.ZIndex = 1003
    accent.Parent = entry
    addStrategyLoggerCorner(accent, 3)

    local indexText = Instance.new("TextLabel")
    indexText.Name = "Index"
    indexText.Position = UDim2.fromOffset(9, 0)
    indexText.Size = UDim2.fromOffset(43, 50)
    indexText.BackgroundTransparency = 1
    indexText.Text = parsed.Step and string.format("%02d/%02d", parsed.Step, parsed.Total or parsed.Step)
        or string.format("%02d", logger.Entries)
    indexText.TextColor3 = STRATEGY_LOGGER_COLORS.Faint
    indexText.TextSize = 9
    indexText.Font = Enum.Font.Code
    indexText.TextXAlignment = Enum.TextXAlignment.Left
    indexText.ZIndex = 1003
    indexText.Parent = entry

    local typeBadge = Instance.new("Frame")
    typeBadge.Name = "TypeBadge"
    typeBadge.AnchorPoint = Vector2.new(0, 0.5)
    typeBadge.Position = UDim2.new(0, 52, 0.5, 0)
    typeBadge.Size = UDim2.fromOffset(31, 26)
    typeBadge.BackgroundColor3 = accentColor
    typeBadge.BackgroundTransparency = 0.76
    typeBadge.BorderSizePixel = 0
    typeBadge.ZIndex = 1003
    typeBadge.Parent = entry
    addStrategyLoggerCorner(typeBadge, 5)
    addStrategyLoggerStroke(typeBadge, accentColor, 0.35, 1)

    typeBadge:SetAttribute("LucideIcon", badgeIconName)
    createStrategyLoggerIcon(typeBadge, badgeIconName, {
        Name = "Icon",
        Position = UDim2.new(0.5, -7, 0.5, -7),
        Size = UDim2.fromOffset(14, 14),
        ImageColor3 = accentColor,
        ZIndex = 1004,
    })

    local actionText = Instance.new("TextLabel")
    actionText.Name = "ActionText"
    actionText.Position = UDim2.fromOffset(93, 0)
    actionText.Size = logger.CompactLayout and UDim2.new(1, -100, 1, 0) or UDim2.new(1, -148, 1, 0)
    actionText.BackgroundTransparency = 1
    actionText.Text = parsed.Text
    actionText.TextColor3 = STRATEGY_LOGGER_COLORS.Text
    actionText.TextSize = 10
    actionText.Font = Enum.Font.Code
    actionText.TextXAlignment = Enum.TextXAlignment.Left
    actionText.TextYAlignment = Enum.TextYAlignment.Center
    actionText.TextTruncate = Enum.TextTruncate.AtEnd
    actionText.ZIndex = 1003
    actionText.Parent = entry

    local timeText = Instance.new("TextLabel")
    timeText.Name = "Timestamp"
    timeText.AnchorPoint = Vector2.new(1, 0)
    timeText.Position = UDim2.new(1, -7, 0, 0)
    timeText.Size = UDim2.fromOffset(45, 50)
    timeText.BackgroundTransparency = 1
    timeText.Text = formatStrategyLoggerTime(logger.StartedAt)
    timeText.TextColor3 = STRATEGY_LOGGER_COLORS.Faint
    timeText.TextSize = 9
    timeText.Font = Enum.Font.Code
    timeText.TextXAlignment = Enum.TextXAlignment.Right
    timeText.Visible = not logger.CompactLayout
    timeText.ZIndex = 1003
    timeText.Parent = entry

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.AnchorPoint = Vector2.new(0, 1)
    divider.Position = UDim2.new(0, 9, 1, 0)
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.BackgroundColor3 = STRATEGY_LOGGER_COLORS.CardStroke
    divider.BackgroundTransparency = 0.55
    divider.BorderSizePixel = 0
    divider.ZIndex = 1002
    divider.Parent = entry

    logger.CurrentRow = entry

    task.defer(function()
        if logger.Scroll and logger.Scroll.Parent then
            logger.Scroll.CanvasPosition = Vector2.new(
                0,
                math.max(0, logger.Layout.AbsoluteContentSize.Y - logger.Scroll.AbsoluteWindowSize.Y + 10)
            )
        end
    end)

    return entry
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

    local perkStates, perkMetadataError = getStrategyPerkStates(strategy)

    assert(perkStates, "[LyraMacro] " .. tostring(perkMetadataError))

    return highestIndex
end

function LyraMacro:_acquireReplayOwnership()
    local environment = getSharedEnvironment()

    if not environment then
        return true
    end

    local activeReplay = environment[ACTIVE_REPLAY_LOCK_KEY]

    if type(activeReplay) == "table"
        and activeReplay.Active == true
        and activeReplay.JobId == game.JobId then
        return false,
            "Another Lyra AutoStrategy is already running in this match. Duplicate execution was blocked to prevent conflicting tower placements."
    end

    local ownershipToken = {}
    environment[ACTIVE_REPLAY_LOCK_KEY] = {
        Active = true,
        JobId = game.JobId,
        Owner = ownershipToken,
        StartedAt = os.clock(),
    }
    self._replayOwnershipToken = ownershipToken
    return true
end

function LyraMacro:_releaseReplayOwnership()
    local environment = getSharedEnvironment()
    local activeReplay = environment and environment[ACTIVE_REPLAY_LOCK_KEY]

    if type(activeReplay) == "table" and activeReplay.Owner == self._replayOwnershipToken then
        activeReplay.Active = false
        environment[ACTIVE_REPLAY_LOCK_KEY] = nil
    end

    self._replayOwnershipToken = nil
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

    local ownsReplay, ownershipError = self:_acquireReplayOwnership()

    if not ownsReplay then
        error("[LyraMacro] " .. tostring(ownershipError), 2)
    end

    self:RemoveIndex()
    self:Ready()
    self:_watchForAutoStrategyResults()
    self:CreateStrategyLogger()
    self:LogStrategyAction("STRATEGY STARTED - " .. tostring(actionCount) .. " ACTIONS")
    local lastAbilityDispatchedAt = os.clock()

    for stepNumber = 1, actionCount do
        local step = strategy[stepNumber]
        local action = step.action
        local actionDescription = describeStrategyStep(step)
        self:LogStrategyAction(tostring(stepNumber) .. "/" .. tostring(actionCount) .. "  " .. actionDescription)

        local executed, actionError = xpcall(function()
            assert(type(action) == "string", "[LyraMacro] Step " .. stepNumber .. " has no action.")

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
                local targetTower = self.SpawnedTowers[step.tower]
                assert(
                    targetTower and targetTower.Parent,
                    "[LyraMacro] Cannot schedule an ability for tower #"
                        .. tostring(step.tower)
                        .. "; it is missing or was sold."
                )

                local abilityDelay = normalizeAbilityDelay(step.delay)

                if abilityDelay then
                    local delayAnchor = lastAbilityDispatchedAt

                    if step.delay_from == ABILITY_DELAY_FROM_TOWER_PLACEMENT then
                        delayAnchor = tonumber(self.SpawnedTowerPlacedAt[step.tower])
                        assert(
                            delayAnchor,
                            "[LyraMacro] Timed ability for tower #"
                                .. tostring(step.tower)
                                .. " is missing its replay placement timestamp."
                        )
                    end

                    local remainingDelay = delayAnchor + abilityDelay - os.clock()

                    if remainingDelay > 0 then
                        print(
                            "[LyraMacro] Waiting "
                                .. formatNumber(remainingDelay)
                                .. " seconds for the recorded ability timing."
                        )
                        task.wait(remainingDelay)
                    end
                end

                -- Anchor start-to-start timing before InvokeServer so remote
                -- latency does not stretch the next recorded ability interval.
                lastAbilityDispatchedAt = os.clock()
                self:ActivateAbility(step.tower, step.ability)
            elseif action == "chaincoa" then
                local chained, chainMessage = self:SetChainCOA(step.enabled ~= false, {
                    ActiveDuration = step.active_duration,
                    HandoffDelay = step.handoff_delay,
                    RetryDelay = step.retry_delay,
                    Record = false,
                })

                if not chained then
                    error(chainMessage or "Chain COA could not be configured.")
                end
            else
                error("[LyraMacro] Unknown action: " .. action)
            end
        end, debug.traceback)

        if not executed then
            pcall(function()
                self:LogStrategyAction(
                    "STRATEGY FAILED - STEP " .. tostring(stepNumber) .. "  " .. actionDescription
                )
            end)
            self:_releaseReplayOwnership()
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
