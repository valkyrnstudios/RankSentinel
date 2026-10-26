local addonName, addon = ...

local fmt = string.format

addon.NotificationTemplates = addon.NotificationTemplates or {}
addon.NotificationTemplates.enUS = {
    ["random"] = false,
    ["default"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
            ["Whisper"] = fmt("{rt7} %s detected", addonName)
        },
        ["Base"] = "%s (Rank %d) was used%s, there's a newer rank at level %d.",
        ["Suffix"] = "Your action bars may be outdated.",
        ["By"] = " by %s"
    },
    ["troll"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t',
            ["Whisper"] = fmt("{rt8} %s: Oi,", addonName)
        },
        ["Base"] = "%s (Rank %d) be used%s, new at %d mon.",
        ["Suffix"] = "Ya may be missin' trainin' or usin' an old shortcut",
        ["By"] = " from %s"
    },
    ["gogowatch"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t you',
            ["Whisper"] = fmt("{rt7} %s: Friendly Reminder! You", addonName)
        },
        ["Base"] = "just used a low rank of %s (Rank %d)%s.",
        ["Suffix"] = "Please check your Action Bars or visit your Class Trainer to make sure you've got the right ability for your level.",
        ["By"] = " (on %s)"
    },
    ["ogre"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t me see',
            ["Whisper"] = "{rt8} me see"
        },
        ["Base"] = "puny %s %d power%s smash lurn gud smash %d.",
        ["Suffix"] = "Big smash!",
        ["By"] = " from %s"
    },
    ["murloc"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4.blp:0|t',
            ["Whisper"] = "{rt4} Mmmrrglllm,"
        },
        ["Base"] = "nk mrrrggk %s %d%s urka %d.",
        ["Suffix"] = "Mmmm mrrrggk!",
        ["By"] = " mmgr %s"
    },
    ["pirate"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2.blp:0|t',
            ["Whisper"] = "{rt2} Ahoy!"
        },
        ["Base"] = "%s (Rank %d) be used%s, there be better booty at %d.",
        ["Suffix"] = "Check yer dock master fer a new beauty!",
        ["By"] = " by ye %s"
    }
}
