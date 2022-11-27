local _, addon = ...

local pairs, InCombatLockdown, UnitIsDeadOrGhost, UnitAffectingCombat, SendChatMessage = pairs, InCombatLockdown,
    UnitIsDeadOrGhost,
    UnitAffectingCombat, SendChatMessage

function addon:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells)
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank)

    self.db.profile.announcedSpells = {}
    self.db.profile.isMaxRank = {}
    self.db.profile.petOwnerCache = {}

    self:InitializeSession()

    self:PrintMessage(self.L["Cache"].Reset, count, isMaxRankCount)
end

function addon:CountCache(cache)
    local count = 0
    for _ in pairs(cache) do count = count + 1 end

    return count
end

function addon:ProcessQueuedNotifications()
    if #self.session.Queue == 0 or InCombatLockdown() or
        UnitIsDeadOrGhost("player") then return end

    local notification = nil
    local retry = {}

    for i = 1, #self.session.Queue do
        notification = self.session.Queue[i]

        if notification.target == self.playerName then
            self:PrintMessage(notification.message)
        elseif self.playerName == self.cluster.lead and self.db.profile.whisper then
            if UnitAffectingCombat(notification.target) then
                retry[#retry + 1] = notification
            else
                SendChatMessage(notification.message, "WHISPER", nil,
                    notification.target)
            end
        elseif self.playerName ~= self.cluster.lead then
            self:PrintMessage("(%s) %s - %s", self.cluster.lead, notification.target,
                notification.ability)
        else
            self:PrintMessage("%s - %s", notification.target,
                notification.ability)
        end
    end

    self.session.Queue = retry
end

function addon:QueueNotification(message, target, ability)
    self.session.Queue[#self.session.Queue + 1] = {
        message = message,
        target = target,
        ability = ability
    }

    if InCombatLockdown() and self.playerName == self.cluster.lead then
        self:PrintMessage(self.L["Cache"].Queue, target, ability)
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
