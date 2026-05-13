local APP_PREFIX = "AmdirHelper"
local DB_NAME = "LegacyRaidsNpcShopUI_DB"

local function GetDB()
    if type(_G[DB_NAME]) ~= "table" then
        _G[DB_NAME] = {}
    end
    return _G[DB_NAME]
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SplitTabs(s)
    local out = {}
    if type(s) ~= "string" then
        return out
    end

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

local function SendToServer(payload)
    SendAddonMessage(APP_PREFIX, payload, "WHISPER", UnitName("player"))
end

local function SendHello()
    SendToServer("LRC_HELLO")
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
    frame:SetFrameLevel(6)
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

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", 12, -12)
    frame.header:SetPoint("TOPRIGHT", -10, -12)
    frame.header:SetHeight(56)
    frame.header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame.header:SetBackdropColor(0.12, 0.10, 0.06, 0.92)

    frame.title = frame.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 12, -8)
    frame.title:SetText("")

    frame.subtitle = frame.header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.subtitle:SetPoint("TOPLEFT", 12, -30)
    frame.subtitle:SetText("")

    frame.balance = frame.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.balance:SetPoint("RIGHT", -12, 0)
    frame.balance:SetText("")

    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", -6, -6)

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hint:SetPoint("BOTTOM", 0, 8)
    frame.hint:SetText("")

    frame.SetDefaultPosition = function(self)
        PlaceFrame(self, posKey, fallbackX, fallbackY)
    end

    if type(UISpecialFrames) == "table" then
        local exists = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == name then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(UISpecialFrames, name)
        end
    end

    frame:Hide()
    return frame
end

local LR = {
    vendor = {
        vendorEntry = 0,
        title = "",
        tokenItem = 0,
        balance = 0,
        selectedCategory = nil,
        categoryScroll = 0,
        itemScroll = 0,
        categories = {},
        categoryOrder = {},
        itemsByCategory = {},
    },
    loot = {
        selectedMapId = 0,
        selectedBossEntry = 0,
        maps = {},
        mapOrder = {},
        bossesByMap = {},
        bossOrderByMap = {},
        itemsByBoss = {},
    },
}

local vendorFrame = CreateWindow("LegacyRaidsVendorFrame", 840, 560, "legacy_vendor", 220, 0)
local lootFrame = CreateWindow("LegacyRaidsLootFrame", 980, 560, "legacy_loot", 220, 0)

local function HideAll()
    vendorFrame:Hide()
    lootFrame:Hide()
end

vendorFrame.closeBtn:SetScript("OnClick", HideAll)
lootFrame.closeBtn:SetScript("OnClick", HideAll)

local function CreatePanel(parent, width, height, x, y)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", x, y)
    panel:SetSize(width, height)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    panel:SetBackdropBorderColor(0.29, 0.31, 0.36, 1)
    return panel
end

local function CreateListContainer(parent, key, width, height, x, y)
    local panel = CreatePanel(parent, width, height, x, y)

    local scroll = CreateFrame("ScrollFrame", parent:GetName() .. key .. "Scroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 34, 1)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.buttons = {}
    return panel
end

local function CreateItemListContainer(parent, key, width, height, x, y)
    local panel = CreatePanel(parent, width, height, x, y)

    local scroll = CreateFrame("ScrollFrame", parent:GetName() .. key .. "Scroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width - 34, 1)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.rows = {}
    return panel
end

local vendorCategories = CreateListContainer(vendorFrame, "Categories", 200, 430, 18, -78)
local vendorItems = CreateItemListContainer(vendorFrame, "Items", 600, 430, 230, -78)

local lootMaps = CreateListContainer(lootFrame, "Maps", 240, 430, 18, -78)
local lootBosses = CreateListContainer(lootFrame, "Bosses", 260, 430, 272, -78)
local lootItems = CreateItemListContainer(lootFrame, "Items", 412, 430, 546, -78)

local PreviewItem

local function EnsureListButtons(container, count, onClick)
    for i = #container.buttons + 1, count do
        local button = CreateFrame("Button", nil, container.content)
        button:SetSize(container.content:GetWidth(), 24)
        button.selectedBg = button:CreateTexture(nil, "BACKGROUND")
        button.selectedBg:SetAllPoints()
        button.selectedBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.selectedBg:SetVertexColor(0.72, 0.60, 0.18, 0.28)
        button.selectedBg:Hide()
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("LEFT", 8, 0)
        button.text:SetPoint("RIGHT", -8, 0)
        button.text:SetJustifyH("LEFT")
        button:SetNormalFontObject(GameFontNormal)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        button:SetScript("OnClick", onClick)
        container.buttons[i] = button
    end
end

local function EnsureItemRows(container, count, onBuy)
    for i = #container.rows + 1, count do
        local row = CreateFrame("Button", nil, container.content)
        row:SetSize(container.content:GetWidth(), 54)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:GetHighlightTexture():SetBlendMode("ADD")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28)
        row.icon:SetPoint("LEFT", 8, 0)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", 44, -6)
        row.name:SetPoint("RIGHT", -170, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("TOP")
        row.name:SetHeight(30)
        if row.name.SetWordWrap then
            row.name:SetWordWrap(true)
        end

        row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.meta:SetPoint("TOPLEFT", 44, -34)
        row.meta:SetPoint("RIGHT", -198, 0)
        row.meta:SetJustifyH("LEFT")

        row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.price:SetPoint("RIGHT", -104, 0)

        row.preview = CreateFrame("Button", nil, row)
        row.preview:SetSize(18, 18)
        row.preview:SetPoint("RIGHT", -82, 0)
        row.preview.icon = row.preview:CreateTexture(nil, "ARTWORK")
        row.preview.icon:SetAllPoints()
        row.preview.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
        row.preview:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Примірка")
            GameTooltip:Show()
        end)
        row.preview:SetScript("OnLeave", GameTooltip_Hide)
        row.preview:SetScript("OnClick", function(self)
            if self.rowData then
                PreviewItem(self.rowData)
            end
        end)

        row.buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.buy:SetSize(62, 22)
        row.buy:SetPoint("RIGHT", -8, 0)
        row.buy:SetText("Купити")
        row.buy:SetScript("OnClick", function(self)
            if self.rowData then
                onBuy(self.rowData)
            end
        end)

        row:SetScript("OnEnter", function(self)
            if not self.itemId then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemId)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)

        container.rows[i] = row
    end
end

local function SetListData(container, rows)
    EnsureListButtons(container, #rows, function(self)
        if self.onSelect then
            self.onSelect(self.rowData)
        end
    end)

    local y = -2
    for i = 1, #container.buttons do
        local button = container.buttons[i]
        local data = rows[i]
        if data then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 0, y)
            button:SetPoint("RIGHT", 0, 0)
            button.text:SetText(data.text or "")
            if data.selected then
                button.selectedBg:Show()
                button.text:SetTextColor(1.0, 0.92, 0.62)
            else
                button.selectedBg:Hide()
                button.text:SetTextColor(1.0, 0.82, 0.0)
            end
            button.rowData = data.value
            button.onSelect = data.onSelect
            button:Show()
            y = y - 24
        else
            button:Hide()
            button.selectedBg:Hide()
            button.text:SetTextColor(1.0, 0.82, 0.0)
            button.rowData = nil
            button.onSelect = nil
        end
    end

    container.content:SetHeight(math.max(1, -y + 4))
end

local function FormatTokenBalance(itemId, amount)
    local icon = itemId and GetItemIcon(itemId) or nil
    if icon then
        return string.format("Баланс: |T%s:14|t %d", icon, amount or 0)
    end
    return string.format("Баланс: %d", amount or 0)
end

local function ConfirmBuy(item)
    if not item then
        return
    end

    StaticPopupDialogs["LEGACYRAIDS_CONFIRM_BUY"] = StaticPopupDialogs["LEGACYRAIDS_CONFIRM_BUY"] or {
        text = "",
        button1 = "Купити",
        button2 = "Скасувати",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    local icon = GetItemIcon(item.tokenItem) or "Interface\\Icons\\INV_Misc_Coin_01"
    local dlg = StaticPopupDialogs["LEGACYRAIDS_CONFIRM_BUY"]
    dlg.text = string.format("Придбати предмет за |T%s:14|t %d?", icon, item.price)
    dlg.OnAccept = function()
        SendToServer(string.format("LRC_VENDOR_BUY\t%d", item.listIndex))
    end

    StaticPopup_Show("LEGACYRAIDS_CONFIRM_BUY")
end

PreviewItem = function(item)
    if not item or not item.itemId then
        return
    end

    if not (DressUpFrame and DressUpModel and DressUpModel.TryOn) then
        return
    end

    local wasShown = DressUpFrame:IsShown()
    local link = string.format("item:%d:0:0:0:0:0:0:0", item.itemId)

    ShowUIPanel(DressUpFrame)

    if not wasShown and DressUpFrame:IsShown() then
        DressUpModel:SetUnit("player")
    end

    DressUpModel:TryOn(link)
end

local function RenderVendor()
    vendorFrame.title:SetText(LR.vendor.title ~= "" and LR.vendor.title or "Інтендант відлуння")
    vendorFrame.subtitle:SetText("Категорії та товари")
    vendorFrame.balance:SetText(FormatTokenBalance(LR.vendor.tokenItem, LR.vendor.balance))
    vendorFrame.hint:SetText("Покупка перевіряється на сервері")

    if LR.vendor.selectedCategory == nil and #LR.vendor.categoryOrder > 0 then
        LR.vendor.selectedCategory = LR.vendor.categoryOrder[1]
    end

    local categoryRows = {}
    for _, categoryIndex in ipairs(LR.vendor.categoryOrder) do
        local category = LR.vendor.categories[categoryIndex]
        categoryRows[#categoryRows + 1] = {
            text = category and category.name or ("Категорія " .. tostring(categoryIndex)),
            value = categoryIndex,
            selected = categoryIndex == LR.vendor.selectedCategory,
            onSelect = function(value)
                LR.vendor.selectedCategory = value
                LR.vendor.itemScroll = 0
                RenderVendor()
            end,
        }
    end
    SetListData(vendorCategories, categoryRows)

    local selectedItems = LR.vendor.itemsByCategory[LR.vendor.selectedCategory] or {}
    EnsureItemRows(vendorItems, #selectedItems, ConfirmBuy)

    local y = -2
    for i = 1, #vendorItems.rows do
        local row = vendorItems.rows[i]
        local item = selectedItems[i]
        if item then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("RIGHT", 0, 0)
            row.itemId = item.itemId
            row.icon:SetTexture(GetItemIcon(item.itemId) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local itemName = item.displayName
            if not itemName or itemName == "" then
                itemName = GetItemInfo(item.itemId) or ("ID " .. item.itemId)
            end
            row.name:SetText(itemName)
            row.meta:SetText("К-сть: x" .. tostring(item.count or 1))
            local priceIcon = GetItemIcon(item.tokenItem) or "Interface\\Icons\\INV_Misc_Coin_01"
            row.price:SetText(string.format("|T%s:14|t %d", priceIcon, item.price or 0))
            row.buy:Show()
            row.buy.rowData = item
            row.preview.rowData = item
            if item.canPreview then
                row.preview:Show()
            else
                row.preview:Hide()
            end
            row:Show()
            y = y - 54
        else
            row:Hide()
            row.itemId = nil
            row.buy.rowData = nil
            row.preview.rowData = nil
            row.preview:Hide()
        end
    end

    vendorItems.content:SetHeight(math.max(1, -y + 4))
    vendorCategories.scroll:SetVerticalScroll(LR.vendor.categoryScroll or 0)
    vendorItems.scroll:SetVerticalScroll(LR.vendor.itemScroll or 0)

    vendorFrame:SetDefaultPosition()
    lootFrame:Hide()
    vendorFrame:Show()
end

local function MakeBossKey(mapId, bossEntry)
    return tostring(mapId) .. ":" .. tostring(bossEntry)
end

local function ShouldShowLootBoss(mapId, bossEntry)
    if mapId == 580 and (bossEntry == 24892 or bossEntry == 25741) then
        return false
    end

    return true
end

local function GetVisibleLootBossOrder(mapId)
    local visible = {}
    for _, bossEntry in ipairs(LR.loot.bossOrderByMap[mapId] or {}) do
        if ShouldShowLootBoss(mapId, bossEntry) then
            visible[#visible + 1] = bossEntry
        end
    end

    return visible
end

local function RenderLoot()
    lootFrame.title:SetText("LegacyRaids")
    lootFrame.subtitle:SetText("Бонусний лут і емблеми")
    lootFrame.balance:SetText("")
    lootFrame.hint:SetText("Перегляд налаштованого луту")

    local mapRows = {}
    for _, mapId in ipairs(LR.loot.mapOrder) do
        local mapData = LR.loot.maps[mapId]
        local label = mapData and mapData.name or ("Рейд " .. tostring(mapId))
        if mapData and mapData.maxPlayers and mapData.maxPlayers > 0 then
            label = string.format("%s [%d]", label, mapData.maxPlayers)
        end

        mapRows[#mapRows + 1] = {
            text = label,
            value = mapId,
            selected = mapId == LR.loot.selectedMapId,
            onSelect = function(value)
                local bossOrder = GetVisibleLootBossOrder(value)
                LR.loot.selectedMapId = value
                LR.loot.selectedBossEntry = bossOrder[1] or 0
                RenderLoot()
            end,
        }
    end
    SetListData(lootMaps, mapRows)

    local visibleBossOrder = GetVisibleLootBossOrder(LR.loot.selectedMapId)
    local bossRows = {}
    for _, bossEntry in ipairs(visibleBossOrder) do
        local bossData = LR.loot.bossesByMap[LR.loot.selectedMapId] and LR.loot.bossesByMap[LR.loot.selectedMapId][bossEntry]
        bossRows[#bossRows + 1] = {
            text = bossData and bossData.name or ("Бос " .. tostring(bossEntry)),
            value = bossEntry,
            selected = bossEntry == LR.loot.selectedBossEntry,
            onSelect = function(value)
                LR.loot.selectedBossEntry = value
                RenderLoot()
            end,
        }
    end
    SetListData(lootBosses, bossRows)

    local lootRows = LR.loot.itemsByBoss[MakeBossKey(LR.loot.selectedMapId, LR.loot.selectedBossEntry)] or {}
    EnsureItemRows(lootItems, #lootRows, function() end)

    local y = -2
    for i = 1, #lootItems.rows do
        local row = lootItems.rows[i]
        local item = lootRows[i]
        if item then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("RIGHT", 0, 0)
            row.itemId = item.itemId
            row.icon:SetTexture(GetItemIcon(item.itemId) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local itemName = item.displayName
            if not itemName or itemName == "" then
                itemName = GetItemInfo(item.itemId) or ("ID " .. item.itemId)
            end
            row.name:SetText(itemName)
            row.meta:SetText("К-сть: x" .. tostring(item.count or 1))
            row.price:SetText(string.format("%s%%", item.chanceText or "0.00"))
            row.buy:Hide()
            row.preview.rowData = nil
            row.preview:Hide()
            row:Show()
            y = y - 54
        else
            row:Hide()
            row.itemId = nil
            row.preview.rowData = nil
            row.preview:Hide()
        end
    end

    lootItems.content:SetHeight(math.max(1, -y + 4))

    lootFrame:SetDefaultPosition()
    vendorFrame:Hide()
    lootFrame:Show()
end

local function ResetVendor()
    LR.vendor.vendorEntry = 0
    LR.vendor.title = ""
    LR.vendor.tokenItem = 0
    LR.vendor.balance = 0
    LR.vendor.selectedCategory = nil
    LR.vendor.categoryScroll = 0
    LR.vendor.itemScroll = 0
    LR.vendor.categories = {}
    LR.vendor.categoryOrder = {}
    LR.vendor.itemsByCategory = {}
end

local function ResetLoot(selectedMapId, selectedBossEntry)
    LR.loot.selectedMapId = selectedMapId or 0
    LR.loot.selectedBossEntry = selectedBossEntry or 0
    LR.loot.maps = {}
    LR.loot.mapOrder = {}
    LR.loot.bossesByMap = {}
    LR.loot.bossOrderByMap = {}
    LR.loot.itemsByBoss = {}
end

local function EnsureLootMap(mapId)
    if not LR.loot.maps[mapId] then
        LR.loot.maps[mapId] = { name = "Рейд " .. tostring(mapId), maxPlayers = 0 }
        LR.loot.mapOrder[#LR.loot.mapOrder + 1] = mapId
    end
end

local function HandlePayload(payload)
    local parts = SplitTabs(payload)
    local cmd = parts[1]
    if not cmd or cmd == "" then
        return
    end

    if string.sub(cmd, 1, 4) == "LRC_" then
        return
    end

    if cmd == "LRS_CLOSE" then
        HideAll()
        return
    end

    if cmd == "LRS_VENDOR_RESET" then
        local newVendorEntry = ToNumber(parts[2], 0)
        local oldVendorEntry = LR.vendor.vendorEntry
        local oldCategory = LR.vendor.selectedCategory
        local oldCategoryScroll = vendorCategories.scroll and vendorCategories.scroll:GetVerticalScroll() or 0
        local oldItemScroll = vendorItems.scroll and vendorItems.scroll:GetVerticalScroll() or 0
        ResetVendor()
        LR.vendor.vendorEntry = newVendorEntry
        LR.vendor.title = parts[3] or ""
        LR.vendor.tokenItem = ToNumber(parts[4], 0)
        LR.vendor.balance = ToNumber(parts[5], 0)
        if oldVendorEntry == newVendorEntry then
            LR.vendor.selectedCategory = oldCategory
            LR.vendor.categoryScroll = oldCategoryScroll or 0
            LR.vendor.itemScroll = oldItemScroll or 0
        end
        return
    end

    if cmd == "LRS_VENDOR_CATEGORY" then
        local categoryIndex = ToNumber(parts[2], 0)
        local name = parts[3] or ("Категорія " .. tostring(categoryIndex))
        if not LR.vendor.categories[categoryIndex] then
            LR.vendor.categories[categoryIndex] = { name = name }
            LR.vendor.categoryOrder[#LR.vendor.categoryOrder + 1] = categoryIndex
        else
            LR.vendor.categories[categoryIndex].name = name
        end
        LR.vendor.itemsByCategory[categoryIndex] = LR.vendor.itemsByCategory[categoryIndex] or {}
        if LR.vendor.selectedCategory == nil then
            LR.vendor.selectedCategory = categoryIndex
        end
        return
    end

    if cmd == "LRS_VENDOR_ITEM" then
        local categoryIndex = ToNumber(parts[2], 0)
        local item = {
            categoryIndex = categoryIndex,
            listIndex = ToNumber(parts[3], 0),
            itemId = ToNumber(parts[4], 0),
            count = ToNumber(parts[5], 1),
            price = ToNumber(parts[6], 0),
            tokenItem = ToNumber(parts[7], 0),
            canPreview = ToNumber(parts[8], 0) == 1,
            displayName = parts[9] or "",
        }
        LR.vendor.itemsByCategory[categoryIndex] = LR.vendor.itemsByCategory[categoryIndex] or {}
        LR.vendor.itemsByCategory[categoryIndex][#LR.vendor.itemsByCategory[categoryIndex] + 1] = item
        return
    end

    if cmd == "LRS_VENDOR_SHOW" then
        if LR.vendor.selectedCategory == nil and #LR.vendor.categoryOrder > 0 then
            LR.vendor.selectedCategory = LR.vendor.categoryOrder[1]
        end
        RenderVendor()
        return
    end

    if cmd == "LRS_LOOT_RESET" then
        ResetLoot(ToNumber(parts[2], 0), ToNumber(parts[3], 0))
        return
    end

    if cmd == "LRS_LOOT_MAP" then
        local mapId = ToNumber(parts[2], 0)
        EnsureLootMap(mapId)
        LR.loot.maps[mapId].name = parts[3] or LR.loot.maps[mapId].name
        LR.loot.maps[mapId].maxPlayers = ToNumber(parts[4], 0)
        return
    end

    if cmd == "LRS_LOOT_BOSS" then
        local mapId = ToNumber(parts[2], 0)
        local bossEntry = ToNumber(parts[3], 0)
        EnsureLootMap(mapId)
        LR.loot.bossesByMap[mapId] = LR.loot.bossesByMap[mapId] or {}
        LR.loot.bossOrderByMap[mapId] = LR.loot.bossOrderByMap[mapId] or {}
        if not LR.loot.bossesByMap[mapId][bossEntry] then
            LR.loot.bossOrderByMap[mapId][#LR.loot.bossOrderByMap[mapId] + 1] = bossEntry
        end
        LR.loot.bossesByMap[mapId][bossEntry] = { name = parts[4] or ("Бос " .. tostring(bossEntry)) }
        return
    end

    if cmd == "LRS_LOOT_ITEM" then
        local mapId = ToNumber(parts[2], 0)
        local bossEntry = ToNumber(parts[3], 0)
        local key = MakeBossKey(mapId, bossEntry)
        LR.loot.itemsByBoss[key] = LR.loot.itemsByBoss[key] or {}
        LR.loot.itemsByBoss[key][#LR.loot.itemsByBoss[key] + 1] = {
            itemId = ToNumber(parts[4], 0),
            count = ToNumber(parts[5], 1),
            chanceText = parts[6] or "0.00",
            personal = ToNumber(parts[7], 0) == 1,
            displayName = parts[8] or "",
        }
        return
    end

    if cmd == "LRS_LOOT_SHOW" then
        if LR.loot.selectedMapId == 0 and #LR.loot.mapOrder > 0 then
            LR.loot.selectedMapId = LR.loot.mapOrder[1]
        end

        local bossOrder = GetVisibleLootBossOrder(LR.loot.selectedMapId)
        if LR.loot.selectedBossEntry == 0 and #bossOrder > 0 then
            LR.loot.selectedBossEntry = bossOrder[1]
        end

        RenderLoot()
        return
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "GOSSIP_SHOW" then
        SendHello()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        if vendorFrame:IsShown() then
            RenderVendor()
        end
        if lootFrame:IsShown() then
            RenderLoot()
        end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix == APP_PREFIX and type(message) == "string" then
            HandlePayload(message)
        end
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg = ...
        local prefix = APP_PREFIX .. "\t"
        if type(msg) == "string" and string.sub(msg, 1, string.len(prefix)) == prefix then
            HandlePayload(string.sub(msg, string.len(prefix) + 1))
        end
    end
end)
