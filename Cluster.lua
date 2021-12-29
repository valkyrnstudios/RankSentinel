local _, RankSentinel = ...

function RankSentinel:OnCommReceived(prefix, message, distribution, sender)
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
        self:RecordAnnoy(data);
    elseif command == 'LEAD' then
        self.cluster.lead = data;

        if self.db.profile.debug then
            self:PrintMessage("Elected to lead: " .. data)
        end
    else
        self:PrintMessage(string.format("Unrecognized comm command: (%s)",
                                        command));
    end
end

function RankSentinel:RecordAnnoy(playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    self:Broadcast("ANNOY", playerSpellIndex);
end

function RankSentinel:Broadcast(command, data)
    if self.db.profile.debug then
        self:PrintMessage(string.format("Broadcasting %s: %s", command, data));
    end

    self:SendCommMessage(RankSentinel._commPrefix,
                         string.format("%s|%s", command, data), "RAID")
end

function RankSentinel:ElectLead(playerName)
    local leadName = playerName;

    if self.Version == 'v9.9.9' or playerName == nil then
        leadName = self.playerName;
    end

    self:Broadcast("LEAD", leadName);
end

function RankSentinel:PrintLead()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
end

function RankSentinel:ResetLead() self.cluster = {lead = self.playerName} end
