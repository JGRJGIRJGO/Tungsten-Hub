--[[
    Lyra UI Library (V4)
    A clean, responsive command interface inspired by the interaction density
    of Starlight Interface Suite. This implementation is original and keeps
    Lyra's existing public API backward compatible.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Lyra = {}

Lyra.Themes = {
    Lyra = {
        Background = Color3.fromRGB(13, 15, 19),
        Header = Color3.fromRGB(20, 22, 27),
        Sidebar = Color3.fromRGB(24, 26, 31),
        Card = Color3.fromRGB(27, 30, 36),
        CardStroke = Color3.fromRGB(54, 59, 69),
        AccentGrad1 = Color3.fromRGB(201, 171, 255),
        AccentGrad2 = Color3.fromRGB(112, 203, 239),
        TextMain = Color3.fromRGB(244, 246, 250),
        TextDark = Color3.fromRGB(151, 157, 170),
    },
    Nebula = {
        Background = Color3.fromRGB(15, 13, 21),
        Header = Color3.fromRGB(23, 19, 31),
        Sidebar = Color3.fromRGB(27, 22, 36),
        Card = Color3.fromRGB(31, 25, 42),
        CardStroke = Color3.fromRGB(65, 51, 82),
        AccentGrad1 = Color3.fromRGB(189, 135, 255),
        AccentGrad2 = Color3.fromRGB(120, 191, 255),
        TextMain = Color3.fromRGB(247, 242, 255),
        TextDark = Color3.fromRGB(165, 151, 184),
    },
    BloodMoon = {
        Background = Color3.fromRGB(19, 14, 16),
        Header = Color3.fromRGB(29, 20, 23),
        Sidebar = Color3.fromRGB(33, 23, 27),
        Card = Color3.fromRGB(38, 26, 30),
        CardStroke = Color3.fromRGB(75, 46, 54),
        AccentGrad1 = Color3.fromRGB(255, 107, 129),
        AccentGrad2 = Color3.fromRGB(255, 174, 105),
        TextMain = Color3.fromRGB(255, 243, 245),
        TextDark = Color3.fromRGB(190, 154, 161),
    },
    Emerald = {
        Background = Color3.fromRGB(12, 18, 17),
        Header = Color3.fromRGB(18, 27, 25),
        Sidebar = Color3.fromRGB(21, 31, 28),
        Card = Color3.fromRGB(24, 36, 32),
        CardStroke = Color3.fromRGB(44, 72, 63),
        AccentGrad1 = Color3.fromRGB(91, 224, 168),
        AccentGrad2 = Color3.fromRGB(91, 194, 235),
        TextMain = Color3.fromRGB(240, 251, 247),
        TextDark = Color3.fromRGB(145, 178, 166),
    },
    Midnight = {
        Background = Color3.fromRGB(11, 15, 21),
        Header = Color3.fromRGB(17, 23, 32),
        Sidebar = Color3.fromRGB(20, 27, 37),
        Card = Color3.fromRGB(23, 31, 42),
        CardStroke = Color3.fromRGB(43, 60, 78),
        AccentGrad1 = Color3.fromRGB(104, 180, 255),
        AccentGrad2 = Color3.fromRGB(120, 229, 206),
        TextMain = Color3.fromRGB(240, 246, 255),
        TextDark = Color3.fromRGB(143, 161, 184),
    },
}

local function normalizeTheme(theme)
    theme = theme or Lyra.Themes.Lyra

    local normalized = {
        Background = theme.Background or Color3.fromRGB(13, 15, 19),
        Header = theme.Header or Color3.fromRGB(20, 22, 27),
        Sidebar = theme.Sidebar or Color3.fromRGB(24, 26, 31),
        Card = theme.Card or Color3.fromRGB(27, 30, 36),
        CardStroke = theme.CardStroke or Color3.fromRGB(54, 59, 69),
        AccentGrad1 = theme.AccentGrad1 or Color3.fromRGB(201, 171, 255),
        AccentGrad2 = theme.AccentGrad2 or Color3.fromRGB(112, 203, 239),
        TextMain = theme.TextMain or Color3.fromRGB(244, 246, 250),
        TextDark = theme.TextDark or Color3.fromRGB(151, 157, 170),
    }

    normalized.SurfaceHover = normalized.Card:Lerp(normalized.TextMain, 0.055)
    normalized.Input = normalized.Header:Lerp(normalized.Background, 0.18)
    normalized.Track = normalized.Background:Lerp(normalized.TextMain, 0.085)
    normalized.Danger = Color3.fromRGB(255, 103, 120)
    normalized.Success = Color3.fromRGB(91, 224, 168)

    return normalized
end

Lyra.Theme = normalizeTheme(Lyra.Themes.Lyra)
Lyra.ToggleKey = Enum.KeyCode.RightShift

local function sha256_hash(msg)
    local h_init = {
        0x6a09e667,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    }
    local k = {
        0x428a2f98,
        0x71374491,
        0xb5c0fbcf,
        0xe9b5dba5,
        0x3956c25b,
        0x59f111f1,
        0x923f82a4,
        0xab1c5ed5,
        0xd807aa98,
        0x12835b01,
        0x243185be,
        0x550c7dc3,
        0x72be5d74,
        0x80deb1fe,
        0x9bdc06a7,
        0xc19bf174,
        0xe49b69c1,
        0xefbe4786,
        0x0fc19dc6,
        0x240ca1cc,
        0x2de92c6f,
        0x4a7484aa,
        0x5cb0a9dc,
        0x76f988da,
        0x983e5152,
        0xa831c66d,
        0xb00327c8,
        0xbf597fc7,
        0xc6e00bf3,
        0xd5a79147,
        0x06ca6351,
        0x14292967,
        0x27b70a85,
        0x2e1b2138,
        0x4d2c6dfc,
        0x53380d13,
        0x650a7354,
        0x766a0abb,
        0x81c2c92e,
        0x92722c85,
        0xa2bfe8a1,
        0xa81a664b,
        0xc24b8b70,
        0xc76c51a3,
        0xd192e819,
        0xd6990624,
        0xf40e3585,
        0x106aa070,
        0x19a4c116,
        0x1e376c08,
        0x2748774c,
        0x34b0bcb5,
        0x391c0cb3,
        0x4ed8aa4a,
        0x5b9cca4f,
        0x682e6ff3,
        0x748f82ee,
        0x78a5636f,
        0x84c87814,
        0x8cc70208,
        0x90befffa,
        0xa4506ceb,
        0xbef9a3f7,
        0xc67178f2,
    }
    local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
    local rshift, lshift, rrotate = bit32.rshift, bit32.lshift, bit32.rrotate

    local function str2w(str)
        local words = {}

        for i = 1, #str, 4 do
            local b1, b2, b3, b4 = string.byte(str, i, i + 3)
            b1 = b1 or 0
            b2 = b2 or 0
            b3 = b3 or 0
            b4 = b4 or 0
            table.insert(words, bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4))
        end

        return words
    end

    local h = { unpack(h_init) }
    local msgLength = #msg
    local extra = msgLength % 64
    local padLength = 56 - extra

    if padLength <= 0 then
        padLength = padLength + 64
    end

    local pad = string.char(0x80) .. string.rep(string.char(0), padLength - 1)
    local bits = msgLength * 8
    local bitsBinary = string.char(
        0,
        0,
        0,
        0,
        math.floor(bits / 16777216) % 256,
        math.floor(bits / 65536) % 256,
        math.floor(bits / 256) % 256,
        bits % 256
    )
    local words = str2w(msg .. pad .. bitsBinary)

    for blockStart = 1, #words, 16 do
        local w = {}

        for i = 1, 16 do
            w[i] = words[blockStart + i - 1]
        end

        for i = 17, 64 do
            local w15 = w[i - 15]
            local s0 = bxor(rrotate(w15, 7), rrotate(w15, 18), rshift(w15, 3))
            local w2 = w[i - 2]
            local s1 = bxor(rrotate(w2, 17), rrotate(w2, 19), rshift(w2, 10))
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
        end

        local a, b, c, d = h[1], h[2], h[3], h[4]
        local e, f, g, hValue = h[5], h[6], h[7], h[8]

        for i = 1, 64 do
            local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (hValue + s1 + ch + k[i] + w[i]) % 4294967296
            local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = (s0 + maj) % 4294967296

            hValue = g
            g = f
            f = e
            e = (d + temp1) % 4294967296
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 4294967296
        end

        h[1] = (h[1] + a) % 4294967296
        h[2] = (h[2] + b) % 4294967296
        h[3] = (h[3] + c) % 4294967296
        h[4] = (h[4] + d) % 4294967296
        h[5] = (h[5] + e) % 4294967296
        h[6] = (h[6] + f) % 4294967296
        h[7] = (h[7] + g) % 4294967296
        h[8] = (h[8] + hValue) % 4294967296
    end

    local hex = ""

    for i = 1, 8 do
        hex = hex .. string.format("%08x", h[i])
    end

    return hex
end

Lyra.SHA256 = sha256_hash

local function makeElement(className, properties)
    local element = Instance.new(className)

    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            element[property] = value
        end
    end

    if properties and properties.Parent then
        element.Parent = properties.Parent
    end

    return element
end

local function addCorner(parent, radius)
    return makeElement("UICorner", {
        CornerRadius = UDim.new(0, radius or 5),
        Parent = parent,
    })
end

local function addStroke(parent, color, transparency, thickness)
    return makeElement("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function tween(instance, duration, properties, style, direction)
    if not instance or not instance.Parent then
        return nil
    end

    local animation = TweenService:Create(
        instance,
        TweenInfo.new(
            duration or 0.16,
            style or Enum.EasingStyle.Quad,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )
    animation:Play()
    return animation
end

local function runCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = table.pack(...)

    task.spawn(function()
        local ok, callbackError = pcall(callback, table.unpack(args, 1, args.n))

        if not ok then
            warn("[Lyra UI] Callback failed: " .. tostring(callbackError))
        end
    end)
end

local function pointInside(instance, position)
    if not instance or not instance.Parent then
        return false
    end

    local topLeft = instance.AbsolutePosition
    local size = instance.AbsoluteSize
    return position.X >= topLeft.X
        and position.Y >= topLeft.Y
        and position.X <= topLeft.X + size.X
        and position.Y <= topLeft.Y + size.Y
end

local function methodValue(owner, first, second)
    if first == owner then
        return second
    end

    return first
end

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, hiddenUi = pcall(gethui)

        if ok and hiddenUi then
            return hiddenUi
        end
    end

    local coreGui = game:GetService("CoreGui")
    local canUseCoreGui = pcall(function()
        local probe = Instance.new("Folder")
        probe.Name = "LyraProbe"
        probe.Parent = coreGui
        probe:Destroy()
    end)

    return canUseCoreGui and coreGui or PlayerGui
end

local GuiParent = getGuiParent()

local function cleanupExisting()
    local checked = {}

    for _, root in ipairs({ GuiParent, PlayerGui }) do
        if root and not checked[root] then
            checked[root] = true
            local existing = root:FindFirstChild("Lyra")

            if existing then
                existing:Destroy()
            end
        end
    end
end

local function setClipboard(text)
    if type(setclipboard) == "function" then
        setclipboard(text)
    elseif type(toclipboard) == "function" then
        toclipboard(text)
    end
end

local function getViewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(760, 500)
end

function Lyra:CreateWindow(titleOrConfig, subtitle)
    cleanupExisting()

    local config = type(titleOrConfig) == "table" and titleOrConfig or {}
    local titleText = type(titleOrConfig) == "table" and (config.Name or "Lyra") or (titleOrConfig or "Lyra")
    local subtitleText = type(titleOrConfig) == "table" and (config.Subtitle or "Interface") or (subtitle or "Interface")
    local keySettings = config.KeySettings
    local viewport = getViewport()
    local compact = viewport.X < 600
    local windowWidth = math.min(760, math.max(300, viewport.X - 16))
    local windowHeight = math.min(500, math.max(300, viewport.Y - 40))
    local sidebarWidth = windowWidth < 380 and 96 or (windowWidth < 520 and 112 or 174)
    local topbarHeight = 50
    local connections = {}
    local themeBindings = {}
    local themeUpdaters = {}
    local currentTheme = normalizeTheme(Lyra.Theme)

    local function track(connection)
        table.insert(connections, connection)
        return connection
    end

    local function bindTheme(instance, property, key)
        table.insert(themeBindings, {
            Instance = instance,
            Property = property,
            Key = key,
        })

        pcall(function()
            instance[property] = currentTheme[key]
        end)
    end

    local function addThemeUpdater(callback)
        table.insert(themeUpdaters, callback)
        pcall(callback, currentTheme)
    end

    local function addAccentGradient(parent, rotation)
        local gradient = makeElement("UIGradient", {
            Rotation = rotation or 0,
            Parent = parent,
        })

        addThemeUpdater(function(theme)
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, theme.AccentGrad1),
                ColorSequenceKeypoint.new(1, theme.AccentGrad2),
            })
        end)

        return gradient
    end

    local ScreenGui = makeElement("ScreenGui", {
        Name = "Lyra",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, ScreenGui)
    end

    ScreenGui.Parent = GuiParent

    local OverlayLayer = makeElement("Frame", {
        Name = "OverlayLayer",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = ScreenGui,
    })

    local initialX = math.floor((viewport.X - windowWidth) / 2)
    local initialY = math.floor((viewport.Y - windowHeight) / 2)
    local MainContainer = makeElement("Frame", {
        Name = "MainContainer",
        Size = UDim2.fromOffset(windowWidth, windowHeight),
        Position = UDim2.fromOffset(initialX, initialY),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        Parent = ScreenGui,
    })

    local WindowScale = makeElement("UIScale", {
        Scale = 1,
        Parent = MainContainer,
    })

    local Shadow = makeElement("Frame", {
        Name = "Shadow",
        Size = UDim2.new(1, 16, 1, 18),
        Position = UDim2.fromOffset(-8, -7),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.52,
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = MainContainer,
    })
    addCorner(Shadow, 10)

    local MainFrame = makeElement("Frame", {
        Name = "Window",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = MainContainer,
    })
    addCorner(MainFrame, 7)
    local MainStroke = addStroke(MainFrame, currentTheme.CardStroke, 0.25, 1)
    bindTheme(MainFrame, "BackgroundColor3", "Background")
    bindTheme(MainStroke, "Color", "CardStroke")

    local AccentStroke = addStroke(MainFrame, currentTheme.AccentGrad1, 0.73, 1)
    addThemeUpdater(function(theme)
        AccentStroke.Color = theme.AccentGrad1:Lerp(theme.AccentGrad2, 0.5)
    end)

    local Sidebar = makeElement("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = MainFrame,
    })
    bindTheme(Sidebar, "BackgroundColor3", "Sidebar")

    local SidebarDivider = makeElement("Frame", {
        Name = "Divider",
        Size = UDim2.new(0, 1, 1, -20),
        Position = UDim2.new(1, -1, 0, 10),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = Sidebar,
    })
    bindTheme(SidebarDivider, "BackgroundColor3", "CardStroke")

    local Brand = makeElement("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, -20, 0, 62),
        Position = UDim2.fromOffset(10, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Sidebar,
    })

    local BrandIcon = makeElement("Frame", {
        Name = "Icon",
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromOffset(0, 10),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Brand,
    })
    addCorner(BrandIcon, 7)
    addAccentGradient(BrandIcon, 35)

    makeElement("TextLabel", {
        Name = "Mark",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "L",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        ZIndex = 5,
        Parent = BrandIcon,
    })

    local BrandTitle = makeElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -42, 0, 19),
        Position = UDim2.fromOffset(42, 9),
        BackgroundTransparency = 1,
        Text = tostring(titleText),
        TextColor3 = currentTheme.TextMain,
        TextSize = compact and 12 or 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Brand,
    })
    bindTheme(BrandTitle, "TextColor3", "TextMain")

    local BrandSubtitle = makeElement("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(1, -42, 0, 15),
        Position = UDim2.fromOffset(42, 29),
        BackgroundTransparency = 1,
        Text = tostring(subtitleText),
        TextColor3 = currentTheme.TextDark,
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Brand,
    })
    bindTheme(BrandSubtitle, "TextColor3", "TextDark")

    local TabsList = makeElement("ScrollingFrame", {
        Name = "Tabs",
        Size = UDim2.new(1, -16, 1, -136),
        Position = UDim2.fromOffset(8, 74),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 4,
        Parent = Sidebar,
    })

    local TabsLayout = makeElement("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = TabsList,
    })

    track(TabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabsList.CanvasSize = UDim2.fromOffset(0, TabsLayout.AbsoluteContentSize.Y + 4)
    end))

    local Profile = makeElement("Frame", {
        Name = "Profile",
        Size = UDim2.new(1, -16, 0, 52),
        Position = UDim2.new(0, 8, 1, -58),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Sidebar,
    })

    local ProfileDivider = makeElement("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Parent = Profile,
    })
    bindTheme(ProfileDivider, "BackgroundColor3", "CardStroke")

    local Avatar = makeElement("ImageLabel", {
        Name = "Avatar",
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(2, 12),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 4,
        Parent = Profile,
    })
    addCorner(Avatar, 6)
    bindTheme(Avatar, "BackgroundColor3", "Card")

    local DisplayName = makeElement("TextLabel", {
        Size = UDim2.new(1, -42, 0, 16),
        Position = UDim2.fromOffset(40, 11),
        BackgroundTransparency = 1,
        Text = LocalPlayer.DisplayName,
        TextSize = 10.5,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Profile,
    })
    bindTheme(DisplayName, "TextColor3", "TextMain")

    local Username = makeElement("TextLabel", {
        Size = UDim2.new(1, -42, 0, 14),
        Position = UDim2.fromOffset(40, 27),
        BackgroundTransparency = 1,
        Text = "@" .. LocalPlayer.Name,
        TextSize = 9.5,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
        Parent = Profile,
    })
    bindTheme(Username, "TextColor3", "TextDark")

    task.spawn(function()
        local ok, image = pcall(
            Players.GetUserThumbnailAsync,
            Players,
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size48x48
        )

        if ok and Avatar.Parent then
            Avatar.Image = image
        end
    end)

    local Content = makeElement("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -sidebarWidth, 1, 0),
        Position = UDim2.fromOffset(sidebarWidth, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = MainFrame,
    })
    bindTheme(Content, "BackgroundColor3", "Background")

    local Topbar = makeElement("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, topbarHeight),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Content,
    })
    bindTheme(Topbar, "BackgroundColor3", "Header")

    local TopbarDivider = makeElement("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.new(0, 10, 1, -1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = Topbar,
    })
    bindTheme(TopbarDivider, "BackgroundColor3", "CardStroke")

    local PageTitle = makeElement("TextLabel", {
        Name = "PageTitle",
        Size = UDim2.new(1, -112, 0, 19),
        Position = UDim2.fromOffset(14, 8),
        BackgroundTransparency = 1,
        Text = "Overview",
        TextSize = 12.5,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = Topbar,
    })
    bindTheme(PageTitle, "TextColor3", "TextMain")

    local PageSubtitle = makeElement("TextLabel", {
        Name = "PageSubtitle",
        Size = UDim2.new(1, -112, 0, 14),
        Position = UDim2.fromOffset(14, 26),
        BackgroundTransparency = 1,
        Text = tostring(subtitleText),
        TextSize = 9.5,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = Topbar,
    })
    bindTheme(PageSubtitle, "TextColor3", "TextDark")

    local DragHandle = makeElement("Frame", {
        Name = "DragHandle",
        Size = UDim2.new(1, -84, 1, 0),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 6,
        Parent = Topbar,
    })

    local Controls = makeElement("Frame", {
        Name = "Controls",
        Size = UDim2.fromOffset(70, 32),
        Position = UDim2.new(1, -78, 0, 9),
        BackgroundTransparency = 1,
        ZIndex = 7,
        Parent = Topbar,
    })

    local function makeWindowControl(name, text, x)
        local button = makeElement("TextButton", {
            Name = name,
            Size = UDim2.fromOffset(30, 28),
            Position = UDim2.fromOffset(x, 2),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = text,
            TextSize = 14,
            Font = Enum.Font.GothamMedium,
            AutoButtonColor = false,
            ZIndex = 8,
            Parent = Controls,
        })
        addCorner(button, 5)
        bindTheme(button, "BackgroundColor3", "Card")
        bindTheme(button, "TextColor3", "TextDark")

        track(button.MouseEnter:Connect(function()
            tween(button, 0.12, {
                BackgroundTransparency = 0,
                TextColor3 = currentTheme.TextMain,
            })
        end))

        track(button.MouseLeave:Connect(function()
            tween(button, 0.12, {
                BackgroundTransparency = 1,
                TextColor3 = currentTheme.TextDark,
            })
        end))

        return button
    end

    local MinimizeButton = makeWindowControl("Minimize", "-", 2)
    local CloseButton = makeWindowControl("Close", "x", 38)

    track(CloseButton.MouseEnter:Connect(function()
        tween(CloseButton, 0.12, {
            BackgroundTransparency = 0,
            TextColor3 = currentTheme.Danger,
        })
    end))

    local PageHost = makeElement("Frame", {
        Name = "PageHost",
        Size = UDim2.new(1, 0, 1, -topbarHeight),
        Position = UDim2.fromOffset(0, topbarHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = Content,
    })

    local Window = {
        Tabs = {},
        ActiveTab = nil,
        ScreenGui = ScreenGui,
        MainContainer = MainContainer,
        _openDropdown = nil,
    }

    local unlocked = false
    local isVisible = false
    local isAnimating = false
    local fitScale = 1
    local toggleKey = Lyra.ToggleKey or Enum.KeyCode.RightShift

    local function closeOpenDropdown()
        if Window._openDropdown and Window._openDropdown.Close then
            Window._openDropdown.Close()
        end
    end

    local function disconnectAll()
        for _, connection in ipairs(connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        table.clear(connections)
    end

    track(ScreenGui.Destroying:Connect(function()
        disconnectAll()
    end))

    function Window:Destroy()
        disconnectAll()

        if ScreenGui.Parent then
            ScreenGui:Destroy()
        end
    end

    function Window:SetTheme(theme)
        currentTheme = normalizeTheme(theme)
        Lyra.Theme = currentTheme

        for _, binding in ipairs(themeBindings) do
            if binding.Instance and binding.Instance.Parent then
                pcall(function()
                    binding.Instance[binding.Property] = currentTheme[binding.Key]
                end)
            end
        end

        for _, updater in ipairs(themeUpdaters) do
            pcall(updater, currentTheme)
        end

        return currentTheme
    end

    function Window:SetToggleKey(newKey)
        if typeof(newKey) == "EnumItem" and newKey.EnumType == Enum.KeyCode then
            toggleKey = newKey
            Lyra.ToggleKey = newKey
            return true
        end

        return false
    end

    local MobileButton

    local function showWindow()
        if isAnimating or not unlocked then
            return
        end

        isAnimating = true
        isVisible = true
        MainContainer.Visible = true
        WindowScale.Scale = fitScale * 0.965
        tween(WindowScale, 0.22, { Scale = fitScale }, Enum.EasingStyle.Quint)

        task.delay(0.23, function()
            isAnimating = false
        end)
    end

    local function hideWindow()
        if isAnimating or not unlocked then
            return
        end

        isAnimating = true
        closeOpenDropdown()
        local hideTween = tween(
            WindowScale,
            0.16,
            { Scale = fitScale * 0.97 },
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        )

        if hideTween then
            track(hideTween.Completed:Connect(function()
                MainContainer.Visible = false
                isVisible = false
                isAnimating = false
            end))
        else
            MainContainer.Visible = false
            isVisible = false
            isAnimating = false
        end
    end

    function Window:Toggle()
        if isVisible then
            hideWindow()
        else
            showWindow()
        end
    end

    local dragging = false
    local dragInput
    local dragStart
    local dragOrigin

    track(DragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            dragOrigin = MainContainer.Position

            track(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end))
        end
    end))

    track(DragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            local currentViewport = getViewport()
            local minX = -windowWidth + 84
            local maxX = currentViewport.X - 84
            local minY = 0
            local maxY = currentViewport.Y - 42
            local x = math.clamp(dragOrigin.X.Offset + delta.X, minX, maxX)
            local y = math.clamp(dragOrigin.Y.Offset + delta.Y, minY, maxY)
            MainContainer.Position = UDim2.fromOffset(x, y)
        end
    end))

    track(MinimizeButton.MouseButton1Click:Connect(hideWindow))
    track(CloseButton.MouseButton1Click:Connect(function()
        Window:Destroy()
    end))

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == toggleKey then
            Window:Toggle()
            return
        end

        if Window._openDropdown
            and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
        then
            local openDropdown = Window._openDropdown

            if not pointInside(openDropdown.Frame, input.Position) and not pointInside(openDropdown.Row, input.Position) then
                openDropdown.Close()
            end
        end
    end))

    if UserInputService.TouchEnabled then
        MobileButton = makeElement("TextButton", {
            Name = "MobileToggle",
            Size = UDim2.fromOffset(44, 44),
            Position = UDim2.fromOffset(14, math.max(14, math.floor(viewport.Y * 0.18))),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = "L",
            TextSize = 15,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 90,
            Parent = ScreenGui,
        })
        addCorner(MobileButton, 8)
        local MobileStroke = addStroke(MobileButton, currentTheme.CardStroke, 0.15, 1)
        addAccentGradient(MobileButton, 35)
        bindTheme(MobileStroke, "Color", "CardStroke")

        local mobileDragging = false
        local mobileMoved = false
        local mobileStart
        local mobileOrigin

        track(MobileButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                mobileDragging = true
                mobileMoved = false
                mobileStart = input.Position
                mobileOrigin = MobileButton.Position

                track(input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        mobileDragging = false

                        if not mobileMoved then
                            Window:Toggle()
                        end
                    end
                end))
            end
        end))

        track(UserInputService.InputChanged:Connect(function(input)
            if mobileDragging
                and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement)
            then
                local delta = input.Position - mobileStart

                if delta.Magnitude > 5 then
                    mobileMoved = true
                end

                local currentViewport = getViewport()
                local x = math.clamp(mobileOrigin.X.Offset + delta.X, 6, currentViewport.X - 50)
                local y = math.clamp(mobileOrigin.Y.Offset + delta.Y, 6, currentViewport.Y - 50)
                MobileButton.Position = UDim2.fromOffset(x, y)
            end
        end))
    end

    local function fitWindowToViewport()
        local currentViewport = getViewport()
        fitScale = math.min(1, (currentViewport.X - 12) / windowWidth, (currentViewport.Y - 12) / windowHeight)
        WindowScale.Scale = fitScale
        MainContainer.Position = UDim2.fromOffset(
            math.floor((currentViewport.X - (windowWidth * fitScale)) / 2),
            math.floor((currentViewport.Y - (windowHeight * fitScale)) / 2)
        )

        if MobileButton then
            MobileButton.Position = UDim2.fromOffset(
                math.clamp(MobileButton.Position.X.Offset, 6, currentViewport.X - 50),
                math.clamp(MobileButton.Position.Y.Offset, 6, currentViewport.Y - 50)
            )
        end
    end

    local camera = workspace.CurrentCamera

    if camera then
        track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            closeOpenDropdown()
            fitWindowToViewport()
        end))
    end

    fitWindowToViewport()

    local function createRow(tab, rowName, height)
        tab._order = tab._order + 1
        local row = makeElement("Frame", {
            Name = rowName,
            Size = UDim2.new(1, -2, 0, height),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Active = true,
            LayoutOrder = tab._order,
            Parent = tab.Page,
        })
        addCorner(row, 5)
        local rowStroke = addStroke(row, currentTheme.CardStroke, 0.48, 1)
        bindTheme(row, "BackgroundColor3", "Card")
        bindTheme(rowStroke, "Color", "CardStroke")

        local accent = makeElement("Frame", {
            Name = "Accent",
            Size = UDim2.new(0, 2, 0, math.max(16, height - 18)),
            Position = UDim2.new(0, 0, 0.5, -math.max(16, height - 18) / 2),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 2,
            Parent = row,
        })
        addCorner(accent, 2)
        addAccentGradient(accent, 90)

        track(row.MouseEnter:Connect(function()
            tween(row, 0.13, { BackgroundColor3 = currentTheme.SurfaceHover })
            tween(rowStroke, 0.13, {
                Color = currentTheme.AccentGrad2,
                Transparency = 0.34,
            })
            tween(accent, 0.13, { BackgroundTransparency = 0 })
        end))

        track(row.MouseLeave:Connect(function()
            tween(row, 0.13, { BackgroundColor3 = currentTheme.Card })
            tween(rowStroke, 0.13, {
                Color = currentTheme.CardStroke,
                Transparency = 0.48,
            })
            tween(accent, 0.13, { BackgroundTransparency = 1 })
        end))

        return row, rowStroke, accent
    end

    local function createRowLabel(row, text, rightPadding)
        local label = makeElement("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -(rightPadding or 56), 1, 0),
            Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1,
            Text = tostring(text or "Control"),
            TextSize = 11.5,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
            Parent = row,
        })
        bindTheme(label, "TextColor3", "TextMain")
        return label
    end

    function Window:CreateTab(tabNameOrConfig)
        local tabConfig = type(tabNameOrConfig) == "table" and tabNameOrConfig or {}
        local tabName = type(tabNameOrConfig) == "table" and (tabConfig.Name or "Tab") or (tabNameOrConfig or "Tab")
        local tabIndex = #self.Tabs + 1
        local TabButton = makeElement("TextButton", {
            Name = tostring(tabName) .. "Tab",
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = tabIndex,
            ZIndex = 5,
            Parent = TabsList,
        })
        addCorner(TabButton, 5)

        local ActiveFill = makeElement("Frame", {
            Name = "ActiveFill",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = TabButton,
        })
        addCorner(ActiveFill, 5)
        addAccentGradient(ActiveFill, 12)

        local Monogram = makeElement("Frame", {
            Name = "Monogram",
            Size = UDim2.fromOffset(24, 24),
            Position = UDim2.fromOffset(7, 8),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 6,
            Parent = TabButton,
        })
        addCorner(Monogram, 5)
        bindTheme(Monogram, "BackgroundColor3", "Card")

        local MonogramText = makeElement("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = string.upper(tostring(tabName):sub(1, 1)),
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            ZIndex = 7,
            Parent = Monogram,
        })
        bindTheme(MonogramText, "TextColor3", "TextDark")

        local TabLabel = makeElement("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -42, 1, 0),
            Position = UDim2.fromOffset(38, 0),
            BackgroundTransparency = 1,
            Text = tostring(tabName),
            TextSize = compact and 10.5 or 11,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 7,
            Parent = TabButton,
        })
        bindTheme(TabLabel, "TextColor3", "TextDark")

        local Page = makeElement("ScrollingFrame", {
            Name = tostring(tabName) .. "Page",
            Size = UDim2.new(1, -24, 1, -22),
            Position = UDim2.fromOffset(12, 11),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageTransparency = 0.25,
            CanvasSize = UDim2.fromOffset(0, 0),
            Visible = false,
            ZIndex = 4,
            Parent = PageHost,
        })
        bindTheme(Page, "ScrollBarImageColor3", "AccentGrad2")

        local PageLayout = makeElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = Page,
        })

        track(PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.fromOffset(0, PageLayout.AbsoluteContentSize.Y + 4)
        end))

        local Tab = {
            Name = tostring(tabName),
            Button = TabButton,
            Page = Page,
            _order = 0,
        }

        local function applySelection(selected, animate)
            if selected then
                ActiveFill.BackgroundTransparency = animate and 1 or 0.1
                tween(ActiveFill, 0.18, { BackgroundTransparency = 0.1 })
                tween(TabLabel, 0.15, { TextColor3 = Color3.fromRGB(255, 255, 255) })
                tween(Monogram, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.84 })
                tween(MonogramText, 0.15, { TextColor3 = Color3.fromRGB(255, 255, 255) })
            else
                tween(ActiveFill, 0.15, { BackgroundTransparency = 1 })
                tween(TabLabel, 0.15, { TextColor3 = currentTheme.TextDark })
                tween(Monogram, 0.15, { BackgroundColor3 = currentTheme.Card, BackgroundTransparency = 0 })
                tween(MonogramText, 0.15, { TextColor3 = currentTheme.TextDark })
            end
        end

        function Tab:Select()
            if Window.ActiveTab == self then
                return
            end

            closeOpenDropdown()

            if Window.ActiveTab then
                Window.ActiveTab.Page.Visible = false
                Window.ActiveTab._applySelection(false, true)
            end

            Window.ActiveTab = self
            PageTitle.Text = self.Name
            self.Page.Position = UDim2.fromOffset(18, 11)
            self.Page.Visible = true
            tween(self.Page, 0.18, { Position = UDim2.fromOffset(12, 11) }, Enum.EasingStyle.Quint)
            self._applySelection(true, true)
        end

        Tab._applySelection = applySelection

        function Tab:SetName(newName)
            self.Name = tostring(newName or self.Name)
            TabLabel.Text = self.Name
            MonogramText.Text = string.upper(self.Name:sub(1, 1))

            if Window.ActiveTab == self then
                PageTitle.Text = self.Name
            end
        end

        track(TabButton.MouseButton1Click:Connect(function()
            Tab:Select()
        end))

        track(TabButton.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                tween(TabButton, 0.12, {
                    BackgroundColor3 = currentTheme.Card,
                    BackgroundTransparency = 0.45,
                })
            end
        end))

        track(TabButton.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                tween(TabButton, 0.12, { BackgroundTransparency = 1 })
            end
        end))

        addThemeUpdater(function(theme)
            if Window.ActiveTab ~= Tab then
                TabLabel.TextColor3 = theme.TextDark
                Monogram.BackgroundColor3 = theme.Card
                MonogramText.TextColor3 = theme.TextDark
            end
        end)

        function Tab:CreateLabel(textOrConfig)
            local labelConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (labelConfig.Text or labelConfig.Name or "Section")
                or (textOrConfig or "Section")
            self._order = self._order + 1
            local holder = makeElement("Frame", {
                Name = "Section",
                Size = UDim2.new(1, -2, 0, compact and 40 or 32),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = self._order,
                Parent = self.Page,
            })

            local marker = makeElement("Frame", {
                Size = UDim2.fromOffset(2, 14),
                Position = UDim2.new(0, 2, 0.5, -7),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Parent = holder,
            })
            addCorner(marker, 2)
            addAccentGradient(marker, 90)

            local label = makeElement("TextLabel", {
                Size = UDim2.new(1, -14, 1, 0),
                Position = UDim2.fromOffset(12, 0),
                BackgroundTransparency = 1,
                Text = tostring(text),
                TextSize = 10.5,
                Font = Enum.Font.GothamBold,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                Parent = holder,
            })
            bindTheme(label, "TextColor3", "TextDark")

            local control = {}
            control.UpdateText = function(first, second)
                label.Text = tostring(methodValue(control, first, second) or "")
            end
            control.SetText = control.UpdateText
            return control
        end

        Tab.CreateSection = Tab.CreateLabel

        function Tab:CreateButton(textOrConfig, callback)
            local buttonConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (buttonConfig.Name or buttonConfig.Text or "Button")
                or (textOrConfig or "Button")
            callback = type(textOrConfig) == "table" and (buttonConfig.Callback or callback) or callback

            local row = createRow(self, "Button", 42)
            local label = createRowLabel(row, text, 52)
            local action = makeElement("Frame", {
                Size = UDim2.fromOffset(26, 26),
                Position = UDim2.new(1, -34, 0.5, -13),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(action, 5)
            bindTheme(action, "BackgroundColor3", "Header")

            local actionLabel = makeElement("TextLabel", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = ">",
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                ZIndex = 4,
                Parent = action,
            })
            bindTheme(actionLabel, "TextColor3", "TextDark")

            local click = makeElement("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 5,
                Parent = row,
            })

            local disabled = buttonConfig.Disabled == true

            track(click.MouseButton1Click:Connect(function()
                if disabled then
                    return
                end

                tween(action, 0.07, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -32, 0.5, -11) })
                task.delay(0.08, function()
                    tween(action, 0.12, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -34, 0.5, -13) })
                end)
                runCallback(callback)
            end))

            local control = {}
            control.UpdateButtonText = function(first, second)
                label.Text = tostring(methodValue(control, first, second) or "")
            end
            control.SetText = control.UpdateButtonText
            control.SetDisabled = function(first, second)
                disabled = methodValue(control, first, second) == true
                label.TextTransparency = disabled and 0.45 or 0
                actionLabel.TextTransparency = disabled and 0.45 or 0
            end
            return control
        end

        function Tab:CreateToggle(textOrConfig, default, callback)
            local toggleConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (toggleConfig.Name or toggleConfig.Text or "Toggle")
                or (textOrConfig or "Toggle")

            if type(textOrConfig) == "table" then
                default = toggleConfig.CurrentValue

                if default == nil then
                    default = toggleConfig.Default
                end

                callback = toggleConfig.Callback or callback
            end

            local state = default == true
            local row = createRow(self, "Toggle", 42)
            createRowLabel(row, text, 68)

            local switch = makeElement("Frame", {
                Name = "Switch",
                Size = UDim2.fromOffset(38, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(switch, 10)
            local switchStroke = addStroke(switch, currentTheme.CardStroke, 0.4, 1)
            bindTheme(switchStroke, "Color", "CardStroke")

            local knob = makeElement("Frame", {
                Name = "Knob",
                Size = UDim2.fromOffset(14, 14),
                BackgroundColor3 = currentTheme.TextDark,
                BorderSizePixel = 0,
                ZIndex = 4,
                Parent = switch,
            })
            addCorner(knob, 7)

            local click = makeElement("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 5,
                Parent = row,
            })

            local function render(animate)
                local switchColor = state and currentTheme.AccentGrad2 or currentTheme.Input
                local knobColor = state and Color3.fromRGB(255, 255, 255) or currentTheme.TextDark
                local knobPosition = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)

                if animate then
                    tween(switch, 0.16, { BackgroundColor3 = switchColor })
                    tween(knob, 0.2, {
                        Position = knobPosition,
                        BackgroundColor3 = knobColor,
                    }, Enum.EasingStyle.Back)
                else
                    switch.BackgroundColor3 = switchColor
                    knob.Position = knobPosition
                    knob.BackgroundColor3 = knobColor
                end
            end

            local function setState(newState, fireCallback, animate)
                state = newState == true
                render(animate ~= false)

                if fireCallback then
                    runCallback(callback, state)
                end
            end

            track(click.MouseButton1Click:Connect(function()
                setState(not state, true, true)
            end))

            addThemeUpdater(function()
                render(false)
            end)
            setState(state, true, false)

            local control = {}
            control.SetToggle = function(first, second)
                setState(methodValue(control, first, second), true, true)
            end
            control.SetValue = control.SetToggle
            control.GetValue = function()
                return state
            end
            return control
        end

        function Tab:CreateSlider(textOrConfig, minimum, maximum, default, callback)
            local sliderConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (sliderConfig.Name or sliderConfig.Text or "Slider")
                or (textOrConfig or "Slider")

            if type(textOrConfig) == "table" then
                minimum = sliderConfig.Min or (sliderConfig.Range and sliderConfig.Range[1]) or 0
                maximum = sliderConfig.Max or (sliderConfig.Range and sliderConfig.Range[2]) or 100
                default = sliderConfig.CurrentValue

                if default == nil then
                    default = sliderConfig.Default
                end

                callback = sliderConfig.Callback or callback
            end

            minimum = tonumber(minimum) or 0
            maximum = tonumber(maximum) or 100

            if maximum < minimum then
                minimum, maximum = maximum, minimum
            end

            default = math.clamp(tonumber(default) or minimum, minimum, maximum)
            local increment = tonumber(sliderConfig.Increment)

            if not increment or increment <= 0 then
                increment = (minimum % 1 ~= 0 or maximum % 1 ~= 0 or default % 1 ~= 0) and 0.1 or 1
            end

            local value = default
            local row = createRow(self, "Slider", 58)
            createRowLabel(row, text, 82).Size = UDim2.new(1, -94, 0, 28)

            local valueBox = makeElement("TextLabel", {
                Size = UDim2.fromOffset(62, 22),
                Position = UDim2.new(1, -74, 0, 7),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                TextSize = 10.5,
                Font = Enum.Font.GothamBold,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(valueBox, 4)
            bindTheme(valueBox, "BackgroundColor3", "Input")
            bindTheme(valueBox, "TextColor3", "TextDark")

            local trackFrame = makeElement("Frame", {
                Name = "Track",
                Size = UDim2.new(1, -24, 0, 4),
                Position = UDim2.new(0, 12, 1, -15),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(trackFrame, 2)
            bindTheme(trackFrame, "BackgroundColor3", "Track")

            local progress = makeElement("Frame", {
                Name = "Progress",
                Size = UDim2.fromScale(0, 1),
                BackgroundColor3 = currentTheme.AccentGrad1,
                BorderSizePixel = 0,
                ZIndex = 4,
                Parent = trackFrame,
            })
            addCorner(progress, 2)
            addAccentGradient(progress, 0)

            local handle = makeElement("Frame", {
                Name = "Handle",
                Size = UDim2.fromOffset(12, 12),
                Position = UDim2.new(1, -6, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 5,
                Parent = progress,
            })
            addCorner(handle, 6)
            addStroke(handle, Color3.fromRGB(20, 22, 27), 0.35, 1)

            local trigger = makeElement("TextButton", {
                Size = UDim2.new(1, 8, 0, 22),
                Position = UDim2.fromOffset(-4, -9),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 6,
                Parent = trackFrame,
            })

            local draggingSlider = false

            local incrementText = string.format("%.6f", increment):gsub("0+$", ""):gsub("%.$", "")
            local decimalPart = incrementText:match("%.(%d+)$")
            local decimalPlaces = decimalPart and #decimalPart or 0

            local function formatValue(number)
                if increment >= 1 then
                    return tostring(math.floor(number + 0.5))
                end

                return string.format("%." .. tostring(math.max(1, decimalPlaces)) .. "f", number)
            end

            local function render(animate)
                local range = maximum - minimum
                local percent = range == 0 and 0 or math.clamp((value - minimum) / range, 0, 1)
                valueBox.Text = formatValue(value)

                if animate then
                    tween(progress, 0.08, { Size = UDim2.fromScale(percent, 1) })
                else
                    progress.Size = UDim2.fromScale(percent, 1)
                end
            end

            local function setValue(newValue, fireCallback, animate)
                local rounded = math.floor(((tonumber(newValue) or minimum) - minimum) / increment + 0.5) * increment + minimum
                value = math.clamp(rounded, minimum, maximum)
                render(animate ~= false)

                if fireCallback then
                    runCallback(callback, value)
                end
            end

            local function updateFromInput(input)
                local width = trackFrame.AbsoluteSize.X

                if width <= 0 then
                    return
                end

                local percent = math.clamp((input.Position.X - trackFrame.AbsolutePosition.X) / width, 0, 1)
                setValue(minimum + ((maximum - minimum) * percent), true, true)
            end

            track(trigger.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    updateFromInput(input)
                    tween(handle, 0.12, { Size = UDim2.fromOffset(15, 15), Position = UDim2.new(1, -7.5, 0.5, -7.5) })
                end
            end))

            track(UserInputService.InputChanged:Connect(function(input)
                if draggingSlider
                    and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
                then
                    updateFromInput(input)
                end
            end))

            track(UserInputService.InputEnded:Connect(function(input)
                if draggingSlider
                    and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
                then
                    draggingSlider = false
                    tween(handle, 0.12, { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -6, 0.5, -6) })
                end
            end))

            render(false)

            local control = {}
            control.SetValue = function(first, second)
                setValue(methodValue(control, first, second), true, true)
            end
            control.GetValue = function()
                return value
            end
            return control
        end

        function Tab:CreateDropdown(textOrConfig, list, default, callback)
            local dropdownConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (dropdownConfig.Name or dropdownConfig.Text or "Dropdown")
                or (textOrConfig or "Dropdown")

            if type(textOrConfig) == "table" then
                list = dropdownConfig.Options or dropdownConfig.List or {}
                default = dropdownConfig.CurrentOption

                if type(default) == "table" then
                    default = default[1]
                end

                if default == nil then
                    default = dropdownConfig.Default
                end

                callback = dropdownConfig.Callback or callback
            end

            list = type(list) == "table" and list or {}
            local active = default

            if active == nil then
                active = list[1]
            end

            local row = createRow(self, "Dropdown", 42)
            createRowLabel(row, text, 150)

            local selected = makeElement("TextLabel", {
                Size = UDim2.fromOffset(104, 26),
                Position = UDim2.new(1, -138, 0.5, -13),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Text = tostring(active or "None"),
                TextSize = 10.5,
                Font = Enum.Font.GothamSemibold,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(selected, 4)
            bindTheme(selected, "BackgroundColor3", "Input")
            bindTheme(selected, "TextColor3", "AccentGrad2")

            local arrow = makeElement("TextLabel", {
                Size = UDim2.fromOffset(24, 24),
                Position = UDim2.new(1, -30, 0.5, -12),
                BackgroundTransparency = 1,
                Text = "v",
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                ZIndex = 4,
                Parent = row,
            })
            bindTheme(arrow, "TextColor3", "TextDark")

            local click = makeElement("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 5,
                Parent = row,
            })

            local popup = makeElement("Frame", {
                Name = "DropdownPopup",
                Size = UDim2.fromOffset(180, 0),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 110,
                Parent = OverlayLayer,
            })
            addCorner(popup, 6)
            local popupStroke = addStroke(popup, currentTheme.CardStroke, 0.2, 1)
            bindTheme(popup, "BackgroundColor3", "Header")
            bindTheme(popupStroke, "Color", "CardStroke")

            local options = makeElement("ScrollingFrame", {
                Size = UDim2.new(1, -10, 1, -10),
                Position = UDim2.fromOffset(5, 5),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                CanvasSize = UDim2.fromOffset(0, 0),
                ZIndex = 111,
                Parent = popup,
            })
            bindTheme(options, "ScrollBarImageColor3", "AccentGrad2")

            local optionLayout = makeElement("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 3),
                Parent = options,
            })

            local open = false
            local closeToken = 0
            local targetHeight = 0
            local optionConnections = {}

            local function trackOption(connection)
                table.insert(optionConnections, connection)
                return connection
            end

            local function positionPopup()
                local currentViewport = getViewport()
                local width = math.clamp(row.AbsoluteSize.X, 150, 240)
                local x = row.AbsolutePosition.X + row.AbsoluteSize.X - width
                local belowY = row.AbsolutePosition.Y + row.AbsoluteSize.Y + 5
                local y = belowY

                if belowY + targetHeight > currentViewport.Y - 8 then
                    y = math.max(8, row.AbsolutePosition.Y - targetHeight - 5)
                end

                popup.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
                popup.Size = UDim2.fromOffset(width, popup.Size.Y.Offset)
            end

            local function closePopup()
                if not open then
                    if Window._openDropdown and Window._openDropdown.Frame == popup then
                        Window._openDropdown = nil
                    end
                    return
                end

                open = false
                closeToken = closeToken + 1
                local token = closeToken
                arrow.Text = "v"
                tween(popup, 0.14, { Size = UDim2.fromOffset(popup.Size.X.Offset, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

                task.delay(0.15, function()
                    if token == closeToken and not open and popup.Parent then
                        popup.Visible = false
                    end
                end)

                if Window._openDropdown and Window._openDropdown.Frame == popup then
                    Window._openDropdown = nil
                end
            end

            local function openPopup()
                if Window._openDropdown and Window._openDropdown.Frame ~= popup then
                    Window._openDropdown.Close()
                end

                open = true
                closeToken = closeToken + 1
                arrow.Text = "^"
                positionPopup()
                popup.Size = UDim2.fromOffset(popup.Size.X.Offset, 0)
                popup.Visible = true
                tween(popup, 0.18, { Size = UDim2.fromOffset(popup.Size.X.Offset, targetHeight) }, Enum.EasingStyle.Quint)
                Window._openDropdown = {
                    Frame = popup,
                    Row = row,
                    Close = closePopup,
                }
            end

            local function selectOption(option, fireCallback)
                active = option
                selected.Text = tostring(option or "None")

                if fireCallback then
                    runCallback(callback, option)
                end
            end

            local function rebuild()
                for _, connection in ipairs(optionConnections) do
                    pcall(function()
                        connection:Disconnect()
                    end)
                end

                table.clear(optionConnections)

                for _, child in ipairs(options:GetChildren()) do
                    if child:IsA("GuiButton") then
                        child:Destroy()
                    end
                end

                for index, option in ipairs(list) do
                    local optionButton = makeElement("TextButton", {
                        Name = "Option" .. tostring(index),
                        Size = UDim2.new(1, -2, 0, 29),
                        BackgroundTransparency = option == active and 0.2 or 1,
                        BorderSizePixel = 0,
                        Text = tostring(option),
                        TextSize = 10.5,
                        Font = option == active and Enum.Font.GothamSemibold or Enum.Font.GothamMedium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        LayoutOrder = index,
                        ZIndex = 112,
                        Parent = options,
                    })
                    addCorner(optionButton, 4)
                    makeElement("UIPadding", {
                        PaddingLeft = UDim.new(0, 9),
                        PaddingRight = UDim.new(0, 7),
                        Parent = optionButton,
                    })
                    bindTheme(optionButton, "BackgroundColor3", "Card")
                    bindTheme(optionButton, "TextColor3", option == active and "TextMain" or "TextDark")

                    trackOption(optionButton.MouseEnter:Connect(function()
                        tween(optionButton, 0.1, {
                            BackgroundTransparency = 0.12,
                            TextColor3 = currentTheme.TextMain,
                        })
                    end))

                    trackOption(optionButton.MouseLeave:Connect(function()
                        tween(optionButton, 0.1, {
                            BackgroundTransparency = option == active and 0.2 or 1,
                            TextColor3 = option == active and currentTheme.TextMain or currentTheme.TextDark,
                        })
                    end))

                    trackOption(optionButton.MouseButton1Click:Connect(function()
                        selectOption(option, true)
                        rebuild()
                        closePopup()
                    end))
                end

                targetHeight = math.clamp((#list * 32) + 10, 42, 182)
                options.CanvasSize = UDim2.fromOffset(0, optionLayout.AbsoluteContentSize.Y)

                if open then
                    positionPopup()
                    popup.Size = UDim2.fromOffset(popup.Size.X.Offset, targetHeight)
                end
            end

            track(optionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                options.CanvasSize = UDim2.fromOffset(0, optionLayout.AbsoluteContentSize.Y)
            end))

            track(click.MouseButton1Click:Connect(function()
                if open then
                    closePopup()
                else
                    openPopup()
                end
            end))

            rebuild()

            local control = {}
            control.Select = function(first, second)
                local option = methodValue(control, first, second)
                selectOption(option, true)
                rebuild()
            end
            control.Refresh = function(first, second)
                local newList = methodValue(control, first, second)

                if type(newList) == "table" then
                    list = newList
                    rebuild()
                end
            end
            control.GetValue = function()
                return active
            end
            return control
        end

        function Tab:CreateTextbox(textOrConfig, placeholder, callback)
            local textboxConfig = type(textOrConfig) == "table" and textOrConfig or {}
            local text = type(textOrConfig) == "table" and (textboxConfig.Name or textboxConfig.Text or "Input")
                or (textOrConfig or "Input")

            if type(textOrConfig) == "table" then
                placeholder = textboxConfig.PlaceholderText or textboxConfig.Placeholder or "Type here"
                callback = textboxConfig.Callback or callback
            end

            placeholder = placeholder or "Type here"
            local row, rowStroke = createRow(self, "Textbox", 42)
            createRowLabel(row, text, 144)

            local inputFrame = makeElement("Frame", {
                Size = UDim2.fromOffset(122, 26),
                Position = UDim2.new(1, -134, 0.5, -13),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
                Parent = row,
            })
            addCorner(inputFrame, 4)
            local inputStroke = addStroke(inputFrame, currentTheme.CardStroke, 0.55, 1)
            bindTheme(inputFrame, "BackgroundColor3", "Input")
            bindTheme(inputStroke, "Color", "CardStroke")

            local textBox = makeElement("TextBox", {
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.fromOffset(6, 0),
                BackgroundTransparency = 1,
                Text = textboxConfig.CurrentValue or "",
                PlaceholderText = tostring(placeholder),
                TextSize = 10.5,
                Font = Enum.Font.GothamMedium,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 4,
                Parent = inputFrame,
            })
            bindTheme(textBox, "TextColor3", "TextMain")
            bindTheme(textBox, "PlaceholderColor3", "TextDark")

            track(textBox.Focused:Connect(function()
                tween(inputStroke, 0.13, {
                    Color = currentTheme.AccentGrad2,
                    Transparency = 0.18,
                })
                tween(rowStroke, 0.13, {
                    Color = currentTheme.AccentGrad2,
                    Transparency = 0.34,
                })
            end))

            track(textBox.FocusLost:Connect(function(enterPressed)
                tween(inputStroke, 0.13, {
                    Color = currentTheme.CardStroke,
                    Transparency = 0.55,
                })
                runCallback(callback, textBox.Text, enterPressed)
            end))

            local control = {}
            control.SetText = function(first, second)
                textBox.Text = tostring(methodValue(control, first, second) or "")
            end
            control.GetText = function()
                return textBox.Text
            end
            return control
        end

        table.insert(self.Tabs, Tab)

        if not self.ActiveTab then
            Tab:Select()
        end

        return Tab
    end

    local activeNotifications = {}

    local function repositionNotifications()
        local currentViewport = getViewport()
        local y = currentViewport.Y - 12

        for index = #activeNotifications, 1, -1 do
            local notification = activeNotifications[index]

            if notification and notification.Parent then
                y = y - notification.AbsoluteSize.Y
                tween(notification, 0.18, {
                    Position = UDim2.fromOffset(currentViewport.X - notification.AbsoluteSize.X - 12, y),
                }, Enum.EasingStyle.Quint)
                y = y - 8
            end
        end
    end

    function Window:Notify(title, description, duration)
        title = tostring(title or "Notification")
        description = tostring(description or "")
        duration = tonumber(duration) or 4

        local currentViewport = getViewport()
        local width = math.min(310, currentViewport.X - 24)
        local notification = makeElement("Frame", {
            Name = "Notification",
            Size = UDim2.fromOffset(width, 76),
            Position = UDim2.fromOffset(currentViewport.X + 8, currentViewport.Y - 88),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 130,
            Parent = OverlayLayer,
        })
        addCorner(notification, 6)
        local notificationStroke = addStroke(notification, currentTheme.CardStroke, 0.22, 1)
        bindTheme(notification, "BackgroundColor3", "Header")
        bindTheme(notificationStroke, "Color", "CardStroke")

        local accent = makeElement("Frame", {
            Size = UDim2.fromOffset(3, 52),
            Position = UDim2.fromOffset(0, 10),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 131,
            Parent = notification,
        })
        addCorner(accent, 2)
        addAccentGradient(accent, 90)

        local icon = makeElement("Frame", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.fromOffset(12, 13),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 131,
            Parent = notification,
        })
        addCorner(icon, 6)
        bindTheme(icon, "BackgroundColor3", "Card")

        local iconText = makeElement("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = string.upper(title:sub(1, 1)),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 132,
            Parent = icon,
        })
        bindTheme(iconText, "TextColor3", "AccentGrad2")

        local titleLabel = makeElement("TextLabel", {
            Size = UDim2.new(1, -82, 0, 18),
            Position = UDim2.fromOffset(51, 10),
            BackgroundTransparency = 1,
            Text = title,
            TextSize = 11.5,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 131,
            Parent = notification,
        })
        bindTheme(titleLabel, "TextColor3", "TextMain")

        local descriptionLabel = makeElement("TextLabel", {
            Size = UDim2.new(1, -66, 0, 35),
            Position = UDim2.fromOffset(51, 29),
            BackgroundTransparency = 1,
            Text = description,
            TextSize = 9.8,
            Font = Enum.Font.GothamMedium,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 131,
            Parent = notification,
        })
        bindTheme(descriptionLabel, "TextColor3", "TextDark")

        local dismissButton = makeElement("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.new(1, -28, 0, 6),
            BackgroundTransparency = 1,
            Text = "x",
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            ZIndex = 133,
            Parent = notification,
        })
        bindTheme(dismissButton, "TextColor3", "TextDark")

        local progress = makeElement("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, -2),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 132,
            Parent = notification,
        })
        addAccentGradient(progress, 0)

        table.insert(activeNotifications, notification)
        repositionNotifications()

        local dismissed = false

        local function dismiss()
            if dismissed then
                return
            end

            dismissed = true
            local index = table.find(activeNotifications, notification)

            if index then
                table.remove(activeNotifications, index)
            end

            repositionNotifications()
            local exitTween = tween(notification, 0.16, {
                Position = UDim2.fromOffset(getViewport().X + 8, notification.Position.Y.Offset),
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

            if exitTween then
                track(exitTween.Completed:Connect(function()
                    if notification.Parent then
                        notification:Destroy()
                    end
                end))
            elseif notification.Parent then
                notification:Destroy()
            end
        end

        track(dismissButton.MouseButton1Click:Connect(dismiss))
        tween(notification, 0.2, {
            Position = UDim2.fromOffset(currentViewport.X - width - 12, currentViewport.Y - 88),
        }, Enum.EasingStyle.Quint)

        if duration > 0 then
            tween(progress, duration, { Size = UDim2.fromOffset(0, 2) }, Enum.EasingStyle.Linear)
            task.delay(duration, function()
                if notification.Parent then
                    dismiss()
                end
            end)
        end

        return {
            Dismiss = dismiss,
        }
    end

    local function startMainUI()
        unlocked = true
        isAnimating = false
        isVisible = false

        if MobileButton then
            MobileButton.Visible = true
        end

        showWindow()
    end

    local function makeKeyGate()
        local keyFileName = tostring(titleText):lower():gsub("%s+", "_") .. "_key.txt"

        local function validateKey(entered)
            if type(keySettings.Key) == "string" then
                return entered == keySettings.Key
            elseif type(keySettings.Key) == "table" then
                for _, candidate in ipairs(keySettings.Key) do
                    if entered == candidate then
                        return true
                    end
                end
            elseif type(keySettings.Key) == "function" then
                local ok, result = pcall(keySettings.Key, entered)
                return ok and result == true
            end

            return false
        end

        local function loadSavedKey()
            if type(readfile) ~= "function" then
                return nil
            end

            local ok, value = pcall(readfile, keyFileName)
            return ok and tostring(value):gsub("%s+", "") or nil
        end

        local savedKey = loadSavedKey()

        if savedKey and validateKey(savedKey) then
            startMainUI()
            return
        end

        local gate = makeElement("Frame", {
            Name = "KeyGate",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.38,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 200,
            Parent = OverlayLayer,
        })

        local gateWidth = math.min(410, viewport.X - 24)
        local gateHeight = 276
        local card = makeElement("Frame", {
            Name = "Card",
            Size = UDim2.fromOffset(gateWidth, gateHeight),
            Position = UDim2.fromOffset(math.floor((viewport.X - gateWidth) / 2), math.floor((viewport.Y - gateHeight) / 2)),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 201,
            Parent = gate,
        })
        addCorner(card, 7)
        local cardStroke = addStroke(card, currentTheme.CardStroke, 0.18, 1)
        local gateScale = makeElement("UIScale", {
            Scale = 0.96,
            Parent = card,
        })
        bindTheme(card, "BackgroundColor3", "Header")
        bindTheme(cardStroke, "Color", "CardStroke")

        local gateTopbar = makeElement("Frame", {
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 202,
            Parent = card,
        })
        bindTheme(gateTopbar, "BackgroundColor3", "Sidebar")

        local gateIcon = makeElement("Frame", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 203,
            Parent = gateTopbar,
        })
        addCorner(gateIcon, 6)
        addAccentGradient(gateIcon, 35)

        makeElement("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "L",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            ZIndex = 204,
            Parent = gateIcon,
        })

        local keyTitle = makeElement("TextLabel", {
            Size = UDim2.new(1, -92, 0, 18),
            Position = UDim2.fromOffset(54, 11),
            BackgroundTransparency = 1,
            Text = keySettings.Title or "Key verification",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 203,
            Parent = gateTopbar,
        })
        bindTheme(keyTitle, "TextColor3", "TextMain")

        local keySubtitle = makeElement("TextLabel", {
            Size = UDim2.new(1, -92, 0, 15),
            Position = UDim2.fromOffset(54, 29),
            BackgroundTransparency = 1,
            Text = keySettings.Subtitle or subtitleText,
            TextSize = 9.5,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 203,
            Parent = gateTopbar,
        })
        bindTheme(keySubtitle, "TextColor3", "TextDark")

        local gateClose = makeElement("TextButton", {
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, -38, 0, 15),
            BackgroundTransparency = 1,
            Text = "x",
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            ZIndex = 204,
            Parent = gateTopbar,
        })
        bindTheme(gateClose, "TextColor3", "TextDark")

        local note = makeElement("TextLabel", {
            Size = UDim2.new(1, -28, 0, 44),
            Position = UDim2.fromOffset(14, 69),
            BackgroundTransparency = 1,
            Text = keySettings.Note or "Enter your key to continue.",
            TextSize = 10,
            Font = Enum.Font.GothamMedium,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 202,
            Parent = card,
        })
        bindTheme(note, "TextColor3", "TextDark")

        local inputFrame = makeElement("Frame", {
            Size = UDim2.new(1, -28, 0, 38),
            Position = UDim2.fromOffset(14, 119),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 202,
            Parent = card,
        })
        addCorner(inputFrame, 5)
        local inputStroke = addStroke(inputFrame, currentTheme.CardStroke, 0.4, 1)
        bindTheme(inputFrame, "BackgroundColor3", "Input")
        bindTheme(inputStroke, "Color", "CardStroke")

        local keyInput = makeElement("TextBox", {
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = "Enter key",
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 203,
            Parent = inputFrame,
        })
        bindTheme(keyInput, "TextColor3", "TextMain")
        bindTheme(keyInput, "PlaceholderColor3", "TextDark")

        local status = makeElement("TextLabel", {
            Size = UDim2.new(1, -28, 0, 18),
            Position = UDim2.fromOffset(14, 162),
            BackgroundTransparency = 1,
            Text = "",
            TextSize = 9.5,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202,
            Parent = card,
        })
        bindTheme(status, "TextColor3", "TextDark")

        local actions = makeElement("Frame", {
            Size = UDim2.new(1, -28, 0, 38),
            Position = UDim2.fromOffset(14, 190),
            BackgroundTransparency = 1,
            ZIndex = 202,
            Parent = card,
        })

        local hasUrl = type(keySettings.Url) == "string" and keySettings.Url ~= ""
        local verifyButton = makeElement("TextButton", {
            Size = hasUrl and UDim2.new(0.5, -4, 1, 0) or UDim2.fromScale(1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = "Verify",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            ZIndex = 203,
            Parent = actions,
        })
        addCorner(verifyButton, 5)
        addAccentGradient(verifyButton, 12)

        local getKeyButton

        if hasUrl then
            getKeyButton = makeElement("TextButton", {
                Size = UDim2.new(0.5, -4, 1, 0),
                Position = UDim2.new(0.5, 4, 0, 0),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Text = "Get key",
                TextSize = 11,
                Font = Enum.Font.GothamSemibold,
                AutoButtonColor = false,
                ZIndex = 203,
                Parent = actions,
            })
            addCorner(getKeyButton, 5)
            local getKeyStroke = addStroke(getKeyButton, currentTheme.CardStroke, 0.35, 1)
            bindTheme(getKeyButton, "BackgroundColor3", "Card")
            bindTheme(getKeyButton, "TextColor3", "TextMain")
            bindTheme(getKeyStroke, "Color", "CardStroke")
        end

        local gateDragging = false
        local gateDragInput
        local gateStart
        local gateOrigin

        track(gateTopbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                gateDragging = true
                gateStart = input.Position
                gateOrigin = card.Position

                track(input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        gateDragging = false
                    end
                end))
            end
        end))

        track(gateTopbar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                gateDragInput = input
            end
        end))

        track(UserInputService.InputChanged:Connect(function(input)
            if gateDragging and input == gateDragInput then
                local delta = input.Position - gateStart
                local currentViewport = getViewport()
                local x = math.clamp(gateOrigin.X.Offset + delta.X, 6, currentViewport.X - gateWidth - 6)
                local y = math.clamp(gateOrigin.Y.Offset + delta.Y, 6, currentViewport.Y - gateHeight - 6)
                card.Position = UDim2.fromOffset(x, y)
            end
        end))

        local verifying = false

        local function verify()
            if verifying then
                return
            end

            verifying = true
            local entered = keyInput.Text:gsub("%s+", ""):gsub("%c+", "")

            if validateKey(entered) then
                if keySettings.SaveKey and type(writefile) == "function" then
                    pcall(writefile, keyFileName, entered)
                end

                status.Text = "Key accepted"
                status.TextColor3 = currentTheme.Success
                verifyButton.Text = "Accepted"
                local exitTween = tween(card, 0.2, {
                    Position = UDim2.fromOffset(card.Position.X.Offset, card.Position.Y.Offset + 10),
                    BackgroundTransparency = 1,
                }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

                task.delay(exitTween and 0.21 or 0, function()
                    if gate.Parent then
                        gate:Destroy()
                    end

                    startMainUI()
                end)
            else
                status.Text = "That key is not valid"
                status.TextColor3 = currentTheme.Danger
                inputStroke.Color = currentTheme.Danger
                verifyButton.Text = "Try again"
                local origin = card.Position
                tween(card, 0.06, { Position = UDim2.fromOffset(origin.X.Offset - 7, origin.Y.Offset) })
                task.delay(0.07, function()
                    tween(card, 0.1, { Position = origin }, Enum.EasingStyle.Back)
                end)
                task.delay(1.2, function()
                    if verifyButton.Parent then
                        verifyButton.Text = "Verify"
                        inputStroke.Color = currentTheme.CardStroke
                        verifying = false
                    end
                end)
            end
        end

        track(verifyButton.MouseButton1Click:Connect(verify))
        track(keyInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                verify()
            end
        end))
        track(gateClose.MouseButton1Click:Connect(function()
            Window:Destroy()
        end))

        if getKeyButton then
            track(getKeyButton.MouseButton1Click:Connect(function()
                setClipboard(keySettings.Url)
                getKeyButton.Text = "Copied"

                task.delay(1.1, function()
                    if getKeyButton.Parent then
                        getKeyButton.Text = "Get key"
                    end
                end)
            end))
        end

        tween(gateScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Quint)
    end

    if keySettings and keySettings.Key ~= nil then
        makeKeyGate()
    else
        startMainUI()
    end

    Lyra._activeWindow = Window
    return Window
end

function Lyra:SetTheme(theme)
    if self._activeWindow then
        return self._activeWindow:SetTheme(theme)
    end

    self.Theme = normalizeTheme(theme)
    return self.Theme
end

function Lyra:Destroy()
    if self._activeWindow then
        self._activeWindow:Destroy()
        self._activeWindow = nil
        return
    end

    cleanupExisting()
end

return Lyra
