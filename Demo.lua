--[[
    Tungsten Hub Demo Script
    This script loads and runs the Tungsten Hub UI Library to show all available controls.
    
    How to run in Roblox Studio:
    1. Open Roblox Studio.
    2. Create a LocalScript in StarterGui.
    3. Copy the entire content of 'TungstenHub.lua' and paste it inside a ModuleScript named 'TungstenHub' under the LocalScript.
    4. Paste the content of this file (Demo.lua) into the LocalScript.
    5. Replace the first few lines with:
       local TungstenHub = require(script:WaitForChild("TungstenHub"))
    6. Play/Run the game.
]]

-- Load the library. (If running from a ModuleScript, use require)
-- For demonstration/executor purposes, we've bundled them or assume it is imported.
-- If you are pasting this into a LocalScript, copy 'TungstenHub.lua' contents above this line, 
-- change 'return TungstenHub' to 'local TungstenHub = ...', and paste this script directly below it.

local TungstenHub = require(script:WaitForChild("TungstenHub"))

-- Create Window
local Window = TungstenHub:CreateWindow("Tungsten Hub", "Universal")

-- Create Tabs
local MainTab = Window:CreateTab("Main")
local MovementTab = Window:CreateTab("Movement")
local SettingsTab = Window:CreateTab("Settings")

-- --- Main Tab Components ---
MainTab:CreateLabel("Welcome to Tungsten Hub!")

MainTab:CreateButton("Send Notification", function()
    Window:Notify("Tungsten Hub", "This is a smooth notification!", 3)
end)

MainTab:CreateToggle("Auto Farm Coins", false, function(state)
    print("Auto Farm set to:", state)
    if state then
        Window:Notify("Auto Farm", "Script started...", 2)
    else
        Window:Notify("Auto Farm", "Script stopped.", 2)
    end
end)

-- --- Movement Tab Components ---
MovementTab:CreateLabel("Player Adjustments")

MovementTab:CreateSlider("WalkSpeed Booster", 16, 200, 16, function(value)
    local character = game:GetService("Players").LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character:FindFirstChildOfClass("Humanoid").WalkSpeed = value
    end
end)

MovementTab:CreateSlider("JumpPower Booster", 50, 300, 50, function(value)
    local character = game:GetService("Players").LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        humanoid.UseJumpPower = true
        humanoid.JumpPower = value
    end
end)

-- --- Settings Tab Components ---
SettingsTab:CreateLabel("Configuration settings")

SettingsTab:CreateDropdown("Theme Color Palette", {"Dark Steel", "Neon Cyan", "Amber Gold", "Crimson Red"}, "Dark Steel", function(option)
    print("Theme palette selected:", option)
    Window:Notify("Theme Changed", "Applied " .. option .. " style.", 2)
end)

SettingsTab:CreateButton("Destroy UI", function()
    local existing = game:GetService("CoreGui"):FindFirstChild("TungstenHub") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("TungstenHub")
    if existing then
        existing:Destroy()
    end
end)

-- Send a welcoming notification
Window:Notify("Success", "Loaded Tungsten Hub!", 4)
