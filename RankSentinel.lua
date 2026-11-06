local addonName, RankSentinel = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName, "AceEvent-3.0", "AceComm-3.0")

local fmt, after, unpack = string.format, C_Timer.After, unpack
local UnitInBattleground, CombatLogGetCurrentEventInfo = _G.UnitInBattleground, _G.CombatLogGetCurrentEventInfo
local UnitIsEnemy, UnitLevel, UnitIsUnit = _G.UnitIsEnemy, _G.UnitLevel, _G.UnitIsUnit
-- These may be missing on newer clients (WoW Forever), so fall back to harmless stubs
local HasFullControl = _G.HasFullControl or function() return true end
local UnitIsPossessed = _G.UnitIsPossessed or function() return false end
local UnitIsCharmed = _G.UnitIsCharmed or function() return false end
local issecretvalue = _G.issecretvalue or function() return false end
local strmatch = string.match
local tinsert = table.insert

-- WoW Forever (Interface 16001) does not expose the combat log to addons
-- (CombatLogGetCurrentEventInfo is nil), so casts are detected via UNIT_SPELLCAST_SUCCEEDED instead.
addon.UseUnitEvents = CombatLogGetCurrentEventInfo == nil
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata

local bit_band = _G.bit.band
local COMBATLOG_OBJECT_AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local COMBATLOG_OBJECT_AFFILIATION_PARTY = _G.COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
local COMBATLOG_OBJECT_AFFILIATION_RAID = _G.COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
local COMBATLOG_FILTER_GROUP = _G.bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)

addon.Version = GetAddOnMetadata(addonName, "Version")
addon.MaxLevel = _G.GetMaxPlayerLevel()

addon.playerGUID = UnitGUID("player")
addon.playerName = UnitName("player")

if not addon.Version or string.match(addon.Version, 'project') then addon.Version = 'v9.9.9' end

addon._commPrefix = string.upper(addonName)

function addon:OnInitialize()
    self.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

    local defaults = {
        profile = {
            enable = true,
            whisper = true,
            debug = false,
            announcedSpells = {},
            ignoredPlayers = {},
            isMaxRank = {},
            petOwnerCache = {},
            dbVersion = 'v0.0.0',
            notificationFlavor = "default",
            isLatestVersion = true
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults)

    self:SetNotificationFlavor(self.db.profile.notificationFlavor)

    SLASH_RankSentinel1 = "/" .. string.lower(addonName)
    SLASH_RankSentinel2 = "/sentinel"

    _G.SlashCmdList[addonName] = function(message, _) addon:ChatCommand(message) end
end

function addon:OnEnable()
    self:UpgradeProfile()
    self:InitializeSession()
    self:BuildOptionsPanel()

    self:RegisterComm(self._commPrefix)

    if not self.db.profile.isLatestVersion then
        self:PrintMessage(self.L["Utilities"]["Outdated"])
        self.db.profile.enabled = false
        return
    end

    if not addon.cleuParser then -- re-use if someone did /disable /enable
        addon.cleuParser = CreateFrame("Frame")
        addon.cleuParser.OnEvent = function(frame, event, ...)
            addon.COMBAT_LOG_EVENT_UNFILTERED(addon, event, ...) -- make sure we get a proper 'self'
        end
        addon.cleuParser:SetScript("OnEvent", addon.cleuParser.OnEvent)
    end
    if addon.UseUnitEvents then
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("UNIT_AURA")
    else
        addon.cleuParser:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.settingsPending then
            self.settingsPending = nil

            local category = _G.Settings.GetCategory(self.options.name)
            _G.Settings.OpenToCategory(category.ID)
        end

        after(5, function() self:ProcessQueuedNotifications() end)
    end)

    self:RegisterEvent("PLAYER_UNGHOST", function(...) after(5, function() self:ProcessQueuedNotifications() end) end)

    self:RegisterEvent("PLAYER_ALIVE", function(...) after(5, function() self:ProcessQueuedNotifications() end) end)

    self:RegisterEvent("GROUP_LEFT")
    self:RegisterEvent("GROUP_JOINED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    self:ResetLead()

    if not self.db.profile.quietMode then
        self:PrintMessage("Loaded %s", self.Version)
    end

    self.db.profile.dbVersion = self.Version

    if self.db.profile.debug then
        self:PrintMessage("Debug enabled, clearing cache on reload")
        self:ClearCache()
    end
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

    self:ProcessCast(sourceGUID, sourceName, sourceName, destName, spellID, spellName)
end

-- Matches the unit tokens of the player, group members and their pets
local function IsGroupUnit(unit)
    if unit == "player" or unit == "pet" then return true end
    return strmatch(unit, "^party%d+$") or strmatch(unit, "^partypet%d+$") or strmatch(unit, "^raid%d+$") or
               strmatch(unit, "^raidpet%d+$")
end

-- Used when the combat log isn't available to addons (WoW Forever)
function addon:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if not self.db.profile.enable then return end

    local debug = self.db.profile.debug
    local unitIsString = type(unit) == "string" and not issecretvalue(unit)

    if not unitIsString then return end
    if not spellID or issecretvalue(spellID) then return end
    if not self.AbilityData[spellID] then return end
    if not IsGroupUnit(unit) then return end
    if UnitInBattleground("player") ~= nil then return end

    local sourceGUID, sourceName = UnitGUID(unit), UnitName(unit)
    if not sourceGUID or not sourceName or issecretvalue(sourceGUID) or issecretvalue(sourceName) then
        if debug then self:PrintMessage("Dropped %s cast: GUID/name unavailable or secret", unit) end
        return
    end

    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)

    -- the target of the cast is not provided by this event
    self:ProcessCast(sourceGUID, sourceName, unit, nil, spellID, spellName)
end

-- Forever hides other players' cast spell IDs (secret values), but the IDs of the auras they
-- receive stay readable. Buff/debuff ranks are therefore detected through UNIT_AURA.
function addon:UNIT_AURA(event, unit, updateInfo)
    if not self.db.profile.enable then return end
    if type(unit) ~= "string" or issecretvalue(unit) then return end
    -- check the unit first: nameplate/enemy updates carry secret fields that error when read
    if not IsGroupUnit(unit) then return end
    if type(updateInfo) ~= "table" or issecretvalue(updateInfo) then return end

    local isFull = updateInfo.isFullUpdate
    if issecretvalue(isFull) or isFull then return end

    local added, updated = updateInfo.addedAuras, updateInfo.updatedAuraInstanceIDs
    if issecretvalue(added) then added = nil end
    if issecretvalue(updated) then updated = nil end

    local getByInstance = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID

    local function check(aura)
        if type(aura) ~= "table" then return end

        local spellID, casterUnit = aura.spellId, aura.sourceUnit
        if not spellID or issecretvalue(spellID) or not self.AbilityData[spellID] then return end
        if not casterUnit or issecretvalue(casterUnit) or type(casterUnit) ~= "string" then return end
        if not IsGroupUnit(casterUnit) then return end

        -- own casts are handled by UNIT_SPELLCAST_SUCCEEDED, where the spell ID is readable
        if UnitIsUnit(casterUnit, "player") then return end

        local sourceGUID, sourceName = UnitGUID(casterUnit), UnitName(casterUnit)
        if not sourceGUID or not sourceName or issecretvalue(sourceGUID) or issecretvalue(sourceName) then return end

        if self.db.profile.debug then
            self:PrintMessage("Aura %d on %s from %s", spellID, unit, sourceName)
        end

        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)

        self:ProcessCast(sourceGUID, sourceName, casterUnit, nil, spellID, spellName)
    end

    if added then for _, aura in ipairs(added) do check(aura) end end

    if getByInstance and updated then
        for _, id in ipairs(updated) do check(getByInstance(unit, id)) end
    end
end

-- `unit` is anything UnitLevel & co accept (unit token or name)
function addon:ProcessCast(sourceGUID, sourceName, unit, destName, spellID, spellName)
    if not self.AbilityData[spellID] then return end
    if self.db.profile.ignoredPlayers[sourceGUID] then return end
    if UnitIsPossessed(unit) then return end
    if UnitIsCharmed(unit) then return end
    if sourceGUID == self.playerGUID and not HasFullControl() then return end
    if UnitIsEnemy("player", unit) then return end

    local castLevel = UnitLevel(unit)
    if not castLevel or issecretvalue(castLevel) or castLevel <= 0 then return end
    if self.db.profile.onlyMaxLevel and castLevel < addon.MaxLevel then return end

    local uid = self:GetUID(sourceGUID)

    -- Remember the whisperable (full) name for this player
    if sourceGUID ~= self.playerGUID then
        self.session.FullNames = self.session.FullNames or {}
        if not self.session.FullNames[sourceName] or self.session.FullNames[sourceName] == sourceName then
            self.session.FullNames[sourceName] = self:ResolveFullName(unit, sourceGUID, sourceName)
        end
    end

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
    --     self:UpdateSessionReport(playerSpellIndex, fmt("%s (%s)", sourceName, petOwner.OwnerName), spellName, spellID)
    -- else
    self:UpdateSessionReport(playerSpellIndex, sourceName, spellName, spellID)
    -- end

    local notification, target, ability = self:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel,
                                                                 petOwner)

    self:QueueNotification(notification, target, ability)

    self:RecordNotification(self.playerName, playerSpellIndex)

    self.session.PlayerGroupsNotified[abilityGroupIndex] = true
end

function addon:ChatCommand(cmd)
    local msg = string.lower(cmd)

    if msg == "reset" then
        self.db:ResetProfile()
        self:PrintMessage(self.L["ChatCommand"].Reset)
    elseif msg == "count" then
        self:PrintMessage(self.L["ChatCommand"].Count.Spells, self:CountCache(self.db.profile.announcedSpells))
        self:PrintMessage(self.L["ChatCommand"].Count.Ranks, self:CountCache(self.db.profile.isMaxRank))
    elseif msg == "clear" then
        self:ClearCache()
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage("%s = %s", self.L["Debug"], tostring(self.db.profile.debug))
    elseif msg == "whisper" then
        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage("%s = %s", self.L["Whisper"], tostring(self.db.profile.whisper))
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage("%s = %s", self.L["Enable"], tostring(self.db.profile.enable))
        if self.db.profile.enable then self:Broadcast("JOIN", fmt("%s,%d", self.playerName, addon.release.int)) end
    elseif msg == "lead" then
        self.cluster.lead = self.playerName
        self:BroadcastLead(self.playerName)
        self:PrintLead()
    elseif msg == "ignore" then
        if UnitExists("target") then
            self:IgnoreTarget()
        else
            self:PrintMessage(self.L["ChatCommand"].Ignore.Target)
            self:PrintMessage(self.L["ChatCommand"].Ignore.Count, self:CountCache(self.db.profile.ignoredPlayers))
        end
    elseif "queue" == string.sub(msg, 1, #"queue") then
        local _, sub = strsplit(' ', msg)
        if sub == 'clear' or sub == 'reset' then
            local queued = #self.session.Queue
            self.session.Queue = {}

            self:PrintMessage(self.L["ChatCommand"].Queue.Clear, queued)
        elseif sub == 'process' or sub == 'send' then
            self:ProcessQueuedNotifications()
        else
            self:PrintMessage(self.L["ChatCommand"].Queue.Count, #self.session.Queue)
            local notification = nil

            for i = 1, #self.session.Queue do
                notification = self.session.Queue[i]
                self:PrintMessage("%s - %s", notification.target, notification.ability)
            end
        end
    elseif msg == "sync" then
        self:SyncBroadcast()
    elseif "report" == string.sub(msg, 1, #"report") then
        local _, channel = strsplit(' ', msg)

        self:ReportToChannel(channel)
    elseif "flavor" == string.sub(msg, 1, #"flavor") then
        local _, sub = strsplit(' ', msg)
        if self.L["Notification"][sub] ~= nil then
            self:SetNotificationFlavor(sub)

            self:PrintMessage(self.L["ChatCommand"].Flavor.Set, sub)
        else
            if sub ~= nil then self:PrintMessage(self.L["ChatCommand"].Flavor.Unavailable, sub) end
            local flavorBaseExample = nil

            self:PrintMessage(self.L["ChatCommand"].Flavor.Available)

            for flavor, _ in pairs(self.L["Notification"]) do
                if self.L["Notification"][flavor] and self.L["Notification"][flavor].Base ~= nil then
                    flavorBaseExample = fmt("|cffffffff: " .. self.L["Notification"][flavor].Base, '[Spell]', '9', '',
                                            '62') .. '|r'
                else
                    flavorBaseExample = ''
                end

                self:PrintMessage("- %s%s", flavor, flavorBaseExample)
            end
        end
    elseif msg == "help" then
        self:PrintHelp(msg)
    else
        if InCombatLockdown() then
            self.settingsPending = true

            return
        end

        local category = _G.Settings.GetCategory(self.options.name)
        _G.Settings.OpenToCategory(category.ID)
    end
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
