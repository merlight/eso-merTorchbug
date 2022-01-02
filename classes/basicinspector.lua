local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local wm = WINDOW_MANAGER

local strformat = string.format
local strlow = string.lower
local strlen = string.len
local tos = tostring

local UPDATE_NONE = 0
local UPDATE_SCROLL = 1
local UPDATE_SORT = 2
local UPDATE_FILTER = 3
local UPDATE_MASTER = 4

local earliestTimeStamp = 1
local latestTimeStamp = 2147483647

local function createPanelFunc(inspector, panelClass)
    local function createPanel(pool)
        local panelName = panelClass.CONTROL_PREFIX .. pool:GetNextControlId()
        local panelControl = wm:CreateControlFromVirtual(panelName, inspector.control,
                                                         panelClass.TEMPLATE_NAME)
        return panelClass(panelControl, inspector, pool)
    end
    return createPanel
end


local function resetPanel(panel, pool)
    panel:reset()
end


local function startMovingOnMiddleDown(control, mouseButton)
    if mouseButton == MOUSE_BUTTON_INDEX_MIDDLE then
        local owningWindow = control:GetOwningWindow()
        if owningWindow:StartMoving() then
            --df("tbug: middle down => start moving %s", owningWindow:GetName())
            control.tbugMovingWindow = owningWindow
            return true
        end
    end
end


local function stopMovingOnMiddleUp(control, mouseButton)
    if mouseButton == MOUSE_BUTTON_INDEX_MIDDLE then
        local movingWindow = control.tbugMovingWindow
        if movingWindow then
            --df("tbug: middle up => stop moving %s", movingWindow:GetName())
            movingWindow:StopMovingOrResizing()
            control.tbugMovingWindow = nil
            return true
        end
    end
end


-------------------------------
-- class BasicInspectorPanel --
local classes = tbug.classes
local BasicInspectorPanel = classes.BasicInspectorPanel


function BasicInspectorPanel:__init__(control, inspector, pool)
    self._pool = pool
    self._pendingUpdate = UPDATE_NONE
    self._lockedForUpdates = false
    self.control = assert(control)
    self.inspector = inspector

    local listContents = control:GetNamedChild("ListContents")
    if listContents then
        listContents:SetHandler("OnMouseDown", startMovingOnMiddleDown)
        listContents:SetHandler("OnMouseUp", stopMovingOnMiddleUp)
    end
end


function BasicInspectorPanel:addDataType(typeId, templateName, ...)
    local list = self.list

    local function rowMouseEnter(row)
        local data = ZO_ScrollList_GetData(row)
        self:onRowMouseEnter(row, data)
    end

    local function rowMouseExit(row)
        local data = ZO_ScrollList_GetData(row)
        self:onRowMouseExit(row, data)
    end

    local function rowMouseUp(row, ...)
        if stopMovingOnMiddleUp(row, ...) then
            return
        end
        local data = ZO_ScrollList_GetData(row)
        self:onRowMouseUp(row, data, ...)
    end

    local function rowMouseDoubleClick(row, ...)
        local data = ZO_ScrollList_GetData(row)
        self:onRowMouseDoubleClick(row, data, ...)
    end

    local function rowCreate(pool)
        local name = strformat("$(grandparent)%dRow%d", typeId, pool:GetNextControlId())
        local row = wm:CreateControlFromVirtual(name, list.contents, templateName)
        row:SetHandler("OnMouseDown", startMovingOnMiddleDown)
        row:SetHandler("OnMouseEnter", rowMouseEnter)
        row:SetHandler("OnMouseExit", rowMouseExit)
        row:SetHandler("OnMouseUp", rowMouseUp)
        row:SetHandler("OnMouseDoubleClick", rowMouseDoubleClick)
        return row
    end

    ZO_ScrollList_AddDataType(list, typeId, templateName, ...)

    local dataTypeTable = ZO_ScrollList_GetDataTypeTable(list, typeId)
    dataTypeTable.pool = ZO_ObjectPool:New(rowCreate, ZO_ObjectPool_DefaultResetControl) --add reset function
end


function BasicInspectorPanel:buildMasterList()
end


function BasicInspectorPanel:colorRow(row, data, mouseOver)
    local hiBg = row:GetNamedChild("HiBg")
    if hiBg then
        hiBg:SetHidden(not mouseOver)
    end
end


function BasicInspectorPanel:commitScrollList()
    self:exitRowIf(self._mouseOverRow)
    ZO_ScrollList_Commit(self.list)
end


function BasicInspectorPanel:enterRow(row, data)
    if not self._lockedForUpdates then
        ZO_ScrollList_MouseEnter(self.list, row)
        self:colorRow(row, data, true)
        self._mouseOverRow = row
    end
end


function BasicInspectorPanel:exitRow(row, data)
    if not self._lockedForUpdates then
        ZO_ScrollList_MouseExit(self.list, row)
        self:colorRow(row, data, false)
        self._mouseOverRow = nil
    end
end


function BasicInspectorPanel:exitRowIf(row)
    if row then
        self:exitRow(row, ZO_ScrollList_GetData(row))
    end
end


function BasicInspectorPanel:filterScrollList()
    local masterList = self.masterList
    local filterFunc = self.filterFunc
    local dataList = ZO_ScrollList_GetDataList(self.list)

    ZO_ScrollList_Clear(self.list)

    if filterFunc then
        local j = 1
        for i = 1, #masterList do
            local dataEntry = masterList[i]
            if filterFunc(dataEntry.data) then
                dataList[j] = dataEntry
                j = j + 1
            end
        end
    else
        for i = 1, #masterList do
            dataList[i] = masterList[i]
        end
    end
end


function BasicInspectorPanel:initScrollList(control)
    local list = assert(control:GetNamedChild("List"))

    self.list = list
    self.compareFunc = false
    self.filterFunc = false
    self.masterList = {}

    ZO_ScrollList_AddResizeOnScreenResize(list)
    self:setLockedForUpdates(true)

    list:SetHandler("OnEffectivelyShown", function(list)
        ZO_ScrollAreaBarBehavior_OnEffectivelyShown(list)
        list.windowHeight = list:GetHeight()
        self:refreshScroll()
        self:setLockedForUpdates(false)
    end)

    list:SetHandler("OnEffectivelyHidden", function(list)
        ZO_ScrollAreaBarBehavior_OnEffectivelyHidden(list)
        self:setLockedForUpdates(true)
    end)

    local thumb = list.scrollbar:GetThumbTextureControl()
    thumb:SetDimensionConstraints(8, 8, 0, 0)
end


function BasicInspectorPanel:onResizeUpdate(newHeight)
    local list = self.list
    local listHeight = (newHeight ~= nil and newHeight >= tbug.minInspectorWindowHeight and newHeight)
    if listHeight == nil or listHeight == 0 then listHeight = list:GetHeight() end
--d(">onResizeUpdate: " ..tos(listHeight))
    if list.windowHeight ~= listHeight then
        list.windowHeight = listHeight
        ZO_ScrollList_Commit(list)
    end
end


function BasicInspectorPanel:onRowClicked(row, data, mouseButton, ...)
end

function BasicInspectorPanel:onRowDoubleClicked(row, data, mouseButton, ...)
end

local function isTextureRow(rowText)
    if not rowText or type(rowText) ~= "string" or rowText == "" then return end
    local textureString = rowText:match('(%.dds)$')
    if textureString == ".dds" then return true end
    return false
end

local function isMouseCursorRow(row, cursorConstant)
    --d(">isMouseCursorRow: " ..tos(rowText))
    if row._isCursorConstant then return true end
    if not cursorConstant or type(cursorConstant) ~= "string" or cursorConstant == "" then return end
    local mouseCursorName = cursorConstant:match('^MOUSE_CURSOR_GENERIC_.*')
    if mouseCursorName ~= nil then return false end
    mouseCursorName = cursorConstant:match('^MOUSE_CURSOR_.*')
    if mouseCursorName ~= nil then return true end
    return false
end

local function isTimeStampRow(row, data, value)
    if row._isTimeStamp then return true end
    local key = data.key
    local prop = data.prop
    local propName = prop and prop.name
--d(">isTimeStampRow: " ..tos(value) .. ", key: " ..tos(key) .. ", propName: " ..tos(propName))
    if value and type(value) == "number" and (value >= earliestTimeStamp and value <= latestTimeStamp) then
        if key ~= nil and type(key) == "string" then
            local keyLow = strlow(key)
            if keyLow ~= nil and ((keyLow:match('time') ~= nil or keyLow:match('date') ~= nil)) then
                return true
            end
        elseif propName ~= nil and type(propName) == "string"  then
            local propNameLow = strlow(propName)
            if propNameLow ~= nil and ((propNameLow:match('time') ~= nil or propNameLow:match('date') ~= nil)) then
                return true
            end
        end
    end
    return false
end


function BasicInspectorPanel:onRowMouseEnter(row, data)
--d("[tbug:onRowMouseEnter]")
    self:enterRow(row, data)

    if not data then return end
    local prop      = data.prop
    local propName  = (prop and prop.name) or data.key
    local value     = data.value
--[[
tbug._BasicInspectorPanel_onRowMouseEnter = {
    row = row,
    data = data,
    value = value,
    prop = prop,
}
]]

    if propName ~= nil and propName ~= "" and value ~= nil and value ~= "" then
--d(">propName:  " ..tos(propName) .. ", value: " ..tos(value))
        --Show the texture as tooltip
        if tbug.textureNamesSupported[propName] == true or isTextureRow(value) then
            local width     = (prop and prop.textureFileWidth) or 48
            local height    = (prop and prop.textureFileHeight) or 48
            if width > tbug.maxInspectorTexturePreviewWidth then
                width = tbug.maxInspectorTexturePreviewWidth
            end
            if height > tbug.maxInspectorTexturePreviewHeight then
                height = tbug.maxInspectorTexturePreviewHeight
            end
            local textureText = zo_iconTextFormatNoSpace(value, width, height, "", nil)
            if textureText and textureText ~= "" then
                ZO_Tooltips_ShowTextTooltip(row, RIGHT, textureText)
            end
            --Change the mouse cursor to the cursor constant below the mouse
        elseif isMouseCursorRow(row, propName) then
            row._isCursorConstant = true
            wm:SetMouseCursor(_G[propName])
            --Add a tooltip to timestamps
        elseif isTimeStampRow(row, data, value) then
            row._isTimeStamp = true
            --Show formated timestamp text tooltip
            local noError, resultStr = pcall(function() return os.date("%c", value) end)
            if noError == true then
                ZO_Tooltips_ShowTextTooltip(row, RIGHT, resultStr)
            end
        end
    end
end


function BasicInspectorPanel:onRowMouseExit(row, data)
    self:exitRow(row, data)
    ZO_Tooltips_HideTextTooltip()
    if row._isCursorConstant == true then
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
        row._isCursorConstant = nil
    elseif row._isTimeStamp == true then
        row._isTimeStamp = nil
    end
end


function BasicInspectorPanel:onRowMouseUp(row, data, mouseButton, upInside, ...)
    if upInside then
        self:onRowClicked(row, data, mouseButton, ...)
    end
end

function BasicInspectorPanel:onRowMouseDoubleClick(row, data, mouseButton, upInside, ...)
    self:onRowDoubleClicked(row, data, mouseButton, ...)
end

function BasicInspectorPanel:readyForUpdate(pendingUpdate)
    if not self._lockedForUpdates then
        return true
    end
    if self._pendingUpdate < pendingUpdate then
        self._pendingUpdate = pendingUpdate
    end
    return false
end


function BasicInspectorPanel:refreshData()
--d("BasicInspectorPanel:refreshData")
    if self:readyForUpdate(UPDATE_MASTER) then
--d(">MasterList")
        self:buildMasterList()
--d(">>FilterScrollList")
        self:filterScrollList()
--d(">>SortScrollList")
        self:sortScrollList()
--d(">>CommitScrollList")
        self:commitScrollList()
    end
end


function BasicInspectorPanel:refreshFilter()
    if self:readyForUpdate(UPDATE_FILTER) then
        self:filterScrollList()
        self:sortScrollList()
        self:commitScrollList()
    end
end


function BasicInspectorPanel:refreshScroll()
    if self:readyForUpdate(UPDATE_SCROLL) then
        self:commitScrollList()
    end
end


function BasicInspectorPanel:refreshSort()
    if self:readyForUpdate(UPDATE_SORT) then
        self:sortScrollList()
        self:commitScrollList()
    end
end


function BasicInspectorPanel:refreshVisible()
    ZO_ScrollList_RefreshVisible(self.list)
end


function BasicInspectorPanel:release()
    if self._pool and self._pkey then
        self._pool:ReleaseObject(self._pkey)
    end
end


function BasicInspectorPanel:reset()
end


function BasicInspectorPanel:setFilterFunc(filterFunc)
    if self.filterFunc ~= filterFunc then
        self.filterFunc = filterFunc
        self:refreshFilter()
    end
end


function BasicInspectorPanel:setLockedForUpdates(locked)
    if self._lockedForUpdates ~= locked then
        self._lockedForUpdates = locked
        if locked then
            return
        end
    else
        return
    end

    self:exitRowIf(self._mouseOverRow)

    local pendingUpdate = self._pendingUpdate
    self._pendingUpdate = UPDATE_NONE

    if pendingUpdate >= UPDATE_SCROLL then
        if pendingUpdate >= UPDATE_SORT then
            if pendingUpdate >= UPDATE_FILTER then
                if pendingUpdate >= UPDATE_MASTER then
                    self:buildMasterList()
                end
                self:filterScrollList()
            end
            self:sortScrollList()
        end
        self:commitScrollList()
    end
end


function BasicInspectorPanel:setupRow(row, data)
    row._isCursorConstant = nil
    if self._lockedForUpdates then
        self:colorRow(row, data, self._mouseOverRow == row)
    elseif MouseIsOver(row) then
        self:enterRow(row, data)
    else
        self:colorRow(row, data, false)
    end
end


function BasicInspectorPanel:sortScrollList()
    local compareFunc = self.compareFunc
    if compareFunc then
        local dataList = ZO_ScrollList_GetDataList(self.list)
        table.sort(dataList, compareFunc)
    end
end


--------------------------
-- class BasicInspector --
local TabWindow = classes.TabWindow
local BasicInspector = classes.BasicInspector .. TabWindow


function BasicInspector:__init__(id, control)
    TabWindow.__init__(self, control, id)
    self.panelPools = {}
end


function BasicInspector:acquirePanel(panelClass)
    local pool = self.panelPools[panelClass]
    if not pool then
        pool = ZO_ObjectPool:New(createPanelFunc(self, panelClass), resetPanel)
        self.panelPools[panelClass] = pool
    end
    local panel, pkey = pool:AcquireObject()
    panel._pkey = pkey
    return panel
end
