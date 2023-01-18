local addonName, RankSentinel = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName,
    "AceEvent-3.0", "AceComm-3.0")

local fmt, after, unpack = string.format, C_Timer.After, unpack
local UnitInBattleground, CombatLogGetCurrentEventInfo = UnitInBattleground,
    CombatLogGetCurrentEventInfo
local HasFullControl, UnitIsPossessed, UnitIsCharmed, UnitIsEnemy, UnitLevel = HasFullControl, UnitIsPossessed,
    UnitIsCharmed,
    UnitIsEnemy, UnitLevel

addon.Version = GetAddOnMetadata(addonName, "Version")
addon.MaxLevel = _G.GetMaxPlayerLevel()

addon.playerGUID = UnitGUID("player")
addon.playerName = UnitName("player")

if string.match(addon.Version, 'project') then addon.Version = 'v9.9.9' end

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

    _G.SlashCmdList[addonName] = function(message, _)
        addon:ChatCommand(message)
    end
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
    addon.cleuParser:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        after(5, function() self:ProcessQueuedNotifications() end)
    end)

    self:RegisterEvent("PLAYER_UNGHOST", function(...)
        after(5, function() self:ProcessQueuedNotifications() end)
    end)

    self:RegisterEvent("PLAYER_ALIVE", function(...)
        after(5, function() self:ProcessQueuedNotifications() end)
    end)

    self:RegisterEvent("GROUP_LEFT")
    self:RegisterEvent("GROUP_JOINED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    self:ResetLead()

    self:PrintMessage("Loaded %s", self.Version)

    self.db.profile.dbVersion = self.Version

    if self.db.profile.debug then
        self:PrintMessage("Debug enabled, clearing cache on reload")
        self:ClearCache()
    end
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
    if not self.db.profile.enable then return end
    if UnitInBattleground("player") ~= nil then return end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
    spellID, spellName = CombatLogGetCurrentEventInfo()
    -- bail out early for trivial cases (lookups before function calls, wide checks to narrow)
    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    if sourceName == nil then return end
    if self.AbilityData[spellID] == nil then return end
    if self.db.profile.ignoredPlayers[sourceGUID] ~= nil then return end
    if UnitIsPossessed(sourceName) then return end
    if UnitIsCharmed(sourceName) then return end
    if sourceGUID == self.playerGUID and not HasFullControl() then return end
    if UnitIsEnemy("player", sourceName) then return end

    local isInGroup, petOwner = self:InGroupWith(sourceGUID)
    if not isInGroup then return end

    local castLevel = UnitLevel(sourceName)
    if self.db.profile.onlyMaxLevel and castLevel < addon.MaxLevel then
        return
    end

    local uid = self:GetUID(sourceGUID)

    -- Only notify once per ability group
    local abilityGroupIndex = fmt("%s-%d", uid, addon.AbilityData[spellID].AbilityGroup)
    if self.session.PlayerGroupsNotified[abilityGroupIndex] ~= nil and not self.db.profile.debug then
        return
    end

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
    if self.db.profile.announcedSpells[playerSpellIndex] ~= nil and not self.db.profile.debug then
        return
    end

    if petOwner then
        self:UpdateSessionReport(playerSpellIndex, fmt("%s (%s)", sourceName,
            petOwner.OwnerName),
            spellName, spellID)
    else
        self:UpdateSessionReport(playerSpellIndex, sourceName, spellName,
            spellID)
    end

    local notification, target, ability =
    self:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel,
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
        self:PrintMessage(self.L["ChatCommand"].Count.Spells,
            self:CountCache(self.db.profile.announcedSpells))
        self:PrintMessage(self.L["ChatCommand"].Count.Ranks,
            self:CountCache(self.db.profile.isMaxRank))
    elseif msg == "clear" then
        self:ClearCache()
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage("%s = %s", self.L["Debug"],
            tostring(self.db.profile.debug))
    elseif msg == "whisper" then
        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage("%s = %s", self.L["Whisper"],
            tostring(self.db.profile.whisper))
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage("%s = %s", self.L["Enable"],
            tostring(self.db.profile.enable))
        if self.db.profile.enable then
            self:Broadcast("JOIN", fmt("%s,%d", self.playerName, addon.release.int))
        end
    elseif msg == "lead" then
        self.cluster.lead = self.playerName
        self:BroadcastLead(self.playerName)
        self:PrintLead()
    elseif msg == "ignore" then
        if UnitExists("target") then
            self:IgnoreTarget()
        else
            self:PrintMessage(self.L["ChatCommand"].Ignore.Target)
            self:PrintMessage(self.L["ChatCommand"].Ignore.Count,
                self:CountCache(self.db.profile.ignoredPlayers))
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
            self:PrintMessage(self.L["ChatCommand"].Queue.Count,
                #self.session.Queue)
            local notification = nil

            for i = 1, #self.session.Queue do
                notification = self.session.Queue[i]
                self:PrintMessage("%s - %s", notification.target,
                    notification.ability)
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
            if sub ~= nil then
                self:PrintMessage(self.L["ChatCommand"].Flavor.Unavailable,
                    sub)
            end
            local flavorBaseExample = nil

            self:PrintMessage(self.L["ChatCommand"].Flavor.Available)

            for flavor, _ in pairs(self.L["Notification"]) do
                if self.L["Notification"][flavor] and
                    self.L["Notification"][flavor].Base ~= nil then
                    flavorBaseExample = fmt("|cffffffff: " ..
                        self.L["Notification"][flavor]
                        .Base, '[Spell]', '9', '',
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
        _G.InterfaceOptionsFrame_OpenToCategory(addon.options)
        _G.InterfaceOptionsFrame_OpenToCategory(addon.options)
    end
end

function addon:IsMaxRank(spellID, casterLevel, targetLevel)
    -- UnitLevel(destName) returns 0 for non-party members
    -- Ignore casts with larger than 10 level differences
    if targetLevel >= 1 and targetLevel < casterLevel - 8 then return true end

    local lookup_key = fmt('%s-%s', spellID, casterLevel)

    if self.db.profile.isMaxRank[lookup_key] ~= nil and
        not self.db.profile.debug then
        -- this as a boolean would only work for isMax == true where the 2nd argument is discarded
        -- it fails for isMax == false in the caller because `nextRankLevel` would show up as nil
        -- ClearCache should take care of old boolean entries if we up the version.
        return unpack(self.db.profile.isMaxRank[lookup_key])
    end

    local abilityData = addon.AbilityData[spellID]

    local abilityGroupData = addon.AbilityGroups[abilityData["AbilityGroup"]]

    -- Vast majority of checks will be on lvl 70, check if highest available rank first
    if spellID == abilityGroupData[#abilityGroupData] then
        if self.db.profile.debug then
            self:PrintMessage("Caching max rank %s", lookup_key)
        end

        self.db.profile.isMaxRank[lookup_key] = { true }

        return true
    end

    -- Above block guarantees there's another rank
    local nextRankID = abilityGroupData[abilityData["Rank"] + 1]

    local nextRankData = addon.AbilityData[nextRankID]

    -- Above logic assumes no ranks are excluded, breaks for Arcane Explosion at least
    -- If rank not the index, find proper rank
    if nextRankData == nil or (nextRankData.Rank ~= (abilityData.Rank + 1)) then
        if self.db.profile.debug then
            self:PrintMessage("Mismatching indices next rank (%d), performing search",
                abilityData["Rank"] + 1)
        end

        for _, checkedSpellID in pairs(abilityGroupData) do
            nextRankID = checkedSpellID
            nextRankData = addon.AbilityData[checkedSpellID]

            if (abilityData.Rank + 1) == nextRankData.Rank then
                if self.db.profile.debug then
                    self:PrintMessage("Found proper next rank (%d) for %s",
                        nextRankData.Rank, nextRankID)
                end
                break
            end
        end
    end

    if nextRankData.Level == 0 then
        if self.db.profile.debug then
            self:PrintMessage("Failed to get next rank past %d, guessed %d",
                spellID, nextRankID)
        end
        return nil, -1
    end

    local isMax = self:IsHighestAlertableRank(nextRankData.Level, casterLevel)

    if self.db.profile.debug then
        self:PrintMessage(
            "Casted %d, next rank (%d) available at %d, isMax %s",
            spellID, nextRankID, nextRankData.Level,
            tostring(isMax))
    end

    self.db.profile.isMaxRank[lookup_key] = { isMax, nextRankData.Level }

    return isMax, nextRankData.Level
end
