local _, addon = ...

local fmt, strsplit, ssub, unpack = string.format, strsplit, string.sub, unpack
local UnitInBattleground, CombatLogGetCurrentEventInfo = _G.UnitInBattleground, _G.CombatLogGetCurrentEventInfo
local HasFullControl, UnitIsPossessed, UnitIsCharmed, UnitIsEnemy, UnitLevel = _G.HasFullControl, _G.UnitIsPossessed,
                                                                               _G.UnitIsCharmed, _G.UnitIsEnemy,
                                                                               _G.UnitLevel
local UnitGUID, GetPlayerInfoByGUID = UnitGUID, GetPlayerInfoByGUID
local GetNumGroupMembers, GetNumSubgroupMembers = GetNumGroupMembers, GetNumSubgroupMembers
local IsInRaid, IsInGroup, IsGUIDInGroup = IsInRaid, IsInGroup, IsGUIDInGroup
local _G = _G

local bit_band = _G.bit.band
local COMBATLOG_OBJECT_AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local COMBATLOG_OBJECT_AFFILIATION_PARTY = _G.COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
local COMBATLOG_OBJECT_AFFILIATION_RAID = _G.COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
local COMBATLOG_FILTER_GROUP = _G.bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)

-- cache relevant unitids once so we don't do concat every call
local raidUnit, raidUnitPet = {}, {}
local partyUnit, partyUnitPet = {}, {}

for i = 1, _G.MAX_RAID_MEMBERS do
    raidUnit[i] = "raid" .. i
    raidUnitPet[i] = "raidpet" .. i
end
for i = 1, _G.MAX_PARTY_MEMBERS do
    partyUnit[i] = "party" .. i
    partyUnitPet[i] = "partypet" .. i
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
    if not self.db.profile.enable then return end
    if UnitInBattleground("player") ~= nil then return end

    local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, _, destName, _, _, spellID, spellName =
        CombatLogGetCurrentEventInfo()

    -- bail out early for trivial cases (lookups before function calls, wide checks to narrow)
    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    if not sourceName then return end

    if bit_band(sourceFlags, COMBATLOG_FILTER_GROUP) == 0 then return end

    if not self.AbilityData[spellID] then return end
    if self.db.profile.ignoredPlayers[sourceGUID] then return end
    if UnitIsPossessed(sourceName) then return end
    if UnitIsCharmed(sourceName) then return end
    if sourceGUID == self.playerGUID and not HasFullControl() then return end
    if UnitIsEnemy("player", sourceName) then return end

    -- local isInGroup, petOwner = self.InGroupWith(sourceGUID)
    -- if not isInGroup then return end

    local castLevel = UnitLevel(sourceName)
    if self.db.profile.onlyMaxLevel and castLevel < addon.MaxLevel then return end

    local uid = self:GetUID(sourceGUID)

    -- Only notify once per ability group
    local abilityGroupIndex = fmt("%s-%d", uid, addon.AbilityData[spellID].AbilityGroup)
    if self.session.PlayerGroupsNotified[abilityGroupIndex] ~= nil and not self.db.profile.debug then return end

    local targetLevel = destName and UnitLevel(destName) or 0
    local isMax, nextRankLevel = self:IsMaxRank(spellID, castLevel, targetLevel)
    if isMax or not nextRankLevel or nextRankLevel <= 0 then return end

    if not self.session.PlayerLevelCache[uid] then
        self.session.PlayerLevelCache[uid] = castLevel
    elseif castLevel > self.session.PlayerLevelCache[uid] then
        -- If downrank, don't notify on a new level up this session
        return
    end

    local playerSpellIndex = fmt("%s-%s-%s", uid, castLevel, spellID)
    if self.db.profile.announcedSpells[playerSpellIndex] ~= nil and not self.db.profile.debug then return end

    -- Disabled for Classic/TBC, restore for Wrath
    -- if petOwner then
    --     self.comms:UpdateSessionReport(playerSpellIndex, fmt("%s (%s)", sourceName, petOwner.OwnerName), spellName, spellID)
    -- else
    self.comms:UpdateSessionReport(playerSpellIndex, sourceName, spellName, spellID)
    -- end

    local notification, target, ability = self.comms:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel,
                                                                      petOwner)

    self.comms:QueueNotification(notification, target, ability)

    self.comms:RecordNotification(self.playerName, playerSpellIndex)

    self.session.PlayerGroupsNotified[abilityGroupIndex] = true
end

function addon:IsMaxRank(spellID, casterLevel, targetLevel)
    -- UnitLevel(destName) returns 0 for non-party members
    -- Ignore casts with larger than 10 level differences
    if targetLevel >= 1 and targetLevel < casterLevel - 8 then return true end

    local lookup_key = fmt('%s-%s', spellID, casterLevel)

    if self.db.profile.isMaxRank[lookup_key] ~= nil and not self.db.profile.debug then
        -- this as a boolean would only work for isMax == true where the 2nd argument is discarded
        -- it fails for isMax == false in the caller because `nextRankLevel` would show up as nil
        -- ClearCache should take care of old boolean entries if we up the version.
        return unpack(self.db.profile.isMaxRank[lookup_key])
    end

    local abilityData = addon.AbilityData[spellID]

    local abilityGroupData = addon.AbilityGroups[abilityData["AbilityGroup"]]

    -- Vast majority of checks will be on lvl 70, check if highest available rank first
    if spellID == abilityGroupData[#abilityGroupData] then
        if self.db.profile.debug then self:PrintMessage("Caching max rank %s", lookup_key) end

        self.db.profile.isMaxRank[lookup_key] = {true}

        return true
    end

    -- Above block guarantees there's another rank
    local nextRankID = abilityGroupData[abilityData["Rank"] + 1]

    local nextRankData = addon.AbilityData[nextRankID]

    -- Above logic assumes no ranks are excluded, breaks for Arcane Explosion at least
    -- If rank not the index, find proper rank
    if nextRankData == nil or (nextRankData.Rank ~= (abilityData.Rank + 1)) then
        if self.db.profile.debug then
            self:PrintMessage("Mismatching indices next rank (%d), performing search", abilityData["Rank"] + 1)
        end

        for _, checkedSpellID in pairs(abilityGroupData) do
            nextRankID = checkedSpellID
            nextRankData = addon.AbilityData[checkedSpellID]

            if (abilityData.Rank + 1) == nextRankData.Rank then
                if self.db.profile.debug then
                    self:PrintMessage("Found proper next rank (%d) for %s", nextRankData.Rank, nextRankID)
                end
                break
            end
        end
    end

    if nextRankData.Level == 0 then
        if self.db.profile.debug then
            self:PrintMessage("Failed to get next rank past %d, guessed %d", spellID, nextRankID)
        end
        return nil, -1
    end

    local isMax = self:IsHighestAlertableRank(nextRankData.Level, casterLevel)

    if self.db.profile.debug then
        self:PrintMessage("Casted %d, next rank (%d) available at %d, isMax %s", spellID, nextRankID,
                          nextRankData.Level, tostring(isMax))
    end

    self.db.profile.isMaxRank[lookup_key] = {isMax, nextRankData.Level}

    return isMax, nextRankData.Level
end

function addon:IsHighestAlertableRank(nextRankLevel, casterLevel)
    if casterLevel == addon.MaxLevel then
        return nextRankLevel > casterLevel
    elseif casterLevel < 10 then
        return nextRankLevel > casterLevel
    elseif casterLevel < 20 then
        return nextRankLevel + 3 > casterLevel
    elseif casterLevel < addon.MaxLevel - 10 then
        return nextRankLevel + 2 > casterLevel
    elseif casterLevel < addon.MaxLevel then
        return nextRankLevel + 1 > casterLevel
    end

    return nextRankLevel > casterLevel
end

function addon:IsPetOwnerInRaid(petGuid)
    local petUID = self:GetUID(petGuid)

    if petGuid == UnitGUID("pet") then
        self.db.profile.petOwnerCache[petUID] = self.db.profile.petOwnerCache[petUID] or
                                                    {OwnerName = self.playerName, OwnerGUID = self.playerGUID}
        return true, self.db.profile.petOwnerCache[petUID]
    end

    local _, ownerId, ownerName, groupPetId

    if self.db.profile.petOwnerCache[petUID] ~= nil then
        -- :InGroupWith() calls :IsPetOwnerInRaid make sure we never infinite recurse?
        local isInGroup, _ = self:InGroupWith(self.db.profile.petOwnerCache[petUID].OwnerGUID)

        return isInGroup, self.db.profile.petOwnerCache[petUID]
    end

    if IsInGroup() then
        if not IsInRaid() then
            for i = 1, GetNumSubgroupMembers() do
                groupPetId = UnitGUID(partyUnitPet[i])

                if not groupPetId then break end
                if petGuid ~= groupPetId then break end

                ownerId = UnitGUID(partyUnit[i])

                if not ownerId then break end
                if petGuid == groupPetId then
                    _, _, _, _, _, ownerName, _ = GetPlayerInfoByGUID(ownerId)

                    self.db.profile.petOwnerCache[petUID] = {OwnerName = ownerName, OwnerGUID = ownerId}
                    return true, self.db.profile.petOwnerCache[petUID]
                end
            end
        else
            for i = 1, GetNumGroupMembers() do
                groupPetId = UnitGUID(raidUnitPet[i])

                if not groupPetId then break end
                if petGuid ~= groupPetId then break end

                ownerId = UnitGUID(raidUnit[i])

                if not ownerId then break end
                if petGuid == groupPetId then
                    _, _, _, _, _, ownerName, _ = GetPlayerInfoByGUID(ownerId)

                    self.db.profile.petOwnerCache[petUID] = {OwnerName = ownerName, OwnerGUID = ownerId}
                    return true, self.db.profile.petOwnerCache[petUID]
                end
            end
        end
    end
end

function addon:GetUID(guid)
    local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)

    if unitType == "Pet" then return fmt("Pet-%s", ssub(spawnUID, 3)) end

    return guid
end

function addon:InGroupWith(guid)
    if guid == self.playerGUID then
        return true, nil
    elseif strsplit("-", guid) == 'Pet' then
        return self:IsPetOwnerInRaid(guid)
    elseif GetNumGroupMembers() > 1 then
        return IsGUIDInGroup(guid)
    end
end

function addon:IsLeaderInGroup(leader)
    if self.playerName == leader then
        return true
    elseif IsInGroup() then
        if not IsInRaid() then
            for i = 1, GetNumSubgroupMembers() do if leader == UnitName(partyUnit[i]) then return true end end
        else
            for i = 1, GetNumGroupMembers() do if leader == UnitName(raidUnit[i]) then return true end end
        end
    end
end
