local addonName, addon = ...

function addon:Annoy(msg, target)
    if self.playerName == self.cluster.lead then
        self:QueueNotification(msg, target);
    else
        self:PrintMessage(msg);
    end
end

function addon:BuildNotification(spellID, sourceGUID, sourceName, nextRankLevel,
                                 petOwner)
    local spellLink = GetSpellLink(spellID)
    local contactName = sourceName
    local castStringMsg = nil

    if sourceGUID == self.playerGUID then
        castStringMsg = string.format(self.db.profile.castString, "you",
                                      spellLink, nextRankLevel)
        castStringMsg = string.format("%s %s", self.L["AnnouncePrefix"]["Self"],
                                      castStringMsg):gsub('{rt7} ', '', 1)

        contactName = "self"
    elseif self.db.profile.whisper and self.playerName == self.cluster.lead then
        castStringMsg = string.format(self.db.profile.castString,
                                      petOwner and sourceName or "you",
                                      spellLink, nextRankLevel)
        castStringMsg = string.format("%s %s %s",
                                      self.L["AnnouncePrefix"]["Whisper"],
                                      castStringMsg,
                                      self.db.profile.postMessageString)
    else
        castStringMsg = string.format(self.db.profile.castString, sourceName,
                                      spellLink, nextRankLevel)
        castStringMsg = string.format("%s %s", self.L["AnnouncePrefix"]["Self"],
                                      castStringMsg)
        castStringMsg = castStringMsg:gsub('{rt7} ', '', 1):gsub("you",
                                                                 contactName)
                            :gsub(addonName, self.cluster.lead)
    end

    return castStringMsg, contactName
end

function addon:GetUID(guid)
    local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)

    if unitType == "Pet" then
        return string.format("Pet-%s", string.sub(spawnUID, 3))
    end

    return guid
end

function addon:IgnoreTarget()
    local guid = UnitGUID("target")
    if not guid then
        self:PrintMessage("Must target a unit");
        return;
    end

    local name, _ = UnitName("target");

    if self.db.profile.ignoredPlayers[guid] ~= true then
        self:PrintMessage("Ignored " .. name);
        self.db.profile.ignoredPlayers[guid] = true;
    else
        self:PrintMessage("Unignored " .. name);
        self.db.profile.ignoredPlayers[guid] = nil;
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

function addon:IsHighestAlertableRank(nextRankLevel, casterLevel)
    if casterLevel == 70 then
        return nextRankLevel > casterLevel
    elseif casterLevel < 10 then
        return nextRankLevel > casterLevel
    elseif casterLevel < 20 then
        return nextRankLevel + 3 > casterLevel
    elseif casterLevel < 60 then
        return nextRankLevel + 2 > casterLevel
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

function addon:PrintHelp()
    self:PrintMessage(string.format("%s (%s)", self.L['Help']['title'],
                                    self.Version))

    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'enable',
                                    tostring(self.db.profile.enable),
                                    self.L['Help']['enable']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'whisper',
                                    tostring(self.db.profile.whisper),
                                    self.L['Help']['whisper']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'combat',
                                    tostring(self.db.profile.combat),
                                    self.L['Help']['combat']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'debug',
                                    tostring(self.db.profile.debug),
                                    self.L['Help']['debug']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'report [channel]',
                                    self.L['Help']['report [channel]']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'reset',
                                    self.L['Help']['reset']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'count',
                                    self.L['Help']['count']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'clear',
                                    self.L['Help']['clear']));
    self:PrintMessage(string.format('- %s (%s)|cffffffff: %s|r', 'lead',
                                    self.cluster.lead, self.L['Help']['lead']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'ignore',
                                    self.L['Help']['ignore']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'queue',
                                    self.L['Help']['queue']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'queue clear',
                                    self.L['Help']['queue clear']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'queue process',
                                    self.L['Help']['queue process']));
    self:PrintMessage(string.format('- %s|cffffffff: %s|r', 'sync',
                                    self.L['Help']['sync']));
end

function addon:PrintMessage(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00" .. self.L[addonName] ..
                                          "|r: " .. msg, 0.0, 1.0, 0.0, 1.0);
    end
end

function addon:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end
    if not self.db.profile.petOwnerCache then
        self.db.profile.petOwnerCache = {}
    end

    if self.db.profile.dbVersion ~= addon.Version then
        self:PrintMessage("Addon version change, resetting cache");
        self:ClearCache();
    end
end
