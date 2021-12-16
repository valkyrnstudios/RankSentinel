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

    print("|cFFFFFF00Spell Sentinel|r Loaded")
end

function SpellSentinel:getProfileOption(info) return
    self.db.profile[info[#info]] end

function SpellSentinel:setProfileOption(info, value)
    local key = info[#info]
    self.db.profile[key] = value
end

function SpellSentinel:ChatCommand(cmd)
    local ssentinel = "|cFFFFFF00Spell Sentinel|r"
    local enabled = "|cFF00FF00Enabled|r"
    local disabled = "|cFFFF0000Disabled|r"
    local out = nil

    local msg = string.lower(cmd)

    if msg == "self" then
        self.db.profile.whisper = false
        self.db.profile.enable = true
        out = string.format("%s %s: Only show to self.", ssentinel, enabled)
        print(out)
    elseif msg == "whisper" then
        self.db.profile.whisper = true
        self.db.profile.enable = true
        out = string.format("%s %s: Whisper to others.", ssentinel, enabled)
        print(out)
    elseif msg == "off" then
        self.db.profile.enable = false
        self.db.profile.whisper = false
        out = string.format("%s %s.", ssentinel, disabled)
        print(out)
    else
        local startStr = "|cFFFFFF00Spell Sentinel|r is currently %s."
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
            print(out)
        else
            out = string.format(startStr, disabled)
            out = string.format("%s %s", out, endStr)
            print(out)
        end

        print("Options: /spellsentinel option")
        print("  |cFFFFFF00Self|r: Only report low rank spell usage to self.")
        print(
            "  |cFFFFFF00Whisper|r: Whisper others about their low spell rank usage.")
        print("  |cFFFFFF00Off|r: Disable Spell Sentinel checks.")
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
        print(msg)
    else
        SendChatMessage(msg, "WHISPER", nil, target)
    end
end

function SpellSentinel:InGroupWith(guid)
    for i = 1, 4 do if guid == UnitGUID("Party" .. i) then return true end end
    for i = 1, 40 do if guid == UnitGUID("Raid" .. i) then return true end end
end
