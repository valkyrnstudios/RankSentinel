CommPrefix = "spellsentinel"

function SpellSentinel:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= CommPrefix then return end
    if sender == PlayerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    self:PrintMessage(string.format("OnCommReceived: %s; Sender: %s; Data: %s",
                                    command, sender, data));

    if command == 'JOINED' then
        self:JoinCluster(sender);
    elseif command == 'ANNOY' then
        self:RecordAnnoy(data);
    elseif command == 'LEAD' then
        self.cluster.lead = data;
        self:PrintMessage("Elected to cluster lead: " .. data);
    else
        self:PrintMessage(string.format("Unrecognized comm command: (%s)",
                                        command));
    end
end

function SpellSentinel:JoinCluster(playerName)
    if self.cluster.members[playerName] ~= true then
        self.cluster.members[playerName] = true;
    end

    self:ClusterBroadcast("JOINED", playerName);
end

function SpellSentinel:RecordAnnoy(playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    self:ClusterBroadcast("ANNOY", playerSpellIndex);
end

function SpellSentinel:ClusterBroadcast(command, data)
    local commandString = string.format("%s|%s", command, data);
    if IsInRaid() then
        self:SendCommMessage(CommPrefix, commandString, "RAID")
    elseif IsInGroup() then
        self:SendCommMessage(CommPrefix, commandString, "PARTY")
    end
end

function SpellSentinel:ClusterElect()
    local leadName = nil;

    for name, _ in pairs(self.cluster.members) do
        if name == "Kahira" or name == "Kynura" or name == "Kaytla" then
            leadName = name
        end
    end

    if leadName == nil then
        for name, _ in pairs(self.cluster.members) do
            if IsInRaid() and UnitIsGroupAssistant(name) then
                leadName = name
                break
            elseif UnitIsGroupLeader(name) then
                leadName = name
                break
            end
        end
    end

    if leadName == nil then leadName = PlayerName end

    ClusterLead = leadName
    self:ClusterBroadcast("LEAD", leadName)
end

function SpellSentinel:PrintCluster()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
    self:PrintMessage("Cluster members:")

    for i = 1, #self.cluster.members do
        self:PrintMessage(" - " .. self.cluster.members[i]);
    end
end
