local NS = {
    kind = "",
    contextId = 0,
    title = "",
    page = 1,
    totalPages = 1,
    balance = 0,
    allowPreview = false,
    items = {},
}

local XFER = {
    fee = 0,
    balance = 0,
    suggestions = {},
    suggestionsSet = {},
    queryAt = 0,
    lastQuery = "",
    pendingQuery = nil,
}

local CREDIT = {
    title = "",
    subtitle = "",
    hint = "",
    lines = {},
    buttons = {},
}

local APP_NAME = "Дід Панас"
local TOKEN_ICON = "|TInterface\\Icons\\inv_misc_coin_01:14|t"

local function GetDB()
    if type(DidPanasNpcShopUI_DB) ~= "table" then
        DidPanasNpcShopUI_DB = {}
    end
    return DidPanasNpcShopUI_DB
end

local function SplitTabs(s)
    local out = {}
    for token in string.gmatch(s, "([^\t]+)") do
        out[#out + 1] = token
    end
    return out
end

local function ToNumber(v, default)
    local n = tonumber(v)
    if n == nil then
        return default
    end
    return n
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ShortName(s, maxChars)
    if not s then
        return ""
    end

    if strlenutf8 and strsubutf8 then
        if strlenutf8(s) > maxChars then
            return strsubutf8(s, 1, maxChars - 1) .. "..."
        end
        return s
    end

    return s
end

local function SendToServer(payload)
    SendAddonMessage("NSHOP", payload, "WHISPER", UnitName("player"))
end

local function SendHello()
    SendToServer("HELLO")
end

local function SendCreditToServer(payload)
    SendAddonMessage("NCREDIT", payload, "WHISPER", UnitName("player"))
end

local function SendCreditHello()
    SendCreditToServer("HELLO")
end

local function ShowAddonNotice(text, r, g, b)
    if type(text) ~= "string" or text == "" then
        return
    end

    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
        return
    end

    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(text, r or 1.0, g or 1.0, b or 1.0, 1.0)
    end
end

local function SaveFramePosition(frame, key)
    local db = GetDB()
    db.frames = db.frames or {}
    db.frames[key] = db.frames[key] or {}

    local fx, fy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if fx and fy and ux and uy then
        db.frames[key].customPos = true
        db.frames[key].offsetX = fx - ux
        db.frames[key].offsetY = fy - uy
    end
end

local function PlaceFrame(frame, key, fallbackX, fallbackY)
    local db = GetDB()
    db.frames = db.frames or {}
    local pos = db.frames[key]

    frame:ClearAllPoints()
    if pos and pos.customPos and pos.offsetX and pos.offsetY then
        frame:SetPoint("CENTER", UIParent, "CENTER", pos.offsetX, pos.offsetY)
        return
    end

    if GossipFrame and GossipFrame:IsShown() then
        frame:SetPoint("TOPLEFT", GossipFrame, "TOPRIGHT", fallbackX, fallbackY)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", fallbackX, fallbackY)
    end
end

local function CreateWindow(name, width, height, posKey, fallbackX, fallbackY)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetFrameLevel(5)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePosition(self, posKey)
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.04, 0.06, 0.96)
    frame:SetBackdropBorderColor(0.45, 0.39, 0.18, 1)

    frame.bgGlow = frame:CreateTexture(nil, "BACKGROUND")
    frame.bgGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.bgGlow:SetPoint("TOPLEFT", 8, -8)
    frame.bgGlow:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.bgGlow:SetVertexColor(0.07, 0.08, 0.12, 0.65)

    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -6, -6)

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", 12, -12)
    frame.header:SetPoint("TOPRIGHT", -10, -12)
    frame.header:SetHeight(56)
    frame.header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame.header:SetBackdropColor(0.12, 0.10, 0.06, 0.92)

    frame.headerLine = frame.header:CreateTexture(nil, "OVERLAY")
    frame.headerLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.headerLine:SetHeight(1)
    frame.headerLine:SetPoint("BOTTOMLEFT", 0, 0)
    frame.headerLine:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.headerLine:SetVertexColor(0.72, 0.61, 0.22, 0.85)

    frame.title = frame.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 12, -8)
    frame.title:SetText(APP_NAME)

    frame.subtitle = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.subtitle:SetPoint("TOPLEFT", 12, -30)
    frame.subtitle:SetText("")

    frame.balance = frame.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.balance:SetPoint("RIGHT", -12, 0)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("BOTTOM", 0, 8)
    frame.hint:SetText("")

    frame.SetDefaultPosition = function(self)
        PlaceFrame(self, posKey, fallbackX, fallbackY)
    end

    frame:Hide()
    return frame
end

local shopFrame = CreateWindow("NpcShopUIShopFrame", 450, 560, "shop", 220, 0)
local transferFrame = CreateWindow("NpcShopUITransferFrame", 360, 500, "xfer", 220, 0)
local creditFrame = CreateWindow("NpcShopUICreditFrame", 520, 560, "credit", 220, 0)

if type(UISpecialFrames) == "table" then
    local names = {
        "NpcShopUIShopFrame",
        "NpcShopUITransferFrame",
        "NpcShopUICreditFrame",
    }

    for _, frameName in ipairs(names) do
        local exists = false
        for _, current in ipairs(UISpecialFrames) do
            if current == frameName then
                exists = true
                break
            end
        end

        if not exists then
            table.insert(UISpecialFrames, frameName)
        end
    end
end

local function HideAll()
    shopFrame:Hide()
    transferFrame:Hide()
    creditFrame:Hide()
end

shopFrame.closeBtn:SetScript("OnClick", HideAll)
transferFrame.closeBtn:SetScript("OnClick", HideAll)
creditFrame.closeBtn:SetScript("OnClick", HideAll)

local pager = CreateFrame("Frame", nil, shopFrame)
pager:SetPoint("BOTTOM", 0, 24)
pager:SetSize(290, 28)

pager.prev = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
pager.prev:SetSize(92, 24)
pager.prev:SetPoint("LEFT", 0, 0)
pager.prev:SetText("< Назад")

pager.info = pager:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pager.info:SetPoint("CENTER", 0, 0)

pager.next = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
pager.next:SetSize(92, 24)
pager.next:SetPoint("RIGHT", 0, 0)
pager.next:SetText("Далі >")

local grid = CreateFrame("Frame", nil, shopFrame)
grid:SetPoint("TOPLEFT", 18, -78)
grid:SetSize(414, 412)

local COLS = 3
local ROWS = 3
local CELL_W = 132
local CELL_H = 132
local GAP_X = 9
local GAP_Y = 8

local slots = {}

local function ShowTooltip(self)
    if not self.itemId then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. self.itemId)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function ConfirmBuy(item)
    if not item then
        return
    end

    StaticPopupDialogs["NSHOP_CONFIRM_BUY"] = StaticPopupDialogs["NSHOP_CONFIRM_BUY"] or {
        text = "",
        button1 = "Купити",
        button2 = "Скасувати",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    local dlg = StaticPopupDialogs["NSHOP_CONFIRM_BUY"]
    dlg.text = string.format("Придбати предмет за %s %d?", TOKEN_ICON, item.price)
    dlg.OnAccept = function()
        SendToServer(string.format("BUY\t%s\t%d\t%d\t%d", NS.kind, NS.contextId, item.listIndex, NS.page))
    end

    StaticPopup_Show("NSHOP_CONFIRM_BUY")
end

for i = 1, (COLS * ROWS) do
    local cell = CreateFrame("Button", nil, grid)
    cell:SetSize(CELL_W, CELL_H)

    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    cell:SetPoint("TOPLEFT", col * (CELL_W + GAP_X), -row * (CELL_H + GAP_Y))

    cell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    cell:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    cell:SetBackdropBorderColor(0.29, 0.31, 0.36, 1)

    local bar = cell:CreateTexture(nil, "BORDER")
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("TOPRIGHT", -3, -3)
    bar:SetHeight(2)
    bar:SetVertexColor(0.74, 0.61, 0.18, 0.9)

    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(28, 28)
    cell.icon:SetPoint("TOP", 0, -10)

    cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cell.name:SetWidth(CELL_W - 10)
    cell.name:SetHeight(30)
    cell.name:SetPoint("TOP", 0, -42)
    cell.name:SetJustifyH("CENTER")
    cell.name:SetJustifyV("TOP")
    cell.name:SetWordWrap(true)

    cell.count = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cell.count:SetPoint("TOP", 0, -74)

    cell.price = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.price:SetPoint("TOP", 0, -92)

    cell.buy = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
    cell.buy:SetSize(68, 20)
    cell.buy:SetPoint("BOTTOM", -8, 6)
    cell.buy:SetText("Купити")

    cell.preview = CreateFrame("Button", nil, cell)
    cell.preview:SetSize(18, 18)
    cell.preview:SetPoint("BOTTOMRIGHT", -8, 9)
    cell.preview.icon = cell.preview:CreateTexture(nil, "ARTWORK")
    cell.preview.icon:SetAllPoints()
    cell.preview.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    cell.preview:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Примірка")
        GameTooltip:Show()
    end)
    cell.preview:SetScript("OnLeave", HideTooltip)
    cell.preview:SetScript("OnClick", function()
        if cell.item then
            SendToServer(string.format("PREVIEW\t%s\t%d\t%d", NS.kind, NS.contextId, cell.item.listIndex))
        end
    end)

    cell:SetScript("OnEnter", ShowTooltip)
    cell:SetScript("OnLeave", HideTooltip)
    cell.buy:SetScript("OnEnter", function()
        ShowTooltip(cell)
    end)
    cell.buy:SetScript("OnLeave", HideTooltip)
    cell.buy:SetScript("OnClick", function()
        ConfirmBuy(cell.item)
    end)

    slots[i] = cell
end

local transferPanel = CreateFrame("Frame", nil, transferFrame)
transferPanel:SetPoint("TOPLEFT", 18, -78)
transferPanel:SetPoint("BOTTOMRIGHT", -18, 34)
transferPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
transferPanel:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
transferPanel:SetBackdropBorderColor(0.29, 0.31, 0.36, 1)

transferPanel.title = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
transferPanel.title:SetPoint("TOPLEFT", 12, -12)
transferPanel.title:SetText("Переказ токенів")

transferPanel.fee = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
transferPanel.fee:SetPoint("TOPLEFT", 12, -34)
transferPanel.fee:SetText("Комісія: 0")

transferPanel.nameLabel = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
transferPanel.nameLabel:SetPoint("TOPLEFT", 12, -60)
transferPanel.nameLabel:SetText("Ім'я отримувача")

transferPanel.nameInput = CreateFrame("EditBox", nil, transferPanel, "InputBoxTemplate")
transferPanel.nameInput:SetPoint("TOPLEFT", 12, -78)
transferPanel.nameInput:SetSize(220, 24)
transferPanel.nameInput:SetAutoFocus(false)
transferPanel.nameInput:SetMaxLetters(12)

transferPanel.sugTitle = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
transferPanel.sugTitle:SetPoint("TOPLEFT", 12, -108)
transferPanel.sugTitle:SetText("Підказки (від 3 символів)")

transferPanel.sugButtons = {}
for i = 1, 8 do
    local b = CreateFrame("Button", nil, transferPanel, "UIPanelButtonTemplate")
    b:SetSize(100, 20)
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    b:SetPoint("TOPLEFT", 12 + col * 110, -126 - row * 22)
    b:SetText("")
    b:Hide()
    b:SetScript("OnClick", function(self)
        transferPanel.nameInput:SetText(self.nick or "")
        transferPanel.nameInput:HighlightText(0, 0)

        XFER.suggestions = {}
        XFER.suggestionsSet = {}
        XFER.pendingQuery = nil
        XFER.lastQuery = self.nick or ""

        for j = 1, 8 do
            local sb = transferPanel.sugButtons[j]
            sb.nick = nil
            sb:SetText("")
            sb:Hide()
        end
    end)
    transferPanel.sugButtons[i] = b
end

transferPanel.amountLabel = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
transferPanel.amountLabel:SetPoint("TOPLEFT", 12, -220)
transferPanel.amountLabel:SetText("Сума токенів")

transferPanel.amountInput = CreateFrame("EditBox", nil, transferPanel)
transferPanel.amountInput:SetPoint("TOPLEFT", 12, -238)
transferPanel.amountInput:SetSize(220, 24)
transferPanel.amountInput:SetAutoFocus(false)
transferPanel.amountInput:SetMaxLetters(10)
transferPanel.amountInput:SetFontObject(GameFontHighlight)
transferPanel.amountInput:SetTextInsets(6, 6, 0, 0)
transferPanel.amountInput:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
transferPanel.amountInput:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
transferPanel.amountInput:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

transferPanel.totalText = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
transferPanel.totalText:SetPoint("TOPLEFT", 12, -268)
transferPanel.totalText:SetText("До списання: 0")

transferPanel.sendBtn = CreateFrame("Button", nil, transferPanel, "UIPanelButtonTemplate")
transferPanel.sendBtn:SetSize(120, 24)
transferPanel.sendBtn:SetPoint("TOPLEFT", 12, -296)
transferPanel.sendBtn:SetText("Відправити")

transferPanel.tip = transferPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
transferPanel.tip:SetPoint("TOPLEFT", 12, -328)
transferPanel.tip:SetWidth(300)
transferPanel.tip:SetJustifyH("LEFT")
transferPanel.tip:SetText("")

local scrollSectionCounter = 0

local function CreateScrollSection(parent, width, height, point, rel, relPoint, x, y)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint(point, rel, relPoint, x, y)
    panel:SetSize(width, height)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    panel:SetBackdropBorderColor(0.29, 0.31, 0.36, 1)

    scrollSectionCounter = scrollSectionCounter + 1
    local scrollName = string.format("NpcShopUICreditScroll%d", scrollSectionCounter)
    local scroll = CreateFrame("ScrollFrame", scrollName, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width - 38)
    content:SetHeight(1)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    return panel
end

local creditInfo = CreateScrollSection(creditFrame, 488, 220, "TOPLEFT", creditFrame, "TOPLEFT", 16, -78)
local creditActions = CreateScrollSection(creditFrame, 488, 220, "BOTTOMLEFT", creditFrame, "BOTTOMLEFT", 16, 38)
local creditLineWidgets = {}
local creditButtonWidgets = {}

for i = 1, 18 do
    local fs = creditInfo.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetWidth(430)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    if i == 1 then
        fs:SetPoint("TOPLEFT", 4, -4)
    else
        fs:SetPoint("TOPLEFT", creditLineWidgets[i - 1], "BOTTOMLEFT", 0, -8)
    end
    creditLineWidgets[i] = fs
end

for i = 1, 16 do
    local b = CreateFrame("Button", nil, creditActions.content, "UIPanelButtonTemplate")
    b:SetSize(430, 24)
    if i == 1 then
        b:SetPoint("TOPLEFT", 4, -4)
    else
        b:SetPoint("TOPLEFT", creditButtonWidgets[i - 1], "BOTTOMLEFT", 0, -8)
    end
    b:SetText("")
    b.actionId = 0
    b:SetScript("OnClick", function(self)
        if self.actionId and self.actionId > 0 then
            SendCreditToServer("ACT\t" .. self.actionId)
        else
            HideAll()
        end
    end)
    creditButtonWidgets[i] = b
end

local function RefreshShop()
    shopFrame.title:SetText(APP_NAME)
    shopFrame.subtitle:SetText(NS.title ~= "" and NS.title or "Категорія")
    shopFrame.balance:SetText(string.format("Баланс: %s %d", TOKEN_ICON, NS.balance or 0))
    shopFrame.hint:SetText("Покупка перевіряється на сервері")
    pager.info:SetText(string.format("Сторінка %d / %d", NS.page or 1, NS.totalPages or 1))

    if (NS.page or 1) > 1 then
        pager.prev:Enable()
    else
        pager.prev:Disable()
    end

    if (NS.page or 1) < (NS.totalPages or 1) then
        pager.next:Enable()
    else
        pager.next:Disable()
    end

    for i = 1, #slots do
        local cell = slots[i]
        local item = NS.items[i]
        if item then
            local itemName, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.itemId)
            texture = texture or GetItemIcon(item.itemId)
            cell.item = item
            cell.itemId = item.itemId
            cell.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            local shownName = itemName or item.displayName or ("ID " .. item.itemId)
            cell.name:SetText(ShortName(shownName, 24))
            cell.count:SetText("К-сть: x" .. item.count)
            cell.price:SetText(string.format("Ціна: %s %d", TOKEN_ICON, item.price))
            if NS.allowPreview then
                cell.preview:Show()
            else
                cell.preview:Hide()
            end
            cell:Show()
        else
            cell.item = nil
            cell.itemId = nil
            cell.icon:SetTexture(nil)
            cell.name:SetText("")
            cell.count:SetText("")
            cell.price:SetText("")
            cell.preview:Hide()
            cell:Hide()
        end
    end
end

local function RefreshTransfer()
    transferFrame.title:SetText(APP_NAME)
    transferFrame.subtitle:SetText("Переказ токенів")
    transferFrame.balance:SetText(string.format("Баланс: %s %d", TOKEN_ICON, XFER.balance or 0))
    transferFrame.hint:SetText("Адресат отримає токени моментально")

    transferPanel.fee:SetText(string.format("Комісія: %s %d", TOKEN_ICON, XFER.fee or 0))

    local amount = tonumber(transferPanel.amountInput:GetText() or "") or 0
    transferPanel.totalText:SetText(string.format("До списання: %s %d", TOKEN_ICON, amount + (XFER.fee or 0)))

    local nameText = Trim(transferPanel.nameInput:GetText() or "")
    if nameText ~= "" and amount > 0 then
        transferPanel.sendBtn:Enable()
    else
        transferPanel.sendBtn:Disable()
    end

    for i = 1, 8 do
        local b = transferPanel.sugButtons[i]
        local n = XFER.suggestions[i]
        if n and n ~= "" then
            b.nick = n
            b:SetText(n)
            b:Show()
        else
            b.nick = nil
            b:SetText("")
            b:Hide()
        end
    end
end

local function ShowShopFrame()
    transferFrame:Hide()
    shopFrame:SetDefaultPosition()
    shopFrame:Show()
end

local function ShowTransferFrame()
    shopFrame:Hide()
    creditFrame:Hide()
    transferFrame:SetDefaultPosition()
    transferFrame:Show()
end

local function RefreshCredit()
    creditFrame.title:SetText(CREDIT.title ~= "" and CREDIT.title or "Кредитор")
    creditFrame.subtitle:SetText(CREDIT.subtitle or "")
    creditFrame.balance:SetText("")
    creditFrame.hint:SetText(CREDIT.hint or "")

    local linesHeight = 8
    for i = 1, #creditLineWidgets do
        local widget = creditLineWidgets[i]
        local text = CREDIT.lines[i]
        if text and text ~= "" then
            widget:SetText(text)
            widget:Show()
            local h = widget:GetStringHeight() or 18
            linesHeight = linesHeight + h + 8
        else
            widget:SetText("")
            widget:Hide()
        end
    end
    creditInfo.content:SetHeight(math.max(creditInfo:GetHeight(), linesHeight))
    if creditInfo.scroll and creditInfo.scroll.SetVerticalScroll then
        creditInfo.scroll:SetVerticalScroll(0)
    end

    local buttonsHeight = 8
    for i = 1, #creditButtonWidgets do
        local widget = creditButtonWidgets[i]
        local btn = CREDIT.buttons[i]
        if btn then
            widget.actionId = btn.action or 0
            widget:SetText(btn.label or "")
            widget:Show()
            buttonsHeight = buttonsHeight + 32
        else
            widget.actionId = 0
            widget:SetText("")
            widget:Hide()
        end
    end
    creditActions.content:SetHeight(math.max(creditActions:GetHeight(), buttonsHeight))
    if creditActions.scroll and creditActions.scroll.SetVerticalScroll then
        creditActions.scroll:SetVerticalScroll(0)
    end
end

local function ShowCreditFrame()
    shopFrame:Hide()
    transferFrame:Hide()
    creditFrame:SetDefaultPosition()
    creditFrame:Show()
end

pager.prev:SetScript("OnClick", function()
    local p = math.max(1, (NS.page or 1) - 1)
    SendToServer(string.format("NAV\t%s\t%d\t%d", NS.kind, NS.contextId, p))
end)

pager.next:SetScript("OnClick", function()
    local p = math.min(NS.totalPages or 1, (NS.page or 1) + 1)
    SendToServer(string.format("NAV\t%s\t%d\t%d", NS.kind, NS.contextId, p))
end)

transferPanel.nameInput:SetScript("OnTextChanged", function(self)
    local txt = Trim(self:GetText() or "")
    XFER.pendingQuery = nil

    if string.len(txt) >= 3 then
        if txt ~= XFER.lastQuery then
            XFER.pendingQuery = txt
        end
    else
        XFER.suggestions = {}
        XFER.suggestionsSet = {}
        XFER.lastQuery = ""
    end

    RefreshTransfer()
end)

transferPanel.nameInput:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

transferPanel.nameInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    HideAll()
end)

transferPanel.amountInput:SetScript("OnTextChanged", function()
    local txt = transferPanel.amountInput:GetText() or ""
    local clean = string.gsub(txt, "[^0-9]", "")
    if clean ~= txt then
        transferPanel.amountInput:SetText(clean)
        transferPanel.amountInput:SetCursorPosition(string.len(clean))
    end
    RefreshTransfer()
end)

transferPanel.amountInput:SetScript("OnEnterPressed", function(self)
    local nameText = Trim(transferPanel.nameInput:GetText() or "")
    local amount = tonumber(transferPanel.amountInput:GetText() or "") or 0
    if nameText ~= "" and amount > 0 then
        SendToServer(string.format("XFER\tSEND\t%s\t%d", nameText, amount))
    end
    self:ClearFocus()
end)

transferPanel.amountInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    HideAll()
end)

transferPanel.sendBtn:SetScript("OnClick", function()
    local nameText = Trim(transferPanel.nameInput:GetText() or "")
    local amount = tonumber(transferPanel.amountInput:GetText() or "") or 0
    if nameText == "" or amount <= 0 then
        return
    end

    SendToServer(string.format("XFER\tSEND\t%s\t%d", nameText, amount))
end)

transferFrame:SetScript("OnUpdate", function(_, elapsed)
    if not transferFrame:IsShown() then
        return
    end

    if XFER.pendingQuery and XFER.pendingQuery ~= "" then
        XFER.queryAt = (XFER.queryAt or 0) + elapsed
        if XFER.queryAt >= 0.25 then
            XFER.queryAt = 0
            XFER.lastQuery = XFER.pendingQuery
            XFER.suggestions = {}
            XFER.suggestionsSet = {}
            SendToServer("XFER\tQUERY\t" .. XFER.lastQuery)
            XFER.pendingQuery = nil
        end
    else
        XFER.queryAt = 0
    end
end)

local function HandlePayload(payload)
    local cmd, rest = payload:match("^(%u+)%s*\t?(.*)$")
    if not cmd then
        return
    end

    if cmd == "CLOSE" then
        HideAll()
        return
    end

    if cmd == "OPEN" then
        local parts = SplitTabs(rest)
        NS.kind = parts[1] or ""
        NS.contextId = ToNumber(parts[2], 0)
        NS.title = parts[3] or ""
        NS.page = ToNumber(parts[4], 1)
        NS.totalPages = ToNumber(parts[5], 1)
        NS.balance = ToNumber(parts[6], 0)
        NS.allowPreview = ToNumber(parts[7], 0) == 1
        NS.items = {}
        return
    end

    if cmd == "ITEM" then
        local parts = SplitTabs(rest)
        local item = {
            itemId = ToNumber(parts[1], 0),
            count = ToNumber(parts[2], 1),
            price = ToNumber(parts[3], 0),
            listIndex = ToNumber(parts[5], 0),
            displayName = parts[6] or "",
        }
        if item.itemId > 0 then
            NS.items[#NS.items + 1] = item
        end
        return
    end

    if cmd == "SHOW" then
        RefreshShop()
        ShowShopFrame()
        return
    end

    if cmd == "XFEROPEN" then
        local parts = SplitTabs(rest)
        XFER.fee = ToNumber(parts[1], 0)
        XFER.balance = ToNumber(parts[2], 0)
        XFER.suggestions = {}
        XFER.suggestionsSet = {}
        XFER.pendingQuery = nil
        XFER.queryAt = 0
        XFER.lastQuery = ""
        RefreshTransfer()
        ShowTransferFrame()
        return
    end

    if cmd == "XFERSUG" then
        local name = Trim(rest or "")
        if name ~= "" and not XFER.suggestionsSet[name] and #XFER.suggestions < 8 then
            XFER.suggestionsSet[name] = true
            XFER.suggestions[#XFER.suggestions + 1] = name
        end
        return
    end

    if cmd == "XFERSUGDONE" then
        RefreshTransfer()
        return
    end

    if cmd == "XFERSENT" then
        transferPanel.amountInput:SetText("")
        XFER.suggestions = {}
        XFER.suggestionsSet = {}
        XFER.pendingQuery = nil
        XFER.queryAt = 0
        XFER.lastQuery = ""
        RefreshTransfer()
        return
    end

    if cmd == "INFO" then
        local text = rest or ""
        ShowAddonNotice(text, 0.1, 1.0, 0.1)
        return
    end

    if cmd == "DENY" then
        local text = rest or ""
        ShowAddonNotice(text, 1.0, 0.1, 0.1)
        return
    end
end

local function HandleCreditPayload(payload)
    local cmd, rest = payload:match("^(%u+)%s*\t?(.*)$")
    if not cmd then
        return
    end

    if cmd == "CLOSE" then
        creditFrame:Hide()
        return
    end

    if cmd == "OPEN" then
        local parts = SplitTabs(rest)
        CREDIT.title = parts[1] or "Кредитор"
        CREDIT.subtitle = parts[2] or ""
        CREDIT.hint = parts[3] or ""
        CREDIT.lines = {}
        CREDIT.buttons = {}
        return
    end

    if cmd == "LINE" then
        CREDIT.lines[#CREDIT.lines + 1] = rest or ""
        return
    end

    if cmd == "BUTTON" then
        local parts = SplitTabs(rest)
        CREDIT.buttons[#CREDIT.buttons + 1] = {
            action = ToNumber(parts[1], 0),
            label = parts[2] or "",
        }
        return
    end

    if cmd == "INFO" then
        local text = rest or ""
        ShowAddonNotice(text, 1.0, 0.1, 0.1)
        return
    end

    if cmd == "SHOW" then
        RefreshCredit()
        ShowCreditFrame()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GOSSIP_SHOW")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        SendHello()
        SendCreditHello()
        return
    end

    if event == "GOSSIP_SHOW" then
        SendHello()
        SendCreditHello()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" and shopFrame:IsShown() then
        RefreshShop()
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix == "NSHOP" and type(message) == "string" then
            HandlePayload(message)
        elseif prefix == "NCREDIT" and type(message) == "string" then
            HandleCreditPayload(message)
        end
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg = ...
        if type(msg) == "string" and string.sub(msg, 1, 6) == "NSHOP\t" then
            HandlePayload(string.sub(msg, 7))
        elseif type(msg) == "string" and string.sub(msg, 1, 8) == "NCREDIT\t" then
            HandleCreditPayload(string.sub(msg, 9))
        end
    end
end)

SLASH_NPCSHOPUI1 = "/npcshopui"
SlashCmdList.NPCSHOPUI = function()
    if shopFrame:IsShown() or transferFrame:IsShown() or creditFrame:IsShown() then
        HideAll()
    else
        shopFrame:SetDefaultPosition()
        shopFrame:Show()
    end
end
