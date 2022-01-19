local _, addon = ...

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
    if #self.notificationsQueue == 0 or InCombatLockdown() then return end

    local notification = nil;

    for i = 1, #self.notificationsQueue do
        notification = self.notificationsQueue[i];

        if notification.target ~= self.playerName then
            SendChatMessage(notification.message, "WHISPER", nil,
                            notification.target)
        else
            self:PrintMessage(notification.message)
        end
    end

    self.notificationsQueue = {};
end

function addon:QueueNotification(message, target, ability)
    self.notificationsQueue[#self.notificationsQueue + 1] = {
        message = message,
        target = target,
        ability = ability
    };

    if InCombatLockdown() then
        self:PrintMessage(string.format("Queued - %s, %s", target, ability))
    else
        self:ProcessQueuedNotifications()
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
