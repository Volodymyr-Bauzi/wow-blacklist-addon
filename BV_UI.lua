-- BV_UI.lua  v1.1
-- Blacklist by Vovo — UI: main window, tabs, scroll lists, modals, alert popup.
-- All visual code lives here; BV_Core.lua owns data + events.

local addonName, BV = ...
BV.UI = BV.UI or {}

-- =========================================================
-- Static Popup Dialogs
-- =========================================================
StaticPopupDialogs["BV_CONFIRM_DEL_REASON"] = {
    text          = "Delete reason \"%s\"?",
    button1       = YES,
    button2       = NO,
    OnAccept      = function(self, data)
        BV:RemoveReason(data)
        BV:RefreshReasonsList()
        BV:UpdateTabBadges()
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BV_CONFIRM_DEL_REASON_WARN"] = {
    text          = "Delete reason \"%s\"?\n\n|cFFFF8888Warning:|r %d player(s) are assigned this reason.\nThey will show as '(reason deleted)' until reassigned.",
    button1       = YES,
    button2       = NO,
    OnAccept      = function(self, data)
        BV:RemoveReason(data)
        BV:RefreshReasonsList()
        BV:UpdateTabBadges()
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BV_CONFIRM_DEL_PLAYER"] = {
    text          = "Remove \"%s\" from blacklist?",
    button1       = YES,
    button2       = NO,
    OnAccept      = function(self, data)
        BV:RemoveFromBlacklist(data)
        BV:RefreshBlacklistList()
        BV:UpdateTabBadges()
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

-- =========================================================
-- Theme helpers
-- =========================================================
local function ApplyBackdrop(f, r, g, b, a, br, bg_, bb, ba)
    f:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(r or 0.05, g or 0.06, b or 0.08, a or 0.97)
    f:SetBackdropBorderColor(br or 0.4, bg_ or 0.4, bb or 0.4, ba or 1)
end

local function ApplyDarkRow(f)
    ApplyBackdrop(f, 0.06, 0.07, 0.09, 0.90, 0.18, 0.20, 0.25, 0.90)
end

local function MakeButton(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w or 80, h or 22)
    btn:SetText(label or "")
    return btn
end

local function SectionHeader(parent, text, y)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT",  12, y)
    bar:SetPoint("TOPRIGHT", -12, y)
    bar:SetHeight(1)
    bar:SetColorTexture(0.25, 0.30, 0.40, 0.8)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 14, y - 3)
    fs:SetText("|cFF8899BB" .. text .. "|r")
    return fs
end

-- =========================================================
-- Slider widget  (uses OptionsSliderTemplate for native thumb)
-- Returns: slider, valueLabelFS
-- =========================================================
local _bvSliderIdx = 0
local function MakeSlider(parent, minVal, maxVal, step, w)
    _bvSliderIdx = _bvSliderIdx + 1
    local sName  = "BVSettingsSlider" .. _bvSliderIdx
    local slider = CreateFrame("Slider", sName, parent, "OptionsSliderTemplate")
    slider:SetWidth(w or 220)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    -- Suppress the template's auto labels (we draw our own)
    local lo = _G[sName .. "Low"]
    local hi = _G[sName .. "High"]
    local tx = _G[sName .. "Text"]
    if lo then lo:SetText("") end
    if hi then hi:SetText("") end
    if tx then tx:SetText("") end

    -- Min/Max text flanking the slider
    local minFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minFS:SetPoint("RIGHT", slider, "LEFT", -6, 0)
    minFS:SetTextColor(0.7, 0.7, 0.7)
    minFS:SetText(tostring(minVal))
    slider._minFS = minFS

    local maxFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxFS:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    maxFS:SetTextColor(0.7, 0.7, 0.7)
    maxFS:SetText(tostring(maxVal))
    slider._maxFS = maxFS

    -- Current-value label (right of maxFS)
    local valFS = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valFS:SetPoint("LEFT", maxFS, "RIGHT", 8, 0)
    slider._valFS = valFS

    return slider
end

-- =========================================================
-- Checkbox widget
-- Returns: checkFrame (has :SetChecked() / :GetChecked() / .onChange)
-- =========================================================
local function MakeCheckbox(parent, labelText)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    -- create label separately (template child name depends on frame name)
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(labelText or "")
    cb._lbl = lbl
    cb:SetScript("OnClick", function(self)
        if self.onChange then self.onChange(self:GetChecked() == 1 or self:GetChecked() == true) end
    end)
    return cb
end

-- =========================================================
-- Custom Dropdown
-- =========================================================
local function CreateDropdown(parent, width)
    width = width or 150
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 24)
    ApplyBackdrop(frame, 0.08, 0.08, 0.10, 0.95, 0.25, 0.25, 0.28, 1)

    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", 8, 0); lbl:SetPoint("RIGHT", -22, 0)
    lbl:SetJustifyH("LEFT"); lbl:SetText("Select...")
    frame._lbl = lbl

    local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0); arrow:SetText("▼")

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(width, 10)
    popup:SetFrameStrata("TOOLTIP"); popup:SetFrameLevel(500)
    ApplyBackdrop(popup, 0.08, 0.08, 0.10, 0.98, 0.30, 0.30, 0.35, 1)
    popup:Hide()

    frame._items = {}; frame._value = nil; frame._btns = {}; frame._popup = popup

    local function Close() popup:Hide(); arrow:SetText("▼") end

    local function Open()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        popup:SetWidth(frame:GetWidth())
        for _, b in ipairs(frame._btns) do b:Hide() end
        local yOff = -4
        for i, item in ipairs(frame._items) do
            local b = frame._btns[i]
            if not b then
                b = CreateFrame("Button", nil, popup)
                b:SetHeight(22)
                b._fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b._fs:SetPoint("LEFT", b, "LEFT", 8, 0)
                b._fs:SetPoint("RIGHT", b, "RIGHT", -4, 0)
                b._fs:SetJustifyH("LEFT")
                local hl = b:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.08)
                frame._btns[i] = b
            end
            b:SetPoint("TOPLEFT", 4, yOff); b:SetWidth(popup:GetWidth()-8)
            b._fs:SetText(item.text)
            local cv = item.value
            b:SetScript("OnClick", function()
                frame:SetValue(cv); Close()
                if frame.onChange then frame.onChange(cv) end
            end)
            b:Show(); yOff = yOff - 22
        end
        popup:SetHeight(math.abs(yOff)+4); popup:Show(); arrow:SetText("▲")
    end

    frame:SetScript("OnClick", function() if popup:IsShown() then Close() else Open() end end)
    function frame:SetItems(list) self._items = list end
    function frame:GetValue()     return self._value   end
    function frame:Close()        Close()              end
    function frame:SetValue(val)
        self._value = val
        for _, item in ipairs(self._items) do
            if item.value == val then self._lbl:SetText(item.text); return end
        end
        self._lbl:SetText(val and tostring(val) or "Select...")
    end
    return frame
end

-- =========================================================
-- Shared constants
-- =========================================================
local CHANNEL_ITEMS = {
    { text = "SAY",          value = "SAY"          },
    { text = "PARTY",        value = "PARTY"        },
    { text = "RAID",         value = "RAID"         },
    { text = "RAID WARNING", value = "RAID_WARNING" },
}

local CHAN_COLOR = {
    SAY          = "FFFFFF",
    PARTY        = "44AAFF",
    RAID         = "FF8800",
    RAID_WARNING = "FF3333",
}

-- =========================================================
-- Modal Factory
-- =========================================================
local MODAL_TITLE_H = 28

local function CreateModal(name, w, h, titleText)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h); f:SetPoint("CENTER"); f:Hide()
    f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(200)
    ApplyBackdrop(f, 0.05, 0.06, 0.08, 0.97, 0.45, 0.45, 0.55, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    local hdrTex = f:CreateTexture(nil, "ARTWORK")
    hdrTex:SetPoint("TOPLEFT", 5, -5); hdrTex:SetPoint("TOPRIGHT", -5, -5)
    hdrTex:SetHeight(MODAL_TITLE_H - 6); hdrTex:SetColorTexture(0.10, 0.12, 0.16, 1)

    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleFS:SetPoint("TOP", 0, -8); titleFS:SetText(titleText or "")
    f.titleFS = titleFS

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     8, -(MODAL_TITLE_H + 4))
    content:SetPoint("BOTTOMRIGHT", -8, 8)
    f.content = content

    function f:Open() self:SetPoint("CENTER"); self:Show(); self:Raise() end
    if name then tinsert(UISpecialFrames, name) end
    return f
end

-- =========================================================
-- Tab Badge Helper
-- =========================================================
function BV:UpdateTabBadges()
    if not BV.DB then return end
    local rc = #(BV.DB.reasons   or {})
    local bc = #(BV.DB.blacklist or {})
    if BV._tabLabelR then
        local badge = rc > 0 and (" |cFFAAAAAA(" .. rc .. ")|r") or ""
        BV._tabLabelR:SetText("Reasons" .. badge)
    end
    if BV._tabLabelB then
        local badge = bc > 0 and (" |cFFAAAAAA(" .. bc .. ")|r") or ""
        BV._tabLabelB:SetText("Blacklisted" .. badge)
    end
end

-- =========================================================
-- Main Window
-- =========================================================
local WINDOW_W = 660
local WINDOW_H = 520
local HDR_H    = 32
local TAB_H    = 30
local ROW_H    = 30
local ROW_PAD  = 2

function BV:CreateMainWindow()
    if BV.mainFrame then return end

    local frame = CreateFrame("Frame", "BVMainFrame", UIParent, "BackdropTemplate")
    BV.mainFrame = frame
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  function(f)
        f:StopMovingOrSizing()
        BV:SaveWindowPos()          -- persist position
    end)
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(10)
    ApplyBackdrop(frame, 0.04, 0.04, 0.06, 0.97, 0.35, 0.38, 0.50, 1)
    frame:Hide()
    tinsert(UISpecialFrames, "BVMainFrame")

    -- Title bar
    local titleFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", 14, -8)
    titleFS:SetText("|cFF00AAFFBlacklist|r by Vovo")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- ── Tabs ─────────────────────────────────────────────
    local tabY = -(HDR_H + 2)

    local tabR = CreateFrame("Button", nil, frame, "BackdropTemplate")
    tabR:SetSize(170, TAB_H); tabR:SetPoint("TOPLEFT", 8, tabY)

    local tabB = CreateFrame("Button", nil, frame, "BackdropTemplate")
    tabB:SetSize(190, TAB_H); tabB:SetPoint("TOPLEFT", tabR, "TOPRIGHT", 3, 0)

    local tabS = CreateFrame("Button", nil, frame, "BackdropTemplate")
    tabS:SetSize(110, TAB_H); tabS:SetPoint("TOPLEFT", tabB, "TOPRIGHT", 3, 0)

    local function StyleTab(tab, active)
        if active then ApplyBackdrop(tab, 0.10, 0.14, 0.22, 1.0, 0.25, 0.55, 1.0, 1)
        else            ApplyBackdrop(tab, 0.07, 0.07, 0.09, 0.90, 0.20, 0.20, 0.25, 1) end
    end

    -- Store label refs so UpdateTabBadges() can update them
    local tabRFS = tabR:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabRFS:SetAllPoints(); tabRFS:SetJustifyH("CENTER")
    BV._tabLabelR = tabRFS

    local tabBFS = tabB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabBFS:SetAllPoints(); tabBFS:SetJustifyH("CENTER")
    BV._tabLabelB = tabBFS

    local tabSFS = tabS:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabSFS:SetAllPoints(); tabSFS:SetJustifyH("CENTER"); tabSFS:SetText("Settings")

    -- ── Content Panels ───────────────────────────────────
    local panelY = tabY - TAB_H - 4
    local panelW = WINDOW_W - 16
    local panelH = WINDOW_H - HDR_H - TAB_H - 14

    local function MakePanel()
        local p = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        p:SetSize(panelW, panelH); p:SetPoint("TOPLEFT", 8, panelY)
        ApplyBackdrop(p, 0.03, 0.03, 0.04, 0.80, 0.14, 0.14, 0.20, 0.80)
        return p
    end

    local reasonsPanel   = MakePanel()
    local blacklistPanel = MakePanel()
    local settingsPanel  = MakePanel()

    BV:BuildReasonsPanel(reasonsPanel,    panelW, panelH)
    BV:BuildBlacklistPanel(blacklistPanel, panelW, panelH)
    BV:BuildSettingsPanel(settingsPanel,   panelW, panelH)

    -- ── Tab Switch ───────────────────────────────────────
    local function SwitchTab(which)
        BV._activeTab = which
        StyleTab(tabR, which == "reasons")
        StyleTab(tabB, which == "blacklist")
        StyleTab(tabS, which == "settings")
        reasonsPanel:SetShown(which == "reasons")
        blacklistPanel:SetShown(which == "blacklist")
        settingsPanel:SetShown(which == "settings")
        if which == "reasons"   then BV:RefreshReasonsList()   end
        if which == "blacklist" then BV:RefreshBlacklistList() end
        if which == "settings"  then BV:RefreshSettings()      end
    end

    tabR:SetScript("OnClick", function() SwitchTab("reasons")   end)
    tabB:SetScript("OnClick", function() SwitchTab("blacklist") end)
    tabS:SetScript("OnClick", function() SwitchTab("settings")  end)

    SwitchTab("reasons")
    BV:UpdateTabBadges()

    -- Restore saved position & scale now that the window is built
    BV:RestoreWindowPos()
    BV:ApplyScale()
end

-- =========================================================
-- Reasons Panel
-- =========================================================
function BV:BuildReasonsPanel(panel, w, h)
    local addBtn = MakeButton(panel, "+ Add Reason", 130, 26)
    addBtn:SetPoint("TOPLEFT", 8, -6)
    addBtn:SetScript("OnClick", function() BV:ShowReasonModal(nil) end)

    local hdrY = -36
    local function ColHdr(parent, text, x, cw)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, hdrY); fs:SetWidth(cw)
        fs:SetJustifyH("LEFT"); fs:SetTextColor(0.7, 0.7, 0.7, 1); fs:SetText(text)
    end
    ColHdr(panel, "REASON NAME", 10,  160)
    ColHdr(panel, "MESSAGE",     178, 300)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, -50); sep:SetPoint("TOPRIGHT", -8, -50)
    sep:SetHeight(1); sep:SetColorTexture(0.25, 0.25, 0.30, 0.8)

    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -54); sf:SetPoint("BOTTOMRIGHT", -26, 4)
    BV._reasonsSF = sf

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(w - 30); content:SetHeight(10)
    sf:SetScrollChild(content)
    BV._reasonsContent = content

    local emptyFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyFS:SetPoint("CENTER", 0, 0)
    emptyFS:SetText("|cFF666666No reasons added yet.\nClick  '+ Add Reason'  to create one.|r")
    emptyFS:SetJustifyH("CENTER")
    BV._reasonsEmpty = emptyFS

    BV._reasonsRows = {}
end

function BV:RefreshReasonsList()
    if not BV._reasonsContent then return end
    local content = BV._reasonsContent
    local rows    = BV._reasonsRows
    local w       = content:GetWidth()
    local reasons = (BV.DB and BV.DB.reasons) or {}
    for _, r in ipairs(rows) do r:Hide() end

    if #reasons == 0 then
        BV._reasonsEmpty:Show(); content:SetHeight(80)
        BV:UpdateTabBadges(); return
    end
    BV._reasonsEmpty:Hide()

    local y = 4
    for i, reason in ipairs(reasons) do
        local row = rows[i]
        if not row then row = BV:_CreateReasonRow(content); rows[i] = row end
        row:SetWidth(w - 4); row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -y); row:Show()
        BV:_PopulateReasonRow(row, reason)
        y = y + ROW_H + ROW_PAD
    end
    content:SetHeight(math.max(y + 4, 80))
    BV:UpdateTabBadges()
end

function BV:_CreateReasonRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H); ApplyDarkRow(row)

    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFS:SetPoint("LEFT", 8, 0); nameFS:SetWidth(155); nameFS:SetJustifyH("LEFT")
    row.nameFS = nameFS

    local msgFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msgFS:SetPoint("LEFT", 172, 0); msgFS:SetPoint("RIGHT", -162, 0); msgFS:SetJustifyH("LEFT")
    row.msgFS = msgFS

    local delBtn  = MakeButton(row, "Delete", 72, 22); delBtn:SetPoint("RIGHT",  -6,  0)
    local editBtn = MakeButton(row, "Edit",   72, 22); editBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
    row.delBtn = delBtn; row.editBtn = editBtn
    return row
end

function BV:_PopulateReasonRow(row, reason)
    row.nameFS:SetText("|cFFFFCC00" .. (reason.name or "") .. "|r")
    local msg = reason.message or ""
    if #msg > 55 then msg = msg:sub(1, 52) .. "..." end
    row.msgFS:SetText("|cFF888888" .. msg .. "|r")

    row.editBtn:SetScript("OnClick", function() BV:ShowReasonModal(reason) end)
    row.delBtn:SetScript("OnClick", function()
        local refs = BV:ReasonRefCount(reason.id)
        if refs > 0 then
            StaticPopup_Show("BV_CONFIRM_DEL_REASON_WARN", reason.name, refs, reason.id)
        else
            StaticPopup_Show("BV_CONFIRM_DEL_REASON", reason.name, nil, reason.id)
        end
    end)
end

-- =========================================================
-- Blacklist Panel
-- =========================================================
function BV:BuildBlacklistPanel(panel, w, h)
    local addBtn = MakeButton(panel, "+ Add Player", 130, 26)
    addBtn:SetPoint("TOPLEFT", 8, -6)
    addBtn:SetScript("OnClick", function() BV:ShowPlayerModal(nil) end)

    -- Search bar
    local searchLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLbl:SetPoint("TOPRIGHT", -170, -9)
    searchLbl:SetText("|cFF888888Filter:|r")

    local searchEB = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    searchEB:SetSize(155, 22); searchEB:SetPoint("TOPRIGHT", -8, -6)
    searchEB:SetAutoFocus(false); searchEB:SetMaxLetters(50)
    searchEB:SetScript("OnTextChanged", function() BV:RefreshBlacklistList() end)
    searchEB:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    BV._blacklistSearch = searchEB

    local hdrY = -36
    local function ColHdr(parent, text, x, cw)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, hdrY); fs:SetWidth(cw)
        fs:SetJustifyH("LEFT"); fs:SetTextColor(0.7, 0.7, 0.7, 1); fs:SetText(text)
    end
    ColHdr(panel, "PLAYER NAME", 10,  200)
    ColHdr(panel, "REASON",      218, 200)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, -50); sep:SetPoint("TOPRIGHT", -8, -50)
    sep:SetHeight(1); sep:SetColorTexture(0.25, 0.25, 0.30, 0.8)

    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -54); sf:SetPoint("BOTTOMRIGHT", -26, 4)
    BV._blacklistSF = sf

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(w - 30); content:SetHeight(10)
    sf:SetScrollChild(content)
    BV._blacklistContent = content

    local emptyFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyFS:SetPoint("CENTER", 0, 0)
    emptyFS:SetText("|cFF666666No players blacklisted yet.\nClick  '+ Add Player'  or right-click a name in chat.|r")
    emptyFS:SetJustifyH("CENTER")
    BV._blacklistEmpty = emptyFS

    BV._blacklistRows = {}
end

function BV:RefreshBlacklistList()
    if not BV._blacklistContent then return end
    local content = BV._blacklistContent
    local rows    = BV._blacklistRows
    local w       = content:GetWidth()
    local list    = (BV.DB and BV.DB.blacklist) or {}
    local query   = (BV._blacklistSearch and BV._blacklistSearch:GetText():lower()) or ""

    -- Build filtered list
    local filtered = {}
    for _, entry in ipairs(list) do
        if query == "" or (entry.username or ""):lower():find(query, 1, true) then
            table.insert(filtered, entry)
        end
    end

    for _, r in ipairs(rows) do r:Hide() end

    local showEmpty = (#list == 0) or (query ~= "" and #filtered == 0)
    if showEmpty then
        BV._blacklistEmpty:Show()
        if #list == 0 then
            BV._blacklistEmpty:SetText("|cFF666666No players blacklisted yet.\nClick  '+ Add Player'  or right-click a name in chat.|r")
        else
            BV._blacklistEmpty:SetText("|cFF666666No players match \"" .. query .. "\".|r")
        end
        content:SetHeight(80); BV:UpdateTabBadges(); return
    end
    BV._blacklistEmpty:Hide()

    local y = 4
    for i, entry in ipairs(filtered) do
        local row = rows[i]
        if not row then row = BV:_CreateBlacklistRow(content); rows[i] = row end
        row:SetWidth(w - 4); row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -y); row:Show()
        BV:_PopulateBlacklistRow(row, entry)
        y = y + ROW_H + ROW_PAD
    end
    content:SetHeight(math.max(y + 4, 80))
    BV:UpdateTabBadges()
end

function BV:_CreateBlacklistRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H); ApplyDarkRow(row)

    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFS:SetPoint("LEFT", 8, 0); nameFS:SetWidth(200); nameFS:SetJustifyH("LEFT")
    row.nameFS = nameFS

    local reasonFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reasonFS:SetPoint("LEFT", 216, 0); reasonFS:SetWidth(220); reasonFS:SetJustifyH("LEFT")
    row.reasonFS = reasonFS

    local delBtn  = MakeButton(row, "Remove", 76, 22); delBtn:SetPoint("RIGHT", -6, 0)
    local editBtn = MakeButton(row, "Edit",   72, 22); editBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
    row.delBtn = delBtn; row.editBtn = editBtn
    return row
end

function BV:_PopulateBlacklistRow(row, entry)
    row.nameFS:SetText("|cFFFFFFFF" .. (entry.username or "") .. "|r")
    local reason = BV:GetReasonById(entry.reasonId)
    if reason then
        row.reasonFS:SetText("|cFFFFCC00" .. reason.name .. "|r")
    else
        row.reasonFS:SetText("|cFFFF4444(reason deleted)|r")
    end
    row.editBtn:SetScript("OnClick", function() BV:ShowPlayerModal(entry) end)
    row.delBtn:SetScript("OnClick",  function()
        StaticPopup_Show("BV_CONFIRM_DEL_PLAYER", entry.username, nil, entry.key or entry.username)
    end)
end

-- =========================================================
-- Settings Panel  (Tab 3)
-- =========================================================
function BV:BuildSettingsPanel(panel, w, h)
    local x0 = 14   -- left indent for all controls

    -- ── Display ──────────────────────────────────────────
    SectionHeader(panel, "Display", -14)

    local scaleTitleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleTitleFS:SetPoint("TOPLEFT", x0, -34)
    scaleTitleFS:SetText("Window & Text Scale:")

    local scaleSlider = MakeSlider(panel, 75, 150, 5, 220)
    scaleSlider:SetPoint("TOPLEFT", x0 + 38, -52)   -- offset so min label has room

    -- Override auto min/max labels with % suffix
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

    local scaleHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleHint:SetPoint("TOPLEFT", x0, -72)
    scaleHint:SetText("|cFF555555Scales the entire window and all text inside it.|r")

    -- ── Alert ─────────────────────────────────────────────
    SectionHeader(panel, "Alert", -98)

    local durTitleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    durTitleFS:SetPoint("TOPLEFT", x0, -118)
    durTitleFS:SetText("Alert Banner Duration (seconds):")

    local durSlider = MakeSlider(panel, 3, 20, 1, 220)
    durSlider:SetPoint("TOPLEFT", x0 + 24, -136)
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

    local soundCB = MakeCheckbox(panel, "Play alert sound when a blacklisted player joins")
    soundCB:SetPoint("TOPLEFT", x0, -164)
    soundCB:SetChecked((BV.DB and BV.DB.alertSound) ~= false)
    soundCB.onChange = function(checked)
        if BV.DB then BV.DB.alertSound = checked end
    end
    BV._soundCB = soundCB

    local resetAlertBtn = MakeButton(panel, "Reset Alert Banner Position", 220, 26)
    resetAlertBtn:SetPoint("TOPLEFT", x0, -196)
    resetAlertBtn:SetScript("OnClick", function() BV:ResetAlertPosition() end)

    -- ── Minimap ───────────────────────────────────────────
    SectionHeader(panel, "Minimap", -238)

    local minimapCB = MakeCheckbox(panel, "Show minimap button")
    minimapCB:SetPoint("TOPLEFT", x0, -258)
    minimapCB:SetChecked(not (BV.DB and BV.DB.minimap and BV.DB.minimap.hide))
    minimapCB.onChange = function(checked)
        if BV.DB then BV.DB.minimap.hide = not checked end
        local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
        if DBIcon then
            if checked then DBIcon:Show("BlacklistByVovo")
            else             DBIcon:Hide("BlacklistByVovo") end
        elseif _G["BVMinimapButton"] then
            _G["BVMinimapButton"]:SetShown(checked)
        end
    end
    BV._minimapCB = minimapCB

    -- Expose sync function so slash command can update the checkbox
    function BV:SyncMinimapCheckbox()
        if BV._minimapCB then
            BV._minimapCB:SetChecked(not (BV.DB and BV.DB.minimap and BV.DB.minimap.hide))
        end
    end

    -- ── Message Channel ───────────────────────────────────
    SectionHeader(panel, "Message Channel", -296)

    local chanLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    chanLabel:SetPoint("TOPLEFT", x0, -316)
    chanLabel:SetText("Default Output Channel:")

    local chanDD = CreateDropdown(panel, 220)
    chanDD:SetPoint("TOPLEFT", x0, -334)
    chanDD:SetItems(CHANNEL_ITEMS)
    chanDD:SetValue((BV.DB and BV.DB.globalChannel) or "PARTY")
    chanDD.onChange = function(value)
        if BV.DB then BV.DB.globalChannel = value end
    end
    BV._settingsChanDD = chanDD

    local chanDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chanDesc:SetPoint("TOPLEFT", x0, -364)
    chanDesc:SetPoint("RIGHT", -x0, 0)
    chanDesc:SetJustifyH("LEFT")
    chanDesc:SetText(
        "|cFF888888Blacklist alert messages are sent here.\n" ..
        "Falls back to PARTY if not in a raid, SAY if not in any group.|r"
    )

    -- ── Context Menu info ─────────────────────────────────
    SectionHeader(panel, "Chat Context Menu", -402)

    local ctxDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ctxDesc:SetPoint("TOPLEFT", x0, -422)
    ctxDesc:SetPoint("RIGHT", -x0, 0)
    ctxDesc:SetJustifyH("LEFT")
    ctxDesc:SetText(
        "|cFF888888Right-click any player name in chat, party/raid frames, or the friends list:\n" ..
        "|cFFFFCC00Add to Blacklist|r  — opens Add Player with the name pre-filled.\n" ..
        "|cFFFF8888Remove from Blacklist|r  — removes the player immediately.|r"
    )
end

function BV:RefreshSettings()
    if BV._scaleSlider and BV.DB then
        local sv = math.floor((BV.DB.uiScale or 1.0) * 100)
        BV._scaleSlider:SetValue(sv)
        BV._scaleSlider._valFS:SetText(sv .. "%")
    end
    if BV._durSlider and BV.DB then
        local dv = BV.DB.alertDuration or 8
        BV._durSlider:SetValue(dv)
        BV._durSlider._valFS:SetText(dv .. "s")
    end
    if BV._soundCB and BV.DB then
        BV._soundCB:SetChecked(BV.DB.alertSound ~= false)
    end
    if BV._minimapCB and BV.DB then
        BV._minimapCB:SetChecked(not (BV.DB.minimap and BV.DB.minimap.hide))
    end
    if BV._settingsChanDD and BV.DB then
        BV._settingsChanDD:SetItems(CHANNEL_ITEMS)
        BV._settingsChanDD:SetValue(BV.DB.globalChannel or "PARTY")
    end
end

-- =========================================================
-- Alert Reset
-- =========================================================
function BV:ResetAlertPosition()
    if _G["BVAlertFrame"] then
        _G["BVAlertFrame"]:ClearAllPoints()
        _G["BVAlertFrame"]:SetPoint("TOP", UIParent, "TOP", 0, -160)
        print("|cFF00AAFFBlacklist by Vovo:|r Alert banner position reset.")
    end
end

-- =========================================================
-- Reason Modal (Add / Edit)
-- =========================================================
local _reasonModal = nil

function BV:ShowReasonModal(existingReason)
    if not _reasonModal then
        _reasonModal = CreateModal("BVReasonModal", 430, 215, "Add Reason")
        local c = _reasonModal.content

        local nameLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 4, -4); nameLabel:SetText("Reason Name:")

        local nameEB = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        nameEB:SetSize(390, 26); nameEB:SetPoint("TOPLEFT", 4, -22)
        nameEB:SetAutoFocus(false); nameEB:SetMaxLetters(40)
        nameEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        _reasonModal.nameEB = nameEB

        local msgLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msgLabel:SetPoint("TOPLEFT", 4, -57); msgLabel:SetText("Message:")

        local msgHint = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        msgHint:SetPoint("TOPLEFT", 4, -73)
        msgHint:SetText("|cFF888888Use {{username}} to insert the player's name|r")

        local msgEB = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        msgEB:SetSize(390, 26); msgEB:SetPoint("TOPLEFT", 4, -91)
        msgEB:SetAutoFocus(false); msgEB:SetMaxLetters(255)
        msgEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        _reasonModal.msgEB = msgEB

        local saveBtn = MakeButton(c, "Save", 160, 26)
        saveBtn:SetPoint("BOTTOMLEFT", 4, 4)
        saveBtn:SetScript("OnClick", function()
            local name = (_reasonModal.nameEB:GetText() or ""):match("^%s*(.-)%s*$")
            local msg  = _reasonModal.msgEB:GetText() or ""
            if name == "" then _reasonModal.nameEB:SetTextColor(1, 0.3, 0.3); return end
            _reasonModal.nameEB:SetTextColor(1, 1, 1)
            if _reasonModal._editing then
                _reasonModal._editing.name    = name
                _reasonModal._editing.message = msg
            else
                BV:AddReason(name, msg)
            end
            _reasonModal:Hide()
            BV:RefreshReasonsList()
        end)

        local cancelBtn = MakeButton(c, "Cancel", 160, 26)
        cancelBtn:SetPoint("BOTTOMRIGHT", -4, 4)
        cancelBtn:SetScript("OnClick", function() _reasonModal:Hide() end)
    end

    _reasonModal._editing = existingReason
    if existingReason then
        _reasonModal.titleFS:SetText("Edit Reason")
        _reasonModal.nameEB:SetText(existingReason.name    or "")
        _reasonModal.msgEB:SetText(existingReason.message  or "")
    else
        _reasonModal.titleFS:SetText("Add Reason")
        _reasonModal.nameEB:SetText("")
        _reasonModal.msgEB:SetText("")
    end
    _reasonModal.nameEB:SetTextColor(1, 1, 1)
    _reasonModal:Open()
    _reasonModal.nameEB:SetFocus()
end

-- =========================================================
-- Player Modal (Add / Edit)
-- =========================================================
local _playerModal = nil

function BV:ShowPlayerModal(existingEntry, prefillName)
    local reasons = (BV.DB and BV.DB.reasons) or {}
    if #reasons == 0 then
        print("|cFF00AAFFBlacklist by Vovo:|r Add at least one reason first (Reasons tab).")
        return
    end

    if not _playerModal then
        _playerModal = CreateModal("BVPlayerModal", 390, 210, "Add Player")
        local c = _playerModal.content

        local nameLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 4, -4); nameLabel:SetText("Player Name:")

        local nameEB = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        nameEB:SetSize(350, 26); nameEB:SetPoint("TOPLEFT", 4, -22)
        nameEB:SetAutoFocus(false); nameEB:SetMaxLetters(50)
        nameEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        _playerModal.nameEB = nameEB

        local reasonLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        reasonLabel:SetPoint("TOPLEFT", 4, -57); reasonLabel:SetText("Reason:")

        local reasonDD = CreateDropdown(c, 280)
        reasonDD:SetPoint("TOPLEFT", 4, -75)
        _playerModal.reasonDD = reasonDD

        local saveBtn = MakeButton(c, "Save", 160, 26)
        saveBtn:SetPoint("BOTTOMLEFT", 4, 4)
        saveBtn:SetScript("OnClick", function()
            local uname = (_playerModal.nameEB:GetText() or ""):match("^%s*(.-)%s*$")
            local rid   = _playerModal.reasonDD:GetValue()
            if uname == "" then _playerModal.nameEB:SetTextColor(1, 0.3, 0.3); return end
            if not rid then
                print("|cFF00AAFFBlacklist by Vovo:|r Please select a reason."); return
            end
            _playerModal.nameEB:SetTextColor(1, 1, 1)
            if _playerModal._editing then
                _playerModal._editing.username = uname
                _playerModal._editing.key      = uname:lower()
                _playerModal._editing.reasonId = rid
            else
                BV:AddToBlacklist(uname, rid)
            end
            _playerModal:Hide()
            BV:RefreshBlacklistList()
        end)

        local cancelBtn = MakeButton(c, "Cancel", 160, 26)
        cancelBtn:SetPoint("BOTTOMRIGHT", -4, 4)
        cancelBtn:SetScript("OnClick", function() _playerModal:Hide() end)
    end

    local items = {}
    for _, r in ipairs(reasons) do
        table.insert(items, { text = r.name, value = r.id })
    end
    _playerModal.reasonDD:SetItems(items)

    _playerModal._editing = existingEntry
    if existingEntry then
        _playerModal.titleFS:SetText("Edit Player")
        _playerModal.nameEB:SetText(existingEntry.username or "")
        _playerModal.reasonDD:SetValue(existingEntry.reasonId)
    else
        _playerModal.titleFS:SetText("Add Player")
        _playerModal.nameEB:SetText(prefillName or "")
        _playerModal.reasonDD:SetValue(items[1] and items[1].value or nil)
    end

    _playerModal.nameEB:SetTextColor(1, 1, 1)
    _playerModal:Open()
    _playerModal.nameEB:SetFocus()
    if prefillName and prefillName ~= "" then
        _playerModal.nameEB:SetCursorPosition(#prefillName)
    end
end

-- =========================================================
-- Alert Popup
-- =========================================================
local _alertTimerSeq = 0

function BV:ShowBlacklistAlert(playerName, reason)
    local af = _G["BVAlertFrame"]
    if not af then
        af = CreateFrame("Frame", "BVAlertFrame", UIParent, "BackdropTemplate")
        af:SetSize(430, 92)
        af:SetPoint("TOP", UIParent, "TOP", 0, -160)
        af:SetFrameStrata("TOOLTIP"); af:SetFrameLevel(300)
        ApplyBackdrop(af, 0.14, 0.02, 0.02, 0.96, 0.75, 0.10, 0.10, 1)
        af:Hide()
        af:EnableMouse(true)
        af:SetMovable(true); af:RegisterForDrag("LeftButton")
        af:SetScript("OnDragStart", af.StartMoving)
        af:SetScript("OnDragStop",  af.StopMovingOrSizing)

        -- Click (no drag) dismisses
        af:SetScript("OnMouseUp", function(self, btn)
            if btn == "LeftButton" and not self.dragging then
                self:Hide()
            end
        end)
        af:SetScript("OnDragStart", function(self, ...) self.dragging = true; self:StartMoving() end)
        af:SetScript("OnDragStop",  function(self, ...) self.dragging = false; self:StopMovingOrSizing() end)

        local iconFS = af:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconFS:SetPoint("LEFT", 12, 2); iconFS:SetText("⚠")
        iconFS:SetTextColor(1, 0.3, 0.1, 1)

        local nameFS = af:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        nameFS:SetPoint("TOPLEFT", 44, -12); nameFS:SetPoint("RIGHT", -10, 0)
        nameFS:SetJustifyH("LEFT"); af.nameFS = nameFS

        local reasonFS = af:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        reasonFS:SetPoint("TOPLEFT", 44, -34); reasonFS:SetPoint("RIGHT", -10, 0)
        reasonFS:SetJustifyH("LEFT"); af.reasonFS = reasonFS

        local msgFS = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        msgFS:SetPoint("TOPLEFT", 44, -54); msgFS:SetPoint("RIGHT", -10, 0)
        msgFS:SetJustifyH("LEFT"); af.msgFS = msgFS

        local dismissFS = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dismissFS:SetPoint("BOTTOMRIGHT", -8, 6)
        dismissFS:SetText("|cFF555555Click or drag to move  •  click to dismiss|r")
    end

    local chan = (BV.DB and BV.DB.globalChannel) or "PARTY"
    local cc   = CHAN_COLOR[chan] or "AAAAAA"

    af.nameFS:SetText("|cFFFF4444" .. playerName .. "|r  joined your group!")
    af.reasonFS:SetText("Reason: |cFFFFCC00" .. (reason.name or "") .. "|r")

    local msgPreview = (reason.message or ""):gsub("{{username}}", playerName)
    if #msgPreview > 55 then msgPreview = msgPreview:sub(1, 52) .. "..." end
    af.msgFS:SetText("|cFF" .. cc .. "[" .. chan .. "]|r " .. msgPreview)

    af:Show()
    BV:PlayAlertSound()

    -- Auto-dismiss timer; sequence token prevents stale timer races
    _alertTimerSeq = _alertTimerSeq + 1
    local seq = _alertTimerSeq
    local duration = (BV.DB and BV.DB.alertDuration) or 8
    C_Timer.After(duration, function()
        if _alertTimerSeq == seq then
            local f = _G["BVAlertFrame"]
            if f then f:Hide() end
        end
    end)
end
