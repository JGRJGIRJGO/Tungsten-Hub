--[[
    Lyra strategy recorder example.

    Opens the Lyra UI Library and adds a Record Strategy button. While recording,
    place, upgrade, sell, and wave skip remote calls are captured into a strategy
    table that can be replayed by LyraMacroLib.
]]

local LyraUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraV2.lua?t=" .. tostring(os.time())
))()

local LyraMacro = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/JGRJGIRJGO/Tungsten-Hub/main/LyraMacroLib.lua?t=" .. tostring(os.time())
))()

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

local Window = LyraUI:CreateWindow({
    Name = "Lyra Strategy Recorder",
    Subtitle = "Macro Tools",
})

local StrategyTab = Window:CreateTab("Strategy")

StrategyTab:CreateLabel("Record tower placements, upgrades, sells, and wave skips.")

local isRecording = false
local recordButton

recordButton = StrategyTab:CreateButton("Record Strategy", function()
    if type(LyraMacro.StartRecording) ~= "function" or type(LyraMacro.StopRecording) ~= "function" then
        Window:Notify("Recorder Unavailable", "LyraMacroLib.lua does not include recording support yet.", 4)
        return
    end

    if isRecording then
        local recordedStrategy = LyraMacro:StopRecording()
        isRecording = false
        recordButton.UpdateButtonText("Record Strategy")
        Window:Notify("Recording Stopped", "Recorded " .. tostring(#recordedStrategy) .. " strategy steps.", 3)
        return
    end

    local started, message = LyraMacro:StartRecording()

    if not started then
        Window:Notify("Recorder Unavailable", message or "Strategy recording could not be started.", 4)
        return
    end

    isRecording = true
    recordButton.UpdateButtonText("Stop Recording")
    Window:Notify("Recording Started", "Your strategy actions are now being recorded.", 3)
end)

StrategyTab:CreateButton("Run Demo Strategy", function()
    task.spawn(function()
        LyraMacro:Run(Strategy)
    end)
end)

Window:Notify("Lyra UI Library", "Strategy recorder loaded.", 4)
