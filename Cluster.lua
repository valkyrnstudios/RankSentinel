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

function RankSentinel:JoinCluster(name, version)
    if self.cluster.members[name] == nil then
        self.cluster.members[name] = version;
    end

    self:ClusterBroadcast("JOINED", string.format("%s,%s", name, version));
end

function RankSentinel:RecordAnnoy(playerSpellIndex)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= true then
        self.db.profile.announcedSpells[playerSpellIndex] = true
    end

    self:ClusterBroadcast("ANNOY", playerSpellIndex);
end

function RankSentinel:ClusterBroadcast(command, data)
    self:SendCommMessage(RankSentinel._commPrefix,
                         string.format("%s|%s", command, data), "RAID")
end

function RankSentinel:ClusterElect()
    local leadName = nil;

    if self.db.profile.debug then
        self:PrintMessage("Electing lead from: ")
        for name, version in pairs(self.cluster.members) do
            self:PrintMessage(string.format(" - %s (%s)", name, version));
        end
    end

    -- Elect local dev clone
    if self.Version == 'v9.9.9' then leadName = self.playerName; end

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
        leadName = self.playerName
    end

    self:ClusterBroadcast("LEAD", leadName);
end

function RankSentinel:PrintCluster()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
    self:PrintMessage("Cluster members:")

    for name, version in pairs(self.cluster.members) do
        self:PrintMessage(string.format(" - %s (%s)", name, version));
    end
end

function RankSentinel:ClusterReset()
    self.cluster = {
        members = {[self.playerName] = self.Version},
        lead = self.playerName
    }
end
