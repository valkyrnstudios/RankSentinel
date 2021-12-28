local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:PLAYER_LEVEL_UP(level, ...) self.playerLevel = level; end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, sourceGUID, _, spellID)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    if addon.AbilityData[spellID] == nil then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if self.db.profile.announcedSpells[PlayerSpellIndex] ~= nil and
        not self.db.profile.debug then return end

    local isMax, nextRankLevel = self:IsMaxRank(spellID, self.playerLevel);

    if isMax then return end

    local spellLink = GetSpellLink(spellID);

    local castStringMsg = string.format(self.db.profile.castString, "You",
                                        spellLink, nextRankLevel)
    castStringMsg = string.format("%s %s", L["AnnouncePrefix"]["Self"],
                                  castStringMsg);

    self:PrintMessage(castStringMsg);

    self.db.profile.announcedSpells[PlayerSpellIndex] = true
end
