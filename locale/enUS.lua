local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["Notification"] = {
    ["Prefix"] = {
        ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
        ["Whisper"] = string.format("{rt7} %s detected", addonName)
    },
    ["Base"] = "%s used %s (Rank %d), next rank available at level %d.",
    ["Suffix"] = "You might be missing training or using an outdated ability shortcut."
};

L["Help"] = {
    ["title"] = 'Command-line options',
    ["enable"] = 'toggles combat log parsing',
    ["whisper"] = 'toggles whispers to players',
    ["reset"] = 'resets profile to defaults',
    ["count"] = 'prints current statistics',
    ["debug"] = 'toggles debug output for testing',
    ["clear"] = 'clears local ability caches',
    ["lead"] = 'sets yourself as lead',
    ["ignore"] = 'adds current target to addon ignore list, will not report rank errors',
    ["queue"] = 'prints queued notifications',
    ["queue clear"] = 'clears queued notifications',
    ["queue process"] = 'processes queued notifications',
    ["sync"] = 'broadcast announcement cache',
    ["report [channel]"] = 'report session data [say, raid, guild]'
}
