local _, addon = ...

local fmt = string.format

function addon:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells);
    local petCount = self:CountCache(self.db.profile.petOwnerCache);
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank);

    self.db.profile.announcedSpells = {};
    self.db.profile.isMaxRank = {};
    self.db.profile.petOwnerCache = {};
    self.session = {
        Queue = {},
        Report = {},
        UnsupportedComm = {},
        PlayersNotified = {}
    }

    self:PrintMessage(
        fmt(self.L["Cache"].Reset, count, isMaxRankCount, petCount));
end

function addon:CountCache(cache)
    local count = 0;
    for _ in pairs(cache) do count = count + 1 end

    return count;
end

function addon:ProcessQueuedNotifications()
    if #self.session.Queue == 0 or InCombatLockdown() then return end

    local notification = nil;

    for i = 1, #self.session.Queue do
        notification = self.session.Queue[i];

        if notification.target ~= self.playerName then
            SendChatMessage(notification.message, "WHISPER", nil,
                            notification.target)
        else
            self:PrintMessage(notification.message)
        end
    end

    self.session.Queue = {};
end

function addon:QueueNotification(message, target, ability)
    self.session.Queue[#self.session.Queue + 1] = {
        message = message,
        target = target,
        ability = ability
    };

    if InCombatLockdown() then
        self:PrintMessage(fmt(self.L["Cache"].Queue, target, ability))
    else
        self:ProcessQueuedNotifications()
    end
end

function addon:UpdateSessionReport(playerSpellIndex, playerName, spellName,
                                   spellID)

    if self.session.Report[playerSpellIndex] ~= nil then return end

    local spellRank = addon.AbilityData[spellID].Rank

    self.session.Report[playerSpellIndex] = {
        ['PlayerName'] = playerName,
        ['SpellName'] = spellName,
        ['SpellRank'] = spellRank
    }
end
