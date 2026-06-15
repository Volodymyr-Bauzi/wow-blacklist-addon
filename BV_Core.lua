-- =========================================================
-- BV_Core.lua  –  Blacklist by Vovo  (v1.2)
-- Logic: DB, CRUD, roster scanning, alerts, minimap, slash,
--        chat context menu, export/import.
-- =========================================================
local addonName, BV = ...
_G["BV"] = BV

-- ── Channel options (shared with UI) ──────────────────────
BV.CHANNEL_ITEMS = {
    { text = "Party",        value = "PARTY"        },
    { text = "Raid",         value = "RAID"         },
    { text = "Raid Warning", value = "RAID_WARNING" },
    { text = "Say",          value = "SAY"          },
}

-- =========================================================
-- Saved-variable initialisation
-- =========================================================
local function EnsureDB()
    BV_AccountDB           = BV_AccountDB           or {}
    BV_AccountDB.reasons   = BV_AccountDB.reasons   or {}
    BV_AccountDB.blacklist = BV_AccountDB.blacklist  or {}
    BV_AccountDB.nextId    = BV_AccountDB.nextId     or 1
    BV_AccountDB.minimap   = BV_AccountDB.minimap    or { hide = false }
    BV_AccountDB.globalChannel = BV_AccountDB.globalChannel or "PARTY"
    BV_AccountDB.uiScale       = BV_AccountDB.uiScale       or 1.0
    BV_AccountDB.alertDuration = BV_AccountDB.alertDuration  or 8
    if BV_AccountDB.alertSound == nil then BV_AccountDB.alertSound = true end
    BV.DB = BV_AccountDB
end

-- =========================================================
-- CRUD – Reasons
-- =========================================================
function BV:AddReason(name, message)
    local id = BV.DB.nextId
    BV.DB.nextId = id + 1
    table.insert(BV.DB.reasons, { id = id, name = name or "Unnamed", message = message or "" })
    return id
end

function BV:GetReasonById(id)
    for _, r in ipairs(BV.DB.reasons) do
        if r.id == id then return r end
    end
end

function BV:DeleteReason(id)
    for i, r in ipairs(BV.DB.reasons) do
        if r.id == id then table.remove(BV.DB.reasons, i); return end
    end
end

function BV:ReasonRefCount(reasonId)
    local n = 0
    for _, e in ipairs(BV.DB.blacklist) do
        if e.reasonId == reasonId then n = n + 1 end
    end
    return n
end

-- =========================================================
-- CRUD – Blacklist
-- =========================================================
function BV:AddToBlacklist(username, reasonId)
    local key = username:lower()
    for _, e in ipairs(BV.DB.blacklist) do
        if e.key == key then return false end
    end
    table.insert(BV.DB.blacklist, { key = key, username = username, reasonId = reasonId })
    return true
end

function BV:GetBlacklistEntry(username)
    local key = username:lower()
    for _, e in ipairs(BV.DB.blacklist) do
        if e.key == key then return e end
    end
end

function BV:RemoveFromBlacklist(username)
    local key = username:lower()
    for i, e in ipairs(BV.DB.blacklist) do
        if e.key == key then table.remove(BV.DB.blacklist, i); return end
    end
end

-- =========================================================
-- Messaging
-- =========================================================
function BV:SendBlacklistMessage(message, playerName)
    local text = message
    text = text:gsub("{{username}}", playerName or "")
    text = text:gsub("{{Username}}", playerName or "")
    text = text:gsub("{{USERNAME}}", (playerName or ""):upper())
    local chan = (BV.DB and BV.DB.globalChannel) or "PARTY"
    if (chan == "RAID" or chan == "RAID_WARNING") and not IsInRaid()  then chan = "PARTY" end
    if  chan == "PARTY"                           and not IsInGroup() then chan = "SAY"   end
    if text == "" then return end
    SendChatMessage(text, chan)
end

-- =========================================================
-- UI helpers (scale, sound, window pos, alert pos)
-- =========================================================
function BV:PlayAlertSound()
    if not (BV.DB and BV.DB.alertSound) then return end
    if PlaySoundFile then PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav") end
end

function BV:ApplyScale()
    if BV.mainFrame then
        BV.mainFrame:SetScale((BV.DB and BV.DB.uiScale) or 1.0)
    end
end

function BV:SaveWindowPos()
    if not BV.mainFrame or not BV.DB then return end
    local point, _, relPoint, x, y = BV.mainFrame:GetPoint()
    BV.DB.windowPos = { point = point or "CENTER", relPoint = relPoint or "CENTER", x = x or 0, y = y or 0 }
end

function BV:RestoreWindowPos()
    if not BV.mainFrame or not BV.DB then return end
    local p = BV.DB.windowPos
    if p then
        BV.mainFrame:ClearAllPoints()
        BV.mainFrame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
    end
end

function BV:ResetAlertPosition()
    local f = _G["BVAlertFrame"]
    if f then f:ClearAllPoints(); f:SetPoint("TOP", UIParent, "TOP", 0, -200) end
    if BV.DB then BV.DB.alertPos = nil end
end

-- =========================================================
-- Roster scanning (TBC-safe APIs)
-- =========================================================
local _prevGroupMembers = {}
local _alertTimerSeq    = 0

local function GetCurrentGroupMembers()
    local members = {}
    if IsInRaid() then
        local num = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, num do
            local name = GetRaidRosterInfo(i)
            if name then members[name:lower()] = name end
        end
    elseif IsInGroup() then
        local num = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, num do
            local name = UnitName("party" .. i)
            if name then members[name:lower()] = name end
        end
    end
    return members
end

local function CheckForBlacklistedJoiners(current)
    if not BV.DB then return end
    for key, name in pairs(current) do
        if not _prevGroupMembers[key] then
            local entry = BV:GetBlacklistEntry(name)
            if entry then
                local reason = BV:GetReasonById(entry.reasonId)
                BV:ShowAlert(name, reason and reason.name or "", reason and reason.message or "")
                if reason and reason.message and reason.message ~= "" then
                    BV:SendBlacklistMessage(reason.message, name)
                end
            end
        end
    end
    _prevGroupMembers = current
end

-- =========================================================
-- Event handling
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        EnsureDB()
        BV:InitMinimap()
        BV:InitChatContextMenu()
        BV:RegisterSlashCommands()
    elseif event == "PLAYER_ENTERING_WORLD" then
        _prevGroupMembers = GetCurrentGroupMembers()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        local current = GetCurrentGroupMembers()
        CheckForBlacklistedJoiners(current)
    end
end)

-- =========================================================
-- Minimap
-- =========================================================
function BV:InitMinimap()
    local LDB    = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and DBIcon then
        local broker = LDB:NewDataObject("BlacklistByVovo", {
            type  = "launcher",
            text  = "Blacklist by Vovo",
            icon  = "Interface\\Icons\\INV_Misc_Book_09",
            OnClick = function(_, btn)
                BV:ToggleMainWindow()
            end,
            OnTooltipShow = function(tt)
                tt:AddLine("|cFFFFFFFFBlacklist by Vovo|r")
                tt:AddLine("|cFFAAAAFFLeft-click to open|r")
            end,
        })
        BV.DB.minimap = BV.DB.minimap or { hide = false }
        DBIcon:Register("BlacklistByVovo", broker, BV.DB.minimap)
    else
        BV:CreateFallbackMinimapButton()
    end
end

function BV:CreateFallbackMinimapButton()
    if _G["BVMinimapButton"] then return end
    local btn = CreateFrame("Button", "BVMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    btn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local bd = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    bd:SetAllPoints()
    bd:SetBackdrop({ bgFile = "Interface\\Minimap\\MiniMap-TrackingBorder" })

    local angle = 225
    local function UpdatePos()
        local rad = math.rad(angle)
        btn:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
    end
    UpdatePos()

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local mx, my = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            mx, my = mx / s, my / s
            angle = math.deg(math.atan2(my - cy, mx - cx))
            UpdatePos()
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then BV:ToggleMainWindow() end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFFFFFBlacklist by Vovo|r")
        GameTooltip:AddLine("|cFFAAAAFFClick to open|r")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if BV.DB and BV.DB.minimap and BV.DB.minimap.hide then
        btn:Hide()
    end
end

-- =========================================================
-- Slash commands
-- =========================================================
function BV:RegisterSlashCommands()
    SLASH_BV1 = "/bv"
    SLASH_BV2 = "/blacklistbyvovo"
    SLASH_BV3 = "/blacklist"
    SlashCmdList["BV"] = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "minimap" then
            if BV.DB then BV.DB.minimap.hide = not BV.DB.minimap.hide end
            local hidden  = BV.DB and BV.DB.minimap.hide
            local DBIcon  = LibStub and LibStub("LibDBIcon-1.0", true)
            if DBIcon then
                if hidden then DBIcon:Hide("BlacklistByVovo") else DBIcon:Show("BlacklistByVovo") end
            elseif _G["BVMinimapButton"] then
                _G["BVMinimapButton"]:SetShown(not hidden)
            end
            if BV.SyncMinimapCheckbox then BV:SyncMinimapCheckbox() end
            print("Blacklist by Vovo: Minimap button " .. (hidden and "hidden" or "shown") .. ".")
        elseif msg == "help" then
            print("|cFF00FF00Blacklist by Vovo commands:|r")
            print("  /bv            — open/close window")
            print("  /bv minimap    — toggle minimap button")
            print("  /bv help       — this help")
        else
            BV:ToggleMainWindow()
        end
    end
end

-- =========================================================
-- Chat context menu (right-click a player name)
-- =========================================================
function BV:InitChatContextMenu()
    UnitPopupButtons["BV_BLACKLIST_ADD"] = {
        text   = "Add to Blacklist",
        dist   = 0,
        nested = 0,
    }
    UnitPopupButtons["BV_BLACKLIST_REMOVE"] = {
        text   = "Remove from Blacklist",
        dist   = 0,
        nested = 0,
    }

    local menus = { "PLAYER", "PARTY", "RAID_PLAYER", "CHAT_ROSTER", "FRIEND" }
    for _, m in ipairs(menus) do
        if UnitPopupMenus[m] then
            table.insert(UnitPopupMenus[m], "BV_BLACKLIST_ADD")
            table.insert(UnitPopupMenus[m], "BV_BLACKLIST_REMOVE")
        end
    end

    -- Capture name from chat hyperlinks
    hooksecurefunc("SetItemRef", function(link)
        if link:match("^player:") then
            local name = link:match("^player:([^:]+)")
            if name and name ~= "" then BV._contextName = name end
        end
    end)

    -- Capture name from unit frames / raid frames
    hooksecurefunc("UnitPopup_ShowMenu", function(_, which, unit, name)
        if name and name ~= "" then
            BV._contextName = name
        elseif unit and unit ~= "" then
            local uName = UnitName(unit)
            if uName then BV._contextName = uName end
        end
    end)

    -- Handle selection
    hooksecurefunc("UnitPopup_OnClick", function(self)
        local button = self.value
        local name   = BV._contextName
        if not name or name == "" then return end

        if button == "BV_BLACKLIST_ADD" then
            if BV:GetBlacklistEntry(name) then
                print("|cFFFF4444Blacklist by Vovo:|r " .. name .. " is already blacklisted.")
                return
            end
            BV:OpenAddBlacklistModal(name)

        elseif button == "BV_BLACKLIST_REMOVE" then
            BV:RemoveFromBlacklist(name)
            BV:RefreshBlacklistList()
            print("|cFFFF4444Blacklist by Vovo:|r Removed " .. name .. " from the blacklist.")
        end
    end)
end