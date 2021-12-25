local L = LibStub("AceLocale-3.0"):NewLocale("RankSentinel", "enUS", true)

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
