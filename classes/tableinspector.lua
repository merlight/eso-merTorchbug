local tbug = LibStub:GetLibrary("merTorchbug")
local cm = CALLBACK_MANAGER
local wm = WINDOW_MANAGER
local strformat = string.format
local typeColors = tbug.cache.typeColors
local typeSafeLess = tbug.typeSafeLess

local BLUE = ZO_ColorDef:New(0.8, 0.8, 1.0)
local RED  = ZO_ColorDef:New(1.0, 0.2, 0.2)


local function getControlInfo(control)
    local controlTypes = tbug.glookupEnum("CT")
    local ct = control:GetType()
    return ct, controlTypes[ct], control:GetName()
end


local function invoke(object, method, ...)
    return object[method](object, ...)
end


-------------------------------
-- class TableInspectorPanel --

local BasicInspectorPanel = tbug.classes.BasicInspectorPanel
local TableInspectorPanel = tbug.classes.TableInspectorPanel .. BasicInspectorPanel

TableInspectorPanel.CONTROL_PREFIX = "$(parent)PanelT"
TableInspectorPanel.TEMPLATE_NAME = "tbugTableInspectorPanel"

local RT = tbug.subtable(TableInspectorPanel, "ROW_TYPES")

RT.GENERIC = 1
RT.FONT_OBJECT = 2
RT.LOCAL_STRING = 3
RT.SOUND_STRING = 4
RT.LIB_TABLE = 5


local function anchorEditBoxToListCell(editBox, listCell)
    editBox:ClearAnchors()
    editBox:SetAnchor(TOPRIGHT, listCell, TOPRIGHT, 0, 4)
    editBox:SetAnchor(BOTTOMLEFT, listCell, BOTTOMLEFT, 0, -3)
    listCell:SetHidden(true)
end


function TableInspectorPanel:__init__(control, ...)
    BasicInspectorPanel.__init__(self, control, ...)
    self:initScrollList(control)

    --ZO_ScrollList_EnableHighlight(self.list, "tbugTableInspectorRowHighlight")

    self.compareFunc = function(a, b)
        return typeSafeLess(a.data.key, b.data.key)
    end

    self.editBox = self:createEditBox(self.list)
    self.editData = nil
    self.editTable = nil

    cm:RegisterCallback("tbugChanged:typeColor", function() self:refreshVisible() end)
end


function TableInspectorPanel:bindMasterList(editTable)
    self.editTable = editTable
end


function TableInspectorPanel:buildMasterList()
    if self:buildMasterListSpecial() then
        return
    end

    local masterList = self:clearMasterList(self.editTable)
    local n = 0

    for k, v in next, self.editTable do
        local tv = type(v)
        local rt = RT.GENERIC

        if tv == "userdata" and pcall(invoke, v, "GetFontInfo") then
            rt = RT.FONT_OBJECT
        end

        local data = {key = k, value = v}
        n = n + 1
        masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
    end
end


function TableInspectorPanel:buildMasterListSpecial()
    local editTable = self.editTable
    if rawequal(editTable, nil) then
        return true
    elseif rawequal(editTable, _G.ESO_Dialogs) then
        self:populateMasterList(editTable, RT.GENERIC)
    elseif rawequal(editTable, _G.EsoStrings) then
        self:populateMasterList(editTable, RT.LOCAL_STRING)
    elseif rawequal(editTable, _G.SOUNDS) then
        self:populateMasterList(editTable, RT.SOUND_STRING)
    elseif rawequal(editTable, LibStub.libs) then
        self:populateMasterList(editTable, RT.LIB_TABLE)
    else
        return false
    end
    return true
end


function TableInspectorPanel:clearMasterList(editTable)
    local masterList = self.masterList
    tbug.truncate(masterList, 0)
    self.editTable = editTable
    return masterList
end


function TableInspectorPanel:createEditBox(list)
    local editBox = wm:CreateControlFromVirtual("$(parent)ValueEdit", list.contents,
                                                "ZO_DefaultEdit")

    local function valueEditCancel(editBox)
        df("tbug: edit cancel")
        editBox:SetHidden(true)
        local editData = self.editData
        if editData then
            self.editData = nil
            ZO_ScrollList_RefreshVisible(list, editData)
        end
    end

    local function valueEditConfirm(editBox)
        local expr = editBox:GetText()
        df("tbug: edit confirm: %s", expr)

        local func, err = zo_loadstring("return " .. expr)
        if not func then
            df("|c%s%s", RED:ToHex(), err)
            return
        end

        local ok, res1 = pcall(setfenv(func, tbug.env))
        if not ok then
            df("|c%s%s", RED:ToHex(), res1)
            return
        end

        local editData = self.editData
        if editData then
            local ok, res2 = pcall(tbug.setindex, self.editTable, editData.key, res1)
            if not ok then
                df("|c%s%s", RED:ToHex(), res2)
                return
            end
            self.editData = nil
            editData.value = res2
            ZO_ScrollList_RefreshVisible(list, editData)
        end

        editBox:LoseFocus()
    end

    local function valueEditUpdate(editBox)
        local expr = editBox:GetText()
        --df("tbug: edit update: %s", expr)
        local func, err = zo_loadstring("return " .. expr)
        if func then
            editBox:SetColor(BLUE:UnpackRGBA())
        else
            editBox:SetColor(RED:UnpackRGBA())
        end
    end

    editBox:SetFont("ZoFontGameSmall")
    editBox:SetHandler("OnEnter", valueEditConfirm)
    editBox:SetHandler("OnFocusLost", valueEditCancel)
    editBox:SetHandler("OnTextChanged", valueEditUpdate)

    return editBox
end


function TableInspectorPanel:initScrollList(control)
    BasicInspectorPanel.initScrollList(self, control)

    local function setupValue(cell, typ, val)
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        cell:SetText(tostring(val))
    end

    local function setupValueLookup(cell, typ, val)
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        local name = tbug.glookup(val)
        if name then
            cell:SetText(strformat("%s: %s", typ, name))
        else
            cell:SetText(tostring(val))
        end
    end

    local function setupCommon(row, data, list, nk)
        local k = data.key
        local tk = type(k)
        local ck = typeColors[tk]

        self:setupRow(row, data)

        if nk == 2 then
            row.cKeyLeft:SetColor(ck:UnpackRGBA())
            row.cKeyRight:SetColor(ck:UnpackRGBA())
        else
            row.cKeyLeft:SetColor(ck:UnpackRGBA())
            row.cKeyLeft:SetText(tostring(k))
            row.cKeyRight:SetText("")
        end

        if self.editData == data then
            anchorEditBoxToListCell(self.editBox, row.cVal)
        else
            row.cVal:SetHidden(false)
        end

        return k, tk
    end

    local function setupGeneric(row, data, list)
        local k, tk = setupCommon(row, data, list, 1)
        local v = data.value
        local tv = type(v)

        if v == nil or tv == "boolean" or tv == "number" then
            setupValue(row.cVal, tv, v)
        elseif tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        elseif tv == "table" and next(v) == nil then
            setupValue(row.cVal, tv, "{}")
        elseif tv == "userdata" then
            local ok, ct, cts, name = pcall(getControlInfo, v)
            if ok then
                setupValue(row.cKeyRight, type(ct), cts)
                setupValue(row.cVal, tv, name)
            else
                setupValueLookup(row.cVal, tv, v)
            end
        else
            setupValueLookup(row.cVal, tv, v)
            if rawequal(v, self.editTable) then
                setupValue(row.cKeyRight, tv, "self")
            end
        end
    end

    local function setupFontObject(row, data, list)
        local k, tk = setupCommon(row, data, list, 1)
        local v = data.value
        local tv = type(v)

        local ok, face, size, option = pcall(invoke, v, "GetFontInfo")
        if ok then
            v = strformat("%s||%s||%s",
                          typeColors[type(face)]:Colorize(face),
                          typeColors[type(size)]:Colorize(size),
                          typeColors[type(option)]:Colorize(option))
        end

        setupValue(row.cVal, tv, v)
    end

    local function setupLibTable(row, data, list)
        local k, tk = setupCommon(row, data, list, 1)
        local v = data.value

        if type(LibStub.minors) == "table" then
            local m = LibStub.minors[k]
            setupValue(row.cKeyRight, type(m), m)
        end

        setupValue(row.cVal, type(v), v)
    end

    local function setupLocalString(row, data, list)
        local k, tk = setupCommon(row, data, list, 2)
        local v = data.value
        local tv = type(v)

        if tk == "number" then
            local si = rawget(tbug.glookupEnum("SI"), k)
            row.cKeyLeft:SetText(si or "")
            row.cKeyRight:SetText(tostring(k))
        else
            row.cKeyLeft:SetText(tostring(k))
            row.cKeyRight:SetText("")
        end

        if tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        else
            setupValue(row.cVal, tv, v)
        end
    end

    local function hideCallback(row, data)
        if self.editData == data then
            self.editBox:ClearAnchors()
            self.editBox:SetAnchor(BOTTOMRIGHT, nil, TOPRIGHT, 0, -20)
        end
    end

    self:addDataType(RT.GENERIC, "tbugTableInspectorRow", 24, setupGeneric, hideCallback)
    self:addDataType(RT.FONT_OBJECT, "tbugTableInspectorRow", 24, setupFontObject, hideCallback)
    self:addDataType(RT.LOCAL_STRING, "tbugTableInspectorRow", 24, setupLocalString, hideCallback)
    self:addDataType(RT.SOUND_STRING, "tbugTableInspectorRow", 24, setupGeneric, hideCallback)
    self:addDataType(RT.LIB_TABLE, "tbugTableInspectorRow", 24, setupLibTable, hideCallback)
end


function TableInspectorPanel:onRowClicked(row, data, mouseButton)
    if mouseButton == 1 then
        local tv = type(data.value)

        if tv == "string" then
            if data.dataEntry.typeId == RT.SOUND_STRING then
                PlaySound(data.value)
            end

        elseif tv == "table" then
            local newTabIndex = 0
            local title = tostring(data.key)

            for tabIndex, tabControl in ipairs(self.inspector.tabs) do
                local panel = tabControl.panel
                if rawequal(data.value, panel.editTable) then
                    self.inspector:selectTab(tabControl)
                    return
                elseif panel == self then
                    newTabIndex = tabIndex + 1
                end
            end

            if rawequal(data.value, _G) then
                local inspector = tbug.getGlobalInspector()
                if inspector.control:IsHidden() then
                    inspector.control:SetHidden(false)
                    inspector:refreshGlobals()
                end
                inspector.control:BringWindowToTop()
                return
            end

            df("tbug: adding tab for %q", title)

            local panel = self.inspector:acquirePanel(TableInspectorPanel)
            local tabControl = self.inspector:insertTab(title, panel, newTabIndex)
            panel.editTable = data.value
            panel:refreshData()
            self.inspector:selectTab(tabControl)

            local mt = getmetatable(data.value)

            while type(mt) == "table" do
                local mtPanel = self.inspector:acquirePanel(TableInspectorPanel)
                local mtTab = self.inspector:insertTab("metatable", mtPanel, newTabIndex + 1)
                newTabIndex = newTabIndex + 1
                mtPanel.editTable = mt
                mtPanel:refreshData()
                mt = getmetatable(mt)
            end

        elseif tv == "userdata" then
            local inspector = tbug.inspect(data.value, tostring(data.key))
            if inspector then
                inspector.control:BringWindowToTop()
            end
        end
    end
end


function TableInspectorPanel:onRowMouseUp(row, data, mouseButton, upInside, ...)
    if upInside then
        if mouseButton == 2 and MouseIsOver(row.cVal) then
            if self.editData ~= data then
                self.editBox:LoseFocus()
            end
            if self:valueEditStart(row, data) then
                return
            end
        end
        self.editBox:LoseFocus()
        self:onRowClicked(row, data, mouseButton)
    end
end


function TableInspectorPanel:populateMasterList(editTable, dataType)
    local masterList, n = self.masterList, 0
    for k, v in next, editTable do
        n = n + 1
        local dataEntry = masterList[n]
        if dataEntry then
            dataEntry.typeId = dataType
            dataEntry.data.key = k
            dataEntry.data.value = v
        else
            local data = {key = k, value = v}
            masterList[n] = ZO_ScrollList_CreateDataEntry(dataType, data)
        end
    end
    return tbug.truncate(masterList, n)
end


function TableInspectorPanel:reset()
    tbug.truncate(self.masterList, 0)
    ZO_ScrollList_Clear(self.list)
    self:commitScrollList()
    self.control:SetHidden(true)
    self.control:ClearAnchors()
    self.editTable = nil
end


function TableInspectorPanel:setupRowValueEdit(row, editMode)
    if editMode then
        row.cVal:SetHidden(true)
        self.editBox:ClearAnchors()
        self.editBox:SetAnchor(TOPRIGHT, row.cVal, TOPRIGHT, 0, 4)
        self.editBox:SetAnchor(BOTTOMLEFT, row.cVal, BOTTOMLEFT, 0, -3)
    else
        row.cVal:SetHidden(false)
    end
end


function TableInspectorPanel:valueEditStart(row, data)
    if not self.editTable then
        return false
    end
    if self.editData == data then
        return true
    end
    self.editBox:LoseFocus()
    df("tbug: edit start")
    if type(data.value) == "string" then
        self.editBox:SetText(strformat("%q", data.value))
    else
        self.editBox:SetText(tostring(data.value))
    end
    self.editBox:SetHidden(false)
    self.editBox:TakeFocus()
    self.editData = data
    anchorEditBoxToListCell(self.editBox, row.cVal)
    return true
end


--------------------------
-- class TableInspector --

local BasicInspector = tbug.classes.BasicInspector
local TableInspector = tbug.classes.TableInspector .. BasicInspector

TableInspector._activeObjects = {}
TableInspector._inactiveObjects = {}
TableInspector._nextObjectId = 1
TableInspector._templateName = "tbugTableInspector"


function TableInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("tableInspector" .. id)
    self:configure(self.conf)
end


function TableInspector:refresh()
    local index, subject = 1, self.subject
    local title = "table"
    local blacklist = {[_G] = true}

    df("tbug: refreshing %s", tostring(subject))

    while not blacklist[subject] and type(subject) == "table" do
        blacklist[subject] = true

        --df(". %d %s", index, tostring(subject))

        local tabControl = self.tabs[index]
        if tabControl then
            self:setTabTitle(tabControl, title)
        else
            local panel = self:acquirePanel(TableInspectorPanel)
            tabControl = self:insertTab(title, panel, index)
        end

        local panel = tabControl.panel
        panel.editTable = subject
        panel:refreshData()

        subject = getmetatable(subject)
        title = "metatable"
        index = index + 1
    end

    for i = #self.tabs, index, -1 do
        local panel = self:removeTab(i)
        panel:release()
    end

    if not self.activeTab then
        self:selectTab(1)
    end
end
