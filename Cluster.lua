local _, RankSentinel = ...

function RankSentinel:OnCommReceived(prefix, message, _, sender)
    if prefix ~= RankSentinel._commPrefix or sender == self.playerName then
        return
    end

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

function RankSentinel:RecordAnnoy(sender, playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    if sender == self.playerName then
        self:Broadcast("ANNOY", playerSpellIndex);
    end
end

function RankSentinel:Broadcast(command, data)
    if self.db.profile.debug then
        self:PrintMessage(string.format("Broadcasting %s: %s", command, data));
    end

    self:SendCommMessage(RankSentinel._commPrefix,
                         string.format("%s|%s", command, data), "RAID")
end

function RankSentinel:SetLead(playerName)
    -- TODO add lead version
    if not self.db.profile.enable or not self.db.profile.whisper or playerName ==
        nil or UnitInBattleground("player") ~= nil then return end

    self:Broadcast("LEAD", playerName);
end

function RankSentinel:PrintLead()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
end

function RankSentinel:ResetLead() self.cluster = {lead = self.playerName} end

function RankSentinel:SyncBroadcast()
    self:PrintMessage(string.format("Broadcasting sync %d", self:CountCache(
                                        self.db.profile.announcedSpells)))

    for key, _ in pairs(self.db.profile.announcedSpells) do
        if self.db.profile.debug then
            self:PrintMessage("Broadcasting " .. key)
        end
        self:SendCommMessage(RankSentinel._commPrefix,
                             string.format("%s|%s", 'SYNC', key), "RAID", "BULK")
    end
end
