-- BV_Core.lua  v1.1
-- Blacklist by Vovo — Core: namespace, DB, event handling, roster tracking,
-- message sending, minimap button, slash commands, scale/sound/position helpers.

local addonName, BV = ...
_G["BV"] = BV

-- =========================================================
-- Database Init (per-account SavedVariables)
-- =========================================================
local function EnsureDB()
    BV_AccountDB           = BV_AccountDB           or {}
    BV_AccountDB.reasons   = BV_AccountDB.reasons   or {}
    BV_AccountDB.blacklist = BV_AccountDB.blacklist  or {}
    BV_AccountDB.nextId    = BV_AccountDB.nextId     or 1
    BV_AccountDB.minimap   = BV_AccountDB.minimap    or { hide = false }

    -- ── Settings ──────────────────────────────────────────
    BV_AccountDB.globalChannel  = BV_AccountDB.globalChannel  or "PARTY"
    BV_AccountDB.uiScale        = BV_AccountDB.uiScale        or 1.0
    BV_AccountDB.alertDuration  = BV_AccountDB.alertDuration  or 8
    if BV_AccountDB.alertSound == nil then
        BV_AccountDB.alertSound = true          -- default ON; explicit nil-check so false persists
    end
    -- windowPos is nil by default (first run = centred)

    BV.DB = BV_AccountDB
end

-- =========================================================
-- Reason API
-- =========================================================
function BV:AddReason(name, message)
    local id = BV.DB.nextId
    BV.DB.nextId = id + 1
    table.insert(BV.DB.reasons, {
        id      = id,
        name    = name    or "Unnamed",
        message = message or "",
    })
    return id
end

function BV:GetReasonById(id)
    if not id then return nil end
    for _, r in ipairs(BV.DB.reasons) do
        if r.id == id then return r end
    end
    return nil
end

function BV:RemoveReason(id)
    for i, r in ipairs(BV.DB.reasons) do
        if r.id == id then
            table.remove(BV.DB.reasons, i)
            return
        end
    end
end

-- Returns how many blacklist entries reference this reason id
function BV:ReasonRefCount(reasonId)
    local n = 0
    for _, e in ipairs(BV.DB.blacklist) do
        if e.reasonId == reasonId then n = n + 1 end
    end
    return n
end

-- =========================================================
-- Blacklist API
-- =========================================================
function BV:AddToBlacklist(username, reasonId)
    BV:RemoveFromBlacklist(username:lower())     -- upsert: drop old entry first
    table.insert(BV.DB.blacklist, {
        key      = username:lower(),
        username = username,
        reasonId = reasonId,
    })
end

function BV:GetBlacklistEntry(name)
    local key = name:lower()
    for _, e in ipairs(BV.DB.blacklist) do
        if e.key == key then return e end
    end
    return nil
end

function BV:RemoveFromBlacklist(nameOrKey)
    local key = nameOrKey:lower()
    for i, e in ipairs(BV.DB.blacklist) do
        if e.key == key then
            table.remove(BV.DB.blacklist, i)
            return
        end
    end
end

-- =========================================================
-- Message Sending
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
-- Alert Sound
-- =========================================================
function BV:PlayAlertSound()
    if not (BV.DB and BV.DB.alertSound) then return end
    -- Night-elf bell — distinctive, in-game, TBC-safe
    if PlaySoundFile then
        PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav")
    end
end

-- =========================================================
-- UI Scale
-- =========================================================
function BV:ApplyScale()
    if BV.mainFrame then
        local scale = (BV.DB and BV.DB.uiScale) or 1.0
        BV.mainFrame:SetScale(scale)
    end
end

-- =========================================================
-- Window Position  (saved on drag-stop; restored on open)
-- =========================================================
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

-- =========================================================
-- Group Roster Snapshot & Blacklist Check
-- =========================================================
BV.lastGroupSnapshot = {}

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

function BV:CheckRosterForBlacklist()
    local current = GetCurrentGroupMembers()
    for key, displayName in pairs(current) do
        if not BV.lastGroupSnapshot[key] then
            local entry = BV:GetBlacklistEntry(key)
            if entry then
                local reason = BV:GetReasonById(entry.reasonId)
                if reason then
                    if BV.ShowBlacklistAlert then BV:ShowBlacklistAlert(displayName, reason) end
                    BV:SendBlacklistMessage(reason.message, displayName)
                end
            end
        end
    end
    BV.lastGroupSnapshot = current
end

-- =========================================================
-- Event Frame
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if BV[event] then BV[event](BV, event, ...) end
end)

local function Register(event) eventFrame:RegisterEvent(event) end

function BV:ADDON_LOADED(_, name)
    if name ~= addonName then return end
    EnsureDB()
    if BV.InitMinimapButton   then BV:InitMinimapButton()   end
    if BV.InitChatContextMenu then BV:InitChatContextMenu() end
    print("|cFF00AAFFBlacklist by Vovo|r loaded.  Type |cFFFFFF00/bv|r to open.")
end

function BV:PARTY_MEMBERS_CHANGED() BV:CheckRosterForBlacklist() end
function BV:RAID_ROSTER_UPDATE()    BV:CheckRosterForBlacklist() end

function BV:PLAYER_ENTERING_WORLD()
    -- Snapshot on login so we don't fire alerts for the existing group
    BV.lastGroupSnapshot = GetCurrentGroupMembers()
end

Register("ADDON_LOADED")
Register("PARTY_MEMBERS_CHANGED")
Register("RAID_ROSTER_UPDATE")
Register("PLAYER_ENTERING_WORLD")

-- =========================================================
-- Window Toggle
-- =========================================================
function BV:Toggle()
    if not BV.mainFrame then
        if BV.CreateMainWindow then BV:CreateMainWindow() else return end
    end
    if BV.mainFrame:IsShown() then
        BV.mainFrame:Hide()
    else
        BV:RestoreWindowPos()
        BV:ApplyScale()
        BV.mainFrame:Show()
    end
end

-- =========================================================
-- Slash Commands
--   /bv              — toggle window
--   /bv minimap      — toggle minimap button visibility
--   /bv help | ?     — print help
-- =========================================================
SLASH_BV1 = "/bv"
SLASH_BV2 = "/blacklistbyvovo"
SLASH_BV3 = "/blacklist"
SlashCmdList["BV"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "help" or msg == "?" then
        print("|cFF00AAFFBlacklist by Vovo|r commands:")
        print("  |cFFFFFF00/bv|r            — toggle the window")
        print("  |cFFFFFF00/bv minimap|r    — toggle the minimap button")
        print("  |cFFFFFF00/bv help|r       — this list")
        return
    end

    if msg == "minimap" then
        if not BV.DB then return end
        BV.DB.minimap.hide = not BV.DB.minimap.hide
        -- Apply via LibDBIcon if available
        local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
        if DBIcon then
            if BV.DB.minimap.hide then DBIcon:Hide("BlacklistByVovo")
            else                       DBIcon:Show("BlacklistByVovo") end
        elseif _G["BVMinimapButton"] then
            _G["BVMinimapButton"]:SetShown(not BV.DB.minimap.hide)
        end
        print("|cFF00AAFFBlacklist by Vovo:|r Minimap button " ..
              (BV.DB.minimap.hide and "|cFFFF8888hidden|r" or "|cFF88FF88shown|r") .. ".")
        -- Sync checkbox in Settings if panel is visible
        if BV.SyncMinimapCheckbox then BV:SyncMinimapCheckbox() end
        return
    end

    BV:Toggle()
end

-- =========================================================
-- Minimap Button
-- =========================================================
function BV:InitMinimapButton()
    local LDB    = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    if LDB and DBIcon then
        BV.launcher = LDB:NewDataObject("BlacklistByVovo", {
            type  = "launcher",
            icon  = "Interface\\Icons\\Ability_Rogue_ShadowStrikes",
            OnClick = function(_, button)
                if button == "LeftButton" then BV:Toggle() end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine("|cFF00AAFFBlacklist by Vovo|r")
                tt:AddLine("|cff00ff00Left-Click:|r Open / Close", 1, 1, 1)
                tt:AddLine("|cFFAAAAFFRight-Click:|r Minimap options", 1, 1, 1)
            end,
        })
        DBIcon:Register("BlacklistByVovo", BV.launcher, BV.DB.minimap)
        return
    end

    BV:CreateFallbackMinimapButton()
end

function BV:CreateFallbackMinimapButton()
    local btn = CreateFrame("Button", "BVMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(26, 26); bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20); icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Ability_Rogue_ShadowStrikes")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54); border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function() BV:Toggle() end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFF00AAFFBlacklist by Vovo|r")
        GameTooltip:AddLine("Click to open/close", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Respect hide setting
    if BV.DB and BV.DB.minimap and BV.DB.minimap.hide then btn:Hide() end
end

-- =========================================================
-- Chat Right-Click Context Menu
-- =========================================================
function BV:InitChatContextMenu()
    if BV._contextMenuInited then return end
    BV._contextMenuInited = true

    UnitPopupButtons["BV_BLACKLIST_ADD"]    = { text = "Add to Blacklist",    dist = 0, notCheckable = 1 }
    UnitPopupButtons["BV_BLACKLIST_REMOVE"] = { text = "Remove from Blacklist", dist = 0, notCheckable = 1 }

    local menuTypes = { "PLAYER", "PARTY", "RAID_PLAYER", "CHAT_ROSTER", "FRIEND" }
    for _, mt in ipairs(menuTypes) do
        local list = UnitPopupMenus[mt]
        if list then
            local n = #list
            local insertAt = (list[n] == "CANCEL") and n or (n + 1)
            table.insert(list, insertAt,     "BV_BLACKLIST_ADD")
            table.insert(list, insertAt + 1, "BV_BLACKLIST_REMOVE")
        end
    end

    hooksecurefunc("SetItemRef", function(link, text, button)
        if button == "RightButton" then
            local n = link:match("^player:([^%-:]+)")
            if n then BV._contextName = n end
        end
    end)

    hooksecurefunc("UnitPopup_ShowMenu", function(dropdownMenu, which, unit, name, userData)
        if name and name ~= "" then
            BV._contextName = name
        elseif unit and unit ~= "" then
            local n = UnitName(unit)
            if n then BV._contextName = n end
        end
    end)

    hooksecurefunc("UnitPopup_OnClick", function(self)
        local btn = self.value
        if btn ~= "BV_BLACKLIST_ADD" and btn ~= "BV_BLACKLIST_REMOVE" then return end
        local name = BV._contextName or ""
        if name == "" then return end

        if btn == "BV_BLACKLIST_ADD" then
            if BV:GetBlacklistEntry(name) then
                print("|cFF00AAFFBlacklist by Vovo:|r |cFFFFFF00" .. name .. "|r is already blacklisted.")
            else
                if BV.ShowPlayerModal then BV:ShowPlayerModal(nil, name) end
            end
        elseif btn == "BV_BLACKLIST_REMOVE" then
            if BV:GetBlacklistEntry(name) then
                BV:RemoveFromBlacklist(name)
                if BV.RefreshBlacklistList then BV:RefreshBlacklistList() end
                print("|cFF00AAFFBlacklist by Vovo:|r Removed |cFFFFFF00" .. name .. "|r from blacklist.")
            else
                print("|cFF00AAFFBlacklist by Vovo:|r |cFFFFFF00" .. name .. "|r is not on your blacklist.")
            end
        end
    end)
end
