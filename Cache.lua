local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells);
    local playerCount = self:CountCache(self.db.profile.ignoredPlayers);
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank);

    self.db.profile.announcedSpells = {};
    self.db.profile.ignoredPlayers = {};
    self.db.profile.isMaxRank = {};
    self.db.profile.petOwnerCache = {};

    self:PrintMessage(string.format(
                          "Cache reset: %d entries purged, %d players unignored, and %d cached results",
                          count, playerCount, isMaxRankCount));
end

function addon:CountCache(cache)
    local count = 0;
    for _ in pairs(cache) do count = count + 1 end

    return count;
end

function addon:ProcessQueuedNotifications()
    if #self.notificationsQueue == 0 then return end

    self:PrintMessage(string.format(L["Queue"]["Processing"],
                                    #self.notificationsQueue));

    local notification = nil;

    for i = 1, #self.notificationsQueue do
        notification = self.notificationsQueue[i];

        SendChatMessage(notification.text, "WHISPER", nil, notification.target)
    end

    self.notificationsQueue = {};
end

function addon:QueueNotification(notification, target)
    if InCombatLockdown() and not self.db.profile.combat then
        self:PrintMessage(string.format("Queued - %s, %s", target,
                                        notification:gsub('{rt7} ', '', 1)));

        self.notificationsQueue[#self.notificationsQueue + 1] = {
            text = notification,
            target = target
        };
    else
        SendChatMessage(notification, "WHISPER", nil, target)
    end
end

function addon:UpdateSessionReport(playerSpellIndex, playerName, spellName,
                                   spellID)

    if self.sessionReport[playerSpellIndex] ~= nil then return end

    local spellRank = addon.AbilityData[spellID].Rank

    self.sessionReport[playerSpellIndex] = {
        ['PlayerName'] = playerName,
        ['SpellName'] = spellName,
        ['SpellRank'] = spellRank
    }
end
