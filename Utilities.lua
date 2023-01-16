local addonName, addon = ...

local fmt, strsplit, ssub, print = string.format, strsplit, string.sub, print
local pairs, tinsert = pairs, table.insert
local GetSpellLink, UnitGUID, GetNumGroupMembers, GetNumSubgroupMembers, GetPlayerInfoByGUID = GetSpellLink, UnitGUID,
    GetNumGroupMembers, GetNumSubgroupMembers, GetPlayerInfoByGUID
local IsInRaid, IsInGroup, IsGUIDInGroup = IsInRaid, IsInGroup, IsGUIDInGroup
local _G = _G

-- cache relevant unitids once so we don't do concat every call
local raidUnit, raidUnitPet = {}, {}
local partyUnit, partyUnitPet = {}, {}
for i = 1, _G.MAX_RAID_MEMBERS do
    raidUnit[i] = "raid" .. i
    raidUnitPet[i] = "raidpet" .. i
end
for i = 1, _G.MAX_PARTY_MEMBERS do
    partyUnit[i] = "party" .. i
    partyUnitPet[i] = "partypet" .. i
end

function addon:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel,
                                 petOwner)
    local spellLink = GetSpellLink(spellID)
    local abilityData = self.AbilityData[spellID]
    local contactName = petOwner and petOwner.OwnerName or sourceName
    local by = petOwner and fmt(self.notifications.By, sourceName) or ''
    local msg = nil
    local sourceUID = self:GetUID(sourceGUID)

    if self.db.profile.notificationFlavor == 'random' then
        self.notifications = self:GetRandomNotificationFlavor()
    end

    if sourceGUID == self.playerGUID then
        msg = fmt(self.notifications.Base, spellLink, abilityData.Rank, by,
            nextRankLevel)

        msg = fmt("%s %s", self.notifications.Prefix.Self, msg)

    elseif self.playerName == self.cluster.lead and self.db.profile.whisper then
        msg = fmt(self.notifications.Base, spellLink, abilityData.Rank, by,
            nextRankLevel)

        if self.session.PlayersNotified[sourceUID] == true or petOwner then
            msg = fmt("%s %s", self.notifications.Prefix.Whisper, msg)
        else
            msg = fmt("%s %s %s", self.notifications.Prefix.Whisper, msg,
                self.notifications.Suffix)
        end
    else
        msg = fmt(self.notifications.Base, sourceName, spellLink,
            abilityData.Rank, by, nextRankLevel)

        msg = fmt("%s %s", self.notifications.Prefix.Self, msg)
    end

    self.session.PlayersNotified[sourceUID] = true

    return msg, contactName, fmt('%s (Rank %d)', spellLink, abilityData.Rank)
end

function addon:GetUID(guid)
    local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)

    if unitType == "Pet" then return fmt("Pet-%s", ssub(spawnUID, 3)) end

    return guid
end

function addon:IgnoreTarget()
    local guid = UnitGUID("target")
    if not guid then
        self:PrintMessage(self.L["Utilities"].IgnorePlayer.Error)
        return
    end

    local name, _ = UnitName("target")

    if self.db.profile.ignoredPlayers[guid] == nil then
        self:PrintMessage(self.L["Utilities"].IgnorePlayer.Ignored, name)
        self.db.profile.ignoredPlayers[guid] = name
    else
        self:PrintMessage(self.L["Utilities"].IgnorePlayer.Unignored, name)
        self.db.profile.ignoredPlayers[guid] = nil
    end
end

function addon:InGroupWith(guid)
    if guid == self.playerGUID then
        return true, nil
    elseif strsplit("-", guid) == 'Pet' then
        return self:IsPetOwnerInRaid(guid)
    elseif GetNumGroupMembers() > 1 then
        return IsGUIDInGroup(guid)
    end
end

function addon:IsLeaderInGroup()
    local leader = self.cluster.lead
    if self.playerName == leader then
        return true
    elseif IsInGroup() then
        if not IsInRaid() then
            for i = 1, GetNumSubgroupMembers() do
                if leader == UnitName(partyUnit[i]) then return true end
            end
        else
            for i = 1, GetNumGroupMembers() do
                if leader == UnitName(raidUnit[i]) then return true end
            end
        end
    end
end

function addon:InitializeSession()
    self.session = {
        Queue = {},
        Report = {},
        UnsupportedComm = {},
        PlayersNotified = {},
        PlayerGroupsNotified = {},
        announceTo = "self",
        PlayerLevelCache = {}
    }

    if IsInRaid() then
        self.session.announceTo = "raid"
    elseif IsInGroup() then
        self.session.announceTo = "party"
    end
end

function addon:IsHighestAlertableRank(nextRankLevel, casterLevel)
    if casterLevel == 80 then
        return nextRankLevel > casterLevel
    elseif casterLevel < 10 then
        return nextRankLevel > casterLevel
    elseif casterLevel < 20 then
        return nextRankLevel + 3 > casterLevel
    elseif casterLevel < 70 then
        return nextRankLevel + 2 > casterLevel
    elseif casterLevel < 80 then
        return nextRankLevel + 1 > casterLevel
    end

    return nextRankLevel > casterLevel
end

function addon:IsPetOwnerInRaid(petGuid)
    local petUID = self:GetUID(petGuid)

    if petGuid == UnitGUID("pet") then
        self.db.profile.petOwnerCache[petUID] = self.db.profile.petOwnerCache[petUID] or {
            OwnerName = self.playerName,
            OwnerGUID = self.playerGUID
        }
        return true, self.db.profile.petOwnerCache[petUID]
    end
    local _, ownerId, ownerName, groupPetId

    if self.db.profile.petOwnerCache[petUID] ~= nil then
        -- :InGroupWith() calls :IsPetOwnerInRaid make sure we never infinite recurse?
        local isInGroup, _ = self:InGroupWith(
            self.db.profile.petOwnerCache[petUID].OwnerGUID)

        return isInGroup, self.db.profile.petOwnerCache[petUID]
    end

    if IsInGroup() then
        if not IsInRaid() then
            for i = 1, GetNumSubgroupMembers() do
                groupPetId = UnitGUID(partyUnitPet[i])
                if not groupPetId then break end
                if petGuid ~= groupPetId then break end
                ownerId = UnitGUID(partyUnit[i])
                if not ownerId then break end
                if petGuid == groupPetId then
                    _, _, _, _, _, ownerName, _ = GetPlayerInfoByGUID(ownerId)

                    self.db.profile.petOwnerCache[petUID] = {
                        OwnerName = ownerName,
                        OwnerGUID = ownerId
                    }
                    return true, self.db.profile.petOwnerCache[petUID]
                end
            end
        else
            for i = 1, GetNumGroupMembers() do
                groupPetId = UnitGUID(raidUnitPet[i])
                if not groupPetId then break end
                if petGuid ~= groupPetId then break end
                ownerId = UnitGUID(raidUnit[i])
                if not ownerId then break end
                if petGuid == groupPetId then
                    _, _, _, _, _, ownerName, _ = GetPlayerInfoByGUID(ownerId)

                    self.db.profile.petOwnerCache[petUID] = {
                        OwnerName = ownerName,
                        OwnerGUID = ownerId
                    }
                    return true, self.db.profile.petOwnerCache[petUID]
                end
            end
        end
    end
end

function addon:PrintHelp(subHelp)
    if subHelp == 'advanced' then
        self:PrintMessage("%s (%s)", self.L['Help']['advanced'],
            self.Version)

        self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'debug',
            tostring(self.db.profile.debug),
            self.L['Help']['debug'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'clear',
            self.L['Help']['clear'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'ignore',
            self.L['Help']['ignore'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue',
            self.L['Help']['queue'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue clear',
            self.L['Help']['queue clear'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue process',
            self.L['Help']['queue process'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'reset',
            self.L['Help']['reset'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'sync',
            self.L['Help']['sync'])

        return
    end

    self:PrintMessage("%s (%s)", self.L['Help']['title'], self.Version)

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'enable',
        tostring(self.db.profile.enable),
        self.L['Help']['enable'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'whisper',
        tostring(self.db.profile.whisper),
        self.L['Help']['whisper'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'report [channel]',
        self.L['Help']['report [channel]'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'count',
        self.L['Help']['count'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'lead',
        self.cluster.lead, self.L['Help']['lead'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'flavor',
        self.db.profile.notificationFlavor,
        self.L['Help']['flavor'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'flavor [option]',
        self.L['Help']['flavor [option]'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'advanced',
        self.L['Help']['advanced'])
end

function addon:PrintMessage(msg, ...)
    print(fmt("|cFFFFFF00%s|r: |c0000FF00%s|r", self.L[addonName], fmt(msg, ...)))
end

function addon:SetNotificationFlavor(flavor)
    if self.L["Notification"][flavor] ~= nil then
        self.notifications = self.L["Notification"][self.db.profile
            .notificationFlavor]
        self.db.profile.notificationFlavor = flavor
    else
        self:PrintMessage(self.L["ChatCommand"].Flavor.Unavailable,
            flavor or '')
        self.db.profile.notificationFlavor = "default"
        self.notifications = self.L["Notification"]["default"]
    end
end

function addon:GetRandomNotificationFlavor()
    local keyset = {}

    for k, v in pairs(self.L["Notification"]) do
        if v and v.By ~= nil then tinsert(keyset, k) end
    end

    return self.L["Notification"][keyset[math.random(#keyset)]]
end

function addon:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end
    if not self.db.profile.petOwnerCache then
        self.db.profile.petOwnerCache = {}
    end

    if self.db:GetCurrentProfile() == "Default" then
        self:PrintMessage("Old profile detected, resetting database")
        self.db:ResetDB()
    elseif self.db.profile.dbVersion ~= addon.Version and addon.Version ~=
        'v0.0.0' then
        self:PrintMessage(self.L["Utilities"].Upgrade)
        if not self.db.profile.isLatestVersion then
            -- Re-enable automatically disabled version
            self.db.profile.enabled = true
        end
        self.db.profile.isLatestVersion = true
        self:ClearCache()
    end

    for k, v in pairs(self.db.profile.ignoredPlayers) do
        if v == true then
            self.db.profile.ignoredPlayers[k] = nil
        end
    end
end

local function GetProfileOption(info)
    return addon.db.profile[info[#info]]
end

local function SetProfileOption(info, value)
    addon.db.profile[info[#info]] = value
end

function addon:BuildOptionsPanel()
    local optionsWidth = 1.08

    local optionsTable = {
        type = "group",
        name = function()
            return fmt("%s - %s%s", self.L[addonName], addon.Version,
                self.db.profile.isLatestVersion and '' or (' - ' .. self.L["Utilities"]["Outdated"]))
        end,
        get = GetProfileOption,
        set = SetProfileOption,
        args = {
            cacheCount = {
                name = fmt(self.L["ChatCommand"].Count.Spells,
                    self:CountCache(self.db.profile.announcedSpells)),
                type = "description",
                width = optionsWidth,
                fontSize = "medium",
                order = 0.1
            },
            ranksCached = {
                name = fmt(self.L["ChatCommand"].Count.Ranks,
                    self:CountCache(self.db.profile.isMaxRank)),
                type = "description",
                width = optionsWidth,
                fontSize = "medium",
                order = 0.2
            },
            generalHeader = {
                name = _G.GENERAL,
                type = "header",
                width = "full",
                order = 1.0
            },
            enable = {
                name = _G.ENABLE,
                desc = self.L['Help']['enable'],
                type = "toggle",
                width = optionsWidth,
                order = 1.1,
                set = function(_, value)
                    self.db.profile.enable = value

                    if value then
                        self:Broadcast("JOIN", fmt("%s,%d", self.playerName, addon.release.int))
                    end
                end,
                disabled = function()
                    return not self.db.profile.isLatestVersion
                end
            },
            whisper = {
                name = _G.WHISPER,
                desc = self.L['Help']['whisper'],
                type = "toggle",
                width = optionsWidth,
                order = 1.2,
            },
            onlyMaxLevel = {
                name = "Max level only",
                desc = fmt("Only notify level %d characters", addon.MaxLevel),
                type = "toggle",
                width = optionsWidth,
                order = 1.3,
            },
            announceHeader = {
                name = "Announce",
                type = "header",
                width = "full",
                order = 2.0
            },
            announce = {
                name = _G.BNET_REPORT,
                desc = self.L['Help']['report [channel]'],
                type = "execute",
                width = optionsWidth,
                order = 2.1,
                func = function()
                    self:ReportToChannel(self.session.announceTo)
                end
            },
            announceTo = {
                name = _G.CHANNEL,
                type = "select",
                width = optionsWidth,
                order = 2.2,
                values = { ["self"] = "self", ["say"] = "say", ["party"] = "party", ["raid"] = "raid",
                    ["guild"] = "guild" },
                get = function()
                    return self.session.announceTo
                end,
                set = function(_, value)
                    self.session.announceTo = value
                end
            },
            clusterHeader = {
                name = "Cluster",
                type = "header",
                width = "full",
                order = 3.0
            },
            leader = {
                name = function()
                    return "Leader: " .. self.cluster.lead
                end,
                type = "description",
                width = optionsWidth,
                fontSize = "medium",
                order = 3.1
            },
            takeLead = {
                name = "Take lead",
                desc = self.L['Help']['lead'],
                type = "execute",
                width = optionsWidth,
                order = 3.2,
                func = function()
                    self.cluster.lead = self.playerName
                    self:BroadcastLead(self.playerName)
                end,
                disabled = function()
                    return self.playerName == self.cluster.lead
                end
            },
            flavorHeader = {
                name = "Notification Flavor",
                type = "header",
                width = "full",
                order = 4.0
            },
            notificationFlavor = {
                name = "Flavors",
                desc = self.L['Help']['flavor [option]'],
                type = "select",
                width = optionsWidth,
                order = 4.1,
                set = function(_, value)
                    self:SetNotificationFlavor(value)
                end,
                values = function()
                    local p = {}
                    for flavor, _ in pairs(self.L["Notification"]) do
                        p[flavor] = flavor
                    end
                    return p
                end,
            },
            notificationFlavorExample = {
                name = function()
                    local flavor = self.db.profile.notificationFlavor

                    if self.L["Notification"][flavor] and
                        self.L["Notification"][flavor].Base ~= nil then
                        return fmt('  ' .. self.L["Notification"][flavor]
                            .Base, '[Spell]', '9', '',
                            '62')
                    else
                        return ''
                    end
                end,
                type = "description",
                width = optionsWidth * 2,
                fontSize = "medium",
                order = 4.2
            },
            ignoreHeader = {
                name = "Ignore",
                type = "header",
                width = "full",
                order = 5.0
            },
            ignore = {
                name = _G.IGNORE_PLAYER,
                type = "execute",
                desc = self.L['Help']['ignore'],
                width = optionsWidth,
                order = 5.1,
                func = function()
                    if UnitExists("target") then
                        self:IgnoreTarget()
                    end
                end
            },
            ignoredPlayersList = {
                name = "Ignored Players",
                type = "select",
                width = optionsWidth,
                order = 5.2,
                values = function()
                    local p = {}
                    for _, v in pairs(self.db.profile.ignoredPlayers) do
                        p[v] = v
                    end
                    return p
                end,
                set = function(_, value)
                    self.session.ignoredSelectedPlayer = value
                end,
                get = function()
                    return self.session.ignoredSelectedPlayer
                end,
                disabled = function()
                    return self:CountCache(self.db.profile.ignoredPlayers) == 0
                end
            },
            removeIgnore = {
                name = _G.IGNORE_REMOVE,
                type = "execute",
                width = optionsWidth,
                order = 5.3,
                func = function()
                    for k, v in pairs(self.db.profile.ignoredPlayers) do
                        if v == self.session.ignoredSelectedPlayer then
                            self.db.profile.ignoredPlayers[k] = nil
                            break
                        end
                    end
                end,
                disabled = function()
                    return self:CountCache(self.db.profile.ignoredPlayers) == 0 or
                        self.session.ignoredSelectedPlayer == nil
                end
            },

        }
    }

    addon.options = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.L[addonName])
    LibStub("AceConfig-3.0"):RegisterOptionsTable(self.L[addonName], optionsTable)
end

function addon:ReportToChannel(channel)
    local reportSize = self:CountCache(self.session.Report)

    if channel == nil or channel == "self" then
        self:PrintMessage(self.L["ChatCommand"].Report.Header, '',
            reportSize)

        for _, reportEntry in pairs(self.session.Report) do
            print(fmt(self.L["ChatCommand"].Report.Summary,
                reportEntry.PlayerName, reportEntry.SpellName,
                reportEntry.SpellRank))
        end
    elseif channel == "say" or channel == "party" or channel == "raid" or
        channel == "guild" then
        SendChatMessage(fmt(self.L["ChatCommand"].Report.Header,
            self.L[addonName] .. ': ', reportSize), channel,
            nil)

        for key, reportEntry in pairs(self.session.Report) do
            SendChatMessage(fmt(self.L["ChatCommand"].Report.Summary,
                reportEntry.PlayerName,
                reportEntry.SpellName, reportEntry.SpellRank),
                channel, nil)
            -- Remove entry after announcing to channel
            self.session.Report[key] = nil
        end
    end
end
