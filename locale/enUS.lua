local L = LibStub("AceLocale-3.0"):NewLocale("SpellSentinel", "enUS", true)

L["SpellSentinel"] = "Spell Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["PreMsgNonChat"] =
    "\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.png:0\124t";
L["PreMsgChat"] = "{rt7}";

L["PreMessageString"] = {
    ["Title"] = "Pre message",
    ["Default"] = "Friendly Reminder!"
};

L["CastString"] = {
    ["Title"] = "Cast message (caster, spellLink)",
    ["Default"] = "%s just used a low rank of %s."
};

L["TargetCastString"] = {
    ["Title"] = "Target cast message (caster, spellLink, target)",
    ["Default"] = "%s just used a low rank of %s on a level %s target."
};

L["PostMessageString"] = {
    ["Title"] = "Post message",
    ["Default"] = "You might be missing training or using an outdated ability shortcut."
};
