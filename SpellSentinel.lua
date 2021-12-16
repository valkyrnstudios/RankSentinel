local addonName, SpellSentinel = ...
SpellSentinel.Events = {}

local EventFrame = nil

local addonLoaded, variablesLoaded = false, false

local AnnouncedSpells = {}

SLASH_SpellSentinel1 = "/SpellSentinel"
SLASH_SpellSentinel2 = "/snob"

function SlashCmdList.SpellSentinel(cmd, editbox)
    local ssnob = "|cFFFFFF00Spell Snob|r"
    local enabled = "|cFF00FF00Enabled|r"
    local disabled = "|cFFFF0000Disabled|r"
    local out = nil

    local msg = string.lower(cmd)

    if msg == "self" then
        SpellSentinelVars.Whisper = false
        SpellSentinelVars.Enabled = true
        out = string.format("%s %s: Only show to self.", ssnob, enabled)
        print(out)
    elseif msg == "whisper" then
        SpellSentinelVars.Whisper = true
        SpellSentinelVars.Enabled = true
        out = string.format("%s %s: Whisper to others.", ssnob, enabled)
        print(out)
    elseif msg == "off" then
        SpellSentinelVars.Enabled = false
        SpellSentinelVars.Whisper = false
        out = string.format("%s %s.", ssnob, disabled)
        print(out)
    else
        local startStr = "|cFFFFFF00Spell Snob|r is currently %s."
        local modeStr = "in |cFF00FF00%s|r mode"
        local endStr =
            "Use |cFFFFFF00/SpellSentinel <option>|r or |cFFFFFF00/snob <option>|r to change."

        if SpellSentinelVars.Enabled then
            if SpellSentinelVars.Whisper then
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

        print("Options: /SpellSentinel <option>")
        print("  |cFFFFFF00Self|r: Only report low rank spell usage to self.")
        print(
            "  |cFFFFFF00Whisper|r: Whisper others about their low spell rank usage.")
        print("  |cFFFFFF00Off|r: Disable Spell Snob checks.")
    end
end

function SpellSentinel:OnLoad()
    EventFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    EventFrame:RegisterEvent("VARIABLES_LOADED")
    EventFrame:RegisterEvent("ADDON_LOADED")
    EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    EventFrame:SetScript("OnEvent", function(...) SpellSentinel:OnEvent(...) end)
end

function SpellSentinel:OnEvent(self, event, ...)
    if event == "VARIABLES_LOADED" then
        SpellSentinel.Events:VariablesLoaded(...)
    elseif event == "ADDON_LOADED" then
        SpellSentinel.Events:AddonLoaded(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        SpellSentinel.Events:CombatLogEventUnfiltered(...)
    end
end

function SpellSentinel.Events:CombatLogEventUnfiltered(...)
    if not SpellSentinelVars.Enabled then return end

    local _, subevent, _, sourceGUID, sourceName, _, _, _, destName, _, _,
          spellID, spellName = CombatLogGetCurrentEventInfo()

    if subevent ~= "SPELL_CAST_SUCCESS" then return end

    local curSpell = SpellSentinel.SpellIDs[spellID]

    if curSpell == nil then return end

    if curSpell.MaxLevel == 0 then return end

    local PlayerSpellIndex = string.format("%s-%s", sourceGUID, spellID)

    if AnnouncedSpells[PlayerSpellIndex] ~= nil then return end

    local Strings = SpellSentinel.Strings
    local castLevel, castString = nil, nil

    if curSpell.LevelBase == "Self" then
        castLevel = UnitLevel(sourceName)
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
        SpellSentinel:Annoy(castStringMsg, "self")
        AnnouncedSpells[PlayerSpellIndex] = true
    else
        if not SpellSentinel:InGroupWith(sourceGUID) then return end

        if SpellSentinelVars.Whisper then
            castStringMsg = string.format(castString, "You", spellLink, spellID,
                                          castLevel)
            castStringMsg = string.format("%s %s %s %s", Strings.PreMsgChat,
                                          Strings.PreMsgStandard, castStringMsg,
                                          Strings.PostMessage)
            SpellSentinel:Annoy(castStringMsg, sourceName)
        else
            castStringMsg = string.format(castString, sourceName, spellLink,
                                          spellID, castLevel)
            castStringMsg = string.format("%s %s", Strings.PreMsgNonChat,
                                          castStringMsg)
            SpellSentinel:Annoy(castStringMsg, "self")
        end

        AnnouncedSpells[PlayerSpellIndex] = true
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

function SpellSentinel.Events:VarsAndAddonLoaded()
    print("|cFFFFFF00Spell Snob|r Loaded")
    if not SpellSentinelVars then
        SpellSentinelVars = {Enabled = true, Whisper = true}
    end
end

function SpellSentinel.Events:AddonLoaded(...)
    if (...) == addonName then
        if variablesLoaded == true then
            SpellSentinel.Events:VarsAndAddonLoaded()
        else
            addonLoaded = true
        end
    end
end

function SpellSentinel.Events:VariablesLoaded(...)
    if addonLoaded == true then
        SpellSentinel.Events:VarsAndAddonLoaded()
    else
        variablesLoaded = true
    end
end

SpellSentinel:OnLoad()
