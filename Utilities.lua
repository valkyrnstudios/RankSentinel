local addonName, addon = ...

local fmt = string.format

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

    elseif self.db.profile.whisper and self.playerName == self.cluster.lead then
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
        msg = msg:gsub(addonName, self.cluster.lead)
    end

    self.session.PlayersNotified[sourceUID] = true

    return msg, contactName, fmt('%s (Rank %d)', spellLink, abilityData.Rank)
end

function addon:GetUID(guid)
    local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)

    if unitType == "Pet" then return fmt("Pet-%s", string.sub(spawnUID, 3)) end

    return guid
end

function addon:IgnoreTarget()
    local guid = UnitGUID("target")
    if not guid then
        self:PrintMessage(self.L["Utilities"].IgnorePlayer.Error)
        return
    end

    local name, _ = UnitName("target")

    if self.db.profile.ignoredPlayers[guid] ~= true then
        self:PrintMessage(fmt(self.L["Utilities"].IgnorePlayer.Ignored, name))
        self.db.profile.ignoredPlayers[guid] = true
    else
        self:PrintMessage(fmt(self.L["Utilities"].IgnorePlayer.Unignored, name))
        self.db.profile.ignoredPlayers[guid] = nil
    end
end

function addon:InGroupWith(guid)
    if guid == self.playerGUID then
        return true, nil
    elseif strsplit("-", guid) == 'Pet' then
        return self:IsPetOwnerInRaid(guid)
    elseif IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if guid == UnitGUID("Raid" .. i) then return true, nil end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            if guid == UnitGUID("Party" .. i) then return true, nil end
        end
    end
end

function addon:InitializeSession()
    self.session = {
        Queue = {},
        Report = {},
        UnsupportedComm = {},
        PlayersNotified = {}
    }
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

    local ownerId, ownerName = nil, nil

    if self.db.profile.petOwnerCache[petUID] ~= nil then
        local isInGroup, _ = self:InGroupWith(
            self.db.profile.petOwnerCache[petUID].OwnerGUID)

        return isInGroup, self.db.profile.petOwnerCache[petUID];
    end

    if petGuid == UnitGUID("pet") then
        self.db.profile.petOwnerCache[petUID] = {
            OwnerName = self.playerName,
            OwnerGUID = self.playerGUID
        }

        return true, self.db.profile.petOwnerCache[petUID]
    elseif IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if petGuid == UnitGUID("RaidPet" .. i) then
                ownerId = UnitGUID("Raid" .. i)

                _, _, _, _, _, ownerName, _ = GetPlayerInfoByGUID(ownerId)

                self.db.profile.petOwnerCache[petUID] = {
                    OwnerName = ownerName,
                    OwnerGUID = ownerId
                }
                return true, self.db.profile.petOwnerCache[petUID]
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            if petGuid == UnitGUID("PartyPet" .. i) then
                ownerId = UnitGUID("Party" .. i)

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

function addon:PrintHelp(subHelp)
    if subHelp == 'advanced' then
        self:PrintMessage(fmt("%s (%s)", self.L['Help']['advanced'],
            self.Version))

        self:PrintMessage(fmt('- %s (%s)|cffffffff: %s|r', 'debug',
            tostring(self.db.profile.debug),
            self.L['Help']['debug']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'clear',
            self.L['Help']['clear']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'ignore',
            self.L['Help']['ignore']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'queue',
            self.L['Help']['queue']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'queue clear',
            self.L['Help']['queue clear']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'queue process',
            self.L['Help']['queue process']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'reset',
            self.L['Help']['reset']))

        self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'sync',
            self.L['Help']['sync']))

        return
    end

    self:PrintMessage(fmt("%s (%s)", self.L['Help']['title'], self.Version))

    self:PrintMessage(fmt('- %s (%s)|cffffffff: %s|r', 'enable',
        tostring(self.db.profile.enable),
        self.L['Help']['enable']))

    self:PrintMessage(fmt('- %s (%s)|cffffffff: %s|r', 'whisper',
        tostring(self.db.profile.whisper),
        self.L['Help']['whisper']))

    self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'report [channel]',
        self.L['Help']['report [channel]']))

    self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'count',
        self.L['Help']['count']))

    self:PrintMessage(fmt('- %s (%s)|cffffffff: %s|r', 'lead',
        self.cluster.lead, self.L['Help']['lead']))

    self:PrintMessage(fmt('- %s (%s)|cffffffff: %s |r', 'flavor',
        self.db.profile.notificationFlavor,
        self.L['Help']['flavor']))

    self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'flavor [option]',
        self.L['Help']['flavor [option]']))

    self:PrintMessage(fmt('- %s|cffffffff: %s|r', 'advanced',
        self.L['Help']['advanced']))
end

function addon:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. self.L[addonName] ..
            "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end

function addon:SetNotificationFlavor(flavor)
    if self.L["Notification"][flavor] ~= nil then
        self.notifications = self.L["Notification"][self.db.profile
            .notificationFlavor]
    else
        self:PrintMessage(fmt(self.L["ChatCommand"].Flavor.Unavailable,
            flavor or ''))
        self.db.profile.notificationFlavor = "default"
        self.notifications = self.L["Notification"]["default"]
    end
end

function addon:GetRandomNotificationFlavor()
    local keyset = {}

    for k, v in pairs(self.L["Notification"]) do
        if v and v.By ~= nil then table.insert(keyset, k) end
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
        self:PrintMessage(self.L["Utilities"].Upgrade);
        self:ClearCache();
    end
end
