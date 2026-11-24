local addonName, addon = ...

local CreateFrame = _G.CreateFrame
local GetActionInfo = _G.GetActionInfo
local InCombatLockdown = _G.InCombatLockdown
local UnitLevel = _G.UnitLevel
local IsSpellKnown = _G.C_SpellBook and _G.C_SpellBook.IsSpellKnown or _G.IsSpellKnown
local FindSpellBookSlotForSpell = _G.C_SpellBook and _G.C_SpellBook.FindSpellBookSlotForSpell
local IsSpellBookItemLowRank = _G.C_SpellBook and _G.C_SpellBook.IsSpellBookItemLowRank
local GetNumSpellBookSkillLines = _G.C_SpellBook and _G.C_SpellBook.GetNumSpellBookSkillLines
local GetSpellBookSkillLineInfo = _G.C_SpellBook and _G.C_SpellBook.GetSpellBookSkillLineInfo
local GetSpellBookItemType = _G.C_SpellBook and _G.C_SpellBook.GetSpellBookItemType or _G.GetSpellBookItemInfo
local GetSpellBookItemName = _G.C_SpellBook and _G.C_SpellBook.GetSpellBookItemName or _G.GetSpellBookItemName
local GetSpellBookItemLevelLearned = _G.C_SpellBook and _G.C_SpellBook.GetSpellBookItemLevelLearned
    or _G.GetSpellAvailableLevel or _G.GetSpellLevelLearned
local GetNumSpellTabs = _G.GetNumSpellTabs
local GetSpellTabInfo = _G.GetSpellTabInfo
local AddTooltipPostCall = _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall
local isSecret = _G.issecretvalue or function() return false end

local playerSpellBank = GetNumSpellBookSkillLines and _G.Enum.SpellBookSpellBank.Player or _G.BOOKTYPE_SPELL
local futureSpell = GetNumSpellBookSkillLines and _G.Enum.SpellBookItemType.FutureSpell or "FUTURESPELL"
local highlights = {}
local scanEvents = {
    "LEARNED_SPELL_IN_SKILL_LINE",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD",
}

local actionBars = addon:NewModule("ActionBars", "AceEvent-3.0")
addon.actionBars = actionBars

local function getActionSpellID(slot)
    if isSecret(slot) or not slot or slot <= 0 then return end

    local actionType, spellID = GetActionInfo(slot)
    if not isSecret(actionType) and actionType == "spell" and not isSecret(spellID) then return spellID end
end

local function hasHigherRank(spellID)
    if FindSpellBookSlotForSpell and IsSpellBookItemLowRank then
        local index, bank = FindSpellBookSlotForSpell(spellID, true, false)
        if index then return bank == playerSpellBank and IsSpellBookItemLowRank(index, bank) end
    end

    local spell = addon.AbilityData and addon.AbilityData[spellID]
    if not spell or not IsSpellKnown then return false end

    for _, rankID in ipairs(addon.AbilityGroups[spell.AbilityGroup]) do
        if addon.AbilityData[rankID].Rank > spell.Rank and IsSpellKnown(rankID) then return true end
    end
    return false
end

function actionBars:Scan()
    if InCombatLockdown() then return end

    local buttonEvents = _G.ActionBarButtonEventsFrame
    if not buttonEvents or not buttonEvents.frames then return end

    local checkedSpells = {}
    for _, button in pairs(buttonEvents.frames) do
        local highlight = highlights[button]
        local slot = button.CalculateAction and button:CalculateAction() or button.action
        local spellID = getActionSpellID(slot)
        if spellID and checkedSpells[spellID] == nil then checkedSpells[spellID] = hasHigherRank(spellID) end
        local outdated = spellID and checkedSpells[spellID] or false

        if outdated and not highlight then
            highlight = CreateFrame("Frame", nil, button, "AutoCastOverlayTemplate")
            highlight:ClearAllPoints()
            highlight:SetAllPoints(button)
            highlight:SetAlpha(0.55)
            highlight.Corners:Hide()
            highlight:ShowAutoCastEnabled(true)
            highlights[button] = highlight
        elseif highlight and highlight:IsShown() ~= outdated then
            highlight:SetShown(outdated)
            highlight:ShowAutoCastEnabled(outdated)
        end
    end
end

function actionBars:PLAYER_LEVEL_UP(_, level)
    if addon.db.profile.scanActionBars then self:Scan() end
    if isSecret(level) or not level then return end

    local previousLevel = self.level or level - 1
    self.level = level
    if not addon.db.profile.notifyTrainerSpells or level <= previousLevel then return end
    if not (GetSpellBookItemType and GetSpellBookItemName and GetSpellBookItemLevelLearned) then return end
    if not (GetNumSpellBookSkillLines or GetNumSpellTabs) then return end

    local spells = {}
    local numLines = GetNumSpellBookSkillLines and GetNumSpellBookSkillLines() or GetNumSpellTabs()
    for line = 1, numLines do
        local offset, count
        if GetSpellBookSkillLineInfo then
            local info = GetSpellBookSkillLineInfo(line)
            if info and not info.isGuild and not info.shouldHide and not info.offSpecID then
                offset, count = info.itemIndexOffset, info.numSpellBookItems
            end
        else
            local _, _, start, size, isGuild, offSpecID, shouldHide = GetSpellTabInfo(line)
            if not isGuild and not shouldHide and (not offSpecID or offSpecID == 0) then
                offset, count = start, size
            end
        end

        for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
            if GetSpellBookItemType(index, playerSpellBank) == futureSpell then
                local requiredLevel = GetSpellBookItemLevelLearned(index, playerSpellBank)
                if requiredLevel and requiredLevel > previousLevel and requiredLevel <= level then
                    local name, rank = GetSpellBookItemName(index, playerSpellBank)
                    if name then
                        spells[#spells + 1] = rank and rank ~= "" and (name .. " (" .. rank .. ")") or name
                    end
                end
            end
        end
    end

    if #spells > 0 then
        table.sort(spells)
        addon:PrintMessage(addon.L["New trainer spells: %s"], table.concat(spells, ", "))
    end
end

function actionBars:OnInitialize()
    if not AddTooltipPostCall then return end

    AddTooltipPostCall(_G.Enum.TooltipDataType.Spell, function(tooltip)
        if tooltip ~= _G.GameTooltip or not self:IsEnabled() or not addon.db.profile.scanActionBars then return end

        local info = tooltip:GetProcessingTooltipInfo()
        if not info or info.getterName ~= "GetAction" then return end

        local spellID = getActionSpellID(info.getterArgs[1])
        if spellID and hasHigherRank(spellID) then
            tooltip:AddLine(" ")
            tooltip:AddLine(addon.MessageFormat:format(addon.L[addonName], _G.ADDON_INTERFACE_VERSION))
        end
    end)
end

function actionBars:OnEnable()
    local level = UnitLevel("player")
    self.level = not isSecret(level) and level and level > 0 and level or nil
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self:Setup(addon.db.profile.scanActionBars)
end

function actionBars:OnDisable()
    self:Setup(false)
end

function actionBars:Setup(enabled)
    if enabled then
        for _, event in ipairs(scanEvents) do self:RegisterEvent(event, "Scan") end
        self:Scan()
        return
    end

    for _, event in ipairs(scanEvents) do self:UnregisterEvent(event) end
    for _, highlight in pairs(highlights) do
        highlight:ShowAutoCastEnabled(false)
        highlight:Hide()
    end
end
