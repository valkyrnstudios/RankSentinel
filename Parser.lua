local _, addon = ...

local fmt, ssub = string.format, string.sub
local strsplit, unpack = _G.strsplit, _G.unpack
local UnitInBattleground, CombatLogGetCurrentEventInfo = _G.UnitInBattleground, _G.CombatLogGetCurrentEventInfo
local HasFullControl, UnitIsPossessed, UnitIsCharmed = _G.HasFullControl, _G.UnitIsPossessed, _G.UnitIsCharmed
local UnitIsEnemy, UnitLevel = _G.UnitIsEnemy, _G.UnitLevel
local UnitGUID, UnitName, GetUnitName = _G.UnitGUID, _G.UnitName, _G.GetUnitName
local GetPlayerInfoByGUID = _G.GetPlayerInfoByGUID
local GetNumGroupMembers, GetNumSubgroupMembers = _G.GetNumGroupMembers, _G.GetNumSubgroupMembers
local IsInRaid, IsInGroup, IsGUIDInGroup = _G.IsInRaid, _G.IsInGroup, _G.IsGUIDInGroup
local InCombatLockdown, wipe = _G.InCombatLockdown, _G.wipe
local IsCombatLogRestricted = _G.C_CombatLog and _G.C_CombatLog.IsCombatLogRestricted
local GetSpellName = _G.C_Spell and _G.C_Spell.GetSpellName
local GetAuraDataByAuraInstanceID = _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByAuraInstanceID
local GetCombatSessionFromID = _G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionFromID
local GetCombatSessionFromType = _G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionFromType
local GetCombatSessionSourceFromID = _G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionSourceFromID
local GetCombatSessionSourceFromType = _G.C_DamageMeter and _G.C_DamageMeter.GetCombatSessionSourceFromType
local NewTicker = _G.C_Timer.NewTicker
local _G = _G
local isSecret = _G.issecretvalue or function() return false end

addon.parser = {cleu = {}, damageMeter = {}}

local unitParserEvents = {
    UNIT_SPELLCAST_SENT = "UNIT_SPELLCAST_SENT",
    UNIT_SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST_SUCCEEDED",
    UNIT_SPELLCAST_FAILED = "UNIT_SPELLCAST_FAILED",
    UNIT_SPELLCAST_FAILED_QUIET = "UNIT_SPELLCAST_FAILED",
    UNIT_SPELLCAST_INTERRUPTED = "UNIT_SPELLCAST_FAILED",
    UNIT_AURA = "UNIT_AURA",
}
local targetLevelByCastGUID = {}

local bit_band = _G.bit.band
local COMBATLOG_OBJECT_AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local COMBATLOG_OBJECT_AFFILIATION_PARTY = _G.COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
local COMBATLOG_OBJECT_AFFILIATION_RAID = _G.COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
local COMBATLOG_FILTER_GROUP = _G.bit.bor(
    COMBATLOG_OBJECT_AFFILIATION_MINE,
    COMBATLOG_OBJECT_AFFILIATION_PARTY,
    COMBATLOG_OBJECT_AFFILIATION_RAID
)

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

local function resolveFullName(unit, guid)
    local name = GetUnitName(unit, true)
    if isSecret(name) or name == "" then name = nil end
    if name and name:find(" ", 1, true) then return name end

    local _, _, _, _, _, fullName = GetPlayerInfoByGUID(guid)
    if not isSecret(fullName) and fullName and fullName ~= "" then return fullName end
    return name
end

function addon.parser.cleu:Parse()
    local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, _, destName, _, _, spellID, spellName =
        CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    if not sourceName then return end

    if bit_band(sourceFlags, COMBATLOG_FILTER_GROUP) == 0 then return end

    if not addon.AbilityData[spellID] then return end
    if UnitInBattleground("player") ~= nil then return end
    if UnitIsPossessed(sourceName) then return end
    if UnitIsCharmed(sourceName) then return end
    if sourceGUID == addon.playerGUID and not HasFullControl() then return end
    if UnitIsEnemy("player", sourceName) then return end

    local targetLevel = destName and UnitLevel(destName) or 0
    addon:ProcessCast(spellID, spellName, sourceGUID, sourceName, UnitLevel(sourceName), targetLevel)
end

function addon.parser.damageMeter:Poll()
    if not self.ticker or InCombatLockdown() then return end
    if not IsInGroup() or UnitInBattleground("player") ~= nil then
        wipe(self.sessions)
        return
    end

    local roster = {"player"}
    for _, unit in ipairs(IsInRaid() and raidUnit or partyUnit) do
        roster[#roster + 1] = unit
    end

    local unitsByGUID = {}
    local unitsByName = {}
    local guid
    for _, unit in ipairs(roster) do
        guid = UnitGUID(unit)
        if isSecret(guid) or not guid or not unitsByGUID[guid] then
            if not isSecret(guid) and guid then unitsByGUID[guid] = unit end
            for _, name in pairs({GetUnitName(unit, true), (UnitName(unit))}) do
                if not isSecret(name) and name then
                    if unitsByName[name] == nil then
                        unitsByName[name] = unit
                    elseif unitsByName[name] ~= unit then
                        unitsByName[name] = false
                    end
                end
            end
        end
    end

    self:PollType(Enum.DamageMeterType.DamageDone, unitsByGUID, unitsByName)
    self:PollType(Enum.DamageMeterType.HealingDone, unitsByGUID, unitsByName)
end

function addon.parser.damageMeter:PollType(meterType, unitsByGUID, unitsByName)
    local snapshot = self.sessions[meterType] or {}
    local sessionKey = snapshot.id or Enum.DamageMeterSessionType.Current
    local getSession = snapshot.id and GetCombatSessionFromID or GetCombatSessionFromType
    local getSource = snapshot.id and GetCombatSessionSourceFromID or GetCombatSessionSourceFromType
    local session = getSession(sessionKey, meterType)
    if isSecret(session) or not session then return end
    local sources = session.combatSources
    if isSecret(sources) or not sources then return end

    local reportChanges = snapshot.totals ~= nil
    local totals = snapshot.totals or {}
    local guid, unit, name
    local details, spells, level, canReport, spellTotals
    local spellID, amount, spellName

    for _, source in ipairs(sources) do
        guid = source.sourceGUID
        if not isSecret(guid) and guid then
            unit = unitsByGUID[guid]
        else
            name = source.name
            unit = not isSecret(name) and unitsByName[name]
            if unit then
                guid = UnitGUID(unit)
                if isSecret(guid) or not guid then unit = nil end
            end
        end

        if unit and unit ~= "player" and guid ~= addon.playerGUID and not source.isLocalPlayer then
            details = getSource(sessionKey, meterType, guid)
            spells = not isSecret(details) and details and details.combatSpells
            if not isSecret(spells) and spells then
                level = UnitLevel(unit)
                name = resolveFullName(unit, guid)
                canReport = reportChanges and not isSecret(level) and level and level > 0 and name
                spellTotals = totals[guid] or {}
                totals[guid] = spellTotals

                for _, spell in ipairs(spells) do
                    spellID, amount = spell.spellID, spell.totalAmount
                    if not isSecret(spellID) and addon.AbilityData[spellID]
                        and not isSecret(amount) and amount
                    then
                        if canReport and amount > 0 and amount ~= spellTotals[spellID] then
                            spellName = GetSpellName(spellID) or tostring(spellID)
                            addon:ProcessCast(spellID, spellName, guid, name, level, 0)
                        end
                        spellTotals[spellID] = amount
                    end
                end
            end
        end
    end
    snapshot.totals = totals
    self.sessions[meterType] = snapshot
end

function addon.parser:ProcessUnitCast(unit, spellID, targetLevel, fromAura)
    if isSecret(unit) or not unit then return end
    if unit ~= "player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$") then return end
    if isSecret(spellID) or not addon.AbilityData[spellID] then return end

    local guid = UnitGUID(unit)
    if isSecret(guid) or not guid then return end
    if fromAura and guid == addon.playerGUID then return end

    local level = UnitLevel(unit)
    if isSecret(level) or not level or level <= 0 then return end

    local name = guid == addon.playerGUID and addon.playerName or resolveFullName(unit, guid)
    if not name then return end

    local spellName = GetSpellName(spellID) or tostring(spellID)
    addon:ProcessCast(spellID, spellName, guid, name, level, targetLevel)
end

function addon.parser:UNIT_SPELLCAST_SENT(_, unit, target, castGUID, spellID)
    if isSecret(unit) or unit ~= "player" then return end
    if isSecret(spellID) or not addon.AbilityData[spellID] then return end
    if isSecret(castGUID) or not castGUID then return end
    if isSecret(target) or not target or target == "" then return end
    if UnitInBattleground("player") ~= nil then return end

    local targetLevel = UnitLevel(target)
    if not isSecret(targetLevel) and targetLevel and targetLevel > 0 then
        targetLevelByCastGUID[castGUID] = targetLevel
        return
    end

    -- Resolve names that UnitLevel cannot look up directly.
    targetLevel = nil
    local name, level
    for _, member in ipairs(IsInRaid() and raidUnit or partyUnit) do
        name = GetUnitName(member, true)
        if not isSecret(name) and name == target then
            if targetLevel then return end
            level = UnitLevel(member)
            if isSecret(level) or not level or level <= 0 then return end
            targetLevel = level
        end
    end
    targetLevelByCastGUID[castGUID] = targetLevel
end

function addon.parser:UNIT_SPELLCAST_FAILED(_, unit, castGUID)
    if not isSecret(unit) and unit == "player" and not isSecret(castGUID) and castGUID then
        targetLevelByCastGUID[castGUID] = nil
    end
end

function addon.parser:UNIT_SPELLCAST_SUCCEEDED(_, unit, castGUID, spellID)
    if isSecret(unit) or unit ~= "player" then return end

    local targetLevel
    if not isSecret(castGUID) and castGUID then
        targetLevel = targetLevelByCastGUID[castGUID]
        targetLevelByCastGUID[castGUID] = nil
    end
    if UnitInBattleground("player") ~= nil then return end

    self:ProcessUnitCast(unit, spellID, targetLevel or 0)
end

function addon.parser:ProcessAura(aura, targetLevel)
    if isSecret(aura) or not aura then return end
    self:ProcessUnitCast(aura.sourceUnit, aura.spellId, targetLevel, true)
end

function addon.parser:UNIT_AURA(_, unit, updateInfo)
    if isSecret(unit) or not unit then return end
    if unit ~= "player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$") then return end
    if UnitInBattleground("player") ~= nil or isSecret(updateInfo) or not updateInfo then return end

    local fullUpdate = updateInfo.isFullUpdate
    if isSecret(fullUpdate) or fullUpdate then return end

    local added = updateInfo.addedAuras
    local updated = updateInfo.updatedAuraInstanceIDs
    if isSecret(added) or not added or #added == 0 then added = nil end
    if isSecret(updated) or not updated or #updated == 0 then updated = nil end
    if not added and not updated then return end

    local targetLevel = UnitLevel(unit)
    if isSecret(targetLevel) or not targetLevel then targetLevel = 0 end

    if added then
        for _, aura in ipairs(added) do
            self:ProcessAura(aura, targetLevel)
        end
    end

    if updated then
        for _, instanceID in ipairs(updated) do
            if not isSecret(instanceID) then
                self:ProcessAura(GetAuraDataByAuraInstanceID(unit, instanceID), targetLevel)
            end
        end
    end
end

function addon.parser:Setup()
    local cleu, damageMeter = self.cleu, self.damageMeter
    local profile = addon.db.profile

    if not profile.enable or not profile.isLatestVersion then
        if cleu.frame then cleu.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
        for event in pairs(unitParserEvents) do
            addon:UnregisterEvent(event)
        end
        wipe(targetLevelByCastGUID)

        if damageMeter.ticker then
            damageMeter.ticker:Cancel()
            damageMeter.ticker = nil
            addon:UnregisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
            addon:UnregisterEvent("DAMAGE_METER_RESET")
        end
        return
    end

    if CombatLogGetCurrentEventInfo and not (IsCombatLogRestricted and IsCombatLogRestricted()) then
        if not cleu.frame then
            cleu.frame = CreateFrame("Frame")
            cleu.frame:SetScript("OnEvent", function() cleu:Parse() end)
        end
        cleu.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        return
    end

    if not GetSpellName then return end

    for event, method in pairs(unitParserEvents) do
        if event ~= "UNIT_AURA" or GetAuraDataByAuraInstanceID then
            addon:RegisterEvent(event, self[method], self)
        end
    end

    if damageMeter.ticker then return end
    if not (GetCombatSessionFromType and GetCombatSessionSourceFromType) then return end
    if not (GetCombatSessionFromID and GetCombatSessionSourceFromID) then return end

    damageMeter.sessions = {}
    addon:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", function(_, meterType, sessionID)
        if isSecret(meterType) or isSecret(sessionID) or not sessionID or sessionID <= 0 then return end
        if meterType ~= Enum.DamageMeterType.DamageDone and meterType ~= Enum.DamageMeterType.HealingDone then
            return
        end

        local snapshot = damageMeter.sessions[meterType]
        if not snapshot or snapshot.id ~= sessionID then
            damageMeter.sessions[meterType] = {
                id = sessionID,
                totals = snapshot and snapshot.totals and {},
            }
        end
    end)
    addon:RegisterEvent("DAMAGE_METER_RESET", function()
        damageMeter.sessions = {}
    end)
    damageMeter.ticker = NewTicker(15, function() damageMeter:Poll() end)
    damageMeter:Poll()
end

function addon:ProcessCast(spellID, spellName, sourceGUID, sourceName, castLevel, targetLevel)
    if self.db.profile.ignoredPlayers[sourceGUID] then return end
    if self.db.profile.onlyMaxLevel and castLevel < addon.MaxLevel then return end

    local uid = self:GetUID(sourceGUID)

    -- Only notify once per ability group
    local abilityGroupIndex = fmt("%s-%d", uid, addon.AbilityData[spellID].AbilityGroup)
    if self.session.PlayerGroupsNotified[abilityGroupIndex] ~= nil and not self.db.profile.debug then return end

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

    self.comms:UpdateSessionReport(playerSpellIndex, sourceName, spellName, spellID)

    local notification, target, ability = self.comms:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel)

    self.comms:QueueNotification(notification, target, ability)

    self.comms:RecordNotification(self.playerName, playerSpellIndex)

    self.session.PlayerGroupsNotified[abilityGroupIndex] = true
end

function addon:IsMaxRank(spellID, casterLevel, targetLevel)
    -- UnitLevel(destName) returns 0 for non-party members
    -- Ignore casts with larger than 10 level differences
    if targetLevel >= 1 and targetLevel < casterLevel - 8 then return true end

    local cacheKey = fmt('%s-%s', spellID, casterLevel)
    local cache = self.db.profile.isMaxRank
    local cached = cache[cacheKey]
    if type(cached) == "table" and not self.db.profile.debug then return unpack(cached) end

    local abilityData = addon.AbilityData[spellID]

    local abilityGroupData = addon.AbilityGroups[abilityData["AbilityGroup"]]

    -- Vast majority of checks will be on lvl 70, check if highest available rank first
    if spellID == abilityGroupData[#abilityGroupData] then
        if self.db.profile.debug then self:PrintMessage("Caching max rank %s", cacheKey) end

        cache[cacheKey] = {true}

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
        self:PrintMessage(
            "Casted %d, next rank (%d) available at %d, isMax %s",
            spellID,
            nextRankID,
            nextRankData.Level,
            tostring(isMax)
        )
    end

    cache[cacheKey] = {isMax, nextRankData.Level}

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
        self.db.profile.petOwnerCache[petUID] = self.db.profile.petOwnerCache[petUID]
            or {OwnerName = self.playerName, OwnerGUID = self.playerGUID}
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
            for i = 1, GetNumSubgroupMembers() do
                if leader == UnitName(partyUnit[i]) then return true end
            end
        else
            for i = 1, GetNumGroupMembers() do
                if leader == UnitName(raidUnit[i]) then return true end
            end
        end
    end
end
