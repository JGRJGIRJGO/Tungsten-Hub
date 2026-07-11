--[[
    Lyra Macro & Strategy Library (LyraMacroLib)

    Solo strategy playback that advances from game state, never elapsed time.
    An action is retried only after LocalPlayer.Cash changes, so the game's
    economy remains the source of truth for when a placement or upgrade works.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    self.SelectedMap = mapName
    print("[LyraMacro] Match configured for map: " .. mapName)
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
    self.IsRecording = true

    print("[LyraMacro] Strategy recording started.")
    return true
end

function LyraMacro:StopRecording()
    if not self.IsRecording then
        return self:GetRecordedStrategy(), self:GetRecordedStrategySource()
    end

    self.IsRecording = false

    for _, connection in ipairs(self.RecordingConnections) do
        connection:Disconnect()
    end

    table.clear(self.RecordingConnections)

    local recordedStrategy = self:GetRecordedStrategy()
    local strategySource = self:GetRecordedStrategySource()

    print("[LyraMacro] Strategy recording stopped. Recorded " .. #recordedStrategy .. " steps.")
    print(strategySource)

    if type(setclipboard) == "function" then
        pcall(setclipboard, strategySource)
    end

    return recordedStrategy, strategySource
end

function LyraMacro:GetRecordedStrategy()
    return cloneStrategy(self.RecordedStrategy)
end

function LyraMacro:GetRecordedStrategySource()
    local lines = {
        "local Strategy = {",
    }

    for _, step in ipairs(self.RecordedStrategy) do
        table.insert(lines, "    " .. formatRecordedStep(step) .. ",")
    end

    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

function LyraMacro:CreateRecorderWindow(config)
    config = config or {}

    if self.RecorderWindow then
        return self.RecorderWindow
    end

    local LyraUI = config.LyraUI

    if not LyraUI then
        local libraryUrl = config.LibraryUrl or "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraV2.lua?t=" .. tostring(os.time())
        local loaded, result = pcall(function()
            return loadstring(game:HttpGet(libraryUrl))()
        end)

        if not loaded or not result then
            error("[LyraMacro] Failed to load Lyra UI Library: " .. tostring(result), 0)
        end

        LyraUI = result
    end

    local window = LyraUI:CreateWindow({
        Name = config.Name or "Lyra Strategy Recorder",
        Subtitle = config.Subtitle or "Macro Tools",
    })

    local strategyTab = window:CreateTab(config.TabName or "Strategy")
    local descriptionLabel = strategyTab:CreateLabel("Record mode votes, placements, upgrades, sells, and wave skips.")

    local isRecording = false
    local recordButton

    recordButton = strategyTab:CreateButton("Record Strategy", function()
        if isRecording then
            local recordedStrategy = self:StopRecording()
            isRecording = false
            recordButton.UpdateButtonText("Record Strategy")
            descriptionLabel.UpdateText("Recorded " .. tostring(#recordedStrategy) .. " strategy steps.")
            window:Notify("Recording Stopped", "Recorded " .. tostring(#recordedStrategy) .. " strategy steps.", 3)
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
