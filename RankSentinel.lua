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
        if not self.meterTicker then
            self.meterTicker = C_Timer.NewTicker(15, function() addon:PollDamageMeter() end)
        end
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
        if addon.UseUnitEvents then after(2, function() self:PollDamageMeter() end) end
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

    -- A cast GUID is "Cast-<type>-<server>-<instance>-<zone>-<spellID>-<castUID>": when the spell ID
    -- is secret (other players on Forever), try to recover it from the cast GUID instead
    local fromCastGUID
    if (not spellID or issecretvalue(spellID)) and type(castGUID) == "string" and not issecretvalue(castGUID) then
        local id = strmatch(castGUID, "^Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
        if id then
            spellID, fromCastGUID = tonumber(id), true
        end
    end

    if debug and unit ~= "player" and IsGroupUnit(unit) then
        self:PrintMessage("Cast %s: spellID %s, castGUID %s%s", unit,
                          (spellID and not issecretvalue(spellID)) and tostring(spellID) or "<secret>",
                          issecretvalue(castGUID) and "<secret>" or tostring(castGUID),
                          fromCastGUID and " (spell ID read from castGUID)" or "")
    end

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

    local function check(aura, kind)
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
            self:PrintMessage("Aura %d (%s) on %s from %s", spellID, kind, unit, sourceName)
        end

        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)

        self:ProcessCast(sourceGUID, sourceName, casterUnit, nil, spellID, spellName)
    end

    if added then for _, aura in ipairs(added) do check(aura, "added") end end

    if getByInstance and updated then
        for _, id in ipairs(updated) do check(getByInstance(unit, id), "refreshed") end
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

-- Finds the party/raid unit token for a (full or first) character name, excluding the player
function addon:FindGroupUnitByName(name)
    local function matches(unit)
        if not UnitExists(unit) then return false end
        local short = UnitName(unit)
        if not short or issecretvalue(short) then return false end
        local full = GetUnitName and GetUnitName(unit, true)
        if full and not issecretvalue(full) and full == name then return true end
        return short == name or strmatch(name, "^(%S+)") == short
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if not UnitIsUnit(unit, "player") and matches(unit) then return unit end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if matches(unit) then return unit end
        end
    end
end

-- WoW Forever hides other players' cast spell IDs, but Blizzard's built-in damage meter lists each
-- group member's damage/healing spells with readable spell IDs. Poll it to catch the spells the
-- UNIT_AURA path cannot see (damage, heals and other instant spells that leave no buff).
function addon:PollDamageMeter()
    if not self.db.profile.enable or not self.UseUnitEvents then return end
    if not (C_DamageMeter and Enum and Enum.DamageMeterSessionType and Enum.DamageMeterType) then return end
    if not IsInGroup() or UnitInBattleground("player") ~= nil then return end

    local debug = self.db.profile.debug
    local sessionType = Enum.DamageMeterSessionType.Current

    for _, dmType in ipairs({Enum.DamageMeterType.DamageDone, Enum.DamageMeterType.HealingDone}) do
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, dmType)
        local sources = ok and type(session) == "table" and not issecretvalue(session) and session.combatSources

        if type(sources) == "table" and not issecretvalue(sources) then
            for _, source in ipairs(sources) do
                local name = type(source) == "table" and not issecretvalue(source) and source.name
                if type(name) == "string" and not issecretvalue(name) then
                    local unit = self:FindGroupUnitByName(name)

                    if unit then
                        local ok2, detail = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, dmType,
                                                  source.sourceGUID)
                        local spells = ok2 and type(detail) == "table" and not issecretvalue(detail) and
                                           detail.combatSpells

                        if type(spells) == "table" and not issecretvalue(spells) then
                            local guid = UnitGUID(unit)

                            for _, spell in ipairs(spells) do
                                local spellID = type(spell) == "table" and not issecretvalue(spell) and spell.spellID

                                if spellID and not issecretvalue(spellID) and self.AbilityData[spellID] and guid and
                                    not issecretvalue(guid) then
                                    if debug then
                                        self:PrintMessage("Meter: %s cast %d", name, spellID)
                                    end

                                    local spellName = C_Spell and C_Spell.GetSpellName and
                                                          C_Spell.GetSpellName(spellID) or tostring(spellID)

                                    self:ProcessCast(guid, UnitName(unit), unit, nil, spellID, spellName)
                                elseif debug and spellID and issecretvalue(spellID) then
                                    self:PrintMessage("Meter: %s spell ID is secret", name)
                                end
                            end
                        elseif debug then
                            self:PrintMessage("Meter: no readable spells for %s (%s)", name, ok2 and "secret/empty" or
                                                  tostring(detail))
                        end
                    end
                end
            end
        end
    end
end

-- Prints what this client exposes that could replace the combat log (run /ranksentinel probe)
function addon:ProbeForever()
    local function keys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = tostring(k) end
        table.sort(out)
        return table.concat(out, ", ")
    end

    self:PrintMessage("Probe: build %s, project %s, combat log %s", tostring(select(4, GetBuildInfo())),
                      tostring(_G.WOW_PROJECT_ID), addon.UseUnitEvents and "unavailable" or "available")

    if C_DamageMeter then
        self:PrintMessage("C_DamageMeter functions: %s", keys(C_DamageMeter))
    else
        self:PrintMessage("C_DamageMeter: not present")
    end

    if Enum and Enum.DamageMeterType then
        self:PrintMessage("Enum.DamageMeterType: %s", keys(Enum.DamageMeterType))
    end
    if Enum and Enum.DamageMeterSessionType then
        self:PrintMessage("Enum.DamageMeterSessionType: %s", keys(Enum.DamageMeterSessionType))
    end

    if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable then
        local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
        self:PrintMessage("IsDamageMeterAvailable: %s %s %s", tostring(ok), tostring(available), tostring(reason))
    end
end

-- Dumps the structure (and whether values are secret) of the built-in damage meter data
function addon:ProbeDamageMeter()
    if not (C_DamageMeter and Enum and Enum.DamageMeterSessionType and Enum.DamageMeterType) then
        self:PrintMessage("Probe meter: C_DamageMeter not available")
        return
    end

    local function show(label, v, depth)
        if issecretvalue(v) then
            self:PrintMessage("%s = <secret %s>", label, type(v))
        elseif type(v) == "table" then
            local n = 0
            for _ in pairs(v) do n = n + 1 end
            self:PrintMessage("%s = table (%d entries)", label, n)
            if depth > 0 then
                local shown = 0
                for k, val in pairs(v) do
                    shown = shown + 1
                    if shown > 8 then break end
                    show(label .. "." .. tostring(k), val, depth - 1)
                end
            end
        else
            self:PrintMessage("%s = %s", label, tostring(v))
        end
    end

    for _, dmType in ipairs({"DamageDone", "HealingDone"}) do
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Overall,
                                  Enum.DamageMeterType[dmType])
        if not ok then
            self:PrintMessage("%s: error %s", dmType, tostring(session))
        else
            show(dmType, session, 1)

            local sources = type(session) == "table" and not issecretvalue(session) and session.combatSources
            local first = sources and not issecretvalue(sources) and sources[1]
            if first and not issecretvalue(first) then
                show(dmType .. " source1", first, 1)

                local guid = first.sourceGUID
                local ok2, detail = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
                                          Enum.DamageMeterSessionType.Overall, Enum.DamageMeterType[dmType], guid)
                if ok2 then
                    show(dmType .. " detail", detail, 2)
                    local spells = type(detail) == "table" and not issecretvalue(detail) and detail.combatSpells
                    if spells and not issecretvalue(spells) and spells[1] then
                        show(dmType .. " spell1", spells[1], 1)
                    end
                else
                    self:PrintMessage("%s detail: error %s", dmType, tostring(detail))
                end
            end
        end
    end
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
    elseif msg == "probe" then
        self:ProbeForever()
    elseif msg == "probe meter" then
        self:ProbeDamageMeter()
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
