-- =========================================================
-- BV_UI.lua  –  Blacklist by Vovo  (v1.2)
-- All visual code: main window, tabs, modals, alert banner,
-- settings panel (now scrollable + Export/Import section).
-- =========================================================

local _, BV = ...

-- ── Layout constants ──────────────────────────────────────
local WINDOW_W = 520
local WINDOW_H = 520
local HDR_H    = 32
local TAB_H    = 30

-- =========================================================
-- Shared helpers
-- =========================================================

-- Plain coloured section divider
local function SectionHeader(parent, text, yOff)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(parent:GetWidth() - 28, 1)
    line:SetPoint("TOPLEFT", 14, yOff)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 14, yOff + 10)
    fs:SetTextColor(0.55, 0.55, 0.55)
    fs:SetText(text:upper())
    return fs
end

-- Button with BackdropTemplate highlight
local function MakeButton(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 120, h or 26)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 4, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetAllPoints()
    fs:SetText(label)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 0.9)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end)
    return btn
end

-- Checkbox with label
local function MakeCheckbox(parent, labelText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(labelText or "")
    cb._lbl = lbl
    cb:SetScript("OnClick", function(self)
        if self.onChange then
            self.onChange(self:GetChecked() == 1 or self:GetChecked() == true)
        end
    end)
    return cb
end

-- Named slider (for OptionsSliderTemplate child access)
local _bvSliderIdx = 0
local function MakeSlider(parent, minVal, maxVal, step, w)
    _bvSliderIdx = _bvSliderIdx + 1
    local sName  = "BVSettingsSlider" .. _bvSliderIdx
    local slider = CreateFrame("Slider", sName, parent, "OptionsSliderTemplate")
    slider:SetWidth(w or 220)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    local lo = _G[sName .. "Low"];  if lo  then lo:SetText("")  end
    local hi = _G[sName .. "High"]; if hi  then hi:SetText("")  end
    local tx = _G[sName .. "Text"]; if tx  then tx:SetText("")  end

    -- flanking min/max labels + current-value label
    local minFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minFS:SetPoint("RIGHT", slider, "LEFT", -4, 0)
    local maxFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxFS:SetPoint("LEFT", slider, "RIGHT", 4, 0)
    local valFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valFS:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider._minFS = minFS
    slider._maxFS = maxFS
    slider._valFS = valFS
    return slider
end

-- Simple custom dropdown (avoids UIDropDownMenu complexity in TBC)
local _bvDDActive = nil

local function CreateDropdown(parent, width)
    local dd = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dd:SetSize(width, 22)
    dd:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 4, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    dd:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    dd:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT",  6, 0)
    label:SetPoint("RIGHT", -18, 0)
    label:SetJustifyH("LEFT")

    local arrowFS = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrowFS:SetPoint("RIGHT", -4, 0)
    arrowFS:SetText("▼")

    local clickZone = CreateFrame("Button", nil, dd)
    clickZone:SetAllPoints()

    dd._items  = {}
    dd._value  = nil
    dd._label  = label

    -- Popup list (UIParent parent for z-order above modals)
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(500)
    popup:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = true, tileSize = 4, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    popup:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    popup:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    popup:Hide()
    dd._popup = popup

    local ITEM_H  = 22
    local itemBtns = {}

    local function RebuildPopup()
        for _, b in ipairs(itemBtns) do b:Hide(); b:SetParent(nil) end
        itemBtns = {}
        popup:SetWidth(dd:GetWidth())
        popup:SetHeight(#dd._items * ITEM_H + 2)
        for i, item in ipairs(dd._items) do
            local row = CreateFrame("Button", nil, popup)
            row:SetSize(dd:GetWidth(), ITEM_H)
            row:SetPoint("TOPLEFT", 0, -1 - (i - 1) * ITEM_H)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("LEFT", 6, 0); fs:SetText(item.text)
            row:SetScript("OnClick", function()
                dd._value = item.value
                label:SetText(item.text)
                popup:Hide(); _bvDDActive = nil
                if dd.onChange then dd.onChange(item.value) end
            end)
            table.insert(itemBtns, row)
        end
    end

    clickZone:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide(); _bvDDActive = nil
        else
            if _bvDDActive and _bvDDActive ~= popup then
                _bvDDActive:Hide()
            end
            RebuildPopup()
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -1)
            popup:Show()
            _bvDDActive = popup
        end
    end)

    function dd:SetItems(itemList)
        dd._items = itemList
    end

    function dd:SetValue(value)
        dd._value = value
        for _, item in ipairs(dd._items) do
            if item.value == value then
                label:SetText(item.text)
                return
            end
        end
        label:SetText(value or "")
    end

    function dd:GetValue()
        return dd._value
    end

    return dd
end

-- =========================================================
-- Scrollable list helpers used by Reasons & Blacklist panels
-- =========================================================
local function MakeScrollList(parent, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(w - 24, h)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w - 40, 1)
    sf:SetScrollChild(content)
    return sf, content
end

-- =========================================================
-- Alert banner  (draggable, click to dismiss)
-- =========================================================
local alertFrame = CreateFrame("Frame", "BVAlertFrame", UIParent, "BackdropTemplate")
alertFrame:SetSize(360, 90)
alertFrame:SetFrameStrata("DIALOG")
alertFrame:SetFrameLevel(300)
alertFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 20,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
alertFrame:SetBackdropColor(0.14, 0, 0, 0.93)
alertFrame:SetBackdropBorderColor(0.65, 0.08, 0.08, 1)
alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
alertFrame:EnableMouse(true)
alertFrame:SetMovable(true)
alertFrame:RegisterForDrag("LeftButton")
alertFrame:Hide()

local alertTitle = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
alertTitle:SetPoint("TOP", 0, -14)
alertTitle:SetTextColor(1, 0.25, 0.25)

local alertBody = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
alertBody:SetPoint("TOPLEFT", 16, -38)
alertBody:SetPoint("BOTTOMRIGHT", -16, 10)
alertBody:SetJustifyH("LEFT")
alertBody:SetJustifyV("TOP")

alertFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self.dragging = true
end)
alertFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.dragging = false
    if BV.DB then
        local point, _, relPoint, x, y = self:GetPoint()
        BV.DB.alertPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)
alertFrame:SetScript("OnMouseUp", function(self, btn)
    if btn == "LeftButton" and not self.dragging then
        self:Hide()
    end
end)

local _alertSeq = 0

function BV:ShowAlert(name, reasonName, message)
    local f = _G["BVAlertFrame"]
    if not f then return end

    if BV.DB and BV.DB.alertPos then
        local p = BV.DB.alertPos
        f:ClearAllPoints()
        f:SetPoint(p.point or "TOP", UIParent, p.relPoint or "TOP", p.x or 0, p.y or -200)
    else
        f:ClearAllPoints()
        f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end

    alertTitle:SetText("|cFFFF3333⚠ BLACKLISTED: " .. name .. "|r")

    local body = "|cFFFFFF00Reason:|r " .. (reasonName ~= "" and reasonName or "Unknown")
    if message and message ~= "" then
        local preview = message
            :gsub("{{username}}", name)
            :gsub("{{Username}}", name)
            :gsub("{{USERNAME}}", name:upper())
        body = body .. "\n|cFF999999" .. preview .. "|r"
    end
    alertBody:SetText(body)

    f:Show()
    BV:PlayAlertSound()

    _alertSeq = _alertSeq + 1
    local seq = _alertSeq
    local dur = (BV.DB and BV.DB.alertDuration) or 8
    C_Timer.After(dur, function()
        if seq == _alertSeq then f:Hide() end
    end)
end

-- =========================================================
-- Confirm / StaticPopup dialogs
-- =========================================================
StaticPopupDialogs["BV_CONFIRM_DEL_REASON"] = {
    text    = "Delete reason \"|cFFFFFF00%s|r\"?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        BV:DeleteReason(data)
        BV:RefreshReasonsList()
        BV:UpdateTabBadges()
    end,
    timeout    = 0,
    whileDead  = true,
    hideOnEscape = true,
}

StaticPopupDialogs["BV_CONFIRM_DEL_REASON_WARN"] = {
    text    = "Delete reason \"|cFFFFFF00%s|r\"?\n|cFFFF8800Warning:|r %d blacklisted player(s) use this reason and will become orphaned.",
    button1 = "Delete Anyway",
    button2 = "Cancel",
    OnAccept = function(self, data)
        BV:DeleteReason(data)
        BV:RefreshReasonsList()
        BV:UpdateTabBadges()
    end,
    timeout    = 0,
    whileDead  = true,
    hideOnEscape = true,
}

StaticPopupDialogs["BV_CONFIRM_DEL_BLACKLIST"] = {
    text    = "Remove |cFFFF4444%s|r from the blacklist?",
    button1 = "Remove",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local entry = BV.DB.blacklist[data]
        if entry then
            BV:RemoveFromBlacklist(entry.username)
            BV:RefreshBlacklistList()
            BV:UpdateTabBadges()
        end
    end,
    timeout    = 0,
    whileDead  = true,
    hideOnEscape = true,
}

-- =========================================================
-- Modal factory
-- =========================================================
local function MakeModal(title, w, h)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(w or 360, h or 200)
    f:SetPoint("CENTER")
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(200)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    table.insert(UISpecialFrames, f:GetName() or "BVModal")

    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", 0, -14)
    titleFS:SetText(title or "")
    f._titleFS = titleFS

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    return f
end

-- Input row helper inside modals
local function MakeModalInput(parent, label, y, w)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 18, y)
    lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w or 300, 22)
    eb:SetPoint("TOPLEFT", 18, y - 18)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(128)
    return eb
end

-- =========================================================
-- Reasons modal (Add / Edit)
-- =========================================================
local reasonModal = MakeModal("Add Reason", 360, 210)
local reasonModalNameEB    = MakeModalInput(reasonModal, "Name:",    -44, 310)
local reasonModalMessageEB = MakeModalInput(reasonModal, "Message:", -82, 310)
local reasonModalHint = reasonModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
reasonModalHint:SetPoint("TOPLEFT", 18, -116)
reasonModalHint:SetText("|cFF888888Use {{username}} to insert the player's name.|r")

local reasonModalSaveBtn   = MakeButton(reasonModal, "Save",   100, 26)
local reasonModalCancelBtn = MakeButton(reasonModal, "Cancel", 100, 26)
reasonModalSaveBtn:SetPoint("BOTTOMLEFT",   18,  16)
reasonModalCancelBtn:SetPoint("BOTTOMRIGHT", -18, 16)

reasonModalCancelBtn:SetScript("OnClick", function() reasonModal:Hide() end)

local _editingReason = nil

function BV:OpenAddReasonModal()
    _editingReason = nil
    reasonModal._titleFS:SetText("Add Reason")
    reasonModalNameEB:SetText("")
    reasonModalMessageEB:SetText("")
    reasonModalNameEB:SetFocus()
    reasonModal:Show()
end

function BV:OpenEditReasonModal(reason)
    _editingReason = reason
    reasonModal._titleFS:SetText("Edit Reason")
    reasonModalNameEB:SetText(reason.name)
    reasonModalMessageEB:SetText(reason.message)
    reasonModalNameEB:SetFocus()
    reasonModal:Show()
end

reasonModalSaveBtn:SetScript("OnClick", function()
    local name = reasonModalNameEB:GetText():match("^%s*(.-)%s*$")
    local msg  = reasonModalMessageEB:GetText():match("^%s*(.-)%s*$")
    if name == "" then return end
    if _editingReason then
        _editingReason.name    = name
        _editingReason.message = msg
    else
        BV:AddReason(name, msg)
    end
    reasonModal:Hide()
    BV:RefreshReasonsList()
    BV:UpdateTabBadges()
end)

-- =========================================================
-- Add to Blacklist modal (from right-click context menu)
-- =========================================================
local ablModal = MakeModal("Blacklist Player", 340, 170)
local ablModalNameFS = ablModal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ablModalNameFS:SetPoint("TOPLEFT", 18, -44)

local ablModalReasonDD = CreateDropdown(ablModal, 290)
ablModalReasonDD:SetPoint("TOPLEFT", 18, -76)

local ablModalHint = ablModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ablModalHint:SetPoint("TOPLEFT", 18, -104)
ablModalHint:SetText("|cFF888888Select the reason to attach.|r")

local ablModalAddBtn    = MakeButton(ablModal, "Add",    100, 26)
local ablModalCancelBtn = MakeButton(ablModal, "Cancel", 100, 26)
ablModalAddBtn:SetPoint("BOTTOMLEFT",   18,  16)
ablModalCancelBtn:SetPoint("BOTTOMRIGHT", -18, 16)
ablModalCancelBtn:SetScript("OnClick", function() ablModal:Hide() end)

local _ablTargetName = nil

function BV:OpenAddBlacklistModal(playerName)
    if not BV.DB or #BV.DB.reasons == 0 then
        print("|cFFFF4444Blacklist by Vovo:|r Add at least one reason in the Reasons tab first.")
        BV:ToggleMainWindow()
        return
    end
    _ablTargetName = playerName
    ablModalNameFS:SetText("Player: |cFFFF4444" .. playerName .. "|r")

    local items = {}
    for _, r in ipairs(BV.DB.reasons) do
        table.insert(items, { text = r.name, value = r.id })
    end
    ablModalReasonDD:SetItems(items)
    ablModalReasonDD:SetValue(BV.DB.reasons[1].id)

    ablModal:Show()
end

ablModalAddBtn:SetScript("OnClick", function()
    local reasonId = ablModalReasonDD:GetValue()
    if not _ablTargetName or not reasonId then return end
    BV:AddToBlacklist(_ablTargetName, reasonId)
    BV:RefreshBlacklistList()
    BV:UpdateTabBadges()
    ablModal:Hide()
    print("|cFF00FF00Blacklist by Vovo:|r Added |cFFFF4444" .. _ablTargetName .. "|r to the blacklist.")
end)

-- =========================================================
-- Main window
-- =========================================================
function BV:BuildMainWindow()
    local f = CreateFrame("Frame", "BVMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(WINDOW_W, WINDOW_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self)
        self:StopMovingOrSizing()
        BV:SaveWindowPos()
    end)
    table.insert(UISpecialFrames, "BVMainFrame")

    -- Header
    local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOP", 0, -10)
    hdr:SetText("|cFFFF4444Blacklist|r by Vovo")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() BV:ToggleMainWindow() end)

    BV.mainFrame = f
    f:Hide()
    return f
end

-- =========================================================
-- Tabs
-- =========================================================
function BV:BuildTabs(f)
    local panelW = WINDOW_W - 28
    local panelH = WINDOW_H - HDR_H - TAB_H - 14
    local panelY = -(HDR_H + TAB_H + 4)

    -- Tab buttons
    local tabDefs = {
        { label = "Reasons",     key = "reasons"   },
        { label = "Blacklisted", key = "blacklist" },
        { label = "Settings",    key = "settings"  },
    }
    local tabBtns  = {}
    local tabW     = math.floor(panelW / #tabDefs)

    for i, def in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(tabW, TAB_H)
        btn:SetPoint("TOPLEFT", 14 + (i - 1) * tabW, -(HDR_H + 4))
        btn:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, tileSize = 4, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetAllPoints()
        lbl:SetText(def.label)
        def._lbl = lbl

        if def.key == "reasons"   then BV._tabLabelR = lbl end
        if def.key == "blacklist" then BV._tabLabelB = lbl end

        table.insert(tabBtns, { btn = btn, key = def.key })
    end

    -- Panels
    local panels = {}
    for _, def in ipairs(tabDefs) do
        local p = CreateFrame("Frame", nil, f, "BackdropTemplate")
        p:SetSize(panelW, panelH)
        p:SetPoint("TOPLEFT", 14, panelY)
        p:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, tileSize = 4, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        p:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
        p:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
        p:Hide()
        panels[def.key] = p
    end

    -- Build content
    BV:BuildReasonsPanel(panels["reasons"],   panelW, panelH)
    BV:BuildBlacklistPanel(panels["blacklist"], panelW, panelH)
    BV:BuildSettingsPanel(panels["settings"],  panelW, panelH)

    BV._panels = panels

    -- ShowTab
    local function ShowTab(key)
        for k, p in pairs(panels) do
            p:SetShown(k == key)
        end
        for _, t in ipairs(tabBtns) do
            if t.key == key then
                t.btn:SetBackdropColor(0.2, 0.2, 0.2, 0.95)
                t.btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            else
                t.btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                t.btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            end
        end
        if key == "reasons"   then BV:RefreshReasonsList() end
        if key == "blacklist" then BV:RefreshBlacklistList() end
        if key == "settings"  then BV:RefreshSettings() end
        BV._activeTab = key
    end

    for _, t in ipairs(tabBtns) do
        t.btn:SetScript("OnClick", function() ShowTab(t.key) end)
    end

    BV._showTab = ShowTab
    ShowTab("reasons")
end

-- =========================================================
-- Tab 1 – Reasons
-- =========================================================
function BV:BuildReasonsPanel(panel, w, h)
    local toolH = 34
    local addBtn = MakeButton(panel, "+ Add Reason", 130, 26)
    addBtn:SetPoint("TOPRIGHT", -8, -4)
    addBtn:SetScript("OnClick", function() BV:OpenAddReasonModal() end)

    local sf, content = MakeScrollList(panel, w, h - toolH - 8)
    sf:SetPoint("TOPLEFT", 4, -(toolH))

    BV._reasonsContent = content
    BV:RefreshReasonsList()
end

function BV:RefreshReasonsList()
    local content = BV._reasonsContent
    if not content or not BV.DB then return end

    -- Clear old rows
    for _, c in ipairs({ content:GetChildren() }) do c:Hide() end

    local list  = BV.DB.reasons or {}
    local rowH  = 44
    local rowW  = content:GetWidth()

    for i, reason in ipairs(list) do
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(rowW, rowH)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (rowH + 2))
        row:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, tileSize = 4,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        row:SetBackdropColor(i % 2 == 0 and 0.08 or 0.11, 0.08, 0.08, 0.7)

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetPoint("TOPLEFT", 8, -6)
        nameFS:SetText("|cFFFF9944" .. reason.name .. "|r")

        local msgFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        msgFS:SetPoint("TOPLEFT", 8, -22)
        msgFS:SetPoint("RIGHT",  -90, 0)
        msgFS:SetJustifyH("LEFT")
        msgFS:SetText("|cFF888888" .. (reason.message ~= "" and reason.message or "(no message)") .. "|r")

        local refFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        refFS:SetPoint("RIGHT", -52, 0)
        local refs = BV:ReasonRefCount(reason.id)
        refFS:SetText(refs > 0 and ("|cFFAAAA44" .. refs .. " player(s)|r") or "")

        local editBtn = MakeButton(row, "Edit", 44, 22)
        editBtn:SetPoint("RIGHT", -46, 0)
        local capturedReason = reason
        editBtn:SetScript("OnClick", function()
            BV:OpenEditReasonModal(capturedReason)
        end)

        local delBtn = MakeButton(row, "✕", 36, 22)
        delBtn:SetPoint("RIGHT", 0, 0)
        delBtn:SetScript("OnClick", function()
            local r2 = BV:ReasonRefCount(capturedReason.id)
            if r2 > 0 then
                StaticPopup_Show("BV_CONFIRM_DEL_REASON_WARN", capturedReason.name, r2, capturedReason.id)
            else
                StaticPopup_Show("BV_CONFIRM_DEL_REASON", capturedReason.name, nil, capturedReason.id)
            end
        end)
    end

    content:SetHeight(math.max(1, #list * (rowH + 2)))
    BV:UpdateTabBadges()
end

-- =========================================================
-- Tab 2 – Blacklisted Players
-- =========================================================
function BV:BuildBlacklistPanel(panel, w, h)
    local toolH = 34
    -- Search bar
    local searchEB = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    searchEB:SetSize(w - 32, 22)
    searchEB:SetPoint("TOPLEFT", 8, -6)
    searchEB:SetAutoFocus(false)
    searchEB:SetMaxLetters(64)
    local ph = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ph:SetPoint("LEFT", searchEB, "LEFT", 4, 0)
    ph:SetTextColor(0.4, 0.4, 0.4)
    ph:SetText("Search player name…")
    searchEB:SetScript("OnTextChanged", function(self)
        ph:SetShown(self:GetText() == "")
        BV:RefreshBlacklistList()
    end)
    BV._blacklistSearch = searchEB

    local sf, content = MakeScrollList(panel, w, h - toolH - 8)
    sf:SetPoint("TOPLEFT", 4, -(toolH))
    BV._blacklistContent = content
    BV:RefreshBlacklistList()
end

function BV:RefreshBlacklistList()
    local content = BV._blacklistContent
    if not content or not BV.DB then return end

    for _, c in ipairs({ content:GetChildren() }) do c:Hide() end

    local list  = BV.DB.blacklist or {}
    local query = (BV._blacklistSearch and BV._blacklistSearch:GetText():lower()) or ""

    local filtered = {}
    for _, entry in ipairs(list) do
        if query == "" or (entry.username or ""):lower():find(query, 1, true) then
            table.insert(filtered, entry)
        end
    end

    local rowH = 44
    local rowW = content:GetWidth()

    for i, entry in ipairs(filtered) do
        local reason = BV:GetReasonById(entry.reasonId)
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(rowW, rowH)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (rowH + 2))
        row:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, tileSize = 4,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        row:SetBackdropColor(i % 2 == 0 and 0.08 or 0.11, 0.06, 0.06, 0.7)

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetPoint("TOPLEFT", 8, -6)
        nameFS:SetText("|cFFFF4444" .. (entry.username or "?") .. "|r")

        local reasonFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        reasonFS:SetPoint("TOPLEFT", 8, -22)
        reasonFS:SetPoint("RIGHT", -46, 0)
        reasonFS:SetJustifyH("LEFT")
        reasonFS:SetText(reason and ("|cFFFF9944" .. reason.name .. "|r") or "|cFFFF4444(missing reason)|r")

        local delBtn = MakeButton(row, "✕", 36, 22)
        delBtn:SetPoint("RIGHT", 0, 0)
        local capturedIdx = #BV.DB.blacklist  -- stable index trick: use username key
        local capturedName = entry.username
        delBtn:SetScript("OnClick", function()
            BV:RemoveFromBlacklist(capturedName)
            BV:RefreshBlacklistList()
            BV:UpdateTabBadges()
        end)
    end

    content:SetHeight(math.max(1, #filtered * (rowH + 2)))
    BV:UpdateTabBadges()
end

-- =========================================================
-- Tab 3 – Settings  (scrollable)
-- =========================================================
local CHANNEL_ITEMS = BV.CHANNEL_ITEMS

function BV:BuildSettingsPanel(panel, w, h)
    -- Wrap all content in a scroll frame so the panel can grow beyond its height
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     0,   0)
    sf:SetPoint("BOTTOMRIGHT", -26, 0)

    local cw = w - 30   -- content width
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(cw)
    content:SetHeight(10)   -- adjusted at the end
    sf:SetScrollChild(content)

    local x0 = 14

    -- ── Display ────────────────────────────────────────────
    SectionHeader(content, "Display", -14)

    local scaleTitleFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleTitleFS:SetPoint("TOPLEFT", x0, -34)
    scaleTitleFS:SetText("Window & Text Scale:")

    local scaleSlider = MakeSlider(content, 75, 150, 5, 220)
    scaleSlider:SetPoint("TOPLEFT", x0 + 38, -52)
    scaleSlider._minFS:SetText("75%")
    scaleSlider._maxFS:SetText("150%")
    local scaleVal = math.floor(((BV.DB and BV.DB.uiScale) or 1.0) * 100)
    scaleSlider:SetValue(scaleVal)
    scaleSlider._valFS:SetText(scaleVal .. "%")
    scaleSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        self._valFS:SetText(val .. "%")
        if BV.DB then BV.DB.uiScale = val / 100 end
        BV:ApplyScale()
    end)
    BV._scaleSlider = scaleSlider

    local scaleHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleHint:SetPoint("TOPLEFT", x0, -76)
    scaleHint:SetText("|cFF555555Scales the entire window and all text inside it.|r")

    -- ── Alert ──────────────────────────────────────────────
    SectionHeader(content, "Alert", -100)

    local durTitleFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    durTitleFS:SetPoint("TOPLEFT", x0, -120)
    durTitleFS:SetText("Alert Banner Duration (seconds):")

    local durSlider = MakeSlider(content, 3, 20, 1, 220)
    durSlider:SetPoint("TOPLEFT", x0 + 24, -138)
    durSlider._minFS:SetText("3s")
    durSlider._maxFS:SetText("20s")
    local durVal = (BV.DB and BV.DB.alertDuration) or 8
    durSlider:SetValue(durVal)
    durSlider._valFS:SetText(durVal .. "s")
    durSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        self._valFS:SetText(val .. "s")
        if BV.DB then BV.DB.alertDuration = val end
    end)
    BV._durSlider = durSlider

    local soundCB = MakeCheckbox(content, "Play alert sound when a blacklisted player joins")
    soundCB:SetPoint("TOPLEFT", x0, -168)
    soundCB:SetChecked((BV.DB and BV.DB.alertSound) ~= false)
    soundCB.onChange = function(checked) if BV.DB then BV.DB.alertSound = checked end end
    BV._soundCB = soundCB

    local resetAlertBtn = MakeButton(content, "Reset Alert Banner Position", 220, 26)
    resetAlertBtn:SetPoint("TOPLEFT", x0, -200)
    resetAlertBtn:SetScript("OnClick", function() BV:ResetAlertPosition() end)

    -- ── Minimap ────────────────────────────────────────────
    SectionHeader(content, "Minimap", -242)

    local minimapCB = MakeCheckbox(content, "Show minimap button")
    minimapCB:SetPoint("TOPLEFT", x0, -262)
    minimapCB:SetChecked(not (BV.DB and BV.DB.minimap and BV.DB.minimap.hide))
    minimapCB.onChange = function(checked)
        if BV.DB then BV.DB.minimap.hide = not checked end
        local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
        if DBIcon then
            if checked then DBIcon:Show("BlacklistByVovo") else DBIcon:Hide("BlacklistByVovo") end
        elseif _G["BVMinimapButton"] then
            _G["BVMinimapButton"]:SetShown(checked)
        end
    end
    BV._minimapCB = minimapCB

    function BV:SyncMinimapCheckbox()
        if BV._minimapCB then
            BV._minimapCB:SetChecked(not (BV.DB and BV.DB.minimap and BV.DB.minimap.hide))
        end
    end

    -- ── Message Channel ────────────────────────────────────
    SectionHeader(content, "Message Channel", -300)

    local chanLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chanLabel:SetPoint("TOPLEFT", x0, -320)
    chanLabel:SetText("Default Output Channel:")

    local chanDD = CreateDropdown(content, 220)
    chanDD:SetPoint("TOPLEFT", x0, -344)
    chanDD:SetItems(CHANNEL_ITEMS)
    chanDD:SetValue((BV.DB and BV.DB.globalChannel) or "PARTY")
    chanDD.onChange = function(value) if BV.DB then BV.DB.globalChannel = value end end
    BV._settingsChanDD = chanDD

    local chanDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chanDesc:SetPoint("TOPLEFT", x0, -372)
    chanDesc:SetPoint("RIGHT",  content, "RIGHT", -x0, 0)
    chanDesc:SetJustifyH("LEFT")
    chanDesc:SetText("|cFF888888Alert messages are sent here. Falls back to PARTY if not in a raid, SAY if not grouped.|r")

    -- Total content height
    content:SetHeight(420)
end

-- =========================================================
-- RefreshSettings  (called when Settings tab is opened)
-- =========================================================
function BV:RefreshSettings()
    if not BV.DB then return end

    if BV._scaleSlider then
        local v = math.floor((BV.DB.uiScale or 1.0) * 100)
        BV._scaleSlider:SetValue(v)
        BV._scaleSlider._valFS:SetText(v .. "%")
    end

    if BV._durSlider then
        local v = BV.DB.alertDuration or 8
        BV._durSlider:SetValue(v)
        BV._durSlider._valFS:SetText(v .. "s")
    end

    if BV._soundCB then
        BV._soundCB:SetChecked(BV.DB.alertSound ~= false)
    end

    if BV._minimapCB then
        BV._minimapCB:SetChecked(not (BV.DB.minimap and BV.DB.minimap.hide))
    end

    if BV._settingsChanDD then
        BV._settingsChanDD:SetItems(CHANNEL_ITEMS)
        BV._settingsChanDD:SetValue(BV.DB.globalChannel or "PARTY")
    end

end

-- =========================================================
-- Tab badges  (count labels on tab headers)
-- =========================================================
function BV:UpdateTabBadges()
    if not BV.DB then return end
    local rc = #(BV.DB.reasons   or {})
    local bc = #(BV.DB.blacklist or {})
    if BV._tabLabelR then
        BV._tabLabelR:SetText("Reasons" .. (rc > 0 and " |cFFAAAAAA(" .. rc .. ")|r" or ""))
    end
    if BV._tabLabelB then
        BV._tabLabelB:SetText("Blacklisted" .. (bc > 0 and " |cFFAAAAAA(" .. bc .. ")|r" or ""))
    end
end

-- =========================================================
-- Toggle (open / close)
-- =========================================================
function BV:ToggleMainWindow()
    if not BV.mainFrame then
        BV:BuildMainWindow()
        BV:BuildTabs(BV.mainFrame)
    end

    if BV.mainFrame:IsShown() then
        BV:SaveWindowPos()
        BV.mainFrame:Hide()
    else
        BV:RestoreWindowPos()
        BV:ApplyScale()
        BV:UpdateTabBadges()
        BV.mainFrame:Show()
        if BV._showTab then BV._showTab(BV._activeTab or "reasons") end
    end
end