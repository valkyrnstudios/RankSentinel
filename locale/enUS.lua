local addonName, _ = ...
local fmt = string.format
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = _G.ENABLE
L["Whisper"] = _G.WHISPER
L["Debug"] = _G.BINDING_HEADER_DEBUG

L["Notification"] = {
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

L["Cache"] = {
    ["Reset"] = "Cache reset: %d entries purged and %d max ranks forgotten",
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
    },
    ["Outdated"] = "Outdated version, functionality disabled",
    ["NewVersion"] = "New version available please update to re-enable"
}

L["ChatCommand"] = {
    ["Reset"] = "Settings reset",
    ["Count"] = {
        ["Spells"] = "Spells caught: %d",
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
    ["enable"] = 'Toggles combat log parsing',
    ["whisper"] = 'Toggles whispers to players',
    ["reset"] = 'Resets profile to defaults',
    ["count"] = 'Prints current statistics',
    ["debug"] = 'Toggles debug output for testing',
    ["clear"] = 'Clears local ability caches',
    ["lead"] = 'Sets yourself as lead',
    ["ignore"] = 'Adds current target to addon ignore list, will not report rank errors',
    ["queue"] = 'Prints queued notifications',
    ["queue clear"] = 'Clears queued notifications',
    ["queue process"] = 'Processes queued notifications',
    ["sync"] = 'Broadcast announcement cache',
    ["report [channel]"] = 'Report session data [self, say, party, raid, guild]',
    ["flavor"] = 'List available notification flavors',
    ["flavor [option]"] = 'Set notification flavor to option'
}
