--[[
    Lyra Macro & Strategy Library (LyraMacroLib)

    Solo strategy playback that advances from game state, never elapsed time.
    An action is retried only after LocalPlayer.Cash changes, so the game's
    economy remains the source of truth for when a placement or upgrade works.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local LocalPlayer = Players.LocalPlayer
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")
local TowersFolder = workspace:FindFirstChild("Towers")

local LyraMacro = {
    SpawnedTowers = {},
    NextTowerIndex = 0,
    SelectedLoadout = {},
    SelectedMode = "Normal",
    SelectedMap = "",
    IsRecording = false,
    RecordedStrategy = {},
    RecordedTowerIndexes = {},
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
    _recordHookInstalled = false,
    _originalNamecall = nil,
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
    elseif step.action == "skip" and step.label then
        table.insert(fields, formatField("label", step.label))
    end

    return "{ " .. table.concat(fields, ", ") .. " }"
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

-- Retries only when the authoritative cash value changes; it never polls or sleeps.
function LyraMacro:_retryOnCashChange(actionName, invoke, isComplete)
    local cash = getCashValue()

    while true do
        invoke()

        if isComplete() then
            return
        end

        print("[LyraMacro] " .. actionName .. " is pending; waiting for Cash to change.")
        cash:GetPropertyChangedSignal("Value"):Wait()

        if isComplete() then
            return
        end
    end
end

-- Sets the starting troop configuration. Lobby selection is intentionally separate.
function LyraMacro:Loadout(...)
    self.SelectedLoadout = { ... }
    print("[LyraMacro] Loadout configured: " .. table.concat(self.SelectedLoadout, ", "))
end

function LyraMacro:Mode(modeName)
    self.SelectedMode = modeName
    print("[LyraMacro] Mode configured: " .. modeName)
end

function LyraMacro:VoteMode(modeName, confirmed)
    confirmed = confirmed ~= false
    self:Mode(modeName)
    print("[LyraMacro] Voting for difficulty: " .. tostring(modeName))
    RemoteFunction:InvokeServer("Difficulty", "Vote", modeName, confirmed)
end

function LyraMacro:GameInfo(mapName, options)
    options = options or {}

    local normalizedMapName = normalizeMapCandidate(mapName) or tostring(mapName or "")
    self.SelectedMap = normalizedMapName
    self.LastDetectedMapSource = options.Source or "manual"
    print("[LyraMacro] Match configured for map: " .. normalizedMapName)
end

-- Clears only this strategy's stable tower IDs for a fresh solo match.
function LyraMacro:RemoveIndex()
    table.clear(self.SpawnedTowers)
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

    local recorderReady, recorderMessage = self:_installRecorder()

    if not recorderReady then
        return false, recorderMessage
    end

    self.PendingElevatorReplay = {
        Strategy = cloneStrategy(strategy),
        ExpectedFingerprint = type(expectedFingerprint) == "string" and expectedFingerprint or nil,
        LibraryUrl = options.LibraryUrl,
        Timeout = options.Timeout or self.AutoRecordTimeout,
    }
    self.AutoRecordTeleportArmed = false
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

function LyraMacro:_trackNextRecordedTower()
    local connection

    connection = getTowersFolder().ChildAdded:Connect(function(tower)
        connection:Disconnect()

        if not self.IsRecording then
            return
        end

        self.NextRecordedTowerIndex += 1
        self.RecordedTowerIndexes[tower] = self.NextRecordedTowerIndex
        print("[LyraMacro] Recorded tower #" .. self.NextRecordedTowerIndex .. ".")
    end)

    table.insert(self.RecordingConnections, connection)
end

function LyraMacro:_getRecordedTowerIndex(tower)
    if not tower then
        return nil
    end

    local towerIndex = self.RecordedTowerIndexes[tower]

    if not towerIndex then
        warn("[LyraMacro] Ignored tower action because that tower was not placed after recording started.")
    end

    return towerIndex
end

function LyraMacro:_recordRemoteInvoke(args)
    if not self.IsRecording then
        return
    end

    local category = args[1]
    local action = args[2]
    local remoteMapName, remoteMapSource = detectMapFromRemoteArgs(args)

    if remoteMapName then
        self:_setDetectedMap(remoteMapName, remoteMapSource, false)
    end

    if category == "Waves" and action == "Skip" then
        self:_appendRecordedStep({
            action = "skip",
        })
        return
    end

    if category == "Difficulty" and action == "Vote" then
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

    if category ~= "Troops" then
        return
    end

    if action == "Place" then
        local troopType = args[3]
        local placementInfo = args[4] or {}
        local position = placementInfo.Position or args[6]

        if getValueKind(position) ~= "Vector3" then
            warn("[LyraMacro] Ignored place action because no Vector3 position was found.")
            return
        end

        self:_appendRecordedStep({
            action = "place",
            troop = tostring(troopType),
            x = roundNumber(position.X),
            y = roundNumber(position.Y),
            z = roundNumber(position.Z),
            rotation = placementInfo.Rotation,
        })
        self:_trackNextRecordedTower()
    elseif action == "Upgrade" and args[3] == "Set" then
        local upgradeInfo = args[4] or {}
        local towerIndex = self:_getRecordedTowerIndex(upgradeInfo.Troop)

        if towerIndex then
            self:_appendRecordedStep({
                action = "upgrade",
                tower = towerIndex,
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

        if method == "InvokeServer" and remote == RemoteFunction then
            local args = { ... }
            self:_observeElevatorEnter(args)
            local recorded, recordError = pcall(function()
                self:_recordRemoteInvoke(args)
            end)

            if not recorded then
                warn("[LyraMacro] Failed to record remote call: " .. tostring(recordError))
            end
        end

        return oldNamecall(remote, ...)
    end

    if type(newcclosure) == "function" then
        recorderNamecall = newcclosure(recorderNamecall)
    end

    oldNamecall = hookmetamethod(game, "__namecall", recorderNamecall)
    self._originalNamecall = oldNamecall
    self._recordHookInstalled = true

    return true
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
    self:DetectMap({ Silent = true })
    self:DetectMapFingerprint({ Silent = true, Force = true })

    print("[LyraMacro] Strategy recording started.")
    return true
end

function LyraMacro:StopRecording()
    if not self.IsRecording then
        return self:GetRecordedStrategy(), self:GetRecordedStrategyScriptSource(), self.LastStrategyExport
    end

    self.IsRecording = false

    for _, connection in ipairs(self.RecordingConnections) do
        connection:Disconnect()
    end

    table.clear(self.RecordingConnections)

    if self.SelectedMap == "" then
        self:DetectMap({ Silent = true })
    end

    self:DetectMapFingerprint({ Silent = true, Force = true })

    local recordedStrategy = self:GetRecordedStrategy()
    local exportResult = self:SaveRecordedStrategy()
    local strategySource = exportResult.Source

    print("[LyraMacro] Strategy recording stopped. Recorded " .. #recordedStrategy .. " steps.")
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
        table.insert(lines, "LyraMacro:GameInfo(" .. formatLuaValue(self.SelectedMap) .. ", { Source = " .. formatLuaValue(self.LastDetectedMapSource or "recorded") .. " })")
        table.insert(lines, "")
    end

    if type(self.SelectedMapFingerprint) == "string" and self.SelectedMapFingerprint ~= "" then
        table.insert(lines, "local RecordedMapFingerprint = " .. formatLuaValue(self.SelectedMapFingerprint))
    else
        table.insert(lines, "local RecordedMapFingerprint = nil")
    end

    appendRecordedStrategyLines(lines, self.RecordedStrategy)
    table.insert(lines, "")
    table.insert(lines, "if game.PlaceId == " .. tostring(LOBBY_PLACE_ID) .. " then")
    table.insert(lines, "    local queued, message = LyraMacro:QueueStrategyAfterElevator(Strategy, RecordedMapFingerprint, { LibraryUrl = " .. formatLuaValue(macroLibraryUrl) .. " })")
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
        })

        local strategyTab = window:CreateTab(config.TabName or "Strategy")
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

function LyraMacro:Place(troopType, x, y, z, rotation)
    local position = Vector3.new(x, y, z)
    rotation = rotation or CFrame.new()
    local towersFolder = getTowersFolder()

    local placedTower
    local towerAddedConnection = towersFolder.ChildAdded:Connect(function(tower)
        -- This library is intentionally solo-only, so the next tower is ours.
        placedTower = tower
    end)

    local ok, err = xpcall(function()
        self:_retryOnCashChange("Place " .. troopType, function()
            RemoteFunction:InvokeServer(
                "Troops",
                "Place",
                troopType,
                {
                    Rotation = rotation,
                    Position = position,
                },
                {
                    Type = troopType,
                    Skin = "Default",
                },
                position
            )
        end, function()
            return placedTower ~= nil
        end)

        self.NextTowerIndex += 1
        self.SpawnedTowers[self.NextTowerIndex] = placedTower
        print("[LyraMacro] Registered tower #" .. self.NextTowerIndex .. ".")
    end, debug.traceback)

    towerAddedConnection:Disconnect()

    if not ok then
        error(err, 0)
    end

    return placedTower
end

function LyraMacro:Upgrade(towerIndex)
    local targetTower = self.SpawnedTowers[towerIndex]
    assert(
        targetTower and targetTower.Parent,
        "[LyraMacro] Cannot upgrade tower #" .. tostring(towerIndex) .. "; it is missing or was sold."
    )

    local cashBeforeRequest = 0

    self:_retryOnCashChange("Upgrade tower #" .. towerIndex, function()
        cashBeforeRequest = getCashValue().Value

        RemoteFunction:InvokeServer(
            "Troops",
            "Upgrade",
            "Set",
            {
                Troop = targetTower,
            }
        )
    end, function()
        -- In a solo run, the macro is the only spender, so a cash decrease
        -- confirms that this upgrade was accepted by the server.
        return getCashValue().Value < cashBeforeRequest
    end)

    print("[LyraMacro] Upgraded tower #" .. towerIndex .. ".")
end

function LyraMacro:Sell(towerIndex)
    local targetTower = self.SpawnedTowers[towerIndex]
    assert(
        targetTower and targetTower.Parent,
        "[LyraMacro] Cannot sell tower #" .. tostring(towerIndex) .. "; it is missing or already sold."
    )

    self:_retryOnCashChange("Sell tower #" .. towerIndex, function()
        RemoteFunction:InvokeServer(
            "Troops",
            "Sell",
            {
                Troop = targetTower,
            }
        )
    end, function()
        return targetTower.Parent == nil
    end)

    -- Keep IDs stable: selling #1 never changes the ID of tower #2.
    self.SpawnedTowers[towerIndex] = nil
    print("[LyraMacro] Sold tower #" .. towerIndex .. ".")
end

function LyraMacro:VoteSkip(label)
    print("[LyraMacro] Requesting skip" .. (label and " for " .. tostring(label) or "") .. ".")
    RemoteFunction:InvokeServer("Waves", "Skip")
end

function LyraMacro:Run(strategy)
    assert(type(strategy) == "table", "[LyraMacro] Strategy must be a table of step tables.")

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

    for stepNumber, step in ipairs(strategy) do
        local action = step.action
        assert(type(action) == "string", "[LyraMacro] Step " .. stepNumber .. " has no action.")

        if action == "skip" then
            self:VoteSkip(step.label)
        elseif action == "mode" then
            self:VoteMode(step.mode, step.confirmed)
        elseif action == "place" then
            self:Place(step.troop, step.x, step.y, step.z, step.rotation)
        elseif action == "upgrade" then
            self:Upgrade(step.tower)
        elseif action == "sell" then
            self:Sell(step.tower)
        else
            error("[LyraMacro] Unknown action in step " .. stepNumber .. ": " .. action)
        end
    end

    print("[LyraMacro] Strategy completed.")
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
