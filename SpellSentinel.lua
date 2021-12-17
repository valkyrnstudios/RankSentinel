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
        gui = {
            type = "execute",
            name = L["SpellSentinel"],
            guiHidden = true,
            func = function()
                InterfaceOptionsFrame_OpenToCategory("SpellSentinel")
                -- need to call it a second time as there is a bug where the first time it won't switch !BlizzBugsSuck has a fix
                InterfaceOptionsFrame_OpenToCategory("SpellSentinel")
            end
        },
        enable = {type = "toggle", name = L["Enable"], order = 1},
        whisper = {type = "toggle", name = L["Whisper"], order = 2}
    }
}

local defaults = {profile = {enable = true, whisper = true}}

function SpellSentinel:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SpellSentinelDB", defaults, true)

    if not self.db.profile then self.db.profile.ResetProfile() end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("SpellSentinel", options)

    self:RegisterChatCommand("spellsentinel", "ChatCommand")
    self:RegisterChatCommand("ss", "ChatCommand")

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
    local enabled = "|cFF00FF00" .. L["Enable"] .. "r"
    local disabled = "|cFFFF0000" .. L["Disable"] .. "r"
    local out = nil

    local msg = string.lower(cmd)

    if msg == "self" then
        self.db.profile.whisper = false
        self.db.profile.enable = true
        out = string.format("%s: Only show to self.", enabled)
        self:PrintMessage(out)
    elseif msg == "whisper" then
        self.db.profile.whisper = true
        self.db.profile.enable = true
        out = string.format("%s: Whisper to others.", enabled)
        self:PrintMessage(out)
    elseif msg == "off" then
        self.db.profile.enable = false
        self.db.profile.whisper = false
        out = string.format("%s.", disabled)
        self:PrintMessage(out)
    else
        local startStr = "Currently %s."
        local modeStr = "in |cFF00FF00%s|r mode"
        local endStr =
            "Use |cFFFFFF00/SpellSentinel option|r or |cFFFFFF00/sentinel option|r to change."

        if self.db.profile.enable then
            if self.db.profile.whisper then
                modeStr = string.format(modeStr, "Whisper")
            else
                modeStr = string.format(modeStr, "Self-only")
            end

            out = string.format("%s %s", enabled, modeStr)
            out = string.format(startStr, out)
            out = string.format("%s %s", out, endStr)
            self:PrintMessage(out)
        else
            out = string.format(startStr, disabled)
            out = string.format("%s %s", out, endStr)
            self:PrintMessage(out)
        end

        self:PrintMessage("Options: /spellsentinel option")
        self:PrintMessage(
            "  |cFFFFFF00Self|r: Only report low rank spell usage to self.")
        self:PrintMessage(
            "  |cFFFFFF00Whisper|r: Whisper others about their low spell rank usage.")
        self:PrintMessage("  |cFFFFFF00Off|r: Disable Spell Sentinel checks.")
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
        castString = L["SelfCast"]
    elseif curSpell.LevelBase == "Target" then -- Why does this exist? -SV
        castLevel = UnitLevel(destName)
        castString = L["TargetCast"]
    end

    if curSpell.MaxLevel >= castLevel then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == UnitGUID("Player") then
        castStringMsg = string.format(castString, "You", spellLink, spellID,
                                      castLevel)
        castStringMsg =
            string.format("%s %s", L["PreMsgNonChat"], castStringMsg)
        SpellSentinel:Annoy(castStringMsg, "self")
        AnnouncedSpells[PlayerSpellIndex] = true
    else
        if not SpellSentinel:InGroupWith(sourceGUID) then return end

        if self.db.profile.whisper then
            castStringMsg = string.format(castString, "You", spellLink, spellID,
                                          castLevel)
            castStringMsg = string.format("%s %s %s %s", L["PreMsgChat"],
                                          L["PreMsgStandard"], castStringMsg,
                                          L["PostMessage"])
            SpellSentinel:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(castString, sourceName, spellLink,
                                          spellID, castLevel)
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
