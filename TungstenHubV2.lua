--[[
    Tungsten Hub UI Library (V2 - Fluent & Rayfield Redesign)
    A professional, modern, and draggable dark-themed UI library for Roblox.
    Designed with a Fluent Windows 11 style structure, smooth bouncing transitions, and modular themes.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Safe parent selection for Gui
local Parent = game:GetService("CoreGui")
local success, _ = pcall(function()
    local _ = Parent.Name
end)
if not success then
    Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Cleanup previous instances
if Parent:FindFirstChild("TungstenHub") then
    Parent:FindFirstChild("TungstenHub"):Destroy()
end

local TungstenHub = {}

-- Pre-defined Premium Themes (Fluent inspired)
TungstenHub.Themes = {
    Tungsten = {
        Background = Color3.fromRGB(20, 20, 22),       -- Fluent Dark Slate
        Header = Color3.fromRGB(25, 25, 28),           -- Header/Sidebar Gray
        Sidebar = Color3.fromRGB(25, 25, 28),          -- Sidebar Gray
        Card = Color3.fromRGB(28, 28, 31),             -- Inner card panels
        CardStroke = Color3.fromRGB(42, 42, 46),       -- Fluent card border
        AccentGrad1 = Color3.fromRGB(0, 150, 255),     -- Windows 11 Blue
        AccentGrad2 = Color3.fromRGB(0, 204, 255),     -- Light Blue
        TextMain = Color3.fromRGB(245, 245, 250),      -- White
        TextDark = Color3.fromRGB(160, 160, 165),      -- Muted Gray
    },
    Nebula = {
        Background = Color3.fromRGB(14, 11, 22),
        Header = Color3.fromRGB(18, 14, 28),
        Sidebar = Color3.fromRGB(18, 14, 28),
        Card = Color3.fromRGB(22, 18, 34),
        CardStroke = Color3.fromRGB(38, 30, 60),
        AccentGrad1 = Color3.fromRGB(138, 43, 226),    -- Violet
        AccentGrad2 = Color3.fromRGB(218, 112, 214),   -- Orchid
        TextMain = Color3.fromRGB(245, 240, 255),
        TextDark = Color3.fromRGB(150, 140, 170),
    },
    BloodMoon = {
        Background = Color3.fromRGB(20, 12, 12),
        Header = Color3.fromRGB(26, 16, 16),
        Sidebar = Color3.fromRGB(26, 16, 16),
        Card = Color3.fromRGB(30, 20, 20),
        CardStroke = Color3.fromRGB(50, 32, 32),
        AccentGrad1 = Color3.fromRGB(220, 20, 60),     -- Crimson
        AccentGrad2 = Color3.fromRGB(255, 69, 0),      -- Orange-Red
        TextMain = Color3.fromRGB(255, 240, 240),
        TextDark = Color3.fromRGB(180, 150, 150),
    },
    Emerald = {
        Background = Color3.fromRGB(10, 18, 14),
        Header = Color3.fromRGB(14, 24, 19),
        Sidebar = Color3.fromRGB(14, 24, 19),
        Card = Color3.fromRGB(18, 28, 23),
        CardStroke = Color3.fromRGB(30, 48, 39),
        AccentGrad1 = Color3.fromRGB(46, 204, 113),    -- Emerald
        AccentGrad2 = Color3.fromRGB(26, 188, 156),    -- Teal
        TextMain = Color3.fromRGB(240, 250, 245),
        TextDark = Color3.fromRGB(140, 170, 155),
    },
    Midnight = {
        Background = Color3.fromRGB(10, 13, 20),
        Header = Color3.fromRGB(14, 17, 26),
        Sidebar = Color3.fromRGB(14, 17, 26),
        Card = Color3.fromRGB(18, 21, 31),
        CardStroke = Color3.fromRGB(30, 36, 52),
        AccentGrad1 = Color3.fromRGB(33, 97, 140),     -- Navy
        AccentGrad2 = Color3.fromRGB(52, 152, 219),    -- Sky Blue
        TextMain = Color3.fromRGB(240, 245, 255),
        TextDark = Color3.fromRGB(140, 150, 170),
    }
}

TungstenHub.Theme = TungstenHub.Themes.Tungsten
TungstenHub.ToggleKey = Enum.KeyCode.RightShift

-- Utility function for creating UI elements smoothly
local function makeElement(className, properties, children)
    local element = Instance.new(className)
    for k, v in pairs(properties or {}) do
        element[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = element
    end
    return element
end

-- Smooth UI dragging function
local function makeDraggable(dragFrame, parentFrame)
    local dragging = false
    local dragInput
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        local endPos = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
        local tween = TweenService:Create(
            parentFrame, 
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
            {Position = endPos}
        )
        tween:Play()
    end

    dragFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = parentFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- Top-level Window builder supporting dynamic configs and Key System
function TungstenHub:CreateWindow(titleTextOrConfig, subtitleText)
    local titleText, subText, keySettings
    if type(titleTextOrConfig) == "table" then
        titleText = titleTextOrConfig.Name or "Tungsten Hub"
        subText = titleTextOrConfig.Subtitle or "Roblox Edition"
        keySettings = titleTextOrConfig.KeySettings
    else
        titleText = titleTextOrConfig or "Tungsten Hub"
        subText = subtitleText or "Roblox Edition"
    end

    -- Registry of instances to update dynamically on theme change
    local themeObjects = {
        Backgrounds = {},
        Headers = {},
        Sidebars = {},
        Cards = {},
        Strokes = {},
        MainText = {},
        DarkText = {},
        Gradients = {},
        Updaters = {},
    }

    local ScreenGui = makeElement("ScreenGui", {
        Name = "TungstenHub",
        Parent = Parent,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    -- Main Container (handles non-clipped shadow drawing)
    local MainContainer = makeElement("Frame", {
        Name = "MainContainer",
        Size = UDim2.new(0, 560, 0, 390), -- Fluent-spec size ratio
        Position = UDim2.new(0.5, -280, 0.5, -195),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = ScreenGui
    })

    -- Large Frosted Drop Shadow Decal
    local Shadow = makeElement("ImageLabel", {
        Name = "Shadow",
        Size = UDim2.new(1, 40, 1, 40),
        Position = UDim2.new(0, -20, 0, -20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 20, 20),
        ZIndex = 0,
        Parent = MainContainer
    })

    -- Main Frame (Windows 11 rounded layout)
    local MainFrame = makeElement("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = TungstenHub.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = MainContainer
    })
    table.insert(themeObjects.Backgrounds, MainFrame)

    local MainCorner = makeElement("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = MainFrame
    })

    -- Thin border outline (Fluent card stroke style)
    local MainStroke = makeElement("UIStroke", {
        Color = TungstenHub.Theme.CardStroke,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = MainFrame
    })
    table.insert(themeObjects.Strokes, MainStroke)

    -- Sidebar (Navigation Panel on the Left)
    local Sidebar = makeElement("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 160, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = TungstenHub.Theme.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = MainFrame
    })
    table.insert(themeObjects.Sidebars, Sidebar)

    local SidebarCorner = makeElement("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = Sidebar
    })

    -- Clean divider between Sidebar and Content
    local Separator = makeElement("Frame", {
        Name = "Separator",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = TungstenHub.Theme.CardStroke,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = Sidebar
    })
    table.insert(themeObjects.Strokes, Separator)

    -- App Brand/Title block in Sidebar
    local BrandContainer = makeElement("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, -10, 0, 50),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Parent = Sidebar
    })

    local TitleLabel = makeElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = TungstenHub.Theme.TextMain,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = BrandContainer
    })
    table.insert(themeObjects.MainText, TitleLabel)

    local SubtitleLabel = makeElement("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 5, 0, 22),
        BackgroundTransparency = 1,
        Text = subText,
        TextColor3 = TungstenHub.Theme.TextDark,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = BrandContainer
    })
    table.insert(themeObjects.DarkText, SubtitleLabel)

    -- Scrolling Frame for Tab List
    local SidebarScroll = makeElement("ScrollingFrame", {
        Name = "TabsList",
        Size = UDim2.new(1, -10, 1, -75),
        Position = UDim2.new(0, 5, 0, 65),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = Sidebar
    })

    local SidebarScrollLayout = makeElement("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = SidebarScroll
    })

    SidebarScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, SidebarScrollLayout.AbsoluteContentSize.Y)
    end)

    -- Header Panel (Thin drag bar next to sidebar)
    local DragBar = makeElement("Frame", {
        Name = "DragBar",
        Size = UDim2.new(1, -160, 0, 35),
        Position = UDim2.new(0, 160, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = MainFrame
    })

    -- Window Controls Container (Minimize & Close buttons)
    local WindowControls = makeElement("Frame", {
        Name = "Controls",
        Size = UDim2.new(0, 65, 1, 0),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Parent = DragBar
    })

    -- Minimize Button
    local MinBtn = makeElement("TextButton", {
        Name = "MinBtn",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(0, 5, 0.5, -12),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = TungstenHub.Theme.TextDark,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        Parent = WindowControls
    })
    table.insert(themeObjects.DarkText, MinBtn)

    -- Close Button
    local CloseBtn = makeElement("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(0, 35, 0.5, -12),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = TungstenHub.Theme.TextDark,
        TextSize = 18,
        Font = Enum.Font.GothamMedium,
        Parent = WindowControls
    })
    table.insert(themeObjects.DarkText, CloseBtn)

    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
    end)
    -- Animation state tracking
    local isAnimating = false
    local lastPosition = MainContainer.Position

    local function animateCollapse(callback)
        if isAnimating then return end
        isAnimating = true
        lastPosition = MainContainer.Position
        
        local targetPos = UDim2.new(
            lastPosition.X.Scale,
            lastPosition.X.Offset,
            lastPosition.Y.Scale,
            lastPosition.Y.Offset + 195
        )
        
        local tween = TweenService:Create(MainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 560, 0, 0),
            Position = targetPos
        })
        
        tween:Play()
        tween.Completed:Connect(function()
            MainContainer.Visible = false
            isAnimating = false
            if callback then callback() end
        end)
    end

    local function animateExpand()
        if isAnimating then return end
        isAnimating = true
        
        local targetPos = lastPosition
        local startPos = UDim2.new(
            targetPos.X.Scale,
            targetPos.X.Offset,
            targetPos.Y.Scale,
            targetPos.Y.Offset + 195
        )
        
        MainContainer.Size = UDim2.new(0, 560, 0, 0)
        MainContainer.Position = startPos
        MainContainer.Visible = true
        
        local tween = TweenService:Create(MainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 390),
            Position = targetPos
        })
        
        tween:Play()
        tween.Completed:Connect(function()
            isAnimating = false
        end)
    end

    CloseBtn.MouseButton1Click:Connect(function()
        animateCollapse(function()
            ScreenGui:Destroy()
        end)
    end)

    makeDraggable(DragBar, MainContainer)

    -- Content Container (Right Panel)
    local PageContainer = makeElement("Frame", {
        Name = "PageContainer",
        Size = UDim2.new(1, -170, 1, -45),
        Position = UDim2.new(0, 170, 0, 45),
        BackgroundTransparency = 1,
        Parent = MainFrame
    })

    -- Entrance Animation Definition
    MainContainer.Size = UDim2.new(0, 560, 0, 0)
    MainContainer.Position = UDim2.new(0.5, -280, 0.5, 0)
    local fadeIn = TweenService:Create(MainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 560, 0, 390),
        Position = UDim2.new(0.5, -280, 0.5, -195),
    })

    -- Helper functions for local Key caching
    local keyFileName = titleText:lower():gsub("%s+", "_") .. "_key.txt"

    local function saveKey(keyVal)
        if writefile then
            pcall(function()
                writefile(keyFileName, keyVal)
            end)
        end
    end

    local function loadSavedKey()
        if readfile then
            local successLoad, content = pcall(function()
                return readfile(keyFileName)
            end)
            if successLoad then
                return content:gsub("%s+", "")
            end
        end
        return nil
    end

    local function setClipboard(text)
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        end
    end

    local function startMainUI()
        MainContainer.Visible = true
        fadeIn:Play()
    end

    -- Run Key System if enabled
    if keySettings and keySettings.Key then
        local savedKey = loadSavedKey()
        
        local function validateKey(entered)
            if type(keySettings.Key) == "string" then
                return entered == keySettings.Key
            elseif type(keySettings.Key) == "table" then
                for _, k in ipairs(keySettings.Key) do
                    if entered == k then return true end
                end
            elseif type(keySettings.Key) == "function" then
                local successCheck, checkResult = pcall(keySettings.Key, entered)
                return successCheck and checkResult
            end
            return false
        end

        if savedKey and validateKey(savedKey) then
            startMainUI()
        else
            -- Hide main UI window during key verification
            MainContainer.Visible = false
            
            -- Key Verification Window Container
            local KeyContainer = makeElement("Frame", {
                Name = "KeyContainer",
                Size = UDim2.new(0, 320, 0, 210),
                Position = UDim2.new(0.5, -160, 0.5, -105),
                BackgroundTransparency = 1,
                Parent = ScreenGui
            })
            
            local KeyShadow = makeElement("ImageLabel", {
                Name = "Shadow",
                Size = UDim2.new(1, 40, 1, 40),
                Position = UDim2.new(0, -20, 0, -20),
                BackgroundTransparency = 1,
                Image = "rbxassetid://6014261993",
                ImageColor3 = Color3.fromRGB(0, 0, 0),
                ImageTransparency = 0.5,
                ScaleType = Enum.ScaleType.Slice,
                SliceCenter = Rect.new(10, 10, 20, 20),
                ZIndex = 0,
                Parent = KeyContainer
            })
            
            local KeyFrame = makeElement("Frame", {
                Name = "KeyFrame",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = TungstenHub.Theme.Background,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                ZIndex = 1,
                Parent = KeyContainer
            })
            
            local KeyCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
                Parent = KeyFrame
            })
            
            local KeyStroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = KeyFrame
            })
            
            makeDraggable(KeyFrame, KeyContainer)
            
            -- Header title
            local KeyHeader = makeElement("Frame", {
                Size = UDim2.new(1, 0, 0, 35),
                BackgroundTransparency = 1,
                Parent = KeyFrame
            })
            
            local KeyTitle = makeElement("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1,
                Text = keySettings.Title or "Key Verification",
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 13.5,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = KeyHeader
            })
            
            local KeyClose = makeElement("TextButton", {
                Size = UDim2.new(0, 25, 0, 25),
                Position = UDim2.new(1, -35, 0.5, -12.5),
                BackgroundTransparency = 1,
                Text = "×",
                TextColor3 = TungstenHub.Theme.TextDark,
                TextSize = 18,
                Font = Enum.Font.GothamMedium,
                Parent = KeyHeader
            })
            
            KeyClose.MouseButton1Click:Connect(function()
                ScreenGui:Destroy()
            end)
            
            -- Developer Custom Note
            local KeyNote = makeElement("TextLabel", {
                Size = UDim2.new(1, -30, 0, 35),
                Position = UDim2.new(0, 15, 0, 42),
                BackgroundTransparency = 1,
                Text = keySettings.Note or "Please enter key to unlock features.",
                TextColor3 = TungstenHub.Theme.TextDark,
                TextSize = 11,
                Font = Enum.Font.GothamMedium,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = KeyFrame
            })
            
            -- TextBox Outline
            local BoxFrame = makeElement("Frame", {
                Size = UDim2.new(1, -30, 0, 34),
                Position = UDim2.new(0, 15, 0, 85),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = KeyFrame
            })
            
            local BoxCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = BoxFrame
            })
            
            local BoxStroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = BoxFrame
            })
            
            local KeyInput = makeElement("TextBox", {
                Size = UDim2.new(1, -20, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = "",
                PlaceholderText = "Enter key here...",
                PlaceholderColor3 = TungstenHub.Theme.TextDark,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                ClearTextOnFocus = false,
                Parent = BoxFrame
            })
            
            KeyInput.Focused:Connect(function()
                TweenService:Create(BoxStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)
            KeyInput.FocusLost:Connect(function()
                TweenService:Create(BoxStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)
            
            -- Actions (Verify / Get Key Link)
            local ActionHolder = makeElement("Frame", {
                Size = UDim2.new(1, -30, 0, 34),
                Position = UDim2.new(0, 15, 0, 135),
                BackgroundTransparency = 1,
                Parent = KeyFrame
            })
            
            local ActionLayout = makeElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
                Parent = ActionHolder
            })
            
            -- Submit button (accent background)
            local VerifyBtnFrame = makeElement("Frame", {
                Size = UDim2.new(0.5, -4, 1, 0),
                BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
                BorderSizePixel = 0,
                Parent = ActionHolder
            })
            
            local VerifyCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = VerifyBtnFrame
            })
            
            local VerifyBtn = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "Verify Key",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                Parent = VerifyBtnFrame
            })
            
            -- Copy Key Link button (card background)
            local GetBtnFrame = makeElement("Frame", {
                Size = UDim2.new(0.5, -4, 1, 0),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = ActionHolder
            })
            
            local GetCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = GetBtnFrame
            })
            
            local GetStroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = GetBtnFrame
            })
            
            local GetBtn = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "Get Key Link",
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                Parent = GetBtnFrame
            })
            
            GetBtn.MouseEnter:Connect(function()
                TweenService:Create(GetStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)
            GetBtn.MouseLeave:Connect(function()
                TweenService:Create(GetStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)
            
            GetBtn.MouseButton1Click:Connect(function()
                if keySettings.Url then
                    setClipboard(keySettings.Url)
                    GetBtn.Text = "Link Copied!"
                    task.wait(1.5)
                    GetBtn.Text = "Get Key Link"
                end
            end)
            
            VerifyBtn.MouseButton1Click:Connect(function()
                local entered = KeyInput.Text:gsub("%s+", ""):gsub("%c+", "")
                if validateKey(entered) then
                    if keySettings.SaveKey then
                        saveKey(entered)
                    end
                    VerifyBtn.Text = "Success!"
                    
                    local slideOut = TweenService:Create(KeyContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Size = UDim2.new(0, 320, 0, 0),
                        Position = UDim2.new(0.5, -160, 0.5, 0),
                    })
                    slideOut:Play()
                    slideOut.Completed:Connect(function()
                        KeyContainer:Destroy()
                        startMainUI()
                    end)
                else
                    VerifyBtn.Text = "Invalid Key!"
                    TweenService:Create(BoxStroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(255, 75, 75)}):Play()
                    task.wait(1.5)
                    VerifyBtn.Text = "Verify Key"
                    TweenService:Create(BoxStroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
                end
            end)
        end
    else
        startMainUI()
    end

    local isVisible = true
    local function toggleUI()
        if not MainContainer or not MainContainer.Parent or isAnimating then return end
        if isVisible then
            animateCollapse(function()
                isVisible = false
            end)
        else
            animateExpand()
            isVisible = true
        end
    end

    -- Minimize connection
    MinBtn.MouseButton1Click:Connect(toggleUI)

    -- Toggle with Key
    local toggleKey = TungstenHub.ToggleKey or Enum.KeyCode.RightShift
    local toggleConnection
    toggleConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then
            toggleUI()
        end
    end)

    ScreenGui.Destroying:Connect(function()
        if toggleConnection then
            toggleConnection:Disconnect()
            toggleConnection = nil
        end
    end)

    -- Mobile Floating Toggle Button
    if UserInputService.TouchEnabled then
        local MobileButton = makeElement("ImageButton", {
            Name = "MobileToggle",
            Size = UDim2.new(0, 45, 0, 45),
            Position = UDim2.new(0.05, 0, 0.15, 0),
            BackgroundColor3 = TungstenHub.Theme.Header,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = ScreenGui
        })
        table.insert(themeObjects.Headers, MobileButton)
        
        local ButtonCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = MobileButton
        })
        
        local ButtonStroke = makeElement("UIStroke", {
            Color = TungstenHub.Theme.AccentGrad1,
            Thickness = 1,
            Parent = MobileButton
        })
        table.insert(themeObjects.Strokes, ButtonStroke)
        
        local ButtonLabel = makeElement("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "T",
            TextColor3 = TungstenHub.Theme.TextMain,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            Parent = MobileButton
        })
        table.insert(themeObjects.MainText, ButtonLabel)
        
        MobileButton.MouseButton1Click:Connect(toggleUI)
        
        local dragStart, startPos
        local dragging = false
        
        MobileButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = MobileButton.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - dragStart
                MobileButton.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X, 
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Window Object Definition
    local Window = {
        Tabs = {},
        ActiveTab = nil,
        ToggleConnection = toggleConnection,
    }

    -- Set dynamic theme updating
    function Window:SetTheme(themeTable)
        TungstenHub.Theme = themeTable
        
        for _, bg in ipairs(themeObjects.Backgrounds) do bg.BackgroundColor3 = themeTable.Background end
        for _, hd in ipairs(themeObjects.Headers) do hd.BackgroundColor3 = themeTable.Header end
        for _, sb in ipairs(themeObjects.Sidebars) do sb.BackgroundColor3 = themeTable.Sidebar end
        for _, cd in ipairs(themeObjects.Cards) do cd.BackgroundColor3 = themeTable.Card end
        for _, str in ipairs(themeObjects.Strokes) do str.Color = themeTable.CardStroke end
        for _, txt in ipairs(themeObjects.MainText) do txt.TextColor3 = themeTable.TextMain end
        for _, txt in ipairs(themeObjects.DarkText) do txt.TextColor3 = themeTable.TextDark end
        for _, grad in ipairs(themeObjects.Gradients) do
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, themeTable.AccentGrad1),
                ColorSequenceKeypoint.new(1, themeTable.AccentGrad2)
            })
        end
        for _, updateFn in ipairs(themeObjects.Updaters) do
            pcall(updateFn, themeTable)
        end
    end

    function Window:SetToggleKey(newKey)
        if typeof(newKey) == "EnumItem" and newKey.EnumType == Enum.KeyCode then
            toggleKey = newKey
        end
    end

    function Window:CreateTab(tabName)
        tabName = tabName or "Tab"
        
        -- Fluent Sidebar Button
        local TabButton = makeElement("TextButton", {
            Name = tabName .. "_Btn",
            Size = UDim2.new(1, -10, 0, 32),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = SidebarScroll
        })

        local TabBtnCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 5),
            Parent = TabButton
        })

        -- Rayfield-style Left Accent Bar Indicator
        local ActiveIndicator = makeElement("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 3.5, 0.5, 0),
            Position = UDim2.new(0, 0, 0.25, 0),
            BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton
        })
        table.insert(themeObjects.Backgrounds, ActiveIndicator) -- Uses background color logic
        
        local ActiveIndicatorGrad = makeElement("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, TungstenHub.Theme.AccentGrad1),
                ColorSequenceKeypoint.new(1, TungstenHub.Theme.AccentGrad2)
            }),
            Parent = ActiveIndicator
        })
        table.insert(themeObjects.Gradients, ActiveIndicatorGrad)

        local IndicatorCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 2),
            Parent = ActiveIndicator
        })

        local TabLabel = makeElement("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = tabName,
            TextColor3 = TungstenHub.Theme.TextDark,
            TextSize = 12.5,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = TabButton
        })
        table.insert(themeObjects.DarkText, TabLabel)

        -- Tab Content Scrolling Page
        local TabPage = makeElement("ScrollingFrame", {
            Name = tabName .. "_Page",
            Size = UDim2.new(1, -10, 1, -10),
            Position = UDim2.new(0, 5, 0, 5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = TungstenHub.Theme.CardStroke,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Parent = PageContainer
        })

        local TabPageLayout = makeElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 5),
            Parent = TabPage
        })

        TabPageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, TabPageLayout.AbsoluteContentSize.Y)
        end)

        local Tab = {
            Button = TabButton,
            Page = TabPage
        }

        local function selectTab()
            if Window.ActiveTab == Tab then return end

            if Window.ActiveTab then
                TweenService:Create(Window.ActiveTab.Button.Label, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
                TweenService:Create(Window.ActiveTab.Button.Indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                TweenService:Create(Window.ActiveTab.Button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                Window.ActiveTab.Page.Visible = false
            end

            Window.ActiveTab = Tab
            TweenService:Create(TabLabel, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextMain}):Play()
            TweenService:Create(ActiveIndicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
            
            -- Soft card fill for active tab button
            TweenService:Create(TabButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.94}):Play()
            TabPage.Visible = true
        end

        TabButton.MouseButton1Click:Connect(selectTab)

        TabButton.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                TweenService:Create(TabLabel, TweenInfo.new(0.15), {TextColor3 = TungstenHub.Theme.TextMain}):Play()
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.97}):Play()
            end
        end)

        TabButton.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                TweenService:Create(TabLabel, TweenInfo.new(0.15), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
            end
        end)

        if not Window.ActiveTab then
            selectTab()
        end

        -- =====================================================================
        -- COMPONENT CREATORS (Fluent Design Specs)
        -- =====================================================================

        function Tab:CreateLabel(textString)
            local LabelFrame = makeElement("Frame", {
                Name = "LabelFrame",
                Size = UDim2.new(1, -6, 0, 22),
                BackgroundTransparency = 1,
                Parent = TabPage
            })

            local TextLabel = makeElement("TextLabel", {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = textString,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = LabelFrame
            })
            table.insert(themeObjects.MainText, TextLabel)

            return {
                UpdateText = function(newText)
                    TextLabel.Text = newText
                end
            }
        end

        function Tab:CreateButton(btnText, callback)
            callback = callback or function() end

            local BtnFrame = makeElement("Frame", {
                Name = "ButtonFrame",
                Size = UDim2.new(1, -6, 0, 34),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, BtnFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = BtnFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = BtnFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local Button = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = btnText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
                Font = Enum.Font.GothamMedium,
                AutoButtonColor = false,
                Parent = BtnFrame
            })
            table.insert(themeObjects.MainText, Button)

            Button.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
                TweenService:Create(BtnFrame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(34, 34, 38)}):Play()
            end)

            Button.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
                TweenService:Create(BtnFrame, TweenInfo.new(0.15), {BackgroundColor3 = TungstenHub.Theme.Card}):Play()
            end)

            Button.MouseButton1Down:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.05), {Size = UDim2.new(1, -12, 0, 32), Position = UDim2.new(0, 3, 0, 1)}):Play()
            end)

            Button.MouseButton1Up:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.1), {Size = UDim2.new(1, -6, 0, 34), Position = UDim2.new(0, 0, 0, 0)}):Play()
                task.spawn(callback)
            end)

            return {
                UpdateButtonText = function(newText)
                    Button.Text = newText
                end
            }
        end

        function Tab:CreateToggle(toggleText, default, callback)
            default = default or false
            callback = callback or function() end
            local toggled = default

            local ToggleFrame = makeElement("Frame", {
                Name = "ToggleFrame",
                Size = UDim2.new(1, -6, 0, 36),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, ToggleFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = ToggleFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = ToggleFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = toggleText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = ToggleFrame
            })
            table.insert(themeObjects.MainText, Label)

            -- Fluent Pill Switch Frame
            local Switch = makeElement("Frame", {
                Name = "Switch",
                Size = UDim2.new(0, 34, 0, 18),
                Position = UDim2.new(1, -46, 0.5, -9),
                BackgroundColor3 = Color3.fromRGB(40, 40, 44),
                BorderSizePixel = 0,
                Parent = ToggleFrame
            })

            local SwitchCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Switch
            })

            local SwitchStroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = Switch
            })

            -- Circular Switch Knob
            local Circle = makeElement("Frame", {
                Name = "Circle",
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, 2, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(180, 180, 185),
                BorderSizePixel = 0,
                Parent = Switch
            })

            local CircleCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Circle
            })

            local ToggleBtn = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = ToggleFrame
            })

            local function updateToggle(state)
                toggled = state
                local targetPos = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
                local targetColor = state and TungstenHub.Theme.AccentGrad1 or Color3.fromRGB(40, 40, 44)
                local targetCircleColor = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 185)

                -- Bouncy knob slide
                local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                TweenService:Create(Circle, tweenInfo, {Position = targetPos, BackgroundColor3 = targetCircleColor}):Play()
                TweenService:Create(Switch, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
                
                task.spawn(callback, toggled)
            end

            ToggleBtn.MouseButton1Click:Connect(function()
                updateToggle(not toggled)
            end)

            ToggleBtn.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ToggleBtn.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            updateToggle(default)

            table.insert(themeObjects.Updaters, function(newTheme)
                local targetColor = toggled and newTheme.AccentGrad1 or Color3.fromRGB(40, 40, 44)
                Switch.BackgroundColor3 = targetColor
                SwitchStroke.Color = newTheme.CardStroke
            end)

            return {
                SetToggle = function(state)
                    updateToggle(state)
                end
            }
        end

        function Tab:CreateSlider(sliderText, min, max, default, callback)
            min = min or 0
            max = max or 100
            default = default or min
            callback = callback or function() end

            local value = default

            local SliderFrame = makeElement("Frame", {
                Name = "SliderFrame",
                Size = UDim2.new(1, -6, 0, 44),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, SliderFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = SliderFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = SliderFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -100, 0, 22),
                Position = UDim2.new(0, 12, 0, 2),
                BackgroundTransparency = 1,
                Text = sliderText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = SliderFrame
            })
            table.insert(themeObjects.MainText, Label)

            local ValueLabel = makeElement("TextLabel", {
                Size = UDim2.new(0, 80, 0, 22),
                Position = UDim2.new(1, -92, 0, 2),
                BackgroundTransparency = 1,
                Text = tostring(default),
                TextColor3 = TungstenHub.Theme.TextDark,
                TextSize = 11.5,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = SliderFrame
            })
            table.insert(themeObjects.DarkText, ValueLabel)

            -- Horizontal line track (Fluent Slider Spec)
            local Track = makeElement("Frame", {
                Name = "Track",
                Size = UDim2.new(1, -24, 0, 4),
                Position = UDim2.new(0, 12, 1, -12),
                BackgroundColor3 = Color3.fromRGB(34, 34, 38),
                BorderSizePixel = 0,
                Parent = SliderFrame
            })

            local TrackCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Track
            })

            -- Progress Bar
            local Progress = makeElement("Frame", {
                Name = "Progress",
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
                BorderSizePixel = 0,
                Parent = Track
            })
            table.insert(themeObjects.Backgrounds, Progress)

            local ProgressCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Progress
            })

            -- Handle knob
            local Handle = makeElement("Frame", {
                Name = "Handle",
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(0, -5, 0.5, -5),
                BackgroundColor3 = Color3.fromRGB(240, 240, 245),
                BorderSizePixel = 0,
                Parent = Progress
            })

            local HandleCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Handle
            })

            local SlidingTrigger = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = SliderFrame
            })

            local isDragging = false
            
            local function moveSlider(input)
                local trackSize = Track.AbsoluteSize.X
                if trackSize == 0 then return end
                local relativeMouseX = math.clamp(input.Position.X - Track.AbsolutePosition.X, 0, trackSize)
                local percent = relativeMouseX / trackSize
                
                local rawValue = min + ((max - min) * percent)
                local roundedValue = math.floor(rawValue + 0.5)
                
                value = roundedValue
                ValueLabel.Text = tostring(value)
                
                TweenService:Create(Progress, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(percent, 0, 1, 0)
                }):Play()
                
                task.spawn(callback, value)
            end

            SlidingTrigger.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = true
                    moveSlider(input)
                    TweenService:Create(Handle, TweenInfo.new(0.15), {Size = UDim2.new(0, 13, 0, 13), Position = UDim2.new(0, -6.5, 0.5, -6.5)}):Play()
                end
            end)

            SlidingTrigger.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                    TweenService:Create(Handle, TweenInfo.new(0.15), {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, -5, 0.5, -5)}):Play()
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    moveSlider(input)
                end
            end)

            SlidingTrigger.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            SlidingTrigger.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            local initialPercent = math.clamp((default - min) / (max - min), 0, 1)
            Progress.Size = UDim2.new(initialPercent, 0, 1, 0)

            table.insert(themeObjects.Updaters, function(newTheme)
                Progress.BackgroundColor3 = newTheme.AccentGrad1
            end)

            return {
                SetValue = function(newValue)
                    local clamped = math.clamp(newValue, min, max)
                    value = clamped
                    ValueLabel.Text = tostring(clamped)
                    local pct = (clamped - min) / (max - min)
                    TweenService:Create(Progress, TweenInfo.new(0.15), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
                    task.spawn(callback, value)
                end
            }
        end

        function Tab:CreateDropdown(dropdownText, list, default, callback)
            list = list or {}
            default = default or list[1] or ""
            callback = callback or function() end
            
            local activeOption = default
            local dropdownOpen = false

            local DropdownFrame = makeElement("Frame", {
                Name = "DropdownFrame",
                Size = UDim2.new(1, -6, 0, 36),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, DropdownFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = DropdownFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = DropdownFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local TopArea = makeElement("Frame", {
                Name = "TopArea",
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Parent = DropdownFrame
            })

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -120, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = dropdownText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = TopArea
            })
            table.insert(themeObjects.MainText, Label)

            -- Selected label highlighted with Accent color
            local SelectionLabel = makeElement("TextLabel", {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, -135, 0, 0),
                BackgroundTransparency = 1,
                Text = activeOption,
                TextColor3 = TungstenHub.Theme.AccentGrad1,
                TextSize = 11.5,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = TopArea
            })
            table.insert(themeObjects.DarkText, SelectionLabel)

            local Arrow = makeElement("TextLabel", {
                Size = UDim2.new(0, 30, 1, 0),
                Position = UDim2.new(1, -35, 0, 0),
                BackgroundTransparency = 1,
                Text = "▼",
                TextColor3 = TungstenHub.Theme.TextDark,
                TextSize = 10,
                Font = Enum.Font.GothamMedium,
                Parent = TopArea
            })
            table.insert(themeObjects.DarkText, Arrow)

            local ClickButton = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = TopArea
            })

            -- Options menu (expands downwards)
            local OptionsHolder = makeElement("Frame", {
                Name = "OptionsHolder",
                Size = UDim2.new(1, -20, 0, 0),
                Position = UDim2.new(0, 10, 0, 36),
                BackgroundTransparency = 1,
                Parent = DropdownFrame
            })

            local HolderLayout = makeElement("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 3),
                Parent = OptionsHolder
            })

            local optionButtons = {}

            local function toggleDropdown(state)
                dropdownOpen = state
                local targetHeight = state and (36 + HolderLayout.AbsoluteContentSize.Y + 8) or 36
                local arrowChar = state and "▲" or "▼"
                
                Arrow.Text = arrowChar
                TweenService:Create(DropdownFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, -6, 0, targetHeight)
                }):Play()
            end

            ClickButton.MouseButton1Click:Connect(function()
                toggleDropdown(not dropdownOpen)
            end)

            local function refreshList()
                for _, btn in ipairs(optionButtons) do
                    btn:Destroy()
                end
                optionButtons = {}

                for index, optionText in ipairs(list) do
                    local isSelected = (optionText == activeOption)
                    
                    local OptButton = makeElement("TextButton", {
                        Name = optionText .. "_Opt",
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = Color3.fromRGB(32, 32, 36),
                        BorderSizePixel = 0,
                        Text = optionText,
                        TextColor3 = isSelected and TungstenHub.Theme.TextMain or TungstenHub.Theme.TextDark,
                        TextSize = 11.5,
                        Font = isSelected and Enum.Font.GothamBold or Enum.Font.GothamMedium,
                        AutoButtonColor = false,
                        Parent = OptionsHolder
                    })

                    local OptCorner = makeElement("UICorner", {
                        CornerRadius = UDim.new(0, 4),
                        Parent = OptButton
                    })

                    local OptStroke = makeElement("UIStroke", {
                        Color = isSelected and TungstenHub.Theme.AccentGrad1 or TungstenHub.Theme.CardStroke,
                        Thickness = 1,
                        Parent = OptButton
                    })

                    OptButton.MouseEnter:Connect(function()
                        TweenService:Create(OptButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 38, 44)}):Play()
                    end)
                    OptButton.MouseLeave:Connect(function()
                        TweenService:Create(OptButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 32, 36)}):Play()
                    end)

                    OptButton.MouseButton1Click:Connect(function()
                        activeOption = optionText
                        SelectionLabel.Text = optionText
                        toggleDropdown(false)
                        refreshList()
                        task.spawn(callback, optionText)
                    end)

                    table.insert(optionButtons, OptButton)
                end
            end

            ClickButton.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ClickButton.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            refreshList()

            table.insert(themeObjects.Updaters, function(newTheme)
                SelectionLabel.TextColor3 = newTheme.AccentGrad1
                refreshList()
            end)

            return {
                Select = function(newSelection)
                    activeOption = newSelection
                    SelectionLabel.Text = newSelection
                    refreshList()
                    task.spawn(callback, newSelection)
                end,
                Refresh = function(newList)
                    list = newList
                    refreshList()
                    if dropdownOpen then
                        toggleDropdown(true)
                    end
                end
            }
        end

        function Tab:CreateTextbox(boxText, placeholderText, callback)
            placeholderText = placeholderText or "Type here..."
            callback = callback or function() end

            local BoxFrame = makeElement("Frame", {
                Name = "BoxFrame",
                Size = UDim2.new(1, -6, 0, 36),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, BoxFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = BoxFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = BoxFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -160, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = boxText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = BoxFrame
            })
            table.insert(themeObjects.MainText, Label)

            -- Textbox border turns accent color on click
            local InputContainer = makeElement("Frame", {
                Name = "InputContainer",
                Size = UDim2.new(0, 120, 0, 24),
                Position = UDim2.new(1, -132, 0.5, -12),
                BackgroundColor3 = Color3.fromRGB(34, 34, 38),
                BorderSizePixel = 0,
                Parent = BoxFrame
            })

            local InputCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 4),
                Parent = InputContainer
            })

            local InputStroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = InputContainer
            })
            table.insert(themeObjects.Strokes, InputStroke)

            local TextBox = makeElement("TextBox", {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = "",
                PlaceholderText = placeholderText,
                PlaceholderColor3 = TungstenHub.Theme.TextDark,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 11.5,
                Font = Enum.Font.GothamMedium,
                ClipsDescendants = true,
                ClearTextOnFocus = false,
                Parent = InputContainer
            })
            table.insert(themeObjects.MainText, TextBox)

            TextBox.Focused:Connect(function()
                TweenService:Create(InputStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            TextBox.FocusLost:Connect(function(enterPressed)
                TweenService:Create(InputStroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
                task.spawn(callback, TextBox.Text, enterPressed)
            end)

            BoxFrame.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            BoxFrame.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.15), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            return {
                SetText = function(newText)
                    TextBox.Text = newText
                end,
                GetText = function()
                    return TextBox.Text
                end
            }
        end

        return Tab
    end

    -- Window-level helper to generate full system notifications
    function Window:Notify(title, description, duration)
        title = title or "Notification"
        description = description or ""
        duration = duration or 4

        local NotifyFrame = makeElement("Frame", {
            Name = "Notification",
            Size = UDim2.new(0, 220, 0, 60),
            Position = UDim2.new(1, 20, 1, -80), -- Starts off-screen right
            BackgroundColor3 = TungstenHub.Theme.Header,
            BorderSizePixel = 0,
            Parent = ScreenGui
        })
        table.insert(themeObjects.Headers, NotifyFrame)

        local NotifyCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = NotifyFrame
        })

        local NotifyStroke = makeElement("UIStroke", {
            Color = TungstenHub.Theme.CardStroke,
            Thickness = 1,
            Parent = NotifyFrame
        })
        table.insert(themeObjects.Strokes, NotifyStroke)

        local LeftSideLine = makeElement("Frame", {
            Size = UDim2.new(0, 3.5, 1, 0),
            BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
            BorderSizePixel = 0,
            Parent = NotifyFrame
        })
        table.insert(themeObjects.Backgrounds, LeftSideLine)
        
        local LeftSideLineGrad = makeElement("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, TungstenHub.Theme.AccentGrad1),
                ColorSequenceKeypoint.new(1, TungstenHub.Theme.AccentGrad2)
            }),
            Parent = LeftSideLine
        })
        table.insert(themeObjects.Gradients, LeftSideLineGrad)

        local LineCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 2),
            Parent = LeftSideLine
        })

        local NotifyTitle = makeElement("TextLabel", {
            Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.new(0, 12, 0, 4),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = TungstenHub.Theme.TextMain,
            TextSize = 11.5,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = NotifyFrame
        })
        table.insert(themeObjects.MainText, NotifyTitle)

        local NotifyDesc = makeElement("TextLabel", {
            Size = UDim2.new(1, -20, 1, -26),
            Position = UDim2.new(0, 12, 0, 22),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = TungstenHub.Theme.TextDark,
            TextSize = 10.5,
            Font = Enum.Font.GothamMedium,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = NotifyFrame
        })
        table.insert(themeObjects.DarkText, NotifyDesc)

        -- Slide notification in
        TweenService:Create(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -240, 1, -80)
        }):Play()

        -- Auto dismiss
        task.delay(duration, function()
            local slideOut = TweenService:Create(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, 20, 1, -80)
            })
            slideOut:Play()
            slideOut.Completed:Connect(function()
                NotifyFrame:Destroy()
            end)
        end)
    end

    return Window
end

return TungstenHub
