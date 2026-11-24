local addonName, RankSentinel = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(RankSentinel, addonName, "AceEvent-3.0", "AceComm-3.0")

local fmt = string.format
local tinsert = table.insert
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata

addon.Version = GetAddOnMetadata(addonName, "Version")
addon.MaxLevel = _G.GetMaxPlayerLevel()

addon.playerGUID = UnitGUID("player")
addon.playerName = UnitName("player")

if not addon.Version or string.match(addon.Version, 'project') then addon.Version = 'v9.9.9' end

function addon:OnInitialize()
    self.L = LibStub("AceLocale-3.0"):GetLocale(addonName)

    local defaults = {
        profile = {
            enable = true,
            whisper = true,
            debug = false,
            announcedSpells = {},
            ignoredPlayers = {},
            isMaxRank = {},
            petOwnerCache = {},
            dbVersion = 'v0.0.0',
            notificationFlavor = "default",
            isLatestVersion = true
        }
    }

    self.db = LibStub("AceDB-3.0"):New("RankSentinelDB", defaults)

    self:SetNotificationFlavor(self.db.profile.notificationFlavor)

    SLASH_RankSentinel1 = "/" .. string.lower(addonName)
    SLASH_RankSentinel2 = "/sentinel"

    _G.SlashCmdList[addonName] = function(message, _) addon:ChatCommand(message) end
end

function addon:OnEnable()
    self:UpgradeProfile()
    self:InitializeSession()
    self:BuildOptionsPanel()

    self.comms:Setup()

    if not self.db.profile.isLatestVersion then
        self:PrintMessage(self.L["Utilities"]["Outdated"])
        self.db.profile.enabled = false
        return
    end

    if not addon.cleuParser then -- re-use if someone did /disable /enable
        addon.cleuParser = CreateFrame("Frame")
        addon.cleuParser.OnEvent = function(frame, event, ...)
            addon.COMBAT_LOG_EVENT_UNFILTERED(addon, event, ...) -- make sure we get a proper 'self'
        end
        addon.cleuParser:SetScript("OnEvent", addon.cleuParser.OnEvent)
    end
    addon.cleuParser:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.settingsPending then
            self.settingsPending = nil

            local category = _G.Settings.GetCategory(self.options.name)
            _G.Settings.OpenToCategory(category.ID)
        end

        self.comms:ScheduleQueueProcessing()
    end)

    if not self.db.profile.quietMode then
        self:PrintMessage("Loaded %s", self.Version)
    end

    self.db.profile.dbVersion = self.Version

    if self.db.profile.debug then
        self:PrintMessage("Debug enabled, clearing cache on reload")
        self:ClearCache()
    end
end

function addon:ChatCommand(cmd)
    local msg = string.lower(cmd)

    if msg == "reset" then
        self.db:ResetProfile()
        self:PrintMessage(self.L["ChatCommand"].Reset)
    elseif msg == "count" then
        self:PrintMessage(self.L["ChatCommand"].Count.Spells, self:CountCache(self.db.profile.announcedSpells))
        self:PrintMessage(self.L["ChatCommand"].Count.Ranks, self:CountCache(self.db.profile.isMaxRank))
    elseif msg == "clear" then
        self:ClearCache()
    elseif msg == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:PrintMessage("%s = %s", self.L["Debug"], tostring(self.db.profile.debug))
    elseif msg == "whisper" then
        self.db.profile.whisper = not self.db.profile.whisper
        self:PrintMessage("%s = %s", self.L["Whisper"], tostring(self.db.profile.whisper))
    elseif msg == "enable" then
        self.db.profile.enable = not self.db.profile.enable
        self:PrintMessage("%s = %s", self.L["Enable"], tostring(self.db.profile.enable))
        if self.db.profile.enable then self.comms:BroadcastJoin() end
    elseif msg == "lead" then
        self.comms.cluster.lead = self.playerName
        self.comms:BroadcastLead(self.playerName)
        self.comms:PrintLead()
    elseif msg == "ignore" then
        if UnitExists("target") then
            self:IgnoreTarget()
        else
            self:PrintMessage(self.L["ChatCommand"].Ignore.Target)
            self:PrintMessage(self.L["ChatCommand"].Ignore.Count, self:CountCache(self.db.profile.ignoredPlayers))
        end
    elseif "queue" == string.sub(msg, 1, #"queue") then
        local _, sub = strsplit(' ', msg)
        if sub == 'clear' or sub == 'reset' then
            local queued = #self.session.Queue
            self.session.Queue = {}

            self:PrintMessage(self.L["ChatCommand"].Queue.Clear, queued)
        elseif sub == 'process' or sub == 'send' then
            self.comms:ProcessQueuedNotifications()
        else
            self:PrintMessage(self.L["ChatCommand"].Queue.Count, #self.session.Queue)
            local notification = nil

            for i = 1, #self.session.Queue do
                notification = self.session.Queue[i]
                self:PrintMessage("%s - %s", notification.target, notification.ability)
            end
        end
    elseif msg == "sync" then
        self.comms:SyncBroadcast()
    elseif "report" == string.sub(msg, 1, #"report") then
        local _, channel = strsplit(' ', msg)

        self.comms:ReportToChannel(channel)
    elseif "flavor" == string.sub(msg, 1, #"flavor") then
        local _, sub = strsplit(' ', msg)
        if self.L["Notification"][sub] ~= nil then
            self:SetNotificationFlavor(sub)

            self:PrintMessage(self.L["ChatCommand"].Flavor.Set, sub)
        else
            if sub ~= nil then self:PrintMessage(self.L["ChatCommand"].Flavor.Unavailable, sub) end
            local flavorBaseExample = nil

            self:PrintMessage(self.L["ChatCommand"].Flavor.Available)

            for flavor, _ in pairs(self.L["Notification"]) do
                if self.L["Notification"][flavor] and self.L["Notification"][flavor].Base ~= nil then
                    flavorBaseExample = fmt("|cffffffff: " .. self.L["Notification"][flavor].Base, '[Spell]', '9', '',
                                            '62') .. '|r'
                else
                    flavorBaseExample = ''
                end

                self:PrintMessage("- %s%s", flavor, flavorBaseExample)
            end
        end
    elseif msg == "help" then
        self:PrintHelp(msg)
    else
        if InCombatLockdown() then
            self.settingsPending = true

            return
        end

        local category = _G.Settings.GetCategory(self.options.name)
        _G.Settings.OpenToCategory(category.ID)
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

function addon:ClearCache()
    local count = self:CountCache(self.db.profile.announcedSpells)
    local isMaxRankCount = self:CountCache(self.db.profile.isMaxRank)

    self.db.profile.announcedSpells = {}
    self.db.profile.isMaxRank = {}
    self.db.profile.petOwnerCache = {}

    self:InitializeSession()

    self:PrintMessage(self.L["Cache"].Reset, count, isMaxRankCount)
end

function addon:CountCache(cache)
    local count = 0
    for _ in pairs(cache) do count = count + 1 end

    return count
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

function addon:PrintHelp(subHelp)
    if subHelp == 'advanced' then
        self:PrintMessage("%s (%s)", self.L['Help']['advanced'], self.Version)

        self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'debug', tostring(self.db.profile.debug), self.L['Help']['debug'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'clear', self.L['Help']['clear'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'ignore', self.L['Help']['ignore'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue', self.L['Help']['queue'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue clear', self.L['Help']['queue clear'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'queue process', self.L['Help']['queue process'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'reset', self.L['Help']['reset'])

        self:PrintMessage('- %s|cffffffff: %s|r', 'sync', self.L['Help']['sync'])

        return
    end

    self:PrintMessage("%s (%s)", self.L['Help']['title'], self.Version)

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'enable', tostring(self.db.profile.enable), self.L['Help']['enable'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'whisper', tostring(self.db.profile.whisper),
                      self.L['Help']['whisper'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'report [channel]', self.L['Help']['report [channel]'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'count', self.L['Help']['count'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'lead', self.comms.cluster.lead, self.L['Help']['lead'])

    self:PrintMessage('- %s (%s)|cffffffff: %s|r', 'flavor', self.db.profile.notificationFlavor,
                      self.L['Help']['flavor'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'flavor [option]', self.L['Help']['flavor [option]'])

    self:PrintMessage('- %s|cffffffff: %s|r', 'advanced', self.L['Help']['advanced'])
end

function addon:PrintMessage(msg, ...) print(fmt("|cFFFFFF00%s|r: |c0000FF00%s|r", self.L[addonName], fmt(msg, ...))) end

function addon:SetNotificationFlavor(flavor)
    if self.L["Notification"][flavor] ~= nil then
        self.notifications = self.L["Notification"][self.db.profile.notificationFlavor]
        self.db.profile.notificationFlavor = flavor
    else
        self:PrintMessage(self.L["ChatCommand"].Flavor.Unavailable, flavor or '')
        self.db.profile.notificationFlavor = "default"
        self.notifications = self.L["Notification"]["default"]
    end
end

function addon:GetRandomNotificationFlavor()
    local keyset = {}

    for k, v in pairs(self.L["Notification"]) do if v and v.By ~= nil then tinsert(keyset, k) end end

    return self.L["Notification"][keyset[math.random(#keyset)]]
end

function addon:UpgradeProfile()
    if not self.db.profile.isMaxRank then self.db.profile.isMaxRank = {} end
    if not self.db.profile.petOwnerCache then self.db.profile.petOwnerCache = {} end

    if self.db:GetCurrentProfile() == "Default" then
        self:PrintMessage("Old profile detected, resetting database")
        self.db:ResetDB()
    elseif self.db.profile.dbVersion ~= addon.Version and addon.Version ~= 'v0.0.0' then
        self:PrintMessage(self.L["Utilities"].Upgrade)
        if not self.db.profile.isLatestVersion then
            -- Re-enable automatically disabled version
            self.db.profile.enabled = true
        end
        self.db.profile.isLatestVersion = true
        self:ClearCache()
    end

    for k, v in pairs(self.db.profile.ignoredPlayers) do
        if v == true then self.db.profile.ignoredPlayers[k] = nil end
    end
end

local function GetProfileOption(info) return addon.db.profile[info[#info]] end

local function SetProfileOption(info, value) addon.db.profile[info[#info]] = value end

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
                name = fmt(self.L["ChatCommand"].Count.Spells, self:CountCache(self.db.profile.announcedSpells)),
                type = "description",
                width = optionsWidth,
                fontSize = "medium",
                order = 0.1
            },
            ranksCached = {
                name = fmt(self.L["ChatCommand"].Count.Ranks, self:CountCache(self.db.profile.isMaxRank)),
                type = "description",
                width = optionsWidth,
                fontSize = "medium",
                order = 0.2
            },
            generalHeader = {name = _G.GENERAL, type = "header", width = "full", order = 1.0},
            enable = {
                name = _G.ENABLE,
                desc = self.L['Help']['enable'],
                type = "toggle",
                width = optionsWidth,
                order = 1.1,
                set = function(_, value)
                    self.db.profile.enable = value

                    if value then
                        self.comms:BroadcastJoin()
                    end
                end,
                disabled = function() return not self.db.profile.isLatestVersion end
            },
            whisper = {
                name = _G.WHISPER,
                desc = self.L['Help']['whisper'],
                type = "toggle",
                width = optionsWidth,
                order = 1.2
            },
            onlyMaxLevel = {
                name = "Max level only",
                desc = fmt("Only notify level %d characters", addon.MaxLevel),
                type = "toggle",
                width = optionsWidth,
                order = 1.3
            },
            quietMode = {
                name = "Quiet Mode",
                desc = "Reduce output to minimum",
                type = "toggle",
                width = optionsWidth,
                order = 1.4
            },
            announceHeader = {name = "Announce", type = "header", width = "full", order = 2.0},
            announce = {
                name = _G.BNET_REPORT,
                desc = self.L['Help']['report [channel]'],
                type = "execute",
                width = optionsWidth,
                order = 2.1,
                func = function() self.comms:ReportToChannel(self.session.announceTo) end
            },
            announceTo = {
                name = _G.CHANNEL,
                type = "select",
                width = optionsWidth,
                order = 2.2,
                values = {
                    ["self"] = "self",
                    ["say"] = "say",
                    ["party"] = "party",
                    ["raid"] = "raid",
                    ["guild"] = "guild"
                },
                get = function() return self.session.announceTo end,
                set = function(_, value) self.session.announceTo = value end
            },
            clusterHeader = {name = "Cluster", type = "header", width = "full", order = 3.0},
            leader = {
                name = function() return "Leader: " .. self.comms.cluster.lead end,
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
                    self.comms.cluster.lead = self.playerName
                    self.comms:BroadcastLead(self.playerName)
                end,
                disabled = function() return self.playerName == self.comms.cluster.lead end
            },
            flavorHeader = {name = "Notification Flavor", type = "header", width = "full", order = 4.0},
            notificationFlavor = {
                name = "Flavors",
                desc = self.L['Help']['flavor [option]'],
                type = "select",
                width = optionsWidth,
                order = 4.1,
                set = function(_, value) self:SetNotificationFlavor(value) end,
                values = function()
                    local p = {}
                    for flavor, _ in pairs(self.L["Notification"]) do p[flavor] = flavor end
                    return p
                end
            },
            notificationFlavorExample = {
                name = function()
                    local flavor = self.db.profile.notificationFlavor

                    if self.L["Notification"][flavor] and self.L["Notification"][flavor].Base ~= nil then
                        return fmt('  ' .. self.L["Notification"][flavor].Base, '[Spell]', '9', '', '62')
                    else
                        return ''
                    end
                end,
                type = "description",
                width = optionsWidth * 2,
                fontSize = "medium",
                order = 4.2
            },
            ignoreHeader = {name = "Ignore", type = "header", width = "full", order = 5.0},
            ignore = {
                name = _G.IGNORE_PLAYER,
                type = "execute",
                desc = self.L['Help']['ignore'],
                width = optionsWidth,
                order = 5.1,
                func = function() if UnitExists("target") then self:IgnoreTarget() end end
            },
            ignoredPlayersList = {
                name = "Ignored Players",
                type = "select",
                width = optionsWidth,
                order = 5.2,
                values = function()
                    local p = {}
                    for _, v in pairs(self.db.profile.ignoredPlayers) do p[v] = v end
                    return p
                end,
                set = function(_, value) self.session.ignoredSelectedPlayer = value end,
                get = function() return self.session.ignoredSelectedPlayer end,
                disabled = function() return self:CountCache(self.db.profile.ignoredPlayers) == 0 end
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
                    return self:CountCache(self.db.profile.ignoredPlayers) == 0 or self.session.ignoredSelectedPlayer ==
                               nil
                end
            }

        }
    }

    addon.options = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.L[addonName])
    LibStub("AceConfig-3.0"):RegisterOptionsTable(self.L[addonName], optionsTable)
end
