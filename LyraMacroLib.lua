--[[
    Lyra Macro & Strategy Library (LyraMacroLib)
    A clean, modular tower defense strategy playback framework.
    Handles sequential ID tracking, placement, upgrades, selling, and skip voting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local TowersFolder = workspace:WaitForChild("Towers")
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")

local LyraMacro = {}
LyraMacro.SpawnedTowers = {}
LyraMacro.AutoSkip = true
LyraMacro.SelectedLoadout = {}
LyraMacro.SelectedMode = "Normal"
LyraMacro.SelectedMap = ""

-- Auto-register newly spawned towers sequentially
TowersFolder.ChildAdded:Connect(function(newTower)
    task.wait(0.05) -- Brief yield to let properties replicate to the client
    table.insert(LyraMacro.SpawnedTowers, newTower)
    print("[LyraMacro] Registered tower #" .. #LyraMacro.SpawnedTowers .. ": " .. newTower.Name)
end)

-- Sets up the starting troop configuration
function LyraMacro:Loadout(...)
    self.SelectedLoadout = {...}
    print("[LyraMacro] Loadout initialized: " .. table.concat(self.SelectedLoadout, ", "))
end

-- Sets the target mode
function LyraMacro:Mode(modeName)
    self.SelectedMode = modeName
    print("[LyraMacro] Mode set to: " .. modeName)
end

-- Configures mapping details
function LyraMacro:GameInfo(mapName, options)
    self.SelectedMap = mapName
    print("[LyraMacro] Match configured for Map: " .. mapName)
end

-- Completely resets the tracking list for a fresh game session
function LyraMacro:RemoveIndex()
    table.clear(self.SpawnedTowers)
    print("[LyraMacro] Tower tracking index cleared.")
end

-- Signals that the client is ready
function LyraMacro:Ready()
    print("[LyraMacro] Strategy match starting...")
end

-- Places a troop at specified coordinates (auto-assigns next integer ID)
function LyraMacro:Place(troopType, x, y, z, rotation)
    rotation = rotation or CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    local position = Vector3.new(x, y, z)
    
    print("[LyraMacro] Placing " .. troopType .. " at: " .. tostring(position))
    
    local placeArgs = {
        "Troops",
        "Place",
        troopType,
        {
            Rotation = rotation,
            Position = position
        },
        {
            Type = troopType,
            Skin = "Default"
        },
        position -- Fallback target mouse position
    }
    
    local currentCount = #self.SpawnedTowers
    RemoteFunction:InvokeServer(unpack(placeArgs))
    
    -- Pause execution until the instance successfully spawns and registers
    repeat 
        task.wait(0.05) 
    until #self.SpawnedTowers > currentCount
    
    task.wait(0.15)
end

-- Upgrades a tower using its sequential index
function LyraMacro:Upgrade(towerIndex)
    local targetTower = self.SpawnedTowers[towerIndex]
    
    if targetTower and targetTower.Parent then
        print("[LyraMacro] Upgrading tower #" .. towerIndex .. " (" .. targetTower.Name .. ")")
        local upgradeArgs = {
            "Troops",
            "Upgrade",
            "Set",
            {
                Troop = targetTower
            }
        }
        RemoteFunction:InvokeServer(unpack(upgradeArgs))
    else
        warn("[LyraMacro] Failed to upgrade: Tower index " .. tostring(towerIndex) .. " does not exist or was sold.")
    end
    task.wait(0.15)
end

-- Sells a tower by its index reference
function LyraMacro:Sell(towerIndex)
    local targetTower = self.SpawnedTowers[towerIndex]
    
    if targetTower and targetTower.Parent then
        print("[LyraMacro] Selling tower #" .. towerIndex .. " (" .. targetTower.Name .. ")")
        local sellArgs = {
            "Troops",
            "Sell",
            {
                Troop = targetTower
            }
        }
        RemoteFunction:InvokeServer(unpack(sellArgs))
        
        -- Void this position in our array
        self.SpawnedTowers[towerIndex] = nil
    else
        warn("[LyraMacro] Failed to sell: Tower index " .. tostring(towerIndex) .. " does not exist.")
    end
    task.wait(0.15)
end

-- Invokes a skip wave voting remote
function LyraMacro:VoteSkip(waveNumber)
    print("[LyraMacro] Requesting skip vote for Wave: " .. tostring(waveNumber))
    local skipArgs = {
        "Voting",
        "Skip"
    }
    pcall(function()
        RemoteFunction:InvokeServer(unpack(skipArgs))
    end)
    task.wait(0.1)
end

return LyraMacro
