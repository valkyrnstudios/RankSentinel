SpellSentinel = LibStub("AceAddon-3.0"):NewAddon("SpellSentinel",
                                                 "AceConsole-3.0",
                                                 "AceEvent-3.0", "AceComm-3.0")

SpellSentinel.Version = GetAddOnMetadata("SpellSentinel", "Version");

PlayerGUID = UnitGUID("Player");
PlayerName = UnitName("Player");

local SpellSentinel = SpellSentinel

local L = LibStub("AceLocale-3.0"):GetLocale("SpellSentinel")

local options = {
    name = L["SpellSentinel"],
    handler = SpellSentinel,
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
        ignoredPlayers = {}
    }
}

function SpellSentinel:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SpellSentinelDB", defaults, true)

    if not self.db.profile then self.db.profile.ResetProfile() end

    self:ClusterReset();

    LibStub("AceConfig-3.0"):RegisterOptionsTable("SpellSentinel", options)

    self:RegisterChatCommand("spellsentinel", "ChatCommand")
    self:RegisterChatCommand("sentinel", "ChatCommand")

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
                            "SpellSentinel", "SpellSentinel")
end

function SpellSentinel:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    self:RegisterComm(CommPrefix);

    self:PrintMessage("Loaded " .. self.Version);
end

function SpellSentinel:getProfileOption(info) return
    self.db.profile[info[#info]] end

function SpellSentinel:setProfileOption(info, value)
    local key = info[#info]
    self.db.profile[key] = value
end

function SpellSentinel:ChatCommand(cmd)
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
        InterfaceOptionsFrame_OpenToCategory("SpellSentinel")
    end
end

function SpellSentinel:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not self.db.profile.enable or UnitInBattleground("player") ~= nil then
        return
    end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, _ = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" then return end

    if self.db.profile.ignoredPlayers[sourceGUID] ~= nil then return end

    local curSpell = SpellSentinel.SpellIDs[spellID]

    if curSpell == nil or curSpell.MaxLevel == 0 then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if self.db.profile.announcedSpells[PlayerSpellIndex] ~= nil then return end

    local castLevel = UnitLevel(sourceName)
    local castString = self.db.profile.castString

    if curSpell.MaxLevel >= castLevel then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == PlayerGUID then
        castStringMsg = string.format(castString, "You", spellLink, castLevel)
        castStringMsg =
            string.format("%s %s", L["PreMsgNonChat"], castStringMsg)
        SpellSentinel:Annoy(castStringMsg, "self")

        self:RecordAnnoy(PlayerSpellIndex)
    elseif not SpellSentinel:InGroupWith(sourceGUID) then
        return
    else
        if self.db.profile.whisper then
            castStringMsg = string.format(castString, "You", spellLink,
                                          castLevel)
            castStringMsg = string.format("%s %s %s %s", L["PreMsgChat"],
                                          self.db.profile.preMessageString,
                                          castStringMsg,
                                          self.db.profile.postMessageString)
            SpellSentinel:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(castString, sourceName, spellLink,
                                          castLevel)
            castStringMsg = string.format("%s %s", L["PreMsgNonChat"],
                                          castStringMsg)
            SpellSentinel:Annoy(castStringMsg, "self")
        end

        self:RecordAnnoy(PlayerSpellIndex)
    end
end

function SpellSentinel:PLAYER_ENTERING_WORLD(...)
    self:JoinCluster(PlayerName, self.Version);

    self:ClusterElect();
end

function SpellSentinel:Annoy(msg, target)
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

function SpellSentinel:InGroupWith(guid)
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

function SpellSentinel:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. L["SpellSentinel"] ..
                                          "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end

