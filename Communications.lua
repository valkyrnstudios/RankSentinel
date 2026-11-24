local addonName, addon = ...

local fmt, smatch, strsplit, tsort, tinsert = string.format, string.match, strsplit, table.sort, table.insert
local UnitInBattleground = UnitInBattleground
local InCombatLockdown, UnitIsDeadOrGhost, UnitAffectingCombat = InCombatLockdown, UnitIsDeadOrGhost, UnitAffectingCombat
local SendChatMessage, GetSpellLink = SendChatMessage, GetSpellLink

local prefix = string.upper(addonName)

addon.comms = {cluster = {lead = addon.playerName}}

function addon.comms:Setup()
    addon:RegisterComm(prefix, function(...) self:OnCommReceived(...) end)

    if not addon.db.profile.isLatestVersion then return end

    addon:RegisterEvent("PLAYER_ENTERING_WORLD", self.PLAYER_ENTERING_WORLD, self)
    addon:RegisterEvent("GROUP_LEFT", self.GROUP_LEFT, self)
    addon:RegisterEvent("GROUP_JOINED", self.GROUP_JOINED, self)
    addon:RegisterEvent("GROUP_ROSTER_UPDATE", self.GROUP_ROSTER_UPDATE, self)
    addon:RegisterEvent("PLAYER_UNGHOST", self.ScheduleQueueProcessing, self)
    addon:RegisterEvent("PLAYER_ALIVE", self.ScheduleQueueProcessing, self)

    self:ResetLead()
end

function addon.comms:ScheduleQueueProcessing()
    C_Timer.After(5, function() self:ProcessQueuedNotifications() end)
end

function addon.comms:ShouldWhisper()
    local profile = addon.db.profile
    return profile.enable and profile.whisper and profile.isLatestVersion and UnitInBattleground("player") == nil
end

function addon.comms:OnCommReceived(receivedPrefix, message, _, sender)
    if receivedPrefix ~= prefix or sender == addon.playerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    if addon.db.profile.debug then
        addon:PrintMessage("OnCommReceived: %s; Sender: %s; Data: %s", command, sender, data)
    end

    if command == 'NOTIFY' then
        self:RecordNotification(sender, data)
    elseif command == 'LEAD' then
        local name, intVersion = strsplit(",", data)
        self.cluster.lead = name

        if self.clusterJoinPending then
            self.clusterJoinPending = nil
            self:PrintLead()
        end

        if name == addon.playerName then return end

        self:CheckRelease(intVersion, name)

        if addon.db.profile.debug or addon.Version == 'v9.9.9' then addon:PrintMessage("Lead taken by " .. name) end
    elseif command == 'JOIN' then
        local name, intVersion = strsplit(",", data)

        self:CheckRelease(intVersion, name)

        addon:SendCommMessage(prefix, fmt('LEAD|%s,%d', self.cluster.lead, self.release.int), "WHISPER",
                             sender)
    elseif command == 'SYNC' then
        if addon.db.profile.announcedSpells[data] ~= true then addon.db.profile.announcedSpells[data] = true end
    else
        if addon.session.UnsupportedComm[command] == nil then
            addon.session.UnsupportedComm[command] = true
            addon:PrintMessage(addon.L["Broadcast"].Unrecognized, command, sender)
        end
    end
end

function addon.comms:Broadcast(command, data)
    if not addon.db.profile.enable or UnitInBattleground("player") ~= nil then return end

    if addon.db.profile.debug then addon:PrintMessage("Broadcasting %s: %s", command, data) end

    addon:SendCommMessage(prefix, fmt("%s|%s", command, data), "RAID")
end

function addon.comms:PrintLead() addon:PrintMessage(addon.L["Cluster"].Lead, self.cluster.lead) end

function addon.comms:RecordNotification(sender, playerSpellIndex)
    if addon.db.profile.announcedSpells[playerSpellIndex] ~= true then
        addon.db.profile.announcedSpells[playerSpellIndex] = true
    end

    if sender == addon.playerName then self:Broadcast("NOTIFY", playerSpellIndex) end
end

function addon.comms:ResetLead()
    self.cluster = {lead = addon.playerName}
    self.clusterJoinPending = nil
end

function addon.comms:BroadcastJoin()
    self:Broadcast("JOIN", fmt("%s,%d", addon.playerName, self.release.int))
end

function addon.comms:BroadcastLead(playerName)
    if not playerName or not self:ShouldWhisper() then return end

    self:Broadcast('LEAD', fmt('%s,%d', playerName, self.release.int))
end

function addon.comms:SyncBroadcast(array, index)
    local batch_size = 10

    if array == nil or index == nil then
        addon:PrintMessage(addon.L["Cluster"].Sync, addon:CountCache(addon.db.profile.announcedSpells))

        local ordered_announcements = {}
        for k in pairs(addon.db.profile.announcedSpells) do tinsert(ordered_announcements, k) end

        tsort(ordered_announcements)

        self:SyncBroadcast(ordered_announcements, 1)
    else
        addon:PrintMessage(addon.L["Cluster"].Batch, index, index + batch_size)

        for i = index, index + batch_size do
            if array[i] == nil then return end

            if addon.db.profile.debug then print(fmt("Sending %d - %s", i, array[i])) end

            addon:SendCommMessage(prefix, fmt("%s|%s", 'SYNC', array[i]), "RAID", "BULK")
        end

        C_Timer.After(3, function() self:SyncBroadcast(array, index + batch_size) end)
    end
end

function addon.comms:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    if not isInitialLogin and not isReloadingUi then return end

    local major, minor, patch = smatch(addon.Version, "v(%d+)%.(%d+)%.(%d+)")

    self.release = {major = major, minor = minor, patch = patch, int = tonumber(fmt('%d%d%d', major, minor, patch))}

    if isReloadingUi then
        self.clusterJoinPending = true
        self:BroadcastJoin()
    else
        self:BroadcastLead(addon.playerName)
    end
end

function addon.comms:GROUP_LEFT()
    self:BroadcastLead(addon.playerName)
    addon:InitializeSession()
end

function addon.comms:GROUP_JOINED()
    -- TODO delay, happens too early
    self:BroadcastJoin()
    addon:InitializeSession()
end

function addon.comms:GROUP_ROSTER_UPDATE()
    if not addon:IsLeaderInGroup(self.cluster.lead) then
        if addon.db.profile.debug or addon.Version == 'v9.9.9' then
            addon:PrintMessage('Leader not in group, resetting')
        end

        self.cluster.lead = addon.playerName
        self:BroadcastLead(addon.playerName)
    end
end

function addon.comms:CheckRelease(theirIntRelease, name)
    theirIntRelease = tonumber(theirIntRelease)
    if addon.db.profile.debug or addon.Version == 'v9.9.9' then
        addon:PrintMessage("%s:theirIntRelease = %s", name, theirIntRelease or 'nil')
    end

    -- Treat Development announcements as equal to current
    if theirIntRelease == 999 or addon.Version == 'v9.9.9' or not theirIntRelease then return end

    -- Failed to parse version or older version
    if self.release.int == 0 or theirIntRelease == 0 then return end

    if self.release.int < theirIntRelease then
        addon:PrintMessage(addon.L["Utilities"]["NewVersion"])
        return true
    end
end

function addon.comms:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel, petOwner)
    local spellLink = GetSpellLink(spellID)
    local abilityData = addon.AbilityData[spellID]
    local contactName = petOwner and petOwner.OwnerName or sourceName
    local by = petOwner and fmt(addon.notifications.By, sourceName) or ''
    local msg = nil
    local sourceUID = addon:GetUID(sourceGUID)

    if addon.db.profile.notificationFlavor == 'random' then addon.notifications = addon:GetRandomNotificationFlavor() end

    if sourceGUID == addon.playerGUID then
        msg = fmt(addon.notifications.Base, spellLink, abilityData.Rank, by, nextRankLevel)

        msg = fmt("%s %s", addon.notifications.Prefix.Self, msg)

    elseif addon.playerName == self.cluster.lead and self:ShouldWhisper() then
        msg = fmt(addon.notifications.Base, spellLink, abilityData.Rank, by, nextRankLevel)

        if addon.session.PlayersNotified[sourceUID] == true or petOwner then
            msg = fmt("%s %s", addon.notifications.Prefix.Whisper, msg)
        else
            msg = fmt("%s %s %s", addon.notifications.Prefix.Whisper, msg, addon.notifications.Suffix)
        end
    else
        msg = fmt(addon.notifications.Base, sourceName, spellLink, abilityData.Rank, by, nextRankLevel)

        msg = fmt("%s %s", addon.notifications.Prefix.Self, msg)
    end

    addon.session.PlayersNotified[sourceUID] = true

    return msg, contactName, fmt('%s (Rank %d)', spellLink, abilityData.Rank)
end

function addon.comms:ProcessQueuedNotifications()
    if #addon.session.Queue == 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then return end

    local notification = nil
    local retry = {}

    for i = 1, #addon.session.Queue do
        notification = addon.session.Queue[i]

        if notification.target == addon.playerName then
            addon:PrintMessage(notification.message)
        elseif addon.playerName == self.cluster.lead and self:ShouldWhisper() then
            if UnitAffectingCombat(notification.target) then
                retry[#retry + 1] = notification
            else
                SendChatMessage(notification.message, "WHISPER", nil, notification.target)
            end
        elseif addon.playerName ~= self.cluster.lead then
            if not addon.db.profile.quietMode then
                addon:PrintMessage("(%s) %s - %s", self.cluster.lead, notification.target, notification.ability)
            end
        else
            if not addon.db.profile.quietMode then
                addon:PrintMessage("%s - %s", notification.target, notification.ability)
            end
        end
    end

    addon.session.Queue = retry
end

function addon.comms:QueueNotification(message, target, ability)
    addon.session.Queue[#addon.session.Queue + 1] = {message = message, target = target, ability = ability}

    if InCombatLockdown() and addon.playerName == self.cluster.lead then
        if not addon.db.profile.quietMode then
            addon:PrintMessage(addon.L["Cache"].Queue, target, ability)
        end
    else
        self:ProcessQueuedNotifications()
    end
end

function addon.comms:UpdateSessionReport(playerSpellIndex, playerName, spellName, spellID)
    if addon.session.Report[playerSpellIndex] ~= nil then return end

    local spellRank = addon.AbilityData[spellID].Rank

    addon.session.Report[playerSpellIndex] = {
        ['PlayerName'] = playerName,
        ['SpellName'] = spellName,
        ['SpellRank'] = spellRank
    }
end

function addon.comms:ReportToChannel(channel)
    local reportSize = addon:CountCache(addon.session.Report)

    if channel == nil or channel == "self" then
        addon:PrintMessage(addon.L["ChatCommand"].Report.Header, '', reportSize)

        for _, reportEntry in pairs(addon.session.Report) do
            print(fmt(addon.L["ChatCommand"].Report.Summary, reportEntry.PlayerName, reportEntry.SpellName,
                      reportEntry.SpellRank))
        end
    elseif channel == "say" or channel == "party" or channel == "raid" or channel == "guild" then
        SendChatMessage(fmt(addon.L["ChatCommand"].Report.Header, addon.L[addonName] .. ': ', reportSize), channel, nil)

        for key, reportEntry in pairs(addon.session.Report) do
            SendChatMessage(fmt(addon.L["ChatCommand"].Report.Summary, reportEntry.PlayerName, reportEntry.SpellName,
                                reportEntry.SpellRank), channel, nil)
            -- Remove entry after announcing to channel
            addon.session.Report[key] = nil
        end
    end
end
