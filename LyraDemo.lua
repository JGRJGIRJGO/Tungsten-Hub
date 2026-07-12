--[[
    Lyra UI Library Demo Script
    This script loads and runs the Lyra UI Library to show all available controls.
    
    How to run in Roblox Studio:
    1. Open Roblox Studio.
    2. Create a LocalScript in StarterGui.
    3. Copy the entire content of 'LyraV2.lua' and paste it inside a ModuleScript named 'Lyra' under the LocalScript.
    4. Paste the content of this file (LyraDemo.lua) into the LocalScript.
    5. Replace the first few lines with:
       local Lyra = require(script:WaitForChild("Lyra"))
    6. Play/Run the game.
]]

local Lyra = require(script:WaitForChild("Lyra"))

-- Create Window
local Window = Lyra:CreateWindow({
    Name = "Lyra UI Library",
    Subtitle = "Universal",
    Icon = "command",
})

-- Create Tabs
local MainTab = Window:CreateTab({ Name = "Main", Icon = "home" })
local MovementTab = Window:CreateTab({ Name = "Movement", Icon = "mouse-pointer-click" })
local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })

-- --- Main Tab Components ---
MainTab:CreateLabel("Welcome to Lyra UI Library!")

MainTab:CreateButton("Send Notification", function()
    Window:Notify("Lyra UI Library", "This is a smooth notification!", 3)
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

SettingsTab:CreateDropdown("UI Theme Palette", {"Lyra", "Nebula", "BloodMoon", "Emerald", "Midnight"}, "Lyra", function(themeName)
    local themeTable = Lyra.Themes[themeName]
    if themeTable then
        Window:SetTheme(themeTable)
        Window:Notify("Theme Loaded", "Applied the " .. themeName .. " theme palette.", 2)
    end
end)

SettingsTab:CreateButton("Destroy UI", function()
    local existing = game:GetService("CoreGui"):FindFirstChild("Lyra") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Lyra")
    if existing then
        existing:Destroy()
    end
end)

-- Send a welcoming notification
Window:Notify("Success", "Loaded Lyra UI Library!", 4)
