local addonName, SpellSnob = ...
SpellSnob.Events = {}

local EventFrame = nil

local addonLoaded, variablesLoaded = false, false

local AnnouncedSpells = {}

SLASH_SPELLSNOB1 = "/spellsnob"
SLASH_SPELLSNOB2 = "/snob"

function SlashCmdList.SPELLSNOB(cmd, editbox)
    local ssnob = "|cFFFFFF00Spell Snob|r"
    local enabled = "|cFF00FF00Enabled|r"
    local disabled = "|cFFFF0000Disabled|r"
    local out = nil

    msg = string.lower(cmd)

    if msg == "self" then
        SpellSnobVars.Whisper = false
        SpellSnobVars.Enabled = true
        out = string.format("%s %s: Only show to self.", ssnob, enabled)
        print(out)
        return
    end

    if msg == "whisper" then
        SpellSnobVars.Whisper = true
        SpellSnobVars.Enabled = true
        out = string.format("%s %s: Whisper to others.", ssnob, enabled)
        print(out)
        return
    end

    if msg == "off" then
        SpellSnobVars.Enabled = false
        SpellSnobVars.Whisper = false
        out = string.format("%s %s.", ssnob, disabled)
        print(out)
        return
    end

    if msg == "" then
        local startStr = "|cFFFFFF00Spell Snob|r is currently %s."
        local modeStr = "in |cFF00FF00%s|r mode"
        local endStr =
            "Use |cFFFFFF00/spellsnob <option>|r or |cFFFFFF00/snob <option>|r to change."

        if SpellSnobVars.Enabled then
            if SpellSnobVars.Whisper then
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

        print("Options: /spellsnob <option>")
        print("  |cFFFFFF00Self|r: Only report low rank spell usage to self.")
        print(
            "  |cFFFFFF00Whisper|r: Whisper others about their low spell rank usage.")
        print("  |cFFFFFF00Off|r: Disable Spell Snob checks.")
    end
end

function SpellSnob:OnLoad()
    EventFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    EventFrame:RegisterEvent("VARIABLES_LOADED")
    EventFrame:RegisterEvent("ADDON_LOADED")
    EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    EventFrame:SetScript("OnEvent", function(...) SpellSnob:OnEvent(...) end)
end

function SpellSnob:OnEvent(self, event, ...)
    if event == "VARIABLES_LOADED" then
        SpellSnob.Events:VariablesLoaded(...)
    elseif event == "ADDON_LOADED" then
        SpellSnob.Events:AddonLoaded(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        SpellSnob.Events:CombatLogEventUnfiltered(...)
    end
end

function SpellSnob.Events:CombatLogEventUnfiltered(...)
    if not SpellSnobVars.Enabled then return end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, spellName = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" then return end

    local curSpell = SpellSnob.SpellIDs[spellID]

    if curSpell == nil then return end

    if curSpell.MaxLevel == 0 then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if AnnouncedSpells[PlayerSpellIndex] ~= nil then return end

    local Strings = SpellSnob.Strings
    local castLevel, castString = nil, nil

    if curSpell.LevelBase == "Self" then
        castLevel = UnitLevel("Player")
        castString = Strings.SelfCast
    elseif curSpell.LevelBase == "Target" then -- Why does this exist? -SV
        castLevel = UnitLevel(destName)
        castString = Strings.TargetCast
    end

    if curSpell.MaxLevel >= castLevel then return end

    local spellLink = GetSpellLink(spellID)
    local castStringMsg = nil

    if sourceGUID == UnitGUID("Player") then
        castStringMsg = string.format(castString, "You", spellLink, spellID,
                                      castLevel)
        castStringMsg = string.format("%s %s", Strings.PreMsgNonChat,
                                      castStringMsg)
        SpellSnob:Annoy(castStringMsg, "self")
        AnnouncedSpells[PlayerSpellIndex] = true
    else
        if not SpellSnob:InGroupWith(sourceGUID) then return end

        if SpellSnobVars.Whisper then
            castStringMsg = string.format(castString, "You", spellLink, spellID,
                                          castLevel)
            castStringMsg = string.format("%s %s %s %s", Strings.PreMsgChat,
                                          Strings.PreMsgStandard, castStringMsg,
                                          Strings.PostMessage)
            SpellSnob:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(castString, sourceName, spellLink,
                                          spellID, castLevel)
            castStringMsg = string.format("%s %s", Strings.PreMsgNonChat,
                                          castStringMsg)
            SpellSnob:Annoy(castStringMsg, "self")
        end

        AnnouncedSpells[PlayerSpellIndex] = true
    end
end

function SpellSnob:Annoy(msg, target)
    if target == "self" then
        print(msg)
    else
        SendChatMessage(msg, "WHISPER", nil, target)
    end
end

function SpellSnob:InGroupWith(guid)
    for i = 1, 4 do if guid == UnitGUID("Party" .. i) then return true end end
    for i = 1, 40 do if guid == UnitGUID("Raid" .. i) then return true end end
end

function SpellSnob.Events:VarsAndAddonLoaded()
    print("|cFFFFFF00Spell Snob|r Loaded")
    if not SpellSnobVars then
        SpellSnobVars = {Enabled = true, Whisper = true}
    end
end

function SpellSnob.Events:AddonLoaded(...)
    if (...) == addonName then
        if variablesLoaded == true then
            SpellSnob.Events:VarsAndAddonLoaded()
        else
            addonLoaded = true
        end
    end
end

function SpellSnob.Events:VariablesLoaded(...)
    if addonLoaded == true then
        SpellSnob.Events:VarsAndAddonLoaded()
    else
        variablesLoaded = true
    end
end

SpellSnob:OnLoad()
