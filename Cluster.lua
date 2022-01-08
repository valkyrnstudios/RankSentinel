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
        self:RecordAnnoy(sender, data);
    else
        self:PrintMessage(string.format("Unrecognized comm command: (%s)",
                                        command));
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

function RankSentinel:SyncCache() end
