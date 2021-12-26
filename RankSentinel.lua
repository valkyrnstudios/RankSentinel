-- our addon name and a table scoped to our addon files is passed in by the wow client when the addon loads
-- we can use that to avoid polluting the global namespace shared by all addons.
local addonName, RankSentinel = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName, "AceEvent-3.0",
                                                "AceComm-3.0")

addon.Version = GetAddOnMetadata(addonName, "Version");
addon._commPrefix = string.upper(addonName)

if string.match(addon.Version, 'project') then
    addon.Version = 'v9.9.9'
end

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:OnInitialize()
    local defaults = {
        profile = {
            enable = true,
            whisper = true,
            debug = false,
            castString = L["CastString"],
            postMessageString = L["PostMessageString"],
            announcedSpells = {},
            ignoredPlayers = {},
            isMaxRank = {}
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults, true)

    if not self.db.profile then self.db.profile.ResetProfile() end

    self.playerGUID = UnitGUID("Player");
    self.playerName = UnitName("Player");

    self:UpgradeProfile();

    self:ClusterReset();

    SLASH_RankSentinel1 = "/"..string.lower(addonName);
    SLASH_RankSentinel2 = "/sentinel";

    SlashCmdList[addonName] = function(message, _)
        addon:ChatCommand(message)
    end;
end

function addon:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end
end

function addon:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    self:RegisterComm(addon._commPrefix);

    self:PrintMessage("Loaded " .. self.Version);

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
    elseif msg == "clear" then
        self:ClearCache();
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage("debug = " .. tostring(self.db.profile.debug));
    elseif msg == "whisper" then
        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage("whisper = " .. tostring(self.db.profile.whisper));
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage("enable = " .. tostring(self.db.profile.enable));
    elseif "cluster" == string.sub(msg, 1, #"cluster") then
        local _, sub = strsplit(' ', msg)

        if sub == "reset" then
            self:ClusterReset();
        elseif sub == "elect" then
            self:ClusterElect();
        else
            self:PrintCluster();
        end
    elseif "ignore" == string.sub(msg, 1, #"ignore") then
        local _, name = strsplit(' ', msg)
        if name then
            self:IgnorePlayer(name);
            self:PrintMessage("Ignored " .. name)
        else
            self:PrintMessage("Invalid parameter")
        end
    else
        addon:PrintHelp()
    end
end

function addon:PrintHelp()
    self:PrintMessage(string.format("%s (%s)", L['Help']['title'], self.Version))

    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'enable',
                                    L['Help']['enable']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'whisper',
                                    L['Help']['whisper']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'reset',
                                    L['Help']['reset']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'count',
                                    L['Help']['count']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'debug',
                                    L['Help']['debug']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'clear',
                                    L['Help']['clear']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'cluster',
                                    L['Help']['cluster']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'cluster reset',
                                    L['Help']['cluster reset']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'cluster elect',
                                    L['Help']['cluster elect']));
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
        addon.BCC.AbilityData[spellID] == nil then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if self.db.profile.announcedSpells[PlayerSpellIndex] ~= nil and
        not self.db.profile.debug then return end

    local castLevel = UnitLevel(sourceName)

    if self:IsMaxRank(spellID, castLevel) then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == self.playerGUID then
        castStringMsg = string.format(self.db.profile.castString, "You",
                                      spellLink, castLevel)
        castStringMsg = string.format("%s %s", L["AnnouncePrefix"]["Self"],
                                      castStringMsg)

        addon:Annoy(castStringMsg, "self")

        self:RecordAnnoy(PlayerSpellIndex)
    elseif not addon:InGroupWith(sourceGUID) then
        return
    else
        if self.db.profile.whisper then
            castStringMsg = string.format(self.db.profile.castString, "you",
                                          spellLink, castLevel)
            castStringMsg = string.format("%s %s %s",
                                          L["AnnouncePrefix"]["Whisper"],
                                          castStringMsg,
                                          self.db.profile.postMessageString)

            addon:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(self.db.profile.castString,
                                          sourceName, spellLink, castLevel)
            castStringMsg = string.format("%s %s", L["AnnouncePrefix"]["Self"],
                                          castStringMsg)

            addon:Annoy(castStringMsg, "self")
        end

        self:RecordAnnoy(PlayerSpellIndex)
    end
end

function addon:PLAYER_ENTERING_WORLD(...)
    self:JoinCluster(self.playerName, self.Version);

    self:ClusterElect();
end

function addon:Annoy(msg, target)
    if self.playerName == self.cluster.lead then
        if target == "self" then
            self:PrintMessage(msg)
        else
            SendChatMessage(msg, "WHISPER", nil, target)
        end
    else
        self:PrintMessage(msg)
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

    local abilityData = addon.BCC.AbilityData[spellID];

    local abilityGroupData =
        addon.BCC.AbilityGroups[abilityData["AbilityGroup"]]

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

    local nextRankData = addon.BCC.AbilityData[nextRankID];

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
            nextRankData = addon.BCC.AbilityData[checkedSpellID];

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

    return isMax
end

function addon:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. L["RankSentinel"] ..
                                          "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end

