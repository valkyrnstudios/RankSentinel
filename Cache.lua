function SpellSentinel:IgnorePlayer(name)
    local playerGUID = UnitGUID(name)
    self.db.profile.ignoredPlayers[playerGUID] = true;
end

function SpellSentinel:CountCache(cache)
    local count = 0;
    for _ in pairs(cache) do count = count + 1 end

    return count;
end

function SpellSentinel:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells);
    local playerCount = self:CountCache(self.db.profile.ignoredPlayers);

    self.db.profile.announcedSpells = {};
    self.db.profile.ignoredPlayers = {};

    self:PrintMessage(string.format(
                          "Cache reset: %d entries purged and %d players unignored",
                          count, playerCount));
end
