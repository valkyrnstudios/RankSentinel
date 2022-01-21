local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["Notification"] = {
    ["default"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
            ["Whisper"] = string.format("{rt7} %s detected", addonName)
        },
        ["Base"] = "%s used %s (Rank %d), next rank available at level %d.",
        ["Suffix"] = "You might be missing training or using an outdated ability shortcut.",
        ["You"] = "you"
    },
    ["troll"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t',
            ["Whisper"] = string.format("{rt8} %s Oy!", addonName)
        },
        ["Base"] = "%s be usin' %s (Rank %d), new at %d, mon.",
        ["Suffix"] = "Ya may be missin' trainin' or usin' an old shortcut",
        ["You"] = "ya"
    },
    ["aussie"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1.blp:0|t',
            ["Whisper"] = string.format("{rt1} %s sprung ya:", addonName)
        },
        ["Base"] = "%s usin' %s (Rank %d), it's an oldie, new one at %d.",
        ["Suffix"] = "Not ta be a knocker, but make sure ya prepare before venturin' out in the brush",
        ["You"] = "you"
    },
    ["gogo"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3.blp:0|t to be the best that',
            ["Whisper"] = string.format(
                "{rt3} %s: Friendly reminder to be the best that", addonName)
        },
        ["Base"] = "%s can be! There's a higher rank of %s (Rank %d) available at level %d.",
        ["Suffix"] = "Please check your action bars or visit your trainer when you can. Cheers!",
        ["You"] = "you"
    }
}

L["Cache"] = {
    ["Reset"] = "Cache reset: %d entries purged, %d max ranks forgotten, %d pet owners cleared",
    ["Queue"] = "Queued - %s, %s"
}

L["Broadcast"] = {
    ["Unrecognized"] = "Unrecognized broadcast (%s), you or %s's client may be outdated"
}

L["Cluster"] = {
    ["Lead"] = "Cluster Lead: %s",
    ["Sync"] = "Broadcasting sync %d",
    ["Batch"] = "Syncing batch %d to %d"
}

L["Utilities"] = {
    ["Upgrade"] = "Addon version change, resetting cache",
    ["IgnorePlayer"] = {
        ["Error"] = "Must target a unit",
        ["Ignored"] = "Ignored: %s",
        ["Unignored"] = "Unignored: %s"
    }
}

L["ChatCommand"] = {
    ["Reset"] = "Settings reset",
    ["Count"] = {
        ["Spells"] = "Spells caught: %d",
        ["Pets"] = "Pet owners: %d",
        ["Ranks"] = "Ranks cached: %d"
    },
    ["Ignore"] = {
        ["Target"] = "Select a target to ignore",
        ["Count"] = "Currently ignoring %d players"
    },
    ["Queue"] = {
        ["Clear"] = "Cleared %d queued notifications",
        ["Count"] = "Currently %d queued notifications"
    },
    ["Report"] = {
        ["Header"] = "%sDetected %d low ranks this session",
        ["Summary"] = "%s - %s (Rank %d)",
        ["Unsupported"] = "Unsupported channel %s"
    },
    ["Flavor"] = {
        ["Set"] = "Notification flavor set to: %s",
        ["Available"] = "Available notification flavors are",
        ["Unavailable"] = "%s flavor is no longer available, resetting to default"
    }
}

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
    ["report [channel]"] = 'report session data [self, say, raid, guild]',
    ["flavor"] = 'list available notification flavors',
    ["flavor [option]"] = 'set notification flavor to option'
}
