local L = LibStub("AceLocale-3.0"):NewLocale("SpellSentinel", "enUS", true)

L["SpellSentinel"] = "Spell Sentinel"
L["Enable"] = "Enable";
L["Disable"] = "Disable";
L["Whisper"] = "Whisper";

L["PreMsgNonChat"] =
    "\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.png:0\124t";
L["PreMsgChat"] = "{rt7} SpellSentinel:";

L["PreMessageString"] = {
    ["Title"] = "Pre message",
    ["Default"] = "Friendly Reminder!"
};

L["CastString"] = {
    ["Title"] = "Cast message (caster, spellLink, spellId)",
    ["Default"] = "%s just used a low rank of %s (%s)."
};

L["TargetCastString"] = {
    ["Title"] = "Target cast message (caster, spellLink, spellId, target)",
    ["Default"] = "%s just used a low rank of %s (%s) on a level %s target."
};

L["PostMessageString"] = {
    ["Title"] = "Post message",
    ["Default"] = "Please check your Action Bars or visit your Class Trainer to make sure you've got the right ability for your level."
};
