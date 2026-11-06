local _, addon = ...

local pairs, InCombatLockdown, UnitIsDeadOrGhost, UnitAffectingCombat, SendChatMessage = pairs, InCombatLockdown,
                                                                                         UnitIsDeadOrGhost,
                                                                                         UnitAffectingCombat,
                                                                                         SendChatMessage

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
    local debug = self.db.profile.debug

    if #self.session.Queue == 0 then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        if debug then
            self:PrintMessage("Notifications held (%d queued): %s", #self.session.Queue,
                              InCombatLockdown() and "you are in combat" or "you are dead")
        end
        return
    end

    local notification = nil
    local retry = {}

    for i = 1, #self.session.Queue do
        notification = self.session.Queue[i]

        if notification.target == self.playerName then
            if debug then self:PrintMessage("Notify %s: self (print to chat)", notification.target) end
            self:PrintMessage(notification.message)
        elseif self.playerName == self.cluster.lead and self.db.profile.whisper then
            if UnitAffectingCombat(notification.target) then
                if debug then self:PrintMessage("Whisper to %s delayed: target is in combat, retrying", notification.target) end
                retry[#retry + 1] = notification
            else
                if debug then
                    self:PrintMessage("Whispering %s (%s): %s", (self.session.FullNames and self.session.FullNames[notification.target]) or notification.target, notification.ability,
                                      notification.message)
                end
                local whisperTarget = self.session.FullNames and self.session.FullNames[notification.target] or
                                          notification.target
                local ok, err = pcall(SendChatMessage, notification.message, "WHISPER", nil, whisperTarget)
                if debug then
                    self:PrintMessage("Whisper to %s %s%s", whisperTarget, ok and "sent" or "FAILED: ",
                                      ok and "" or tostring(err))
                end
            end
        elseif self.playerName ~= self.cluster.lead then
            if debug then
                self:PrintMessage("No whisper to %s: you are not the lead (lead is %s)", notification.target,
                                  tostring(self.cluster.lead))
            end
            if not self.db.profile.quietMode then
                self:PrintMessage("(%s) %s - %s", self.cluster.lead, notification.target, notification.ability)
            end
        else
            if debug then self:PrintMessage("No whisper to %s: whispering is turned off", notification.target) end
            if not self.db.profile.quietMode then
                self:PrintMessage("%s - %s", notification.target, notification.ability)
            end
        end
    end

    self.session.Queue = retry
end

function addon:QueueNotification(message, target, ability)
    self.session.Queue[#self.session.Queue + 1] = {message = message, target = target, ability = ability}

    if InCombatLockdown() and self.playerName == self.cluster.lead then
        if not self.db.profile.quietMode then
            self:PrintMessage(self.L["Cache"].Queue, target, ability)
        end
    else
        self:ProcessQueuedNotifications()
    end
end

function addon:UpdateSessionReport(playerSpellIndex, playerName, spellName, spellID)
    if self.session.Report[playerSpellIndex] ~= nil then return end

    local spellRank = addon.AbilityData[spellID].Rank

    self.session.Report[playerSpellIndex] = {
        ['PlayerName'] = playerName,
        ['SpellName'] = spellName,
        ['SpellRank'] = spellRank
    }
end
