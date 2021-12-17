SpellSentinel = LibStub("AceAddon-3.0"):NewAddon("SpellSentinel",
                                                 "AceConsole-3.0",
                                                 "AceEvent-3.0")

local AnnouncedSpells = {}

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
            order = 3
        },
        castString = {
            type = 'input',
            name = L["CastString"]["Title"],
            width = "full",
            order = 4
        },
        targetCastString = {
            type = 'input',
            name = L["TargetCastString"]["Title"],
            width = "full",
            order = 5
        },
        postMessageString = {
            type = 'input',
            name = L["PostMessageString"]["Title"],
            width = "full",
            order = 6
        }
    }
}

local defaults = {
    profile = {
        enable = true,
        whisper = true,
        preMessageString = L["PreMessageString"]["Default"],
        castString = L["CastString"]["Default"],
        targetCastString = L["TargetCastString"]["Default"],
        postMessageString = L["PostMessageString"]["Default"]
    }
}

function SpellSentinel:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SpellSentinelDB", defaults, true)

    if not self.db.profile then self.db.profile.ResetProfile() end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("SpellSentinel", options)

    self:RegisterChatCommand("spellsentinel", "ChatCommand")
    self:RegisterChatCommand("sentinel", "ChatCommand")

    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
                            "SpellSentinel", "SpellSentinel")
end

function SpellSentinel:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

    self:PrintMessage("Loaded")
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
    else
        InterfaceOptionsFrame_Show()
        InterfaceOptionsFrame_OpenToCategory("SpellSentinel")
    end
end

function SpellSentinel:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not self.db.profile.enable then return end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, _ = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" then return end

    local curSpell = SpellSentinel.SpellIDs[spellID]

    if curSpell == nil then return end

    if curSpell.MaxLevel == 0 then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if AnnouncedSpells[PlayerSpellIndex] ~= nil then return end

    local castLevel, castString = nil, nil

    if curSpell.LevelBase == "Self" then
        castLevel = UnitLevel(sourceName)
        castString = self.db.profile.castString
    elseif curSpell.LevelBase == "Target" then -- Why does this exist? -SV
        castLevel = UnitLevel(destName)
        castString = self.db.profile.targetCastString
    end

    if curSpell.MaxLevel >= castLevel then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == UnitGUID("Player") then
        castStringMsg = string.format(castString, "You", spellLink, castLevel)
        castStringMsg =
            string.format("%s %s", L["PreMsgNonChat"], castStringMsg)
        SpellSentinel:Annoy(castStringMsg, "self")
        AnnouncedSpells[PlayerSpellIndex] = true
    else
        if not SpellSentinel:InGroupWith(sourceGUID) then return end

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

        AnnouncedSpells[PlayerSpellIndex] = true -- TODO allow spam
    end
end

function SpellSentinel:Annoy(msg, target)
    if target == "self" then
        self:PrintMessage(msg)
    else
        SendChatMessage(msg, "WHISPER", nil, target)
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
    else
        self:PrintMessage("InGroupWith logic failure")
    end
end

function SpellSentinel:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. L["SpellSentinel"] ..
                                          "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end
