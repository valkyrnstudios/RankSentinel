local _, addon = ...

local fmt, smatch, strsplit, tsort, tinsert = string.format, string.match, strsplit, table.sort, table.insert
local UnitInBattleground = UnitInBattleground

function addon:OnCommReceived(prefix, message, _, sender)
    if prefix ~= addon._commPrefix or sender == self.playerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    if self.db.profile.debug then
        self:PrintMessage("OnCommReceived: %s; Sender: %s; Data: %s",
            command, sender, data)
    end

    if command == 'NOTIFY' then
        self:RecordNotification(sender, data)
    elseif command == 'LEAD' then
        self.cluster.lead = data

        if self.db.profile.debug or addon.Version == 'v9.9.9' then
            self:PrintMessage("Lead taken by " .. data)
        end
    elseif command == 'JOIN' then
        self:SendCommMessage(addon._commPrefix, 'LEAD|' .. self.cluster.lead,
            "WHISPER", sender)
    elseif command == 'SYNC' then
        if self.db.profile.announcedSpells[data] ~= true then
            self.db.profile.announcedSpells[data] = true
        end
    else
        if self.session.UnsupportedComm[command] == nil then
            self.session.UnsupportedComm[command] = true
            self:PrintMessage(self.L["Broadcast"].Unrecognized, command,
                sender)
        end
    end
end

function addon:Broadcast(command, data)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    if self.db.profile.debug then
        self:PrintMessage("Broadcasting %s: %s", command, data)
    end

    self:SendCommMessage(addon._commPrefix, fmt("%s|%s", command, data), "RAID")
end

function addon:PrintLead()
    self:PrintMessage(self.L["Cluster"].Lead, self.cluster.lead)
end

function addon:RecordNotification(sender, playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    if sender == self.playerName then
        self:Broadcast("NOTIFY", playerSpellIndex)
    end
end

function addon:ResetLead() self.cluster = { lead = self.playerName } end

function addon:SetLead(playerName)
    -- TODO add lead version
    if not self.db.profile.enable or not self.db.profile.whisper or playerName ==
        nil or UnitInBattleground("player") ~= nil or
        not smatch(addon.Version, 'v%d.%d.%d') then return end

    self:Broadcast("LEAD", playerName)
end

function addon:SyncBroadcast(array, index)
    local batch_size = 10

    if array == nil or index == nil then
        self:PrintMessage(self.L["Cluster"].Sync,
            self:CountCache(self.db.profile.announcedSpells))

        local ordered_announcements = {}
        for k in pairs(self.db.profile.announcedSpells) do
            tinsert(ordered_announcements, k)
        end

        tsort(ordered_announcements)

        self:SyncBroadcast(ordered_announcements, 1)
    else
        self:PrintMessage(self.L["Cluster"].Batch, index, index + batch_size)

        for i = index, index + batch_size do
            if array[i] == nil then return end

            if self.db.profile.debug then
                print(fmt("Sending %d - %s", i, array[i]))
            end

            self:SendCommMessage(addon._commPrefix,
                fmt("%s|%s", 'SYNC', array[i]), "RAID", "BULK")
        end

        C_Timer.After(3, function()
            self:SyncBroadcast(array, index + batch_size)
        end)
    end
end

--TODO optimize, don't flip lead every transition
function addon:PLAYER_ENTERING_WORLD() self:SetLead(self.playerName) end

function addon:GROUP_LEFT()
    self:SetLead(self.playerName)
    self:InitializeSession()
end

function addon:GROUP_JOINED()
    self:Broadcast("JOIN", self.playerName)
    self:InitializeSession()
end

function addon:GROUP_ROSTER_UPDATE()
    if not self:IsLeaderInGroup() then
        if self.db.profile.debug or addon.Version == 'v9.9.9' then
            self:PrintMessage('Leader not in group, resetting')
        end

        self.cluster.lead = self.playerName
        self:SetLead(self.playerName)
    end
end
