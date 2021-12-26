local addonName, RankSentinel = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L["RankSentinel"] = "Rank Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["AnnouncePrefix"] = {
    ["Self"] = "\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.png:0\124t",
    ["Whisper"] = "{rt7} RankSentinel detected"
}

L["CastString"] = "%s just used a low rank of %s.";

L["PostMessageString"] =
    "You might be missing training or using an outdated ability shortcut.";

L["Help"] = {
    ["title"] = 'Command-line options',
    ["enable"] = 'toggles combat log parsing',
    ["whisper"] = 'toggles whispers to players',
    ["reset"] = 'resets profile to defaults',
    ["count"] = 'prints current statistics',
    ["debug"] = 'toggles debug output for testing',
    ["clear"] = 'clears local ability caches',
    ["cluster"] = 'prints cluster members',
    ["cluster reset"] = 'resets cluster to defaults',
    ["cluster elect"] = 'triggers lead election logic',
    ["ignore playerName"] = 'ignores all abilities cast by playerName'
}
