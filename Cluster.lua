CommPrefix = "spellsentinel"

function SpellSentinel:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= CommPrefix or sender == PlayerName then return end

    local command, data = strsplit("|", message)
    if not command then return end

    if self.db.profile.debug then
        self:PrintMessage(string.format(
                              "OnCommReceived: %s; Sender: %s; Data: %s",
                              command, sender, data));
    end

    if command == 'JOINED' then
        self:JoinCluster(sender, data);
    elseif command == 'ANNOY' then
        self:RecordAnnoy(data);
    elseif command == 'LEAD' then
        self.cluster.lead = data;

        if self.db.profile.debug then
            self:PrintMessage("Elected to cluster lead: " .. data)
        end
    else
        self:PrintMessage(string.format("Unrecognized comm command: (%s)",
                                        command));
    end
end

function SpellSentinel:JoinCluster(playerName, version)
    if self.cluster.members[playerName] == nil then
        self.cluster.members[playerName] = version;
    end

    self:ClusterBroadcast("JOINED", string.format("%s,%s", playerName, version));
end

function SpellSentinel:RecordAnnoy(playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    self:ClusterBroadcast("ANNOY", playerSpellIndex);
end

function SpellSentinel:ClusterBroadcast(command, data)
    self:SendCommMessage(CommPrefix, string.format("%s|%s", command, data),
                         "RAID")
end

function SpellSentinel:ClusterElect()
    local leadName = nil;

    if self.db.profile.debug then
        self:PrintMessage("Electing lead from: ")
        for name, version in pairs(self.cluster.members) do
            self:PrintMessage(string.format(" - %s (%s)", name, version));
        end
    end

    -- Default lead to devs
    for name, _ in pairs(self.cluster.members) do
        if name == "Kahira" or name == "Kynura" or name == "Kaytla" then
            leadName = name;
            break
        end
    end

    -- TODO Set lead to lead to latest version

    -- Set lead to lead or first assist found
    if leadName == nil then
        for name, _ in pairs(self.cluster.members) do
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
    if leadName == nil or self.cluster.members[leadName] == nil then
        -- Fall back to current or newest player as lead
        leadName = PlayerName
    end

    self:ClusterBroadcast("LEAD", leadName);
end

function SpellSentinel:PrintCluster()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
    self:PrintMessage("Cluster members:")

    for name, version in pairs(self.cluster.members) do
        self:PrintMessage(string.format(" - %s (%s)", name, version));
    end
end

function SpellSentinel:ClusterReset()
    self.cluster = {members = {[PlayerName] = self.Version}, lead = PlayerName}
end
