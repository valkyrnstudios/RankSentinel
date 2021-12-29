-- addon name and a table scoped to our addon files is passed in by the wow client when the addon loads
-- we can use that to avoid polluting the global namespace shared by all addons.
local addonName, RankSentinel = ...

local addon = nil;

local isTBC = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC;
local isVanilla = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC;

if isTBC then
    addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName,
                                             "AceEvent-3.0", "AceComm-3.0")
elseif isVanilla then
    -- Clustering moot on classic, can only detect self spellIDs
    addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName,
                                             "AceEvent-3.0")
end

addon.Version = GetAddOnMetadata(addonName, "Version");

if string.match(addon.Version, 'project') then addon.Version = 'v9.9.9' end

addon._commPrefix = string.upper(addonName)

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:OnInitialize()
    local defaults = {
        profile = {
            enable = true,
            whisper = true,
            debug = false,
            combat = true,
            castString = L["CastString"],
            postMessageString = L["PostMessageString"],
            announcedSpells = {},
            ignoredPlayers = {},
            isMaxRank = {},
            dbVersion = 'v0.0.0'
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults, true)

    self.playerGUID = UnitGUID("Player");
    self.playerName = UnitName("Player");

    SLASH_RankSentinel1 = "/" .. string.lower(addonName);
    SLASH_RankSentinel2 = "/sentinel";

    SlashCmdList[addonName] =
        function(message, _) addon:ChatCommand(message) end;
end

function addon:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end

    if self.db.profile.dbVersion ~= addon.Version then
        self:PrintMessage("Addon version change, resetting cache");
        self:ClearCache();
    end
end

function addon:OnEnable()
    if WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
        self:RegisterEvent("PLAYER_ENTERING_WORLD");
        self:RegisterEvent("PLAYER_REGEN_ENABLED");

        self:RegisterComm(self._commPrefix);
        self:ResetLead();

        self.notificationsQueue = {};
    elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        -- SpellID not a parameter of COMBAT_LOG_EVENT_UNFILTERED in Classic era
        -- Self casted UNIT_SPELLCAST_SUCCEEDED contains spellID
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
        self:RegisterEvent("PLAYER_LEVEL_UP");

        self.playerLevel = UnitLevel("Player");
    end

    self:PrintMessage("Loaded " .. self.Version);

    self:UpgradeProfile();

    self.db.profile.dbVersion = self.Version;

    if self.db.profile.debug then
        self:PrintMessage("Debug enabled, clearing cache on reload");
        self:ClearCache();
    end
end

function addon:ChatCommand(cmd)
    local msg = string.lower(cmd)

    if msg == "reset" then
        self.db:ResetProfile()
        self:PrintMessage(string.format("Settings reset"))
    elseif msg == "count" then
        self:PrintMessage(string.format("Spells caught: %d", self:CountCache(
                                            self.db.profile.announcedSpells)))
        self:PrintMessage(string.format("Ignored players: %d", self:CountCache(
                                            self.db.profile.ignoredPlayers)))
        self:PrintMessage(string.format("Ranks cached: %d", self:CountCache(
                                            self.db.profile.isMaxRank)))
    elseif msg == "clear" then
        self:ClearCache();
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage("debug = " .. tostring(self.db.profile.debug));
    elseif msg == "whisper" then
        if not isTBC then
            self:PrintMessage("Whisper only supported on TBC");
            return
        end

        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage("whisper = " .. tostring(self.db.profile.whisper));
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage("enable = " .. tostring(self.db.profile.enable));
    elseif msg == "combat" then
        self.db.profile.combat = not self.db.profile.combat
        self:PrintMessage("combat = " .. tostring(self.db.profile.combat));
    elseif msg == "lead" then
        self:SetLead(self.playerName);
        self:PrintLead();
    elseif "ignore" then
        if UnitExists("target") then
            self:IgnoreTarget();
        else
            self:PrintMessage("Select a target to ignore");
            self:PrintMessage(string.format("Currently ignoring %d players",
                                            self:CountCache(
                                                self.db.profile.ignoredPlayers)))
        end
    else
        self:PrintHelp()
    end
end

function addon:PrintHelp()
    self:PrintMessage(string.format("%s (%s)", L['Help']['title'], self.Version))

    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'enable',
                                    tostring(self.db.profile.enable),
                                    L['Help']['enable']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'whisper',
                                    tostring(self.db.profile.whisper),
                                    L['Help']['whisper']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'combat',
                                    tostring(self.db.profile.combat),
                                    L['Help']['combat']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'debug',
                                    tostring(self.db.profile.debug),
                                    L['Help']['debug']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'reset',
                                    L['Help']['reset']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'count',
                                    L['Help']['count']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'clear',
                                    L['Help']['clear']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'lead',
                                    self.cluster.lead, L['Help']['lead']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'ignore playerName',
                                    L['Help']['ignore playerName']));
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, _ = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" or
        self.db.profile.ignoredPlayers[sourceGUID] ~= nil or
        addon.AbilityData[spellID] == nil or not self:InGroupWith(sourceGUID) then
        return
    end

    local castLevel = UnitLevel(sourceName)

    local PlayerSpellIndex = string.format("%s-%s-%s", sourceGUID, castLevel,
                                           spellID)

    if self.db.profile.announcedSpells[PlayerSpellIndex] ~= nil and
        not self.db.profile.debug then return end

    local isMax, nextRankLevel = self:IsMaxRank(spellID, castLevel);

    if isMax then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == self.playerGUID then
        castStringMsg = string.format(self.db.profile.castString, "You",
                                      spellLink, nextRankLevel)
        castStringMsg = string.format("%s %s", L["AnnouncePrefix"]["Self"],
                                      castStringMsg)

        addon:Annoy(castStringMsg, "self")

        self:RecordAnnoy(self.playerName, PlayerSpellIndex)
    else
        if self.db.profile.whisper then
            castStringMsg = string.format(self.db.profile.castString, "you",
                                          spellLink, nextRankLevel)
            castStringMsg = string.format("%s %s %s",
                                          L["AnnouncePrefix"]["Whisper"],
                                          castStringMsg,
                                          self.db.profile.postMessageString)

            addon:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(self.db.profile.castString,
                                          sourceName, spellLink, nextRankLevel)
            castStringMsg = string.format("%s %s", L["AnnouncePrefix"]["Self"],
                                          castStringMsg)

            addon:Annoy(castStringMsg, "self")
        end

        self:RecordAnnoy(self.playerName, PlayerSpellIndex)
    end
end

function addon:PLAYER_ENTERING_WORLD(...) self:SetLead(self.playerName); end

function addon:PLAYER_REGEN_ENABLED(...)
    -- If player dead, combat for rest of the raid could be ongoing
    if UnitIsDeadOrGhost("Player") then return end

    -- TODO trigger notification processing again without waiting for a combat cycle
    -- PLAYER_UNGHOST, PLAYER_ALIVE
    self:ProcessQueuedNotifications();
end

function addon:ProcessQueuedNotifications()
    if #self.notificationsQueue == 0 then return end

    self:PrintMessage(string.format(L["Queue"]["Processing"],
                                    #self.notificationsQueue));

    local notification = nil;

    for i = 1, #self.notificationsQueue do
        notification = self.notificationsQueue[i];

        SendChatMessage(notification.text, "WHISPER", nil, notification.target)
    end

    self.notificationsQueue = {};
end

function addon:Annoy(msg, target)
    if self.playerName == self.cluster.lead then
        if target == "self" then
            self:PrintMessage(msg);
        else
            self:QueueNotification(msg, target);
        end
    else
        self:PrintMessage(msg);
    end
end

function addon:InGroupWith(guid)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if guid == UnitGUID("Raid" .. i) then return true end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            if guid == UnitGUID("Party" .. i) then return true end
        end
    end
end

function addon:IsMaxRank(spellID, casterLevel)
    local lookup_key = string.format('%s-%s', spellID, casterLevel);

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
            self:PrintMessage(string.format(
                                  "Mismatching indices next rank (%d), performing search",
                                  abilityData["Rank"] + 1));
        end

        for _, checkedSpellID in pairs(abilityGroupData) do
            nextRankID = checkedSpellID;
            nextRankData = addon.AbilityData[checkedSpellID];

            if abilityData.Rank + 1 == nextRankData.Rank then
                if self.db.profile.debug then
                    self:PrintMessage(string.format(
                                          "Found proper next rank (%d) for %s",
                                          nextRankData.Rank, nextRankID));
                end
                break
            end
        end
    end

    local isMax = nextRankData.Level > casterLevel;

    if self.db.profile.debug then
        self:PrintMessage(string.format(
                              "Casted %d, next rank (%d) available at %d, isMax %s",
                              spellID, nextRankID, nextRankData.Level,
                              tostring(isMax)));
    end

    self.db.profile.isMaxRank[lookup_key] = isMax;

    return isMax, nextRankData.Level
end

function addon:QueueNotification(notification, target)
    if InCombatLockdown() and not self.db.profile.combat then
        self:PrintMessage(string.format("Queued - %s, %s", target, notification));

        self.notificationsQueue[#self.notificationsQueue + 1] = {
            text = notification,
            target = target
        };
    else
        SendChatMessage(notification, "WHISPER", nil, target)
    end
end

function addon:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. L[addonName] .. "|r: " ..
                                          msg, 0.0, 1.0, 0.0, 1.0);
    end
end
