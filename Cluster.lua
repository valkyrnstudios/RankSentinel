CommPrefix = "spellsentinel"

function SpellSentinel:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= CommPrefix or sender == PlayerName then return end

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
    self:SendCommMessage(CommPrefix, string.format("%s|%s", command, data),
                         "PARTY")
end

function SpellSentinel:ClusterElect()
    local leadName, name = nil, nil;

    -- Default lead to author
    for i = 1, #self.cluster.members do
        name = self.cluster.members[i];

        if name == "Kahira" or name == "Kynura" or name == "Kaytla" then
            leadName = name;
        end
    end

    -- Set lead to lead or first assist found
    if leadName == nil then
        for i = 1, #self.cluster.members do
            name = self.cluster.members[i];

            if UnitIsGroupLeader(name) then
                leadName = name;
                break
            elseif IsInRaid() and UnitIsGroupAssistant(UnitGUID(name)) then
                leadName = name;
                break
            end
        end
    end

    -- Handle if elected lead is not in members, race/stale condition
    if leadName == nil or self.cluster.members[leadName] ~= true then
        -- Fall back to current or newest player as lead
        leadName = PlayerName
    end

    self:ClusterBroadcast("LEAD", leadName);
end

function SpellSentinel:PrintCluster()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
    self:PrintMessage("Cluster members:")

    for i = 1, #self.cluster.members do
        self:PrintMessage(" - " .. self.cluster.members[i]);
    end
end

function SpellSentinel:ClusterReset()
    self.cluster = {members = {PlayerName}, lead = PlayerName}
end
