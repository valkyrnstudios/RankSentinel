CommPrefix = "spellsentinel"

function SpellSentinel:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= CommPrefix then return end
    if sender == PlayerName then return end

    local command, data = strsplit("|", message)

    self:PrintMessage(string.format("OnCommReceived: %s; Sender: %s; Data: %s",
                                    command, sender, data));

    if not command then return end

    -- if distribution == "WHISPER" then
    -- elseif distribution == "RAID" or distribution == "PARTY" or distribution ==
    --    "INSTANCE_CHAT" then
    -- end

    if command == 'JOINED' then
        self:JoinCluster(PlayerName);
    elseif command == 'DETECTED' then
        self:SendCommMessage(CommPrefix, "DETECTED", "WHISPER", sender)
    elseif command == 'ANNOY' then
        self:SendCommMessage(CommPrefix, "ANNOY", "WHISPER", sender)
    else
        self:PrintMessage(string.format("Unrecognized comm command: (%s)",
                                        command));
    end
end

function SpellSentinel:JoinCluster(playerName)
    if self.cluster.members[playerName] ~= true then
        self.cluster.members[playerName] = true;
    end

    if IsInRaid() then
        self:SendCommMessage(CommPrefix, "JOINED|" .. playerName, "RAID")
    elseif IsInGroup() then
        self:SendCommMessage(CommPrefix, "JOINED|" .. playerName, "PARTY")
    end
end

function SpellSentinel:ConfigureCluster()
    -- Join all
    -- Elect
    for name, _ in pairs(self.cluster.members) do
        if name == "Kahira" or name == "Kynura" or name == "Kaytla" then
            ClusterLead = name
            return
        end
    end

end

function SpellSentinel:PrintCluster()
    self:PrintMessage("Cluster Lead: " .. self.cluster.lead);
    self:PrintMessage("Cluster members:")

    for i = 1, #self.cluster.members do
        self:PrintMessage("-" .. self.cluster.members[i]);
    end
end
