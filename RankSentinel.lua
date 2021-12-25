RankSentinel = LibStub("AceAddon-3.0"):NewAddon("RankSentinel",
                                                "AceConsole-3.0",
                                                "AceEvent-3.0", "AceComm-3.0")

RankSentinel.Version = GetAddOnMetadata("RankSentinel", "Version");

PlayerGUID = UnitGUID("Player");
PlayerName = UnitName("Player");

local RankSentinel = RankSentinel

local L = LibStub("AceLocale-3.0"):GetLocale("RankSentinel")

local options = {
    name = L["RankSentinel"],
    handler = RankSentinel,
    type = "group",
    childGroups = "tree",
    get = "getProfileOption",
    set = "setProfileOption",
    args = {
        enable = {type = "toggle", name = L["Enable"], order = 1},
        whisper = {type = "toggle", name = L["Whisper"], order = 2},
        preMessageString = {
            type = 'input',
            name = L["PreMessageString"]["Title"],
            width = "full",
            order = 3,
            guiHidden = true
        },
        castString = {
            type = 'input',
            name = L["CastString"]["Title"],
            width = "full",
            order = 4,
            guiHidden = true
        },
        targetCastString = {
            type = 'input',
            name = L["TargetCastString"]["Title"],
            width = "full",
            order = 5,
            guiHidden = true
        },
        postMessageString = {
            type = 'input',
            name = L["PostMessageString"]["Title"],
            width = "full",
            order = 6,
            guiHidden = true
        }
    }
}

local defaults = {
    profile = {
        enable = true,
        whisper = true,
        debug = false,
        preMessageString = L["PreMessageString"]["Default"],
        castString = L["CastString"]["Default"],
        targetCastString = L["TargetCastString"]["Default"],
        postMessageString = L["PostMessageString"]["Default"],
        announcedSpells = {},
        ignoredPlayers = {},
        isMaxRank = {}
    }
}

function RankSentinel:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults, true)

    if not self.db.profile then self.db.profile.ResetProfile() end

    self:UpgradeProfile();

    self:ClusterReset();

    LibStub("AceConfig-3.0"):RegisterOptionsTable("RankSentinel", options)

    self:RegisterChatCommand("ranksentinel", "ChatCommand")
    self:RegisterChatCommand("sentinel", "ChatCommand")

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
                            "RankSentinel", "RankSentinel")
end

function RankSentinel:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end
end

function RankSentinel:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    self:RegisterComm(CommPrefix);

    self:PrintMessage("Loaded " .. self.Version);
end

function RankSentinel:getProfileOption(info) return self.db.profile[info[#info]] end

function RankSentinel:setProfileOption(info, value)
    local key = info[#info]
    self.db.profile[key] = value
end

function RankSentinel:ChatCommand(cmd)
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
        InterfaceOptionsFrame_Show()
        InterfaceOptionsFrame_OpenToCategory("RankSentinel")
    end
end

function RankSentinel:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, _ = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" or
        self.db.profile.ignoredPlayers[sourceGUID] ~= nil or
        RankSentinel.BCC.AbilityData[spellID] == nil then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if self.db.profile.announcedSpells[PlayerSpellIndex] ~= nil then return end

    local castLevel = UnitLevel(sourceName)

    if self:IsMaxRank(spellID, castLevel) then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    local castString = self.db.profile.castString

    if sourceGUID == PlayerGUID then
        castStringMsg = string.format(castString, "You", spellLink, castLevel)
        castStringMsg =
            string.format("%s %s", L["PreMsgNonChat"], castStringMsg)

        RankSentinel:Annoy(castStringMsg, "self")

        self:RecordAnnoy(PlayerSpellIndex)
    elseif not RankSentinel:InGroupWith(sourceGUID) then
        return
    else
        if self.db.profile.whisper then
            castStringMsg = string.format(castString, "You", spellLink,
                                          castLevel)
            castStringMsg = string.format("%s %s %s %s", L["PreMsgChat"],
                                          self.db.profile.preMessageString,
                                          castStringMsg,
                                          self.db.profile.postMessageString)

            RankSentinel:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(castString, sourceName, spellLink,
                                          castLevel)
            castStringMsg = string.format("%s %s", L["PreMsgNonChat"],
                                          castStringMsg)

            RankSentinel:Annoy(castStringMsg, "self")
        end

        self:RecordAnnoy(PlayerSpellIndex)
    end
end

function RankSentinel:PLAYER_ENTERING_WORLD(...)
    self:JoinCluster(PlayerName, self.Version);

    self:ClusterElect();
end

function RankSentinel:Annoy(msg, target)
    if PlayerName == self.cluster.lead then
        if target == "self" then
            self:PrintMessage(msg)
        else
            SendChatMessage(msg, "WHISPER", nil, target)
        end
    else
        self:PrintMessage(msg)
    end
end

function RankSentinel:InGroupWith(guid)
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

function RankSentinel:IsMaxRank(spellID, casterLevel)
    local lookup_key = string.format('%s-%s', spellID, casterLevel);

    if self.db.profile.isMaxRank[lookup_key] ~= nil then
        if self.db.profile.debug then
            self:PrintMessage("Using cached result for " .. lookup_key)
        end

        return self.db.profile.isMaxRank[lookup_key];
    end

    local abilityData = RankSentinel.BCC.AbilityData[spellID];

    local abilityGroupData =
        RankSentinel.BCC.AbilityGroups[abilityData["AbilityGroup"]]

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

    if self.db.profile.debug then
        self:PrintMessage(string.format(
                              "Casted %d, next rank (%d) available at %d",
                              spellID, nextRankID,
                              RankSentinel.BCC.AbilityData[nextRankID].Level));
    end

    local isMax = RankSentinel.BCC.AbilityData[nextRankID]['Level'] >
                      casterLevel;

    self.db.profile.isMaxRank[lookup_key] = isMax;

    return isMax
end

function RankSentinel:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. L["RankSentinel"] ..
                                          "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end

