local _, addon = ...

local fmt = string.format

function addon:OnCommReceived(prefix, message, _, sender)
    if prefix ~= addon._commPrefix or sender == self.playerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    if self.db.profile.debug then
        self:PrintMessage(fmt("OnCommReceived: %s; Sender: %s; Data: %s",
                              command, sender, data));
    end

    if command == 'NOTIFY' then
        self:RecordNotification(sender, data);
    elseif command == 'LEAD' then
        self.cluster.lead = data;

        if self.db.profile.debug then
            self:PrintMessage("Lead taken by " .. data)
        end
    elseif command == 'SYNC' then
        if self.db.profile.announcedSpells[data] ~= true then
            self.db.profile.announcedSpells[data] = true
        end
    else
        if self.session.UnsupportedComm[command] == nil then
            self.session.UnsupportedComm[command] = true
            self:PrintMessage(fmt(self.L["Broadcast"].Unrecognized, command,
                                  sender));
        end
    end
end

function addon:Broadcast(command, data)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    if self.db.profile.debug then
        self:PrintMessage(fmt("Broadcasting %s: %s", command, data));
    end

    self:SendCommMessage(addon._commPrefix, fmt("%s|%s", command, data), "RAID")
end

function addon:PrintLead()
    self:PrintMessage(fmt(self.L["Cluster"].Lead, self.cluster.lead));
end

function addon:RecordNotification(sender, playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    if sender == self.playerName then
        self:Broadcast("NOTIFY", playerSpellIndex);
    end
end

function addon:ResetLead() self.cluster = {lead = self.playerName} end

function addon:SetLead(playerName)
    -- TODO add lead version
    if not self.db.profile.enable or not self.db.profile.whisper or playerName ==
        nil or UnitInBattleground("player") ~= nil then return end

    self:Broadcast("LEAD", playerName);
end

function addon:SyncBroadcast(array, index)
    local batch_size = 10

    if array == nil or index == nil then
        self:PrintMessage(fmt(self.L["Cluster"].Sync,
                              self:CountCache(self.db.profile.announcedSpells)))

        local ordered_announcements = {}
        for k in pairs(self.db.profile.announcedSpells) do
            table.insert(ordered_announcements, k)
        end

        table.sort(ordered_announcements)

        self:SyncBroadcast(ordered_announcements, 1)
    else
        self:PrintMessage(
            fmt(self.L["Cluster"].Batch, index, index + batch_size))

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

function addon:PLAYER_ENTERING_WORLD(...) self:SetLead(self.playerName); end
