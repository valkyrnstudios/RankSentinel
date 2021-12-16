local L = LibStub("AceLocale-3.0"):NewLocale("SpellSentinel", "enUS", true)

L["SpellSentinel"] = "Spell Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";

L["PreMsgNonChat"] =
    "\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.png:0\124t";
L["PreMsgChat"] = "{rt7} SpellSentinel:";
L["PreMsgStandard"] = "Friendly Reminder!";
L["SelfCast"] = "%s just used a low rank of %s (%s).";
L["TargetCast"] = "%s just used a low rank of %s (%s) on a level %s target.";
L["PostMessage"] =
    "Please check your Action Bars or visit your Class Trainer to make sure you've got the right ability for your level.";
