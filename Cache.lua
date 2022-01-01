local _, addon = ...

function addon:IgnoreTarget()
    local guid = UnitGUID("target")
    if not guid then
        self:PrintMessage("Must target a unit");
        return;
    end

    local name, _ = UnitName("target");

    if self.db.profile.ignoredPlayers[guid] ~= true then
        self:PrintMessage("Ignored " .. name);
        self.db.profile.ignoredPlayers[guid] = true;
    else
        self:PrintMessage("Unignored " .. name);
        self.db.profile.ignoredPlayers[guid] = nil;
    end
end

function addon:CountCache(cache)
    local count = 0;
    for _ in pairs(cache) do count = count + 1 end

    return count;
end

function addon:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells);
    local playerCount = self:CountCache(self.db.profile.ignoredPlayers);
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank);

    self.db.profile.announcedSpells = {};
    self.db.profile.ignoredPlayers = {};
    self.db.profile.isMaxRank = {};
    self.db.profile.petOwnerCache = {};

    self:PrintMessage(string.format(
                          "Cache reset: %d entries purged, %d players unignored, and %d cached results",
                          count, playerCount, isMaxRankCount));
end
