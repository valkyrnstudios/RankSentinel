local addonName, RankSentinel = ...
function RankSentinel:IgnorePlayer(name)
    local guid = UnitGUID(name)
    self.db.profile.ignoredPlayers[guid] = true;
end

function RankSentinel:CountCache(cache)
    local count = 0;
    for _ in pairs(cache) do count = count + 1 end

    return count;
end

function RankSentinel:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells);
    local playerCount = self:CountCache(self.db.profile.ignoredPlayers);
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank);

    self.db.profile.announcedSpells = {};
    self.db.profile.ignoredPlayers = {};
    self.db.profile.isMaxRank = {};

    self:PrintMessage(string.format(
                          "Cache reset: %d entries purged, %d players unignored, and %d cached results",
                          count, playerCount, isMaxRankCount));
end
