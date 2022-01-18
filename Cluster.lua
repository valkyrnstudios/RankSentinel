local _, addon = ...

function addon:OnCommReceived(prefix, message, _, sender)
    if prefix ~= addon._commPrefix or sender == self.playerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    if self.db.profile.debug then
        self:PrintMessage(string.format(
                              "OnCommReceived: %s; Sender: %s; Data: %s",
                              command, sender, data));
    end

    if command == 'ANNOY' then
        self:RecordAnnoy(sender, data);
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
        if self.unsupportedCommCache[command] == nil then
            self.unsupportedCommCache[command] = true
            self:PrintMessage(string.format(
                                  "Unrecognized broadcast (%s), you or %s's client may be outdated",
                                  command, sender));
        end
    end
end

function addon:Broadcast(command, data)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    if self.db.profile.debug then
        self:PrintMessage(string.format("Broadcasting %s: %s", command, data));
    end

    self:SendCommMessage(addon._commPrefix,
                         string.format("%s|%s", command, data), "RAID")
end

function addon:PrintLead()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
end

function addon:RecordAnnoy(sender, playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    if sender == self.playerName then
        self:Broadcast("ANNOY", playerSpellIndex);
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
        self:PrintMessage(string.format("Broadcasting sync %d", self:CountCache(
                                            self.db.profile.announcedSpells)))

        local ordered_announcements = {}
        for k in pairs(self.db.profile.announcedSpells) do
            table.insert(ordered_announcements, k)
        end

        table.sort(ordered_announcements)

        self:SyncBroadcast(ordered_announcements, 1)
    else
        self:PrintMessage(string.format("Syncing batch %d to %d", index,
                                        index + batch_size))

        for i = index, index + batch_size do
            if array[i] == nil then return end

            if self.db.profile.debug then
                print(string.format("Sending %d - %s", i, array[i]))
            end

            self:SendCommMessage(addon._commPrefix,
                                 string.format("%s|%s", 'SYNC', array[i]),
                                 "RAID", "BULK")
        end

        C_Timer.After(3, function()
            self:SyncBroadcast(array, index + batch_size)
        end)
    end
end

function addon:PLAYER_ENTERING_WORLD(...) self:SetLead(self.playerName); end
