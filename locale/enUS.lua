local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

L[addonName] = "Rank Sentinel"
L["Enable"] = _G.ENABLE
L["Whisper"] = _G.WHISPER
L["Debug"] = _G.BINDING_HEADER_DEBUG

L["Notification"] = addon.NotificationTemplates.enUS

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

L["Send outgoing whispers in English"] = "Send outgoing whispers in English"
L["Whisper me about my own low ranks"] = "Whisper me about my own low ranks"
L["Whisper self description"] = "Also whisper you when your own low-rank spells are detected"
L["Test whisper to self"] = "Test whisper to self"
L["Test whisper description"] = "Send yourself a test whisper using the same outgoing notification flow"
L["Local notification"] = "%s used %s (Rank %d)%s, there's a newer rank at level %d."

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
