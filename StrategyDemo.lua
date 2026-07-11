--[[
    Lyra UI Library - Strategy Autoplay Script (StrategyDemo)
    Demonstrates strategy thread spawning, game-over UI polling, and automatic replay logic.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Load the Lyra Macro Library
-- In a real environment, you would use loadstring(game:HttpGet("https://raw.githubusercontent.com/.../LyraMacroLib.lua"))()
-- For testing, we require it locally or simulate the fetch.
local Lyra = loadstring(game:HttpGet("https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua"))()

-- Configure Global Settings
getgenv().AutoSkip = true
getgenv().AutoRejoin = true

-- Setup Initial Lobby/Game Configuration
Lyra:Loadout("Shotgunner", "Minigunner", "None", "None", "None")
Lyra:Mode("Hardcore")
Lyra:GameInfo("Wretched Front", {})

-- Define the Strategy Steps
local function StartStrategy()
    task.wait(1)
    Lyra:RemoveIndex()
    Lyra:Ready()

    -- [ Wave 1 ]
    Lyra:VoteSkip(1)
    -- Places Tower #1 (Scout)
    Lyra:Place("Shotgunner", -7.348, 0.963, -31.465)

    -- [ Wave 2 ]
    Lyra:VoteSkip(2)
    -- Upgrades Tower #1
    Lyra:Upgrade(1)

    -- [ Wave 3 ]
    Lyra:VoteSkip(3)
    -- Places Tower #2
    Lyra:Place("Minigunner", -1.223, 0.327, -16.418)

    -- [ Wave 4 ]
    Lyra:VoteSkip(4)
    -- Upgrades Tower #2
    Lyra:Upgrade(2)
    
    -- [ Wave 5 ]
    Lyra:VoteSkip(5)
    -- Sells Tower #1
    Lyra:Sell(1)
end

-- Checks GUI elements to determine if the match has finished (Win or Loss)
local function GetMatchStatus()
    local success, status = pcall(function()
        -- Customize these UI path checks to match your game's specific GameOver screen
        local uiRoot = PlayerGui:FindFirstChild("ReactGameNewRewards")
        if not uiRoot then return nil end

        local mainFrame = uiRoot:FindFirstChild("Frame")
        if not mainFrame or not mainFrame.Visible then return nil end

        local gameOver = mainFrame:FindFirstChild("gameOver")
        if not gameOver or not gameOver.Visible then return nil end

        local rewardsScreen = gameOver:FindFirstChild("RewardsScreen")
        if not rewardsScreen or not rewardsScreen.Visible then return nil end

        local topBanner = rewardsScreen:FindFirstChild("RewardBanner")
        if not topBanner then return nil end

        local label = topBanner:FindFirstChild("textLabel") or topBanner:FindFirstChildOfClass("TextLabel")
        if not label then return nil end

        local txt = label.Text:upper()
        if txt == "" then return nil end

        if txt:find("TRIUMPH") or txt:find("VICTORY") or txt:find("WIN") then
            return "WIN"
        elseif txt:find("LOST") or txt:find("DEFEAT") or txt:find("FAIL") then
            return "LOSS"
        end
        return nil
    end)
    
    if success then return status end
    return nil
end

-- Helper to continuously request a retry or skip until accepted
local function fireRestartRequest()
    local Remote = ReplicatedStorage:WaitForChild("RemoteFunction")
    while true do
        local success, result = pcall(function()
            return Remote:InvokeServer("Voting", "Skip") -- Adjust parameter for restart if game has a restart vote
        end)

        if success then
            print("[StrategyDemo] Restart vote sent successfully!")
            break
        else
            print("[StrategyDemo] Restart request failed. Retrying in 1 second...")
            task.wait(1)
        end
    end
end

-- Main Strategy Loop Controller
task.spawn(function()
    local activeStratThread = task.spawn(StartStrategy)

    while true do
        task.wait(0.5)

        local currentStatus = GetMatchStatus()
        
        -- If defeat is detected, stop the old script thread and start a new lobby/retry loop
        if currentStatus == "LOSS" or currentStatus == "WIN" then
            print("[StrategyDemo] Match finished: " .. tostring(currentStatus) .. "! Stopping strategy thread...")

            if activeStratThread and coroutine.status(activeStratThread) ~= "dead" then
                task.cancel(activeStratThread)
                activeStratThread = nil
            end

            if getgenv().AutoRejoin then
                print("[StrategyDemo] Triggering restart/rejoin sequence...")
                fireRestartRequest()

                print("[StrategyDemo] Waiting for match screen to reset...")
                repeat 
                    task.wait(1) 
                until GetMatchStatus() == nil

                task.wait(1)

                print("[StrategyDemo] Starting new strategy thread!")
                activeStratThread = task.spawn(StartStrategy)
            end
        end
    end
end)
