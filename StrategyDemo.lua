--[[
    Lyra strategy example.

    Steps run in list order. Place and upgrade steps wait for a real change to
    Players.LocalPlayer.Cash before retrying; no step is controlled by timers.
    There is deliberately no restart/rejoin logic because this game exposes no
    restart remote.
]]

local Lyra = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua"
))()

Lyra:Loadout("Shotgunner", "Minigunner", "None", "None", "None")
Lyra:Mode("Hardcore")
Lyra:GameInfo("Wretched Front", {})

local Strategy = {
    { action = "skip", label = "the opening wave" },
    { action = "place", troop = "Shotgunner", x = -7.348, y = 0.963, z = -31.465 },

    { action = "skip", label = "the next wave" },
    { action = "upgrade", tower = 1 },

    { action = "skip", label = "the next wave" },
    { action = "place", troop = "Minigunner", x = -1.223, y = 0.327, z = -16.418 },

    { action = "skip", label = "the next wave" },
    { action = "upgrade", tower = 2 },

    { action = "skip", label = "the next wave" },
    -- This sell cannot run until every earlier step, including upgrade #2, succeeds.
    { action = "sell", tower = 1 },
}

Lyra:Run(Strategy)
