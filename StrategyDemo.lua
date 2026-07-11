--[[
    Lyra strategy recorder example.

    Opens the Lyra UI Library and adds a Record Strategy button. While recording,
    place, upgrade, sell, and wave skip remote calls are captured into a strategy
    table that can be replayed by LyraMacroLib.
]]

local LyraUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraV2.lua?t=" .. tostring(os.time())
))()

local previousAutoUI
local hasSharedEnvironment = type(getgenv) == "function"

if hasSharedEnvironment then
    previousAutoUI = getgenv().LyraMacroAutoUI
    getgenv().LyraMacroAutoUI = false
end

local LyraMacro = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua?t=" .. tostring(os.time())
))()

if hasSharedEnvironment then
    getgenv().LyraMacroAutoUI = previousAutoUI
end

LyraMacro:Loadout("Shotgunner", "Minigunner", "None", "None", "None")
LyraMacro:Mode("Hardcore")
LyraMacro:GameInfo("Wretched Front", {})

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

LyraMacro:CreateRecorderWindow({
    LyraUI = LyraUI,
    Strategy = Strategy,
})
