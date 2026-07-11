--[[
    Lyra UI Library - Universal Script Hub
    Loads the Lyra UI Library UI library from GitHub and implements real, working features:
    - Player Movement (WalkSpeed, JumpPower, Gravity, Fly, Noclip, Infinite Jump)
    - Visuals (ESP Highlighting using Roblox Highlights)
    - Teleports (Teleport to Players, Click-to-Teleport with CTRL+Click)
    - Utilities (Anti-AFK, Rejoin Game, Dynamic Theme Swapping)
    
    Loadstring to execute:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/JGRJGIRJGO/Lyra-Hub/main/UniversalV2.lua"))()
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

-- Load the Lyra UI Library UI Library from GitHub (with cache buster)
local success, Lyra = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/JGRJGIRJGO/Lyra-Hub/main/LyraV2.lua?t=" .. tostring(os.time())))()
end)

if not success or not Lyra then
    warn("Failed to load Lyra UI Library UI Library. Falling back to local require or erroring.")
    error("Lyra UI Library: Library load failed. Make sure you are connected to the internet.")
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

-- Pure Luau SHA-256 Hashing Algorithm
local function sha256_hash(msg)
    local h_init = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }
    local k = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }
    local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
    local rshift, lshift, rrotate = bit32.rshift, bit32.lshift, bit32.rrotate

    local function str2w(str)
        local words = {}
        for i = 1, #str, 4 do
            local b1, b2, b3, b4 = string.byte(str, i, i+3)
            b1 = b1 or 0 b2 = b2 or 0 b3 = b3 or 0 b4 = b4 or 0
            table.insert(words, bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4))
        end
        return words
    end

    local h = {unpack(h_init)}
    local msg_len = #msg
    local extra = msg_len % 64
    local pad_len = 56 - extra
    if pad_len <= 0 then pad_len = pad_len + 64 end
    
    local pad = string.char(0x80) .. string.rep(string.char(0), pad_len - 1)
    local bits = msg_len * 8
    local bits_bin = string.char(
        0, 0, 0, 0,
        math.floor(bits / 16777216) % 256,
        math.floor(bits / 65536) % 256,
        math.floor(bits / 256) % 256,
        bits % 256
    )
    
    local padded_msg = msg .. pad .. bits_bin
    local words = str2w(padded_msg)
    
    for block_start = 1, #words, 16 do
        local w = {}
        for i = 1, 16 do w[i] = words[block_start + i - 1] end
        for i = 17, 64 do
            local w15 = w[i-15]
            local s0 = bxor(rrotate(w15, 7), rrotate(w15, 18), rshift(w15, 3))
            local w2 = w[i-2]
            local s1 = bxor(rrotate(w2, 17), rrotate(w2, 19), rshift(w2, 10))
            w[i] = (w[i-16] + s0 + w[i-7] + s1) % 4294967296
        end
        
        local a, b, c, d, e, f, g, h_val = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 1, 64 do
            local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (h_val + s1 + ch + k[i] + w[i]) % 4294967296
            local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = (s0 + maj) % 4294967296
            
            h_val = g g = f f = e e = (d + temp1) % 4294967296
            d = c c = b b = a a = (temp1 + temp2) % 4294967296
        end
        
        h[1] = (h[1] + a) % 4294967296
        h[2] = (h[2] + b) % 4294967296
        h[3] = (h[3] + c) % 4294967296
        h[4] = (h[4] + d) % 4294967296
        h[5] = (h[5] + e) % 4294967296
        h[6] = (h[6] + f) % 4294967296
        h[7] = (h[7] + g) % 4294967296
        h[8] = (h[8] + h_val) % 4294967296
    end
    
    local hex = ""
    for i = 1, 8 do hex = hex .. string.format("%08x", h[i]) end
    return hex
end

local function getHashedHWID()
    return sha256_hash(getHardwareID()):upper()
end

local function getDailyHWIDKey()
    local hashedHwid = getHashedHWID()
    local dateStr = os.date("!%d%m%Y") -- Forced UTC date string to align with browser
    local salt = "LyraSecureKeySystem_V3_Reset_8F2D"
    local input = hashedHwid .. "_" .. salt .. "_" .. dateStr
    return "Lyra_" .. sha256_hash(input):upper()
end

-- Create Window with Secure HWID Key System
local Window = Lyra:CreateWindow({
    Name = "Lyra UI Library",
    Subtitle = "Universal",
    KeySettings = {
        Title = "Lyra Key Verification",
        Subtitle = "Lyra UI Library",
        Note = "Please enter your secure HWID-locked key to unlock features.",
        SaveKey = true,
        Key = getDailyHWIDKey(),
        Url = "https://jgrjgirjgo.github.io/Lyra-Hub/?hwid=" .. getHashedHWID()
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

SettingsTab:CreateLabel("Lyra UI Library Control")

-- Theme Color Palette Selector
SettingsTab:CreateDropdown("UI Theme Palette", {"Lyra", "Nebula", "BloodMoon", "Emerald", "Midnight"}, "Lyra", function(themeName)
    local themeTable = Lyra.Themes[themeName]
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
    local existing = game:GetService("CoreGui"):FindFirstChild("Lyra") or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Lyra")
    if existing then
        existing:Destroy()
    end
end)

-- Welcome Notification
Window:Notify("Lyra UI Library", "Universal cheats loaded successfully!", 4)
