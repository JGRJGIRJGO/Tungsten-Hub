--[[
    Tungsten Hub UI Library & Demo
    All-in-one script. You can run this directly in a LocalScript in StarterGui
    or execute it using a Roblox exploit executor.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Determine the safest parent for the Gui (CoreGui for exploits/Studio, PlayerGui fallback)
local Parent = game:GetService("CoreGui")
local success, _ = pcall(function()
    local _ = Parent.Name
end)
if not success then
    Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Destroy previous instances to avoid clutter
if Parent:FindFirstChild("TungstenHub") then
    Parent:FindFirstChild("TungstenHub"):Destroy()
end

local TungstenHub = {}

-- Pre-defined UI Themes
TungstenHub.Themes = {
    Tungsten = {
        Background = Color3.fromRGB(15, 15, 18),
        Header = Color3.fromRGB(22, 22, 26),
        Sidebar = Color3.fromRGB(18, 18, 22),
        Card = Color3.fromRGB(25, 25, 30),
        CardStroke = Color3.fromRGB(40, 40, 45),
        AccentGrad1 = Color3.fromRGB(0, 180, 216),    -- Glowing metallic cyan
        AccentGrad2 = Color3.fromRGB(72, 202, 228),    -- Metallic blue-silver
        TextMain = Color3.fromRGB(240, 240, 245),
        TextDark = Color3.fromRGB(150, 150, 160),
    },
    Nebula = {
        Background = Color3.fromRGB(10, 8, 18),
        Header = Color3.fromRGB(15, 12, 26),
        Sidebar = Color3.fromRGB(12, 10, 20),
        Card = Color3.fromRGB(18, 15, 30),
        CardStroke = Color3.fromRGB(45, 30, 70),
        AccentGrad1 = Color3.fromRGB(138, 43, 226), -- Violet / Purple
        AccentGrad2 = Color3.fromRGB(218, 112, 214), -- Orchid Pink
        TextMain = Color3.fromRGB(245, 240, 255),
        TextDark = Color3.fromRGB(160, 140, 180),
    },
    BloodMoon = {
        Background = Color3.fromRGB(16, 8, 8),
        Header = Color3.fromRGB(24, 12, 12),
        Sidebar = Color3.fromRGB(20, 10, 10),
        Card = Color3.fromRGB(30, 16, 16),
        CardStroke = Color3.fromRGB(60, 25, 25),
        AccentGrad1 = Color3.fromRGB(220, 20, 60), -- Crimson Red
        AccentGrad2 = Color3.fromRGB(255, 69, 0), -- Orange
        TextMain = Color3.fromRGB(255, 240, 240),
        TextDark = Color3.fromRGB(180, 130, 130),
    },
    Emerald = {
        Background = Color3.fromRGB(8, 15, 12),
        Header = Color3.fromRGB(12, 24, 18),
        Sidebar = Color3.fromRGB(10, 20, 15),
        Card = Color3.fromRGB(16, 32, 24),
        CardStroke = Color3.fromRGB(30, 60, 45),
        AccentGrad1 = Color3.fromRGB(46, 204, 113), -- Emerald Green
        AccentGrad2 = Color3.fromRGB(26, 188, 156), -- Sea Green
        TextMain = Color3.fromRGB(240, 255, 245),
        TextDark = Color3.fromRGB(140, 180, 155),
    },
    Midnight = {
        Background = Color3.fromRGB(8, 10, 15),
        Header = Color3.fromRGB(12, 15, 22),
        Sidebar = Color3.fromRGB(10, 12, 18),
        Card = Color3.fromRGB(16, 20, 28),
        CardStroke = Color3.fromRGB(30, 38, 54),
        AccentGrad1 = Color3.fromRGB(41, 128, 185), -- Cobalt Blue
        AccentGrad2 = Color3.fromRGB(52, 152, 219), -- Sky Blue
        TextMain = Color3.fromRGB(240, 245, 255),
        TextDark = Color3.fromRGB(150, 160, 185),
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

-- Top-level Window builder
function TungstenHub:CreateWindow(titleText, subtitleText)
    titleText = titleText or "Tungsten Hub"
    subtitleText = subtitleText or "Roblox Edition"

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
        Size = UDim2.new(0, 520, 0, 360),
        Position = UDim2.new(0.5, -260, 0.5, -180),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = ScreenGui
    })

    -- Premium Glow/Drop Shadow Decal
    local Shadow = makeElement("ImageLabel", {
        Name = "Shadow",
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.new(0, -15, 0, -15),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 20, 20),
        ZIndex = 0,
        Parent = MainContainer
    })

    -- Main Content Frame (Clips children)
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
        CornerRadius = UDim.new(0, 12),
        Parent = MainFrame
    })

    -- Glow/Gradient Border Outline
    local MainStroke = makeElement("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1.25,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = MainFrame
    })
    table.insert(themeObjects.Strokes, MainStroke)

    local MainStrokeGrad = makeElement("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, TungstenHub.Theme.AccentGrad1),
            ColorSequenceKeypoint.new(0.5, TungstenHub.Theme.CardStroke),
            ColorSequenceKeypoint.new(1, TungstenHub.Theme.AccentGrad2)
        }),
        Rotation = 45,
        Parent = MainStroke
    })
    table.insert(themeObjects.Gradients, MainStrokeGrad)

    -- Top Accent Line
    local BrandLine = makeElement("Frame", {
        Name = "BrandLine",
        Size = UDim2.new(1, 0, 0, 2.5),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = MainFrame
    })

    local BrandGrad = makeElement("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, TungstenHub.Theme.AccentGrad1),
            ColorSequenceKeypoint.new(0.5, TungstenHub.Theme.AccentGrad2),
            ColorSequenceKeypoint.new(1, TungstenHub.Theme.AccentGrad1)
        }),
        Parent = BrandLine
    })
    table.insert(themeObjects.Gradients, BrandGrad)

    -- Header Panel
    local Header = makeElement("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 2.5),
        BackgroundColor3 = TungstenHub.Theme.Header,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = MainFrame
    })
    table.insert(themeObjects.Headers, Header)

    local TitleLabel = makeElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = TungstenHub.Theme.TextMain,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header
    })
    table.insert(themeObjects.MainText, TitleLabel)

    local SubtitleLabel = makeElement("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(0, TitleLabel.TextBounds.X + 25, 0, 0),
        BackgroundTransparency = 1,
        Text = subtitleText,
        TextColor3 = TungstenHub.Theme.TextDark,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header
    })
    table.insert(themeObjects.DarkText, SubtitleLabel)

    TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        SubtitleLabel.Position = UDim2.new(0, TitleLabel.TextBounds.X + 25, 0, 0)
    end)

    -- Close Button
    local CloseBtn = makeElement("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0.5, -15),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = TungstenHub.Theme.TextDark,
        TextSize = 22,
        Font = Enum.Font.GothamMedium,
        Parent = Header
    })
    table.insert(themeObjects.DarkText, CloseBtn)

    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        local fadeOut = TweenService:Create(MainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 0),
            Position = UDim2.new(0.5, -260, 0.5, 0),
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            ScreenGui:Destroy()
        end)
    end)

    makeDraggable(Header, MainContainer)

    -- Sidebar (Tabs list)
    local Sidebar = makeElement("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 140, 1, -44.5),
        Position = UDim2.new(0, 0, 0, 44.5),
        BackgroundColor3 = TungstenHub.Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = MainFrame
    })
    table.insert(themeObjects.Sidebars, Sidebar)

    local Separator = makeElement("Frame", {
        Name = "Separator",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = TungstenHub.Theme.CardStroke,
        BorderSizePixel = 0,
        Parent = Sidebar
    })
    table.insert(themeObjects.Strokes, Separator)

    local SidebarScroll = makeElement("ScrollingFrame", {
        Name = "TabsList",
        Size = UDim2.new(1, -5, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = Sidebar
    })

    local SidebarLayout = makeElement("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = SidebarScroll
    })

    SidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, SidebarLayout.AbsoluteContentSize.Y)
    end)

    -- Content Container (Pages)
    local PageContainer = makeElement("Frame", {
        Name = "PageContainer",
        Size = UDim2.new(1, -145, 1, -50),
        Position = UDim2.new(0, 145, 0, 50),
        BackgroundTransparency = 1,
        Parent = MainFrame
    })

    -- Entrance Animation
    MainContainer.Size = UDim2.new(0, 520, 0, 0)
    MainContainer.Position = UDim2.new(0.5, -260, 0.5, 0)
    local fadeIn = TweenService:Create(MainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 520, 0, 360),
        Position = UDim2.new(0.5, -260, 0.5, -180),
    })
    fadeIn:Play()

    local isVisible = true
    local function toggleUI()
        if not MainContainer or not MainContainer.Parent then return end
        isVisible = not isVisible
        MainContainer.Visible = isVisible
    end

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

    -- Mobile Draggable Toggle Button
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
            Thickness = 1.5,
            Parent = MobileButton
        })
        table.insert(themeObjects.Strokes, ButtonStroke)
        
        local ButtonLabel = makeElement("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "T",
            TextColor3 = TungstenHub.Theme.TextMain,
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            Parent = MobileButton
        })
        table.insert(themeObjects.MainText, ButtonLabel)
        
        local ButtonGrad = makeElement("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, TungstenHub.Theme.AccentGrad1),
                ColorSequenceKeypoint.new(1, TungstenHub.Theme.AccentGrad2)
            }),
            Parent = ButtonStroke
        })
        table.insert(themeObjects.Gradients, ButtonGrad)
        
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
                ColorSequenceKeypoint.new(0.5, themeTable.CardStroke),
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
        
        local TabButton = makeElement("TextButton", {
            Name = tabName .. "_Btn",
            Size = UDim2.new(1, -8, 0, 32),
            BackgroundColor3 = Color3.fromRGB(30, 30, 35),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = SidebarScroll
        })

        local TabBtnCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = TabButton
        })

        local ActiveIndicator = makeElement("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 3, 0.6, 0),
            Position = UDim2.new(0, 3, 0.2, 0),
            BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton
        })
        table.insert(themeObjects.Backgrounds, ActiveIndicator)
        
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
            Size = UDim2.new(1, -15, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = tabName,
            TextColor3 = TungstenHub.Theme.TextDark,
            TextSize = 13,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = TabButton
        })
        table.insert(themeObjects.DarkText, TabLabel)

        -- Tab Content Page
        local TabPage = makeElement("ScrollingFrame", {
            Name = tabName .. "_Page",
            Size = UDim2.new(1, -10, 1, -10),
            Position = UDim2.new(0, 5, 0, 5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = TungstenHub.Theme.CardStroke,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Parent = PageContainer
        })

        local TabPageLayout = makeElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
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
            TweenService:Create(TabButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.88}):Play()
            TabPage.Visible = true
        end

        TabButton.MouseButton1Click:Connect(selectTab)

        TabButton.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                TweenService:Create(TabLabel, TweenInfo.new(0.15), {TextColor3 = TungstenHub.Theme.TextMain}):Play()
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.94}):Play()
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
        -- COMPONENT CREATORS
        -- =====================================================================

        function Tab:CreateLabel(textString)
            local LabelFrame = makeElement("Frame", {
                Name = "LabelFrame",
                Size = UDim2.new(1, -6, 0, 24),
                BackgroundTransparency = 1,
                Parent = TabPage
            })

            local TextLabel = makeElement("TextLabel", {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 5, 0, 0),
                BackgroundTransparency = 1,
                Text = textString,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 12.5,
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
                Size = UDim2.new(1, -6, 0, 36),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, BtnFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
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
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                AutoButtonColor = false,
                Parent = BtnFrame
            })
            table.insert(themeObjects.MainText, Button)

            Button.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
                TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 36)}):Play()
            end)

            Button.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
                TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = TungstenHub.Theme.Card}):Play()
            end)

            Button.MouseButton1Down:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.05), {Size = UDim2.new(1, -12, 0, 34), Position = UDim2.new(0, 3, 0, 1)}):Play()
            end)

            Button.MouseButton1Up:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.1), {Size = UDim2.new(1, -6, 0, 36), Position = UDim2.new(0, 0, 0, 0)}):Play()
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
                Size = UDim2.new(1, -6, 0, 38),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, ToggleFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
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
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = ToggleFrame
            })
            table.insert(themeObjects.MainText, Label)

            -- Switch Frame
            local Switch = makeElement("Frame", {
                Name = "Switch",
                Size = UDim2.new(0, 38, 0, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = Color3.fromRGB(45, 45, 50),
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

            -- Circular Knob
            local Circle = makeElement("Frame", {
                Name = "Circle",
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(200, 200, 205),
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
                local targetPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
                local targetColor = state and TungstenHub.Theme.AccentGrad1 or Color3.fromRGB(45, 45, 50)
                local targetCircleColor = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 205)

                local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                TweenService:Create(Circle, tweenInfo, {Position = targetPos, BackgroundColor3 = targetCircleColor}):Play()
                TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                
                task.spawn(callback, toggled)
            end

            ToggleBtn.MouseButton1Click:Connect(function()
                updateToggle(not toggled)
            end)

            ToggleBtn.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ToggleBtn.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            updateToggle(default)

            table.insert(themeObjects.Updaters, function(newTheme)
                local targetColor = toggled and newTheme.AccentGrad1 or Color3.fromRGB(45, 45, 50)
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
                Size = UDim2.new(1, -6, 0, 48),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, SliderFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
                Parent = SliderFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = SliderFrame
            })
            table.insert(themeObjects.Strokes, Stroke)

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -100, 0, 24),
                Position = UDim2.new(0, 12, 0, 2),
                BackgroundTransparency = 1,
                Text = sliderText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = SliderFrame
            })
            table.insert(themeObjects.MainText, Label)

            local ValueLabel = makeElement("TextLabel", {
                Size = UDim2.new(0, 80, 0, 24),
                Position = UDim2.new(1, -92, 0, 2),
                BackgroundTransparency = 1,
                Text = tostring(default),
                TextColor3 = TungstenHub.Theme.TextDark,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = SliderFrame
            })
            table.insert(themeObjects.DarkText, ValueLabel)

            -- Track
            local Track = makeElement("Frame", {
                Name = "Track",
                Size = UDim2.new(1, -24, 0, 5),
                Position = UDim2.new(0, 12, 1, -13),
                BackgroundColor3 = Color3.fromRGB(38, 38, 42),
                BorderSizePixel = 0,
                Parent = SliderFrame
            })

            local TrackCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Track
            })

            -- Progress Fill
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
                Size = UDim2.new(0, 11, 0, 11),
                Position = UDim2.new(0, -5, 0.5, -5.5),
                BackgroundColor3 = Color3.fromRGB(245, 245, 250),
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
                    TweenService:Create(Handle, TweenInfo.new(0.15), {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, -7, 0.5, -7)}):Play()
                end
            end)

            SlidingTrigger.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                    TweenService:Create(Handle, TweenInfo.new(0.15), {Size = UDim2.new(0, 11, 0, 11), Position = UDim2.new(0, -5, 0.5, -5.5)}):Play()
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    moveSlider(input)
                end
            end)

            SlidingTrigger.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            SlidingTrigger.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
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
                Size = UDim2.new(1, -6, 0, 38),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, DropdownFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
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
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundTransparency = 1,
                Parent = DropdownFrame
            })

            local Label = makeElement("TextLabel", {
                Size = UDim2.new(1, -120, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = dropdownText,
                TextColor3 = TungstenHub.Theme.TextMain,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = TopArea
            })
            table.insert(themeObjects.MainText, Label)

            local SelectionLabel = makeElement("TextLabel", {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, -135, 0, 0),
                BackgroundTransparency = 1,
                Text = activeOption,
                TextColor3 = TungstenHub.Theme.AccentGrad2,
                TextSize = 12,
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
                TextSize = 11,
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

            local OptionsHolder = makeElement("Frame", {
                Name = "OptionsHolder",
                Size = UDim2.new(1, -20, 0, 0),
                Position = UDim2.new(0, 10, 0, 38),
                BackgroundTransparency = 1,
                Parent = DropdownFrame
            })

            local HolderLayout = makeElement("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = OptionsHolder
            })

            local optionButtons = {}

            local function toggleDropdown(state)
                dropdownOpen = state
                local targetHeight = state and (38 + HolderLayout.AbsoluteContentSize.Y + 10) or 38
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
                        Size = UDim2.new(1, 0, 0, 28),
                        BackgroundColor3 = Color3.fromRGB(32, 32, 38),
                        BorderSizePixel = 0,
                        Text = optionText,
                        TextColor3 = isSelected and TungstenHub.Theme.TextMain or TungstenHub.Theme.TextDark,
                        TextSize = 12,
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
                        TweenService:Create(OptButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
                    end)
                    OptButton.MouseLeave:Connect(function()
                        TweenService:Create(OptButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 32, 38)}):Play()
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
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ClickButton.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            refreshList()

            table.insert(themeObjects.Updaters, function(newTheme)
                SelectionLabel.TextColor3 = newTheme.AccentGrad2
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
                Size = UDim2.new(1, -6, 0, 42),
                BackgroundColor3 = TungstenHub.Theme.Card,
                BorderSizePixel = 0,
                Parent = TabPage
            })
            table.insert(themeObjects.Cards, BoxFrame)

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
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
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = BoxFrame
            })
            table.insert(themeObjects.MainText, Label)

            -- Input Box Container
            local InputContainer = makeElement("Frame", {
                Name = "InputContainer",
                Size = UDim2.new(0, 130, 0, 26),
                Position = UDim2.new(1, -142, 0.5, -13),
                BackgroundColor3 = Color3.fromRGB(30, 30, 35),
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
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                ClipsDescendants = true,
                ClearTextOnFocus = false,
                Parent = InputContainer
            })
            table.insert(themeObjects.MainText, TextBox)

            TextBox.Focused:Connect(function()
                TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            TextBox.FocusLost:Connect(function(enterPressed)
                TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
                task.spawn(callback, TextBox.Text, enterPressed)
            end)

            BoxFrame.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            BoxFrame.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
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
            Size = UDim2.new(0, 4, 1, 0),
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
            Size = UDim2.new(1, -20, 0, 22),
            Position = UDim2.new(0, 12, 0, 4),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = TungstenHub.Theme.TextMain,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = NotifyFrame
        })
        table.insert(themeObjects.MainText, NotifyTitle)

        local NotifyDesc = makeElement("TextLabel", {
            Size = UDim2.new(1, -20, 1, -26),
            Position = UDim2.new(0, 12, 0, 24),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = TungstenHub.Theme.TextDark,
            TextSize = 11,
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

-- =====================================================================
-- DEMO ASSEMBLY START
-- =====================================================================

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

MovementTab:CreateTextbox("Set Custom WalkSpeed", "Type speed and press Enter...", function(text)
    local num = tonumber(text)
    if num then
        local character = game:GetService("Players").LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid").WalkSpeed = num
            Window:Notify("Speed Updated", "WalkSpeed set to: " .. tostring(num), 2)
        end
    else
        Window:Notify("Error", "Please enter a valid number", 2)
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

SettingsTab:CreateButton("Destroy UI", function()
    local existing = game:GetService("CoreGui"):FindFirstChild("TungstenHub") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("TungstenHub")
    if existing then
        existing:Destroy()
    end
end)

-- Send a welcoming notification
Window:Notify("Success", "Loaded Tungsten Hub!", 4)
