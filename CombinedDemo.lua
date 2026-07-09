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
TungstenHub.Theme = {
    Background = Color3.fromRGB(15, 15, 18),
    Header = Color3.fromRGB(22, 22, 26),
    Sidebar = Color3.fromRGB(18, 18, 22),
    Card = Color3.fromRGB(25, 25, 30),
    CardStroke = Color3.fromRGB(40, 40, 45),
    AccentGrad1 = Color3.fromRGB(0, 180, 216),    -- Glowing metallic cyan
    AccentGrad2 = Color3.fromRGB(72, 202, 228),    -- Metallic blue-silver
    TextMain = Color3.fromRGB(240, 240, 245),
    TextDark = Color3.fromRGB(150, 150, 160),
    AccentGlow = Color3.fromRGB(0, 180, 216),
}

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

    local ScreenGui = makeElement("ScreenGui", {
        Name = "TungstenHub",
        Parent = Parent,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    -- Main Container
    local MainFrame = makeElement("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 520, 0, 360),
        Position = UDim2.new(0.5, -260, 0.5, -180),
        BackgroundColor3 = TungstenHub.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = ScreenGui
    })

    local MainCorner = makeElement("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = MainFrame
    })

    local MainStroke = makeElement("UIStroke", {
        Color = TungstenHub.Theme.CardStroke,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = MainFrame
    })

    -- Top Gradient Line (Premium metallic feel)
    local BrandLine = makeElement("Frame", {
        Name = "BrandLine",
        Size = UDim2.new(1, 0, 0, 3),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
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

    -- Header Panel
    local Header = makeElement("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 3),
        BackgroundColor3 = TungstenHub.Theme.Header,
        BorderSizePixel = 0,
        Parent = MainFrame
    })

    local TitleLabel = makeElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = TungstenHub.Theme.TextMain,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header
    })

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

    -- Update subtitle position dynamically based on title length
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

    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        -- Smooth closing animation
        local fadeOut = TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 0),
            Position = UDim2.new(0.5, -260, 0.5, 0),
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            ScreenGui:Destroy()
        end)
    end)

    -- Enable Dragging on Header
    makeDraggable(Header, MainFrame)

    -- Sidebar (Tabs list)
    local Sidebar = makeElement("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 140, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = TungstenHub.Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = MainFrame
    })

    -- Subtle border separator between Sidebar and Content
    local Separator = makeElement("Frame", {
        Name = "Separator",
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = TungstenHub.Theme.CardStroke,
        BorderSizePixel = 0,
        Parent = Sidebar
    })

    local SidebarScroll = makeElement("ScrollingFrame", {
        Name = "TabsList",
        Size = UDim2.new(1, -5, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = TungstenHub.Theme.CardStroke,
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
    MainFrame.Size = UDim2.new(0, 520, 0, 0)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, 0)
    local fadeIn = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 520, 0, 360),
        Position = UDim2.new(0.5, -260, 0.5, -180),
    })
    fadeIn:Play()

    -- Window Object Definition
    local Window = {
        Tabs = {},
        ActiveTab = nil,
    }

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

        -- Glow indicator inside tab
        local ActiveIndicator = makeElement("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 3, 0.6, 0),
            Position = UDim2.new(0, 3, 0.2, 0),
            BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton
        })

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

        -- Tab Content Frame
        local TabPage = makeElement("ScrollingFrame", {
            Name = tabName .. "_Page",
            Size = UDim2.new(1, -10, 1, -10),
            Position = UDim2.new(0, 5, 0, 5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ScrollBarThickness = 4,
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

        -- Tab Object Definition
        local Tab = {
            Button = TabButton,
            Page = TabPage
        }

        local function selectTab()
            if Window.ActiveTab == Tab then return end

            -- Deactivate previous tab
            if Window.ActiveTab then
                TweenService:Create(Window.ActiveTab.Button.Label, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
                TweenService:Create(Window.ActiveTab.Button.Indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                TweenService:Create(Window.ActiveTab.Button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                Window.ActiveTab.Page.Visible = false
            end

            -- Activate new tab
            Window.ActiveTab = Tab
            TweenService:Create(TabButton.Label, TweenInfo.new(0.2), {TextColor3 = TungstenHub.Theme.TextMain}):Play()
            TweenService:Create(ActiveIndicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
            TweenService:Create(TabButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.85}):Play()
            
            -- Simple fade in for content
            TabPage.Visible = true
            TabPage.GroupTransparency = 1
            TweenService:Create(TabPage, TweenInfo.new(0.25), {GroupTransparency = 0}):Play()
        end

        TabButton.MouseButton1Click:Connect(selectTab)

        -- Tab Button Hover Effects
        TabButton.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                TweenService:Create(TabButton.Label, TweenInfo.new(0.15), {TextColor3 = TungstenHub.Theme.TextMain}):Play()
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.92}):Play()
            end
        end)

        TabButton.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                TweenService:Create(TabButton.Label, TweenInfo.new(0.15), {TextColor3 = TungstenHub.Theme.TextDark}):Play()
                TweenService:Create(TabButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
            end
        end)

        -- Auto-select the first tab created
        if not Window.ActiveTab then
            selectTab()
        end

        -- Component factories for this Tab
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
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = LabelFrame
            })

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

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
                Parent = BtnFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = BtnFrame
            })

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

            -- Hover & Press Animations
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

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
                Parent = ToggleFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = ToggleFrame
            })

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

            -- Toggle Box (Switch Outer Container)
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

            -- Inside Circle
            local Circle = makeElement("Frame", {
                Name = "Circle",
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(220, 220, 225),
                BorderSizePixel = 0,
                Parent = Switch
            })

            local CircleCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Circle
            })

            -- Invisible button overlays
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

                TweenService:Create(Circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos, BackgroundColor3 = targetCircleColor}):Play()
                TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
                
                task.spawn(callback, toggled)
            end

            -- Click event
            ToggleBtn.MouseButton1Click:Connect(function()
                updateToggle(not toggled)
            end)

            -- Hover animations
            ToggleBtn.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ToggleBtn.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            -- Initialize
            updateToggle(default)

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

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
                Parent = SliderFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = SliderFrame
            })

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

            -- Slider Track Bar
            local Track = makeElement("Frame", {
                Name = "Track",
                Size = UDim2.new(1, -24, 0, 6),
                Position = UDim2.new(0, 12, 1, -14),
                BackgroundColor3 = Color3.fromRGB(40, 40, 45),
                BorderSizePixel = 0,
                Parent = SliderFrame
            })

            local TrackCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Track
            })

            -- Filled Progress portion
            local Progress = makeElement("Frame", {
                Name = "Progress",
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
                BorderSizePixel = 0,
                Parent = Track
            })

            local ProgressCorner = makeElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Progress
            })

            -- Drag Handle (circle)
            local Handle = makeElement("Frame", {
                Name = "Handle",
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, -6, 0.5, -6),
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

            -- Value setting and movement tracking
            local isDragging = false
            
            local function moveSlider(input)
                local trackSize = Track.AbsoluteSize.X
                local relativeMouseX = math.clamp(input.Position.X - Track.AbsolutePosition.X, 0, trackSize)
                local percent = relativeMouseX / trackSize
                
                local rawValue = min + ((max - min) * percent)
                local roundedValue = math.floor(rawValue + 0.5)
                
                value = roundedValue
                ValueLabel.Text = tostring(value)
                
                -- Smooth visual update
                TweenService:Create(Progress, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(percent, 0, 1, 0)
                }):Play()
                
                task.spawn(callback, value)
            end

            SlidingTrigger.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = true
                    moveSlider(input)
                end
            end)

            SlidingTrigger.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    moveSlider(input)
                end
            end)

            -- Hover border effect
            SlidingTrigger.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            SlidingTrigger.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            -- Initial layout setup based on default value
            local initialPercent = math.clamp((default - min) / (max - min), 0, 1)
            Progress.Size = UDim2.new(initialPercent, 0, 1, 0)

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

            local Corner = makeElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
                Parent = DropdownFrame
            })

            local Stroke = makeElement("UIStroke", {
                Color = TungstenHub.Theme.CardStroke,
                Thickness = 1,
                Parent = DropdownFrame
            })

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

            local ClickButton = makeElement("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = TopArea
            })

            -- Dropdown Options Frame
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

            -- Build the dropdown buttons dynamically
            local function refreshList()
                for _, btn in ipairs(optionButtons) do
                    btn:Destroy()
                end
                optionButtons = {}

                for index, optionText in ipairs(list) do
                    local OptButton = makeElement("TextButton", {
                        Name = optionText .. "_Opt",
                        Size = UDim2.new(1, 0, 0, 28),
                        BackgroundColor3 = Color3.fromRGB(32, 32, 38),
                        BorderSizePixel = 0,
                        Text = optionText,
                        TextColor3 = (optionText == activeOption) and TungstenHub.Theme.TextMain or TungstenHub.Theme.TextDark,
                        TextSize = 12,
                        Font = (optionText == activeOption) and Enum.Font.GothamBold or Enum.Font.GothamMedium,
                        AutoButtonColor = false,
                        Parent = OptionsHolder
                    })

                    local OptCorner = makeElement("UICorner", {
                        CornerRadius = UDim.new(0, 4),
                        Parent = OptButton
                    })

                    local OptStroke = makeElement("UIStroke", {
                        Color = (optionText == activeOption) and TungstenHub.Theme.AccentGrad1 or TungstenHub.Theme.CardStroke,
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

            -- Hover border effect
            ClickButton.MouseEnter:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.AccentGrad1}):Play()
            end)

            ClickButton.MouseLeave:Connect(function()
                TweenService:Create(Stroke, TweenInfo.new(0.2), {Color = TungstenHub.Theme.CardStroke}):Play()
            end)

            refreshList()

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

        local NotifyCorner = makeElement("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = NotifyFrame
        })

        local NotifyStroke = makeElement("UIStroke", {
            Color = TungstenHub.Theme.CardStroke,
            Thickness = 1,
            Parent = NotifyFrame
        })

        local LeftSideLine = makeElement("Frame", {
            Size = UDim2.new(0, 4, 1, 0),
            BackgroundColor3 = TungstenHub.Theme.AccentGrad1,
            BorderSizePixel = 0,
            Parent = NotifyFrame
        })

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

-- ==========================================
-- DEMO CODE START
-- ==========================================

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
