local addonName, RankSentinel = ...

local addon = nil

local fmt = string.format

local isTBC = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local isVanilla = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC

if isTBC then
    addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName,
                                             "AceEvent-3.0", "AceComm-3.0")
elseif isVanilla then
    -- Clustering moot on classic, can only detect self spellIDs
    addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName,
                                             "AceEvent-3.0")
end

addon.Version = GetAddOnMetadata(addonName, "Version")

if string.match(addon.Version, 'project') then addon.Version = 'v9.9.9' end

addon._commPrefix = string.upper(addonName)

function addon:OnInitialize()
    self.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

    local defaults = {
        profile = {
            enable = true,
            whisper = UnitLevel("Player") == 70,
            debug = false,
            announcedSpells = {},
            ignoredPlayers = {},
            isMaxRank = {},
            dbVersion = 'v0.0.0',
            notificationFlavor = "default"
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults, true)

    self.notifications = self.L["Notification"][self.db.profile
                             .notificationFlavor]

    self.playerGUID = UnitGUID("Player");
    self.playerName = UnitName("Player");

    SLASH_RankSentinel1 = "/" .. string.lower(addonName);
    SLASH_RankSentinel2 = "/sentinel";

    SlashCmdList[addonName] =
        function(message, _) addon:ChatCommand(message) end;
end

function addon:OnEnable()
    if isTBC then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
        self:RegisterEvent("PLAYER_ENTERING_WORLD");
        self:RegisterEvent("PLAYER_REGEN_ENABLED");

        self:RegisterComm(self._commPrefix);
        self:ResetLead();
    elseif isVanilla then
        -- SpellID not a parameter of COMBAT_LOG_EVENT_UNFILTERED in Classic era
        -- Self casted UNIT_SPELLCAST_SUCCEEDED contains spellID
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
        self:RegisterEvent("PLAYER_LEVEL_UP");

        self.playerLevel = UnitLevel("Player");
    end

    self:PrintMessage("Loaded " .. self.Version);

    self:UpgradeProfile();

    self.db.profile.dbVersion = self.Version;

    self.session = {
        Queue = {},
        Report = {},
        UnsupportedComm = {},
        PlayersNotified = {}
    }

    if self.db.profile.debug then
        self:PrintMessage("Debug enabled, clearing cache on reload");
        self:ClearCache();
    end
end

function addon:PLAYER_REGEN_ENABLED(...)
    -- If player dead, combat for rest of the raid could be ongoing
    if UnitIsDeadOrGhost("Player") then return end

    -- TODO trigger notification processing again without waiting for a combat cycle
    -- PLAYER_UNGHOST, PLAYER_ALIVE
    self:ProcessQueuedNotifications();
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, spellName = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" or
        self.db.profile.ignoredPlayers[sourceGUID] ~= nil or
        self.AbilityData[spellID] == nil or not HasFullControl() or
        UnitIsPossessed(sourceName) or UnitIsCharmed(sourceName) or
        UnitIsEnemy("Player", sourceName) then return end

    local isInGroup, petOwner = self:InGroupWith(sourceGUID)

    if not isInGroup then return end

    local castLevel = UnitLevel(sourceName)

    local playerSpellIndex = fmt("%s-%s-%s", self:GetUID(sourceGUID), castLevel,
                                 spellID)

    if self.db.profile.announcedSpells[playerSpellIndex] ~= nil and
        not self.db.profile.debug then return end

    local targetLevel = destName and UnitLevel(destName) or 0

    local isMax, nextRankLevel = self:IsMaxRank(spellID, castLevel, targetLevel);

    if isMax or not nextRankLevel or nextRankLevel <= 0 then return end

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
end

function addon:ChatCommand(cmd)
    local msg = string.lower(cmd)

    if msg == "reset" then
        self.db:ResetProfile()
        self:PrintMessage(self.L["ChatCommand"].Reset)
    elseif msg == "count" then
        self:PrintMessage(fmt(self.L["ChatCommand"].Count.Spells,
                              self:CountCache(self.db.profile.announcedSpells)))
        self:PrintMessage(fmt(self.L["ChatCommand"].Count.Pets,
                              self:CountCache(self.db.profile.petOwnerCache)))
        self:PrintMessage(fmt(self.L["ChatCommand"].Count.Ranks,
                              self:CountCache(self.db.profile.isMaxRank)))
    elseif msg == "clear" then
        self:ClearCache();
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage(fmt("%s = %s", self.L["Debug"],
                              tostring(self.db.profile.debug)));
    elseif msg == "whisper" then
        if not isTBC then
            self:PrintMessage("Whisper only supported on TBC");
            return
        end

        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage(fmt("%s = %s", self.L["Whisper"],
                              tostring(self.db.profile.whisper)));
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage(fmt("%s = %s", self.L["Enable"],
                              tostring(self.db.profile.enable)));
    elseif msg == "lead" then
        self.cluster.lead = self.playerName
        self:SetLead(self.playerName)
        self:PrintLead()
    elseif msg == "ignore" then
        if UnitExists("target") then
            self:IgnoreTarget();
        else
            self:PrintMessage(self.L["ChatCommand"].Ignore.Target);
            self:PrintMessage(fmt(self.L["ChatCommand"].Ignore.Count,
                                  self:CountCache(self.db.profile.ignoredPlayers)))
        end
    elseif "queue" == string.sub(msg, 1, #"queue") then
        local _, sub = strsplit(' ', msg)
        if sub == 'clear' or sub == 'reset' then
            local queued = #self.session.Queue
            self.session.Queue = {}

            self:PrintMessage(fmt(self.L["ChatCommand"].Queue.Clear, queued))
        elseif sub == 'process' or sub == 'send' then
            self:ProcessQueuedNotifications()
        else
            self:PrintMessage(fmt(self.L["ChatCommand"].Queue.Count,
                                  #self.session.Queue))
            local notification = nil

            for i = 1, #self.session.Queue do
                notification = self.session.Queue[i];
                self:PrintMessage(fmt("%s - %s", notification.target,
                                      notification.ability))
            end
        end
    elseif msg == "sync" then
        self:SyncBroadcast()
    elseif "report" == string.sub(msg, 1, #"report") then
        local _, channel = strsplit(' ', msg)

        local reportSize = self:CountCache(self.session.Report)

        if channel == nil then
            self:PrintMessage(fmt(self.L["ChatCommand"].Report.Header,
                                  reportSize))

            for _, reportEntry in pairs(self.session.Report) do
                print(fmt(self.L["ChatCommand"].Report.Summary,
                          reportEntry.PlayerName, reportEntry.SpellName,
                          reportEntry.SpellRank))
            end
        elseif string.lower(channel) == "say" or string.lower(channel) == "raid" or
            string.lower(channel) == "guild" then

            SendChatMessage(fmt(self.L["ChatCommand"].Report.Header,
                                self.L[addonName], reportSize), channel, nil)

            for key, reportEntry in pairs(self.session.Report) do
                SendChatMessage(fmt(self.L["ChatCommand"].Report.Summary,
                                    reportEntry.PlayerName,
                                    reportEntry.SpellName, reportEntry.SpellRank),
                                channel, nil)
                -- Remove entry after announcing to channel
                self.session.Report[key] = nil
            end
        else
            self:PrintMessage(fmt(self.L["ChatCommand"].Report.Unsupported,
                                  channel))
        end
    else
        self:PrintHelp()
    end
end

function addon:IsMaxRank(spellID, casterLevel, targetLevel)
    -- UnitLevel(destName) returns 0 for non-party members
    -- Ignore casts with larger than 10 level differences
    if targetLevel >= 1 and targetLevel < casterLevel - 10 then return true end

    local lookup_key = fmt('%s-%s', spellID, casterLevel);

    if self.db.profile.isMaxRank[lookup_key] ~= nil and
        not self.db.profile.debug then

        return self.db.profile.isMaxRank[lookup_key];
    end

    local abilityData = addon.AbilityData[spellID];

    local abilityGroupData = addon.AbilityGroups[abilityData["AbilityGroup"]]

    -- Vast majority of checks will be on lvl 70, check if highest available rank first
    if spellID == abilityGroupData[#abilityGroupData] then
        if self.db.profile.debug then
            self:PrintMessage("Caching max rank " .. lookup_key);
        end

        self.db.profile.isMaxRank[lookup_key] = true;

        return true
    end

    -- Above block guarantees there's another rank
    local nextRankID = abilityGroupData[abilityData["Rank"] + 1];

    local nextRankData = addon.AbilityData[nextRankID];

    -- Above logic assumes no ranks are excluded, breaks for Arcane Explosion at least
    -- If rank not the index, find proper rank
    if nextRankData == nil or nextRankData.Rank ~= abilityData.Rank + 1 then
        if self.db.profile.debug then
            self:PrintMessage(fmt(
                                  "Mismatching indices next rank (%d), performing search",
                                  abilityData["Rank"] + 1));
        end

        for _, checkedSpellID in pairs(abilityGroupData) do
            nextRankID = checkedSpellID;
            nextRankData = addon.AbilityData[checkedSpellID];

            if abilityData.Rank + 1 == nextRankData.Rank then
                if self.db.profile.debug then
                    self:PrintMessage(fmt("Found proper next rank (%d) for %s",
                                          nextRankData.Rank, nextRankID));
                end
                break
            end
        end
    end

    if nextRankData.Level == 0 then
        if self.db.profile.debug then
            self:PrintMessage(fmt("Failed to get next rank past %d, guessed %d",
                                  spellID, nextRankID));
        end
        return nil, -1
    end

    local isMax = self:IsHighestAlertableRank(nextRankData.Level, casterLevel)

    if self.db.profile.debug then
        self:PrintMessage(fmt(
                              "Casted %d, next rank (%d) available at %d, isMax %s",
                              spellID, nextRankID, nextRankData.Level,
                              tostring(isMax)));
    end

    self.db.profile.isMaxRank[lookup_key] = isMax;

    return isMax, nextRankData.Level
end
