--[[
    Tungsten Hub - Universal Script Hub
    Loads the Tungsten Hub UI library from GitHub and implements real, working features:
    - Player Movement (WalkSpeed, JumpPower, Gravity, Fly, Noclip, Infinite Jump)
    - Visuals (ESP Highlighting using Roblox Highlights)
    - Teleports (Teleport to Players, Click-to-Teleport with CTRL+Click)
    - Utilities (Anti-AFK, Rejoin Game, Dynamic Theme Swapping)
    
    Loadstring to execute:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/UniversalV2.lua"))()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Helper functions to dynamically fetch player character references safely (fixes nil indexing bugs)
local function getChar()
    return LocalPlayer.Character
end

local function getHum()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Load the Tungsten Hub UI Library from GitHub (with cache buster)
local success, TungstenHub = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/TungstenHubV2.lua?t=" .. tostring(os.time())))()
end)

if not success or not TungstenHub then
    warn("Failed to load Tungsten Hub UI Library. Falling back to local require or erroring.")
    error("Tungsten Hub: Library load failed. Make sure you are connected to the internet.")
end

-- HWID-based dynamic daily key generation (prevents key sharing)
local function getHardwareID()
    local hwid = tostring(LocalPlayer.UserId)
    if gethwid then 
        local success, result = pcall(gethwid)
        if success and type(result) == "string" and #result > 0 then
            hwid = result
        end
    end
    -- Sanitize HWID: remove all whitespace and control characters to ensure consistency
    return hwid:gsub("%s+", ""):gsub("%c+", "")
end

local function multiply32(a, b)
    local a_hi = bit32.rshift(a, 16)
    local a_lo = bit32.band(a, 0xFFFF)
    local b_hi = bit32.rshift(b, 16)
    local b_lo = bit32.band(b, 0xFFFF)
    
    local mid = bit32.band(a_hi * b_lo + a_lo * b_hi, 0xFFFF)
    return bit32.band(mid * 65536 + a_lo * b_lo, 0xFFFFFFFF)
end

local function getHashedHWID()
    local raw = getHardwareID()
    local hash = 2166136261
    for i = 1, #raw do
        hash = bit32.bxor(hash, string.byte(raw, i))
        hash = multiply32(hash, 16777619)
    end
    return string.format("%X", hash)
end

local function getDailyHWIDKey()
    local hashedHwid = getHashedHWID()
    local dateStr = os.date("!%d%m%Y") -- Forced UTC date string to align with browser
    local salt = "TungstenSaltKey"
    local input = hashedHwid .. "_" .. salt .. "_" .. dateStr
    
    local hash = 2166136261
    for i = 1, #input do
        hash = bit32.bxor(hash, string.byte(input, i))
        hash = multiply32(hash, 16777619)
    end
    return "Tungsten_" .. string.format("%X", hash)
end

-- Create Window with Secure HWID Key System
local Window = TungstenHub:CreateWindow({
    Name = "Tungsten Hub",
    Subtitle = "Universal",
    KeySettings = {
        Title = "Tungsten Key Verification",
        Subtitle = "Tungsten Hub",
        Note = "Enter your secure HWID-locked key. (For testing, your key today is: " .. getDailyHWIDKey() .. ")",
        SaveKey = true,
        Key = getDailyHWIDKey(),
        Url = "https://aged-hall-3742.raidingstreamers7.workers.dev/?hwid=" .. getHashedHWID()
    }
})

-- Create Tabs
local PlayerTab = Window:CreateTab("Player")
local VisualsTab = Window:CreateTab("Visuals")
local TeleportTab = Window:CreateTab("Teleport")
local SettingsTab = Window:CreateTab("Settings")

-- =========================================================================
-- PLAYER TAB FEATURES
-- =========================================================================

PlayerTab:CreateLabel("Movement Enhancements")

-- WalkSpeed Slider
PlayerTab:CreateSlider("WalkSpeed Booster", 16, 250, 16, function(value)
    local hum = getHum()
    if hum then
        hum.WalkSpeed = value
    end
end)

-- Custom Walkspeed Textbox
PlayerTab:CreateTextbox("Set Custom WalkSpeed", "Type speed and press Enter...", function(text)
    local num = tonumber(text)
    if num then
        local hum = getHum()
        if hum then
            hum.WalkSpeed = num
            Window:Notify("Speed Updated", "WalkSpeed set to: " .. tostring(num), 2)
        end
    else
        Window:Notify("Error", "Please enter a valid number", 2)
    end
end)

-- JumpPower Slider
PlayerTab:CreateSlider("JumpPower Booster", 50, 400, 50, function(value)
    local hum = getHum()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = value
    end
end)

-- Gravity Slider
PlayerTab:CreateSlider("World Gravity", 0, 196.2, 196.2, function(value)
    workspace.Gravity = value
end)

PlayerTab:CreateLabel("Advanced Movement")

-- Noclip Toggle
local noclipToggle = false
local noclipConnection
PlayerTab:CreateToggle("Noclip (Walk Through Walls)", false, function(state)
    noclipToggle = state
    if not state then
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        return
    end
    
    noclipConnection = RunService.Stepped:Connect(function()
        if not noclipToggle then
            if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
            return
        end
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end)

-- Infinite Jump Toggle
local infJumpToggle = false
local infJumpConnection
PlayerTab:CreateToggle("Infinite Jump", false, function(state)
    infJumpToggle = state
    if not state then
        if infJumpConnection then
            infJumpConnection:Disconnect()
            infJumpConnection = nil
        end
        return
    end
    
    infJumpConnection = UserInputService.JumpRequest:Connect(function()
        local hum = getHum()
        if infJumpToggle and hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end)

-- Fly Toggle and Speed
local flyToggle = false
local flySpeed = 50
local flyConnection

local function updateFlyState()
    local hum = getHum()
    local root = getRoot()

    if not flyToggle then
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        if hum then hum.PlatformStand = false end
        if root then
            local bv = root:FindFirstChild("FlyVelocity")
            local bg = root:FindFirstChild("FlyGyro")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
        return
    end

    if not root or not hum then return end
    humanoid = hum
    humanoid.PlatformStand = true
    
    local bv = root:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
    bv.Name = "FlyVelocity"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root

    local bg = root:FindFirstChild("FlyGyro") or Instance.new("BodyGyro")
    bg.Name = "FlyGyro"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.Parent = root

    local camera = workspace.CurrentCamera
    
    flyConnection = RunService.RenderStepped:Connect(function()
        local currentHum = getHum()
        local currentRoot = getRoot()

        if not flyToggle or not currentRoot or not currentRoot.Parent or not currentHum or not currentHum.Parent then
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            return
        end
        
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local vel = Vector3.new(0, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, 1, 0) end

        bg.CFrame = camera.CFrame
        if vel.Magnitude > 0 then
            bv.Velocity = vel.Unit * flySpeed
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

PlayerTab:CreateToggle("Fly", false, function(state)
    flyToggle = state
    updateFlyState()
end)

PlayerTab:CreateSlider("Fly Speed", 20, 200, 50, function(value)
    flySpeed = value
end)


-- =========================================================================
-- VISUALS (ESP) TAB FEATURES
-- =========================================================================

VisualsTab:CreateLabel("Player Highlighting (ESP)")

local espToggle = false
local highlights = {}

local function applyHighlight(player)
    if player == LocalPlayer then return end
    
    local function checkAndApply(char)
        if not espToggle then return end
        task.wait(0.2) -- Let the character load in fully
        if not char:FindFirstChild("ESPHighlight") then
            local hl = Instance.new("Highlight")
            hl.Name = "ESPHighlight"
            hl.FillColor = Color3.fromRGB(0, 180, 216)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0.1
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            highlights[player] = hl
        end
    end

    if player.Character then
        checkAndApply(player.Character)
    end
    player.CharacterAdded:Connect(checkAndApply)
end

local function clearHighlight(player)
    if highlights[player] then
        pcall(function() highlights[player]:Destroy() end)
        highlights[player] = nil
    end
    local char = player.Character
    if char then
        local hl = char:FindFirstChild("ESPHighlight")
        if hl then pcall(function() hl:Destroy() end) end
    end
end

VisualsTab:CreateToggle("Enable Player ESP", false, function(state)
    espToggle = state
    if state then
        for _, player in ipairs(Players:GetPlayers()) do
            applyHighlight(player)
        end
        Players.PlayerAdded:Connect(applyHighlight)
        Players.PlayerRemoving:Connect(clearHighlight)
    else
        for player, _ in pairs(highlights) do
            clearHighlight(player)
        end
    end
end)


-- =========================================================================
-- TELEPORT TAB FEATURES
-- =========================================================================

TeleportTab:CreateLabel("Coordinates & Mechanics")

-- Click to Teleport (CTRL + Click)
local clickTPToggle = false
local clickTPConnection
TeleportTab:CreateToggle("Click Teleport (CTRL + Click)", false, function(state)
    clickTPToggle = state
    if not state then
        if clickTPConnection then clickTPConnection:Disconnect() clickTPConnection = nil end
        return
    end
    
    local mouse = LocalPlayer:GetMouse()
    clickTPConnection = mouse.Button1Down:Connect(function()
        if clickTPToggle and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local root = getRoot()
            if root and mouse.Target then
                root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
                Window:Notify("Teleported", "Moved to target position.", 1.5)
            end
        end
    end)
end)

TeleportTab:CreateLabel("Teleport to Players")

-- Get list of player names (excluding local player)
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then
        table.insert(names, "No other players in server")
    end
    return names
end

local playerDropdown = TeleportTab:CreateDropdown("Select Player", getPlayerNames(), nil, function(name)
    local target = Players:FindFirstChild(name)
    local root = getRoot()
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        if root then
            root.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
            Window:Notify("Teleported", "Teleported to " .. name, 2)
        end
    else
        Window:Notify("Error", "Player character not found", 2)
    end
end)

-- Refresh Dropdown Button
TeleportTab:CreateButton("Refresh Player List", function()
    playerDropdown:Refresh(getPlayerNames())
    Window:Notify("List Refreshed", "Updated players list", 1.5)
end)


-- =========================================================================
-- SETTINGS TAB FEATURES
-- =========================================================================

SettingsTab:CreateLabel("Utilities")

-- Anti AFK
SettingsTab:CreateButton("Activate Anti-AFK", function()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    Window:Notify("Anti-AFK Enabled", "You will not get kicked for idling.", 3)
end)

-- Rejoin Game
SettingsTab:CreateButton("Rejoin Game", function()
    local TeleportService = game:GetService("TeleportService")
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

SettingsTab:CreateLabel("Tungsten Hub Control")

-- Theme Color Palette Selector
SettingsTab:CreateDropdown("UI Theme Palette", {"Tungsten", "Nebula", "BloodMoon", "Emerald", "Midnight"}, "Tungsten", function(themeName)
    local themeTable = TungstenHub.Themes[themeName]
    if themeTable then
        Window:SetTheme(themeTable)
        Window:Notify("Theme Loaded", "Applied the " .. themeName .. " theme palette.", 2)
    end
end)

-- Toggle Keybind Changer
local currentToggleKey = Enum.KeyCode.RightShift
local listeningForKeybind = false
local keybindButton

keybindButton = SettingsTab:CreateButton("Toggle Keybind: " .. currentToggleKey.Name, function()
    if listeningForKeybind then return end
    listeningForKeybind = true
    keybindButton.UpdateButtonText("Toggle Keybind: Press any key...")
    
    local connection
    connection = UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local pressedKey = input.KeyCode
            
            -- Ignore Escape so they can cancel the keybind selection
            if pressedKey == Enum.KeyCode.Escape then
                listeningForKeybind = false
                keybindButton.UpdateButtonText("Toggle Keybind: " .. currentToggleKey.Name)
                connection:Disconnect()
                return
            end
            
            currentToggleKey = pressedKey
            Window:SetToggleKey(pressedKey)
            keybindButton.UpdateButtonText("Toggle Keybind: " .. pressedKey.Name)
            Window:Notify("Keybind Updated", "Toggle key set to: " .. pressedKey.Name, 2)
            
            listeningForKeybind = false
            connection:Disconnect()
        end
    end)
end)

-- Destroy UI
SettingsTab:CreateButton("Destroy UI", function()
    local existing = game:GetService("CoreGui"):FindFirstChild("TungstenHub") or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("TungstenHub")
    if existing then
        existing:Destroy()
    end
end)

-- Welcome Notification
Window:Notify("Tungsten Hub", "Universal cheats loaded successfully!", 4)
