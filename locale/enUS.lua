local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = "Enable";
L["Whisper"] = "Whisper";
L["Debug"] = "Debug";

L["Notification"] = {
    ["random"] = false,
    ["default"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
            ["Whisper"] = string.format("{rt7} %s detected", addonName)
        },
        ["Base"] = "%s (Rank %d) was used%s, there's a newer rank at level %d.",
        ["Suffix"] = "Please check your keybinds next time you can or see if a trainer has something waiting for you.",
        ["By"] = " by %s"
    },
    ["troll"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t',
            ["Whisper"] = string.format("{rt8} %s: Oi,", addonName)
        },
        ["Base"] = "%s (Rank %d) be used%s, new at %d mon.",
        ["Suffix"] = "Ya may be missin' trainin' or usin' an old shortcut",
        ["By"] = " from %s"
    },
    ["aussie"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1.blp:0|t',
            ["Whisper"] = string.format("{rt1} %s caught", addonName)
        },
        ["Base"] = "%s (Rank %d) cast%s, it's an oldie, new one at %d though.",
        ["Suffix"] = "Not ta be a knocker, but make sure ya prepare before venturin' out in the brush",
        ["By"] = " came from %s"
    },
    ["gogowatch"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t you',
            ["Whisper"] = string.format("{rt7} %s: Friendly Reminder! You",
                                        addonName)
        },
        ["Base"] = "just used a low rank of %s (Rank %d)%s.",
        ["Suffix"] = "Please check your Action Bars or visit your Class Trainer to make sure you've got the right ability for your level.",
        ["By"] = " (on %s)"
    },
    ["bro"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2.blp:0|t',
            ["Whisper"] = "{rt2} Bruh,"
        },
        ["Base"] = "%s (Rank %d)%s y u even, l2train at %d.",
        ["Suffix"] = "L2play scrub.",
        ["By"] = " from %s"
    },
    ["ogre"] = {
        ["Prefix"] = {
            ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp:0|t me see',
            ["Whisper"] = "{rt8} me see"
        },
        ["Base"] = "puny %s %d power%s smash lurn gud smash %d.",
        ["Suffix"] = "Big smash!",
        ["By"] = " from %s"
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
    ["advanced"] = 'Advanced command-line options',
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
