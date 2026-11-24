local addonName, addon = ...

local fmt, smatch, tsort, tinsert = string.format, string.match, table.sort, table.insert
local strsplit = _G.strsplit
local UnitInBattleground = _G.UnitInBattleground
local InCombatLockdown, UnitIsDeadOrGhost = _G.InCombatLockdown, _G.UnitIsDeadOrGhost
local UnitAffectingCombat = _G.UnitAffectingCombat
local SendChatMessage = _G.SendChatMessage
local GetSpellLink = _G.GetSpellLink or (_G.C_Spell and _G.C_Spell.GetSpellLink)
local GetSpellName = _G.C_Spell and _G.C_Spell.GetSpellName
local GetPreferredPlaySettings = _G.C_AccountServices and _G.C_AccountServices.GetPreferredPlaySettings
local After = _G.C_Timer.After
local wipe = _G.wipe

local prefix = string.upper(addonName)

local onlineLocales = {[4] = "frFR", [13] = "ruRU"}

addon.comms = {cluster = {lead = addon.playerName}}

function addon.comms:OnCommReceived(receivedPrefix, message, _, sender)
    if receivedPrefix ~= prefix or sender == addon.playerName then return end

    local command, data = strsplit("|", message)
    if not command or not data or data == "" then return end

    if addon.db.profile.debug then
        addon:PrintMessage("OnCommReceived: %s; Sender: %s; Data: %s", command, sender, data)
    end

    if command == 'NOTIFY' then
        self:RecordNotification(sender, data)
    elseif command == 'LEAD' then
        local name, intVersion = strsplit(",", data)
        if not name or name == "" or not tonumber(intVersion) then return end
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
        if not name or name == "" or not tonumber(intVersion) then return end
        self:CheckRelease(intVersion, name)

        addon:SendCommMessage(prefix, fmt('LEAD|%s,%d', self.cluster.lead, self.releaseVersion), "WHISPER", sender)
    elseif command == 'SYNC' then
        addon.db.profile.announcedSpells[data] = true
    elseif not addon.session.UnsupportedComm[command] then
        addon.session.UnsupportedComm[command] = true
        addon:PrintMessage(addon.L["Broadcast"].Unrecognized, command, sender)
    end
end

function addon.comms:Broadcast(command, data)
    if not addon.db.profile.enable or UnitInBattleground("player") ~= nil then return end

    if addon.db.profile.debug then addon:PrintMessage("Broadcasting %s: %s", command, data) end

    addon:SendCommMessage(prefix, fmt("%s|%s", command, data), "RAID")
end

function addon.comms:PrintLead() addon:PrintMessage(addon.L["Cluster"].Lead, self.cluster.lead) end

function addon.comms:RecordNotification(sender, playerSpellIndex)
    addon.db.profile.announcedSpells[playerSpellIndex] = true
    if sender == addon.playerName then self:Broadcast("NOTIFY", playerSpellIndex) end
end

function addon.comms:ResetLead()
    self.cluster.lead = addon.playerName
    self.clusterJoinPending = nil
end

function addon.comms:BroadcastJoin()
    self:Broadcast("JOIN", fmt("%s,%d", addon.playerName, self.releaseVersion))
end

function addon.comms:BroadcastLead(playerName)
    if not playerName or not self:ShouldWhisper() then return end

    self:Broadcast('LEAD', fmt('%s,%d', playerName, self.releaseVersion))
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

        After(3, function() self:SyncBroadcast(array, index + batch_size) end)
    end
end

function addon.comms:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    if not isInitialLogin and not isReloadingUi then return end

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
    local meter = addon.parser.damageMeter
    if meter.ticker then wipe(meter.sessions) end

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

function addon.comms:Setup()
    local major, minor, patch = smatch(addon.Version, "v(%d+)%.(%d+)%.(%d+)")
    self.releaseVersion = major and tonumber(major .. minor .. patch) or 0
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

function addon.comms:CheckRelease(theirIntRelease, name)
    theirIntRelease = tonumber(theirIntRelease)
    if addon.db.profile.debug or addon.Version == 'v9.9.9' then
        addon:PrintMessage("%s:theirIntRelease = %s", name, theirIntRelease or 'nil')
    end

    -- Treat Development announcements as equal to current
    if theirIntRelease == 999 or addon.Version == 'v9.9.9' or not theirIntRelease then return end

    -- Failed to parse version or older version
    if self.releaseVersion == 0 or theirIntRelease == 0 then return end

    if self.releaseVersion < theirIntRelease then
        addon:PrintMessage(addon.L["Utilities"]["NewVersion"])
        return true
    end
end

function addon.comms:ShouldWhisper()
    if addon.playerName ~= self.cluster.lead then return false end
    if addon.InterfaceVersion >= 16000 and addon.InterfaceVersion < 17000 then return false end

    local profile = addon.db.profile
    return profile.enable and profile.whisper and profile.isLatestVersion and UnitInBattleground("player") == nil
end

function addon.comms:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel, petOwner)
    local spellLink = (GetSpellLink and GetSpellLink(spellID)) or tostring(spellID)
    if addon.InterfaceVersion >= 16000 and addon.InterfaceVersion < 17000 then
        local spellName = GetSpellName and GetSpellName(spellID)
        if spellName then
            spellLink = spellLink:gsub("|h%b[]|h", function() return "|h[" .. spellName .. "]|h" end, 1)
        end
    end
    local rank = addon.AbilityData[spellID].Rank
    local contactName = petOwner and petOwner.OwnerName or sourceName
    local sourceUID = addon:GetUID(sourceGUID)
    local profile = addon.db.profile
    local whisper = sourceGUID ~= addon.playerGUID and self:ShouldWhisper()
    local notifications = addon.L["Notification"]
    if whisper then
        local locale = profile.whisperLanguage
        if locale == "auto" and GetPreferredPlaySettings then
            local loaded, localeID = GetPreferredPlaySettings()
            if loaded then locale = onlineLocales[localeID] end
        end
        notifications = addon.notificationLocales[locale] or addon.notificationLocales.enUS
    end

    local flavorName = profile.notificationFlavor
    local flavor = notifications[flavorName] or notifications.default
    if flavorName == "random" then
        local flavors = {}
        for _, template in pairs(notifications) do
            if template then tinsert(flavors, template) end
        end
        flavor = flavors[math.random(#flavors)]
    end

    local by = petOwner and fmt(flavor.By, sourceName) or ''
    local messagePrefix = whisper and flavor.Prefix.Whisper or flavor.Prefix.Self
    local message = messagePrefix .. " " .. fmt(flavor.Base, spellLink, rank, by, nextRankLevel)
    if whisper and not addon.session.PlayersNotified[sourceUID] and not petOwner then
        message = message .. " " .. flavor.Suffix
    end

    addon.session.PlayersNotified[sourceUID] = true

    return message, contactName, fmt('%s (Rank %d)', spellLink, rank)
end

function addon.comms:ProcessQueuedNotifications()
    local queue = addon.session.Queue
    if #queue == 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then return end

    local isLead = addon.playerName == self.cluster.lead
    local shouldWhisper = self:ShouldWhisper()
    local retry = {}

    for _, notification in ipairs(queue) do

        if notification.target == addon.playerName then
            addon:PrintMessage(notification.message)
        elseif shouldWhisper then
            if UnitAffectingCombat(notification.target) then
                retry[#retry + 1] = notification
            else
                SendChatMessage(notification.message, "WHISPER", nil, notification.target)
            end
        elseif not addon.db.profile.quietMode then
            if isLead then
                addon:PrintMessage("%s - %s", notification.target, notification.ability)
            else
                addon:PrintMessage("(%s) %s - %s", self.cluster.lead, notification.target, notification.ability)
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

function addon.comms:ScheduleQueueProcessing()
    After(5, function() self:ProcessQueuedNotifications() end)
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
