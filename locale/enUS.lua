local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["AnnouncePrefix"] = {
    ["Self"] = "\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.png:0\124t",
    ["Whisper"] = "{rt7} RankSentinel detected"
}

L["CastString"] = "%s just used a low rank of %s, next rank available at %d.";

L["PostMessageString"] =
    "You might be missing training or using an outdated ability shortcut.";

L["Queue"] = {["Processing"] = "Processing %d queued notifications"}

L["Help"] = {
    ["title"] = 'Command-line options',
    ["enable"] = 'toggles combat log parsing',
    ["whisper"] = 'toggles whispers to players',
    ["combat"] = 'toggles whispers to players after comba',
    ["reset"] = 'resets profile to defaults',
    ["count"] = 'prints current statistics',
    ["debug"] = 'toggles debug output for testing',
    ["clear"] = 'clears local ability caches',
    ["lead"] = 'sets yourself as lead',
    ["ignore"] = 'adds current target to addon ignore list, will not report rank errors',
    ["queue"] = 'prints queued notifications',
    ["queue clear"] = 'clears queued notifications',
    ["queue process"] = 'processes queued notifications'
}
