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
local TowersFolder = workspace:WaitForChild("Towers")

local LyraMacro = {
    SpawnedTowers = {},
    NextTowerIndex = 0,
    SelectedLoadout = {},
    SelectedMode = "Normal",
    SelectedMap = "",
}

local function getCashValue()
    local cash = LocalPlayer:WaitForChild("Cash")

    assert(
        cash:IsA("IntValue") or cash:IsA("NumberValue"),
        "[LyraMacro] Players.LocalPlayer.Cash must be an IntValue or NumberValue."
    )

    return cash
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

function LyraMacro:Place(troopType, x, y, z, rotation)
    local position = Vector3.new(x, y, z)
    rotation = rotation or CFrame.new()

    local placedTower
    local towerAddedConnection = TowersFolder.ChildAdded:Connect(function(tower)
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

return LyraMacro
