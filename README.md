# Lyra UI Library

Lyra is a responsive Roblox UI library built for compact script tools. It includes a key gate, themes, notifications, draggable and resizable windows, and controls that work with mouse or touch input.

## Features

- Responsive desktop and mobile layout
- Dragging and bottom-right window resizing
- Buttons, toggles, sliders, dropdowns, textboxes, labels, and tabs
- Built-in themes and animated notifications
- SHA-256 key verification support
- Lucide icon support through [tijnepema/lucide-roblox](https://github.com/tijnepema/lucide-roblox)
- Backward-compatible positional API and table-style configuration

## Lucide Icons

Lyra includes the core icons used by the interface. To make every icon from `tijnepema/lucide-roblox` available by name, provide its module before creating controls:

```lua
local Lyra = require(path.To.Lyra)
local Lucide = require(path.To.Lucide)

Lyra:SetIconProvider(Lucide)

local Window = Lyra:CreateWindow({
    Name = "Lyra",
    Subtitle = "Tools",
    Icon = "command",
})

local Main = Window:CreateTab({
    Name = "Main",
    Icon = "home",
})

Main:CreateDropdown({
    Name = "Mode",
    Icon = "list-filter",
    Options = { "Record", "Replay" },
    CurrentOption = "Record",
    Callback = function(value)
        print(value)
    end,
})
```

`Icon` also accepts a Roblox asset ID, an `rbxassetid://` string, or the sprite descriptor returned by `Lucide.GetAsset(name, size)`.

## Documentation

[UI library documentation](https://jgrjgirjgo.github.io/Tungsten-Hub/library-documentation/#intro)

## Tower Defense Simulator: Reanimated

[Lyra Macro website](https://jgrjgirjgo.github.io/Tungsten-Hub/)
